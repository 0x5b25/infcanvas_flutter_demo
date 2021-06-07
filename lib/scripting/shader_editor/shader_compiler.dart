
import 'package:infcanvas/scripting/graph_compiler.dart';
import 'package:infcanvas/scripting/shader_editor/shader_codemodel.dart';
import 'package:infcanvas/scripting/shader_editor/shader_method_nodes.dart';


class ShaderRef{
  String libName;
  String shaderName;
  ShaderRef(this.libName, this.shaderName);

  @override
  String toString()=>"$libName|$shaderName";

  @override
  int get hashCode => libName.hashCode ^ shaderName.hashCode;

  @override
  bool operator== (Object other){
    if(other.runtimeType != runtimeType) return false;
    if(other.hashCode != hashCode) return false;
    var ref = other as ShaderRef;
    return (
        ref.libName == libName &&
            ref.shaderName == shaderName
    );
  }
}


abstract class ShaderNodeTranslationUnit extends NodeTranslationUnit{

  String get retType;

  @override
  void Translate(ShaderGraphCompileContext ctx) {

  }

  String? GetValName()=>null;

}

class ShaderGraphCompileContext extends GraphCompileContext{

  ///Keeps track of assigned variable names
  Map<ShaderGraphNode, ShaderNodeTranslationUnit> _visited = {};
  List<String> src = [];
  List<ShaderGraphNode> srcMap = [];

  List<ShaderRef> refs = [];

  ///Return variable name of return value
  String AddValueDependency(ShaderGraphNode from){
    var v = _visited[from];
    if(v != null) {
      var valName = v.GetValName();
      if(valName != null) return valName;
      return _assignedNames[v]!;
    }
    return TranslateNode(from);
  }

  Map<ShaderNodeTranslationUnit, String> _assignedNames = {};
  String TranslateNode(ShaderGraphNode which){
    var tu = which.CreateTranslationUnit() as ShaderNodeTranslationUnit;

    int id = _visited.length;
    String nodeName = which.displayName;
    String retType = tu.retType;

    String valName = "NODE$id";
    valName = valName.replaceAll(RegExp(r'((^[0-9]+)|[^\w]|(\s))+'), '_');
    _assignedNames[tu] = valName;

    _visited[which] = tu;

    workingList.add(tu);

    tu.Translate(this);

    workingList.removeLast();

    return tu.GetValName()??valName;
  }

  void EmitCode(String line){
    srcMap.add(currentTU.fromWhichNode as ShaderGraphNode);
    src.add(line);
  }

  String AssignedName(){
    return _assignedNames[currentTU]!;
  }

  void RefShader(String fullName){
    var segs = fullName.split('|');
    var lib = segs.first;
    var name = segs.last;
    for(var r in refs){
      if(r.libName == lib && r.shaderName == name) return;
    }

    refs.add(ShaderRef(lib, name));
  }

}

class ShaderGraphCompiler{

}


class CompiledShaderBody{
  final ShaderFunction from;
  final String src;
  final List<ShaderRef> shaderRefs;

  const CompiledShaderBody(
    this.from, this.src, this.shaderRefs
  );
}

///[compiledBody, Err]
List CompileShaderBody(ShaderFunction s) {
  var ctx = ShaderGraphCompileContext();
  ctx.TranslateNode(s.root);
  s.nodeMessage = ctx.errMsg.map(
    (key, value) => MapEntry(key as ShaderGraphNode, value)
  );
  if(ctx.hasErr) return [null, "Shader function ${s.fullName} has error"];
  var buf = StringBuffer();
  for(var line in ctx.src){
    buf.writeln("  $line");
  }
  return [CompiledShaderBody(s, buf.toString(), ctx.refs), null];
}

///[Src, Err]
List<String?> LinkShader(ShaderFunction s){

  if(!s.IsRetSuitableForEntry()){
    return[
      null, "Return type should either be float or float4"
    ];
  }

  List<ShaderFunction> linkOrder = [];
  Map<ShaderFunction, CompiledShaderBody> visited = {};
  List<ShaderFunction> workingList = [];
  String errMsg = "";
  _ProcessNode(ShaderFunction n){
    if(visited.containsKey(n)) return true;

    if(workingList.contains(n)){
      //Loop in the graph
      errMsg = "Cyclic dependencies: ${workingList.last.name} -> ${n.name}";
      return false;
    }

    var cb = CompileShaderBody(n);
    if(cb.last != null) {
      errMsg = cb.last;
      return false;
    }

    workingList.add(n);
    CompiledShaderBody cf = cb.first;
    visited[n] = cf;
    for(var neigh in cf.shaderRefs){
      if(_ProcessNode(s) == false) return false;
    }
    //Should be the last node after all function returns
    workingList.removeLast();
    linkOrder.add(n);
    return true;
  }

  //Get compilation orders
  if(!_ProcessNode(s))
    return[
      null, errMsg
    ];
  assert(linkOrder.last == s);

  //Compile functions

  String linked = "";

  //argument
  for(int i = 0; i < s.args.fields.length;i++){
    var f =  s.args.fields[i];
    var ty = f.type!.fullName;
    var nm = f.name.value;
    linked += "uniform $ty $nm;\n";
  }
  linked += "\n";
  //Insert functions
  for(int i = 0; i < linkOrder.length - 1; i++){
    var fn = visited[linkOrder[i]]!.src;
    linked += fn;
    linked += "\n";
  }

  //Insert main
  var mainBody = visited[linkOrder.last]!.src;
  linked += "float4 main(){\n"
      + mainBody
      +"}\n";

  return[linked, null];
}
