
import 'package:infcanvas/utilities/serializer/serialize.dart';
import 'package:infcanvas/scripting/editor/codemodel.dart';
import 'package:infcanvas/scripting/graphlink_serializer.dart';
import 'package:infcanvas/scripting/shader_editor/shader_codemodel.dart';
import 'package:infcanvas/scripting/shader_editor/shader_editor.dart';
import 'package:infcanvas/scripting/shader_editor/shader_method_nodes.dart';
import 'package:infcanvas/scripting/shader_editor/shader_node_serializer.dart';
import 'package:infcanvas/scripting/editor/vm_serializer.dart';


Map<String, dynamic> SerializeShaderLibrary(
    ShaderNodeSerializer serializer,
    ShaderLib lib
){
  Map<String ,dynamic> map = {};

  map["libName"] = lib.name.value;
  map["functions"] = lib.functions.map(
    (e) => SerializeShaderFn(serializer, e)
  ).toList();

  return map;
}


Map<String, dynamic> SerializeShaderFn(
    ShaderNodeSerializer serializer,
    ShaderFunction m
) {
  Map<String ,dynamic> map = {};

  map["functionName"] = m.name.value;
  map["args"] = Field2Map(m.args);
  map["returnType"] = m.returnType.value.fullName;
  map["entry"] = serializer.Serialize( m.root! );
  map["body"] = m.body.map((e) => serializer.Serialize(e)).toList();
  var allNodes = <ShaderGraphNode>[m.root!] + m.body;
  var serializedLinks = SerializeLink(allNodes);
  map["links"] = serializedLinks.map((e) => {
    "from":e.from,
    "fromSlot":e.fromSlot,
    "to":e.to,
    "toSlot":e.toSlot
  }).toList();
  return map;
}


ShaderLib CreateShaderLibSkeleton(Map<String, dynamic> data){
  var lib = ShaderLib();
  lib.name.value = data["libName"];
  for(var fnData in data["functions"]){
    lib.AddFn(CreateShaderFnSkeleton(fnData));
  }

  return lib;
}

ShaderFunction CreateShaderFnSkeleton(Map<String, dynamic> data){
  var fn = ShaderFunction();
  fn.name.value = data["functionName"];
  return fn;
}

void MatchLists<K, V>(
    List<K> matchAgainst,
    List<V> toBeMatched,
    bool Function(K, V) isEq
    ){
  assert(matchAgainst.length == toBeMatched.length);
  int length = matchAgainst.length;
  int currPos = 0;
  while(currPos < length){
    var k = matchAgainst[currPos];
    for(int i = currPos; i < length; i++){
      var v = toBeMatched[i];
      if(isEq(k, v)){
        //Swap position
        if(i != currPos){
          toBeMatched[i] = toBeMatched[currPos];
          toBeMatched[currPos] = v;
        }
        //Move to next
        currPos++;
        //Finish this pass
        break;
      }
    }
  }
}

void FillShaderLibSkeleton(
    ShaderEditorEnv env,
    ShaderNodeSerializer serializer,
    ShaderLib lib,
    Map<String, dynamic> data
){

  var fnData = data["functions"];
  var fnSkeleton = lib.functions.toList();
  //Align
  MatchLists(
      fnData,
      fnSkeleton,
          (dynamic data,ShaderFunction fn)=>fn.name.value == data["functionName"]
  );
  for(int i = 0; i < fnSkeleton.length;i++)
    FillShaderFnSkeleton(env,serializer, fnSkeleton[i], fnData[i]);
}

_FillFieldArray(
    Iterable<CodeType> availTy,
    CodeFieldArray arr,
    Map data
){

  _LookupTy(String fullName) {
    try {
      return availTy.firstWhere((e) => e.fullName == fullName);
    }
    catch(e){
      throw Exception("Can't find type $fullName");
    }
  }

  for(var e in data.entries){
    var name = e.key;
    var tyName = e.value;
    var type = _LookupTy(tyName);
    arr.AddField(CodeField(name)..type = type);
  }
}

void FillShaderFnSkeleton(
    ShaderEditorEnv env,
    ShaderNodeSerializer serializer,
    ShaderFunction fn,
    Map<String, dynamic> data
){
  var analyzer = ShaderFnAnalyzer();
  analyzer.env = env;
  analyzer.whichFn = fn;
  var tyAvail = ShaderTypes.values;
  _FillFieldArray(tyAvail, fn.args, data["args"]);

  var rn = data["returnType"];
  try {
    var retTy = tyAvail.firstWhere(
      (e) => e.fullName == rn
    );
    fn.returnType.value = retTy;
  }
  catch(e){
    throw Exception("Can't find type $rn");
  }

  fn.entry = serializer.Deserialize(data["entry"], analyzer)
    as ShaderRetNode
  ;
  List bodyData = data["body"];
  for(var bd in bodyData){
    var node = serializer.Deserialize(bd, analyzer);
    fn.body.add(node);
  }
  var allNodes = <ShaderGraphNode>[fn.root!] + fn.body;
  for(var n in allNodes){
    n.Update();
  }
  var serializedLinks = data["links"];
  List<LinkNotation> lnks = [];
  for(var e in serializedLinks) {
    var n = LinkNotation(e["from"], e["fromSlot"], e["to"], e["toSlot"]);
    lnks.add(n);
  }
  DeserializeLink(allNodes, lnks);
  analyzer.AnalyzeFn();
  analyzer.Dispose();
}
