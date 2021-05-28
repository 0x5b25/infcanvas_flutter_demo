

import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';

import 'package:infcanvas/canvas/canvas_tool.dart';
import 'package:infcanvas/canvas/tools/color_picker.dart';
import 'package:infcanvas/canvas/tools/infcanvas_viewer.dart';
import 'package:infcanvas/utilities/async/task_guards.dart';
import 'package:infcanvas/widgets/functional/anchor_stack.dart';
import 'package:infcanvas/widgets/functional/floating.dart';
import 'package:infcanvas/widgets/functional/multi_drag.dart';
import 'package:infcanvas/widgets/functional/tool_view.dart';
import 'package:reorderables/reorderables.dart';

class CVPainter extends CustomPainter{
  final Offset origin;
  final ui.Image? img;
  CVPainter(this.img, this.origin);
  @override
  void paint(Canvas canvas, Size size) {
    double step = 40;

    var xOrigin = origin.dx % step;
    var yOrigin = origin.dy % step;

    var xStart = xOrigin - step;
    var yStart = yOrigin - step;

    var w = step/2;
    for(var x = xStart; x <= size.width; x+=step){
      for(var y = yStart; y <= size.width; y+=step){

        var cx = x + w;
        var cy = y + w;
        canvas.drawRect(Rect.fromLTWH(x, y, w, w), Paint()..color = Colors.grey);
        canvas.drawRect(Rect.fromLTWH(cx, y, w, w), Paint()..color = Colors.grey[600]!);
        canvas.drawRect(Rect.fromLTWH(x, cy, w, w), Paint()..color = Colors.grey[600]!);
        canvas.drawRect(Rect.fromLTWH(cx, cy, w, w), Paint()..color = Colors.grey);
      }
    }

    //print("Cursor pos: ${touchPoint}");
    Paint paint = Paint();

    //cp.tree.DrawTreeToCanvas(canvas, size, cp.offset,cp.height);
    if(img != null){
      canvas.drawImage(img!, Offset.zero, paint);
    }


    //p.shader = shaderProg.GenerateShader(uniforms);
    //canvas.drawRect(Rect.fromCenter(center:Offset.zero, width: 480, height: 480),p );
    paint.color = Color.fromARGB(255, 0, 255, 0);
    canvas.drawCircle(origin, 3, paint);
    //canvas.drawRect(Rect.fromLTWH(-cp.offset.dx, -cp.offset.dy, 50, 50), p);
  }
  @override
  bool shouldRepaint(oldDelegate) => true;

}


class BrushInputOverlay extends ToolOverlayEntry{

  final BrushTool tool;

  BrushInputOverlay(this.tool);

  @override AcceptPointerInput(p){
    return tool.AcceptPointer(p);
  }

}

class _LayerThumbPainter extends CustomPainter{
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    canvas.drawPaint(Paint()..color = Color.fromARGB(255, 130, 80, 140));
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

}

class BrushSideBar extends SideBar{

  final BrushTool tool;
  BrushSideBar(this.tool);

  @override BuildContent(ctx){
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [

      ],
    );
  }

  @override OnFocusLost(){
    tool.DeactivateTool();
  }

  @override OnFocusRegain(){
    tool.ActivateTool();
  }

  @override OnRemove()async{
    tool.DeactivateTool();
  }
}

class BrushTool extends CanvasTool{
  @override get displayName => "BrushTool";

  late final MenuAction _menuAction;

  @override OnInit(mgr){
    mgr.overlayManager.RegisterOverlayEntry(_overlay, 1);
    _menuAction = mgr.menuBarManager.RegisterAction(
      MenuPath(name:"Brush"),
      () {
        if(isActive)
          DeactivateTool();
        else
          ActivateTool();
      }
    );
  }

  InfCanvasViewer get cvTool => manager.FindTool<InfCanvasViewer>()!;
  ColorPicker get colorTool => manager.FindTool<ColorPicker>()!;

  bool isActive = false;
  void ActivateTool(){
    _menuAction.isEnabled = true;
    manager.overlayManager.RegisterOverlayEntry(_overlay, 1);
    manager.sideBarManager.ShowSideBar(_sidebar);
    isActive = true;
  }

  void DeactivateTool(){
    _menuAction.isEnabled = false;
    isActive = false;
  }

  late final _overlay = BrushInputOverlay(this);
  late final _sidebar = BrushSideBar(this);

  ui.BrushInstance _brush = ui.BrushInstance();
  ui.PipelineDesc? _currBrush;

  bool get isBrushValid => _brush.isValid;

  ui.PipelineDesc? get currentBrush => _currBrush;
  set currentBrush(ui.PipelineDesc? val){
    var old = _currBrush;
    _currBrush = val;
    if(old != val){
      _brush.InstallDesc(val);
    }
  }

  CanvasParam get canvasParam => cvTool.canvasParam;

  Size brushSize = Size(50,50);
  double brushOpacity = 1.0;

  Offset ScreenToLocal(Offset pos){
    var overlaySize = manager.overlayManager.overlaySize;
    return pos - overlaySize.center(Offset.zero);
  }

  Offset GetWorldPos(Offset overlayPos){
    var centered = ScreenToLocal(overlayPos);
    var canvasCenterPos = canvasParam.offset;
    var canvasLod = canvasParam.lod;
    var cx = canvasCenterPos.positionX;
    var cy = canvasCenterPos.positionY;
    double scale = pow(2.0, -canvasLod) as double;
    return (Offset(cx, cy) + centered) * scale;
  }

  late final _brushGR = DetailedMultiDragGestureRecognizer<ui.PaintObject>()
    ..onDragStart = _OnDragStart
    ..onDragUpdate = _OnDragUpdate
    ..onDragEnd = (d, o)=>_OnDragFinished(o)
    ..onDragCancel = _OnDragFinished
  ;

  ui.PaintObject? _OnDragStart(DetailedDragEvent<PointerDownEvent> d){
    if(!_brush.isValid) return null;
    var p = d.pointerEvent;
    var worldPos = GetWorldPos(p.localPosition);
    var po = _brush.NewStroke(worldPos, colorTool.currentColor);
    return po;
  }

  _OnDragUpdate(DetailedDragUpdate d, ui.PaintObject? o){
    if(o == null) return;
    var p = d.pointerEvent;
    var delta = p.delta;
    var velocity = d.velocity.pixelsPerSecond;
    var pressure = (p.pressure - p.pressureMin)/(p.pressureMax - p.pressureMin);
    var brushPipe = o!.Update(
      brushSize, 
      GetWorldPos(p.localPosition), 
      colorTool.currentColor, 
      brushOpacity,
      velocity,
      Offset(0,p.tilt), 
      pressure
    );
  }

  _OnDragFinished(ui.PaintObject? o){
    if(o == null) return;
    o!.Dispose();
  }


  bool AcceptPointer(PointerDownEvent p) {
    var canAccept = false;

    if( _brushGR.isPointerAllowed(p)){
      _brushGR.addPointer(p);
      canAccept = true;
    }


    return canAccept;
  }
}

