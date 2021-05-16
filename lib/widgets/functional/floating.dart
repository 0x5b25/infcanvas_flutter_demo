import 'dart:core';
import 'dart:ui';

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



Widget _BuildFWContent(Widget child){
  return Card(
    color: Colors.transparent,

    child: ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 50.0,
          sigmaY: 50.0,
          tileMode: TileMode.repeated,
        ),
        child: Container(
          color: Colors.grey[300]!.withOpacity(0.9),

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

  Widget child;

  FloatingWindow({Key? key,required this.child,
    this.left, this.top,this.right, this.bottom, this.width,this.height, 
    this.anchor = const Rect.fromLTRB(0, 0, 0, 0),
    this.align = Offset.zero,
    this.tracking,
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
      child: _BuildFWContent(child),

    );
  }
}

class DFWController{
  //Positioning
  double? dx, dy;
  Offset? anchor, align;
  double? width, height;
  PositioningBehavior? layoutBehavior = PositioningBehavior.StopAtEdge;
  GeometryTrackHandle? tracking;
}

class DraggableFloatingWindow extends StatefulWidget{
  
  Widget? child;
  DFWController ctrl;

  DraggableFloatingWindow({
    Key? key, this.child,
    required this.ctrl,
  }) : super(key: key);


  @override
  _DFWState createState() => _DFWState();
}

class _DFWState extends State<DraggableFloatingWindow>{

  //double? dx, dy;
  GeometryTrackHandle _positionHandle = GeometryTrackHandle();

  //Size get size => widget.size??Size(200, 100);
  static bool isFloatEq(double a, double b){
    return (a - b).abs() < 1e-6;
  }

  void _OnWindowDrag(Offset delta){

    var ldx = delta.dx;
    var ldy = delta.dy;

    var panel =FloatingWindowPanelState.of(context);
    if(panel != null){
      var panelGeo = panel.geometryHandle.RequestGeometry();
      var wndGeo = _positionHandle.RequestGeometry();
      if(panelGeo == null || wndGeo == null) return;

      if(wndGeo.right >= panelGeo.right && ldx > 0){
        ldx = 0;
      }else if(wndGeo.left <= panelGeo.left && ldx < 0){
        ldx = 0;
      }

      if(wndGeo.bottom >= panelGeo.bottom && ldy > 0){
        ldy = 0;
      }else if(wndGeo.top <= panelGeo.top && ldy < 0){
        ldy = 0;
      }
    }
    setState(() {
      var ctrl = widget.ctrl;

      if(ctrl.dx != null){
        ctrl.dx = ctrl.dx! + ldx;
      }

      if(ctrl.dy != null){
        ctrl.dy = ctrl.dy! + ldy;
      }
    });
  }

  _DFWState()
  {
  }

  @override
  Widget build(BuildContext context){
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
      child: GeometryTracker(
        handle: _positionHandle,
        child: Card(
          color: Colors.transparent,

          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: 50.0,
                sigmaY: 50.0,
                tileMode: TileMode.repeated,
              ),
              child: Container(
                color: Colors.grey[300]!.withOpacity(0.9),

                child: widget.child
              ),
            ),
          ),
        ),
      ),

    );
  }

  static _DFWState? of(BuildContext ctx){
    return ctx.findAncestorStateOfType<_DFWState>();
  
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
      child: _BuildFWContent(child),
      onPositioning: PositioningBehavior.StopAtEdge.onPositioning,
      onSizing: PositioningBehavior.StopAtEdge.onSizing,
    );
  }
}
