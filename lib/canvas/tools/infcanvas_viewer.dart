import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'package:infcanvas/canvas/canvas_tool.dart';
import 'package:infcanvas/utilities/async/task_guards.dart';
import 'package:infcanvas/utilities/storage/app_model.dart';
import 'package:infcanvas/widgets/functional/anchor_stack.dart';
import 'package:infcanvas/widgets/functional/any_drag.dart';
import 'package:infcanvas/widgets/functional/floating.dart';
import 'package:infcanvas/widgets/functional/tool_view.dart';
import 'package:infcanvas/widgets/visual/sliders.dart';
import 'package:provider/provider.dart';
import 'package:reorderables/reorderables.dart';

class CVPainter extends CustomPainter{
  final Offset origin;
  final ui.Picture? img;
  final double canvasScale;
  CVPainter(this.img, this.origin, this.canvasScale);
  @override
  void paint(Canvas canvas, Size size) {
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
      for(var y = yStart; y <= size.width; y+=step){

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

    //print("Cursor pos: ${touchPoint}");
    Paint paint = Paint();
    paint.filterQuality = FilterQuality.high;

    //cp.tree.DrawTreeToCanvas(canvas, size, cp.offset,cp.height);
    if(img != null){
      canvas.drawPicture(img!);//(img!, Offset.zero, paint);
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
            painter: CVPainter(pic,off, canvasScale),
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


  late final _panGR = AnyPanGestureRecognizer()
    ..onUpdate = _OnPanUpdate
    ;
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
    tool.Translate(center_delta + delta);
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

    if( _panGR.isPointerAllowed(p)){
      _panGR.addPointer(p);
      canAccept = true;
    }

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
    _panGR.dispose();
    _zoomGR.dispose();
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

class _LayerEntry extends StatefulWidget{

  final ui.PaintLayer layer;
  final InfCanvasViewer tool;

  _LayerEntry(Key key, this.layer, this.tool):super(key: key);

  @override
  _LayerEntryState createState() => _LayerEntryState();
}

class _LayerEntryState extends State<_LayerEntry> {

  InfCanvasViewer get tool => widget.tool;
  bool get isActive=> widget.layer == tool.activePaintLayer;
  double get alpha => widget.layer.alpha;
  set alpha(double val){
    widget.layer.alpha = val.clamp(0, 1);
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
                        setState(() {
                          widget.layer.blendMode = newValue??BlendMode.srcOver;
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
                  child: Slider(
                    label: "Alpha",
                    value: alpha,
                    onChanged: (val){
                      alpha = val;
                      _NotifyOverlayUpdate();
                      mctx.Repaint();
                    },
                  ),
                ),
                Text(alpha.toStringAsFixed(2))
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
                    onPressed: (){mctx.Close();}
                  ),
                  MenuActionButton(
                      icon: Icons.copy,
                      label: "Duplicate",
                      onPressed: (){mctx.Close();}
                  ),

                ],
              ),
            ),
            Divider(),
            ElevatedButton(
              style: ElevatedButton.styleFrom(primary: Colors.red),
              onPressed: ()async{
                await mctx.Close();
                widget.layer.Remove();
                _NotifyOverlayUpdate();
                _NotifyParentUpdate();

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
          Theme.of(context).highlightColor,
        width: 2,
      )
    );
    return MenuButton(
      _menu,
      (ctx, showFn) {
        return Padding(
            padding: const EdgeInsets.all(4.0),
            child: Container(
              width: 100,
              height: 100,
              decoration: border,
              //color: (isActive?Theme.of(context).primaryColor.withOpacity(0.5):null),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: () {
                  if (isActive) {
                    showFn();
                  }
                  else {
                    tool.activePaintLayer = widget.layer;
                    _NotifyParentUpdate();
                  }
                },
                child: ClipRect(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(painter: _LayerThumbPainter(),)
                      ),
                      Positioned(
                        top: 0, right: 0,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: TextButton(
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
                      ),
                      Positioned(
                        bottom: 0, right: 0,
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: TextButton(
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
                      ),
                      
                    ],

                  ),
                ),
              ),
            ),
          );
      }
    );
  }

  void _NotifyParentUpdate(){
    var state = context.findAncestorStateOfType<_LayerManagerWidgetState>();
    if(state != null && state.mounted)
      state.setState(() {});
  }

  void _NotifyOverlayUpdate(){
    tool.NotifyOverlayUpdate();
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

  @override
  Widget build(BuildContext context) {
    var layers = widget.tool.cvInstance.layers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.max,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: 100,
            maxWidth: 100,
            minHeight: 100,
            maxHeight: 400,
          ),
          child: Scrollbar(
            child: ReorderableColumn(
              onReorder: (oldIndex, newIndex) {
                if(oldIndex == newIndex) return;

                //if(newIndex > oldIndex){
                //  newIndex -= 1;
                //}
                widget.tool.cvInstance.layers[oldIndex].MoveTo(newIndex);
                tool.NotifyOverlayUpdate();
                setState((){});
              },
              children: <Widget>[
                for(int i = 0; i < layers.length; i++)
                  _LayerEntry(Key("_layerman_entry_#${i}"),layers[i],tool),

              ]
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Expanded(
              child: TextButton(onPressed: (){
                widget.tool.cvInstance.CreateNewPaintLayer();
                setState((){});
              }, child: Icon(Icons.add)),
            )
          ],
        )
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
    return IntrinsicWidth(
      child:CreateDefaultLayout(
        LayerManagerWidget(tool:tool),
        title: "Layers",
      ),
    );
  }

  @override OnRemove(){
    tool._lmAction.isEnabled = false;
    return super.OnRemove();
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
    _model = Provider.of<AppModel>(ctx, listen: false);
    try{
      RestoreState();
    }catch(e){
      debugPrint("CanvasTool restore state failed: $e");
    }
    _layerMgrWnd.addListener(() {_saveTaskGuard.Schedule();});

    var blackhole = await rootBundle.load("assets/images/blackhole.jpg");
    var codec = await ui.instantiateImageCodec(blackhole.buffer.asUint8List());
    var frame = await codec.getNextFrame();
    blackholeImg = frame.image;
  }
  ui.Image? blackholeImg;

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
    _lmAction.isEnabled = true;
    manager.windowManager.ShowWindow(_layerMgrWnd);
  }

  _OnLMWindowClose(){
    _lmAction.isEnabled = true;
  }

  ui.InfCanvasInstance _cvInstance = ui.InfCanvasInstance();
  int get minLod{return 1 - _cvInstance.height;}

  ui.InfCanvasInstance get cvInstance => _cvInstance;
  set cvInstance(ui.InfCanvasInstance val){
    var old = _cvInstance;
    _cvInstance = val;
    if(old != val){
      NotifyOverlayUpdate();
    }
  }

  ui.PaintLayer? _activeLayer;
  ui.PaintLayer? get activePaintLayer => _activeLayer;
  set activePaintLayer(ui.PaintLayer? val){
    _activeLayer = val;
  }

  //Draw point
  FutureOr<void> DrawOnActiveLayer(
    ui.HierarchicalPoint lt,
    int lod,
    ui.BrushRenderPipeline stroke,
    [Matrix4? transform]
  ){
    if(activePaintLayer == null) return null;
    var layer = activePaintLayer!;
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
      return img;
    }
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
}
