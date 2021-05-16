
import 'package:infcanvas/scripting/editor/codemodel.dart';
import 'package:infcanvas/scripting/editor/vm_editor.dart';
import 'package:infcanvas/scripting/editor/vm_method_nodes.dart';
import 'package:infcanvas/scripting/editor/vm_node_serializer.dart';
import 'package:infcanvas/scripting/graphlink_serializer.dart';

Map<String, String> Field2Map(CodeFieldArray f)=>
    Map.fromIterable(f.fields,
        key: (e) => e.name.value,
        value: (e) => e.type.fullName
    );

Map<String, dynamic> SerializeCodeLibrary(
  VMNodeSerializer serializer,
  CodeLibrary lib
){
  Map<String ,dynamic> map = {};

  map["libName"] = lib.name.value;
  map["dependencies"] = lib.deps.map((e) => e.name.value).toList();
  map["types"] = lib.types.map((e) => SerializeCodeType(serializer,e)).toList();

  return map;
}


Map<String, dynamic> SerializeCodeType(
    VMNodeSerializer serializer,
    CodeType type
) {
  Map<String ,dynamic> map = {};

  map["typeName"] = type.name.value;
  map["refType"] = type.isRef.value;
  map["fields"] = Field2Map(type.fields);
  map["staticFields"] = Field2Map(type.staticFields);

  map["methods"] = type.methods.map(
    (e) => SerializeMethod(serializer, e as CodeMethod)
  ).toList();

  return map;
}


Map<String, dynamic> SerializeMethod(
    VMNodeSerializer serializer,
    CodeMethod m
) {
  Map<String ,dynamic> map = {};

  map["methodName"] = m.name.value;
  map["static"] = m.isStatic.value;
  map["const"] = m.isConst.value;
  map["args"] = Field2Map(m.args);
  map["returns"] = Field2Map(m.rets);
  map["entry"] = serializer.Serialize( m.root! );
  map["body"] = m.body.map((e) => serializer.Serialize(e)).toList();
  var allNodes = <CodeGraphNode>[m.root!] + m.body;
  var serializedLinks = SerializeLink(allNodes);
  map["links"] = serializedLinks.map((e) => {
    "from":e.from,
    "fromSlot":e.fromSlot,
    "to":e.to,
    "toSlot":e.toSlot
  }).toList();
  return map;
}


CodeLibrary CreateLibSkeleton(Map<String, dynamic> data){
  var lib = CodeLibrary();
  lib.name.value = data["libName"];
  for(var typeData in data["types"]){
    lib.AddType(CreateTypeSkeleton(typeData));
  }

  return lib;
}

CodeType CreateTypeSkeleton(Map<String, dynamic> data){
  var type = CodeType();
  type.name.value = data["typeName"];
  type.isRef.value = data["refType"];
  for(var methodData in data["methods"]){
    type.AddMethod(CreateMethodSkeleton(methodData));
  }
  return type;
}

CodeMethod CreateMethodSkeleton(Map<String, dynamic> data){
  var method = CodeMethod();
  method.name.value = data["methodName"];
  method.isStatic.value = data["static"];
  method.isConst.value = data["const"];
  return method;
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

void FillLibSkeleton(
    VMEditorEnv env,
    VMNodeSerializer serializer,
    CodeLibrary lib,
    Map<String, dynamic> data
){
  var depNames = data["dependencies"];
  var libAvail = env.LoadedLibs();
  for(var name in depNames){
    var dep = libAvail.firstWhere((e) => e.name.value == name);
    lib.AddDep(dep);
  }

  var typeData = data["types"];
  var typeSkeleton = lib.types.toList();
  //Align
  MatchLists(
    typeData,
    typeSkeleton,
    (dynamic data,CodeType ty)=>ty.name.value == data["typeName"]
  );
  for(int i = 0; i < typeSkeleton.length;i++)
    FillTypeSkeleton(env,serializer,typeSkeleton[i], typeData[i]);
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

void FillTypeSkeleton(
    VMEditorEnv env,
    VMNodeSerializer serializer,
    CodeType type,
    Map<String, dynamic> data
){
  var tyAvail = env.AccessableTypes(type);
  _FillFieldArray(tyAvail, type.staticFields, data["staticFields"]);
  _FillFieldArray(tyAvail, type.fields, data["fields"]);

  var mtdData = data["methods"];
  var mtdSkeleton = type.methods.toList();
  //Align
  MatchLists(
      mtdData,
      mtdSkeleton,
          (dynamic data,CodeMethodBase mtd)=>mtd.name.value == data["methodName"]
  );
  for(int i = 0; i < mtdSkeleton.length;i++)
    FillMethodSkeleton(
        env,
        serializer,
        mtdSkeleton[i] as CodeMethod,
        mtdData[i]
    );
}


void FillMethodSkeleton(
    VMEditorEnv env,
    VMNodeSerializer serializer,
    CodeMethod mtd,
    Map<String, dynamic> data
){
  var analyzer = VMMethodAnalyzer();
  analyzer.env = env;
  analyzer.whichMethod = mtd;
  var tyAvail = analyzer.AccessableTypes();
  _FillFieldArray(tyAvail, mtd.args, data["args"]);
  _FillFieldArray(tyAvail, mtd.rets, data["returns"]);

  mtd.root = serializer.Deserialize(data["entry"], analyzer);
  List bodyData = data["body"];
  for(var bd in bodyData){
    var node = serializer.Deserialize(bd, analyzer);
    mtd.body.add(node);
  }
  var allNodes = <CodeGraphNode>[mtd.root!] + mtd.body;
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

  analyzer.FullyAnalyzeMethod();
  analyzer.Dispose();

}
