

import 'package:infcanvas/scripting/graph_compiler.dart';
import 'package:infcanvas/scripting/script_graph.dart';
import 'package:infcanvas/scripting/codepage.dart';
import 'package:infcanvas/scripting/editor/codemodel.dart';
import 'package:infcanvas/scripting/editor/vm_method_nodes.dart';
import 'package:infcanvas/scripting/shader_editor/shader_codemodel.dart';
import 'package:infcanvas/scripting/shader_editor/shader_compiler.dart';
import 'package:infcanvas/scripting/shader_editor/shader_editor.dart';

class ArgField{
  final ShaderType type;
  final String name;
  const ArgField(this.type, this.name);
}

class ShaderTU extends ShaderNodeTranslationUnit{
  ShaderGraphNode get node => fromWhichNode as ShaderGraphNode;

  List<ArgField> AddValDeps(ShaderGraphCompileContext ctx){
    var inputs = [
      for(int i = 0; i < fromWhichNode.inSlot.length; i++)
        ArgField(ShaderType("Unknown_ty"),"Input_$i"),
    ];

    for(int i = 0; i < fromWhichNode.inSlot.length; i++){
      var slot = fromWhichNode.inSlot[i] as ValueInSlotInfo;
      var link = slot.link;
      if(link == null){
        ctx.ReportError("Input $i is empty");
        continue;
      }
      var argType = slot.type!;

      var from = link.from as ValueOutSlotInfo;
      var valNode = from.node as ShaderGraphNode;
      var valName = ctx.AddValueDependency(from.node as ShaderGraphNode);
      var valType = valNode.retType;
      inputs[i] = ArgField(valType, valName);
    }

    return inputs;
  }

  @override
  void Translate(ShaderGraphCompileContext ctx) {

    var inputs = AddValDeps(ctx);

    var src = node.GetSrc(inputs);
    if(src  != null) {
      var assigned = ctx.AssignedName();
      ctx.EmitCode(
          "${retType} $assigned = " + src + ";"
      );
    }
  }

  @override
  String? GetValName()=>node.GetValName();

  @override get retType => node.retType.fullName;

}

abstract class ShaderGraphNode extends GraphNode with DrawableNodeMixin{

  late ShaderFunction fn;
  ShaderType get retType => fn.returnType.value;

  @override
  ShaderTU doCreateTU() {
    return ShaderTU();
  }

  @override get needsExplicitExec => false;
  bool Validate( ShaderFnAnalyzer analyzer )=>true;

  String? GetSrc(List<ArgField> args){}

  ///Ment for direct variable access, such as element accessors
  String? GetValName() => null;

  @override Clone(){
    var node = doCloneNode();
    node.fn = fn;
    return node;
  }

  ShaderGraphNode doCloneNode();

}


class ShaderRetTU extends ShaderTU{

  @override
  void Translate(ShaderGraphCompileContext ctx){
    var names = AddValDeps(ctx);
    ctx.EmitCode("return ${names.first.name};");
  }
}


class ShaderRetNode extends ShaderGraphNode{

  @override get outSlot => [];
  @override get inSlot => [retIn];

  @override get displayName => "Return";

  @override get closable => false;

  late final ValueInSlotInfo retIn;

  ShaderRetNode(ShaderFunction fn)
  {
    this.fn = fn;
    retIn = ValueInSlotInfo(this, "value", retType);
  }
  @override Update(){
    var newType = retType;
    var oldType = retIn.type;

    if(oldType == null || !oldType.IsSubTypeOf(newType)){
      retIn.Disconnect();
    }
    retIn.type = newType;
  }

  @override doCloneNode() => ShaderRetNode(fn);

  @override ShaderRetTU doCreateTU()=> ShaderRetTU();
  @override
  String GetSrc(argNames) {
    throw UnimplementedError();
  }
}

class ShaderArgGetNode extends ShaderGraphNode{

  CodeField arg;

  String get name => arg.name.value;
  ShaderType? get type => arg.type as ShaderType?;

  @override get displayName => "Get $name";

  late final argOut = ValueOutSlotInfo(this, name, type, 0);

  ShaderArgGetNode(this.arg){
  }

  @override Update(){
    argOut.type = type;
    argOut.name = name;

    super.Update();
  }

  @override
  bool Validate(analyzer){

    return !arg.isDisposed;

  }

  @override doCloneNode() => ShaderArgGetNode(arg);
  @override get retType => type!;
  @override GetValName()=>name;

  @override get inSlot => [];
  @override get outSlot => [argOut];
}

class ShaderInvokeTU extends ShaderTU{
  @override
  void Translate(ctx){
    var node  = fromWhichNode as ShaderInvokeNode;
    super.Translate(ctx);
    ctx.RefShader(node.whichFn.fullName);
  }
}

class ShaderInvokeNode extends ShaderGraphNode{

  ShaderFunction whichFn;

  @override get displayName => "Call ${whichFn.fullName}";

  String get embeddedName
    => "${fn.parentScope?.name??''}_${fn.name}";

  late final List<FieldInSlotInfo> argIn = [];
  late final ValueOutSlotInfo valOut = ValueOutSlotInfo(this, "result", retType);

  @override get inSlot => argIn;
  @override get outSlot => [valOut];

  ShaderInvokeNode(this.whichFn)
  {

  }

  @override Update(){
    AlignLists(argIn, whichFn.args.fields, (CodeField f) => FieldInSlotInfo(this,
        f));
    valOut.type = whichFn.returnType.value;

    super.Update();
  }

  @override
  bool Validate(analyzer){
    if(fn.isDisposed) return false;
    if(!fn.IsSuitableForEmbedding()) return false;
    return (analyzer.FnContainedInDeps(fn));
  }

  @override
  String? GetSrc(List<ArgField> args) {
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

    return "$embeddedName(" + arg + ")";
  }

  @override get retType => whichFn.returnType.value;

  @override
  ShaderGraphNode doCloneNode() => ShaderInvokeNode(whichFn);
}

