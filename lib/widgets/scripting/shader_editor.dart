
import 'dart:ffi';

import 'package:flutter/material.dart';
import 'package:infcanvas/widgets/functional/anchor_stack.dart';
import 'package:infcanvas/widgets/functional/editor_widgets.dart';
import 'package:infcanvas/widgets/functional/floating.dart';
import 'package:infcanvas/widgets/scripting/shader_graphnodes.dart';
import 'package:infcanvas/widgets/scripting/shaderlib_inspector.dart';

import 'package:provider/provider.dart';


import 'package:infcanvas/utilities/scripting/graph_compiler.dart';
import 'package:infcanvas/utilities/scripting/script_graph.dart';
import 'package:infcanvas/widgets/scripting/vm_graphnodes.dart';
import 'package:infcanvas/widgets/scripting/codepage.dart';

import '../../util.dart';

enum ShaderValType{
  tex,
  float, float2, float3, float4,
}

String GetShaderTyName(ShaderValType ty) => ty.toString().split('.').last;

int inputTypeOnly = 1;

Map<String, List<String>> compatibleTypes = {
  "tex" :[],
  "float" :["float2", "float3", "float4"],
  "float2":[],
  "float3":[],
  "float4":[],
};



class ShaderRetTU extends ShaderTU{

  @override
  void Translate(ShaderGraphCompileContext ctx){
    var node = fromWhichNode as ShaderRetNode;
    var retType = node.data._retType;
    var names = AddValDeps(ctx);
    ctx.EmitCode("return ${names.first};");
  }
}


class ShaderRetNode extends ShaderGN{
  EditorShaderData data;
  ShaderRetNode(this.data){
    displayName = "Return";
    var newType = data._retType.toString().split('.').last;
    inSlot.add(ValueInSlotInfo(this, "value", newType));
    Update();
  }

  void Update(){
    var newType = data._retType.toString().split('.').last;
    var oldType = (inSlot[0] as ValueInSlotInfo).link?.from.type;
    
    if(!data.IsSubTypeOf(oldType??newType, newType)){
      inSlot[0].Disconnect();
    }

    inSlot[0].type = newType;
  }

  @override
  bool Validate() {
    Update();
    return true;
  }

  @override
  GraphNode Clone() {
    return ShaderRetNode(data);
  }

  @override
  ShaderRetTU doCreateTU(){
    return ShaderRetTU();
  }

  @override
  String GetSrc(List<String> argNames) {
    throw UnimplementedError();
  }

  @override
  String get retType => "";
}

class ShaderArgGetNode extends ShaderGN{
  EditorShaderData data;
  int argIndex;

  String get name => data.argName[argIndex];
  String get type =>data.argType[argIndex].toString().split('.').last;

  ShaderArgGetNode(this.data,this.argIndex){
    displayName = "Get $name";
    var ty = type;
    outSlot.add(ValueOutSlotInfo(this, name, ty, 0));
  }

  @override
  bool Validate(){

    if(argIndex >= data.argName.length) return false;

    var newType = type;
    var oldType = outSlot[0].type;
    
    if(!data.IsSubTypeOf(newType, oldType)){
      outSlot[0].Disconnect();
    }

    outSlot[0].type = newType;
    outSlot[0].name = name;
    return true;
  }

  @override
  GraphNode Clone() {
    return ShaderArgGetNode(data, argIndex);
  }


  @override
  String GetSrc(List<String> argNames) {
    return name;
  }

  @override
  String get retType => type;


}

class ShaderFnTU extends ShaderTU{
  @override
  void Translate(ctx){
    var node  = fromWhichNode as ShaderFnNode;
    super.Translate(ctx);
    ctx.RefShader(node.fn.reg.name, node.fn.name);
  }
}

class ShaderFnNode extends ShaderBuiltinFunction{
  EditorShaderData fn;

  

  ShaderFnNode(this.fn) 
    :super(fn.name, fn.embeddedName, fn.argName, 
      fn.argType.map((e) => e.toString().split('.').last).toList(),
      "result", fn.returnType.toString().split('.').last){
        displayName = fn.name;
      }

  @override
  bool Validate(){
    if(!fn.isValid) return false;

    displayName = fn.name;


    int inCnt = fn.argName.length;
    for(int i = inCnt; i < inSlot.length; i++){
      inSlot.last.Disconnect();
      inSlot.removeLast();
    }

    for(int i = 0; i < inCnt; i ++){
      var newType = fn.argType[i].toString().split('.').last;
      var newName = fn.argName[i];
      if(i >= inSlot.length){
        inSlot.add(ValueInSlotInfo(this, newName, newType));
      }else{
        var slot = inSlot[i] as ValueInSlotInfo;
        slot.name = newName;
        var oldType = slot.type;
        if(!fn.IsSubTypeOf(oldType, newType)){
          slot.Disconnect();
        }
        slot.type = newType;
      }
    }

    var slot = outSlot.single as ValueOutSlotInfo;
    var oldType = slot.type;
    var newType = fn._retType.toString().split('.').last;
    if(!fn.IsSubTypeOf(newType, oldType)){
      slot.Disconnect();
    }
    slot.type = newType;

    return true;
  }

  @override
  ShaderFnNode Clone(){
    return ShaderFnNode(fn);
  }
}



class EditorShaderData extends CodeData with ChangeNotifier{

  late ShaderLib reg;

  String name;
  String get embeddedName => "${reg.name}_${name}";

  ShaderValType _retType = ShaderValType.float4;

  ShaderValType get returnType => _retType;
  set returnType(val){_retType = val; NotifyCodeChange();}

  List<ShaderRef> shaderRefs = [];

  String? body;
  get isBodyValid => body != null;
  get hasError => nodeMessage.isNotEmpty;

  bool get isValid => reg.shaders.contains(this);


  List<ShaderValType> argType = [];
  List<String> argName = [];

  List<NodeHolder> _nodes = [];
  late NodeHolder returnNode = NodeHolder(ShaderRetNode(this));
  
  EditorShaderData(this.name){
    _retType = ShaderValType.float4;
    AddArg("fragCoord", ShaderValType.float2);
    AddArg("size", ShaderValType.float2);
  }


  @override
  void AddNode(NodeHolder n) {
    _nodes.add(n);
    NotifyCodeChange();
  }

  @override
  void RemoveNode(NodeHolder n) {
    n.info.RemoveLinks();
    _nodes.remove(n);
    NotifyCodeChange();
  }

 
  @override
  Iterable<NodeSearchInfo> FindMatchingNode(String? argType, String? retType)sync*{
    
    var _match = (node, cat){
      return MatchGraphNode(node, cat, IsSubTypeOf, argType, retType);
    };
    
    var _yieldNodes = (list, cat)sync*{
      for(var n in list){
        var res = _match(n, cat);
        if(res != null)
          yield res;
      }
    };

    //argument getters
    var argGetter = [
      for(int i = 0; i < argName.length; i++)
        ShaderArgGetNode(this, i)
    ];

    yield* _yieldNodes(argGetter, "Arguments");

    yield* _yieldNodes(ShaderBuiltins, "Builtin");

    for(var s in reg.shaders){
      if(s == this) continue;
      var fnNode = ShaderFnNode(s);
      var res = _match(fnNode, reg.name);
      if(res != null)
        yield res;
    }
    
  }

  @override
  List<NodeHolder> GetNodes() {return [returnNode] + _nodes;}


  @override
  bool IsSubTypeOf(String type, String base) {
    if(type == base) return true;
    var compatList = compatibleTypes[type];
    if(compatList == null) return false;
    return compatList.contains(base);
  }

  @override
  void NotifyCodeChange() {
    shaderRefs.clear();
    body = null;
    nodeMessage.clear();
    //ValidateNode();
    notifyListeners();
  }

  void ValidateNode(){
    (returnNode.info as ShaderRetNode).Update();
    _nodes.removeWhere((e){
      var n = e.info as ShaderGN;
      if(n.Validate()) return false;
      n.RemoveLinks();
      return true;
    });
  }

  void AddArg(String name, ShaderValType type){
    argType.add(type);
    argName.add(name);
    NotifyCodeChange();
  }

  void RemoveArg(int idx){
    argType.removeAt(idx);
    argName.removeAt(idx);
    NotifyCodeChange();
  }

  void SetArgName(int fieldIndex, String newName) {
    argName[fieldIndex] = newName;
    NotifyCodeChange();
  }

  void SetArgType(int fieldIndex, ShaderValType type) {
    argType[fieldIndex] = type;
    NotifyCodeChange();
  }

  void Compile() {

    var ctx = ShaderGraphCompileContext();
    ctx.TranslateNode(returnNode.info);
    nodeMessage = ctx.errMsg;
    if(nodeMessage.isEmpty){
      body = "";
      for(var line in ctx.src){
        body = body! + "    $line\n";
      }
      shaderRefs = ctx.refs;
    }
    notifyListeners();
  }

  String WrapAsFunction(){
    _Arg2Str(int idx)=>"${GetShaderTyName(argType[idx])} ${argName[idx]}";
    String argList = argName.length > 0? _Arg2Str(0) : "";

    for(int i = 1; i < argName.length; i++){
      argList += ", ${_Arg2Str(i)}";
    }

    String fn = "${GetShaderTyName(returnType)} $embeddedName($argList){\n"
    + body!
    +"}\n";

    return fn;
  }

  bool IsArgSuitableForEntry(){
    //Check signature first
    return (
      argType.length > 0
      &&argType.first == ShaderValType.float2
    );
  }

  bool IsRetSuitableForEntry(){
    return returnType == ShaderValType.float || returnType == ShaderValType.float4; 
  }

  bool IsSuitableForEntry(){
    return IsArgSuitableForEntry() && IsRetSuitableForEntry();
  }
 
  ///[Src, Err]
  List<String?> LinkAsPipelineStage(){

    //Check signature first
    if(
      !IsArgSuitableForEntry()
    ){
      return[
        null, "First argument should be float2"
      ];
    }

    if(
      !IsRetSuitableForEntry()
    ){
      return[
        null, "Return type should either be float or float4"
      ];
    }

    List<EditorShaderData> linkOrder = [];
    Set<EditorShaderData> visited = {};
    List<EditorShaderData> workingList = [];
    String errMsg = "";
    _ProcessNode(EditorShaderData n){
      if(visited.contains(n)) return true;

      if(workingList.contains(n)){
        //Loop in the graph
        errMsg = "Cyclic dependencies: ${workingList.last.name} -> ${n.name}";
        return false;
      }
      workingList.add(n);
      for(var neigh in n.shaderRefs){
        var s = reg.LookupShader(neigh);
        if(s == null){ 
          errMsg = "Dependency not found: ${neigh.libName}|${neigh.shaderName}";
          return false;
        }
        if(_ProcessNode(s) == false) return false;
      }
      //Should be the last node after all function returns
      workingList.removeLast();
      visited.add(n);
      linkOrder.add(n);
      return true;
    }

    //Get compilation orders
    if(!_ProcessNode(this))
      return[
        null, errMsg
      ];
    assert(linkOrder.last == this);

    //Compile functions
    for(var s in linkOrder){
      s.Compile();
      if(!s.isValid){
        return [
          null, "Compilation failed: ${s.embeddedName}"
        ];
      }
    }

    String linked = "";
    String mainArgList = "";

    //Add uniforms
    for(int i = 1; i < argName.length; i++){
      var ty = argType[i].toString().split('.').last;
      var nm = argName[i];
      linked += "uniform $ty $nm;\n";
      mainArgList += ", $nm";
    }
    linked += "\n";
    //Insert functions
    for(int i = 0; i < linkOrder.length; i++){
      var fn = linkOrder[i].WrapAsFunction();
      linked += fn;
      linked += "\n";
    }

    //Insert main    
    linked += "half4 main(float2 coord){\n"
    +"    return half4(${linkOrder.last.embeddedName}(coord$mainArgList));\n"
    +"}\n";

    return[linked, null];
  }
}

class ShaderInputInterface extends ListInterface{

  late EditorShaderData data;

  ShaderInputInterface();

  @override
  void Init(BuildContext ctx){
    data = Provider.of(ctx);
  }

  @override
  void AddEntry(TemplateShaderInputEntry e) {
    data.AddArg(e.argName, e.argType);
  }

  @override
  void RemoveEntry(ShaderInputEntry entry) {
    data.RemoveArg(entry.fieldIndex);
  }

  @override
  TemplateShaderInputEntry doCreateEntryTemplate() {
    return TemplateShaderInputEntry();
  }

  @override
  Iterable<ShaderInputEntry> doGetEntry() {
    return[
      for(int i = 0; i < data.argName.length;i++)
        ShaderInputEntry(i),
    ];
  }

}

abstract class ShaderInputEntryBase extends ListEditEntry{

  ShaderInputInterface get interface=> iface as ShaderInputInterface;
  EditorShaderData get data => interface.data;

  String get argName;

  ShaderValType get argType;
  set argType(ShaderValType type);

  @override
  bool CanEdit() => true;

  @override
  Iterable<ListEntryProperty> EditableProps(BuildContext ctx) {
    return [
      StringProp(
        EditArgName,
        initialContent: argName,
        hint: "Argument Name",
      ),
      SelectionProp<ShaderValType>(
        initialValue: (argType),
        requestSelections: (){
          return ShaderValType.values;
        },
        onSelect: (ty){
          argType = ty!;
          interface.data.NotifyCodeChange();
        },
        displayName: (e)=>e.toString().split('.').last,
      )
    ];
  }

  @override
  bool IsConfigValid()=>ValidateName(argName);
  bool EditArgName(String newName);
  bool ValidateName(String name);
}

class ShaderInputEntry extends ShaderInputEntryBase{
  int fieldIndex;
  ShaderInputEntry(this.fieldIndex);

  @override
  bool ValidateName(String name) {
    if(name == "") return false;
    for(int i = 0; i < data.argName.length; i++){
      if(i == fieldIndex) continue;
      if(data.argName[i] == name) return false;
    }
    return true;
  }

  @override
  bool EditArgName(String newName) {
    bool valid = ValidateName(newName);
    if(valid){
      data.SetArgName(fieldIndex, newName);
    }
    return valid;
  }

  @override String get argName => data.argName[fieldIndex];
  @override ShaderValType get argType => data.argType[fieldIndex];
  @override set argType(type) => data.SetArgType(fieldIndex, type);

}

class TemplateShaderInputEntry extends ShaderInputEntryBase{
  String name = "";

  @override
  bool ValidateName(String name) {
    if(name == "") return false;
    for(int i = 0; i < data.argName.length; i++){
      if(data.argName[i] == name) return false;
    }
    return true;
  }

  @override
  bool EditArgName(String newName) {
    name = newName;
    return ValidateName(newName);
  }
  @override String get argName => name;
  @override ShaderValType argType = ShaderValType.float;
}


class ShaderRetEdit extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var data = Provider.of<EditorShaderData>(context);
    return SizedBox(
      width: 100,
      height: 30,
      child: SelectionPropEditor<ShaderValType>(
        initialValue: data.returnType,
        requestSelections: (){
          return [
            for(int i = inputTypeOnly; i < ShaderValType.values.length; i++)
              ShaderValType.values[i],
          ];
        },
        onSelect: (ty){
          data.returnType = ty!;
        },
        displayName: (e)=>e?.toString().split('.').last??"empty",
      ),
    );
  }
}

class ShaderCompileButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    var data = Provider.of<EditorShaderData>(context);
    return ElevatedButton(
      style: 
      data.isBodyValid?
      ElevatedButton.styleFrom(
        primary: Colors.green, // background
        //onPrimary: Colors.white, // foreground
      ):
      data.hasError?
      ElevatedButton.styleFrom(
        primary: Colors.red, // background
        //onPrimary: Colors.white, // foreground
      ):null
      ,
      child: Text('Compile'),
      onPressed: (){
        data.Compile();
      }
    );
  }
}

class ShaderEditor extends StatefulWidget {

  final EditorShaderData data;

  ShaderEditor(this.data);

  @override
  _ShaderEditorState createState() => _ShaderEditorState();
}

class _ShaderEditorState extends State<ShaderEditor> {

  @override
  void initState(){
    super.initState();
    //widget.data.ValidateNode();
  }

  @override
  void didUpdateWidget(ShaderEditor oldWidget){
    super.didUpdateWidget(oldWidget);
    //if(oldWidget.data != widget.data){
    //}
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: 
      ChangeNotifierProvider<EditorShaderData>.value(
        value: widget.data,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 300,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(widget.data.name, style: Theme.of(context).textTheme.headline5,),

                  Divider(),

                  Spacer(),

                  ElevatedButton(
                    onPressed: (){
                      Navigator.of(context).pop();
                    },
                    child: Text("Back")
                  ),

                ],
              ),
            ),

            Expanded(child:FloatingWindowPanel(
              children:[
                AnchoredPosition.fill(child: ShaderPage()),

                FloatingWindow(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                    ],
                  ),
                ),

                FloatingWindow(
                  anchor: Rect.fromLTRB(1,0,1,0),
                  align: Offset(1,0),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      
                      PopupBuilder<EditorShaderData>(
                        data: widget.data,
                        contentBuilder: (open){
                          return ElevatedButton(
                            child: Text('Edit Arguments'),
                            onPressed: open,
                          );
                        }, 
                        popupBuilder: (close){
                          return SizedBox(
                            width: 300,
                            child: ListEditor(
                              listToEdit: ShaderInputInterface(),
                              title: "Shader Inputs",
                            ),
                          );
                        },
                        updateShouldClose: (old){
                          return old.data != widget.data;
                        },
                      ),

                      ShaderRetEdit(),
                     
                      ShaderCompileButton(),
                    ],
                  ),
                )
              ]
            )
            )
          ],
        ),
      ),
    );
  }

}

class ShaderPage extends StatelessWidget {
  const ShaderPage({
    Key? key,
  }) : super(key: key);


  @override
  Widget build(BuildContext context) {
    var data = Provider.of<EditorShaderData>(context);
    data.ValidateNode();    
    return CodePage(
      data,
    );
  }
}
