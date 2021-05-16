
import 'package:infcanvas/scripting/shader_editor/shader_builtin_nodes.dart';
import 'package:infcanvas/scripting/shader_editor/shader_codemodel.dart';
import 'package:infcanvas/scripting/shader_editor/shader_editor.dart';
import 'package:infcanvas/scripting/shader_editor/shader_method_nodes.dart';

class ShaderNodeSerializer {

  Map<String, dynamic> Serialize(ShaderGraphNode node) {
    var map = <String, dynamic>{};

    map["tag"] = node.UniqueTag();
    map["position_x"] = node.ctrl.dx;
    map["position_y"] = node.ctrl.dy;

    var fn = _serializeFn[node.runtimeType];
    if (fn != null) {
      map["data"] = fn(node);
    }

    return map;
  }


  ShaderGraphNode Deserialize(Map<String, dynamic> data,
      ShaderFnAnalyzer analyzer,) {

    var tag = data["tag"];
    double position_x = data["position_x"];
    double position_y = data["position_y"];
    var nodeData = data["data"] ?? "";

    var fn = _deserializeFn[tag];
    if (fn == null) {
      throw Exception("Unknown tag $tag");
    }

    ShaderGraphNode node = fn(analyzer, nodeData);
    node.ctrl.dx = position_x;
    node.ctrl.dy = position_y;
    return node;
  }
}

Map _serializeFn = {
  ElementGetter:Ser_ElementGetter,
  ShaderArgGetNode:Ser_ShaderArgGetNode,
  ShaderInvokeNode:Ser_ShaderInvokeNode,
  ShaderBuiltinFn:Ser_ShaderBuiltinFn,
  ShaderBuiltinBinOp:Ser_ShaderBuiltinBinOp,
  ShaderBuiltinUnaryOp:Ser_ShaderBuiltinBinOp,
  ShaderConstFloatNode:Ser_ShaderConstFloatNode,
};

String Ser_ElementGetter(ElementGetter node){
  return  "${node.type.fullName}|${node.elem}";
}

String Ser_ShaderArgGetNode(ShaderArgGetNode node){
  return node.arg.name.value;
}

String Ser_ShaderInvokeNode(ShaderInvokeNode node){
  var fn = node.whichFn;
  return fn.fullName;
}

String Ser_ShaderBuiltinFn(ShaderBuiltinFn node){
  return node.declaration;
}
String Ser_ShaderBuiltinBinOp(ShaderBuiltinBinOp node){
  return "${node.name}|${node.op}";
}

String Ser_ShaderBuiltinUnaryOp(ShaderBuiltinUnaryOp node){
  return "${node.name}|${node.op}";
}

Ser_ShaderConstFloatNode(ShaderConstFloatNode node){
  return node.val;
}

Map _deserializeFn = {
  "ElementGetter":Des_ElementGetter,
  "ShaderRetNode":Des_ShaderRetNode,
  "ShaderArgGetNode":Des_ShaderArgGetNode,
  "ShaderInvokeNode":Des_ShaderInvokeNode,
  "ShaderBuiltinFn":Des_ShaderBuiltinFn,
  "ShaderBuiltinBinOp":Des_ShaderBuiltinBinOp,
  "ShaderBuiltinUnaryOp":Des_ShaderBuiltinUnaryOp,
  "ShaderConstFloatNode":Des_ShaderConstFloatNode,
};


ElementGetter Des_ElementGetter(
    ShaderFnAnalyzer analyzer,
    data,
    ){
  var parts = data.split('|');
  var type = ShaderTypes.Str2Type(parts[0]);
  if(type == null) {
    throw Exception("Unknown shader type ${parts[0]}");
  }
  return ElementGetter(type, parts[1]);
}

ShaderRetNode Des_ShaderRetNode(
  ShaderFnAnalyzer analyzer,
  data,
){
  return ShaderRetNode(analyzer.whichFn!);
}

ShaderArgGetNode Des_ShaderArgGetNode(
  ShaderFnAnalyzer analyzer,
  String data,
){
  var argField = analyzer.whichFn!.args.fields;
  return ShaderArgGetNode(argField.firstWhere((e) => e.name.value == data));
}

ShaderInvokeNode Des_ShaderInvokeNode(
  ShaderFnAnalyzer analyzer,
  String data,
){
  var fnList = analyzer.env!.LoadedFuncs();
  for(var fn in fnList){
    var name = fn.fullName;
    if(data == name){
      return ShaderInvokeNode(fn);
    }
  }
  throw Exception("Can't find function $data");
}


ShaderBuiltinFn Des_ShaderBuiltinFn(
    ShaderFnAnalyzer analyzer,
    String data,
    ){
  return ShaderBuiltinFn.fromDeclaration(data);
}


ShaderBuiltinBinOp Des_ShaderBuiltinBinOp(
    ShaderFnAnalyzer analyzer,
    String data,
    ){
  var d = data.split('|');
  return ShaderBuiltinBinOp(d.first, d.last);
}


ShaderBuiltinUnaryOp Des_ShaderBuiltinUnaryOp(
    ShaderFnAnalyzer analyzer,
    String data,
    ){
  var d = data.split('|');
  return ShaderBuiltinUnaryOp(d.first, d.last);
}


ShaderConstFloatNode Des_ShaderConstFloatNode(
    ShaderFnAnalyzer analyzer,
    data,
    ){
  return ShaderConstFloatNode()..val = data;
}



