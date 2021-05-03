
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:infcanvas/utilities/scripting/graph_compiler.dart';
import 'package:infcanvas/widgets/scripting/vm_graphnodes.dart';
import 'package:infcanvas/utilities/scripting/opcodes.dart';
import 'package:infcanvas/utilities/scripting/script_graph.dart';
import 'package:infcanvas/utilities/scripting/vm_types.dart';
import 'package:infcanvas/widgets/functional/editor_widgets.dart';
import 'package:infcanvas/widgets/scripting/class_inspector.dart';
import 'package:infcanvas/widgets/scripting/codepage.dart';
import 'package:infcanvas/widgets/scripting/lib_inspector.dart';
import 'package:infcanvas/widgets/scripting/libreg_inspector.dart';
import 'package:infcanvas/widgets/scripting/shader_editor.dart';
import 'package:infcanvas/widgets/scripting/shader_graphnodes.dart';
import 'package:infcanvas/widgets/scripting/shaderlib_inspector.dart';

import 'vm_editor_data.dart';

class BrushPipeTU extends SeqNodeTU{

  @override
  void Translate(VMGraphCompileContext ctx){
    var node = fromWhichNode as GNBrushPipelineAddStage;

    for(var u in node.shaderUniforms){
      AddDep(u, ctx);
    }

    for(var u in node.shaderSamplers){
      AddDep(u, ctx);
    }

    int shaderID = node.data.RegisterStage(node.shader);
    ctx.EmitCode(SimpleCB([InstLine(OpCode.PUSHIMM, i:shaderID)]));
    AddDep(node.pipeIn, ctx);
    ctx.EmitCode(SimpleCB([
      InstLine(OpCode.d_embed, s:"RenderPipeline|PipelineBuilder|AddStage")
    ]));
    ctx.EmitCode(SeqOutputHanderCB());
    ctx.AddNextExec(node.execOut.link?.to.node);
  }

  @override
  int ReportStackUsage() => 1;
}

class GNBrushPipelineAddStage extends GraphNode with GNPainterMixin{
  EditorBrushData data;
  ShaderRef? shader;

  late ExecInSlotInfo execIn = ExecInSlotInfo(this);
  late ValueInSlotInfo pipeIn 
    = ValueInSlotInfo(this, "Pipeline", "RenderPipeline|PipelineBuilder");
  late ExecOutSlotInfo execOut = ExecOutSlotInfo(this);
  late ValueOutSlotInfo stageOut
    = ValueOutSlotInfo(this, "Output", "RenderPipeline|TexEntry", 0);

  List<ValueInSlotInfo> shaderUniforms = [];
  List<ValueInSlotInfo> shaderSamplers = [];

  @override List<InSlotInfo> get inSlot => [
    execIn, pipeIn
  ] + shaderUniforms + shaderSamplers;

  @override List<OutSlotInfo> get outSlot=>[ execOut, stageOut ];

  GNBrushPipelineAddStage(this.data){
    displayName = "Add Pipeline Stage";
  }

  void Update(){
    EditorShaderData? shaderData;
    if(shader != null){
      shaderData = data._shaderLib.LookupShader(shader!);
    }
    UpdateUniformInput(shaderData);
  }

  String MapType(ShaderValType ty){
    switch(ty){
      
      case ShaderValType.tex: return "RenderPipeline|TexEntry";
      case ShaderValType.float: return "Num|Float";
      case ShaderValType.float2: return "Vec|Vec2";
      case ShaderValType.float3: return "Vec|Vec3";
      case ShaderValType.float4: return "Vec|Vec4";
    }
  }

  void UpdateUniformInput(EditorShaderData? data){
    if(data == null){
      for(var i in shaderUniforms)i.Disconnect();
      shaderUniforms.clear();
      return;
    }
    
    //Sort samplers and uniforms
    var uniformIdx = [];
    var samplerIdx = [];

    //First arg of suitable shaders should be in main function signature
    for(int i = 1; i < data.argName.length; i++){
      if(data.argType[i] == ShaderValType.tex){
        samplerIdx.add(i);
      }else{
        uniformIdx.add(i);
      }
    }
    _ProcessArg(idx, slots){
      int cnt = idx.length;

      for(int i = cnt; i < slots.length;i++){
        slots.last.Disconnect();
        slots.removeLast();
      }

      for(int i = 0; i < cnt; i++){
        int argIdx = idx[i];
        var newType = MapType(data.argType[argIdx]);
        var newName = data.argName[argIdx];
        if(i >= slots.length){
          slots.add(ValueInSlotInfo(this, newName, newType));
        }else{
          var slot = slots[i];
          var oldType = slot.type;
          if(!this.data._brushEnv.IsSubTypeOf(oldType, newType)){
            slot.Disconnect();
          }
          slot.type = newType;
          slot.name = newName;
        }
      }
    }
    _ProcessArg(uniformIdx, shaderUniforms);
    _ProcessArg(samplerIdx, shaderSamplers);
  }

  @override
  GraphNode Clone() {
    return GNBrushPipelineAddStage(data)..shader = this.shader;
  }

  @override
  VMNodeTranslationUnit doCreateTU() {
    return BrushPipeTU();
  }

  @override
  bool get needsExplicitExec => true;

  List<ShaderRef> AvaliShaders(){
    var lib = data._shaderLib;
    return[
      for(var shader in lib.shaders)
        if(shader.IsSuitableForEntry())
          ShaderRef(lib.name, shader.name)
    ];
  }

  @override
  Widget Draw(BuildContext context, void Function() update){
    var body = super.Draw(context, update);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 30,
          child: SelectionPropEditor<ShaderRef>(
            initialValue: shader,
            requestSelections: AvaliShaders, 
            onSelect: (newRef){
              if(SetShader(newRef)){
                Update();
                update();
              }
            }
          ),
        ),
        body
      ],
    );
  }

  //Return if old is different from new
  bool SetShader(ShaderRef? newRef){
    shader = newRef;
    if(newRef == null || shader == null){
      return shader == null;
    }

    if(newRef.libName == shader!.libName 
    && newRef.shaderName == shader!.shaderName) return true;
    return false;
  }

}

class BrushEnv extends VMEnv{
  EditorBrushData brushData;
  static late final List<VMLibInfo> brushBuiltins = VMRTLibs.RuntimeLibs + [VMRTLibs.RenderPipeline()];
  BrushEnv(this.brushData);

  @override
  Iterable<NodeSearchInfo> FindMatchingNode(String? argType, String? retType)
  sync*
  {
    yield* super.FindMatchingNode(argType, retType);

    var _match = (node, cat){
      return MatchGraphNode(
        node, cat, IsSubTypeOf,
        argType, retType
      );
    };

    var pipeNodes = [
      GNBrushPipelineAddStage(brushData)
    ];

    for(var n in pipeNodes){
      var result = _match(n, "Rendering");
      if(result != null) yield result;
    }

  }

  @override
  void Reset(){
    super.Reset();
    AddLibs(brushBuiltins);
  }

}

class EditorBrushData {

  String name;
  PipelineDesc? desc;
  String? errMsg;

  ///Main program
  late EditorLibData _brushProg;
  late BrushEnv _brushEnv;

  ///Program dependencies
  late LibRegistery _deps;

  ///Shader registry
  late ShaderLib _shaderLib;
  
  bool IsValid(){
    return desc!=null;
  }

  EditorBrushData.createNew(this.name, {
    Iterable<VMLibInfo> builtinLibs = const {}
  }){
    _shaderLib = ShaderLib("MainShaderLib");

    VMMethodInfo mtdOnLoad = VMMethodInfo("OnLoad")..isStaticMethod = true;
    VMMethodInfo mtdOnPaintBegin = VMMethodInfo("OnPaintBegin");
    VMMethodInfo mtdOnPaintEnd = VMMethodInfo("OnPaintEnd");
    VMMethodInfo mtdOnPaintUpdate = VMMethodInfo("OnPaintUpdate");
    {
      var arg = mtdOnPaintUpdate.Args();
      /*Pipeline      */ arg.AddField("Pipeline",   "RenderPipeline|PipelineBuilder");
      /*Background Tex*/ arg.AddField("Background", "RenderPipeline|TexEntry");
      /*Brush size    */ arg.AddField("Size",       "Vec|Vec2");  
      /*Position      */ arg.AddField("Position",   "Vec|Vec2");  
      /*Speed         */ arg.AddField("Speed",      "Vec|Vec2");     
      /*Tilt          */ arg.AddField("Tilt",       "Vec|Vec2");      
      /*Pressure      */ arg.AddField("Pressure",   "Num|Float");

      var ret = mtdOnPaintUpdate.Rets();
      /*Pipeline output*/ ret.AddField("Pipeline Output", "RenderPipeline|TexEntry");
    }
    //TODO: Infinite recursion detection? or timed execution?
    VMLibInfo mainLib = VMLibInfo("");
    VMClassInfo mainProg = VMClassInfo("EventGraph")
          ..AddMethod(mtdOnLoad)
          ..AddMethod(mtdOnPaintBegin)
          ..AddMethod(mtdOnPaintEnd)
          ..AddMethod(mtdOnPaintUpdate)
      ;

    _deps = LibRegistery();
    _brushEnv = BrushEnv(this);
    _brushEnv.AddLibrary(mainLib);
    _brushProg = EditorLibData(_brushEnv,mainLib);
    _brushProg.AddType(mainProg);
  }

  void ReloadBrushEnv(){
    _brushEnv.Reset();
    _brushEnv.AddLibrary(_brushProg.lib);
    _brushEnv.AddLibs(_deps.LoadedLibs());
  }

  List<ShaderRef> _pipeStages = [];

  ///[Result, errMessage]
  List PackageBrush(){
    var res = _PackageBrush();
    desc = res.first;
    errMsg = res.last;
    return res;
  }
  List _PackageBrush(){
    //Build deps
    for(var d in _deps.editableLibs){
      d.Compile();
      if(!d.IsValid()) return [null, "Lib compilation failed: ${d.lib.name}"];
    }

    //Event graph, also the stage shader list
    _pipeStages.clear();
    _brushProg.Compile();
    if(!_brushProg.IsValid()) return[null, "Event graph compilation failed"];

    //Package shaders
    List<ShaderProgram> shaders = [];
    for(var s in _pipeStages){
      var shader = _shaderLib.LookupShader(s);
      if(shader == null) return [null, "Shader not found: ${s.libName}|${s.shaderName}"];
      var result = shader.LinkAsPipelineStage();
      if(result.first == null) return [null, result.last];
      var compiled = ShaderProgram(result.first!);
      if(!compiled.IsProgramValid()) return[null, compiled.GetProgramStatus()];
      shaders.add(compiled);
    }

    var prog = _brushEnv.LoadedLibs().toList();
    var desc = PipelineDesc()
      ..installedLibs = prog
      ..installedShaders = shaders
      ;
    return[desc, null];

  }

  int RegisterStage(ShaderRef? shader) {
    if(shader == null) return -1;
    int id = _pipeStages.length;
    _pipeStages.add(shader);
    return id;
  }

}

class BrushEditor extends StatefulWidget{

  final EditorBrushData data;

  BrushEditor(this.data);

  @override
  State<StatefulWidget> createState() => _BrushEditorState();
  
}

class _BrushEditorState extends State<BrushEditor>{
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children:[
              Expanded(
                child: Text(widget.data.name,
                  style: Theme.of(context).textTheme.headline4,
                ),
              ),
              TextButton(
                onPressed: (){
                  Navigator.of(context).pop();
                },
                child: Icon(Icons.close)
              )
            ],
          ),

          ElevatedButton(
            onPressed:ShowEventGraphEditor, 
            child: Text("Edit Event Graph")
          ),
          TextButton(
            onPressed:ShowVMGraphEditor, 
            child: Text("Edit Dependencies")
          ),
          TextButton(
            onPressed:ShowShaderGraphEditor, 
            child: Text("Edit Shader Library")
          ),
          Spacer(),
          ElevatedButton(
            onPressed:PackageBrush, 
            child: Text("Package Brush")
          ),
        ],
      ),
    );
  }

  void ShowEventGraphEditor(){
    var mainClass = widget.data._brushProg.clsData.single;
    Navigator.of(context).push(MaterialPageRoute(builder: 
      (ctx)=>ClassInspector(mainClass, canEditMethod: false,)
    ));
  }

  void ShowVMGraphEditor(){
    Navigator.of(context).push(MaterialPageRoute(builder: 
      (ctx)=>LibRegInspector(widget.data._deps)
    ));
  }

  void ShowShaderGraphEditor(){
    Navigator.of(context).push(MaterialPageRoute(builder: 
      (ctx)=>ShaderLibInspector(widget.data._shaderLib)
    ));
  }

  void PackageBrush(){
    var res = widget.data.PackageBrush();
    PipelineDesc? desc = res.first;
    String? errMsg = res.last;
  }

}
