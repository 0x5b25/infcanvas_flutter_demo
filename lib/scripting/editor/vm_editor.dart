
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:infcanvas/utilities/async/task_guards.dart';
import 'package:infcanvas/scripting/script_graph.dart';
import 'package:infcanvas/scripting/editor/vm_types.dart';
import 'package:infcanvas/scripting/editor_widgets.dart';
import 'package:infcanvas/scripting/codepage.dart';
import 'package:infcanvas/scripting/editor/codemodel.dart';
import 'package:infcanvas/scripting/editor/codemodel_events.dart';
import 'package:infcanvas/scripting/editor/vm_compiler.dart';
import 'package:infcanvas/scripting/editor/vm_lib_editor.dart';
import 'package:infcanvas/scripting/editor/vm_method_nodes.dart';

import 'package:infcanvas/scripting/code_element.dart';
import 'vm_type_editor.dart';

class EditorEvent extends Event{}


class AnalyzerEvent extends EditorEvent{
  CodeElementChangeEvent originalEvent;
  AnalyzerEvent(this.originalEvent);
}

class EditorNeedsRefreshEvent extends EditorEvent{
  final CodeElement? changedElement;
  EditorNeedsRefreshEvent(this.changedElement);
}

class VMEditorEnv with Observable{

  late var _ob = Observer("$debugName");

  final Set<CodeLibrary> loaded = {};

  void _LoadLib(CodeLibrary lib){
    var newLib = loaded.add(lib);
    if(newLib){
      _StartWatching(lib);
    }
  }

  void LoadLib(CodeLibrary lib){

    if(loaded.contains(lib)) return;
    _LoadLib(lib);
    for(var d in lib.deps){
      LoadLib(d);
    }
  }

  void UnloadLib(CodeLibrary lib){
    loaded.remove(lib);
    _StopWatching(lib);
  }

  Iterable<CodeLibrary> FindDependant(CodeLibrary dep)sync*{
    for(var l in loaded){
      if(l == dep) continue;
      if(l.deps.contains(dep)) yield l;
    }
  }

  void UnloadLibWithDep(CodeLibrary lib){
    if(!loaded.contains(lib)) return;
    //Resolve dependencies
    var deps = lib.deps;
    var unwantedDeps = [lib];

    //Is this lib referenced?
    _CheckDepRef(d){
      for(var l in loaded){
        if(l == lib) continue;
        if(l.deps.contains(d)) return true;
      }
      return false;
    }

    for(var d in deps){
      if(_CheckDepRef(d))continue;
      unwantedDeps.add(d);
    }

    for(var u in unwantedDeps){
      UnloadLib(u);
    }
  }

  _StopWatching(lib){
    _ob.StopWatching(lib);
  }

  _StartWatching(lib){
    _ob.Watch<CodeElementChangeEvent>(lib, _PumpAnalyzerEvt);
  }

  _PumpAnalyzerEvt(original){
    print("Received from lib");
    SendEvent(AnalyzerEvent(original));
  }

  Iterable<CodeLibrary> LoadedLibs() sync*{
    //yield* VMBuiltinTypes.runtimeLibs;
    yield* loaded;
  }

  Iterable<CodeType> LoadedTypes() sync*{
    yield* VMBuiltinTypes.types.values;
    for(var l in LoadedLibs()){
      for(var ty in l.types){
        yield ty;
      }
    }
  }

  Iterable<CodeLibrary> AccessableLibs(CodeLibrary? from) sync*{
    yield* VMBuiltinTypes.libs;
    if(from == null) return;
    yield from;
    yield* from.deps;
  }

  Iterable<CodeType> AccessableTypes(CodeType? from)sync*{
    var libs = AccessableLibs(from?.library);
    for(var l in libs){
      yield* l.types;
    }

  }

  bool TypeContainedInDeps(CodeType? from, CodeType? type){
    return AccessableTypes(from).contains(type);
  }

  VMEditorEnv({String debugName = "VMEditorEnv"}){
    this.debugName = debugName;
  }

  @override toString() => debugName;

  void Clear(){
    _ob.Clear();
    loaded.clear();
  }

  @override Dispose(){
    loaded.clear();
    _ob.Dispose();
    super.Dispose();
  }

  CodeGraphNode? MapNode(CodeGraphNode which) => null;

}

class VMMethodAnalyzer extends ICodeData with Observable{

  VMEditorEnv? _env;
  VMEditorEnv? get env => _env;
  set env(VMEditorEnv? env){
    if(_env == env) return;
    _ob.StopWatching(_env);
    _env = env;
    if(_env != null){
      _ob.Watch<AnalyzerEvent>(_env!, _HandleEvt);
    }
  }

  CodeMethod? whichMethod;
  Observer _ob = Observer("MethodAnalyzer_ob");

  VMMethodAnalyzer();

  @override Dispose(){
    _ob.Dispose();
    super.Dispose();
  }

  _HandleEvt(e){
    SendEvent(e);
  }

  GraphNodeQueryResult? _MatchNode(CodeGraphNode node, SlotInfo? slot,String
  cat){
    var mapped = env?.MapNode(node);
    if(mapped != null) node = mapped;
    if(whichMethod != null)
      node.thisMethod = whichMethod!;

    if(slot == null){
      return GraphNodeQueryResult(node, cat);
    }
    int i = 0;
    for(var s in node.inSlot){
      if(s.CanEstablishLink(slot))
        return GraphNodeQueryResult(node, cat, true, i);
      i++;
    }
    i = 0;
    for(var s in node.outSlot){
      if(s.CanEstablishLink(slot))
        return GraphNodeQueryResult(node, cat, false, i);
      i++;
    }
    return null;
  }

  Iterable<GraphNodeQueryResult> _MatchNodeList(nodes, slot, cat)sync*{
    for(var n in nodes) {
      var res = _MatchNode(n, slot, cat);
      if (res != null) yield res;
    }
  }

  //Check and correct method body structurally
  void SanitizeMethodBody(){
    if(whichMethod == null) return;
    var nodes = whichMethod!.body;
    //Remove all invalid nodes
    nodes.removeWhere((n){
      if(n is! IValidatableNode) return false;
      var vn = n as IValidatableNode;
      return !vn.Validate(this);
    });
    //Update nodes
    for(var n in nodes){
      n.Update();
    }
    //Check entry
    if(whichMethod!.isConst.value && whichMethod!.root is! CodeReturnNode){
      whichMethod!.root?.Dispose();
      whichMethod!.root = CodeReturnNode(whichMethod!);
    }else if(!whichMethod!.isConst.value
        && whichMethod!.root is! CodeEntryNode){
      whichMethod!.root?.Dispose();
      whichMethod!.root = CodeEntryNode(whichMethod!);
    }

    whichMethod?.root?.Update();
    return;
    ;
  }

  ///Do both sanitize pass and compiler checking pass
  ///returns whether test passed
  bool FullyAnalyzeMethod(){
    if(whichMethod == null || env == null) return true;
    SanitizeMethodBody();
    var compilerChkRes = CompileMethod(whichMethod!, env!).last;
    return compilerChkRes == null;
  }

  late final _analysisTask = SequentialTaskGuard<bool>(
      (_) async => FullyAnalyzeMethod()
  );

  Future<bool> BeginAnalyzeMethod(){
    return _analysisTask.RunNowOrSchedule();
  }

  @override FindNodeWithConnectableSlot(SlotInfo? slot)sync* {
    //Constants
    var constVal = [
      ConstIntNode(),
      ConstFloatNode(),
    ];
    yield* _MatchNodeList(constVal, slot, "Constants");

    //Control flow
    var ctrlFlow = [
      CodeIfNode(), CodeSequenceNode()
    ];
    yield* _MatchNodeList(ctrlFlow, slot, "Control Flow");

    if(whichMethod != null){
      var mtdStruct = [];
      if(!whichMethod!.isStatic.value){
        mtdStruct.add(CodeThisGetterNode(whichMethod!));
      }

      if(whichMethod!.isConst.value){
        //Constant methods can construct "Entry" node,
        //But can have only one "Return" node
        mtdStruct.add(CodeEntryNode(whichMethod!));
      }else{
        //
        mtdStruct.add(CodeReturnNode(whichMethod!));
      }

      yield* _MatchNodeList(mtdStruct, slot, "Method Structure");
    }

    //Methods from other types
    for(var ty in AccessableTypes()){
      var baseCat = ty.fullName;
      //Instantiators
      if(ty.isImplicitConstructable && ty.isRef.value){
        var ctorCat = "$baseCat|Constructors";
        var ins = [InstantiateNode(ty), ConstructNode(ty)];
        yield* _MatchNodeList(ins, slot, ctorCat);
      }

      //Field Getters
      {
        var staticAccCat = "$baseCat|Static Fields";
        var accCat = "$baseCat|Fields";
        var sf = ty.staticFields.fields;
        var sfGetter = sf.map((e)
          => CodeFieldGetterNode(FieldDesc(ty,e)));
        yield* _MatchNodeList(sfGetter, slot, staticAccCat);

        var sfSetter = sf.map((e)
        => CodeFieldSetterNode(FieldDesc(ty,e)));
        yield* _MatchNodeList(sfSetter, slot, staticAccCat);

        var f = ty.fields.fields;
        var fGetter = f.map((e)
          => CodeFieldGetterNode(FieldDesc(ty,e)));
        yield* _MatchNodeList(fGetter, slot, accCat);

        var fSetter = f.map((e)
        => CodeFieldSetterNode(FieldDesc(ty,e)));
        yield* _MatchNodeList(fSetter, slot, accCat);
      }

      //Methods
      {
        var mtdCat = "$baseCat|Methods";
        var mtdNodes = ty.methods.map((e) => CodeInvokeNode(e));
        yield* _MatchNodeList(mtdNodes, slot, mtdCat);
      }
    }
  }

  @override
  void AddNode(CodeGraphNode node) {
    if(whichMethod == null) return;
    whichMethod!.body.add(node);
    NotifyCodeChange();
  }

  @override GetNodes() {
    if(whichMethod == null) return [];
    if(whichMethod!.root == null) return whichMethod!.body;
    return [whichMethod!.root!] + whichMethod!.body;
  }


  @override
  void OnCodeChange() {
    NotifyCodeChange();
  }

  @override
  void RemoveNode(CodeGraphNode node) {
    if(whichMethod == null) return;
    if(!whichMethod!.body.remove(node))return;
    NotifyCodeChange();
  }

  void NotifyCodeChange(){
    ClearNodeMessage();
    whichMethod?.SendEventAlongChain(
      MethodBodyChangeEvent()
    );
  }

  void ClearNodeMessage(){
    whichMethod?.nodeMessage.clear();
  }

  @override GetNodeMessage(GraphNode node)
    => whichMethod?.nodeMessage[node]??[];

  Iterable<CodeType> AccessableTypes(){
    return env?.AccessableTypes(whichMethod?.thisType)
      ??[];
  }

  Iterable<CodeLibrary> AccessableLibs(){
    var thisLib = whichMethod?.thisType?.library;
    return env?.AccessableLibs(thisLib)
        ??[];
  }

  bool TypeContainedInDeps(CodeType type){
    return AccessableTypes().contains(type);
  }
}

abstract class IValidatableNode{
  bool Validate(VMMethodAnalyzer analyzer);
}

class FieldEditor extends StatefulWidget {

  final CodeFieldArray field;
  final Iterable<CodeType> Function() typeProvider;
  final String title;

  const FieldEditor(
      this.field,
      this.typeProvider,
      {Key? key, this.title = ""}
    ) : super(key: key);

  @override
  _FieldEditorState createState() => _FieldEditorState();
}

class _FieldEditorState extends State<FieldEditor> {

  late Observer _ob = Observer("FieldEditor_ob->${widget.field.fullName}");

  @override void initState() {
    super.initState();
    _StartWatching();
  }

  @override didUpdateWidget(oldWidget){
    super.didUpdateWidget(oldWidget);
    if(widget.field == oldWidget.field) return;
    _StopWatching(oldWidget.field);
    _StartWatching();
  }

  @override dispose(){
    super.dispose();
    _ob.Dispose();
  }

  _HandleEvent(e){
    setState(() {

    });
  }

  _StartWatching(){
    _ob.Watch<FieldChangeEvent>(widget.field, _HandleEvent);
  }
  _StopWatching(from){
    _ob.StopWatching(from);
  }

  @override
  Widget build(BuildContext context) {
    return ListEditor(
      title: widget.title,
      listToEdit: _FieldIface(this),
      canEdit: widget.field.editable,
    );
  }
}

class _FieldIface extends ListInterface{
  final _FieldEditorState state;
  CodeFieldArray get fieldArr => state.widget.field;
  _FieldIface(this.state);

  get availableTypes => state.widget.typeProvider();

  @override
  void AddEntry(_FieldEntry entry) {
    fieldArr.AddField(entry.field);
  }

  @override
  void RemoveEntry(_FieldEntry entry) {
    entry.field.Dispose();
  }

  @override doCreateEntryTemplate() => _FieldEntry._();

  @override doGetEntry() {
    return [
      for(var f in fieldArr.fields)
        _FieldEntry(f),
    ];
  }
}

class _FieldEntry extends ListEditEntry<_FieldIface>{

  final CodeField field;

  _FieldEntry(this.field);

  _FieldEntry._()
    :field = CodeField(){

  }

  CodeFieldArray get arr => fromWhichIface.fieldArr;
  @override CanEdit()=>field.editable;

  @override
  Iterable<ListEntryProperty> EditableProps(BuildContext ctx) {
    return[
      if(!ValidateName(name))
        StatusIndicator(EntryStatus.Error),

      StringProp((n)=>EditFieldName(n),
          initialContent: name,
          hint: "Field Name"
      ),

      if(!ValidateType(type))
        StatusIndicator(EntryStatus.Error),

      SelectionProp<CodeType>(
          requestSelections: ()=>fromWhichIface.availableTypes,
          onSelect: (ty){
            type = ty;
            PerformRepaint();
          },
          initialValue: type
      )
    ];
  }

  @override
  bool IsConfigValid() {
    return ValidateName(name)
        && ValidateType(type);
  }

  bool ValidateType(CodeType? type){
    if(type == null) return false;
    return !type.isDisposed;
  }

  String get name => field.name.value;
  set name(String val){field.name.value = val;}

  CodeType? get type => field.type;
  set type(CodeType? val){field.type = val;}

  bool ValidateName(String name){
    if(name == "")return false;
    for(var f in arr.fields){
      if(f == field)continue;
      if(f.name.value == name){return false;}
    }
    return true;
  }

  bool EditFieldName(String name){
    if(!ValidateName(name)) return false;
    this.name = name;
    PerformRepaint();
    return true;
  }
}

class VMEditor extends StatefulWidget {

  final CodeLibrary lib;
  final VMEditorEnv env;

  const VMEditor(this.lib, this.env,{Key? key}) : super(key: key);

  @override
  _VMEditorState createState() => _VMEditorState();
}

class _VMEditorState extends State<VMEditor> {
  //VMEditorEnv env = VMEditorEnv();

  @override void initState() {
    super.initState();
    //env.LoadLib(widget.lib);
  }

  @override void didUpdateWidget(covariant VMEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(oldWidget.lib == widget.lib) return;
    //env.Clear();
    //env.LoadLib(widget.lib);
  }

  @override void dispose() {
    super.dispose();
    //env.Dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VMLibInspector(widget.lib, widget.env,
      onSelect: _ShowTypeInspector,
    );
  }

  void _ShowTypeInspector(CodeType type){
    if(type is BuiltinType) return;
    Navigator.of(context).push(
        MaterialPageRoute(builder: (ctx){
          return VMTypeInspector(type, widget.env);
        })
    );
  }
}

