
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:infcanvas/utilities/scripting/graph_compiler.dart';
import 'package:infcanvas/utilities/scripting/graphnodes.dart';
import 'package:infcanvas/utilities/scripting/opcodes.dart';
import 'package:infcanvas/utilities/scripting/script_graph.dart';
import 'package:infcanvas/utilities/scripting/vm_types.dart';
import 'package:infcanvas/widgets/functional/anchor_stack.dart';
import 'package:infcanvas/widgets/functional/floating.dart';

import 'fgpage.dart';
import 'class_inspector.dart';

class FnEntryCB extends CodeBlock{
  @override
  Iterable<InstLine> EmitCode(int lineCnt) {
    var outputCnt = (fromWhichUnit as FnEntryTC).outputCnt;
    return[
      for(int i = 0; i < outputCnt; i++)
        InstLine(OpCode.ldarg, i:i),
    ];
  }

}

class FnEntryTC extends NodeTranslationUnit{

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
  String? Translate(GraphCompileContext ctx) {
    ctx.EmitCode(doEmitCode());

    if(!entry.md.mtd.isConstantMethod){
      var execSlot = fromWhichNode.outSlot.first as ExecOutSlotInfo;
      var execLink = execSlot.link;
      if(execLink == null)return null;
      var rear = execLink.to;
      ctx.AddNextExec(rear.node);
    }
  }

}

class FnEntryNode extends GraphNode with GNPainterMixin {
  EditorMethodData md;

  @override
  bool get closable => false;

  FnEntryNode(this.md){
    displayName = "Entry";
    Update(md);
  }

  @override
  GraphNode Clone() {
    return FnEntryNode(this.md);
  }

  @override
  NodeTranslationUnit doCreateTC() {
    return FnEntryTC();
  }

  void Update(EditorMethodData md){
    this.md = md;
    var mtd = md.mtd;
    if(mtd.isConstantMethod){
      if(
        outSlot.length > 0 &&
        outSlot.first is ExecOutSlotInfo
      ){
        outSlot.first.Disconnect();
        outSlot.removeAt(0);
      }
    }else{
      if(
        outSlot.length <= 0 ||
        !(outSlot.first is ExecOutSlotInfo)
      ){
        outSlot.insert(0, ExecOutSlotInfo(this, name:"Start"));
      }
    }


    int base = 0;
    if(!mtd.isConstantMethod) base = 1;


    var args = mtd.Args();
    //Discarding all redundant slots
    //Because slot 0 is execution flow output
    //and we want to retain that, so length-1
    for(int i = args.FieldCount(); i < outSlot.length - base;i++){
      outSlot.last.DisconnectFromRear();
      outSlot.removeLast();
    }

    for(int i = 0; i < args.FieldCount(); i++){
      var fieldName = args.GetName(i);
      var fieldType = args.GetFullType(i);
      if(i + base >= outSlot.length){
        outSlot.add(ValueOutSlotInfo(this, fieldName, fieldType, i+base));
        continue;
      }

      var slot = outSlot[i+base];
      if(!md.IsSubTypeOf(fieldType, slot.type)){
        slot.Disconnect();
      }
      slot.type = fieldType;
      slot.name = fieldName;

    }
  }

  @override
  bool get needsExplicitExec => !md.mtd.isConstantMethod;

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

class FnRetTC extends NodeTranslationUnit{

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
  String? Translate(GraphCompileContext ctx) {
    for(int i = inputCnt - 1;i>=0;i--){
      var dep = doGetValDep(i);
      if(dep == null) return "Return value input not satisfied!";
      ctx.AddValueDependency(dep.fromWhich, dep.idx);
    }

    ctx.EmitCode(doEmitCode());
  }


}

class FnRetNode extends GraphNode{

  EditorMethodData md;

  FnRetNode(this.md){
    displayName = "Return";
    
    Update(md);
  }

  @override
  GraphNode Clone() {
    return FnRetNode(md);
  }

  @override
  NodeTranslationUnit doCreateTC() {
    return FnRetTC();
  }

  void Update(EditorMethodData md){
    
    this.md = md;
    var mtd = md.mtd;
    if(mtd.isConstantMethod){
      if(
        inSlot.length > 0 &&
        inSlot.first is ExecInSlotInfo
      ){
        inSlot.first.Disconnect();
        inSlot.removeAt(0);
      }
    }else{
      if(
        inSlot.length <= 0 ||
        !(inSlot.first is ExecInSlotInfo)
      ){
        inSlot.insert(0, ExecInSlotInfo(this, name:"End"));
      }
    }

    this.md = md;

    int base = 0;
    if(!mtd.isConstantMethod) base = 1;

    var rets = mtd.Rets();
    //Discarding all redundant slots
    //Because slot 0 is execution flow input
    //and we want to retain that, so length-1
    for(int i = rets.FieldCount(); i < inSlot.length - base;i++){
      inSlot.last.DisconnectFromRear();
      inSlot.removeLast();
    }

    for(int i = 0; i < rets.FieldCount(); i++){
      var fieldName = rets.GetName(i);
      var fieldType = rets.GetFullType(i);
      if(i + base >= inSlot.length){
        inSlot.add(ValueInSlotInfo(this, fieldName, fieldType));
        continue;
      }

      var slot = inSlot[i+base];
      if(!md.IsSubTypeOf(slot.type, fieldType)){
        slot.Disconnect();
      }
      slot.type = fieldType;
      slot.name = fieldName;
    }
  }

  @override
  bool get needsExplicitExec => !md.mtd.isConstantMethod;

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

  @override
  GraphNode Clone() {
    return FnThisNode(thisType);
  }

  @override
  // TODO: implement instructions
  List<InstLine> get instructions => [
    InstLine(OpCode.ldthis)
  ];


}

class EditorMethodData extends CodeData{
  EditorClassData classData;
  int mtdIdx;

  late NodeHolder entryNode = NodeHolder(FnEntryNode(this))
    ..ctrl.dx = 50
    ..ctrl.dy = 50
    ;
  List<NodeHolder> _nodes = [];

  NodeHolder? entry;

  void UpdateNodes(){

    CheckThisPointer();
    //CheckExecType();
    CheckEnvNode();
    CheckAccessors();
    CheckMethodCalls();

    //Check rets
    if(!mtd.isConstantMethod){
      _nodes.removeWhere(
        (element){
          if(element.info is FnEntryNode){
            element.info.RemoveLinks();
            return true;
          }
          return false;
        }
      );
      if(entry == null)
        entry = NodeHolder(FnEntryNode(this));
      else if(!(entry!.info is FnEntryNode)){
        entry!.info.RemoveLinks();
        var ctrl = entry!.ctrl;
        entry = NodeHolder(FnEntryNode(this))..ctrl = ctrl;
      }else{
        (entry!.info as FnEntryNode).Update(this);
      }
    }else{
      _nodes.removeWhere(
        (element){
          if(element.info is FnRetNode){
            element.info.RemoveLinks();
            return true;
          }
          return false;
        }
      );

      if(entry == null)
        entry = NodeHolder(FnRetNode(this));
      else if(!(entry!.info is FnRetNode)){
        entry!.info.RemoveLinks();
        var ctrl = entry!.ctrl;
        entry = NodeHolder(FnRetNode(this))..ctrl = ctrl;
      }else{
        (entry!.info as FnRetNode).Update(this);
      }      

    }
  }

  void CheckEnvNode(){
    _nodes.removeWhere((element){
      var n = element.info;
      if(!(n is EnvNode))return false;
      bool isValid = n.Validate(classData.lib.env);
      if(!isValid){
        n.RemoveLinks();
      }
      return !isValid;
    });
  }

  void CheckMethodCalls(){
    _nodes.removeWhere(
      (element){
        var node = element.info;
        if(node is GNVMMethod){
          var n = (node as GNVMMethod).info;
          if(n.IsValid()){
            (node as GNVMMethod).Update();
          }else{
            node.RemoveLinks();
            return true;
          }
        }

        return false;
      }
    );
  }

  void CheckExecType(){
    if(mtd.isConstantMethod){
      _nodes.removeWhere(
        (element) {
          if(element.info.needsExplicitExec){
            element.info.RemoveLinks();
            return true;
          }
          return false;
        }
      );
    }
  }

  void CheckThisPointer(){
    bool allowThisPointer = !mtd.isStaticMethod;
    if(!allowThisPointer)
      _nodes.removeWhere((element){
        if(!(element.info is FnThisNode)) return false;
        element.info.RemoveLinks();
        return true;
      });
    else{
      for(var n in _nodes){
        if(!(n.info is FnThisNode)) continue;

        var tn = n.info as FnThisNode;
        tn.Update(mtd.thisType);
      }
    }
  }

  void CheckAccessors(){
    _nodes.removeWhere((element){
      var node = element.info;
      if((node is GetterNode) || (node is SetterNode) ){
        dynamic dn = node;
        String f = dn.fieldName;
        String ty = dn.thisType;
        bool fromStatic = dn.fromStatic;

        var fields = fromStatic?
        classData.lib.env.StaticFields(ty):
        classData.lib.env.Fields(ty);
        for(var field in fields){
          if(field.name == f){
            dn.fieldType = field.type;
            return false;
          }
        }
        node.RemoveLinks();
        return true;
      }
      return false;
    });
  }


  @override
  List<NodeHolder> GetNodes() {return [entry!] + _nodes;}

  @override
  void RemoveNode(NodeHolder n) {_nodes.remove(n);}

  @override
  void AddNode(NodeHolder n) {_nodes.add(n);}


  
  EditorMethodData(this.classData, this.mtdIdx){

  }

  void NotifyChange(){
    classData.NotifyMethodChange(mtdIdx);
  }

  VMMethodInfo get mtd => classData.cls.GetMethodInfo(mtdIdx);

  @override
  Iterable<NodeSearchInfo> FindMatchingNode(String? argType, String? retType)sync* {
    yield* classData.FindMatchingNode(argType, retType);

    //This pointer
    if(!mtd.isStaticMethod){
      var node = FnThisNode(mtd.thisType);
      var result = MatchGraphNode(node, "", IsSubTypeOf, argType, retType);
      if(result != null)
        yield result;
    }

    //Add return nodes
    if(!mtd.isConstantMethod){
    
      if(argType == null && retType == null){
        var retNode = FnRetNode(this);
        yield (NodeSearchInfo(retNode, "", -1));
      }
      else if(argType != null){
        var retNode = FnRetNode(this);

        for(int i = 0; i < retNode.inSlot.length; i++){

          if(IsSubTypeOf(argType, retNode.inSlot[i].type)){
            yield (NodeSearchInfo(retNode, "", i));
            break;
          }
        }
      }
    }else{
      if(argType == null && retType == null){
        var entryNode = FnEntryNode(this);
        yield (NodeSearchInfo(entryNode, "", -1));
      }
      else if(retType != null){
        var entryNode = FnEntryNode(this);

        for(int i = 0; i < entryNode.outSlot.length; i++){

          if(IsSubTypeOf(entryNode.outSlot[i].type, retType)){
            yield (NodeSearchInfo(entryNode, "", i));
            break;
          }
        }
      }
    }

  }

  @override
  bool IsSubTypeOf(String type, String base) {
    return classData.lib.env.IsSubTypeOf(type, base);
  }

  @override
  NodeStatus ValidateNode(GraphNode node) {
    if(node is FnEntryNode){
      node.Update(this);
    }

    if(node is FnRetNode){
      (node).Update(this);
    }

    return NodeStatus();
  }

  // TODO: implement nodes

  //TODO: Implement node lookup library
  //Entry node:
  //  Not instantiatable, not destructable
  //  The first node of an empty method
  //Return node:
  //  Instantiatable, destructable
  //  
}

class MethodEditor extends StatefulWidget {

  EditorMethodData meta;

  void Function(EditorMethodData)? onChange;

  MethodEditor(this.meta, {this.onChange}){
    meta.UpdateNodes();
  }

  @override
  _MethodEditorState createState() => _MethodEditorState();
}

class _MethodEditorState extends State<MethodEditor> {

  void CompileMethod(){
    var m = widget.meta;
    var root = m.entry!.info;
    Graph g = Graph()
      ..argCnt = m.mtd.Args().FieldCount()
      ..retCnt = m.mtd.Rets().FieldCount()
      ..entry = root
      ;

    var compiler = GraphCompiler(g);
  }


  @override
  Widget build(BuildContext context) {
    return FloatingWindowPanel(
      children:[
        AnchoredPosition.fill(child: CodePage(widget.meta)),

        FloatingWindow(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              
            ],
          ),
        ),

        FloatingWindow(
          anchor: Rect.fromLTRB(1,0,1,0),
          align: Offset(1,0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              PopupBuilder<EditorMethodData>(
                data: widget.meta,
                contentBuilder: (open){
                  return ElevatedButton(
                    child: Text('Edit Return'),
                    onPressed: open
                  );
                }, 
                popupBuilder: (close){
                  return _BuildRetInspector();
                },
                updateShouldClose: (old){
                  return old.data != widget.meta;
                },
              ),

              PopupBuilder<EditorMethodData>(
                data: widget.meta,
                contentBuilder: (open){
                  return ElevatedButton(
                    child: Text('Edit Arguments'),
                    onPressed: open
                  );
                }, 
                popupBuilder: (close){
                  return _BuildArgInspector();
                },
                updateShouldClose: (old){
                  return old.data != widget.meta;
                },
              ),
              ElevatedButton(
                child: Text('Compile'),
                onPressed: (){
                  CompileMethod();
                }
              ),
            ],
          ),
        )
      ]
    );
  }

  Widget _BuildArgInspector(){
    return SizedBox(
      width: 300,
      child: FieldInspector(
        widget.meta.mtd.Args(),
        name: "Arguments",
        onChange: (f,i){
          widget.onChange?.call(widget.meta);
        },
      ),
    );
  }

  
  Widget _BuildRetInspector(){
    return SizedBox(
      width: 300,
      child: FieldInspector(
        widget.meta.mtd.Rets(),
        name: "Return Values",
        onChange: (f,i){
          widget.onChange?.call(widget.meta);
        },
      ),
    );
  }
}
