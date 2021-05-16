
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:infcanvas/scripting/editor/vm_opcodes.dart';
import 'package:infcanvas/scripting/graph_compiler.dart';
import 'package:infcanvas/scripting/brush_serializer.dart';
import 'package:infcanvas/scripting/editor/codemodel.dart';
import 'package:infcanvas/scripting/editor/vm_compiler.dart';
import 'package:infcanvas/scripting/editor/vm_editor.dart';
import 'package:infcanvas/scripting/editor/vm_method_nodes.dart';
import 'package:infcanvas/scripting/editor/vm_type_editor.dart';
import 'package:infcanvas/scripting/shader_editor/shader_codemodel.dart';
import 'package:infcanvas/scripting/script_graph.dart';
import 'package:infcanvas/scripting/editor/vm_types.dart';
import 'package:infcanvas/scripting/editor_widgets.dart';
import 'package:infcanvas/scripting/codepage.dart';
import 'package:infcanvas/scripting/shader_editor/shader_compiler.dart';
import 'package:infcanvas/scripting/shader_editor/shader_editor.dart';


class BrushPipeTU extends VMNodeTranslationUnit{

  @override
  void Translate(VMGraphCompileContext ctx){

    _AddDep(ValueInSlotInfo slot){
      var l = slot.link;
      if(l == null) {
        ctx.ReportError("Input can't be null");
        return -1;
      }
      var rear = l.from as ValueOutSlotInfo;
      return ctx.AddValueDependency(rear.node as CodeGraphNode, rear.outputOrder);
    }

    var node = fromWhichNode as GNBrushPipelineAddStage;

    var uniformAddrs = [
      for(var u in node.shaderUniforms)
        _AddDep(u),
    ];

    var samplerAddrs = [
      for(var u in node.shaderSamplers)
        _AddDep(u),
    ];

    int shaderID = node.data.RegisterStage(node.shader);
    var pbAddr = _AddDep(node.pipeIn);
    //TODO:Replace hard coded type names with getters from VMRTLib
    ctx.EmitCode(SimpleCB([
      for(var addr in uniformAddrs)
        InstLine(OpCode.ldarg, i:addr),
      for(var addr in samplerAddrs)
        InstLine(OpCode.ldarg, i:addr),
      InstLine(OpCode.PUSHIMM, i:shaderID),
      InstLine(OpCode.ldarg, i:pbAddr),
      InstLine(OpCode.d_embed, s:"RenderPipeline|PipelineBuilder|AddStage")
    ]));
    ctx.AddNextExec(node.execOut.link?.to.node as CodeGraphNode?);
  }

  @override
  int ReportStackUsage() => 1;
}

class GNBrushPipelineAddStage extends CodeGraphNode
  with GNPainterMixin
{
  BrushData data;
  ShaderFunction? shader;

  late ExecInSlotInfo execIn = ExecInSlotInfo(this);
  late ValueInSlotInfo pipeIn 
    = ValueInSlotInfo(this, "Pipeline", VMBuiltinTypes
        .types["RenderPipeline|PipelineBuilder"]);
  late ExecOutSlotInfo execOut = ExecOutSlotInfo(this);
  late ValueOutSlotInfo stageOut
    = ValueOutSlotInfo(this, "Output", VMBuiltinTypes
        .types["RenderPipeline|TexEntry"], 0);

  List<ValueInSlotInfo> shaderUniforms = [];
  List<ValueInSlotInfo> shaderSamplers = [];

  @override List<InSlotInfo> get inSlot => <InSlotInfo>[
    execIn, pipeIn
  ] + shaderUniforms + shaderSamplers;

  @override List<OutSlotInfo> get outSlot=>[ execOut, stageOut ];

  @override get displayName => "Add Pipeline Stage";

  GNBrushPipelineAddStage(this.data){}

  void Update(){

    if(shader == null
      || shader!.isDisposed
      || !shader!.IsSuitableForEntry()
    )
    {
      shader = null;
    }

    UpdateUniformInput(shader);
    super.Update();
  }

  CodeType? MapType(ShaderType ty){
    if(ty == ShaderTypes.float) return VMBuiltinTypes.floatType;
    if(ty == ShaderTypes.float2) return VMBuiltinTypes.types["Vec|Vec2"];
    if(ty == ShaderTypes.float3) return VMBuiltinTypes.types["Vec|Vec3"];
    if(ty == ShaderTypes.float4) return VMBuiltinTypes.types["Vec|Vec4"];
    if(ty == ShaderTypes.shader) return VMBuiltinTypes.types["RenderPipeline|TexEntry"];
  }

  void UpdateUniformInput(ShaderFunction? fn){
    if(fn == null){
      for(var i in shaderUniforms)i.Disconnect();
      shaderUniforms.clear();
      return;
    }
    
    //Sort samplers and uniforms
    var uniformIdx = [];
    var samplerIdx = [];

    //First arg of suitable shaders should be in main function signature
    for(int i = 1; i < fn.args.length; i++){
      var ty = fn.args.fields[i];
      if(ty == ShaderTypes.shader){
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
        var field = fn.args.fields[argIdx];
        var newType = MapType(field.type as ShaderType);
        var newName = field.name.value;
        if(i >= slots.length){
          slots.add(ValueInSlotInfo(this, newName, newType));
        }else{
          var slot = slots[i];
          var oldType = slot.type;
          if(!oldType.IsSubTypeOf(newType)){
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

  @override doCloneNode() {
    return GNBrushPipelineAddStage(data)..shader = this.shader;
  }

  @override
  VMNodeTranslationUnit doCreateTU() {
    return BrushPipeTU();
  }

  @override
  bool get needsExplicitExec => true;

  List<ShaderFunction> AvaliShaders(){
    var lib = data.shaderLib;
    return[
      for(var shader in lib.functions)
        if(shader.IsSuitableForEntry())
          shader
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
          child: SelectionPropEditor<ShaderFunction>(
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
  bool SetShader(ShaderFunction? newShdr){
    if(shader == newShdr) return false;
    shader = newShdr;
    return true;
  }
}

class BrushEditorEnv extends VMEditorEnv{

  //VMEditorEnv brushDeps = VMEditorEnv();

  CodeLibrary? get egLib => _brushData?.progLib;
  CodeType? get egType => _brushData?.progClass;

  BrushData? _brushData;
  BrushData? get brushData => _brushData;
  set brushData(BrushData? data){
    if(data ==_brushData) return;
    _Unload();
    if(data != null)
      _Load(data);
  }

  _Unload(){
    Clear();
    //brushDeps.Clear();
    _brushData = null;
  }

  _Load(BrushData data){
    _brushData = data;
    LoadLib(data.progLib);
    //for(var d in data.deps){
    //  brushDeps.LoadLib(d);
    //}
  }

  BrushEditorEnv(){
    debugName = "BrushEnv";
  }

  //@override LoadedLibs()sync*{
  //  if(_brushData != null)
  //    yield _brushData!.progLib;
  //  //yield* brushDeps.LoadedLibs();
  //}

  late final methodOverrides = {
    "RenderPipeline|PipelineBuilder|AddStage":
    ()=> GNBrushPipelineAddStage(this.brushData!)
  };

  @override CodeGraphNode? MapNode(CodeGraphNode which) {
    if(which is CodeInvokeNode){
      var mtd = which.whichMethod;
      var override = methodOverrides[mtd.fullName];
      return override?.call();
    }
  }


}

class BrushData {

  String name;
  PipelineDesc? desc;
  String? errMsg;

  ///Main program
  late CodeLibrary progLib;
  late CodeType progClass;

  ///Shader registry
  late ShaderLib shaderLib;

  
  bool IsValid(){
    return desc!=null;
  }

  BrushData.createNew(this.name, {
    Iterable<VMLibInfo> builtinLibs = const {}
  }){
    progLib = CodeLibrary()
      ..name.value = "";
    _ValidateBrushEventGraph();

    shaderLib = ShaderLib()..name.value = "MainShaderLib";

  }

  BrushData(this.name, this.progLib, this.shaderLib){
    _ValidateBrushEventGraph();
  }


  _CreateBrushEventGraph(){
    _NT(name) => VMBuiltinTypes.types[name];
    //Review: No randomize functions allowed: all randomize must
    //rely only on world position. i.e. repeatable
    progClass = CodeType()
      ..name.value = "EventGraph"
      ..editable = false
      ..AddMethod(
          CodeMethod()..name.value = "OnLoad"
            ..isStatic.value = true
            ..editable = false
            ..args.editable = false
            ..rets.editable = false
            ..CreateBody()
      )
      ..AddMethod(CodeMethod()..name.value = "OnPaintBegin"
        ..editable = false
        ..args.editable = false
        ..rets.editable = false
        ..CreateBody())
    //TODO:Add world position input to OnPaintBegin
      ..AddMethod(CodeMethod()..name.value = "OnPaintEnd"
        ..editable = false
        ..args.editable = false
        ..rets.editable = false
        ..CreateBody())
      ..AddMethod(CodeMethod()..name.value = "OnPaintUpdate"
          ..args.AddField(CodeField("Pipeline",      )..type=_NT("RenderPipeline|PipelineBuilder") )
          ..args.AddField(CodeField("Background",    )..type=_NT("RenderPipeline|TexEntry") )
          ..args.AddField(CodeField("Size",          )..type=_NT("Vec|Vec2") )
          ..args.AddField(CodeField("Position",      )..type=_NT("Vec|Vec2") )
          ..args.AddField(CodeField("Speed",         )..type=_NT("Vec|Vec2") )
          ..args.AddField(CodeField("Tilt",          )..type=_NT("Vec|Vec2") )
          ..args.AddField(CodeField("Pressure",      )..type=_NT("Num|Float") )
          ..rets.AddField(CodeField("Pipeline Output")..type=_NT("RenderPipeline|TexEntry") )
        ..editable = false
        ..args.editable = false
        ..rets.editable = false
        ..CreateBody()
      )
    ;
    //TODO:Add color input to OnPaintUpdate

    progLib = CodeLibrary()
      ..name.value = ""
      ..AddType(progClass)
    ;

  }

  _ValidateBrushEventGraph(){
    _NT(name) => VMBuiltinTypes.types[name];
    //Review: No randomize functions allowed: all randomize must
    //rely only on world position. i.e. repeatable
    CodeType? _progClass;
    for(var ty in progLib.types){
      if(ty.name.value == "EventGraph"){
        _progClass = ty;
      }
    }
    if(_progClass == null) {
      _progClass = CodeType()
        ..name.value = "EventGraph";
      progLib.AddType(_progClass);
    }
    _progClass
      ..editable = false;
    progClass = _progClass;
    _FindOrCreateMtd(String name){
      for(var m in _progClass!.methods){
        if(m.name.value == name) {
          m.args.fields.clear();
          m.rets.fields.clear();
          return m as CodeMethod;
        }
      }
      var m = CodeMethod()
        ..name.value = name
        ..CreateBody();
      _progClass.AddMethod(m);
      return m;
    }

    var m_OnLoad = _FindOrCreateMtd("OnLoad");
    m_OnLoad..isStatic.value = true
            ..editable = false
            ..args.editable = false
            ..rets.editable = false;
    var m_OnPaintBegin = _FindOrCreateMtd("OnPaintBegin");
    m_OnPaintBegin..editable = false
                  ..args.editable = false
                  ..rets.editable = false;

    //TODO:Add world position input to OnPaintBegin
    var m_OnPaintEnd = _FindOrCreateMtd("OnPaintEnd");
    m_OnPaintEnd..editable = false
        ..args.editable = false
        ..rets.editable = false;

    var m_OnPaintUpdate = _FindOrCreateMtd("OnPaintUpdate");
    m_OnPaintUpdate
        ..args.AddField(CodeField("Pipeline",      )..type=_NT("RenderPipeline|PipelineBuilder") )
        ..args.AddField(CodeField("Background",    )..type=_NT("RenderPipeline|TexEntry") )
        ..args.AddField(CodeField("Size",          )..type=_NT("Vec|Vec2") )
        ..args.AddField(CodeField("Position",      )..type=_NT("Vec|Vec2") )
        ..args.AddField(CodeField("Speed",         )..type=_NT("Vec|Vec2") )
        ..args.AddField(CodeField("Tilt",          )..type=_NT("Vec|Vec2") )
        ..args.AddField(CodeField("Pressure",      )..type=_NT("Num|Float") )
        ..rets.AddField(CodeField("Pipeline Output")..type=_NT("RenderPipeline|TexEntry") )
        ..editable = false
        ..args.editable = false
        ..rets.editable = false
    ;
    //TODO:Add color input to OnPaintUpdate


  }

  List<ShaderFunction> _pipeStages = [];

  ///[Result, errMessage]
  List PackageBrush(){
    var res = _PackageBrush();
    desc = res.first;
    errMsg = res.last;
    return res;
  }
  List _PackageBrush(){
    //Build deps
    List<VMLibInfo> packagedLibs = [];
    for(var d in progLib.deps){
      var result = CompileLibrary(d);

      if(result.last != null) return [null,
        "Lib compilation failed: ${d.fullName}"
        + result.last
      ];
      packagedLibs.add(result.first);
    }

    //Event graph, also the stage shader list
    var result = CompileLibrary(progLib);

    if(result.last != null) return [null,
      "Event graph compilation failed"
          + result.last
    ];
    packagedLibs.add(result.first);

    //Package shaders
    List<ShaderProgram> shaders = [];
    for(var s in _pipeStages){
      //var shader = _shaderLib.LookupShader(s);
      //if(shader == null) return [null, "Shader not found: ${s.libName}|${s.shaderName}"];
      var result = LinkShader(s);
      if(result.first == null) return [null, result.last];
      var compiled = ShaderProgram(result.first!);
      if(!compiled.IsProgramValid()) return[null, compiled.GetProgramStatus()];
      shaders.add(compiled);
    }

    var desc = PipelineDesc()
      ..installedLibs = packagedLibs
      ..installedShaders = shaders
      ;
    return[desc, null];

  }

  int RegisterStage(ShaderFunction? shader) {
    if(shader == null) return -1;
    int id = _pipeStages.length;
    _pipeStages.add(shader);
    return id;
  }

  //TODO:Make happen "Real" deep copy
  void copyFrom(BrushData brush) {
    this.name = brush.name;
    this.progLib.Dispose();
    this.progLib = brush.progLib;
    this.progClass = brush.progClass;
    this.shaderLib = brush.shaderLib;
  }

}

class BrushEditor extends StatefulWidget{

  final BrushData data;

  BrushEditor(this.data);

  @override
  State<StatefulWidget> createState() => _BrushEditorState();
  
}

class _BrushEditorState extends State<BrushEditor>{

  final BrushEditorEnv env = BrushEditorEnv();

  @override initState(){
    super.initState();
    env.brushData = widget.data;
  }

  @override void didUpdateWidget(BrushEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.data == oldWidget.data) return;
    env.brushData = widget.data;
  }

  @override void dispose() {
    super.dispose();
    env.Dispose();
  }


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
          ElevatedButton(
            onPressed:ExportBrush,
            child: Text("Export Brush")
          ),
          ElevatedButton(
              onPressed:ImportBrush,
              child: Text("Import Brush")
          ),
        ],
      ),
    );
  }

  void ShowEventGraphEditor(){
    var mainClass = widget.data.progClass;
    Navigator.of(context).push(MaterialPageRoute(builder: 
      (ctx)=>VMTypeInspector(widget.data.progClass, env)
    ));
  }

  void ShowVMGraphEditor(){
    Navigator.of(context).push(MaterialPageRoute(builder: 
      (ctx)=>VMEditor(widget.data.progLib, env)
    ));
  }

  void ShowShaderGraphEditor(){
    Navigator.of(context).push(MaterialPageRoute(builder: 
      (ctx)=>ShaderEditor(widget.data.shaderLib)
    ));
  }

  void PackageBrush(){
    var res = widget.data.PackageBrush();
    PipelineDesc? desc = res.first;
    String? errMsg = res.last;
  }

  Future<void> _showMyDialog(
    String title,
    List<String> body,
  ) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                for(var l in body)
                  Text(l),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void ExportBrush(){
    try{
      var data = widget.data;
      var map = SerializeBrush(data);
      var jsonStr = JsonEncoder.withIndent("  ").convert(map);
      var utf8Str = Utf8Codec().encode(jsonStr);
      var dirPath = Directory.current.path;
      final filename = "${data.name}.json";

      final typeGroup = XTypeGroup(label: 'brush data', extensions: ['json']);
      getSavePath(acceptedTypeGroups: [typeGroup], suggestedName: filename)
      .then((path)async{
        if(path == null)
          throw Exception("Path can't be null");
        var file = XFile.fromData(
            Uint8List.fromList(utf8Str),
            path: p.join(dirPath, filename)
        );
        await file.saveTo(path);
        _showMyDialog(
            "Export successful",
            [
              "Exported to:",
              path
            ]
        );
      });

    }
    catch(e){
      _showMyDialog(
        "Export failed",
        [e.toString()]
      );
    }
  }

  void ImportBrush(){
    final typeGroup = XTypeGroup(label: 'brush data', extensions: ['json']);
    openFile(acceptedTypeGroups: [typeGroup]).then((file)async{
      try{
        if(file == null)
          throw Exception("Can't open file");
        var str = await file.readAsString();
        var data = jsonDecode(str);
        env.brushData = null;
        var brush = DeserializeBrush(data);
        widget.data.copyFrom(brush);
        env.brushData = widget.data;
      }catch(e){
        _showMyDialog(
            "Import failed",
            [e.toString()]
        );
      }

    });

  }
}


class StringInputDialog extends StatefulWidget {

  String title;
  StringInputDialog(this.title);

  @override
  _StringInputDialogState createState() => _StringInputDialogState();
}

class _StringInputDialogState extends State<StringInputDialog> {

  String path = "";

  @override
  Widget build(BuildContext ctx) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: ListBody(
          children: <Widget>[
            NameField(
              hint: "Enter path...",
              initialText: path,
              onChange: (name){
                path = name;
                return true;
              },
            )
          ],
        ),
      ),
      actions: <Widget>[
        ElevatedButton(
          child: Text('Import'),
          onPressed: (){Navigator.of(ctx).pop<String?>(path);},
        ),

        TextButton(
          child: Text('Close'),
          onPressed: (){Navigator.of(ctx).pop<String?>(null);},
        ),
      ],
    );

  }
}