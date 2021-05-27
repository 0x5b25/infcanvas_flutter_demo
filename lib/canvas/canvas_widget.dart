
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:infcanvas/canvas/canvas_tool.dart';
import 'package:infcanvas/canvas/tools/color_picker.dart';
import 'package:infcanvas/canvas/tools/infcanvas_viewer.dart';
import 'package:infcanvas/widgets/functional/floating.dart';
import 'package:infcanvas/widgets/functional/tool_view.dart';


class CanvasWidget extends StatefulWidget {
  const CanvasWidget({Key? key}) : super(key: key);

  @override
  _CanvasWidgetState createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends State<CanvasWidget> {

  final manager = ToolManager()
    ..tools = [
      InfCanvasViewer(),
      ColorPicker(),
    ]
    ;

  _CanvasWidgetState(){
    manager.menuBarManager.RegisterAction(
      MenuPath().Next("Back", Icons.home_filled),
      () { }
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: ToolView(manager: manager,),
    );
  }
}

