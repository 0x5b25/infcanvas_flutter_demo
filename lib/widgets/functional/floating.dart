import 'dart:core';
import 'dart:async';
import 'dart:ui';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:infcanvas/util.dart';

import 'anchor_stack.dart';

//typedef Offset CustomPosFn(Rect geo, Rect old, Size size);


class PositioningBehavior{

  final PositioningFn? onPositioning;
  final SizingFn? onSizing;

  const PositioningBehavior(this.onPositioning, this.onSizing);

  /// Positioning function to stop at edge.
  static Offset SAE_Ps(LayoutParams lps, Offset pos){
    var cw = lps.widgetSize.width;
    var ch = lps.widgetSize.height;

    var cl = pos.dx;
    var ct = pos.dy;
    var cr = cl + cw;
    var cb = ct + ch;

    var space_l = cl;
    var space_t = ct;
    var space_r = lps.stackSize.width - cr;
    var space_b = lps.stackSize.height - cb;

    if(space_l < 0){space_r += space_l; space_l = 0; if(space_r < 0) space_r = 0;}
    if(space_t < 0){space_b += space_t; space_t = 0; if(space_b < 0) space_b = 0;}
    if(space_r < 0){space_l += space_r; space_r = 0; if(space_l < 0) space_l = 0;}
    if(space_b < 0){space_t += space_b; space_b = 0; if(space_t < 0) space_t = 0;}

    return Offset(
      space_l,
      space_t,);
  }

  ///Sizing function to constraint max size to panel size.
  static BoxConstraints Loose_Sz(LayoutParams lps){
    var childConstraints = BoxConstraints(
        maxWidth: lps.widgetSize.width.isFinite? lps.widgetSize.width:lps.stackSize.width,
        maxHeight: lps.widgetSize.height.isFinite?lps.widgetSize.height:lps.stackSize.height
    );
    return childConstraints;
  }

  ///Sizing function to constraint max size to panel size, and .
  static BoxConstraints Stretch_Sz(LayoutParams lps){
    var childConstraints = BoxConstraints(
        maxWidth: lps.stackSize.width,
        maxHeight:lps.stackSize.height
    );

    if(lps.widgetSize.width.isFinite)
      childConstraints = childConstraints.tighten(width:lps.widgetSize.width);
    if(lps.widgetSize.height.isFinite)
      childConstraints = childConstraints.tighten(height:lps.widgetSize.height);
    return childConstraints;

  }

  static const PositioningBehavior StopAtEdge = const PositioningBehavior(
      SAE_Ps,
      Loose_Sz
  );

}

class FloatingWindowPanel extends StatefulWidget{

  final List<Widget> children;
  final PaintFn? bgPainter, fgPainter;


  FloatingWindowPanel({Key? key, this.bgPainter, this.fgPainter, this.children = const[]}):super(key: key);


  @override
  FloatingWindowPanelState createState() => FloatingWindowPanelState();
}

class FloatingWindowPanelState extends State<FloatingWindowPanel> {

  //Window registry for adding/removing window dynamically
  LinkedList<Widget> _wndOpened = LinkedList();
  Map<Widget, LinkedListNode<Widget>> _wndEntry = Map();
  final GeometryTrackHandle geomHandle = GeometryTrackHandle();

  ///Show window or bring already opened window to front
  void ShowWindow(Widget wnd){
    //Search for entry
    var entry = _wndEntry[wnd];
    if(entry == null){
      //Add the window
      entry = _wndOpened.Add(wnd);
      _wndEntry[wnd] = entry;
    }else{
      _wndOpened.Remove(entry);
      _wndOpened.InsertBack(entry);
    }
    setState(() {

    });
  }

  void CloseWindow(Widget wnd){
    //Search for entry
    var entry = _wndEntry[wnd];
    if(entry == null) return;

    _wndOpened.Remove(entry);
    _wndEntry.remove(wnd);
    setState(() {

    });
  }

  Widget build(BuildContext ctx){
    List<Widget> popupList = [];
    if(hasPopup){

      if(tapDismiss){
        popupList.add(AnchoredPosition.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              RemovePopup(popup: popupWindow);
            },
          ),
        ));
      }

      popupList.add(popupWindow!);
    }

    return GeometryTracker(
      handle: geomHandle,
      child: AnchorStack(
        bgPainter: widget.bgPainter,
        fgPainter: widget.fgPainter,
        children: widget.children + _wndOpened.toList() + popupList,
      ),
    );
  }

  @override
  void initState(){
    super.initState();
  }

  @override
  void didUpdateWidget(FloatingWindowPanel old){
    super.didUpdateWidget(old);
    //popupWindow = null;
  }

  @override
  void dispose(){
    super.dispose();
  }

  Widget? popupWindow;
  bool tapDismiss = true;

  bool get hasPopup => popupWindow != null;

  void ShowPopup(Widget popup, {bool tapOutsideToDismiss = true}){
    popupWindow = popup;
    tapDismiss = tapOutsideToDismiss;
    setState(() {});
  }

  void RemovePopup({Widget? popup}){
    if (!hasPopup) return;

    bool match =
    (popup == null)? true : (popup == popupWindow);

    if(match){
      popupWindow = null;
      setState(() {});
    }
  }

  static FloatingWindowPanelState? of(BuildContext ctx){
    return ctx.findAncestorStateOfType<FloatingWindowPanelState>();
  }

  GeometryTrackHandle get geometryHandle => geomHandle;

}



Widget BuildDefaultWindowContent(
  Widget? child,
  {
    double borderRadius = 4,
    Color background = Colors.white,
    double backgroundOpacity = 0.6,
    double backgroundBlur = 50,
  }
){
  return Container(
    decoration: BoxDecoration(
        boxShadow: <BoxShadow>[
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 15.0,
              offset: Offset(0.0, 0.75)
          )
        ]
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: backgroundBlur,
          sigmaY: backgroundBlur,
          tileMode: TileMode.repeated,
        ),
        child: Container(
            color: background.withOpacity(backgroundOpacity),

            child: child
        ),
      ),
    ),
  );
}


class FloatingWindow extends StatelessWidget{
  double? left, top, right, bottom;
  Rect anchor;
  Offset align;
  double? width, height;
  PositioningBehavior? layoutBehavior;
  GeometryTrackHandle? tracking;
  bool forceUpdate;

  Widget child;

  FloatingWindow({Key? key,required this.child,
    this.left, this.top,this.right, this.bottom, this.width,this.height,
    this.anchor = const Rect.fromLTRB(0, 0, 0, 0),
    this.align = Offset.zero,
    this.tracking,
    this.forceUpdate = false,
    this.layoutBehavior = PositioningBehavior.StopAtEdge,
  }) : super(key: key);

  @override
  Widget build(BuildContext ctx){
    return AnchoredPosition(
      tracking: tracking,
      onPositioning: layoutBehavior?.onPositioning,
      onSizing: layoutBehavior?.onSizing,
      anchor: anchor,
      alignX: align.dx,
      alignY: align.dy,
      left:left,
      top:top,
      right: right,
      bottom: bottom,
      width: width,
      height: height,
      forceUpdate: forceUpdate,
      child: BuildDefaultWindowContent(child),

    );
  }
}

class AnimatedCloseNotifier{
  dynamic _state;
  bool get isInstalled => _state!=null;

  Future<void> NotifyClose(){
    var c = Completer();
    if(!isInstalled){
      c.complete();
    }else{
      TickerFuture f = _state._NotifyClose();
      f.whenCompleteOrCancel(() {c.complete();});
    }
    return c.future;
  }

  Future<void> NotifyOpen(){
    var c = Completer();
    if(!isInstalled){
      c.complete();
    }else{
      TickerFuture f = _state._NotifyOpen();
      f.whenCompleteOrCancel(() {c.complete();});
    }
    return c.future;
  }
}

abstract class AnimatedClosableWidget extends StatefulWidget{
  final AnimatedCloseNotifier? closeNotifier;
  final Duration duration;
  final Curve curve;
  AnimatedClosableWidget(
      {
        Key? key,
        required this.closeNotifier,
        this.duration = const Duration(milliseconds: 100),
        this.curve = Curves.ease,
      }
      ):super(key: key);
}


abstract class AnimatedClosableWidgetState<T extends AnimatedClosableWidget>
    extends State<T>
    with SingleTickerProviderStateMixin
{
  late Animation<double> animation;
  late AnimationController controller;

  Duration get duration => controller.duration!;
  set duration(Duration val){
    if(val != duration){
      controller.duration = val;
    }
  }

  TickerFuture _NotifyClose(){
    return controller.animateBack(0.0);
  }

  TickerFuture _NotifyOpen(){
    return controller.animateTo(1.0);
  }

  _RegCtrl(AnimatedCloseNotifier? closeNotifier){
    if(closeNotifier!=null){
      closeNotifier._state = this;
    }
  }

  _UnregCtrl(AnimatedCloseNotifier? closeNotifier){
    if(closeNotifier!=null){
      closeNotifier._state = null;
    }
  }


  void OnFullyOpened(){
    setState(() {
      
    });
  }

  
  void OnFullyClosed(){
    setState(() {
      
    });
  }

  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(duration: widget.duration, vsync: this);
    animation = Tween<double>(begin: 0, end: 1).animate(controller)
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      })
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          OnFullyOpened();
        } else if (status == AnimationStatus.dismissed) {
          OnFullyClosed();
        }
      });;
    controller.forward();
    _RegCtrl(widget.closeNotifier);
  }



  @override void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(oldWidget.closeNotifier!= widget.closeNotifier){
      _UnregCtrl(oldWidget.closeNotifier);
      _RegCtrl(widget.closeNotifier);
    }
    duration = widget.duration;
  }

  @override dispose(){
    controller.dispose();
    _UnregCtrl(widget.closeNotifier);
    super.dispose();
  }

  double get animProgress => widget.curve.transform(animation.value);
  bool get animFinished => animation.isCompleted || animation.isDismissed;
}

class DFWController extends AnimatedCloseNotifier with ChangeNotifier{
  //Positioning
  final GlobalKey _key = GlobalKey();
  double? dx, dy;
  Offset? anchor, align;
  double? width, height;
  PositioningBehavior? layoutBehavior = PositioningBehavior.StopAtEdge;
  GeometryTrackHandle? tracking;
  bool forceUpdate = false;
}

class DraggableFloatingWindow extends AnimatedClosableWidget{

  Widget? child;
  DFWController ctrl;

  DraggableFloatingWindow({
    this.child,
    required this.ctrl,
  }) : super(key: ctrl._key, closeNotifier: ctrl);


  @override
  _DFWState createState() => _DFWState();
}

class _DFWState extends AnimatedClosableWidgetState<DraggableFloatingWindow>{

  //Size get size => widget.size??Size(200, 100);
  static bool isFloatEq(double a, double b){
    return (a - b).abs() < 1e-6;
  }

  static const double minScale = 0.4;

  double get scale => (1-minScale) * animProgress + minScale;
  DFWController get ctrl => widget.ctrl;

  void _OnWindowDrag(Offset delta){

    var ldx = delta.dx * scale;
    var ldy = delta.dy * scale;

    setState(() {

      if(ctrl.dx != null){
        ctrl.dx = ctrl.dx! + ldx;
      }

      if(ctrl.dy != null){
        ctrl.dy = ctrl.dy! + ldy;
      }
      ctrl.notifyListeners();
    });
  }

  _DFWState()
  {
  }

  @override
  Widget build(BuildContext context){
    double opacity = animProgress;

    var ctrl = widget.ctrl;
    return AnchoredPosition.fixedSize(
      tracking: ctrl.tracking,
      onPositioning: ctrl.layoutBehavior?.onPositioning,
      onSizing: ctrl.layoutBehavior?.onSizing,
      anchorX: ctrl.anchor?.dx??0,
      anchorY: ctrl.anchor?.dy??0,
      alignX: ctrl.align?.dx??0,
      alignY: ctrl.align?.dy??0,
      left:ctrl.dx,
      top:ctrl.dy,
      width: ctrl.width,
      height: ctrl.height,
      forceUpdate: ctrl.forceUpdate,
      child: Transform(
        child: Opacity(
          child: BuildDefaultWindowContent(widget.child),
          opacity: opacity,
        ),
        transform:Matrix4.diagonal3Values(1.0, scale, 1.0),
      ),

    );
  }

  static _DFWState? of(BuildContext ctx){
    return ctx.findAncestorStateOfType<_DFWState>();

  }
}

class RelativeDraggableFloatingWindow extends DraggableFloatingWindow{
  RelativeDraggableFloatingWindow({
    required DFWController ctrl,
    Widget? child
  }) : super(ctrl: ctrl, child: child);
  @override createState() => _RDFWState();
}

class _RDFWState extends _DFWState{

  Offset get availSpace {
    var as = context.findAncestorRenderObjectOfType<AnchorStackRO>();
    var ro = context.findRenderObject() as RenderBox;
    assert(as!=null,
    "Floating window must be placed inside anchor stack "
        "to function properly"
    );

    var panelSize = as!.size;
    var wndSize = ro.size;
    var w = max(0.0, panelSize.width - wndSize.width);
    var h = max(0.0, panelSize.height - wndSize.height);
    return Offset(w, h);
  }

  Offset Rel2Abs(Offset relPos){
    return Offset(relPos.dx * availSpace.dx, relPos.dy * availSpace.dy);
  }

  @override void _OnWindowDrag(Offset delta){

    var ldx = delta.dx * scale;
    var ldy = delta.dy * scale;

    var as = availSpace;
    var aw = as.dx;
    var ah = as.dy;

    var rdx = ldx / aw;
    var rdy = ldy / ah;

    var ctrl = widget.ctrl;
    var rx = (ctrl.dx??0) + rdx;
    var ry = (ctrl.dy??0) + rdy;
    if(rx > 1)rx = 1;else if(rx < 0) rx = 0;
    if(ry > 1)ry = 1;else if(ry < 0) ry = 0;

    if(ctrl.dx != null)ctrl.dx = rx;
    if(ctrl.dy != null)ctrl.dy = ry;

    setState(() {

      if(ctrl.dx != null)ctrl.dx = rx;
      if(ctrl.dy != null)ctrl.dy = ry;
      ctrl.notifyListeners();
    });
  }

  @override
  Widget build(BuildContext context) {
    double opacity = animProgress;
    var ctrl = widget.ctrl;

    return AnchoredPosition(
      tracking: ctrl.tracking,
      onPositioning: ctrl.layoutBehavior?.onPositioning,
      onSizing: ctrl.layoutBehavior?.onSizing,
      anchor: Rect.fromLTRB(0, 0, 1, 1),
      alignX: ctrl.dx??0,
      alignY: ctrl.dy??0,
      width: ctrl.width,
      height: ctrl.height,
      forceUpdate: ctrl.forceUpdate,
      child: Transform(
        child: Opacity(
          child: BuildDefaultWindowContent(widget.child),
          opacity: opacity,
        ),
        transform: Matrix4.diagonal3Values(1.0, scale, 1.0),
      ),

    );
  }
}

class FWMoveHandle extends StatelessWidget {
  const FWMoveHandle({
    Key? key,
    required this.child,
  }) : super(key: key);

  /// The widget for which the application would like to respond to a tap and
  /// drag gesture by starting a reordering drag on a reorderable list.
  final Widget child;


  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      //key: widget.listenerKey,
      behavior: HitTestBehavior.translucent,
      onPanUpdate: (details){_OnDrag(context,details.delta);},
      //onPointerMove: (event) => _OnDrag(context,event),
      child: child,
    );
  }

  void _OnDrag(BuildContext ctx, Offset delta) {
    final _DFWState? _dfw = _DFWState.of(ctx);
    _dfw?._OnWindowDrag(delta);
  }
}

enum PopupDirection{
  top, bottom, left, right,
  horizontal, vertical, auto
}

class PopupWindow extends AnimatedClosableWidget {

  final double margin;
  final Widget child;
  final GeometryTrackHandle tracking;

  late final bool showOnTop, showOnBottom, showOnLeft, showOnRight;

  PopupWindow(
      {
        Key? key,
        required this.child,
        required this.tracking,
        this.margin = 10,
        this.showOnTop = false,
        this.showOnBottom = false,
        this.showOnLeft = false,
        this.showOnRight = false,
        Duration duration = const Duration(milliseconds: 100),
        Curve curve = Curves.ease,
        AnimatedCloseNotifier? closeNotifier,
      }
      ):super(
      key: key,
      closeNotifier: closeNotifier,
      duration: duration,
      curve: curve
  );

  PopupWindow.direction(
      {
        Key? key,
        required this.child,
        required this.tracking,
        this.margin = 10,
        PopupDirection direction = PopupDirection.auto,
        Duration duration = const Duration(milliseconds: 100),
        Curve curve = Curves.ease,
        AnimatedCloseNotifier? closeNotifier,
      }
      ):super(
    key: key,
    closeNotifier: closeNotifier,
    duration: duration,
    curve: curve,
  )
  {
    switch(direction){
      case PopupDirection.top:
        showOnTop = true; showOnBottom = false;
        showOnLeft = false; showOnRight = false;
        break;
      case PopupDirection.bottom:
        showOnTop = false; showOnBottom = true;
        showOnLeft = false; showOnRight = false;
        break;
      case PopupDirection.left:
        showOnTop = false; showOnBottom = false;
        showOnLeft = true; showOnRight = false;
        break;
      case PopupDirection.right:
        showOnTop = false; showOnBottom = false;
        showOnLeft = false; showOnRight = true;
        break;
      case PopupDirection.horizontal:
        showOnTop = false; showOnBottom = false;
        showOnLeft = true; showOnRight = true;
        break;
      case PopupDirection.vertical:
        showOnTop = true; showOnBottom = true;
        showOnLeft = false; showOnRight = false;
        break;
      case PopupDirection.auto:
        showOnTop = true; showOnBottom = true;
        showOnLeft = true; showOnRight = true;
        break;
    }
  }

  @override
  _PopupWindowState createState() => _PopupWindowState();
}

class _PopupWindowState extends AnimatedClosableWidgetState<PopupWindow>{
  /*
  late Animation<double> animation;
  late AnimationController controller;

  _NotifyClose(){
    var c = widget.closeNotifier?._chg.value;
    controller.reverse().then((value){c?.complete();});
  }

  _RegListener(WndCloseAnimCtrl? closeNotifier){
    if(closeNotifier!=null){
      closeNotifier!._chg.addListener(_NotifyClose);
      closeNotifier!._isInstalled = true;
    }
  }

  _UnRegListener(WndCloseAnimCtrl? closeNotifier){
    if(closeNotifier!=null){
      closeNotifier!._chg.removeListener(_NotifyClose);
      closeNotifier!._isInstalled = false;
    }
  }

  @override
  void initState() {
    super.initState();
    controller =
        AnimationController(duration: widget.duration, vsync: this);
    animation = Tween<double>(begin: 0, end: 1).animate(controller)
      ..addListener(() {
        setState(() {
          // The state that has changed here is the animation object’s value.
        });
      })
      ..addStatusListener((state) => print('$state'));
    controller.forward();
    _RegListener(widget.closeNotifier);
  }



  @override void didUpdateWidget(PopupWindow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(oldWidget.closeNotifier!= widget.closeNotifier){
      _UnRegListener(oldWidget.closeNotifier);
      _RegListener(widget.closeNotifier);
    }
  }

  @override dispose(){
    super.dispose();
    controller.dispose();
    _UnRegListener(widget.closeNotifier);
  }

  double get animProgress => widget.curve.transform(animation.value);
  bool get animFinished => animation.isCompleted || animation.isDismissed;
  */
  Offset _PositioningFn(LayoutParams p, Offset pos){
    var hndlGeom = p.trackingGeom;
    var hndlCenter = hndlGeom.center;
    _dOffsetX(){
      var maxX = p.stackSize.width;
      var c = hndlCenter.dx;
      var w2 = p.widgetSize.width/2;
      var l = c - w2; var r = c + w2;
      if(l < 0) return -l;
      if(r > maxX) return maxX - r;
      return 0;
    }

    _dOffsetY(){
      var maxY = p.stackSize.height;
      var c = hndlCenter.dy;
      var h2 = p.widgetSize.height/2;
      var t = c - h2; var b = c + h2;
      if(t < 0) return -t;
      if(b > maxY) return maxY - b;
      return 0;
    }

    _assessTop(){
      var availSpace = hndlGeom.top;
      var targetX = hndlCenter.dx - p.widgetSize.width/2;
      var targetY = hndlGeom.top - p.widgetSize.height - widget.margin;
      var offX = _dOffsetX();
      var offY = targetY < 0? -targetY:0;
      var disp = Offset(targetX + offX, targetY + offY);
      var exit = disp + Offset(0,widget.margin);
      return[availSpace, disp, exit];
    }

    _assessBottom(){
      var maxY = p.stackSize.height;
      var availSpace = maxY - hndlGeom.bottom;
      var targetX = hndlCenter.dx - p.widgetSize.width/2;
      var targetY = hndlGeom.bottom + widget.margin;
      var offX = _dOffsetX();
      var offY = min(0, maxY - targetY - p.widgetSize.height);
      var disp = Offset(targetX + offX, targetY + offY);
      var exit = disp - Offset(0,widget.margin);
      return[availSpace, disp, exit];
    }

    _assessLeft(){
      var availSpace = hndlGeom.left;
      var targetX = hndlGeom.left - p.widgetSize.width - widget.margin;
      var targetY = hndlCenter.dy - p.widgetSize.height/2;
      var offX = targetX < 0? -targetX:0;
      var offY = _dOffsetY();
      var disp = Offset(targetX + offX, targetY + offY);
      var exit = disp + Offset(widget.margin, 0);
      return[availSpace, disp, exit];
    }

    _assessRight(){
      var maxX = p.stackSize.width;
      var availSpace = maxX - hndlGeom.right;
      var targetX = hndlGeom.right + widget.margin;
      var targetY = hndlCenter.dy - p.widgetSize.height/2;
      var offX = min(0, maxX - targetX - p.widgetSize.width);
      var offY = _dOffsetY();
      var disp = Offset(targetX + offX, targetY + offY);
      var exit = disp - Offset(widget.margin, 0);
      return[availSpace, disp, exit];
    }

    var options = [];
    if(widget.showOnLeft) options.add(_assessLeft());
    if(widget.showOnRight) options.add(_assessRight());
    if(widget.showOnTop) options.add(_assessTop());
    if(widget.showOnBottom) options.add(_assessBottom());
    var disp = hndlCenter;
    var exit = disp;
    var selectScore = double.negativeInfinity;
    for(var o in options){
      var score = o[0];
      var _disp = o[1];
      var _exit = o[2];
      if(score > selectScore){
        selectScore = score;
        disp = _disp;
        exit = _exit;
      }
    }

    return Offset.lerp(exit, disp, animProgress)!;
  }

  @override
  Widget build(BuildContext context) {
    return AnchoredPosition(
      tracking: widget.tracking,
      child: Opacity(
        child: BuildDefaultWindowContent(widget.child),
        opacity: animProgress,
      ),
      forceUpdate: !animFinished,
      onPositioning: _PositioningFn,
    );
  }
}



class PopupBuilder<T> extends StatefulWidget{

  Widget Function(void Function(), T?) contentBuilder;
  Widget Function(void Function(), T?) popupBuilder;
  bool Function(T?)? updateShouldClose;

  bool tapToDismiss;
  T? data;

  PopupBuilder({
    Key? key,
    required this.contentBuilder,
    required this.popupBuilder,
    this.data,
    this.tapToDismiss = true,
    this.updateShouldClose
  }){
  }

  @override
  _PopupBuilderState<T> createState() => _PopupBuilderState<T>();
}

class _PopupBuilderState<T> extends State<PopupBuilder<T>> {

  late FloatingWindowPanelState fwps;

  Widget? _pop;

  GeometryTrackHandle _gHandle = GeometryTrackHandle();

  @override
  void initState(){
    super.initState();
    fwps = FloatingWindowPanelState.of(context)!;
  }

  @override
  void didUpdateWidget(PopupBuilder<T> oldWidget){
    super.didUpdateWidget(oldWidget);
    bool shouldClose = widget.updateShouldClose?.call(oldWidget.data)??true;
    if(shouldClose){
      WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
        ClosePopup();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GeometryTracker(
      handle: _gHandle,
      child: widget.contentBuilder(ShowPopup, widget.data),
    );
  }

  @override
  void dispose(){
    super.dispose();
  }

  void ShowPopup(){
    if(_pop != null) fwps.CloseWindow(_pop!);
    _pop = _buildPopWrapper(
        widget.popupBuilder(ClosePopup, widget.data)
    );
    fwps.ShowPopup(_pop!, tapOutsideToDismiss: widget.tapToDismiss);
  }

  void ClosePopup(){
    if(_pop == null)return;
    fwps.RemovePopup(popup:_pop!);
    _pop = null;
  }

  Widget _buildPopWrapper(Widget child){
    return AnchoredPosition(
      tracking: _gHandle,
      anchor: Rect.fromLTRB(0.5, 1, 0.5, 1),
      alignX: 0.5,
      child: BuildDefaultWindowContent(child),
      onPositioning: PositioningBehavior.StopAtEdge.onPositioning,
      onSizing: PositioningBehavior.StopAtEdge.onSizing,
    );
  }
}
