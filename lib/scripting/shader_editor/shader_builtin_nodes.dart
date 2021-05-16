

import 'package:flutter/material.dart';
import 'package:infcanvas/scripting/graph_compiler.dart';
import 'package:infcanvas/scripting/script_graph.dart';
import 'package:infcanvas/scripting/editor_widgets.dart';
import 'package:infcanvas/scripting/codepage.dart';
import 'package:infcanvas/scripting/editor/codemodel.dart';
import 'package:infcanvas/scripting/editor/vm_method_nodes.dart';
import 'package:infcanvas/scripting/shader_editor/shader_codemodel.dart';

import 'shader_method_nodes.dart';

class GenericArgConstraint{
  bool Validate(CodeType ty) => true;

  const GenericArgConstraint();
}

class ConcreteTypeConstraint extends GenericArgConstraint{
  bool Validate(CodeType ty){
    if (ty is! ShaderType) return false;
    var sty = ty as ShaderType;
    return !sty.isOpaque;
  }

  const ConcreteTypeConstraint();
}

class GenericArg{
  final String name;
  final GenericArgConstraint constraint;
  const GenericArg(this.name,
      [this.constraint = const GenericArgConstraint()]
      );

  const GenericArg.concreteTypes(String name)
    :this(name,const ConcreteTypeConstraint())
  ;
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
    assert((instType == null) == (instances.isEmpty));
    instances.add(inst);
    if(instType == null) {
      instType = ty;
      onTypeSet?.call(ty);
      return;
    }
    //Find "Shallower" type
    if(instType!.IsSubTypeOf(ty)){
      onTypeSet?.call(ty);
      instType = ty;
    }
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


class SigParser{
  String ret = "";
  String name = "";
  List<String> argType = [];
  List<String> argName = [];
  bool isValid = false;

  int get argCnt => argType.length;

  static final c_char = RegExp(r'[@a-zA-Z0-9_]+');
  static final fnMatcher = RegExp(
      r'([@a-zA-Z0-9_]+)'       //#1 ret
      r'([\s]+)([a-zA-Z0-9_]+)'//#2 w #3 name
      r'([\s]*)'               //#4 w
      r'([(])(.*)([)])');      //#5 ( #6 arg #7 )

  SigParser.parse(String sig){
    var match = fnMatcher.firstMatch(sig);
    if(match == null) return;
    ret = match[1]!;
    name = match[3]!;
    var args = match[6]!;
    var segs = args.split(',');
    for(var s in segs){
      var kv = c_char.allMatches(s);
      if(kv.length < 2) return;
      var ty = kv.first;
      argType.add(ty[0]!);
      var name = kv.last;
      argName.add(name[0]!);
    }
    isValid = true;
  }
}

class ShaderBuiltinFn extends ShaderGraphNode with GNPainterMixin{

  late final String name;
  final String declaration;

  @override get displayName => name;

  late final Map<String, GenericArgGroup> _genGroups;
  late final List<ValueInSlotInfo> argIn;
  late final ValueOutSlotInfo valOut;

  @override get inSlot => argIn;
  @override get outSlot => [valOut];

  ///ReturnType Name(Type argName, Type argName...)
  static _IsGenType(String ty){
    return '@'.matchAsPrefix(ty) != null;
  }

  static _GetGenTypeName(String ty){
    return ty.replaceFirst(RegExp(r'^@'), '');
  }

  void _UpdateGenType(GenericArgGroup group,CodeType? ty){
    repaint?.call();
  }
  Function? repaint;
  @override Draw(ctx, upd){
    repaint = upd;
    return super.Draw(ctx, upd);
  }

  ShaderBuiltinFn.fromDeclaration(
      this.declaration
  ){
    var res = SigParser.parse(declaration);
    assert(res.isValid);
    name = res.name;
    _genGroups = {};
    _GetGenGroup(name){
      var genName = _GetGenTypeName(name);
      var genGroup = _genGroups[genName];
      if(genGroup == null)
      {
          genGroup = GenericArgGroup(
            GenericArg.concreteTypes(genName),
            (ty){
              _UpdateGenType(genGroup!, ty);
            });
          _genGroups[genName] = genGroup;
      }
      return genGroup;
    }

    if(_IsGenType(res.ret)){
      var genGroup = _GetGenGroup(res.ret);
      valOut = GenericValueOutSlotInfo(this, "result", genGroup);
    }else{
      var shaderTy = ShaderTypes.Str2Type(res.ret)!;
      valOut = ValueOutSlotInfo(this, "result", shaderTy);
    }

    argIn = [];
    var argCnt = res.argCnt;
    for(int i =0;i<argCnt;i++){
      var type = res.argType[i];
      var name = res.argName[i];

      if(_IsGenType(type)){
        var genGroup = _GetGenGroup(type);
        argIn.add(GenericValueInSlotInfo(this, name, genGroup));
      }else{
        var shaderTy = ShaderTypes.Str2Type(type)!;
        argIn.add(ValueInSlotInfo(this, name, shaderTy));
      }
    }

  }
  @override get retType => valOut.type as ShaderType;

  @override doCloneNode()=>
      ShaderBuiltinFn.fromDeclaration(declaration);

  @override GetSrc(args) {
    var argList = [];
    for(int i = 0; i < args.length; i++){
      var argTgtType = argIn[i].type!;
      if(argTgtType != args[i].type){
        argList.add("${argTgtType.fullName}(${args[i].name})");
      }else{
        argList.add(args[i].name);
      }
    }

    String arg = argList.join(", ");

    return "$name(" + arg + ")";
  }
}


class ShaderBuiltinBinOp extends ShaderBuiltinFn{
  String op;

  ShaderBuiltinBinOp(String name, this.op)
      : super.fromDeclaration(
        "@genType $name(@genType a, @genType b)"
      )
  {}

  @override doCloneNode()=>ShaderBuiltinBinOp(name, op);

  @override
  String GetSrc(argNames) {
    //NOTE: Can operator do implicit type cast? Yes!
    return "${argNames[0].name} $op ${argNames[1].name}";
  }
}

class ShaderBuiltinUnaryOp extends ShaderBuiltinFn{
  String op;

  ShaderBuiltinUnaryOp(String name, this.op)
      : super.fromDeclaration(
      "@genType $name(@genType a)"
  )
  {}
  @override doCloneNode() => ShaderBuiltinUnaryOp(name, op);

  @override
  String GetSrc(args) {
    return "$op ${args[0].name}";
  }
}


class ShaderConstFloatNode extends ShaderGraphNode with GNPainterMixin{
  double val = 0;

  @override get displayName => "Constant Float";

  @override get inSlot => [];
  @override get outSlot => [valOut];

  late final valOut = ValueOutSlotInfo(this, "f", retType);

  ShaderConstFloatNode(){}

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

  @override doCloneNode() {
    return ShaderConstFloatNode()..val = val;
  }

  @override String GetValName()=>val.toString();

  @override get retType => ShaderTypes.float;

  //@override
  //String? GetSrc(List<ArgField> args) {
  //  // TODO: implement GetSrc
  //  throw UnimplementedError();
  //}

}


class ElementGetter extends ShaderGraphNode{
  String elem;
  ShaderType type;

  @override get displayName => "${type.fullName}.${elem}";

  late final tgtIn = ValueInSlotInfo(this, "Target", type);
  late final elemOut = ValueOutSlotInfo(this, elem, retType);

  @override get inSlot => [tgtIn];
  @override get outSlot => [elemOut];

  ElementGetter(this.type, this.elem){ }

  @override doCloneNode() {
    return ElementGetter(type, elem);
  }

  @override
  String GetSrc(argNames) {
    return "$type(${argNames.single.name}).$elem";
  }

  @override get retType => ShaderTypes.float;


  static List<ShaderGraphNode> ElemAccessors(){
    ShaderGraphNode init(String ty, args) {
      var arg = [
        for(var a in args) "float $a"
      ].join(", ");

      var sig = "$ty $ty($arg)";
      return ShaderBuiltinFn.fromDeclaration(sig);
    }

    List<ShaderGraphNode> gen(type, elems){
      return [
        for(var e in elems)
          ElementGetter(type, e),
        init(type.fullName, elems)
      ];
    };
    return
      gen(ShaderTypes.float4, ["x","y","z","w"]) +
      gen(ShaderTypes.float3, ["x","y","z"]) +
      gen(ShaderTypes.float2, ["x","y"])
    ;
  }
}

List<ShaderGraphNode> Builtins(){
  _Sig1(name) => "@genType $name(@genType a)";
  _Sig2(name) => "@genType $name(@genType a, @genType b)";
  _Map(String sig) => ShaderBuiltinFn.fromDeclaration(sig);
  _MapList(sigList) => [for(var s in sigList) _Map(s)];
  return
    <ShaderBuiltinFn>[
      ShaderBuiltinUnaryOp("Negate", "-",),
      ShaderBuiltinBinOp("Add",      "+",),
      ShaderBuiltinBinOp("Subtract", "-",),
      ShaderBuiltinBinOp("Multiply", "*",),
      ShaderBuiltinBinOp("Divide",   "/",),
    ]+
    _MapList(
    [
      /*ANGLE & TRIGONOMETRY FUNCTIONS*/
      "radians","degrees",
      "sin", "cos", "tan",
      "asin","acos","atan",

      /*Arithmetic*/
      "exp", "exp2","log", "log2",
      "sqrt","inversesqrt",

      /*Conversion*/
      "abs", "sign", "floor", "ceil", "fract","normalize"
    ].map(_Sig1).toList()
    +[
      "pow", "mod", "min", "max"
    ].map(_Sig2).toList()
    +[
      "@genType clamp(@genType x,    @genType min, @genType max)",
      "@genType mix  (@genType x,    @genType y,   @genType alpha)",
      "@genType step (@genType gate, @genType x)",
      "@genType smoothstep(@genType low, @genType high, @genType x)",
      "@genType faceforward(@genType N, @genType I, @genType Nref)",
      "@genType reflect(@genType N, @genType I)",

      "float length(@genType x)",
      "float distance(@genType x, @genType y)",
      "float dot(@genType x, @genType y)",
      "float3 cross(float3 x, float3 y)",
      "@genType refract(@genType I, @genType N, float eta)",
      "float4 sample(shader tex, float2 pos)",
    ]
  );
}

late List<ShaderGraphNode> shaderNodes =
    ElementGetter.ElemAccessors() +
    Builtins();
