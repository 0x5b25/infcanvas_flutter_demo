import 'package:flutter/cupertino.dart';
import 'package:infcanvas/scripting/graph_compiler.dart';
import 'package:infcanvas/scripting/editor/vm_types.dart';

///The representation of scripts
///
///

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
  SlotInfo(this.node, this.name);

  SlotInfo? CreateCounterpart();

  bool CanEstablishLink(SlotInfo slot);

  bool IsLinked();
  ///Invoked by all disconnect actions
  ///Indicates that the link should be removed
  ///from this. no further action required e.g.
  ///remove from rear end
  void DisconnectLink(GraphEdge link);

  ///Disconnect all links
  void Disconnect();

  ///Invoked by all connect actions.
  ///Indicates the link added to this slot, no
  ///further actions required except adding and
  ///setting the correct side of the link
  void ConnectLink(GraphEdge link);

  void ConcatSlot(covariant SlotInfo slot);

  void Dispose(){Disconnect();}

  void ValidateLink();
}

abstract class OutSlotInfo extends SlotInfo{
  OutSlotInfo(GraphNode node, String name):super(node, name);
}
abstract class InSlotInfo extends SlotInfo{
  InSlotInfo(GraphNode node, String name):super(node, name);
}

mixin PairConstructor on SlotInfo{
  @override CreateCounterpart(){
    var s = doCreateCounterpart();
    if(s == null) return null;
    var lnk;
    if(this is OutSlotInfo){
      lnk = GraphEdge(this as OutSlotInfo, s as InSlotInfo);
    }else{
      lnk = GraphEdge(s as OutSlotInfo, this as InSlotInfo);
    }

    ConnectLink(lnk);
    s.ConnectLink(lnk);
    return s;
  }

  SlotInfo? doCreateCounterpart();
}

mixin SingleConnSlotMixin on SlotInfo{
  GraphEdge? link;

  @override @mustCallSuper
  void DisconnectLink(GraphEdge link){
    if(this.link == link) this.link = null;
  }

  SlotInfo? GetRear(){
    if(link == null) return null;
    if(this is InSlotInfo){
      return link!.from;
    }
    if(this is OutSlotInfo){
      return link!.to;
    }
  }

  @override
  void ValidateLink(){
    var rear = GetRear();
    if(rear == null) return;
    if(!CanEstablishLink(rear)){
      Disconnect();
    }
  }
  
  @override @mustCallSuper
  void ConnectLink(GraphEdge link){
    Disconnect();
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
  void ConcatSlot(SlotInfo slot){
    assert(slot is! MultiConnSlotMixin);
    ReplaceConnWith(slot);
  }

  void ReplaceConnWith(slot){
    if(this is OutSlotInfo){
      assert(slot is OutSlotInfo);
    }else{
      assert(slot is InSlotInfo);
    }

    //Disconnect
    Disconnect();

    var l = slot.link;
    //Mend connection
    if(l!=null){
      slot.DisconnectLink(l);
      ConnectLink(l);
    }
  }

  @override
  bool IsLinked() {
    return link != null;
  }


  @override
  void Disconnect(){
    if(link == null) return;
    if(this is OutSlotInfo){
      link!.to.DisconnectLink(link!);
    }else{
      link!.from.DisconnectLink(link!);
    }
    DisconnectLink(link!);
  }

}

mixin MultiConnSlotMixin on SlotInfo{
  List<GraphEdge> links = [];

  @override @mustCallSuper
  void DisconnectLink(GraphEdge link){
    links.remove(link);
  }

  @override @mustCallSuper
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

  bool IsSpecificLinkValid(GraphEdge l){
    var rear = this is OutSlotInfo? l.to : l.from;
    return CanEstablishLink(rear);
  }

  @override
  void ValidateLink() {
    int lastIdx = links.length;
    _Swap(i){
      assert(i < lastIdx);
      var to = links[lastIdx - 1];
      lastIdx--;
      links[lastIdx] = links[i];
      links[i] = to;
    }
    //Mark
    for(int i = 0; i < lastIdx; i++){
      var l = links[i];
      if (!IsSpecificLinkValid(l)) {
        _Swap(i);
        i--;
      }
    }
    //Finalize
    for(int i = lastIdx; i < links.length; i++) {
      _DisconnectFromRearSpecific(links[i]);
    }
    //Sweep
    links.length = lastIdx;
  }

  @override 
  void ConcatSlot(dynamic slot){
    if(slot is MultiConnSlotMixin)
      AddMultipleConn(slot);
    else{
      ConnectLink(slot.link);
    }
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
    }else{
      assert(slot is InSlotInfo);
    }

    for(var link in slot.links){
      ConnectLink(link);
    }
  }

  @override
  bool IsLinked() {
    return links.isNotEmpty;
  }

  void _DisconnectFromRearSpecific(GraphEdge l){
    if(this is OutSlotInfo){
      l.to.DisconnectLink(l);
    }else{
      l.from.DisconnectLink(l);
    }
  }

  @override 
  void Disconnect(){
    for(var l in links){
      _DisconnectFromRearSpecific(l);
    }
    var cnt = links.length;
    for(int i = 0; i < cnt; i++){
      DisconnectLink(links[i]);
    }
  }
}

abstract class GraphNode{
  String get displayName;
  List<InSlotInfo> get inSlot;
  List<OutSlotInfo> get outSlot;

  ///Like getter and setter nodes
  bool get needsExplicitExec;


  void RemoveLinks(){
    for(var s in inSlot) s.Disconnect();
    for(var s in outSlot) s.Disconnect();
  }

  NodeTranslationUnit CreateTranslationUnit(){
    var tc = doCreateTU();
    tc.fromWhichNode = this;
    return tc;
  }

  NodeTranslationUnit doCreateTU();

  GraphNode Clone();

  String UniqueTag()=>this.runtimeType.toString();

  void Dispose(){}


  @mustCallSuper
  void Update(){
    for(var s in outSlot){
      s.ValidateLink();
    }
    for(var s in inSlot){
      s.ValidateLink();
    }
  }
}

class ValueDependency{
  GraphNode fromWhich;
  int idx;
  ValueDependency(this.fromWhich, this.idx);
}
