

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
  final cvKey = GlobalKey(debugLabel:"CanvasPainter");

  ui.Image? img;
  Offset off = Offset.zero;

  void _DrawSnapshot(ui.Image img, Offset off){
    this.img = img; this.off = off;
    manager.Repaint();
  }

  BrushInputOverlay(this.tool);

  @override
  Widget BuildContent(BuildContext ctx) {
    if(img == null){
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
              painter: CVPainter(img,off),
            ),
          ),
        )
    );
  }

  @override AcceptPointerInput(p){
    return tool.AcceptPointer(p);
  }

  void _UpdateSnapshot() {
    double w = 0, h = 0;
    final keyContext = cvKey.currentContext;
    if (keyContext != null) {
      // widget is visible
      final box = keyContext.findRenderObject() as RenderBox;
      w = box.size.width;
      h = box.size.height;
    }
    tool._RequestGenerateSnapshot(Size(w, h));
  }

  bool _OnResize(SizeChangedLayoutNotification e){
    _UpdateSnapshot();
    return true;
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
  final BrushTool tool;

  _LayerEntry(Key key, this.layer, this.tool):super(key: key);

  @override
  _LayerEntryState createState() => _LayerEntryState();
}

class _LayerEntryState extends State<_LayerEntry> {

  BrushTool get tool => widget.tool;
  bool get isActive=> widget.layer == tool.activePaintLayer;
  double alpha = 0.5;

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
                      Positioned.fill(
                          child: CustomPaint(painter: _LayerThumbPainter(),)
                      )
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
    state?.setState(() {});
  }

  void _NotifyOverlayUpdate(){
    tool.NotifyOverlayUpdate();
  }
}

class LayerManagerWidget extends StatefulWidget {

  final BrushTool tool;

  const LayerManagerWidget({Key? key,required this.tool}) : super(key: key);

  @override
  _LayerManagerWidgetState createState() => _LayerManagerWidgetState();
}

class _LayerManagerWidgetState extends State<LayerManagerWidget> {

  BrushTool get tool => widget.tool;

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


class BrushManagerWindow extends ToolWindow{
  final BrushTool tool;

  BrushManagerWindow(this.tool){
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
    return super.OnRemove();
  }
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

  @override OnInit(mgr){
    mgr.overlayManager.RegisterOverlayEntry(_overlay, 1);
    mgr.menuBarManager.RegisterAction(
        MenuPath(name:"Brush"), () {
        ActivateTool();
      }
    );
  }

  InfCanvasViewer get cvTool => manager.FindTool<InfCanvasViewer>()!;
  ColorPicker get colorTool => manager.FindTool<ColorPicker>()!;

  bool isActive = false;
  void ActivateTool(){
    manager.overlayManager.RegisterOverlayEntry(_overlay, 1);
    manager.sideBarManager.ShowSideBar(_sidebar);
    isActive = true;
  }

  void DeactivateTool(){
    isActive = false;
  }

  late final _overlay = BrushInputOverlay(this);
  late final _sidebar = BrushSideBar(this);

  ui.BrushInstance _brush = ui.BrushInstance();

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


  CanvasParam get canvasParam => cvTool.canvasParam;


  late final _brushGR = PanGestureRecognizer()
    ..onUpdate = _OnPanUpdate
  ;

  _OnPanUpdate(DragUpdateDetails d){
    var delta = d.delta;
    Translate(-delta);
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

