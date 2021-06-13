
import 'package:flutter/material.dart';
import 'package:infcanvas/scripting/editor/vm_types.dart';
import 'package:infcanvas/widgets/functional/anchor_stack.dart';
import 'package:infcanvas/scripting/editor_widgets.dart';
import 'package:infcanvas/widgets/functional/floating.dart';
import 'package:infcanvas/scripting/codepage.dart';
import 'package:infcanvas/scripting/editor/codemodel_events.dart';
import 'package:infcanvas/scripting/code_element.dart';
import 'package:infcanvas/scripting/editor/vm_editor.dart';

import 'codemodel.dart';

class VMTypeInspector extends StatefulWidget {

  final CodeType type;
  final VMEditorEnv env;

  Iterable<CodeType> _AvailTypes()=>env.AccessableTypes(type);

  const VMTypeInspector(
    this.type,
    this.env,
    {
      Key? key
    }) : super(key: key);

  @override
  _VMTypeInspectorState createState() => _VMTypeInspectorState();
}

class _VMTypeInspectorState extends State<VMTypeInspector> {

  CodeMethod? _selectedMtd;

  void _SelectMethod(CodeMethodBase? mtd){
    if(_selectedMtd == mtd) return;

    setState(() {
      if(mtd is BuiltinMethod){
        _selectedMtd = null;
      }else {
        _selectedMtd = mtd as CodeMethod;
      }
    });
  }

  Widget _BuildSideBar(BuildContext context,
    void Function(CodeMethodBase?) onSel
  ){
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.type.fullName, style: Theme.of(context)
                  .textTheme
                  .headline5,),

              Divider(),
              //Text("Fields", style: Theme.of(context).textTheme.bodyText1,),
              Card(
                child: FieldEditor(
                  widget.type.fields,
                  widget._AvailTypes,
                  title:"Fields",
                ),
              ),

              //Text("StaticFields", style: Theme.of(context).textTheme.bodyText1,),
              Card(
                  child: FieldEditor(
                    widget.type.staticFields,
                    widget._AvailTypes,
                    title:"Static Fields",
                  ),
              ),


              Card(
                child: MethodSigInspector(
                  widget.type,
                  widget.env,
                  widget._AvailTypes,
                  onSelect: onSel,
                ),
              )

            ],
          ),
        ),
        ElevatedButton(
            onPressed: (){
              Navigator.of(context).pop();
            },
            child: Text("Back")
        ),
      ],
    );
  }

  Widget _BuildCodePage(CodeMethod? selected
    , List<CustomOp> ops
  ){
    return Material(
      child: Container(
        child: (selected == null)?null:
        MethodBodyEditor(selected,widget.env, customOps: ops,),
      ),
    );
  }

  Widget _BuildFullLayout(BuildContext context){
    return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
              width: 300,
              color: Colors.white,
              child: _BuildSideBar(context, _SelectMethod)
          ),
          Expanded(
            child: _BuildCodePage(_selectedMtd, [])
          )
        ],
      );
  }

  Widget _BuildSlimLayout(BuildContext context){
    return  Container(
      color: Colors.white,
      child: _BuildSideBar(context, (mtd){
        _selectedMtd = mtd as CodeMethod?;
        if(mtd == null) return;
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_){
            return _BuildCodePage(
              mtd as CodeMethod,
              [
                CustomOp("Back", () {
                  Navigator.of(context).pop();
                })
              ]
            );
          })
        );
      })
    );
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      child: LayoutBuilder(
        builder: (ctx, size){
          if(size.maxWidth < 700){
            return _BuildSlimLayout(context);
          }else{
            return _BuildFullLayout(context);
          }
        },
      )
    );
  }
}

class CustomOp{
  String name;
  void Function() action;
  CustomOp(this.name, this.action);
}

class MethodBodyEditor extends StatefulWidget {

  final CodeMethod method;
  final VMEditorEnv env;
  final List<CustomOp> customOps;

  const MethodBodyEditor(
    this.method,
    this.env,
    {
      Key? key,
      this.customOps = const []
    }
  ) : super(key: key);

  @override
  _MethodBodyEditorState createState() => _MethodBodyEditorState();
}

class _MethodBodyEditorState extends State<MethodBodyEditor> {

  final analyzer = VMMethodAnalyzer();
  final _ob = Observer("MethodBodyEditor_ob");

  @override void initState() {
    super.initState();
    _ob.Watch<AnalyzerEvent>(analyzer, _HandleEvent);
    analyzer.env = widget.env;
    analyzer.whichMethod = widget.method;
    AnalyzeMethod();
  }

  @override void didUpdateWidget(covariant MethodBodyEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    bool _changed = false;
    if(widget.env != oldWidget.env){
      _changed = true;
      analyzer.env = widget.env;
    }

    if(widget.method != oldWidget.method){
      _changed = true;
      analyzer.whichMethod = widget.method;
    }

    if(_changed){
      AnalyzeMethod();
    }
  }


  _HandleEvent(e){
    //if(!mounted) return;
    //analyzer.BeginAnalyzeMethod().then((value){
    //  if(!mounted) return;
    //  setState(() {
//
    //  });
    //});
    AnalyzeMethod();
  }

  @override void dispose() {
    super.dispose();
    _ob.Dispose();
    analyzer.Dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FloatingWindowPanel(
        children:[
          AnchoredPosition.fill(child: CodePage(
              analyzer,
              onChange:(){}
          )),

          FloatingWindow(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for(var op in widget.customOps)
                  TextButton(
                    onPressed: op.action,
                    child: Text(op.name)
                  )
              ],
            ),
          ),

          FloatingWindow(
            anchor: Rect.fromLTRB(1,0,1,0),
            align: Offset(1,0),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupBuilder<CodeMethod>(
                  data: widget.method,
                  contentBuilder: (open, dat){
                    return ElevatedButton(
                      child: Text('Edit Return'),
                      onPressed: open,
                    );
                  },
                  popupBuilder: (close, dat){
                    return SizedBox(
                      width: 300,
                      child: FieldEditor(
                        dat!.rets,widget.env.LoadedTypes,
                        title: "Return Values",
                      ),
                    );
                  },
                  updateShouldClose: (old){
                    return old != widget.method;
                  },
                ),
                PopupBuilder<CodeMethod>(
                  data: widget.method,
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
                        dat!.args, widget.env.LoadedTypes,
                        title: "Arguments",
                      ),
                    );
                  },
                  updateShouldClose: (old){
                    return old != widget.method;
                  },
                ),
                ElevatedButton(
                    style:
                    widget.method.nodeMessage.isNotEmpty?
                    ElevatedButton.styleFrom(
                      primary: Colors.red, // background
                      //onPrimary: Colors.white, // foreground
                    ):null
                    ,
                    child: Text('Analyze'),
                    onPressed: (){
                      AnalyzeMethod();
                    }
                ),
              ],
            ),
          )
        ]
    );
  }

  void AnalyzeMethod() {
    analyzer.BeginAnalyzeMethod().then((value){
      if(!mounted) return;
      setState(() {

      });
    });
  }
}

class MethodSigInspector extends StatefulWidget {

  final CodeType type;
  final VMEditorEnv env;
  final Iterable<CodeType> Function() typeProvider;

  final void Function(CodeMethodBase)? onSelect;

  const MethodSigInspector(
    this.type, this.env, this.typeProvider,
      {Key? key, this.onSelect}) : super(key: key);

  @override
  _MethodSigInspectorState createState() => _MethodSigInspectorState();
}

class _MethodSigInspectorState extends State<MethodSigInspector> {

  var _ob = Observer("MethodSigInspector_ob");

  @override void initState() {
    super.initState();
    _ob.Watch<MethodChangeEvent>(widget.type, _HandleEvent);
  }

  @override didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.type == oldWidget.type) return;
    _ob.StopWatching(oldWidget.type);
    _ob.Watch<MethodChangeEvent>(widget.type, _HandleEvent);
  }

  @override void dispose() {
    super.dispose();
    _ob.Dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListEditor(
      title: "Methods",
      listToEdit: MethodManInterface(this),
      onSelect:(entry) {
        var e = entry as MethodEntry;
        widget.onSelect?.call(e.method);
      },
    );
  }

  void _HandleEvent(MethodChangeEvent p1) {
    setState(() {

    });
  }
}


class MethodManInterface extends ListInterface{

  _MethodSigInspectorState state;
  Iterable<CodeMethodBase> get methods => state.widget.type.methods;
  Iterable<CodeType> get availableTypes => state.widget.typeProvider();
  //void Function() notifyChange;

  MethodManInterface(this.state);


  @override
  void AddEntry(MethodEntry entry) {
    state.widget.type.AddMethod(entry.method);
  }

  @override
  void RemoveEntry(MethodEntry entry) {
    entry.method.Dispose();
  }

  @override doCreateEntryTemplate() => MethodEntry._();

  @override
  Iterable<MethodEntry> doGetEntry() {
    return[
      for(var m in methods)
        MethodEntry(m),
    ];
  }

}

class MethodEntry extends ListEditEntry<MethodManInterface>{
  CodeMethodBase method;

  MethodEntry(this.method);
  MethodEntry._():method = CodeMethod();
  //VMMethodInfo get mtd;

  @override CanEdit() => method.editable;

  bool get hasError =>
    method is CodeMethod?
      (method as CodeMethod).nodeMessage.isNotEmpty
    :false;

  @override
  Iterable<ListEntryProperty> EditableProps(ctx) {
    return [
      if(hasError)
        StatusIndicator(EntryStatus.Error),
      StringProp(
            (s){return EditMethodName(s, ctx);},
        initialContent: method.name.value,
        hint: "Method name",
      ),
      BoolProp("S", method.isStatic.value,
        (val){
          method.isStatic.value = val;
        }
      ),
      BoolProp("C", method.isConst.value,
        (val){
          method.isConst.value = val;
        }
      )
    ];
  }

  @override
  bool IsConfigValid()=>CheckIsNameValid(method.name.value);


  bool CheckIsNameValid(String name){
    if(name == "")return false;
    for(var mtd in fromWhichIface.methods){
      if(mtd == method) continue;
      if(mtd.name.value == name)return false;
    }
    return true;
  }

  bool EditMethodName(String newName, BuildContext ctx){
    var valid = CheckIsNameValid(newName);
    if(valid){
      method.name.value = newName;
    }
    return valid;
  }
}


