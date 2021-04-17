import 'package:infcanvas/utilities/scripting/graph_compiler.dart';

///The representation of scripts
///
///

import 'opcodes.dart';
import 'package:infcanvas/widgets/functional/anchor_stack.dart';

class GraphEdge{
  InSlotInfo to;
  OutSlotInfo from;
  GraphEdge(this.from, this.to);

  void Remove(){
    from.DisconnectLink(this);
    to.DisconnectLink(this);
  }
}

///Graph node
abstract class SlotInfo{
  GraphNode node;
  GeometryTrackHandle gHandle = GeometryTrackHandle();
  String name;
  String type = "";
  SlotInfo(this.node, this.name);

  bool IsLinked();

  void DisconnectFromRear();

  void DisconnectLink(GraphEdge link);

  void Disconnect();

  void ConnectLink(GraphEdge link);

  void ConcatSlot(covariant SlotInfo slot);

  SlotInfo GenerateLink(GraphNode node, String name);
}

abstract class OutSlotInfo extends SlotInfo{
  OutSlotInfo(GraphNode node, String name):super(node, name);
}
abstract class InSlotInfo extends SlotInfo{
  InSlotInfo(GraphNode node, String name):super(node, name);
}

mixin SingleConnSlotMixin on SlotInfo{
  GraphEdge? link;

  @override
  void DisconnectLink(GraphEdge link){
    if(this.link == link) this.link = null;
  }

  
  @override
  void ConnectLink(GraphEdge link){
    DisconnectFromRear();
    this.link = link;
    if(this is OutSlotInfo)
    {
      link.from = this as OutSlotInfo;
    }
    else{
      link.to = this as InSlotInfo;
    }
  }

  @override
  void ConcatSlot(SingleConnSlotMixin slot){
    ReplaceConnWith(slot);
  }

  void ReplaceConnWith(SingleConnSlotMixin slot){
    //Disconnect
    DisconnectFromRear();
    
    link = slot.link;
    slot.link = null;
    //Mend connection
    if(link!=null){
      if(this is OutSlotInfo){
        assert(slot is OutSlotInfo);
        link!.from = this as OutSlotInfo;
      }else{
        assert(slot is InSlotInfo);
        link!.to = this as InSlotInfo;
      }
    }
  }

  @override
  bool IsLinked() {
    return link != null;
  }

  @override
  void DisconnectFromRear() {
    if(link == null) return;
    if(this is OutSlotInfo){
      link!.to.DisconnectLink(link!);
    }else{
      link!.from.DisconnectLink(link!);
    }
  }

  @override
  void Disconnect(){
    DisconnectFromRear();
    link = null;
  }
}


mixin MultiConnSlotMixin on SlotInfo{
  List<GraphEdge> links = [];

  @override
  void DisconnectLink(GraphEdge link){
    links.remove(link);
  }

  @override
  void ConnectLink(GraphEdge link){
    this.links.add(link);
    if(this is OutSlotInfo)
    {
      link.from = this as OutSlotInfo;
    }
    else{
      link.to = this as InSlotInfo;
    }
  }

  @override 
  void ConcatSlot(MultiConnSlotMixin slot){
    AddMultipleConn(slot);
  }

  void AddConn(SingleConnSlotMixin slot){
    //Disconnect
    if(slot.link == null) return;

    if(this is OutSlotInfo){
      assert(slot is OutSlotInfo);
      links.add(slot.link!);
      links.last.from = this as OutSlotInfo;
    }else{
      assert(slot is InSlotInfo);
      links.add(slot.link!);
      links.last.to = this as InSlotInfo;
    }
    
  }

  void AddMultipleConn(MultiConnSlotMixin slot){
    if(this is OutSlotInfo){
      assert(slot is OutSlotInfo);
      for(var link in slot.links){
        links.add(link);
        links.last.from = this as OutSlotInfo;
      }
    }else{
      assert(slot is InSlotInfo);
      for(var link in slot.links){
        links.add(link);
        links.last.to = this as InSlotInfo;
      }
    }
  }

  @override
  bool IsLinked() {
    return links.isNotEmpty;
  }

  @override
  void DisconnectFromRear() {
    if(this is OutSlotInfo){
      for(var l in links){
        l.to.DisconnectLink(l);
      }
    }else{
      for(var l in links){
        l.from.DisconnectLink(l);
      }
    }
  }

  @override 
  void Disconnect(){
    DisconnectFromRear();
    links.clear();
  }
}

class ValueInSlotInfo extends InSlotInfo with SingleConnSlotMixin{
  ValueInSlotInfo(GraphNode node, String name, String type)
    :super(node, name){
    assert(type!="");
    this.type = type;
  }

  @override
  SlotInfo GenerateLink(GraphNode node, String name) {
    ValueOutSlotInfo compSlot = ValueOutSlotInfo(node, name, type, -1);
    GraphEdge edge = GraphEdge(compSlot, this);
    Disconnect();
    this.link = edge;
    compSlot.links.add(edge);
    return compSlot;
  }
}

class ValueOutSlotInfo extends OutSlotInfo with MultiConnSlotMixin{

  late int outputOrder;

  ValueOutSlotInfo(GraphNode node, String name, String type, this.outputOrder)
    :super(node, name){
    assert(type!="");
    this.type = type;
  }

  @override
  SlotInfo GenerateLink(GraphNode node, String name) {
    ValueInSlotInfo compSlot = ValueInSlotInfo(node, name, type);
    GraphEdge edge = GraphEdge(this, compSlot);
    compSlot.link = edge;
    this.links.add(edge);
    return compSlot;
  }
}


class ExecInSlotInfo extends InSlotInfo with MultiConnSlotMixin{
  ExecInSlotInfo(GraphNode node,{String name = "Exec"}):super(node, name);

  @override
  SlotInfo GenerateLink(GraphNode node, String name) {
    ExecOutSlotInfo compSlot = ExecOutSlotInfo(node, name:name);
    GraphEdge edge = GraphEdge(compSlot, this);
    compSlot.link = edge;
    this.links.add(edge);
    return compSlot;
  }
}

class ExecOutSlotInfo extends OutSlotInfo with SingleConnSlotMixin{
  ExecOutSlotInfo(GraphNode node, {String name = "Then"}):super(node, name);

  @override
  SlotInfo GenerateLink(GraphNode node, String name) {
    ExecInSlotInfo compSlot = ExecInSlotInfo(node, name:name);
    GraphEdge edge = GraphEdge(this, compSlot);
    Disconnect();
    this.link = edge;
    compSlot.links.add(edge);
    return compSlot;
  }
}

abstract class GraphNode{
  String displayName = "???";
  final List<InSlotInfo> inSlot = [];
  final List<OutSlotInfo> outSlot = [];
  
  ///Like getter and setter nodes
  bool get needsExplicitExec;


  void RemoveLinks(){
    for(var s in inSlot) s.Disconnect();
    for(var s in outSlot) s.Disconnect();
  }

  NodeTranslationUnit CreateTranslationUnit(){
    var tc = doCreateTC();
    tc.fromWhichNode = this;
    return tc;
  }

  NodeTranslationUnit doCreateTC();
  
  GraphNode Clone();
}

class ValueDependency{
  GraphNode fromWhich;
  int idx;
  ValueDependency(this.fromWhich, this.idx);
}


class SimpleCB extends CodeBlock{

  List<InstLine> code;

  SimpleCB(this.code){}

  @override
  List<InstLine> EmitCode(int lineCnt) {
    return code;
  }

}

class CodeBuilderCB extends CodeBlock{

  Iterable<InstLine> Function(int) builder;

  CodeBuilderCB(this.builder);

  @override
  Iterable<InstLine> EmitCode(int lineCnt) {
    return builder(lineCnt);
  }

}



enum TranslationStage{
  ///There are nodes need to be translated first
  NeedsExecNode,
  ///There are values needed from other nodes
  NeedsValueInput,
  ///There is code to be executed.
  NeedsEmitCode,
  ///Translation is done for this node
  Done,
}
/*
abstract class GNTranslationCell{
  String debugInfo = '';
  CacheHandle? cacheHandle;
  late GraphNode fromWichNode;

  TranslationStage NextStage();
  bool get handleEOF => false;

  CacheHandle CreateOrGetResultCacheHandle(){
    if(cacheHandle!= null) return cacheHandle!;
    var ch = doCreateCacheHandle();
    ch.unitToCache = this;
    cacheHandle = ch;
    return ch;
  }
  GraphNode? GiveNextNode();

  ValueDependency? GiveNextDep();

  CodeBlock Emit(){
    var cb = doCreateCodeBlock();
    cb.translationCell = this;
    cb.debugInfo += debugInfo;
    return cb;
  }

  CodeBlock? HandleEOF(GNTranslationCell which)=>null;

  bool CanHandleEOF()=>false;

  CodeBlock doCreateCodeBlock();
  CacheHandle doCreateCacheHandle();
}


class Graph{
  GraphNode root;

  List<GraphNode> nodes = [];
  List<GraphEdge> edges = [];

  Graph(this.root);
}*/

///The graph node types
///builtin arithmetic
///    binary: + - * / << >> < == > <= >= !=
///    unary:  - ! ~ ++ --
///    ternary: ?:
///control flow
///    if
///accessor
///    get, set
///functions
///    explicit, implicit

class SeqOutputHanderCB extends CodeBlock{
  @override
  Iterable<InstLine> EmitCode(int lineCnt) sync*{
    var seqUnit = fromWhichUnit as SeqTranslationUnit;
    bool isCached = seqUnit.isCached;
    int outputCnt = seqUnit.ReportStackUsage();
    if(outputCnt <= 0) return;

    if(isCached){
      var handle = fromWhichUnit.cached!;
      int slot = handle.slot;

      for(int i = outputCnt - 1; i >= 0 ;i--){
        yield InstLine(OpCode.starg, i:slot + i);
      }
    }
    else{
      yield InstLine(OpCode.POPI, i:outputCnt);
    }

  }

}

abstract class SeqTranslationUnit extends NodeTranslationUnit{
  
  int get depCnt;
  int get nodeCnt;
  int get outputCnt;

  @override
  int ReportStackUsage() => outputCnt;

  @override
  String? Translate(GraphCompileContext ctx){
    for(int i =0;i<depCnt;i++){
      var dep = doGetValDep(i);
      if(dep != null)
        ctx.AddValueDependency(dep.fromWhich, dep.idx);
      else
        return "Input not satisfied!";
    }

    for(int i =0;i<nodeCnt;i++){
      var n = doGetNode(i);

      //The last execution sequence must handle return!
      if(i == nodeCnt - 1 || n != null)
        ctx.AddNextExec(n);
    }

    var c = doEmitCode();
    if(c != null)
      ctx.EmitCode(c);

    //Output cleanup, only for explicit nodes
    if(
      fromWhichNode.needsExplicitExec
      && outputCnt > 0
    )
      ctx.EmitCode(SeqOutputHanderCB());
  }

  
  GraphNode? doGetNode(int idx)=>null;
  ValueDependency? doGetValDep(int idx)=>null;
  CodeBlock? doEmitCode()=>null;


  @override
  CacheHandle doCreateCacheHandle() {
    return CacheHandle(outputCnt);
  }
}


abstract class GNOp extends GraphNode{

}

class ImplicitTC extends SeqTranslationUnit{

  List<InstLine> instructions;

  ImplicitTC(this.instructions);

  @override
  int get depCnt => fromWhichNode.inSlot.length;

  @override
  bool CanHandleEOF() => false;

  @override
  int get nodeCnt => 0;

  @override
  int get outputCnt => fromWhichNode.outSlot.length;

  @override
  CodeBlock doEmitCode() {
    return SimpleCB(instructions);
  }

  @override
  GraphNode? doGetNode(int idx) {
    assert(false,"Implicit node shouldn't run other nodes");
    throw UnimplementedError();
  }

  @override
  ValueDependency? doGetValDep(int idx) {
    var slot = fromWhichNode.inSlot[idx] as ValueInSlotInfo;
    if(!slot.IsLinked()) return null;
    var fromSlot = slot.link!.from as ValueOutSlotInfo;
    return ValueDependency(fromSlot.node, fromSlot.outputOrder);
  }
}

abstract class GNImplicitOp extends GNOp{

  List<InstLine> get instructions;

  GNImplicitOp();
    //: super([],[], false);
  //List<DataType> input,List<DataType> output, this.needsExplicitExec
  @override
  NodeTranslationUnit doCreateTC() {
    return ImplicitTC(instructions);
  }

  @override
  bool get needsExplicitExec =>false;

}
