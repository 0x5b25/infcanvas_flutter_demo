
import 'package:infcanvas/scripting/editor/codemodel.dart';
import 'package:infcanvas/scripting/editor/vm_editor.dart';
import 'package:infcanvas/scripting/editor/vm_method_nodes.dart';

class VMNodeSerializer {

  Map<String, dynamic> Serialize(CodeGraphNode node) {
    var map = <String, dynamic>{};

    map["tag"] = node.UniqueTag();
    map["position_x"] = node.ctrl.dx;
    map["position_y"] = node.ctrl.dy;

    var data = doSerializeNode(node);
    if (data != null) {
      map["data"] = data;
    }

    return map;
  }

  dynamic doSerializeNode(CodeGraphNode node){
    var fn = _serializeFn[node.runtimeType];
    if (fn != null) {
      return fn(node);
    }
  }

  CodeGraphNode Deserialize(
      Map<String, dynamic> data,
      VMMethodAnalyzer analyzer,
  ) {
    var tag = data["tag"];
    double position_x = data["position_x"];
    double position_y = data["position_y"];
    var nodeData = data["data"] ?? null;


    CodeGraphNode node = doDeserializeNode(tag, analyzer, nodeData);
    node.ctrl.dx = position_x;
    node.ctrl.dy = position_y;
    return node;
  }

  CodeGraphNode doDeserializeNode(
      tag,
      VMMethodAnalyzer analyzer,
      data,
  ){
    var fn = _deserializeFn[tag];
    if (fn == null) {
      throw Exception("Unknown tag $tag");
    }

    return fn(analyzer, data);
  }
}

Map _serializeFn = {
  ConstIntNode        :Ser_ConstIntNode,
  ConstFloatNode      :Ser_ConstFloatNode,
  InstantiateNode     :Ser_InstantiateNode,
  ConstructNode       :Ser_ConstructNode,
  CodeInvokeNode      :Ser_CodeInvokeNode,
  CodeFieldGetterNode :Ser_CodeFGNode,
  CodeFieldSetterNode :Ser_CodeFSNode,
  CodeSequenceNode    :Ser_CodeSeqNode,
};
Map _deserializeFn = {
  "ConstIntNode"       :Des_ConstIntNode,
  "ConstFloatNode"     :Des_ConstFloatNode,
  "InstantiateNode"    :Des_InstantiateNode,
  "ConstructNode"      :Des_ConstructNode,
  "CodeEntryNode"      :Des_CodeEntryNode,
  "CodeReturnNode"     :Des_CodeReturnNode,
  "CodeInvokeNode"     :Des_CodeInvokeNode,
  "CodeFieldGetterNode":Des_CodeFGNode,
  "CodeFieldSetterNode":Des_CodeFSNode,
  "CodeThisGetterNode" :Des_CodeThisGetterNode,
  "CodeIfNode"         :Des_CodeIfNode,
  "CodeSequenceNode"   :Des_CodeSeqNode,
};

/*
CodeGraphNode Des_NodeName(
    VMMethodAnalyzer analyzer,
    data,
    ){

}

Ser_NodeName(
    CodeGraphNode node
    ){

}*/

//const float, const int

Des_ConstIntNode(analyzer, data,){ return ConstIntNode()..val = data;}
Ser_ConstIntNode(node){ return node.val;}

Des_ConstFloatNode(analyzer, data,){ return ConstFloatNode()..val = data;}
Ser_ConstFloatNode(node){ return node.val;}
//Instantiate, construct

Des_InstantiateNode(VMMethodAnalyzer analyzer,String data,){
  var ty = analyzer.AccessableTypes().firstWhere((e) => e.fullName == data);
  return InstantiateNode(ty);
}
Ser_InstantiateNode(InstantiateNode node){ return node.type.fullName;}

Des_ConstructNode(VMMethodAnalyzer analyzer,String data,){
  var ty = analyzer.AccessableTypes().firstWhere((e) => e.fullName == data);
  return ConstructNode(ty);
}
Ser_ConstructNode(ConstructNode node){ return node.type.fullName;}

//entry, return

Des_CodeEntryNode(VMMethodAnalyzer analyzer,data,){
  return CodeEntryNode(analyzer.whichMethod!);
}

Des_CodeReturnNode(VMMethodAnalyzer analyzer,data,){
  return CodeReturnNode(analyzer.whichMethod!);
}

//invoke
_FindType(VMMethodAnalyzer analyzer,String libname, String typename){
  var libs = analyzer.AccessableLibs();
  for(var lib in libs){
    if(lib.name.value == libname){
      for(var ty in lib.types){
        if(ty.name.value == typename){
          return ty;
        }
      }
    }
  }
  throw Exception("Type $libname|$typename not found");
}

Des_CodeInvokeNode(VMMethodAnalyzer analyzer,String data,){
  var path = data.split("|");
  var libs = analyzer.AccessableLibs();
  var ty = _FindType(analyzer, path[0], path[1]);
  for(var m in ty.methods){
    if(m.name.value == path[2]){
      return CodeInvokeNode(m);
    }
  }
  throw Exception("Method $data not found");
}
Ser_CodeInvokeNode(CodeInvokeNode node){ return node.whichMethod.fullName;}
//field getter, field setter ,this getter

FieldDesc _FindField(analyzer, data){
  var isStatic = data["static"];
  var target = data["target"];
  var fieldName = data["name"];
  var path = target.split("|");
  var ty = _FindType(analyzer, path[0], path[1]) as CodeType;
  var fields = isStatic? ty.staticFields: ty.fields;
  for(var f in fields.fields){
    if(f.name.value == fieldName){
      return FieldDesc(ty, f);
    }
  }
  throw Exception("Field $ty|${isStatic?'static ':''}$data not found");
}

Map<String, dynamic> _SerializeFieldDesc(FieldDesc desc){
  return {
    "static":desc.isStatic,
    "target":desc.whichField.parentScope!.fullName,
    "name":desc.whichField.name.value,
  };
}

Des_CodeFGNode(VMMethodAnalyzer analyzer,Map<String, dynamic> data,){
  var f = _FindField(analyzer, data);
  return CodeFieldGetterNode(f);
}
Ser_CodeFGNode(CodeFieldGetterNode node){
  var desc = node.whichField;
  return _SerializeFieldDesc(desc);
}

Des_CodeFSNode(VMMethodAnalyzer analyzer,Map<String, dynamic> data,){
  var f = _FindField(analyzer, data);
  return CodeFieldSetterNode(f);
}
Ser_CodeFSNode(CodeFieldSetterNode node){
  var desc = node.whichField;
  return _SerializeFieldDesc(desc);
}

Des_CodeThisGetterNode(VMMethodAnalyzer analyzer,data,){
  return CodeThisGetterNode(analyzer.whichMethod!);
}

//If node, sequence node

Des_CodeIfNode(VMMethodAnalyzer analyzer,data,){
  return CodeIfNode();
}


Des_CodeSeqNode(VMMethodAnalyzer analyzer,int data,){
  return CodeSequenceNode()..SetSeqCnt(data);
}
Ser_CodeSeqNode(CodeSequenceNode node){
  return node.seqCnt;
}

