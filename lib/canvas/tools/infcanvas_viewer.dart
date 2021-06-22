import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:infcanvas/canvas/canvas_tool.dart';
import 'package:infcanvas/canvas/command.dart';
import 'package:infcanvas/utilities/async/task_guards.dart';
import 'package:infcanvas/utilities/storage/app_model.dart';
import 'package:infcanvas/widgets/functional/anchor_stack.dart';
import 'package:infcanvas/widgets/functional/any_drag.dart';
import 'package:infcanvas/widgets/functional/floating.dart';
import 'package:infcanvas/widgets/functional/tool_view.dart';
import 'package:infcanvas/widgets/tool_window/color_picker.dart';
import 'package:infcanvas/widgets/visual/buttons.dart';
import 'package:infcanvas/widgets/visual/sliders.dart';
import 'package:provider/provider.dart';
import 'package:reorderables/reorderables.dart';

abstract class CanvasViewerCommand extends CanvasCommand{
  late InfCanvasViewer tool;
  late int activeLayer;
  ui.CanvasInstance get cvInst => tool.cvInstance;
  
}

class CanvasLayerParamChangeCommand extends CanvasViewerCommand{
  int layerID;
  //Params
  BlendMode blendMode;
  double alpha;

  CanvasLayerParamChangeCommand(
    this.layerID,
    this.blendMode,
    this.alpha
  );

  @override
  void Execute(CommandRecorder recorder, BuildContext ctx) {
    assert(layerID >= 0 && layerID < cvInst.LayerCount());
    var layer = cvInst.GetLayer(layerID);
    layer.blendMode = blendMode;
    layer.alpha = alpha;
  } 
}

class CanvasLayerAddCommand extends CanvasViewerCommand{
  @override
  void Execute(CommandRecorder recorder, BuildContext ctx) {
    cvInst.CreatePaintLayer();
  }
}

class CanvasLayerRemoveCommand extends CanvasViewerCommand{

  int layerID;
  CanvasLayerRemoveCommand(this.layerID);

  @override
  void Execute(CommandRecorder recorder, BuildContext ctx) {
    assert(layerID >= 0 && layerID < cvInst.LayerCount());
    cvInst.GetLayer(layerID).Remove();
  }
}

class CanvasLayerMoveCommand extends CanvasViewerCommand{

  int layerID;
  int pos;
  CanvasLayerMoveCommand(this.layerID, this.pos);

  @override
  void Execute(CommandRecorder recorder, BuildContext ctx) {
    assert(layerID >= 0 && layerID < cvInst.LayerCount());
    cvInst.GetLayer(layerID).MoveTo(pos);
  }
}

class CanvasLayerMergeCommand extends CanvasViewerCommand{

  int layerID;
  CanvasLayerMergeCommand(this.layerID);

  @override
  void Execute(CommandRecorder recorder, BuildContext ctx) {
    assert(layerID >= 0 && layerID < cvInst.LayerCount() - 1);
    cvInst.MergeDownPaintLayer(layerID);
  }
}

class CanvasLayerDupCommand extends CanvasViewerCommand{

  int layerID;
  CanvasLayerDupCommand(this.layerID);

  @override
  void Execute(CommandRecorder recorder, BuildContext ctx) {
    assert(layerID >= 0 && layerID < cvInst.LayerCount());
    cvInst.DuplicatePaintLayer(layerID);
  }
}


class CVPainter extends CustomPainter{
  final CVViewerOverlay overlay;
  Offset get origin=>overlay.off;
  ui.Picture? get img=>overlay.pic;
  double get canvasScale => overlay.canvasScale;

  InfCanvasViewer get tool => overlay.tool;

  Color get bgColor => tool.bgColor;
  bool get showBG => tool.showBgColor;

  CVPainter._(this.overlay, ChangeNotifier color):
  super(repaint: color);

  factory CVPainter(CVViewerOverlay overlay){
    return CVPainter._(overlay, overlay.tool._bgColorCtrl.colorNotifier);    
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);

    var cvW = size.width * (canvasScale - 1);
    var cvH = size.height * (canvasScale - 1);

    canvas.translate(-cvW/2, -cvH/2);
    canvas.scale(canvasScale);

    double step = 40;

    var xOrigin = origin.dx % step;
    var yOrigin = origin.dy % step;

    var xStart = - xOrigin;
    var yStart = - yOrigin;

    var w = step/2;
    for(var x = xStart; x <= size.width; x+=step){
      for(var y = yStart; y <= size.height; y+=step){

        var cx = x + w;
        var cy = y + w;
        canvas.drawRect(
          Rect.fromLTWH(x, y, w, w), Paint()..color = Colors.grey..isAntiAlias = true);
        canvas.drawRect(
          Rect.fromLTWH(cx, y, w, w), Paint()..color = Colors.grey[600]!..isAntiAlias = true);
        canvas.drawRect(
          Rect.fromLTWH(x, cy, w, w), Paint()..color = Colors.grey[600]!..isAntiAlias = true);
        canvas.drawRect(
          Rect.fromLTWH(cx, cy, w, w), Paint()..color = Colors.grey..isAntiAlias = true);
      }
    }

    if(showBG){
      canvas.drawColor(bgColor, BlendMode.srcOver);
    }

    //print("Cursor pos: ${touchPoint}");
    Paint paint = Paint();
    paint.filterQuality = FilterQuality.high;

    //cp.tree.DrawTreeToCanvas(canvas, size, cp.offset,cp.height);
    if(img != null){
      canvas.drawPicture(img!);//(img!, Offset.zero, paint);
    }


    //p.shader = shaderProg.GenerateShader(uniforms);
    //canvas.drawRect(Rect.fromCenter(center:Offset.zero, width: 480, height: 480),p );
    //paint.color = Color.fromARGB(255, 0, 255, 0);
    //canvas.drawCircle(origin, 3, paint);
    //canvas.drawRect(Rect.fromLTWH(-cp.offset.dx, -cp.offset.dy, 50, 50), p);
  }
  @override
  bool shouldRepaint(oldDelegate) => true;

}



class CVViewerOverlay extends ToolOverlayEntry{

  final InfCanvasViewer tool;
  final cvKey = GlobalKey(debugLabel:"CanvasPainter");

  ui.Picture? pic;
  Offset off = Offset.zero;
  double canvasScale = 1.0;

  void _DrawSnapshot(ui.Picture pic, Offset off, double cvScale){
    this.pic = pic; this.off = off;this.canvasScale = cvScale;
    manager.Repaint();
  }

  CVViewerOverlay(this.tool){
    
  }

  @override
  Widget BuildContent(BuildContext ctx) {
    if(pic == null){
      WidgetsBinding.instance!.addPostFrameCallback(
        (timeStamp) {_UpdateSnapshot(); }
      );
    }
    return AnchoredPosition.fill(
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: _OnResize,
        child: SizeChangedLayoutNotifier(
          child: CustomPaint(
            key: cvKey,
            painter: CVPainter(this),
          ),
        ),
      )
    );
  }

  Size get cvSize{
    var sz = Size.zero;
    final keyContext = cvKey.currentContext;
    if (keyContext != null) {
      // widget is visible
      final box = keyContext.findRenderObject() as RenderBox;
      sz = box.size;
    }
    return sz;
  }

  void _UpdateSnapshot() {
    tool._RequestGenerateSnapshot(cvSize);
  }

  bool _OnResize(SizeChangedLayoutNotification e){
    _UpdateSnapshot();
    return true;
  }


  //late final _panGR = AnyPanGestureRecognizer()
  //  ..onUpdate = _OnPanUpdate
  //  ;

  late final _zoomGR = ScaleGestureRecognizer()
    
    ..onStart = _OnScaleStart
    ..onUpdate = _OnScaleUpdate
    ..onEnd = _OnScaleEnd
    ;

  _OnPanUpdate(DragUpdateDetails d){
    var delta = d.delta;
    var cvScale = tool.canvasParam.canvasScale;
    delta /= cvScale;
    tool.Translate(-delta);
  }

  Offset? prevFocal;
  double prevScale = 1.0;
  _OnScaleStart(ScaleStartDetails d){
    prevFocal = d.localFocalPoint;
    prevScale = 1.0;
  }

  _OnScaleUpdate(ScaleUpdateDetails d){
    var focal = d.localFocalPoint;
    var scale = d.scale;
    var scaleDelta = scale / prevScale;
    var focalDelta = focal - prevFocal!;

    _HandleScale(scaleDelta, focal, focalDelta);

    prevFocal = focal;
    prevScale = scale;
  }

  _OnScaleEnd(ScaleEndDetails d){
    prevFocal = null;
  }

  _HandleScale(double scale, Offset focal, Offset delta){
    //Calculate minimal acceptable scale factor
    var p = tool.canvasParam;
    //Current scale as power of 2
    double cpow2 = p.lod + CanvasParam.log2(p.canvasScale);

    //minimal lod
    double mlod = tool.minLod.toDouble();

    //minimal scale as power of 2
    var mspow2 = mlod - cpow2;

    //Make scale slightly larger than "accurate" value
    var minScale = pow(2, mspow2) + 1e-5;
    scale = max(minScale, scale);

    var size = cvSize;
    var centered = (focal - size.center(Offset.zero))/canvasScale;
    //When the viewport scales up, the center moves
    //closer to the focal point
    var scaled = centered / scale;
    var center_delta = centered - scaled;
    tool.canvasParam.Scale(scale);
    tool.Translate(center_delta - delta);
    tool.manager.popupManager.ShowQuickMessage(
      Text(
        "Canvas Scale : "
        "${tool.canvasParam.canvasScale.toStringAsFixed(2)}"
        " \u00D7 2^${tool.canvasParam.lod}"
      )
    );
  }

  @override AcceptPointerInput(PointerEvent p) {
    if(p is PointerDownEvent) return _AcceptTouch(p);
    return _AcceptMouse(p);    
  }

  bool _AcceptTouch(PointerDownEvent p){
    var canAccept = false;

    //if( _panGR.isPointerAllowed(p)){
    //  _panGR.addPointer(p);
    //  canAccept = true;
    //}

    if(_zoomGR.isPointerAllowed(p)){
      _zoomGR.addPointer(p);
      canAccept = true;
    }

    return canAccept;
  }

  //Handle scrollwheel
  bool _AcceptMouse(PointerEvent e){
    if(e is! PointerSignalEvent) return false;
    
    if(e is! PointerScrollEvent) return false;

    var scaleDelta = -e.scrollDelta.dy / 1000;
    //Mapping: x >= 0: x+1
    //         x <  0:1/(-x+1)
    var scale = scaleDelta >= 0? scaleDelta + 1
                               : 1/(1-scaleDelta);

    var scaleFocal = e.localPosition;
    _HandleScale(scale, scaleFocal, Offset.zero);
    return true;
  }



  @override Dispose(){
    //_panGR.dispose();
    _zoomGR.dispose();
  }
}

class _LayerThumbPainter extends CustomPainter{
  ui.Image? _img;

  _LayerThumbPainter(this._img);
  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    canvas.drawPaint(Paint()..color = Color.fromARGB(255, 255, 255, 255));

    if(_img!=null)
      canvas.drawImageRect(
        _img!, 
        Rect.fromLTWH(0, 0, _img!.width.toDouble(), _img!.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height),
        Paint()
      );
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => true;

}

class _LayerEntry extends StatefulWidget{

  final ui.CanvasLayerWrapper layer;
  final _LayerManagerWidgetState window;
  final Listenable? repaint;

  _LayerEntry(Key key, this.layer, this.window,
    [this.repaint]
  ):super(key: key);

  @override
  _LayerEntryState createState() => _LayerEntryState();
}

class _LayerEntryState extends State<_LayerEntry> {

  InfCanvasViewer get tool => widget.window.tool;
  bool get isActive=> 
    tool._activeLayerIdx == widget.layer.index;
  double get alpha => widget.layer.alpha;
  set alpha(double val){
    widget.layer.alpha = val.clamp(0, 1);
  }

  bool get canMerge => 
    widget.layer.index < tool.cvInstance.LayerCount() - 1;

  bool get canModify => widget.layer.isEnabled && widget.layer.isVisible;

  void MergeLayer(){
    assert(canMerge);
    widget.window.MergeLayer(widget.layer);
  }

  void DupLayer(){
    widget.window.DupLayer(widget.layer);
  }

  void RemoveLayer(){
    widget.window.RemoveLayer(widget.layer);
  }

 

  late final _menu = CustomMenuPage(
    name: 'Layer Menu',
    builder: (bctx, mctx){
      return SizedBox(
        width: 200,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.only(left:8.0, top:4, bottom:4, right:4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<BlendMode>(
                      value: widget.layer.blendMode,
                      isDense: true,
                      isExpanded: true,
                      onChanged: (BlendMode? newValue) {
                        if(newValue == widget.layer.blendMode) return;
                        setState(() {
                          
                          widget.layer.blendMode = newValue??BlendMode.srcOver;
                          tool.RecordCommand(
                            CanvasLayerParamChangeCommand(
                              widget.layer.index,
                              widget.layer.blendMode, 
                              alpha
                            )
                          );
                          mctx.Repaint();
                          _NotifyOverlayUpdate();
                        });
                      },
                      items: BlendMode.values.map((BlendMode classType) {
                        return DropdownMenuItem<BlendMode>(
                            value: classType,
                            child: Text(classType.toString().split('.').last,));
                      }).toList()
                  ),
                ),
              ),
            ),
            Row(
              children: [
                Text("Alpha"),
                Expanded(
                  child: ThinSlider(
                    value: alpha,
                    onChanged: (val){
                      alpha = val;
                      _NotifyOverlayUpdate();
                      mctx.Repaint();
                    },
                    onChangeEnd:(val){
                      tool.RecordCommand(
                        CanvasLayerParamChangeCommand(
                          widget.layer.index,
                          widget.layer.blendMode, 
                          alpha
                        )
                      );
                    }
                  ),
                ),
              ],
            ),
            Divider(),
            Center(
              child: Wrap(
                spacing: 4,
                runSpacing: 8,
                children: [
                  MenuActionButton(
                    icon: Icons.get_app,
                    label: "Merge",
                    onPressed: 
                      canModify&&canMerge?
                    (){
                      mctx.Close();
                      MergeLayer();
                    }:null
                  ),
                  MenuActionButton(
                      icon: Icons.copy,
                      label: "Duplicate",
                      onPressed: 
                        canModify?
                      (){
                        mctx.Close();
                        DupLayer();
                      }:null
                  ),

                ],
              ),
            ),
            Divider(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(primary: Colors.red),
              onPressed: ()async{
                await mctx.Close();
                RemoveLayer();

              }, child: Text("Remove")
            ),
          ],
        ),
      );
    }
  );

  @override
  Widget build(BuildContext context) {

    BoxDecoration border = BoxDecoration(
      borderRadius: BorderRadius.circular(3),
      border: Border.all(
        color: isActive?
          Theme.of(context).primaryColor:
          Theme.of(context).backgroundColor,
        width: 2,
      )
    );
    return MenuButton(
      _menu,
      (ctx, showFn) {
        return AspectRatio(
          aspectRatio: 1.0,
          child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Container(
                decoration: border,
                //color: (isActive?Theme.of(context).primaryColor.withOpacity(0.5):null),
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (isActive) {
                      showFn();
                    }
                    else {
                      tool._activeLayerIdx = widget.layer.index;
                      _NotifyParentUpdate();
                    }
                  },
                  child: ClipRect(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _LayerThumbPainter(
                              widget.layer.GetThumbnail()
                            ),
                          )
                        ),
                        Positioned(
                          top: 0, right: 0,
                          child: SizedTextButton(
                            width: 24,
                            height: 24,
                            child: Icon(
                              widget.layer.isEnabled ? Icons.lock_open : Icons
                                  .lock,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                widget.layer.isEnabled =
                                !widget.layer.isEnabled;
                              });
                            }
                          ),
                        ),
                        Positioned(
                          bottom: 0, right: 0,
                          child: SizedTextButton(
                            width: 24,
                            height: 24,
                            child: Icon(
                              widget.layer.isVisible ? Icons.visibility : Icons
                                  .visibility_off_outlined,
                              size: 18,
                            ),
                            onPressed: () {
                              setState(() {
                                widget.layer.isVisible =
                                !widget.layer.isVisible;
                                _NotifyOverlayUpdate();
                              });
                            }
                          ),
                        ),
                        
                      ],

                    ),
                  ),
                ),
              ),
            ),
        );
      }
    );
  }

  void _NotifyOverlayUpdate(){
    tool.NotifyOverlayUpdate();
  }

  void _NotifyParentUpdate(){
    widget.window.setState(() {
      
    });
  }

  void _RepaintCallback(){
    setState(() {
      
    });
  }

  @override void initState() {
    super.initState();
    widget.repaint?.addListener(_RepaintCallback);
  }
  @override void didUpdateWidget(oldWidget){
    super.didUpdateWidget(oldWidget);
    if(widget.repaint != oldWidget.repaint){
      oldWidget.repaint?.removeListener(_RepaintCallback);
      widget.repaint?.addListener(_RepaintCallback);
    }
    if(widget.layer != oldWidget.layer){
      oldWidget.layer.Dispose();
    }
  }
  @override void dispose() {
    super.dispose();
    widget.layer.Dispose();
    widget.repaint?.removeListener(_RepaintCallback);
  }

}

class _BGColorIndicator extends CustomPainter{
  final InfCanvasViewer tool;

  _BGColorIndicator(this.tool):super(repaint: tool._bgColorCtrl.colorNotifier);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    var shaderProg = ChessboardShaderProg;
    var paintShd = ui.PaintShader(shaderProg).MakeShaderInstance();
    canvas.drawPaint(Paint()..shader = paintShd);

    if(tool.showBgColor){
      var color = tool.bgColor;
      canvas.drawColor(color, BlendMode.srcOver);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BackgroundColorSelector extends StatefulWidget {
  final InfCanvasViewer tool;

  const _BackgroundColorSelector(this.tool);

  @override createState() => _BackgroundColorSelectorState();
}

class _BackgroundColorSelectorState extends State<_BackgroundColorSelector> {

  late final _menu = CustomMenuPage(
    name: "BackgroundColor",
    builder: (bctx, mctx){
      return SizedBox(
        width: 180,
        child: ColorPickerWidget(ctrl: widget.tool._bgColorCtrl)
      );
    }
  );

  @override
  Widget build(BuildContext context) {
    return MenuButton(
      _menu,
      (bctx,showFn){
        return GestureDetector(
          onTap: (){
            widget.tool._bgColorCtrl.NotifyColorUsed();
            showFn();
          },
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _BGColorIndicator(widget.tool),
                )
              ),
              Positioned(
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: Colors.white70.withOpacity(0.8),
                        spreadRadius:0,
                        blurRadius: 10
                      )
                    ]
                  ),
                  child: SizedTextButton(
                    width: 24,
                    height: 24,
                    child: Icon(
                      widget.tool.showBgColor ? Icons.visibility : Icons
                          .visibility_off_outlined,
                      size: 18,
                    ),
                    onPressed: () {
                      setState(() {
                        widget.tool.showBgColor =
                        !widget.tool.showBgColor;
                      });
                    }                  
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}

class LayerManagerWidget extends StatefulWidget {

  final InfCanvasViewer tool;

  const LayerManagerWidget({Key? key,required this.tool}) : super(key: key);

  @override
  _LayerManagerWidgetState createState() => _LayerManagerWidgetState();
}

class _LayerManagerWidgetState extends State<LayerManagerWidget> {

  InfCanvasViewer get tool => widget.tool;

  void MergeLayer(ui.CanvasLayerWrapper layer){
    tool.cvInstance.MergeDownPaintLayer(layer.index);
    widget.tool.RecordCommand(
      CanvasLayerMergeCommand(layer.index)
    );
    tool.NotifyOverlayUpdate();
    setState((){});
  }

  void DupLayer(ui.CanvasLayerWrapper layer){
    tool.cvInstance.DuplicatePaintLayer(layer.index);
    widget.tool.RecordCommand(
      CanvasLayerDupCommand(layer.index)
    );
    tool.NotifyOverlayUpdate();
    setState((){});
  }

  void RemoveLayer(ui.CanvasLayerWrapper layer){
    if(widget.tool._activeLayerIdx == layer.index){
      widget.tool._activeLayerIdx = -1;
    }
    widget.tool.RecordCommand(
      CanvasLayerRemoveCommand(layer.index)
    );
    layer.Remove();
    tool.NotifyOverlayUpdate();
    //_NotifyParentUpdate();
    setState((){});
  }

  @override
  Widget build(BuildContext context) {
    var layers = widget.tool.cvInstance.layers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: 100,
            maxHeight: 400,
          ),
          child: Scrollbar(
            child: SizedBox(
              width: 100,
              child: ReorderableColumn(
                onReorder: (oldIndex, newIndex) {
                  if(oldIndex == newIndex) return;

                  //if(newIndex > oldIndex){
                  //  newIndex -= 1;
                  //}
                  widget.tool.cvInstance.GetLayer(oldIndex).MoveTo(newIndex);
                  if(widget.tool._activeLayerIdx == oldIndex){
                    widget.tool._activeLayerIdx = newIndex;
                  }
                  widget.tool.RecordCommand(CanvasLayerMoveCommand(oldIndex, newIndex));
                  tool.NotifyOverlayUpdate();
                  setState((){});
                },
                children: <Widget>[
                  for(var l in layers)
                    _LayerEntry(
                      Key("_layerman_entry_#${l.index}"),l,this,
                      tool._thumbUpdateNotifier
                    ),
                ]
              ),
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(4.0),
          child: Container(
            height: 30,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              border: Border.all(
                color: Theme.of(context).backgroundColor,
                width: 2,
              )
            ),
            child: 
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: _BackgroundColorSelector(widget.tool)
            ),
          ),
        ),


        TextButton(onPressed: (){
          widget.tool.cvInstance.CreatePaintLayer();
          widget.tool.RecordCommand(CanvasLayerAddCommand());
          setState((){});
        }, child: Icon(Icons.add))
      ],
    );
  }
}


class LayerManagerWindow extends ToolWindow{
  final InfCanvasViewer tool;

  LayerManagerWindow(this.tool){
  }

  @override BuildContent(BuildContext context){
    var layers = tool.cvInstance.layers;
    return SizedBox(
      width: 100,
      child:CreateDefaultLayout(
        LayerManagerWidget(tool:tool),
        title: "Layers",
      ),
    );
  }

  @override OnRemove(){
    tool._lmAction.isActivated = false;
    return super.OnRemove();
  }

  _NotifyUpdate(){
    if(isInstalled)
      manager.Repaint();
  }
}


class CanvasParam{
  ui.HierarchicalPoint offset = ui.HierarchicalPoint(0, 0);
  Size size = Size.zero;
  int lod = 0;
  ///Canvas scale between 2 lods.
  ///Since lod is power of 2, canvas scale
  ///naturally lies between 1.0 to 2.0
  double _canvasScale = 1.0;

  CanvasParam Clone(){
    return CanvasParam()..offset = offset.Clone()
                        ..size = Size.copy(size)
                        ..lod = lod
                        .._canvasScale = _canvasScale
    ;
  }

  double get canvasScale => _canvasScale;
  set canvasScale(double val){
    _canvasScale = val.clamp(1.0, 2.0);
  }

  ///Actual visual scale = (2^lod)*canvasScale
  double get scale => pow(2, lod)*_canvasScale;
  set scale(double val){
    var power = log2(val);
    lod =  power.floor();
    var cvScale_power = power - lod;
    _canvasScale = pow(2, cvScale_power) as double;
  }


  static double log2(double x){
    return log(x)/log(2);
  }

  void Drop(){
    lod++;
    offset.Drop();
  }

  void Lift(){
    lod--;
    offset.Lift();
  }

  void Scale(double val){
    var total = _canvasScale * val;
    if(total >= 1 && total <= 2){
      _canvasScale = total; return;
    }
    var power = log2(total);
    var delta_lod =  power.floor();
    var cvScale_power = power - delta_lod;
    _canvasScale = pow(2, cvScale_power) as double;
    lod += delta_lod;

    bool feq(double a, double b){
      return  (a - b).abs() < 2;
    }

    while(delta_lod != 0){
      var old = offset.Clone();
      if(delta_lod > 0){
        //TODO:offset glitches out sometimes
        old.Drop();
        old.Lift();
        assert(
          feq(old.indexX,offset.indexX)&&
          feq(old.indexY,offset.indexY)&&
          feq(old.offsetX,offset.offsetX)&&
          feq(old.offsetY,offset.offsetY)
        );
        offset.Drop();

        delta_lod--;
      }else{
        old.Lift();
        old.Drop();
        assert(
          feq(old.indexX,offset.indexX)&&
          feq(old.indexY,offset.indexY)&&
          feq(old.offsetX,offset.offsetX)&&
          feq(old.offsetY,offset.offsetY)
        );

        offset.Lift();
        delta_lod++;
        
      }
    }
  }

  bool operator==(dynamic other){
    if(runtimeType != other.runtimeType) return false;
    if(hashCode != other.hashCode) return false;
    return offset == other.offset
        && size == other.size
        && lod == other.lod
        ;
  }

  int get hashCode{
    return offset.hashCode << 30
         ^ size.hashCode << 10
         ^ lod;
  }
}

class InfCanvasViewer extends CanvasTool{
  @override get displayName => "CanvasViewer";

  AppModel? _model;

  Widget _BuildZoomPage(BuildContext bctx,MenuContext mctx){
    return SizedBox(
      width: 200,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 30,
            child: Row(children: [
              SizedBox(width:50, child: Text("Zoom", textAlign:TextAlign.center,)),
              Expanded(
                child: ThinSlider(
                  value: canvasParam.canvasScale,
                  min: 1.0,
                  max:2.0,
                  onChanged: (value){
                    canvasParam.canvasScale = value;
                    NotifyOverlayUpdate();
                    mctx.Repaint();
                  },
                ),
              )
            ],),
          ),
          SizedBox(
            height: 30,
            child: Row(children: [
              SizedBox(width:50, child: Text("LOD ", textAlign: TextAlign.center,)),
              TextButton(
                child: Icon(Icons.remove),
                onPressed: (){
                  if(lod <= minLod) return;
                  canvasParam.Lift();
                  NotifyOverlayUpdate(); 
                  mctx.Repaint();
                },
              ),
              Expanded(
                child: Text(lod.toString(),textAlign:  TextAlign.center,)
              ),
              TextButton(
                child: Icon(Icons.add),
                onPressed: (){
                  canvasParam.Drop();
                  NotifyOverlayUpdate();
                  mctx.Repaint();
                },
              ),
            ],),
          ),
          ElevatedButton(onPressed: (){
            canvasParam = CanvasParam();
            NotifyOverlayUpdate(); mctx.Repaint();
          }, child: Text("Reset Viewport")),
        ],
      ),
    );
  }

  @override OnInit(mgr, ctx)async{
    mgr.overlayManager.RegisterOverlayEntry(_overlay, 0);
    _lmAction = mgr.menuBarManager.RegisterAction(
      MenuPath(name:"Layers"), _ShowLMWindow
    );
    
    mgr.menuBarManager.RegisterPage(
      MenuPath().Next("Zoom", Icons.zoom_in), _BuildZoomPage
    );

    mgr.RegisterReplayBeginListener(() { 
      cvInstance.Clear();
    });

    mgr.RegisterReplayFinishListener(() {
      while(minLod > lod){
        _canvasParam.Drop();
      }
      if(_activeLayerIdx >= cvInstance.LayerCount()){
        _activeLayerIdx = -1;
      }
      NotifyOverlayUpdate();
    });

    _model = Provider.of<AppModel>(ctx, listen: false);
    try{
      RestoreState();
    }catch(e){
      debugPrint("CanvasTool restore state failed: $e");
    }
    _layerMgrWnd.addListener(() {_saveTaskGuard.Schedule();});

  }

  late final _bgColorCtrl = ColorPickerController()
    ..color = Color.fromARGB(255, 255, 255, 255);
  bool _showBgColor = false;
  bool get showBgColor => _showBgColor;
  set showBgColor(bool val){
    if(val == _showBgColor) return;
    _showBgColor = val;
    _bgColorCtrl.colorNotifier.notifyListeners();
  }

  Color get bgColor => _bgColorCtrl.color;
  set bgColor(Color val){
    if(val == bgColor) return;
    _bgColorCtrl.color = val;
  }

  late final _overlay = CVViewerOverlay(this);
  late final MenuAction _lmAction;
  late final _layerMgrWnd = LayerManagerWindow(this);

  late final _saveTaskGuard = DelayedTaskGuard(
    (_)=>SaveState(), Duration(seconds: 3)
  );

  void SaveState(){
    _model?.SaveModel("tool_canvasviewer",{
      "window":SaveToolWindowLayout(_layerMgrWnd),
    });
  }

  void RestoreState(){
    Map<String, dynamic> data = _model!.ReadModel("tool_canvasviewer");
    Map<String, dynamic>? wndlayout = ReadMapSafe(data,"window");
    RestoreToolWindowLayout(wndlayout, _layerMgrWnd, _ShowLMWindow);
  }

  _ShowLMWindow(){
    _lmAction.isActivated = true;
    manager.windowManager.ShowWindow(_layerMgrWnd);
  }

  _OnLMWindowClose(){
    _lmAction.isActivated = true;
  }

  ui.CanvasInstance _cvInstance = ui.CanvasInstance();
  int get minLod{return 1 - _cvInstance.height;}

  ui.CanvasInstance get cvInstance => _cvInstance;
  set cvInstance(ui.CanvasInstance val){
    var old = _cvInstance;
    _cvInstance = val;
    if(old != val){
      NotifyOverlayUpdate();
    }
  }

  int _activeLayerIdx = -1;

  int get activeLayerIdx => _activeLayerIdx;
  bool get isActiveLayerDrawable{
    if(_activeLayerIdx < 0 || _activeLayerIdx >= cvInstance.LayerCount())
      return false;
    var layer = cvInstance.GetLayer(_activeLayerIdx);
    return (layer.isEnabled && layer.isVisible);
  }

  //ui.CanvasLayerWrapper? _activeLayer;
  //ui.CanvasLayerWrapper? get activePaintLayer => _activeLayer;
  //set activePaintLayer(ui.CanvasLayerWrapper? val){
  //  _activeLayer = val;
  //}

  //Draw point
  FutureOr<void> DrawOnActiveLayer(
    ui.HierarchicalPoint lt,
    int lod,
    ui.BrushRenderPipeline stroke,
    [Matrix4? transform]
  ){
    if(_activeLayerIdx < 0
      ||_activeLayerIdx >= cvInstance.LayerCount()) return null;
    var layer = cvInstance.GetLayer(_activeLayerIdx);
    var tm = (transform??Matrix4.identity()).storage;
    return layer.DrawRect(lt, lod, stroke, tm).then(
      (_){
        NotifyOverlayUpdate();
      }
    );
  }

  CanvasParam _canvasParam = CanvasParam();

  CanvasParam get canvasParam => _canvasParam;
  set canvasParam(CanvasParam val){
    var old = canvasParam;
    _canvasParam = val;
    if(old!= val){
      NotifyOverlayUpdate();
    }
  }

  void Translate(Offset delta){
    offset.Translate(delta);
    NotifyOverlayUpdate();
  }

  ui.HierarchicalPoint get offset => _canvasParam.offset;
  set offset(ui.HierarchicalPoint val){
    var old = offset;
    _canvasParam.offset = val;
    if(old!= val){
      NotifyOverlayUpdate();
    }
  }

  int get lod => _canvasParam.lod;
  set lod(int val){
    var newLod = max(val, minLod);
    var old = lod;
    _canvasParam.lod = newLod;
    if(old!= newLod){
      NotifyOverlayUpdate();
    }
  }

  void NotifyOverlayUpdate(){
    /**Update procedure:
     * 1.(Tool)    Send update notification to overlay
     * 2.(Overlay) Acquire viewport size
     * 3.(Overlay) Request snapshot from tool with size
     * 4.(Tool)    Generate shapshot and send to overlay
     * 5.(Overlay) Draw snapshot image
     */
    _overlay._UpdateSnapshot();
  }

  ///Repaint both viewport and layer manager
  //void NotifyCVUpdate(){
  //  NotifyOverlayUpdate();
  //  //manager.Repaint();
  //}
  final _thumbUpdateNotifier = ChangeNotifier();
  late final _snapshotTaskRunner = SequentialTaskGuard<ui.Picture>(
    (req)async{
      //Gather info
      CanvasParam p = req.last;
      var w = p.size.width.ceil();
      var h = p.size.height.ceil();
      var delta = Offset(p.offset.offsetX, p.offset.offsetY);
      var scale = p.canvasScale;
      var lod = p.lod;
      if(lod < minLod){
        scale = 1.0;
        lod = minLod;
      }
      //Generate snapshot
      var img = await _cvInstance.GenSnapshot(
          p.offset, lod, w, h);
      _overlay._DrawSnapshot(img, delta, scale);
      //_layerMgrWnd._NotifyUpdate();
      _thumbUpdateNotifier.notifyListeners();
      return img;
    },
    "CanvasSnapshotTask"
  );

  _RequestGenerateSnapshot(Size size){
    if(size.isEmpty) return;
    var w = -size.width / 2;
    var h = -size.height / 2;
    _snapshotTaskRunner.RunNowOrSchedule(
      canvasParam.Clone()
        ..size = size
        ..offset = offset.Translated(Offset(w,h))
    );
  }

  @override Dispose(){
    _saveTaskGuard.FinishImmediately();
    _layerMgrWnd.dispose();
    _overlay.Dispose();
  }

  void RecordCommand(CanvasViewerCommand command){
    command.tool = this;
    command.activeLayer = _activeLayerIdx;
    manager.RecordCommand(command);
  }
}
