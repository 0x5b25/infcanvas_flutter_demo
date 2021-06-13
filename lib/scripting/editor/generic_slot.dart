
import 'package:flutter/material.dart';
import 'package:infcanvas/scripting/editor/codemodel.dart';
import 'package:infcanvas/scripting/editor/vm_method_nodes.dart';
import 'package:infcanvas/scripting/script_graph.dart';

class GenericArgConstraint{
  bool Validate(CodeType ty) => true;

  const GenericArgConstraint();
}

class GenericArg{
  final String name;
  final GenericArgConstraint constraint;
  const GenericArg(this.name,
      [this.constraint = const GenericArgConstraint()]
      );
}

class GenericArgInstance{
  GenericArgGroup group;
  GenericArgInstance(this.group);
  String get argName => group.argName;
  GenericArg get arg => group.arg;
  CodeType? get type => group.instType;

  void InstantiateType(CodeType ty){
    if(!arg.constraint.Validate(ty)) return;
    group._SetType(this, ty);
  }
  void RemoveTypeInstance(){
    group._UnsetType(this);
  }
}

class GenericArgGroup{
  GenericArg arg;
  String get argName => arg.name;

  void Function(CodeType? ty)? onTypeSet;

  CodeType? instType;

  Set<GenericArgInstance> instances = {};

  GenericArgGroup(this.arg, [this.onTypeSet]);

  void _SetType(GenericArgInstance inst, CodeType ty) {
    //empty instance == no type set
    //assert((instType == null) == (instances.isEmpty));
    instances.add(inst);
    if(instType == null) {
      instType = ty;
    }
    onTypeSet?.call(ty);
    //Find "Shallower" type
    //if(instType!.IsSubTypeOf(ty)){
    //  onTypeSet?.call(ty);
    //  instType = ty;
    //}
  }

  void _UnsetType(GenericArgInstance inst) {
    assert(instances.isNotEmpty);
    instances.remove(inst);
    if(instances.isEmpty){
      instType = null;
    }
  }
}

class GenericValueInSlotInfo extends ValueInSlotInfo{

  GenericArgInstance _gInst;
  @override get type => _gInst.type;

  GenericValueInSlotInfo(GraphNode node, String name, GenericArgGroup group)
      : _gInst = GenericArgInstance(group),
        super(node, name);

  @override DisconnectLink(l){
    super.DisconnectLink(l);
    _gInst.RemoveTypeInstance();
  }

  @override ConnectLink(l){
    super.ConnectLink(l);
    var rear = l.from as ValueOutSlotInfo;
    var ty = rear.type!;
    _gInst.InstantiateType(ty);
  }

  @override CanEstablishLink(slot){
    if(!(slot is ValueOutSlotInfo)) return false;
    var fromType = slot.type;
    if(fromType == null) return false;
    if(type == null) {
      return _gInst.arg.constraint.Validate(fromType);
    }
    return fromType.IsSubTypeOf(type!);
  }

  @override doCreateCounterpart() {
    if(type == null) return null;
    return ValueOutSlotInfo(node, name, type);
  }

  @override get iconColor =>
      type == null? Colors.grey:
      GetColorForType(typeName);
}


class GenericValueOutSlotInfo extends ValueOutSlotInfo{

  GenericArgInstance _gInst;
  @override get type => _gInst.type;

  GenericValueOutSlotInfo(GraphNode node, String name, GenericArgGroup group)
      : _gInst = GenericArgInstance(group),
        super(node, name);

  @override DisconnectLink(l){
    super.DisconnectLink(l);
    if(links.isEmpty)
      _gInst.RemoveTypeInstance();
  }

  @override ConnectLink(l){
    super.ConnectLink(l);
    var rear = l.to as ValueInSlotInfo;
    var ty = rear.type!;
    _gInst.InstantiateType(ty);
  }

  @override
  bool CanEstablishLink(SlotInfo slot) {
    if(!(slot is ValueInSlotInfo)) return false;
    var toType = slot.type;
    if(toType == null) return false;
    if(type == null) {
      return _gInst.arg.constraint.Validate(toType);
    }
    return type!.IsSubTypeOf(toType!);
  }

  @override doCreateCounterpart() {
    if(type == null) return null;
    return ValueInSlotInfo(node, name, type);
  }

  @override get iconColor =>
      type == null? Colors.grey:
      GetColorForType(typeName);
}
