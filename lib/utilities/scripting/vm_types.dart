
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:infcanvas/utilities/scripting/graph_compiler.dart';
import 'package:infcanvas/widgets/functional/editor_widgets.dart';
import 'package:infcanvas/widgets/scripting/codepage.dart';

import '../../widgets/scripting/vm_graphnodes.dart';
import 'opcodes.dart';
import 'script_graph.dart';

class VMInheritHolder{
  VMClassInfo type;
  VMInheritHolder? parent;

  VMInheritHolder(this.type);
}

//All type names need to be full name, e.g. Lib|Type
class VMTypeInheritanceReg{

  ///Name:Parent
  Map<String, VMInheritHolder> inheritanceMap = {};

  void AddLibrary(VMLibInfo lib){
    for(var ty in lib.types){
      assert(ty.fullName != ty.parent);
      inheritanceMap[ty.fullName] = VMInheritHolder(ty);
    }
  }

  void _RegType(VMClassInfo ty){
    assert(ty.fullName != ty.parent);
    var holder = VMInheritHolder(ty);
    inheritanceMap[ty.fullName] = holder;
    if(ty.parent == "") return;
    var p = inheritanceMap[ty.parent];
    if(p == null) return;
    holder.parent = p;
  }

  void AddLibs(Iterable<VMLibInfo> libs){
    for(var lib in libs){
      AddLibrary(lib);
    }
  }

  void BuildInheritMap(){
    for(var holder in inheritanceMap.values){
      var ty = holder.type;
      if(ty.parent == "") continue;
      var p = inheritanceMap[ty.parent];
      if(p == null) continue;
      holder.parent = p;
    }
  }

  bool IsSubTypeOf(String type, String base){
    if(type == base) return true;
    var ty = inheritanceMap[type];
    var b = inheritanceMap[base];
    if(ty == null || b == null) return false;
    //String ty = type;
    while(true)
    {
      if(ty == b) return true;
      if(ty == null) return false;
      ty = ty.parent;
    }
  }

  void Clear(){
    inheritanceMap.clear();
  }
}

class FnSearchInfo{
  VMMethodInfo method;
  int position;
  FnSearchInfo(this.method, this.position);
}



class VMEnv{

  
  VMTypeInheritanceReg reg = VMTypeInheritanceReg();

  Map<String, VMLibInfo> _loadedLibs = {};
  Map<String, GraphNode Function(VMMethodInfo m, VMEnv e)> methodOverrides = {};

  void ReloadInheritanceMap(){
    reg.Clear();
    reg.AddLibs(_loadedLibs.values);
    reg.BuildInheritMap();
  }

  VMEnv(){
    Reset();
  }

  Iterable<VMLibInfo> LoadedLibs(){return _loadedLibs.values;}

  VMLibInfo? FindLib(String name){return _loadedLibs[name];}

  VMInheritHolder? FindType(String name){return reg.inheritanceMap[name];}

  void AddLibrary(VMLibInfo lib){
    _RegLib(lib);
    ReloadInheritanceMap();
  }

  void AddLibs(Iterable<VMLibInfo> libs){
    for(var l in libs){
      _RegLib(l);
    }
    ReloadInheritanceMap();
  }

  void _RegLib(VMLibInfo lib){
    _loadedLibs[lib.name] = lib;
  }

  void RemoveLibrary(String libName){
    _loadedLibs.remove(libName);
    ReloadInheritanceMap();
  }

  void Reset(){
    _loadedLibs.clear();
    reg.Clear();
    
    //ReloadInheritanceMap();
  }

  Iterable<VMField> Fields(String type)sync*{
    var ty = reg.inheritanceMap[type];
    while(ty != null){
      yield* ty.type.Fields().fields;
      ty = ty.parent;
    }
  }

  Iterable<VMField> StaticFields(String type)sync*{
    var ty = reg.inheritanceMap[type];
    while(ty != null){
      yield* ty.type.StaticFields().fields;
      ty = ty.parent;
    }
  }

  Map<String, VMMethodInfo> Methods(String type){
    Map<String, VMMethodInfo> mmap = {};
    var ty = reg.inheritanceMap[type];
    while(ty != null){
      for(var mtd in ty.type.methods){
        mmap[mtd.name] = mtd;
      }
      ty = ty.parent;
    }
    return mmap;
  }


  Iterable<NodeSearchInfo> FindMatchingNode(String? argType, String? retType)
  sync*
  {
  
    var misc = [
      GNIf(),
      GNSeq(),
      ConstIntNode(),
      ConstFloatNode(),
    ];

    var _match = (node, cat){
      return MatchGraphNode(
        node, cat, IsSubTypeOf,
        argType, retType
      );
    };

    for(var n in misc){
      var result = MatchGraphNode(
        n, "Misc", IsSubTypeOf,
        argType, retType
      );

      if(result != null) yield result;
    }

    for(var lib in _loadedLibs.values){
      for(var type in lib.types){
        if(type.isImplicitConstructable && type.isReferenceType){
          GraphNode node = ConstructNode(type, IsSubTypeOf);
          var result = _match(node, "${type.fullName}");
          if(result != null) yield result;

          node = InstNode(type);
          result = _match(node, "${type.fullName}");
          if(result != null) yield result;
        }

        //Field accessor
        for(var f in Fields(type.fullName)){
          GraphNode node = GetterNode(f.name, f.type, type, false);
          var result = _match(node, "${type.fullName}|Getters");
          if(result != null) yield result;

          node = SetterNode(f.name, f.type, type, false);
          result = _match(node, "${type.fullName}|Setters");
          if(result != null) yield result;
        }

        //StaticField accessor

        for(var f in StaticFields(type.fullName)){
          GraphNode node = GetterNode(f.name, f.type, type, true);
          var result = _match(node, "${type.fullName}|StaticGetters");
          if(result != null) yield result;

          node = SetterNode(f.name, f.type, type, true);
          result = _match(node, "${type.fullName}|StaticSetters");
          if(result != null) yield result;
        }        
        
        //Methods
        for(var fn in Methods(type.fullName).values){
          var fullName = "${fn.thisType}|${fn.name}";
          var override = methodOverrides[fullName];
          
          var node = override?.call(fn, this)??
          GNVMMethod(fn);
          
          var result = MatchGraphNode(
            node, "${fn.thisType}|Methods", IsSubTypeOf,
            argType, retType
          );

          if(result != null) yield result;
        }
      }
    }
  }
//
  
  bool IsSubTypeOf(String type, String base){
    return reg.IsSubTypeOf(type, base);
  }

  Iterable<String> get loadedTypes sync*{
    for(var kv in reg.inheritanceMap.entries){
      yield kv.key;
    }
  }


  //Settle for now
  void RenameType(String which, String name){
    var ty = reg.inheritanceMap[which];
    if(ty == null) return;
    ty.type.name = name;
    reg.inheritanceMap.remove(which);
    reg.inheritanceMap[ty.type.fullName] = ty;
  }

  void RenameLib(String which, String name){
    var lib = _loadedLibs[which]; if(lib == null) return;
    List<String> affectedTypes = [];
    for(var ty in lib.types){
      affectedTypes.add(ty.fullName);
    }
    _loadedLibs.remove(which);

    lib.name = name;
    _loadedLibs[name] = lib;

    for(var n in affectedTypes){
      var ty = reg.inheritanceMap[n];
      assert(ty != null,"Type should be in register");
      reg.inheritanceMap.remove(n);
      reg.inheritanceMap[ty!.type.fullName] = ty;
    }
  }

  void RegisterClass(VMClassInfo cls) {
    reg._RegType(cls);
  }

}


class GetterTC extends VMNodeTranslationUnit{
  @override
  int ReportStackUsage() => 1;

  @override
  void Translate(VMGraphCompileContext ctx) {
    var n = fromWhichNode as SetterNode;

    var _AddDep = (slot){
      var e = slot.link;
      if(e == null){
        ctx.ReportError("Incomplete input to getter node!");
        return;
      }
      var rear = e.from as ValueOutSlotInfo;
      ctx.AddValueDependency(rear.node, rear.outputOrder);
    };

    _AddDep(n.inSlot[1]);
    _AddDep(n.inSlot[0]);

    ctx.EmitCode(SimpleCB([
      InstLine(OpCode.ldmem, s:n.fieldName)
    ]));
  }
}


class SetterTC extends VMNodeTranslationUnit{

  @override
  int ReportStackUsage() => 0;

  @override
  void Translate(VMGraphCompileContext ctx) {
    var n = fromWhichNode as SetterNode;

    
    AddDep(n.inSlot[1], ctx);
    if(!n.fromStatic)
      AddDep(n.inSlot[2], ctx);

    ctx.EmitCode(SimpleCB([
      if(n.fromStatic)
        InstLine(OpCode.ldthis),
      InstLine(OpCode.stmem, s:n.thisType.fullName+"|"+n.fieldName),
    ]));

    var nextExec = fromWhichNode.outSlot.first as ExecOutSlotInfo;
    //if(nextExec.link!=null){
      ctx.AddNextExec(nextExec.link?.to.node);
    //}
  }

  @override
  CacheHandle doCreateCacheHandle() {
    // Shouldn't be called, since setter shouldn't be cached
    throw UnimplementedError();
  }

}

bool CheckInputSlot(ValueInSlotInfo slot, String newType, 
  bool Function(String ty, String base) isCompat
){
  var oldTy = slot.type;
  bool compat = isCompat(oldTy, newType);
  if(!compat) {
    slot.Disconnect();
  }
  slot.type = newType;
  return compat;
}


bool CheckOutputSlot(ValueOutSlotInfo slot, String newType, 
  bool Function(String ty, String base) isCompat
){
  var oldTy = slot.type;
  bool compat = isCompat(newType, oldTy);
  if(!compat) {
    slot.Disconnect();
  }
  slot.type = newType;
  return compat;
}

abstract class EnvNode extends GraphNode{
  bool Validate(VMEnv env);
}

class GetterNode extends EnvNode{
  bool fromStatic;
  String fieldName;
  String fieldType;
  VMClassInfo thisType;

  GetterNode(this.fieldName, this.fieldType, this.thisType, this.fromStatic){
    displayName = "Get $fieldName";
    outSlot.add(ValueOutSlotInfo(this, fieldName, fieldType, 0));

    if(!fromStatic){
      inSlot.add(ValueInSlotInfo(this, "object", thisType.fullName));
    }
  }
  @override
  bool get needsExplicitExec => false;

  @override
  GraphNode Clone() {
    return GetterNode(this.fieldName, this.fieldType, this.thisType, this.fromStatic);

  }


  @override
  VMNodeTranslationUnit doCreateTU() {
    return GetterTC();
  }

  

  @override
  bool Validate(VMEnv env) {
    String thisTy = thisType.fullName;
    if(env.FindType(thisTy) == null) return false;
    
    var fields = fromStatic?
    env.StaticFields(thisTy):
    env.Fields(thisTy);
    for(var field in fields){
      if(field.name == fieldName){
        fieldType = field.type;
        if(!fromStatic)
          CheckInputSlot(
            inSlot.last as ValueInSlotInfo,
            thisTy, env.IsSubTypeOf);
        CheckOutputSlot(
          outSlot.last as ValueOutSlotInfo,
          fieldType, env.IsSubTypeOf);
        return true;
      }
    }
    RemoveLinks();
    return false;
  }
}

class SetterNode extends EnvNode{
  bool fromStatic;
  String fieldName;
  String fieldType;
  VMClassInfo thisType;

  SetterNode(this.fieldName, this.fieldType, this.thisType, this.fromStatic){
    displayName = "Set $fieldName";
    inSlot.add(ExecInSlotInfo(this));
    outSlot.add(ExecOutSlotInfo(this));

    if(!fromStatic){
      inSlot.add(ValueInSlotInfo(this, "object", thisType.fullName));
    }

    inSlot.add(ValueInSlotInfo(this, fieldName, fieldType));
  }


  @override
  bool get needsExplicitExec => true;

  @override
  GraphNode Clone() {
    return SetterNode(this.fieldName, this.fieldType, this.thisType, this.fromStatic);
  }

  @override
  VMNodeTranslationUnit doCreateTU() {
    return SetterTC();
  }

  @override
  bool Validate(VMEnv env) {
    String thisTy = thisType.fullName;
    if(env.FindType(thisTy) == null) return false;
    
    var fields = fromStatic?
    env.StaticFields(thisTy):
    env.Fields(thisTy);
    for(var field in fields){
      if(field.name == fieldName){
        fieldType = field.type;
        if(!fromStatic)
        {
          CheckInputSlot(
            inSlot[1] as ValueInSlotInfo,
            thisTy, env.IsSubTypeOf);
          CheckInputSlot(
            inSlot[2] as ValueInSlotInfo,
            fieldType, env.IsSubTypeOf);
        }else{
          CheckInputSlot(
            inSlot[1] as ValueInSlotInfo,
            fieldType, env.IsSubTypeOf);
        }
        return true;
      }
    }
    RemoveLinks();
    return false;
  }

}

///Construct implicitly constructable types
class InstNode extends GNImplicitOp implements EnvNode{
  VMClassInfo cls;

  InstNode(this.cls){
    displayName = "New ${cls.name}";
    outSlot.add(ValueOutSlotInfo(this, "object", cls.fullName, 0));
  }

  @override
  bool Validate(VMEnv env){
    //Is type included in env?
    if(env.FindType(cls.fullName)==null)return false;
    if(!cls.IsValid() ||  !cls.IsRefType())return false;
    displayName = "New ${cls.name}";
    outSlot.last.type = cls.fullName;
    return true;
  }

  @override
  GraphNode Clone() {
    return InstNode(cls);
  }

  @override
  List<InstLine> get instructions =>[
    InstLine(OpCode.newobj, s:cls.fullName),
  ];
}

class ConstructTU extends VMNodeTranslationUnit{
  @override
  int ReportStackUsage() => 1;

  @override
  void Translate(VMGraphCompileContext ctx) {
    var n = fromWhichNode as ConstructNode;

    ctx.EmitCode(SimpleCB([
      InstLine(OpCode.newobj, s:n.cls.fullName),
    ]));

    for(var s in n.inSlot){
      AddDep(s, ctx);
      ctx.EmitCode(SimpleCB([
        InstLine(OpCode.ldi, i:1),
        InstLine(OpCode.stmem, s:n.cls.fullName + "|" + s.name),
      ]));
    }

  }

}

///Instantiate implicitly constructable types
class ConstructNode extends EnvNode{
  VMClassInfo cls;

  bool Function(String, String) typeCompat;

  ConstructNode(this.cls, this.typeCompat){
    displayName = "Construct ${cls.name}";
    outSlot.add(ValueOutSlotInfo(this, "object", cls.fullName, 0));
    _updateInput();

  }

  void _updateInput(){
    var fields = cls.Fields();
    //Discarding all redundant slots
    //Because slot 0 is execution flow input
    //and we want to retain that, so length-1
    for(int i = fields.FieldCount(); i < inSlot.length;i++){
      inSlot.last.DisconnectFromRear();
      inSlot.removeLast();
    }

    for(int i = 0; i < fields.FieldCount(); i++){
      var fieldName = fields.GetName(i);
      var fieldType = fields.GetFullType(i);
      if(i >= inSlot.length){
        inSlot.add(ValueInSlotInfo(this, fieldName, fieldType));
        continue;
      }

      var slot = inSlot[i];
      if(!typeCompat(slot.type, fieldType)){
        slot.Disconnect();
      }
      slot.type = fieldType;
      slot.name = fieldName;
    }

    outSlot.last.type = cls.fullName;
  }



  @override
  bool Validate(VMEnv env){
    if(env.FindType(cls.fullName)==null)return false;
    if(!( cls.IsValid() && cls.IsRefType()))return false;
    var ty = env.FindType(cls.fullName);
    if(ty == null) return false;
    _updateInput();
    return true;
  }

  @override
  GraphNode Clone() {
    return ConstructNode(cls, typeCompat);
  }

  @override
  VMNodeTranslationUnit doCreateTU() => ConstructTU();

  @override
  bool get needsExplicitExec => false;
}

class NullCompareNode extends GNImplicitOp{
  VMClassInfo cls;

  NullCompareNode(this.cls){}

  @override
  bool Validate(){
    return cls.IsValid() && cls.IsRefType();
  }

  @override
  GraphNode Clone() {
    return NullCompareNode(cls);
  }

  @override
  List<InstLine> get instructions =>[
    InstLine(OpCode.isnull),
  ];
}

class ConstIntNode extends GNImplicitOp with GNPainterMixin{
  int val = 0;
  ConstIntNode(){
    displayName = "Constant Int";
    outSlot.add(ValueOutSlotInfo(this, "i", "Num|Int", 0));
  }

  bool SetVal(String val){
    var newIVal = int.tryParse(val);
    if(newIVal == null) return false;
    this.val = newIVal;
    return true;
  }

  String GetVal(){
    return val.toString();
  }

  @override
  Widget Draw(BuildContext ctx, void Function() update){
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SizedBox(
            height: 30,
            child: NameField(
              initialText: GetVal(),
              onChange: SetVal,
            ),
          ),
        ),
        DrawOutput(),
      ],
    );
  }

  @override
  GraphNode Clone() {
    return ConstIntNode()..val = val;
  }

  @override
  List<InstLine> get instructions => [
    InstLine(OpCode.PUSHIMM, i:val),
  ];
}


class ConstFloatNode extends GNImplicitOp with GNPainterMixin{
  double val = 0;
  ConstFloatNode(){
    displayName = "Constant Float";
    outSlot.add(ValueOutSlotInfo(this, "f", "Num|Float", 0));
  }

  bool SetVal(String val){
    var newIVal = double.tryParse(val);
    if(newIVal == null) return false;
    this.val = newIVal;
    return true;
  }

  String GetVal(){
    return val.toString();
  }

  @override
  Widget Draw(BuildContext ctx, void Function() update){
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SizedBox(
            height: 30,
            child: NameField(
              initialText: GetVal(),
              onChange: SetVal,
            ),
          ),
        ),
        DrawOutput(),
      ],
    );
  }

  @override
  GraphNode Clone() {
    return ConstFloatNode()..val = val;
  }

  @override
  List<InstLine> get instructions => [
    InstLine(OpCode.PUSHIMM, f:val),
  ];

}

//TODO:Singleton builtin library loader
