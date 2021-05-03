import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:infcanvas/utilities/scripting/graph_compiler.dart';
import 'package:infcanvas/utilities/scripting/vm_types.dart';
import 'package:infcanvas/widgets/scripting/codepage.dart';
import 'package:infcanvas/widgets/scripting/vm_editor_data.dart';

import '../../utilities/scripting/opcodes.dart';
import '../../utilities/scripting/script_graph.dart';


//////////////////////////////////////////////
// Control flow Nodes
//////////////////////////////////////////////
class IfJmpCB extends CodeBlock{

  CodeBlock target;
  IfJmpCB(this.target);

  @override
  bool NeedsMod()=>true;

  @override
  void ModCode(List<InstLine> code){
    var delta = target.startLine - startLine;
    code[0] = InstLine(OpCode.JZI, i:delta);
  }

  @override
  Iterable<InstLine> EmitCode(int lineCnt) {
    return[InstLine(OpCode.JZI, i:0)];
  }

}

class IfNodeTN extends VMNodeTranslationUnit{
  @override
  int ReportStackUsage()=>0;

  @override
  bool CanHandleEOF()=>false;

  @override
  void Translate(VMGraphCompileContext ctx) {
    var node = fromWhichNode as GNIf;
    var condSlot = node.inSlot.last as ValueInSlotInfo;
    var condLink = condSlot.link;
    if(condLink == null){
      ctx.ReportError("Condition input is emply!");
      return;
    }
    var rear = condLink.from as ValueOutSlotInfo;
    ctx.AddValueDependency(rear.node, rear.outputOrder);

    var jmpTarget = SimpleCB([]);

    ctx.EmitCode(IfJmpCB(jmpTarget));

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
  VMNodeTranslationUnit doCreateTU() {
    return IfNodeTN();
  }

  @override
  bool get needsExplicitExec => true;
}

class SeqNodeTU extends VMNodeTranslationUnit{

  GNSeq get node =>(fromWhichNode as GNSeq);

  int get cnt => node.seqCnt;
  int currCnt = 0;
  bool get isLast => currCnt == cnt-1;
  @override
  bool CanHandleEOF() => !isLast;

  @override
  CodeBlock? HandleEOF(VMNodeTranslationUnit issued){
    return null;
  }

  
  GraphNode? doGetNode(int idx){
    var slot = (fromWhichNode as GNSeq).outSlot[idx] as ExecOutSlotInfo;
    var lnk = slot.link;
    return lnk?.to.node;
  }

  @override
  int ReportStackUsage() => 0;

  @override
  void Translate(VMGraphCompileContext ctx) {
    while(currCnt < cnt){
      ctx.EnterScope();
      ctx.AddNextExec(doGetNode(currCnt));
      ctx.ExitScope();
      currCnt++;
    }
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
  VMNodeTranslationUnit doCreateTU() {
    return SeqNodeTU();
  }
}

//////////////////////////////////////////////
// Code structure Nodes
//////////////////////////////////////////////

class FnEntryCB extends CodeBlock{
  @override
  Iterable<InstLine> EmitCode(int lineCnt) {
    var unit = fromWhichUnit as FnEntryTC;
    bool cached = unit.isCached;

    var outputCnt = (fromWhichUnit as FnEntryTC).outputCnt;
    if(!cached){
      return[
        for(int i = 0; i < outputCnt; i++)
          InstLine(OpCode.ldarg, i:i),
      ];
    }else{
      int slot = unit.cached!.slot;
      var res = <InstLine>[];
      for(int i = 0; i < outputCnt; i++){
        res.add(InstLine(OpCode.ldarg, i:i));
        res.add(InstLine(OpCode.starg, i:slot+i));
      }

      return res;
    }
  }

}

class FnEntryTC extends VMNodeTranslationUnit{

  FnEntryNode get entry => fromWhichNode as FnEntryNode;

  @override
  GraphNode? doGetNode(int idx){
    var execSlot = entry.outSlot.first as ExecOutSlotInfo;
    if(execSlot.link == null) return null;
    var tgtSlot = execSlot.link!.to;
    return tgtSlot.node;
  }

  int get outputCnt => ReportStackUsage();

  CodeBlock doEmitCode(){
    return FnEntryCB();
  }

  @override
  CacheHandle doCreateCacheHandle() {
    return CacheHandle(outputCnt);
  }
 

  @override
  int get nodeCnt => entry.md.mtd.isConstantMethod? 0:1;

  @override
  int ReportStackUsage() {
    return entry.md.mtd.Args().FieldCount();
  }

  @override
  void Translate(VMGraphCompileContext ctx) {
    ctx.EmitCode(doEmitCode());

    if(!entry.md.mtd.isConstantMethod){
      var execSlot = fromWhichNode.outSlot.first as ExecOutSlotInfo;
      var execLink = execSlot.link;
      //if(execLink == null)return null;
      //var rear = execLink.to;
      ctx.AddNextExec(execLink?.to.node);
    }
  }

}

class FnEntryNode extends GraphNode with GNPainterMixin implements EnvNode {
  EditorMethodData md;

  @override bool get closable => false;

  late ExecOutSlotInfo execOut = ExecOutSlotInfo(this,name:"Start");
  List<ValueOutSlotInfo> _fnArgSlots = [];

  @override bool get needsExplicitExec => !md.mtd.isConstantMethod;

  @override
  List<OutSlotInfo> get outSlot =>
  needsExplicitExec? <OutSlotInfo>[execOut] + _fnArgSlots
  :_fnArgSlots;

  FnEntryNode(this.md){
    displayName = "Entry";
    Update();
  }

  @override GraphNode Clone() => FnEntryNode(this.md);
  @override VMNodeTranslationUnit doCreateTU() => FnEntryTC();

  void Update(){
    if(!needsExplicitExec){
      execOut.Disconnect();
    }
    
    var args = md.mtd.Args();
    //Discarding all redundant slots
    //Because slot 0 is execution flow output
    //and we want to retain that, so length-1
    for(int i = args.FieldCount(); i < _fnArgSlots.length;i++){
      _fnArgSlots.last.DisconnectFromRear();
      _fnArgSlots.removeLast();
    }

    for(int i = 0; i < args.FieldCount(); i++){
      var fieldName = args.GetName(i);
      var fieldType = args.GetFullType(i);
      if(i >= _fnArgSlots.length){
        _fnArgSlots.add(ValueOutSlotInfo(this, fieldName, fieldType, i));
        continue;
      }

      var slot = _fnArgSlots[i];
      if(!md.IsSubTypeOf(fieldType, slot.type)){
        slot.Disconnect();
      }
      slot.type = fieldType;
      slot.name = fieldName;

    }
  }

  @override
  bool Validate(VMEnv env) {
    Update();
    return true;
  }

}

class FnRetCB extends CodeBlock{
  @override
  Iterable<InstLine> EmitCode(int lineCnt) {
    var inputCnt = (fromWhichUnit as FnRetTC).inputCnt;
    return[
      for(int i = 0; i < inputCnt; i++)
        InstLine(OpCode.starg, i:i),
      InstLine(OpCode.RET)
    ];
  }

  @override
  String toString()=>"<-Return";
}

class FnRetTC extends VMNodeTranslationUnit{

  FnRetNode get exit => fromWhichNode as FnRetNode;

  int get inputCnt => exit.md.mtd.Rets().FieldCount();


  @override
  CacheHandle doCreateCacheHandle() {
    //No cache should be made from a return node
    throw UnimplementedError();
  }

  CodeBlock doEmitCode(){
    return FnRetCB();
  }

  ValueDependency? doGetValDep(int idx) {
    int base = exit.md.mtd.isConstantMethod? 0:1;
    var inSlot = fromWhichNode.inSlot[base + idx] as ValueInSlotInfo;
    var link = inSlot.link;
    if(link == null) return null;
    var rear = link.from as ValueOutSlotInfo;
    return ValueDependency(rear.node, rear.outputOrder); 
  }

  @override
  int ReportStackUsage() => 0;

  @override
  void Translate(VMGraphCompileContext ctx) {
    for(int i = inputCnt - 1;i>=0;i--){
      var dep = doGetValDep(i);
      if(dep == null)
      { 
        ctx.ReportError("Return value input not satisfied!");
        return;
      }
      ctx.AddValueDependency(dep.fromWhich, dep.idx);
    }

    ctx.EmitCode(doEmitCode());
  }


}

class FnRetNode extends EnvNode with GNPainterMixin{

  EditorMethodData md;

  @override bool get needsExplicitExec => !md.mtd.isConstantMethod;
  @override bool get closable => needsExplicitExec;

  FnRetNode(this.md){
    displayName = "Return";
    Update();
  }

  late ExecInSlotInfo execIn = ExecInSlotInfo(this,name:"End");

  List<ValueInSlotInfo> fnRetSlots = [];

  @override
  List<InSlotInfo> get inSlot =>
  needsExplicitExec? <InSlotInfo>[execIn] + fnRetSlots
  :fnRetSlots;

  @override GraphNode Clone() => FnRetNode(md);
  @override VMNodeTranslationUnit doCreateTU() => FnRetTC();

  void Update(){
    
    var mtd = md.mtd;
    if(!needsExplicitExec){
      execIn.Disconnect();
    }

    var rets = mtd.Rets();
    //Discarding all redundant slots
    //Because slot 0 is execution flow input
    //and we want to retain that, so length-1
    for(int i = rets.FieldCount(); i < fnRetSlots.length;i++){
      fnRetSlots.last.DisconnectFromRear();
      fnRetSlots.removeLast();
    }

    for(int i = 0; i < rets.FieldCount(); i++){
      var fieldName = rets.GetName(i);
      var fieldType = rets.GetFullType(i);
      if(i >= fnRetSlots.length){
        fnRetSlots.add(ValueInSlotInfo(this, fieldName, fieldType));
        continue;
      }

      var slot = fnRetSlots[i];
      if(!md.IsSubTypeOf(slot.type, fieldType)){
        slot.Disconnect();
      }
      slot.type = fieldType;
      slot.name = fieldName;
    }
  }

  @override
  bool Validate(VMEnv env) {
    Update();
    return true;
  }
}

class FnThisNode extends GNImplicitOp{

  String thisType;

  FnThisNode(this.thisType){
    displayName = "This object";
    outSlot.add(ValueOutSlotInfo(this, "this", thisType, 0));
  }

  void Update(String thisType){
    this.thisType = thisType;
    outSlot.first.type = thisType;
  }

  @override GraphNode Clone() => FnThisNode(thisType);
  @override List<InstLine> get instructions => [
    InstLine(OpCode.ldthis)
  ];
}

class TCVMMethod extends SeqTranslationUnit{
  
  VMMethodInfo get mtd => (fromWhichNode as GNVMMethod).info;
  GNVMMethod get mtdNode => fromWhichNode as GNVMMethod;

  @override
  int get depCnt => mtd.Args().FieldCount() + (mtd.isStaticMethod?0:1);

  @override
  int get nodeCnt => mtd.isConstantMethod?0:1;

  @override
  int get outputCnt => mtd.Rets().FieldCount();


  @override
  GraphNode? doGetNode(int idx){
    
    var slot = mtdNode.execOut;
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

    //Requesting "this" pointer
    if(!mtd.isStaticMethod && idx == depCnt - 1){
      var slot = mtdNode.targetIn;
      return _DepFromSlot(slot);
    }

    var slot = mtdNode.argSlots[idx];
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

class GNVMMethod extends EnvNode{

  String get cls => info.thisType;
  VMMethodInfo info;

  late ExecInSlotInfo execIn = ExecInSlotInfo(this);
  late ValueInSlotInfo targetIn 
    = ValueInSlotInfo(this, "target", info.thisType);
  late ExecOutSlotInfo execOut = ExecOutSlotInfo(this);

  List<ValueInSlotInfo> argSlots = [];
  List<ValueOutSlotInfo> retSlots = [];

  @override List<InSlotInfo> get inSlot =>
  <InSlotInfo>[
    if(needsExplicitExec) execIn,
    if(!info.isStaticMethod) targetIn,
  ] + argSlots;


  @override List<OutSlotInfo> get outSlot =>
  <OutSlotInfo>[
    if(needsExplicitExec) execOut,
  ] + retSlots;

  GNVMMethod(this.info){
    argSlots = [
      for(var f in info.Args().fields)
        ValueInSlotInfo(this, f.name, f.type),
    ];

    var ret = info.Rets();
    retSlots = [
      for(int i = 0; i <ret.FieldCount(); i++)
        ValueOutSlotInfo(this, ret.GetName(i), ret.GetType(i), i),
    ];
  }

  @override VMNodeTranslationUnit doCreateTU() => TCVMMethod();
  @override GraphNode Clone() => GNVMMethod(info);

  @override bool get needsExplicitExec => !info.isConstantMethod;

  void _ProcessField(field, slots, typeCompat, newSlot){
    int cnt = field.FieldCount();

    for(int i = cnt; i < slots.length;i++){
      slots.last.Disconnect();
      slots.removeLast();
    }

    for(int i = 0; i < cnt; i++){
      var newName = field.GetName(i);
      var newType = field.GetFullType(i);
      if(i >= slots.length){
        slots.add(newSlot(this, newName, newType, i));
      }else{
        var slot = slots[i];
        var oldType = slot.type;
        if(!typeCompat(oldType, newType)){
          slot.Disconnect();
        }
        slot.type = newType;
        slot.name = newName;
      }
    }
  }

  void _ProcessArgField(VMEnv env){
    _ProcessField(info.Args(), argSlots,
      (oldTy, newTy){
        return env.IsSubTypeOf(oldTy, newTy);
      },
      (node, name, ty, idx){
        return ValueInSlotInfo(node, name, ty);
      }
    );
  }

  void _ProcessRetField(VMEnv env){
    _ProcessField(info.Rets(), retSlots,
      (oldTy, newTy){
        return env.IsSubTypeOf(newTy, oldTy);
      },
      (node, name, ty, idx){
        return ValueOutSlotInfo(node, name, ty, idx);
      }
    );
  }

  @override
  bool Validate(VMEnv env) {
    if(!info.IsValid()) return false;
    if(!needsExplicitExec){
      execIn.Disconnect();
      execOut.Disconnect();
    }

    if(info.isStaticMethod){
      targetIn.Disconnect();
    }

    _ProcessArgField(env);
    _ProcessRetField(env);

    return true;
  }

}


//////////////////////////////////////////////
// Node searching
//////////////////////////////////////////////

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
      if(typeMatcher(node.outSlot[i].type, retType))
      { 
        return(NodeSearchInfo(node,category, i)); 
      }
    }
    return null;
  }

  //Simply list all functions
  return (NodeSearchInfo(node,category, -1));
}
