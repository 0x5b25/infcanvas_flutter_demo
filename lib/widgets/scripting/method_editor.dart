
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:infcanvas/utilities/scripting/graph_compiler.dart';
import 'package:infcanvas/widgets/scripting/vm_graphnodes.dart';
import 'package:infcanvas/utilities/scripting/opcodes.dart';
import 'package:infcanvas/utilities/scripting/script_graph.dart';
import 'package:infcanvas/utilities/scripting/vm_types.dart';
import 'package:infcanvas/widgets/functional/anchor_stack.dart';
import 'package:infcanvas/widgets/functional/floating.dart';

import 'codepage.dart';
import 'class_inspector.dart';
import 'vm_editor_data.dart';



class MethodEditor extends StatefulWidget {

  EditorMethodData meta;
  bool canEditSig;

  //void Function(EditorMethodData)? onChange;

  MethodEditor(this.meta, {this.canEditSig = true}){
    meta.UpdateNodes();
  }

  @override
  _MethodEditorState createState() => _MethodEditorState();
}

class _MethodEditorState extends State<MethodEditor> {

  void CompileMethod(){
    widget.meta.CompileGraph();
    EditorClassInfoHolder.of(context)!.NotifyUpdate();
  }

  @override
  void didUpdateWidget(MethodEditor oldWidget){
    super.didUpdateWidget(oldWidget);
    widget.meta.UpdateNodes();
  }

  @override
  Widget build(BuildContext context) {
    //Make this state rebuild when inherited widet rebuilds
    var holder = EditorClassInfoHolder.of(context);
    
    return FloatingWindowPanel(
      children:[
        AnchoredPosition.fill(child: CodePage(
          widget.meta,
          onChange:(){holder!.NotifyUpdate();}
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
              if(widget.canEditSig)
                PopupBuilder<EditorMethodData>(
                  data: widget.meta,
                  contentBuilder: (open){
                    return ElevatedButton(
                      child: Text('Edit Return'),
                      onPressed: open,
                      style: widget.meta.IsRetFieldValid()?null:
                      ElevatedButton.styleFrom(
                        primary: Colors.red
                      ),
                    );
                  }, 
                  popupBuilder: (close){
                    return _BuildRetInspector();
                  },
                  updateShouldClose: (old){
                    return old.data != widget.meta;
                  },
                ),
              if(widget.canEditSig)
                PopupBuilder<EditorMethodData>(
                  data: widget.meta,
                  contentBuilder: (open){
                    return ElevatedButton(
                      child: Text('Edit Arguments'),
                      onPressed: open,
                      style: widget.meta.IsArgFieldValid()?null:
                      ElevatedButton.styleFrom(
                        primary: Colors.red
                      ),
                    );
                  }, 
                  popupBuilder: (close){
                    return _BuildArgInspector();
                  },
                  updateShouldClose: (old){
                    return old.data != widget.meta;
                  },
                ),
              ElevatedButton(
                style: 
                widget.meta.isBodyValid?
                ElevatedButton.styleFrom(
                  primary: Colors.green, // background
                  //onPrimary: Colors.white, // foreground
                ):
                widget.meta.hasError?
                ElevatedButton.styleFrom(
                  primary: Colors.red, // background
                  //onPrimary: Colors.white, // foreground
                ):null
                ,
                child: Text('Compile'),
                onPressed: (){
                  CompileMethod();
                }
              ),
            ],
          ),
        )
      ]
    );
  }

  Widget _BuildArgInspector(){
    var cls = EditorClassInfoHolder.of(context)!.classData;
    return SizedBox(
      width: 300,
      child: FieldInspector(
        widget.meta.mtd.Args(),
        name: "Arguments",
      ),
    );
  }

  
  Widget _BuildRetInspector(){
    var cls = EditorClassInfoHolder.of(context)!.classData;
    return SizedBox(
      width: 300,
      child: FieldInspector(
        widget.meta.mtd.Rets(),
        name: "Return Values",
      ),
    );
  }
}
