
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:infcanvas/brush_manager/brush_manager.dart';
import 'package:infcanvas/brush_manager/brush_templates.dart';
import 'package:infcanvas/scripting/brush_editor.dart';
import 'package:infcanvas/scripting/brush_serializer.dart';
import 'package:infcanvas/utilities/storage/file_helper.dart';
import 'package:infcanvas/widgets/functional/tree_view.dart';
import 'package:infcanvas/widgets/visual/text_input.dart';

typedef DialogOperation = void Function(_OperationPanelState);

class OperationPanel extends StatefulWidget {

  final DialogOperation op;

  OperationPanel({
    Key? key,
    required this.op,
  }):super(key: key);

  @override
  _OperationPanelState createState() => _OperationPanelState();
}

class _OpStackElem{
  Widget widget;
  Completer c;
  _OpStackElem(this.widget, this.c);
}

class _OperationPanelState extends State<OperationPanel> {

  List<_OpStackElem> _stack = [];
  bool _init = false;

  Widget? get _current => _stack.isEmpty?null:_stack.last.widget;

  Future Push(Widget widget){
    var c = Completer();
    var elem = _OpStackElem(widget, c);
    _stack.add(elem);
    setState(() {});
    return c.future;
  }

  void Pop([val]){
    assert(_stack.isNotEmpty);
    var elem = _stack.last;
    _stack.removeLast();
    elem.c.complete(val);
    setState(() { });
  }

  @override void didUpdateWidget(OperationPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.op == oldWidget.op) return;
    _stack.clear();
    _init = false;
  }

  @override
  Widget build(BuildContext context) {
    if(!_init){
      _init = true;
      widget.op(this);
    }
    return _current??Container();
  }
}

class SimpleDialog extends StatelessWidget {
  final String title;
  final Widget? body;
  final Function()? onConfirm, onCancel;
  final bool showConfirm, showCancel;

  SimpleDialog({
    required this.title,
    this.body,
    this.onConfirm, this.onCancel,
    this.showConfirm = false,
    this.showCancel = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicWidth(
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: 300),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(title, style:Theme.of(context).textTheme.headline5),
            ),
            
            if(body!=null)
              Padding(
                padding: EdgeInsets.all(8),
                child: body!,
              ),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if(onConfirm!=null || showConfirm)
                  Padding(
                    padding:EdgeInsets.all(8),
                    child: TextButton(
                      child: Text("OK"),
                      onPressed: onConfirm,
                    ),
                  ),
                if(onCancel!=null || showCancel)
                  Padding(
                    padding:EdgeInsets.all(4),
                    child: TextButton(
                      child: Text("Cancel"),
                      onPressed: onCancel,
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

Future<BrushData> CreateEmptyBrush(_OperationPanelState state)async{
  return BrushData.createNew("New Brush");
}


Future<BrushData?> CreateBrushFromTemplate(_OperationPanelState state)async{
  var templates = await LoadTemplates();
  BrushTemplate? res = await state.Push(
    SimpleDialog(
      title: "Choose template",
      onCancel: () => state.Pop(null),
      body: SizedBox(
        height: 200,
        child: GridWrap(
          children: [
            for(var t in templates)
              TextButton(
                onPressed: ()=>state.Pop(t),
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: t.thumbnail == null
                        ?Icon(Icons.brush_outlined)
                        :Image.memory(t.thumbnail!),
                    ),
                    Text(t.name, textAlign: TextAlign.center,)
                  ],
                ),
              )
          ],
        ),
      ),
    )
  );
  if(res == null) return null;
  return DeserializeBrush(jsonDecode(res.data));
}

Future<BrushData?> ImportBrush(_OperationPanelState state)async{
  final typeGroup = TypeGroup(label: 'brush data', extensions: ['json']);
  
  _ReadFromFile()async{
    var file = await SelectAndReadFile(acceptedTypeGroups: [typeGroup]);
    try{
      if(file == null) return null;
      var str = Utf8Codec().decode(file);
      var data = jsonDecode(str);
      var brushData = DeserializeBrush(data);
      return [brushData, null];
    }catch(e){
      return [null, e];
    }
  }

  var data = await _ReadFromFile();
  //File open canceled
  if(data == null) return null;
  //Successfully decoded
  if(data.first != null) return data.first as BrushData;
  //Import failed
  await state.Push(SimpleDialog(
    title: "Import failed",
    body: Text(
      "error:${data.last}"
    ),
    onConfirm: (){state.Pop();},
  ));

  return null;
}

Future<BrushData?> CreateBrush(BuildContext ctx){

  _BuildSelection(icon,label,fn){
    return TextButton(
      onPressed: fn,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Icon(icon),
          ),
          Text(label, textAlign: TextAlign.center,),
        ],
      )
    );
  }

  return showDialog<BrushData>(
    useRootNavigator: false,
    context: ctx, 
    builder: (ctx){
      return Dialog(
        child: SizedBox(
          width: 350,
          child: OperationPanel(
            op: (state){
              
              _PerformAct(
                Future<BrushData?>Function(_OperationPanelState) fn
              )async{
                var brush = await fn(state);
                if(brush != null){
                  var ctrl = TextEditingController(text:brush.name);
                  var name = await state.Push(
                    SimpleDialog(
                      title: "Rename",
                      body: InputBox(
                        hint:"Enter name...",
                        ctrl: ctrl,
                      ),
                      onConfirm: (){state.Pop(ctrl.text);},
                      onCancel: (){state.Pop(null);},
                    )
                  );
                  if(name != null){
                    brush.name = name;
                    Navigator.of(ctx).pop(brush);
                  }
                }
              }

              state.Push(IntrinsicWidth(
                child: SimpleDialog(
                  title:"Create brush",
                  body:IntrinsicHeight(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                      _BuildSelection(Icons.add,"Empty",(){
                        _PerformAct(CreateEmptyBrush);
                      }),
                      _BuildSelection(Icons.apps,"Template",(){
                        _PerformAct(CreateBrushFromTemplate);
                      }),
                      _BuildSelection(Icons.file_download,"Import",(){
                        _PerformAct(ImportBrush);
                      }),
                    ],),
                  ),
                  onCancel:(){Navigator.of(ctx).pop(null);}
                ),
              ));
            }
          ),
        ),
      );
    }
  );
}

class BrushSelectAction extends ContentAction{
  @override
  void PerformAction(state, content) {
    var mgrState = state.context
        .findAncestorStateOfType<_BrushManagerWidgetState>();
    mgrState?.widget.onBrushSelect?.call(
      [for(var p in state.path) p as BrushCategory],
      content as BrushObject
    );
  }

  @override get name => "Select";

}

class BrushManagerWidget extends StatefulWidget {

  final BrushCategory rootCategory;
  final Function(
    List<BrushCategory>, BrushObject
  )? onBrushSelect;

  const BrushManagerWidget({
    Key? key,
    required this.rootCategory,
    this.onBrushSelect,
  }) : super(key: key);

  @override
  _BrushManagerWidgetState createState() => _BrushManagerWidgetState();
}

class _BrushManagerWidgetState extends State<BrushManagerWidget> {
  @override
  Widget build(BuildContext context) {
    return TreeViewWidget<BrushCategory>(
      root: widget.rootCategory,
      createItem: (state)async{
        var brush = await CreateBrush(state.context);
        if(brush == null) return null;
        var cat = state.current;
        var obj = BrushObject(cat,brush.name);
        obj.data = brush;
        obj.Save();
      },
    );
  }
}

