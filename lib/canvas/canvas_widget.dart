
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:infcanvas/canvas/canvas_tool.dart';
import 'package:infcanvas/canvas/tools/brush_tool.dart';
import 'package:infcanvas/canvas/tools/color_picker.dart';
import 'package:infcanvas/canvas/tools/file_util.dart';
import 'package:infcanvas/canvas/tools/infcanvas_viewer.dart';
import 'package:infcanvas/widgets/functional/floating.dart';
import 'package:infcanvas/widgets/functional/tool_view.dart';


class CanvasWidget extends StatefulWidget {
  const CanvasWidget({Key? key}) : super(key: key);

  @override
  _CanvasWidgetState createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends State<CanvasWidget> {

  late final CanvasToolManager manager;
  @override initState(){
    super.initState();
    manager = CanvasToolManager()
      ..tools = [
        InfCanvasViewer(),
        ColorPicker(),
        BrushTool(),
        FileUtil(),
      ]
    ;
    manager.menuBarManager.RegisterAction(
        MenuPath().Next("Undo", Icons.undo),
        () { manager.UndoOneStep(); }
    );

    manager.menuBarManager.RegisterAction(
        MenuPath().Next("Redo", Icons.redo),
        () { manager.RedoOneStep();}
    );

    manager.InitTools(context);
    manager.menuBarManager.RegisterAction(
        MenuPath().Next("Back", Icons.home_filled),
            () { }
    );
    manager.menuBarManager.RegisterAction(
        MenuPath().Next("Debug message", Icons.message),
            () { 
              manager.popupManager.ShowQuickMessage(Text("Hello"));
            }
    );
  }

  @override dispose(){
    super.dispose();
    manager.Dispose();
  }

  _CanvasWidgetState(){

  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ToolView(manager: manager,),
    );
  }
}

