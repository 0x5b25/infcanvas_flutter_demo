

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:infcanvas/brush_manager/brush_manager.dart';
import 'package:infcanvas/brush_manager/brush_manager_widget.dart';

import 'package:infcanvas/canvas/canvas_tool.dart';
import 'package:infcanvas/canvas/command.dart';
import 'package:infcanvas/canvas/tools/color_picker.dart';
import 'package:infcanvas/canvas/tools/infcanvas_viewer.dart';
import 'package:infcanvas/utilities/async/task_guards.dart';
import 'package:infcanvas/utilities/storage/app_model.dart';
import 'package:infcanvas/widgets/functional/anchor_stack.dart';
import 'package:infcanvas/widgets/functional/floating.dart';
import 'package:infcanvas/widgets/functional/multi_drag.dart';
import 'package:infcanvas/widgets/functional/tool_view.dart';
import 'package:infcanvas/widgets/functional/tree_view.dart';
import 'package:infcanvas/widgets/tool_window/color_picker.dart';
import 'package:infcanvas/widgets/visual/sliders.dart';
import 'package:path/path.dart';
import 'package:provider/provider.dart';

class _BrushPointInfo{
  late ui.HierarchicalPoint lt;

  late Size size;
  late Offset worldPos;
  late Color color;
  late double brushOpacity;
  late Offset speed;
  late Offset tilt;
  late double pressure;

  late int lod;
  late int layerID;
}

class CanvasBrushCommand extends CanvasCommand{

  late BrushTool tool;

  ui.PipelineDesc _brushProg;
  int lod;
  ui.HierarchicalPoint origin;
  Offset initialPos;
  Color initialColor;
  int layerID;
  //Brush point data
  List<_BrushPointInfo> points = [];
  
  CanvasBrushCommand(
    this._brushProg, this.layerID, this.lod, this.origin,
    this.initialColor, this.initialPos,
  );

  @override
  void Execute(CommandRecorder recorder, BuildContext ctx) {
    if(points.isEmpty) return;
    var runner = ui.BrushInstance();
    runner.InstallDesc(_brushProg);
    var paintObj = runner.NewStroke(initialPos, initialColor);
    assert(paintObj != null);
    for(var p in points){
      var pipeline = paintObj!.Update(
        p.size, p.worldPos, p.color, p.brushOpacity, p.speed, p.tilt, p.pressure
      );
      
      var tm = (Matrix4.identity()).storage;
      var layer = tool.cvTool.cvInstance.GetLayer(p.layerID);
      layer.DrawRect(p.lt.Clone(), p.lod, pipeline, tm);
    }
    tool.cvTool.canvasParam.lod = lod;
    tool.cvTool.canvasParam.offset = origin;
    //tool.cvTool.NotifyOverlayUpdate();
    paintObj!.Dispose();
    runner.Dispose();
  }
}

class AsyncPopupButton<T> extends StatefulWidget {

  AsyncPopupButton({
    Key? key,
    required this.builder,
    required this.popupBuilder,
  }):super(key: key);

  final Widget Function(
    BuildContext,
    Future<T?> Function()
  ) builder;

  final Widget Function(
    BuildContext,
    void Function([T?])
  ) popupBuilder;

  @override
  _AsyncPopupButtonState<T> createState() => _AsyncPopupButtonState<T>();
}

class _AsyncPopupButtonState<T> extends State<AsyncPopupButton<T>> {

  final _gHndle = GeometryTrackHandle();

  Future<T?> _ShowPopup(BuildContext ctx){
    var c = Completer<T?>();
    var entry = PopupProxyConfig();

    _ClsFn([T? val]){
      c.complete(val);
      entry.Close();
    }

    var animCtrl = AnimatedCloseNotifier();

    entry.contentBuilder = (ctx){
      return PopupWindow.direction(
        child: widget.popupBuilder(ctx, _ClsFn),
        tracking: _gHndle,
        closeNotifier: animCtrl,
      );
    };

    entry.onRemove = (){
      if(!c.isCompleted){
        c.complete(null);
      }
      return animCtrl.NotifyClose();
    };

    ToolViewManager.of(ctx)?.popupManager.ShowPopup(entry);

    return c.future;
  }

  @override
  Widget build(BuildContext context) {
    return GeometryTracker(
      handle: _gHndle,
      child: widget.builder(context, ()=>_ShowPopup(context))
    );
  }
}

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

class ColorIndicatorPainter extends CustomPainter{

  final Color color;
  ColorIndicatorPainter(this.color);

  @override
  void paint(ui.Canvas cv, ui.Size size) {
    double borderWidth = 4;
    var center = size.center(Offset.zero);
    var len = size.shortestSide;
    var rad = len/2;
    var b2 = borderWidth/2;
    
    //Chessboard background
    {
      Paint p = Paint()
        ..shader = ui.PaintShader(ChessboardShaderProg).MakeShaderInstance()
      ;
      cv.drawCircle(center, rad - b2, p);
    }
    {
      //Drop shadow
      Paint p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Color.fromARGB(100, 0, 0, 0)
        ..imageFilter = ui.ImageFilter.blur(sigmaX:6, sigmaY: 6)
      ;
      cv.drawCircle(center, rad - b2, p);
    }
    //Color foreground
    {
      Paint p = Paint()
        ..color = color
        ..blendMode = BlendMode.srcATop
      ;
      cv.drawCircle(center, rad - b2, p);
    }
    //Border
    {
      Paint p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..color = Color.fromARGB(255, 255, 255, 255)
      ;
      cv.drawCircle(center, rad - b2, p);
    }
  }

  @override
  bool shouldRepaint(ColorIndicatorPainter oldDelegate) {
    return oldDelegate.color != color;
  }

}

class ColorIndicatorWidget extends StatefulWidget {

  final ValueNotifier<HSVColor> colorNotifier;

  const ColorIndicatorWidget({
    Key? key,
    required this.colorNotifier,
  }) : super(key: key);

  @override
  _ColorIndicatorWidgetState createState() => _ColorIndicatorWidgetState();
}

class _ColorIndicatorWidgetState extends State<ColorIndicatorWidget> {

  HSVColor get color => widget.colorNotifier.value;

  @override initState(){
    super.initState();
    widget.colorNotifier.addListener(_OnColorChange);
  }

  @override void didUpdateWidget(ColorIndicatorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.colorNotifier != oldWidget.colorNotifier){
      oldWidget.colorNotifier.removeListener(_OnColorChange);
      widget.colorNotifier.addListener(_OnColorChange);
    }
  }

  @override dispose(){
    super.dispose();
    widget.colorNotifier.removeListener(_OnColorChange);
  }

  _OnColorChange(){
    setState(() {

    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 30,
      height: 30,
      child: CustomPaint(
        painter: ColorIndicatorPainter(color.toColor()),
      ),
    );
  }
}


class BrushMetricPainter extends CustomPainter{

  final double brushSize, brushOpacity;
  BrushMetricPainter(this.brushSize, this.brushOpacity);

  @override
  void paint(ui.Canvas cv, ui.Size size) {
    //double borderWidth = 8;
    var center = size.center(Offset.zero);
    var len = size.shortestSide;
    var rad = len/2;
    //var b2 = borderWidth/2;
    
    {
    cv.save();
    var path = Path();
    path.addArc(Rect.fromCenter(center:center,width:len, height:len),0, pi*2);
    cv.clipPath(path);
      //Chessboard background
    {
      Paint p = Paint()
        ..shader = ui.PaintShader(ChessboardShaderProg).MakeShaderInstance()
      ;
      cv.drawCircle(center, rad, p);
    }
    {
      
      //Drop shadow
      Paint p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 10
        ..color = Color.fromARGB(255, 0, 0, 0)
        ..imageFilter = ui.ImageFilter.blur(sigmaX:6, sigmaY: 6)
      ;
      cv.drawCircle(center, rad, p);
    }
    
    cv.restore();
    }
    {
      cv.save();
      var ringWidth = len * 0.05;
      var path = Path();
      var maxScale = 0.8, minScale = 0.3;
      var width = len * (minScale + (maxScale - minScale)*brushSize) - ringWidth*2;
      //Calculating angles
      var d_len = (brushOpacity - 0.5)*len;
      var d_angle = acos(d_len/(len/2));
      path.addArc(
        Rect.fromCenter(center:center,width:width, height:width), 
        d_angle - pi/2,
        (pi-d_angle)*2
      );
      cv.clipPath(path);
      {
        cv.drawColor(Color.fromARGB(250,255,255,255), BlendMode.srcOver);
      }
      cv.restore();
      cv.drawCircle(center, (width)/2 + ringWidth, Paint()
                    ..color = Color.fromARGB(250,255,255,255)
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = ringWidth
                   );
      {
        //Drop shadow
        Paint p = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Color.fromARGB(255, 0, 0, 0)
          ..imageFilter = ui.ImageFilter.blur(sigmaX:4, sigmaY: 4)
        ;
        cv.drawCircle(center, (width)/2 + ringWidth, p);
      }
    }
  }

  @override
  bool shouldRepaint(BrushMetricPainter oldDelegate) {
    return oldDelegate.brushSize != brushSize 
        || oldDelegate.brushOpacity != brushOpacity; 
  }

}

class BrushMetricWidget extends StatefulWidget {

  final BrushTool tool;

  const BrushMetricWidget(this.tool);

  @override createState() => _BrushMetricWidgetState();
}

class _BrushMetricWidgetState extends State<BrushMetricWidget> {

  BrushTool get tool => widget.tool;

  void Repaint(){ setState(() {}); }

  @override
  Widget build(BuildContext context) {
    var op = tool.brushOpacity;
    var sz = 
      (tool.brushRadius - BrushTool.minBrushSize)
      /(BrushTool.maxBrushSize - BrushTool.minBrushSize);
    return MenuButton( 
      CustomMenuPage(
        name: "BrushSettings",
        builder: (ctx, mctx){
          return Container(
            width: 240,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(children: [
                    SizedBox(
                      width: 50,
                      child: Text("Opacity", textAlign: TextAlign.center,),
                    ),
                    Expanded(child: ThinSlider(
                      value: tool.brushOpacity,
                      min: 0.0, max: 1.0,
                      onChanged: (val){
                        tool.brushOpacity = val;
                        mctx.Repaint();
                        Repaint();
                      },
                    ),)
                  ],),
                  Row(children: [
                    SizedBox(
                      width: 50,
                      child: Text("Size", textAlign: TextAlign.center),
                    ),
                    Expanded(child: ThinSlider(
                      value: tool.brushRadius,
                      min: BrushTool.minBrushSize, 
                      max: BrushTool.maxBrushSize,
                      onChanged: (val){
                        tool.brushRadius = val;
                        mctx.Repaint();
                        Repaint();
                      },
                    ),)
                  ],)
                ],
              ),
            ),
          );
        },
      ),
      (ctx, fn){
        return GestureDetector(
          onTap: (){fn();},
          child:  Center(
            child: SizedBox(
              width: 30,
              height: 30,
              child: CustomPaint(
                painter: BrushMetricPainter(sz, op),
              ),
            ),
          ),
          onHorizontalDragUpdate:(d){
            setState((){
              var dist = BrushTool.maxBrushSize - BrushTool.minBrushSize;

              tool.brushRadius+=d.delta.dx / 200 * dist;
              
              tool.manager.popupManager.ShowQuickMessage(
                Text("Brush Size : ${tool.brushRadius.toStringAsFixed(1)}")
              );
            });
          },
          onVerticalDragUpdate:(d){
            setState((){
              tool.brushOpacity-=d.delta.dy / 200;
              tool.manager.popupManager.ShowQuickMessage(
                Text("Brush Opacity : ${tool.brushOpacity.toStringAsFixed(2)}")
              );
            });
          },
        );
      },
    );
  }
}


class QuickAccessEntry{
  BrushObject brush;
  List<String> catPath;
  QuickAccessEntry(this.brush, this.catPath);

  bool Exists() => brush.file.existsSync();

  void RefreshData(){
    brush.RefreshData();
  }

  List<String> FullCatPath(){
    return [
      ...catPath,
      brush.fileName
    ];
  }

}

class BrushInputOverlay extends ToolOverlayEntry{

  final BrushTool tool;

  BrushInputOverlay(this.tool);

  Widget _BuildQAEntry(int idx){
    var entry = tool._brushQuickAccess[idx];
    _BuildButton(showCtxMenu){
      var isSelected = tool.selectedQuickAccess == entry;
      if(isSelected){
        bool hasErr = !tool.isBrushValid;
        return ElevatedButton(
          style: ElevatedButton.styleFrom(
            padding: EdgeInsets.zero
          ),
          onPressed: showCtxMenu,
          child: Padding(
            padding: const EdgeInsets.all(1.0),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                children:[
                  Center(child:entry.brush.thumbnail!),
                  if(hasErr)
                  Positioned(
                    right: 0, bottom: 0,
                    child: Icon(Icons.error,size: 18,color: Colors.red,)
                  ),
                ]
              )
            ),
          )
        );
      }else{
        return TextButton(
          onPressed: (){
            tool.SelectQuickAccess(idx);
            tool.ScheduleSaveState();
            manager.Repaint();
          },
          onLongPress: showCtxMenu,
          child: entry.brush.thumbnail!
        );
      }
    }

    return AsyncPopupButton(
      builder: (ctx, showFn){
        return AspectRatio(
          aspectRatio:1,
          child:Padding(
            padding: const EdgeInsets.all(4.0),
            child: _BuildButton(showFn),
          )
        );
      },
      popupBuilder: (ctx, clsFn){
        return Container(
          width: 150,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: ShadowScrollable(
                  child: Text(entry.brush.name),
                  direction: Axis.horizontal
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Expanded(
                      child:TextButton(
                        child: Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 3/2,
                              child: Icon(Icons.edit),
                            ),
                            Text("Edit"),
                          ],
                        ),
                        onPressed: ()async{
                          clsFn();
                          await ShowBrushEditor(ctx, entry.brush);
                          tool._ReloadBrushPipeline();
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton(
                        style: TextButton.styleFrom(
                          primary: Colors.red
                        ),
                        child: Column(
                          children: [
                            AspectRatio(
                              aspectRatio: 3/2,
                              child: Icon(Icons.delete_forever),
                            ),
                            Text("Remove"),
                          ],
                        ),
                        onPressed: (){
                          clsFn();
                          tool._RemoveQuickAccess(idx);
                          manager.Repaint();
                        },
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        );
      }
    );
  }

  @override BuildSideBar(ctx){
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ShadowScrollable(
            direction: Axis.vertical,
            child: Column(
              children: [
                for(int i = 0; i < tool._brushQuickAccess.length; i++)
                  _BuildQAEntry(i),
              ],
            ),
          )
        ),
        AspectRatio(
          aspectRatio: 1,
          child: AsyncPopupButton<ui.PipelineDesc>(
            builder:(ctx, fn){
              return TextButton(
                onPressed: (){
                  fn().then((_){tool._RefreshQuickAccess();});
                },
                child: Icon(Icons.add)
              );
            },
            popupBuilder: (ctx, retFn){
              return Container(
                width: 240, height: 400,
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: BrushManagerWidget(
                    rootCategory:tool.brushRootCat,
                    onBrushSelect: (path, brush){
                      var catPath = [
                        for(int i = 1; i < path.length; i++) path[i].fileName,
                      ];
                      var entry = QuickAccessEntry(brush, catPath);
                      tool._AddToQuickAccess(entry);
                      manager.Repaint();
                    },
                  ),
                ),
              );
            },
          ),
        ),
        AspectRatio(
          aspectRatio: 1,
          child: TextButton(
            onPressed: (){
              tool.colorTool.ShowColorPicker();
            },
            child: ColorIndicatorWidget(
              colorNotifier: tool.colorTool.onColorChange
            ),
          ),
        ),
        AspectRatio(
          aspectRatio: 1,
          child: BrushMetricWidget(tool),
        )
      ],
    );
  }

  @override AcceptPointerInput(p){
    return tool.AcceptPointer(p);
  }


  @override OnRemove(){
    tool.DeactivateTool();
  }

}

class StepRegister<T>{

  final T data;
  double residual = 0;
  final double? step;
  final double Function()? stepGetter;
  Offset currPos;

  double get _step => max(1,step??(stepGetter!()));

  StepRegister(this.data, this.currPos,
  {
    this.step,
    this.stepGetter,
  }){
    assert(step != null || stepGetter != null);
  }

  void Move(Offset to, void Function(T, Offset) update){
    var distance =(to-currPos).distance;
    var total = distance + residual;
    int stepCnt = total ~/ _step;
    var newResidual = total - _step*stepCnt;
    var advance = -residual;
    var dir = (to-currPos)/distance;
    for(int i = 0; i < stepCnt; i++){
      advance += _step;
      var pos = currPos + dir*advance;
      update(data, pos);
    }

    currPos = to;
    residual = newResidual;
  }
}

class StrokeHolder{
  late ui.PaintObject paintObj;
  late CanvasBrushCommand command;
}

class BrushTool extends CanvasTool{
  @override get displayName => "BrushTool";

  late final MenuAction _menuAction;

  AppModel? _model;
  late BrushCategory brushRootCat;

  @override OnInit(mgr, ctx){
    //mgr.overlayManager.RegisterOverlayEntry(_overlay, 1);
    _menuAction = mgr.menuBarManager.RegisterAction(
      MenuPath(name:"Brush"),
      () {
        if(isActive)
          DeactivateTool();
        else
          ActivateTool();
      }
    );

    mgr.RegisterReplayFinishListener(() { _ReloadBrushPipeline();});

    _model = Provider.of<AppModel>(ctx, listen: false);
    try{
      RestoreState();
    }catch(e){
      debugPrint("BrushTool restore state failed: $e");
    }
  }

  late final _saveTaskGuard = DelayedTaskGuard(
    (_)=>SaveState(), Duration(seconds: 3)
  );

  void ScheduleSaveState(){
    _saveTaskGuard.Schedule();
  }

  void SaveState(){
    _model?.SaveModel("tool_brush",{
      "isActive":isActive,
      "quickAccess":[
        for(var q in _brushQuickAccess) q.FullCatPath()
      ],
      "quickAccessSelection":_quickAccessSel,
      "brushRadius":brushRadius,
      "brushOpacity":brushOpacity,
    });
  }

  void RestoreState(){
    //Brush root
    Map<String, dynamic> data = _model!.ReadModel("tool_brush");

    brushRadius = ReadMapSafe(data, "brushRadius")??50;
    brushOpacity = ReadMapSafe(data, "brushOpacity")??0.8;

    //Tool state
    bool isToolActive = ReadMapSafe(data,"isActive") ?? false;
    if(isToolActive){
      ActivateTool();
    }

    var modelDir = _model!.GetStorageDir() as Directory;
    var brushDir = Directory(join(modelDir.path, "brushes"));
    if(!brushDir.existsSync()) brushDir.createSync();
    brushRootCat = BrushCategory(brushDir);
    //Quick access
    _quickAccessSel = -1;
    _brushQuickAccess = [];
    List registeredBrushed = ReadMapSafe(data,"quickAccess")??[];
    int sel = ReadMapSafe(data,"quickAccessSelection")??-1;
    int actualSel = -1;
    for(int i = 0; i < registeredBrushed.length; i++){
      var path = List<String>.from(registeredBrushed[i]);
      var res = brushRootCat.Search(path);
      if(res is BrushObject){
        path.removeLast();
        if(i == sel){
          actualSel = _brushQuickAccess.length;
        }
        _AddToQuickAccess(QuickAccessEntry(res, path));
      }
    }
    SelectQuickAccess(actualSel);
    
  }

  InfCanvasViewer get cvTool => manager.FindTool<InfCanvasViewer>()!;
  ColorPicker get colorTool => manager.FindTool<ColorPicker>()!;

  bool isActive = false;
  void ActivateTool(){
    if(isActive) return;
    _menuAction.isActivated = true;
    manager.overlayManager.RegisterOverlayEntry(_overlay, 1);
    isActive = true;
    ScheduleSaveState();
  }

  void DeactivateTool(){
    if(!isActive) return;
    isActive = false;
    manager.overlayManager.RemoveOverlayEntry(_overlay);
    _menuAction.isActivated = false;
    ScheduleSaveState();
  }

  late final _overlay = BrushInputOverlay(this);

  List<QuickAccessEntry> _brushQuickAccess = [];
  int _quickAccessSel = -1;
  QuickAccessEntry? get selectedQuickAccess =>
    (_quickAccessSel < 0 || _quickAccessSel > _brushQuickAccess.length)?
      null:_brushQuickAccess[_quickAccessSel];
  void SelectQuickAccess(int idx){
    if(idx < 0 || idx > _brushQuickAccess.length){
      _quickAccessSel = -1;
    }else{
      _quickAccessSel = idx;
    }
    _ReloadBrushPipeline();
  }

  void _ReloadBrushPipeline(){
    var newProg = selectedQuickAccess?.brush.data.PackageBrush().first;
    currentBrush = newProg;
    manager.Repaint();
  }

  void _RefreshQuickAccess() {
    var qa = selectedQuickAccess;
    //qa not null and not exists
    if(!(qa?.Exists()??true)) _quickAccessSel = -1;

    _brushQuickAccess.removeWhere((e) => !e.Exists());
    for(var e in _brushQuickAccess){
      e.RefreshData();
    }
    _ReloadBrushPipeline();
    ScheduleSaveState();
  }

  void _AddToQuickAccess(QuickAccessEntry entry){
    var nPath = entry.brush.file.path;
    for(var c in _brushQuickAccess){
      var cPath = c.brush.file.path;
      if(equals(nPath, cPath)){
        c.RefreshData(); return;
      }
    }
    _brushQuickAccess.add(entry);
    ScheduleSaveState();
  }


  void _RemoveQuickAccess(int idx){
    //for(int i = 0; i < _brushQuickAccess.length;i++){
    //  var e = _brushQuickAccess[i];
    //  if(e == entry){
    //    if(i == _quickAccessSel) i = -1;
    //    else if( i < _quickAccessSel) _quickAccessSel -=1;
    //    _brushQuickAccess.removeAt(i);
    //    ScheduleSaveState();
    //    return;
    //  }
    //}
    if(idx < 0 || idx >= _brushQuickAccess.length) return;
    if(idx == _quickAccessSel) _quickAccessSel = -1;
    else if( idx < _quickAccessSel) _quickAccessSel -=1;
    _brushQuickAccess.removeAt(idx);
    ScheduleSaveState();
  }

  ui.BrushInstance _brush = ui.BrushInstance();
  ui.PipelineDesc? _currBrushProg;

  bool get isBrushValid => _brush.isValid;

  ui.PipelineDesc? get currentBrush => _currBrushProg;
  set currentBrush(ui.PipelineDesc? val){
    var old = _currBrushProg;
    _currBrushProg = val;
    if(old != val){
      _brush.InstallDesc(val);
    }
  }

  CanvasParam get canvasParam => cvTool.canvasParam;

  Size _brushSize = Size(50,50);
  static const double minBrushSize = 1;
  static const double maxBrushSize = 100;
  double get brushRadius => _brushSize.width;
  set brushRadius(double val){
    var cval = val.clamp(minBrushSize, maxBrushSize);
    if(cval == brushRadius) return;
    _brushSize = Size(cval,cval);
    ScheduleSaveState();
  }
  double _brushOpacity = 1.0;
  double get brushOpacity => _brushOpacity;
  set brushOpacity(double val){
    _brushOpacity = val.clamp(0,1);
    ScheduleSaveState();
  }

  Offset ScreenToLocal(Offset pos){
    var canvasScale = canvasParam.canvasScale;
    var overlaySize = manager.overlayManager.overlaySize;
    return (pos - overlaySize.center(Offset.zero))/canvasScale;
  }

  Offset LocalToWorldPos(Offset localPos){
    var canvasCenterPos = canvasParam.offset;
    var canvasLod = canvasParam.lod;
    var cx = canvasCenterPos.positionX;
    var cy = canvasCenterPos.positionY;
    double scale = pow(2.0, -canvasLod) as double;
    return (Offset(cx, cy) + localPos) * scale;
  }

  Offset GetWorldPos(Offset overlayPos){
    var centered = ScreenToLocal(overlayPos);
    return LocalToWorldPos(centered);
  }

  late final _brushGR = 
    DetailedMultiDragGestureRecognizer<
      StepRegister<StrokeHolder>
    >()
    ..onDragStart = _OnDragStart
    ..onDragUpdate = _OnDragUpdate
    ..onDragEnd = (d, o){_OnDragFinished(o);}
    ..onDragCancel = _OnDragFinished
  ;

  StepRegister<StrokeHolder>? _OnDragStart(DetailedDragEvent<PointerDownEvent> d){
    if(!_brush.isValid) return null;
    if(!cvTool.isActiveLayerDrawable) return null;
    colorTool.NotifyColorUsed();
    var p = d.pointerEvent;
    var worldPos = GetWorldPos(p.localPosition);
    var po = _brush.NewStroke(worldPos, colorTool.currentColor);
    if(po == null) return null;

    var cmd = CanvasBrushCommand(
      currentBrush!, 
      cvTool.activeLayerIdx,
      canvasParam.lod,
      canvasParam.offset.Clone(),
      colorTool.currentColor, worldPos
    )..tool = this;

    var holder = StrokeHolder()..paintObj = po..command = cmd;

    return StepRegister(
      holder, ScreenToLocal(p.localPosition), 
      stepGetter: (){
        return brushRadius * (selectedQuickAccess?.brush.data.spacing
        ??1)
        ;
      }
    );
  }

  _OnDragUpdate(DetailedDragUpdate d, StepRegister<StrokeHolder>? o){
    if(o == null) return;
    var p = d.pointerEvent;
    var pos = ScreenToLocal(p.localPosition);
    var velocity = d.velocity.pixelsPerSecond;
    var pressure = (p.pressure - p.pressureMin)/(p.pressureMax - p.pressureMin);
    pressure = pressure.clamp(0, 1);

    var cvCenter = cvTool.offset;

    o.Move(pos, (holder, pos ) {
      var brushPipe = holder.paintObj.Update(
        _brushSize, 
        LocalToWorldPos(pos), 
        colorTool.currentColor, 
        brushOpacity,
        velocity,
        Offset(p.orientation,p.tilt), 
        pressure
      );
      var _tBrushSize = Offset(_brushSize.width, _brushSize.height);
      var lt = cvCenter.Translated(pos - _tBrushSize/2);

      holder.command.points.add(_BrushPointInfo()
        ..lt = lt.Clone()
        ..size = _brushSize
        ..worldPos = LocalToWorldPos(pos)
        ..color = colorTool.currentColor
        ..brushOpacity = brushOpacity
        ..speed = velocity
        ..tilt = Offset(p.orientation,p.tilt)
        ..pressure = pressure
        ..lod = cvTool.lod
        ..layerID = cvTool.activeLayerIdx
      );

      cvTool.DrawOnActiveLayer(lt, cvTool.lod, brushPipe);

    });
  }

  _OnDragFinished(StepRegister<StrokeHolder>? o){
    if(o == null) return;
    o.data.paintObj.Dispose();
    manager.RecordCommand(o.data.command);
  }


  bool AcceptPointer(PointerEvent p) {
    if(p is! PointerDownEvent) return false;

    if(p.kind == PointerDeviceKind.mouse){
      if((p.buttons & kPrimaryMouseButton) == 0)
        return false;
    }

    var canAccept = false;

    if( _brushGR.isPointerAllowed(p)){
      _brushGR.addPointer(p);
      canAccept = true;
    }


    return canAccept;
  }

  @override Dispose(){
    _brush.Dispose();
    _brushGR.dispose();
    _saveTaskGuard.FinishImmediately();
  }

}

