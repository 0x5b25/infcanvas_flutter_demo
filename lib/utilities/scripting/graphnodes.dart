import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:infcanvas/utilities/scripting/graph_compiler.dart';
import 'package:infcanvas/widgets/scripting/fgpage.dart';

import 'opcodes.dart';
import 'script_graph.dart';


class TCVMMethod extends SeqTranslationUnit{
  
  VMMethodInfo get mtd => (fromWhichNode as GNVMMethod).info;

  @override
  int get depCnt => mtd.Args().FieldCount() + (mtd.isStaticMethod?0:1);

  @override
  int get nodeCnt => mtd.isConstantMethod?0:1;

  @override
  int get outputCnt => mtd.Rets().FieldCount();

  @override
  GraphNode? doGetNode(int idx){
    var slot = fromWhichNode.outSlot.first as ExecOutSlotInfo;
    var link = slot.link;
    if(link == null) return null;
    return link.to.node;
  }

  @override
  ValueDependency? doGetValDep(int idx){
    var _DepFromSlot = (slot){
      var link = slot.link;
      if(link == null) return null;
      var rear = link.from as ValueOutSlotInfo;
      return ValueDependency(rear.node, rear.outputOrder);
    };

    int base = mtd.isConstantMethod?0:1;
    //Requesting "this" pointer
    if(!mtd.isStaticMethod && idx == depCnt - 1){
      var slot = fromWhichNode.inSlot[base] as ValueInSlotInfo;
      return _DepFromSlot(slot);
    }

    if(!mtd.isStaticMethod) base++;
    var slot = fromWhichNode.inSlot[base+idx] as ValueInSlotInfo;
    return _DepFromSlot(slot);
  }

  @override
  CodeBlock? doEmitCode(){
    if(mtd.IsEmbeddable()){
      return SimpleCB([
        InstLine(OpCode.d_embed, s:"${mtd.thisType}|${mtd.name}")
      ]);
    }

    if(mtd.isStaticMethod){
      return SimpleCB([
        InstLine(OpCode.callstatic, s:"${mtd.thisType}|${mtd.name}")
      ]);
    }else{
      return SimpleCB([
        InstLine(OpCode.callmem, s:"${mtd.thisType}|${mtd.name}")
      ]);
    }
  }

}

class GNVMMethod extends GraphNode{

  String get cls => info.thisType;
  VMMethodInfo info;
  bool Function(String, String) typeCompat;

  GNVMMethod(this.info, this.typeCompat){
    Update();    
  }

  void Update(){
    var mtd = this.info;
    displayName = info.name;
    if(mtd.isConstantMethod){
      if(
        inSlot.length > 0 &&
        inSlot.first is ExecInSlotInfo
      ){
        inSlot.first.Disconnect();
        inSlot.removeAt(0);
      }

      if(
        outSlot.length > 0 &&
        outSlot.first is ExecOutSlotInfo
      ){
        outSlot.first.Disconnect();
        outSlot.removeAt(0);
      }
    }else{
      if(
        inSlot.length <= 0 ||
        !(inSlot.first is ExecInSlotInfo)
      ){
        inSlot.insert(0, ExecInSlotInfo(this));
      }
      if(
        outSlot.length <= 0 ||
        !(outSlot.first is ExecOutSlotInfo)
      ){
        outSlot.insert(0, ExecOutSlotInfo(this));
      }
    }

    int base = 0;
    if(!mtd.isConstantMethod) base = 1;

    int tbase = 1;
    if(info.isStaticMethod){
      tbase = 0;
      if(
        inSlot.length > (base) 
      ){
        inSlot[base].Disconnect();
        inSlot.removeAt(base);
      }
    }else{
      if(
        inSlot.length <= (base)
      ){
        inSlot.insert(base, ValueInSlotInfo(this, "target", info.thisType));
      }else{
        var tslot = inSlot[base];
        if(!typeCompat(tslot.type, info.thisType)){
          tslot.Disconnect();
          
        }
        inSlot[base].type = info.thisType;
        inSlot[base].name = "target";
      }
    }

    
    var _ProcSlot = (slot, field, base, compat, T){
      //Discarding all redundant slots
      //Because slot 0 is execution flow input
      //and we want to retain that, so length-1
      for(int i = field.FieldCount(); i < slot.length - base;i++){
        slot.last.DisconnectFromRear();
        slot.removeLast();
      }

      for(int i = 0; i < field.FieldCount(); i++){
        var fieldName = field.GetName(i);
        var fieldType = field.GetFullType(i);
        if(i + base >= slot.length){
          slot.add(T(this, fieldName, fieldType));
          continue;
        }

        var tslot = slot[i+base];
        if(!compat(tslot.type, fieldType)){
          tslot.Disconnect();
        }
        tslot.type = fieldType;
        tslot.name = fieldName;
      }
    };
    var args = mtd.Args();
    var rets = mtd.Rets();
    _ProcSlot(inSlot, args, base + tbase,
      (a,b)=>typeCompat(a,b), 
      (a,b,c)=> ValueInSlotInfo(a,b,c)
    );
    _ProcSlot(outSlot, rets, base,
      (a,b)=>typeCompat(b,a),
      (a,b,c)=>ValueOutSlotInfo(a,b,c, -1)
    );

    //Output index correction
    int retCnt = rets.FieldCount();
    int startIdx = outSlot.length - retCnt;
    for(int i = 0; i < retCnt; i++){
      (outSlot[startIdx + i] as ValueOutSlotInfo).outputOrder = i;
    }
  }

  @override
  NodeTranslationUnit doCreateTC() {
    return TCVMMethod();
  }

  @override
  GraphNode Clone() {
    return GNVMMethod(info, typeCompat);
  }

  @override
  bool get needsExplicitExec => !info.isConstantMethod;

}

class IfNodeTN extends NodeTranslationUnit{
  @override
  int ReportStackUsage()=>0;

  @override
  bool CanHandleEOF()=>false;

  @override
  String? Translate(GraphCompileContext ctx) {
    var node = fromWhichNode as GNIf;
    var condSlot = node.inSlot.last as ValueInSlotInfo;
    var condLink = condSlot.link;
    if(condLink == null) return "Condition input unsatisfied!";
    var rear = condLink.from as ValueOutSlotInfo;
    ctx.AddValueDependency(rear.node, rear.outputOrder);

    var jmpTarget = SimpleCB([]);

    ctx.EmitCode(CodeBuilderCB(
        (line){
          var delta = jmpTarget.startLine - line;
          return[
            InstLine(OpCode.JZI, i:delta)
          ];
        }
      )
    );

    //True branch
    {
      ctx.EnterScope();
      var slot = node.outSlot[0] as ExecOutSlotInfo;
      var link = slot.link;
      //if(link == null){

      //}else{
        ctx.AddNextExec(link?.to.node);        
      //}
      ctx.ExitScope();
      
    }

    ctx.EmitCode(jmpTarget);
    
    //False branch
    {
      ctx.EnterScope();
      var slot = node.outSlot[1] as ExecOutSlotInfo;
      var link = slot.link;
      //if(link == null){

      //}else{
        ctx.AddNextExec(link?.to.node);        
      //}
      ctx.ExitScope();
      
    }
  }
 
}

class GNIf extends GraphNode{
  GNIf(){
    displayName = "If";
    inSlot.add(ExecInSlotInfo(this));
    inSlot.add(ValueInSlotInfo(this, "Condition", "Num|Int"));
    outSlot.add(ExecOutSlotInfo(this, name: "True"));
    outSlot.add(ExecOutSlotInfo(this, name: "False"));
  }

  @override
  GraphNode Clone() {
    return GNIf();
  }

  @override
  NodeTranslationUnit doCreateTC() {
    return IfNodeTN();
  }

  @override
  bool get needsExplicitExec => true;
}

class SeqNodeTU extends SeqTranslationUnit{

  @override
  int get depCnt => 0;

  @override
  int get nodeCnt => (fromWhichNode as GNSeq).seqCnt;

  @override
  int get outputCnt => 0;

  @override
  bool CanHandleEOF() =>true;

  @override
  CodeBlock? HandleEOF(NodeTranslationUnit issued){
    return null;
  }

  @override
  GraphNode? doGetNode(int idx){
    var slot = (fromWhichNode as GNSeq).outSlot[idx] as ExecOutSlotInfo;
    var lnk = slot.link;
    return lnk?.to.node;
  }

}

class GNSeq extends GraphNode with GNPainterMixin{

  int get seqCnt => outSlot.length;

  GNSeq(){
    displayName = "Sequence";
    inSlot.add(ExecInSlotInfo(this));
    outSlot.add(ExecOutSlotInfo(this, name: "1"));
    outSlot.add(ExecOutSlotInfo(this, name: "2"));
    outSlot.add(ExecOutSlotInfo(this, name: "3"));
  }

  void Update(int cnt){
    if(cnt < 1) cnt = 1;

    var delta = cnt - seqCnt;
    if(delta > 0){
      for(int i = 0; i < delta; i++){
        var idx = seqCnt + 1;
        outSlot.add(ExecOutSlotInfo(this, name: "$idx"));
      }
    }else{
      for(int i = 0; i < -delta; i++){
        outSlot.last.Disconnect();
        outSlot.removeLast();
      }
    }

  }

  @override
  Widget Draw(BuildContext ctx, update){
    var defalut = super.Draw(ctx, update);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        defalut,
        Row(children: [
          Expanded(child: TextButton(
            child: Icon(Icons.remove),
            onPressed: (){Update(seqCnt - 1); update();},
          ),),
          Expanded(child: TextButton(
            child: Icon(Icons.add),
            onPressed: (){Update(seqCnt + 1); update();},
          ),)
        ],)
      ],
    );
  }

  @override
  GraphNode Clone() {
    return GNSeq();
  }

  @override
  bool get needsExplicitExec => true;

  @override
  NodeTranslationUnit doCreateTC() {
    return SeqNodeTU();
  }
}


class NodeSearchInfo{
  GraphNode node;
  String cat;
  int position;
  NodeSearchInfo(this.node,this.cat,this.position);
}

class VMTypeHolder{
  String type;
  List<GNVMMethod> methods = [];
  VMTypeHolder(this.type);
}

class GraphNodeLibrary{
  List<VMTypeHolder> vmMethods = [];
  List<GraphNode> miscNodes = [];

  void ReloadVMLibrary(){
    
  }

  GraphNodeLibrary(){
    ReloadVMLibrary();

    miscNodes = [
      GNIf(),
      GNSeq(),
    ];
  }

  

}


NodeSearchInfo? MatchGraphNode(
  GraphNode node,
  String category,
  bool Function(String argType, String retType) typeMatcher,
  String? argType, String? retType
){


  if(argType != null){
    //Check arg types
    for(int i = 0; i < node.inSlot.length; i++){
      if(typeMatcher(argType, node.inSlot[i].type))
      { 
        return (NodeSearchInfo(node, category, i)); 
      }
    }
    return null;
  }

  if(retType != null){
    for(int i = 0; i < node.outSlot.length; i++){
      if(typeMatcher(retType, node.outSlot[i].type))
      { 
        return(NodeSearchInfo(node,category, i)); 
      }
    }
    return null;
  }

  //Simply list all functions
  return (NodeSearchInfo(node,category, -1));
}
