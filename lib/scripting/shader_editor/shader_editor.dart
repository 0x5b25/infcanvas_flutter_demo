

import 'package:flutter/material.dart';
import 'package:infcanvas/utilities/async/task_guards.dart';
import 'package:infcanvas/scripting/script_graph.dart';
import 'package:infcanvas/widgets/functional/anchor_stack.dart';
import 'package:infcanvas/scripting/editor_widgets.dart';
import 'package:infcanvas/widgets/functional/floating.dart';
import 'package:infcanvas/scripting/codepage.dart';
import 'package:infcanvas/scripting/editor/codemodel_events.dart';
import 'package:infcanvas/scripting/code_element.dart';
import 'package:infcanvas/scripting/editor/vm_editor.dart';
import 'package:infcanvas/scripting/shader_editor/shader_codemodel.dart';
import 'package:infcanvas/scripting/shader_editor/shader_builtin_nodes.dart';
import 'package:infcanvas/scripting/shader_editor/shader_compiler.dart';
import 'package:infcanvas/scripting/shader_editor/shader_method_nodes.dart';


class ShaderEditorEnv with Observable{
  var _ob = Observer("ShaderEditorEnv_ob");

  ShaderLib? _targetLib;
  ShaderLib? get targetLib => _targetLib;
  set targetLib(val){
    _StopWatching();
    _targetLib = val;
    _StartWatching();
  }

  _StopWatching(){
    if(_targetLib == null) return;
    //for(var d in _targetLib!.deps){
    //  _ob.StopWatching(d);
    //}
    _ob.StopWatching(_targetLib!);
  }

  _StartWatching(){
    if(_targetLib == null) return;
    _ob.Watch<CodeElementChangeEvent>(_targetLib!, _PumpAnalyzerEvt);
    //for(var d in _targetLib!.deps){
    //  _ob.Watch<CodeElementChangeEvent>(d, _PumpAnalyzerEvt);
    //}
  }

  Iterable<ShaderFunction> LoadedFuncs(){
    return _targetLib?.functions??[];
  }

  bool FunctionContainedInDeps(ShaderFunction? fn){
    if(fn == null) return false;
    return LoadedFuncs().contains(fn);
  }

  _PumpAnalyzerEvt(original){
    SendEvent(AnalyzerEvent(original));
  }

  @override Dispose(){
    targetLib = null;
    _ob.Dispose();
    super.Dispose();
  }

  bool FnContainedInDeps(ShaderFunction? fn) {
    if(fn == null) return false;
    return LoadedFuncs().contains(fn);
  }
}

class ShaderFnAnalyzer extends ICodeData with Observable{

  ShaderEditorEnv? _env;
  ShaderEditorEnv? get env => _env;
  set env(ShaderEditorEnv? env){
    if(_env == env) return;
    _ob.StopWatching(_env);
    _env = env;
    if(_env != null){
      _ob.Watch<AnalyzerEvent>(_env!, _HandleEvt);
    }
  }

  ShaderFunction? whichFn;
  Observer _ob = Observer("ShaderFnAnalyzer_ob");

  ShaderFnAnalyzer(){
  }

  _HandleEvt(e){
    SendEvent(e);
  }

  @override Dispose(){
    _ob.Dispose();
    super.Dispose();
  }

  GraphNodeQueryResult? _MatchNode(ShaderGraphNode node, SlotInfo? slot,String
  cat){
    if(whichFn != null)
      node.fn = whichFn!;
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


  @override FindNodeWithConnectableSlot(SlotInfo? slot) sync* {


    if(env == null) return;

    var constNode = ShaderConstFloatNode();
    var res = _MatchNode(constNode, slot, "Misc");
    if(res != null){
      yield res;
    }

    //Arg getter, invoke
    if(whichFn!= null) {
      //Arg getters
      var getters = [
      for (var a in whichFn!.args.fields)
        ShaderArgGetNode(a),
      ];
      yield* _MatchNodeList(getters, slot, "Args");

      //Invoked methods
      var fnInvokes = [];
      for(var fn in env!.LoadedFuncs()){
        //No recursive calls
        if(fn == whichFn) continue;
        if(fn.IsSuitableForEmbedding()){
          fnInvokes.add(ShaderInvokeNode(fn));
        }
      }
      yield* _MatchNodeList(fnInvokes, slot, "Function Invoke");
    }

    var builtin = shaderNodes;
    yield* _MatchNodeList(builtin, slot, "Builtins");
  }

  @override
  void AddNode(ShaderGraphNode node) {
    if(whichFn == null) return;
    whichFn!.body.add(node);
    NotifyCodeChange();
  }

  @override GetNodes() {
    if(whichFn == null) return [];
    return <ShaderGraphNode>[whichFn!.entry!] + whichFn!.body;
  }

  bool AnalyzeFn(){
    if(whichFn == null) return true;
    var nodes = whichFn!.body;
    //Remove all invalid nodes
    nodes.removeWhere((n){
      return !n.Validate(this);
    });
    //Update nodes
    for(var n in nodes){
      n.Update();
    }
    //Check entry
    whichFn?.root?.Update();

    var cpRes = CompileShaderBody(whichFn!);

    return cpRes.last == null;
  }
  late final _analysisTask = SequentialTaskGuard<bool>(
      ()async=>AnalyzeFn()
  );

  Future<bool> BeginAnalyze(){
    return _analysisTask.RunNowOrSchedule();
  }

  @override
  void OnCodeChange() {
    NotifyCodeChange();
  }

  @override
  void RemoveNode(ShaderGraphNode node) {
    if(whichFn == null) return;
    if(!whichFn!.body.remove(node))return;
    NotifyCodeChange();
  }

  void NotifyCodeChange(){
    ClearNodeMessage();
    whichFn?.SendEventAlongChain(
        ShaderFnBodyChangeEvent()
    );
  }

  void ClearNodeMessage(){
    whichFn?.nodeMessage.clear();
  }

  @override GetNodeMessage(GraphNode node)
  => whichFn?.nodeMessage[node]??[];

  bool FnContainedInDeps(ShaderFunction? fn)
    => env?.FnContainedInDeps(fn)??false;
}

class ShaderFnEditor extends StatefulWidget {

  final ShaderFunction fn;
  final ShaderEditorEnv env;

  ShaderFnEditor(this.fn, this.env);

  @override createState() => _ShaderFnEditorState();
}

class _ShaderFnEditorState extends State<ShaderFnEditor> {

  final analyzer = ShaderFnAnalyzer();
  final _ob = Observer("ShaderFnEditor_ob");

  @override
  void initState(){
    super.initState();
    _ob.Watch<AnalyzerEvent>(analyzer, _HandleEvent);
    analyzer.env = widget.env;
    analyzer.whichFn = widget.fn;
    //widget.data.ValidateNode();
  }

  @override
  void didUpdateWidget(ShaderFnEditor oldWidget){
    super.didUpdateWidget(oldWidget);
    bool _changed = false;
    if(widget.env != oldWidget.env){
      _changed = true;
      analyzer.env = widget.env;
    }

    if(widget.fn != oldWidget.fn){
      _changed = true;
      analyzer.whichFn = widget.fn;
    }

    if(_changed){
      AnalyzeMethod();
    }
  }

  @override void dispose() {
    super.dispose();
    analyzer.Dispose();
    _ob.Dispose();
  }

  _HandleEvent(e){
    AnalyzeMethod();
  }

  void AnalyzeMethod() {
    analyzer.BeginAnalyze().then((value){
      if(!mounted) return;
      setState(() {

      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child:
      Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 300,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  widget.fn.fullName,
                  style: Theme.of(context).textTheme.headline5,
                ),

                Divider(),
                ShaderFnStatInfo(widget.fn),
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
                AnchoredPosition.fill(child: CodePage(
                  analyzer,
                )),

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

                      PopupBuilder<ShaderFunction>(
                        data: widget.fn,
                        contentBuilder: (open, dat){
                          return ElevatedButton(
                            child: Text('Edit Arguments'),
                            onPressed: open,
                          );
                        },
                        popupBuilder: (close, dat){
                          return SizedBox(
                            width: 300,
                            child: FieldEditor(
                              widget.fn.args,
                              ()=>ShaderTypes.values,
                              title: "Shader Inputs",
                            ),
                          );
                        },
                        updateShouldClose: (old){
                          return old != widget.fn;
                        },
                      ),

                      SizedBox(
                        width: 100,
                        height: 30,
                        child: SelectionPropEditor<ShaderType>(
                          initialValue: widget.fn.returnType.value,
                          requestSelections: (){
                            return ShaderTypes.values.where((e) => !e
                                .isOpaque);
                          },
                          onSelect: (ty){
                            widget.fn.returnType.value = ty!;
                          },
                          displayName: (e)=>e?.name.value??"empty",
                        ),
                      ),

                      ElevatedButton(
                          style:
                          widget.fn.nodeMessage.isNotEmpty?
                          ElevatedButton.styleFrom(
                            primary: Colors.red, // background
                            //onPrimary: Colors.white, // foreground
                          ):null
                          ,
                          child: Text("Analyze"),
                          onPressed: (){
                            AnalyzeMethod();
                          }
                      ),
                    ],
                  ),
                )
              ]
          )
          )
        ],
      ),
    );
  }
}

class ShaderFnStatInfo extends StatefulWidget {

  final ShaderFunction fn;

  const ShaderFnStatInfo(this.fn, {Key? key}) : super(key: key);

  @override
  _ShaderFnStatInfoState createState() => _ShaderFnStatInfoState();
}

class _ShaderFnStatInfoState extends State<ShaderFnStatInfo> {

  final _ob = Observer("ShaderFnMeta_ob");

  @override initState(){
    super.initState();
    _ob.Watch<ShaderFunctionChangeEvent>(widget.fn, _HandleEvt);
  }

  @override didUpdateWidget(oldWidget){
    super.didUpdateWidget(oldWidget);
    if(widget.fn != oldWidget.fn){
      _ob.Clear();
      _ob.Watch<ShaderFunctionChangeEvent>(widget.fn, _HandleEvt);
    }
  }

  @override dispose(){
    super.dispose();
    _ob.Dispose();
  }

  _HandleEvt(e){
    setState((){});
  }

  static get _ico_warn => Icons.warning;

  ///Level:
  /// - 0: correct
  /// - 1: warning
  /// - 2: error
  _BuildInfoLine(level, msg){
    var ico = level == 0? Icons.check:
              level == 1? Icons.warning:
                          Icons.error;
    var ico_color =
              level == 0? Colors.green:
              level == 1? Colors.amber:
                          Colors.red;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
      Padding(
        padding: const EdgeInsets.all(4.0),
        child: Icon(ico, color: ico_color, size: 18,),
      ),
      Expanded(child: Text(msg, softWrap: true,))
    ],);
  }

  Widget _BuildEntryIndicator(){

    _ChkArg(){
      var args = widget.fn.args;
      if(args.length < 1) {
        return _BuildInfoLine(1, "UV input: at least one argument");
      }

      var uvPos = args.fields.first;
      if(uvPos.type != ShaderTypes.float2){
        return _BuildInfoLine(1, "UV input: ${uvPos.name.value}'s type should be float2");
      }

      return _BuildInfoLine(0, "UV input: ${uvPos.name.value}");
    }

    _ChkRet(){
      var retty = widget.fn.returnType.value;
      if(!retty.IsSubTypeOf(ShaderTypes.float4)) {
        return _BuildInfoLine(1, "Color output: should be compatible with float4");
      }

      return _BuildInfoLine(0, "Color output: ${retty.fullName}");
    }

    return Column(
      children: [
        widget.fn.IsSuitableForEntry()?
        _BuildInfoLine(0, "Suitable for stage entry"):
        _BuildInfoLine(2, "Unsuitable for stage entry"),

        Padding(
          padding: const EdgeInsets.only( left:8.0, top:4),
          child: Column(children: [
            _ChkArg(),
            _ChkRet()
          ],),
        )
      ],
    );
  }

  Widget _BuildEmbeddingIndicator(){

    _ChkArg(){
      var info = <Widget>[];
      var args = widget.fn.args;
      for(var f in args.fields){
        var ty = f.type as ShaderType;
        if(ty.isOpaque){
          info.add( _BuildInfoLine(1, "Input: ${f.name.value} is ${ty.fullName}"));
        }
      }

      if(info.isEmpty)
        return  _BuildInfoLine(0, "Input: none of arguments is of opaque type");

      return Column(
        children: [
          _BuildInfoLine(2, "Input: args with opaque type:"),
          Padding(
            padding: const EdgeInsets.only(left:8.0),
            child: Column(

              children: info,
            ),
          )
        ],
      );
    }

    _ChkRet(){
      var retty = widget.fn.returnType.value;
      if(retty.isOpaque) {
        return _BuildInfoLine(1, "Output: shouldn't be opaque type");
      }

      return _BuildInfoLine(0, "Output: ${retty.fullName}");
    }

    return Column(
      children: [
        widget.fn.IsSuitableForEmbedding()?
        _BuildInfoLine(0, "Suitable for embedding"):
        _BuildInfoLine(2, "Unsuitable for embedding"),

        Padding(
          padding: const EdgeInsets.only( left:8.0, top:4),
          child: Column(children: [
            _ChkArg(),
            _ChkRet()
          ],),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(

      children: [
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: _BuildEntryIndicator(),
        ),
        Padding(
          padding: const EdgeInsets.all(4.0),
          child: _BuildEmbeddingIndicator(),
        ),
      ],
    );
  }
}


class ShaderLibInspector extends StatefulWidget {

  final ShaderLib lib;
  final ShaderEditorEnv env;
  final void Function(ShaderFunction)? onSelect;

  const ShaderLibInspector(
    this.lib,
    this.env,
    {
      Key? key,
      this.onSelect,
    }) : super(key: key);

  @override
  _ShaderLibInspectorState createState() => _ShaderLibInspectorState();
}

class _ShaderLibInspectorState extends State<ShaderLibInspector> {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: SizedBox.expand(
        child: Column(
          children: [
            Row(
              children:[
                Expanded(
                  child: Text(widget.lib.fullName,
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


            ListEditor(
              title:"Functions",
              listToEdit: ShaderLibInterface(this),
              onSelect:(e){
                if(e == null) return;
                var entry = e as LibFnEntry;
                widget.onSelect?.call(entry.fn);
              },
            ),

          ],
        ),
      ),
    );
  }

}


class ShaderLibInterface extends ListInterface{
  _ShaderLibInspectorState state;
  ShaderLibInterface(this.state);

  ShaderLib get tgtLib => state.widget.lib;

  @override
  void AddEntry(LibFnEntry entry) {
    tgtLib.AddFn(entry.fn);
  }

  @override
  Iterable<ListEditEntry> doGetEntry(){
    return [
      for(var ty in tgtLib.functions)
        LibFnEntry(ty),
    ];
  }

  @override doCreateEntryTemplate() => LibFnEntry._();

  @override RemoveEntry(LibFnEntry entry) {
    entry.fn.Dispose();
  }
}

class LibFnEntry extends ListEditEntry<ShaderLibInterface>{

  ShaderFunction fn;
  String get name => fn.name.value;

  LibFnEntry(this.fn);
  LibFnEntry._():fn = ShaderFunction();

  @override bool CanEdit()=>fn.editable;

  bool IsValid() {
    return IsConfigValid() && !fn.isDisposed;
  }

  @override
  Iterable<ListEntryProperty> EditableProps(ctx)sync* {
    if(!IsValid())
      yield StatusIndicator(EntryStatus.Error);

    yield StringProp(
        EditTypeName, initialContent:fn.name.value, hint:"Type Name"
    );
  }

  @override
  bool IsConfigValid() {return CheckIsNameValid(name);}

  bool CheckIsNameValid(String name){
    if(name == "")return false;
    var ld = (fromWhichIface).tgtLib;
    for(var ty in ld.functions){
      if(ty == fn) continue;
      if(ty.name.value == name)return false;
    }
    return true;
  }

  bool EditTypeName(name){
    if(!CheckIsNameValid(name))return false;
    fn.name.value = name;
    return true;
  }
}

class ShaderEditor extends StatefulWidget {

  final ShaderLib lib;

  const ShaderEditor(this.lib, {Key? key}) : super(key: key);

  @override
  _ShaderEditorState createState() => _ShaderEditorState();
}

class _ShaderEditorState extends State<ShaderEditor> {

  ShaderEditorEnv env = ShaderEditorEnv();


  @override void initState() {
    super.initState();
    env.targetLib = widget.lib;
  }

  @override void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.lib == oldWidget.lib) return;
    env.targetLib = widget.lib;
  }

  @override void dispose() {
    super.dispose();
    env.Dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ShaderLibInspector(widget.lib, env,
      onSelect: (type){
        Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx){
              return ShaderFnEditor(type, env);
            })
        );
      },
    );
  }
}

