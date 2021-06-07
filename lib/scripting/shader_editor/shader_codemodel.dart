
import 'package:infcanvas/scripting/script_graph.dart';
import 'package:infcanvas/scripting/editor/codemodel.dart';
import 'package:infcanvas/scripting/editor/codemodel_events.dart';
import 'package:infcanvas/scripting/code_element.dart';
import 'package:infcanvas/scripting/editor/vm_method_nodes.dart';
import 'package:infcanvas/scripting/shader_editor/shader_builtin_nodes.dart';
import 'package:infcanvas/scripting/shader_editor/shader_method_nodes.dart';

class ShaderType extends CodeType{
  @override bool get editable => false;

  final Set<ShaderType> compatibleTypes;
  final bool isOpaque;

  ShaderType(String name,
      [
        Set<ShaderType>? compatibleTypes,
        this.isOpaque = false
      ]
    )
    : this.compatibleTypes = compatibleTypes??{}
  {
    this.name.value = name;
  }

  @override get fullName=>name.value;

  @override IsSubTypeOf(ty){
    if(ty == null) return false;
    if(this == ty) return true;
    return compatibleTypes.contains(ty);
  }
}

class ShaderTypes{
  static late final shader = ShaderType("shader", {}, true);
  static late final float = ShaderType("float", {float2, float3, float4}, false);
  static late final float2 = ShaderType("float2", {}, false);
  static late final float3 = ShaderType("float3", {}, false);
  static late final float4 = ShaderType("float4", {}, false);

  static ShaderType? Str2Type(String ty){
    if(ty == shader.fullName) return shader;
    if(ty == float.fullName) return float;
    if(ty == float2.fullName) return float2;
    if(ty == float3.fullName) return float3;
    if(ty == float4.fullName) return float4;
  }

  static late final List<ShaderType> values = [
    shader, float, float2, float3, float4
  ];
}

class ShaderLibChangeEvent extends CodeElementChangeEvent{
  late ShaderLib whichLib;
}

class ShaderLibRenameEvent extends ShaderLibChangeEvent{
  String oldName, newName;
  ShaderLibRenameEvent(this.oldName, this.newName);
}

class ShaderLibFunctionAddEvent extends ShaderLibChangeEvent{
  ShaderFunction fn;
  ShaderLibFunctionAddEvent(this.fn);
}

class ShaderLibFunctionRemoveEvent extends ShaderLibChangeEvent{
  ShaderFunction fn;
  ShaderLibFunctionRemoveEvent(this.fn);
}

class ShaderFunctionChangeEvent extends ShaderLibChangeEvent{
  late ShaderFunction whichFunction;
}

class ShaderFnBodyChangeEvent extends ShaderFunctionChangeEvent{}

class ShaderFunctionRetTypeChangeEvent extends ShaderFunctionChangeEvent{
  ShaderType oldType, newType;
  ShaderFunctionRetTypeChangeEvent(this.oldType, this.newType);
}
class ShaderFunctionArgTypeChangeEvent extends ShaderFunctionChangeEvent{

  ShaderFunctionArgTypeChangeEvent(Event origEvt){
    this.originalEvent = origEvt;
  }
}

class ShaderLib extends CodeElement{

  final Set<ShaderFunction> functions = {};

  @override
  ShaderLibRenameEvent OnRename(o, n){
    return ShaderLibRenameEvent(o, n);
  }

  void _RemoveFn(ShaderFunction fn){
    var removed = functions.remove(fn);
    if(removed){
      SendEventAlongChain(ShaderLibFunctionRemoveEvent(fn));
    }
  }

  void AddFn(ShaderFunction fn){
    var added = functions.add(fn);
    if(added){
      fn.parentScope = this;
      SendEventAlongChain(ShaderLibFunctionAddEvent(fn));
    }
  }

  @override FillEvent(ShaderLibChangeEvent e){
    e.whichLib = this;
  }

  @override
  void DisposeElement(){
    for(var m in functions){
      m.DisposeElement();
    }
    super.DisposeElement();
  }

}

class ShaderFunction extends CodeElement{

  ShaderLib? get library => parentScope as ShaderLib?;

  late final CodeElementProperty<ShaderType> returnType
    = CodeElementProperty(ShaderTypes.float4, this,
      (o, n)=>ShaderFunctionRetTypeChangeEvent(o, n)
    )
  ;

  late final args
    = CodeFieldArray()
      ..parentScope = this
      ..name.value = "arguments"
      ..evtForwarder = (e){
        var evt = ShaderFunctionArgTypeChangeEvent(e);
        SendEventAlongChain(evt);
      }
    ;

  @override FillEvent(ShaderFunctionChangeEvent e){
    e.whichFunction = this;
  }

  Map<ShaderGraphNode, List<String>> nodeMessage = {};

  late ShaderRetNode entry = ShaderRetNode(this);
  get root => entry;
  List<ShaderGraphNode> body = [];


  //bool IsArgSuitableForEntry(){
  //  //Check signature first
  //  var argList = args.fields;
  //  return (
  //      argList.length > 0
  //          &&argList.first.type == ShaderTypes.float2
  //  );
  //}

  bool IsRetSuitableForEntry(){
    var retTy = returnType.value;
    return retTy.IsSubTypeOf(ShaderTypes.float4);
  }

  bool IsSuitableForEntry(){
    return IsRetSuitableForEntry();
  }

  bool IsSuitableForEmbedding(){
    for(var f in args.fields){
      if(f.type == null) return false;
      var ty = f.type as ShaderType;
      if(ty.isOpaque) return false;
    }
    return true;
  }

  @override Dispose(){
    library?._RemoveFn(this);
    super.Dispose();
  }

}
