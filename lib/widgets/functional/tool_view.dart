
import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:infcanvas/widgets/functional/anchor_stack.dart';
import 'package:infcanvas/widgets/functional/floating.dart';



class ReorderEntry<T> extends LinkedListEntry<ReorderEntry<T>>{
  T obj;
  ReorderEntry(this.obj);
}

class Reorderable<T>{
  final _order = LinkedList<ReorderEntry<T>>();
  final _reg = Map<T, ReorderEntry<T>>();

  T? get topmost => _order.isEmpty?null:_order.last.obj;
  int get length => _order.length;

  ///Returns whether object is newly added
  bool AddOrElevate(T object){
    if(object == topmost) return false;
    var record = _reg[object];
    if(record == null){
      var entry = ReorderEntry(object);
      _order.add(entry);
      _reg[object] = entry;
      return true;
    }else{
      record.unlink();
      _order.add(record);
      return false;
    }
  }

  ///Returns whether object is contained and removed
  bool Remove(T object){
    var record = _reg[object];
    if(record == null){
      return false;
    }

    record.unlink();
    _reg.remove(object);
    return true;
  }

  Iterable<T> Ordered()sync*{
    for(var e in _order){
      yield e.obj;
    }
  }

  void Clear(){
    _reg.clear();
    _order.clear();
  }
}


mixin ReorderableToolConfigManager
<T extends ReorderableToolConfig<ReorderableToolConfigManager<T>>>
on _WidgetCtrlBase
{
  final _order = Reorderable<T>();

  Iterable<T> get ordered => _order.Ordered();

  @protected
  Future<bool> RemoveConfig(T config)async{
    if(_order.Remove(config) == false) return false;
    await config.OnRemove();
    config._mgr = null;
    Repaint();
    return true;
  }

  ///@return: is order changed
  @protected
  bool AddOrElevateConfig(T config){
    if(config == topmost) return false;
    var oldConf = topmost;
    if(_order.AddOrElevate(config)){
      config._mgr = this;
    }
    oldConf?.OnFocusLost();
    config.OnFocusRegain();
    Repaint();
    return true;
  }

  T? get topmost => _order.topmost;

  void Clear(){
    var wnd = ordered.toList();
    _order.Clear();
    for(var w in wnd){
      w.OnRemove();
    }
  }

  void Dispose(){
    Clear();
  }

}

class ReorderableToolConfig<T extends ReorderableToolConfigManager<ReorderableToolConfig<T>>>{
  T? _mgr;
  T get manager{
    assert(_mgr != null, 'Config not registered');
    return _mgr!;
  }

  bool get isInstalled => _mgr != null;
  bool get hasFocus => isInstalled && (manager.topmost == this);

  Future<void> Close()async{
    if(!isInstalled) return;
    await manager.RemoveConfig(this);
  }

  void BringToFront(){
    if(!isInstalled) return;
    manager.AddOrElevateConfig(this);
  }

  Future<void> OnRemove()async{}
  ///Triggered when other takes the topmost place
  void OnFocusLost(){}
  ///Triggered when regain topmost place
  void OnFocusRegain(){}
}

abstract class _WidgetCtrlBase{
  void Repaint();
}
class WidgetController<T extends ControlledWidget<T>> extends _WidgetCtrlBase{
  ControlledWidgetState<T>? _state;

  bool get isInstalled => (_state != null) && _state!.mounted;

  ControlledWidgetState<T> get state => _state!;

  void Repaint(){
    if(!isInstalled) return;
    state.NotifyRepaint();
  }

}


abstract class ControlledWidget<T extends ControlledWidget<T>> extends StatefulWidget {

  final WidgetController<T> controller;

  ControlledWidget({Key? key, required this.controller}):super(key: key);

}


abstract class ControlledWidgetState<T extends ControlledWidget<T>> extends State<T> {

  @override void initState() {
    super.initState();
    widget.controller._state = this;
  }

  @override void didUpdateWidget(T oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(oldWidget.controller != widget.controller){
      oldWidget.controller._state = null;
      widget.controller._state = this;
    }
  }

  @override void dispose() {
    super.dispose();
    widget.controller._state = null;
  }

  void NotifyRepaint(){
    setState(() {

    });
  }
}

typedef ContentBuilder = Widget Function(BuildContext);
typedef EntryCloseCallback = void Function();

abstract class ToolOverlayEntry{
  ToolOverlayManager? _mgr;
  ToolOverlayManager get manager{
    assert(_mgr != null, 'Overlay entry not registered');
    return _mgr!;
  }


  bool AcceptPointerInput(PointerDownEvent e) => false;

  Widget BuildContent(BuildContext ctx);

  void OnClose(){}

  void Dispose(){
    if(_mgr == null) return;
    _mgr!.RemoveOverlayEntry(this);
    _mgr = null;
  }
}


class PointerOverlayTest extends ToolOverlayEntry{

  double x = 0; double y = 0;

  late final _gr = PanGestureRecognizer()
    ..onUpdate = (d){
      x = d.localPosition.dx;
      y = d.localPosition.dy;
      manager.Repaint();
    }
  ;

  @override
  Widget BuildContent(BuildContext ctx) {
    return AnchoredPosition(
      top: y, left: x,
      child: Icon(Icons.ac_unit),
    );
  }

  @override bool AcceptPointerInput(PointerDownEvent e) {
    if(!_gr.isPointerAllowed(e)) return false;
    _gr.addPointer(e);
    return true;
  }
}

class TestPainter extends CustomPainter{
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawColor(Colors.black, BlendMode.src);
    canvas.drawRect(
        Rect.fromLTWH(10, 50, 300, 300),
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.fill
    );


    canvas.drawRect(
        Rect.fromLTWH(200, 200, 300, 300),
        Paint()
          ..color = Colors.orange
          ..style = PaintingStyle.fill
    );

    {
      Paint p = Paint();
      p.style = PaintingStyle.stroke;
      p.color = Colors.red;
      p.strokeWidth = 2;
      canvas.drawLine(Offset.zero, size.bottomRight(Offset.zero), p);
    }

    double step = 40;
    var w = step/2;
    for(var x = 0.0; x <= size.width; x+=step){
      for(var y = 0.0; y <= size.width; y+=step){

        var cx = x + w;
        var cy = y + w;
        canvas.drawRect(Rect.fromLTWH(x, y, w, w), Paint()..color = Colors.grey);
        canvas.drawRect(Rect.fromLTWH(cx, y, w, w), Paint()..color = Colors.grey[600]!);
        canvas.drawRect(Rect.fromLTWH(x, cy, w, w), Paint()..color = Colors.grey[600]!);
        canvas.drawRect(Rect.fromLTWH(cx, cy, w, w), Paint()..color = Colors.grey);
      }
    }

  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate)=>true;


}

class CustomPainterTest extends ToolOverlayEntry{
  @override
  Widget BuildContent(BuildContext ctx) {
    return AnchoredPosition.fill(child: CustomPaint(painter: TestPainter(),));
  }

}

class ToolViewManager extends WidgetController<ToolView>{
  final overlayManager = ToolOverlayManager();
  final windowManager = ToolWindowManager();
  final sideBarManager = SideBarManager();
  final popupManager = PopupManager();
  final menuBarManager = MenuBarManager();

  static ToolViewManager? of(BuildContext context){
    var state = context.findAncestorStateOfType<_ToolViewState>();
    return state?.manager;
  }
}


class ToolView extends ControlledWidget<ToolView> {

  ToolView({
    Key? key,
    required ToolViewManager manager
  }) : super(key: key, controller: manager);

  @override
  _ToolViewState createState() => _ToolViewState();
}

class _ToolViewState extends ControlledWidgetState<ToolView> {

  ToolViewManager get manager => widget.controller as ToolViewManager;


  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: Material(
        child: PopupView(
          manager: manager.popupManager,
          child: AnchorStack(
            children: [
              AnchoredPosition.fill(
                  child: ToolOverlayView(manager: manager.overlayManager,)
              ),

              if(manager.sideBarManager.topmost != null)
                FloatingWindow(
                    anchor: Rect.fromLTRB(0, 0, 0, 1),
                    top: 80, bottom: -80, left: 10, width: 50,
                    child: SideBarView(manager: manager.sideBarManager,)
                ),

              AnchoredPosition(
                  anchor: Rect.fromLTRB(1, 0, 1, 0),
                  alignX: 1,
                  child: MenuBar(manager: manager.menuBarManager,)
              ),

              AnchoredPosition.fill(
                  child: ToolWindowPanel(manager: manager.windowManager,)
              ),
            ],
          ),
        ),
      ),
    );
  }
}


const int OverlayLayerCount = 8;
const int OverlayLayer_Canvas = 0;

class ToolOverlayManager extends WidgetController<ToolOverlayView>{
  final List<ToolOverlayEntry?> overlay = List.filled(OverlayLayerCount, null);
  final Map<ToolOverlayEntry, int> _overlayIdx = {};


  ToolOverlayManager(){
    //RegisterOverlayEntry(PointerOverlayTest(),1);
    //RegisterOverlayEntry(CustomPainterTest(), 2);
  }

  void RoutePointer(PointerDownEvent e) {
    //Route pointer from top to bottom
    for(var o in overlay.reversed){
      if(o == null) continue;
      if(o.AcceptPointerInput(e)) return;
    }
  }

  int? GetOverlayIndex(ToolOverlayEntry entry){
    return _overlayIdx[entry];
  }

  void RemoveOverlayEntry(ToolOverlayEntry entry){
    var oldIdx = GetOverlayIndex(entry);
    if(oldIdx != null){
      overlay[oldIdx] = null;
      entry.OnClose();
      entry._mgr = null;
      _overlayIdx.remove(entry);
    }
  }

  void RegisterOverlayEntry(ToolOverlayEntry entry, int slot){
    assert(slot >= 0 && slot < overlay.length, 'Invalid slot index: $slot');

    var oldEntry = overlay[slot];
    if(oldEntry == entry) return;
    oldEntry?.OnClose();

    var oldIdx = GetOverlayIndex(entry);
    if(oldIdx != null){
      overlay[oldIdx] = null;
    }
    entry._mgr = this;
    overlay[slot] = entry;
    _overlayIdx[entry] = slot;
    Repaint();
  }

  void Dispose(){
    _overlayIdx.clear();
    var ov = <ToolOverlayEntry>[];
    for(int i = 0; i < overlay.length; i++){
      var o = overlay[i];
      if(o!= null){
        ov.add(o);
        overlay[i] = null;
      }
    }
    for(var o in ov){
      o.Dispose();
    }
  }
}



class ToolOverlayView extends ControlledWidget<ToolOverlayView> {

  ToolOverlayView({
    Key? key,
    required ToolOverlayManager manager
  }) : super(key: key, controller: manager);

  @override
  _ToolOverlayViewState createState() => _ToolOverlayViewState();
}

class _ToolOverlayViewState extends ControlledWidgetState<ToolOverlayView> {

  ToolOverlayManager get manager => widget.controller as ToolOverlayManager;

  _BuildOverlay() sync* {
    for(var entry in manager.overlay){
      if(entry == null) continue;
      yield entry.BuildContent(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnchorStack(
      children: [
        for(var o in _BuildOverlay())
          o,

        AnchoredPosition.fill(
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (e){manager.RoutePointer(e);},
            )
        ),
      ],
    );
  }
}


class ToolWindow extends ReorderableToolConfig<ToolWindowManager>{

  DFWController windowController = DFWController()
    ..dx = 0
    ..dy = 0
  ;

  Widget BuildContent(BuildContext context){
    return CreateDefaultLayout(
        Container(
          width: 200, height: 300,
        )
    );
  }

  @override @mustCallSuper OnRemove(){
    return windowController.NotifyClose();
  }


  Widget CreateDefaultLayout(
      Widget child,
      {
        IconData? icon,
        String? title,
      }
      ) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e){BringToFront();},
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: FWMoveHandle(
                    child: Row(
                      children: [
                        if(icon != null)
                          Container(width: 30, height: 30, child: Icon(icon)),
                        if(title != null)
                          Padding(
                            padding: EdgeInsets.only(left:4),
                            child: Align(
                                alignment: Alignment.centerLeft,
                                child:Text(title,)
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Container(
                    width: 30,
                    child: TextButton(child: Icon(Icons.close),onPressed: Close,)
                )
              ],
            ),
          ),

          child,
        ],
      ),
    );

  }
}


class ToolWindowManager
    extends WidgetController<ToolWindowPanel>
    with ReorderableToolConfigManager<ToolWindow>
{

  //LinkedList<_WindowEntry> _wndOrder = LinkedList<_WindowEntry>();
  //Map<ToolWindow, _WindowEntry> _wndReg = {};
  bool ShowWindow(ToolWindow window){
    return AddOrElevateConfig(window);
  }

  Future<bool> CloseWindow(ToolWindow window){
    return RemoveConfig(window);
  }

}

class ToolWindowPanel extends ControlledWidget<ToolWindowPanel> {

  ToolWindowPanel({
    Key? key,
    required ToolWindowManager manager,
  }) : super(key: key, controller: manager);

  @override ToolWindowManager get controller => super.controller as ToolWindowManager;

  @override
  _ToolWindowPanelState createState() => _ToolWindowPanelState();
}

class _ToolWindowPanelState extends ControlledWidgetState<ToolWindowPanel> {

  _BuildWindows(){
    return[
      for(var w in widget.controller.ordered)
        RelativeDraggableFloatingWindow(
          ctrl: w.windowController,
          child: w.BuildContent(context),

        ),

    ];
  }

  @override
  Widget build(BuildContext context) {
    return AnchorStack(
      children: _BuildWindows(),
    );
  }
}

class SideBar extends ReorderableToolConfig<SideBarManager>{

  Widget BuildContent(BuildContext context){
    return ListView.builder(
        itemCount: 50,
        itemBuilder: (ctx, i){
          return Text("$i");
        }
    );
  }

}

class SideBarManager
    extends WidgetController<SideBarView>
    with ReorderableToolConfigManager<SideBar>
{

  ///@return: is actually showed
  bool ShowSideBar(SideBar sideBar){
    return AddOrElevateConfig(sideBar);
  }

  Future<bool> CloseSideBar(SideBar sideBar){
    return RemoveConfig(sideBar);
  }

}

class SideBarView extends ControlledWidget<SideBarView> {

  SideBarView({
    Key? key,
    required SideBarManager manager,
  }) : super(key: key, controller: manager);

  @override SideBarManager get controller => super.controller as SideBarManager;

  @override
  _SideBarViewState createState() => _SideBarViewState();
}

class _SideBarViewState extends ControlledWidgetState<SideBarView> {

  SideBarManager get manager => widget.controller;

  @override
  Widget build(BuildContext context) {
    if(manager.topmost != null){
      return manager.topmost!.BuildContent(context);
    }
    return Container();
  }
}


class PopupProxyConfig extends PopupConfig{

  bool Function()? BarrierDismiss;
  Widget Function(BuildContext)? contentBuilder;
  void Function()? onFocusLost, onFocusRegain;
  Future<void> Function()? onRemove;

  @override get barrierDismiss => BarrierDismiss?.call()??super.barrierDismiss;
  @override Widget BuildContent(BuildContext context) {
    return contentBuilder?.call(context)??Container();
  }
  @override void OnFocusLost() {onFocusLost?.call(); }
  @override void OnFocusRegain() {onFocusRegain?.call(); }
  @override Future<void> OnRemove() async{await onRemove?.call();}
}

class PopupConfig extends ReorderableToolConfig<PopupManager>{

  bool get barrierDismiss => true;

  Widget BuildContent(BuildContext context){
    return AnchoredPosition.fixedSize(
      width: 200,
      height: 300,
      child: Container(
        color: Color.fromARGB(255, 255, 140, 50),
      ),
    );
  }
}

class PopupManager
    extends WidgetController<PopupView>
    with ReorderableToolConfigManager<PopupConfig>
{
  bool ShowPopup(PopupConfig popup){
    return AddOrElevateConfig(popup);
  }

  Future<bool> ClosePopup(PopupConfig popup){
    return RemoveConfig(popup);
  }
}

class PopupView extends ControlledWidget<PopupView> {

  final Widget child;

  PopupView({
    Key? key,
    required PopupManager manager,
    required this.child,
  }) : super(key: key, controller: manager);

  @override PopupManager get controller => super.controller as PopupManager;

  @override
  _PopupViewState createState() => _PopupViewState();
}

class _PopupViewState extends ControlledWidgetState<PopupView> {

  PopupManager get manager => widget.controller;

  Iterable<Widget> _BuildContent()sync*{
    for(var c in manager.ordered){
      if(c.barrierDismiss){
        yield AnchoredPosition.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d){manager.ClosePopup(c);},
            )
        );
      }
      yield c.BuildContent(context);
    }
  }

  @override
  Widget build(BuildContext context) {

    return AnchorStack(
        children: [
          AnchoredPosition.fill(child: widget.child),
          for(var c in _BuildContent()) c,
        ]
    );
  }
}

///Operation context for individual menu items
class MenuContext extends WidgetController<MenuPopupContent>{

  void Function() showFn;
  Future<void> Function() closeFn;

  MenuContext(this.showFn, this.closeFn){}

  @override MenuPopupContentState get state
  => super.state as MenuPopupContentState;

  List _stack = [];

  String get currentTitle => _stack.isEmpty?"":_stack.last.first??"";
  get currentBuilder => _stack.isEmpty?null:_stack.last.last;

  void ShowNewPage(
      {
        String? title,
        required Widget Function(BuildContext ctx) builder,
      }
      ){
    _stack.add([title, builder]);
    if(_stack.length == 1){
      showFn();
    }else{
      Repaint();
    }
  }

  void Return(){
    if(_stack.isNotEmpty){
      _stack.removeLast();
    }
    if(!isInstalled) return;
    if(_stack.isEmpty){
      closeFn();
    }else{
      Repaint();
    }
  }

  void NotifyCloseAll() {
    _stack.clear();
  }

  Future<void> Close(){
    NotifyCloseAll();
    return closeFn();
  }

}

class MenuPopupContent extends ControlledWidget<MenuPopupContent>{
  MenuPopupContent({
    Key? key,
    required MenuContext controller,
  }) : super(key: key, controller: controller);


  @override createState() => MenuPopupContentState();

}

class MenuPopupContentState extends ControlledWidgetState<MenuPopupContent>
    with TickerProviderStateMixin{

  MenuContext get mcx => widget.controller as MenuContext;
  bool get isSingleLayer => mcx._stack.length == 1;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      vsync: this,
      duration: Duration(milliseconds: 100),
      curve: Curves.ease,
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ///Header
            if(!isSingleLayer) Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 30,
                  child: TextButton(
                    child: Text('<'),
                    onPressed: (){mcx.Return();},
                  ),
                ),
                Expanded(
                  child: Text(
                    mcx.currentTitle,
                    textAlign: TextAlign.center,
                  ),
                ),
                SizedBox(width: 30,)
              ],
            ),

            ///Content
            if(mcx.currentBuilder!=null)
              Padding(
                padding: EdgeInsets.all(8.0),
                child:mcx.currentBuilder(context),
              ),
          ],
        ),
      ),
    );
  }

}

class MenuButton extends StatefulWidget {

  final PopupDirection direction;
  final MenuContentBase menuEntry;
  final Widget Function(BuildContext, void Function())? buttonBuilder;

  MenuButton(
    this.menuEntry,
    [this.buttonBuilder, this.direction = PopupDirection.auto]
  );

  @override
  _MenuButtonState createState() => _MenuButtonState();
}

class _MenuButtonState extends State<MenuButton> {

  final gHandle = GeometryTrackHandle();
  final pConfig = PopupProxyConfig();
  late final pCtrl = MenuContext(_ShowPopup, _ClosePopup);
  final closeNotifier = AnimatedCloseNotifier();

  void _ShowPopup(){
    var mgr = ToolViewManager.of(context);
    assert(mgr != null, "Widget should be placed inside a ToolView");
    mgr!.popupManager.ShowPopup(pConfig);
  }

  Future<void> _ClosePopup(){
    return pConfig.Close();
  }

  Widget _BuildButton(){
    _PerformAct(){
      widget.menuEntry.PerformAction(pCtrl);
    }
    if(widget.buttonBuilder != null){
      return widget.buttonBuilder!(context, _PerformAct);
    }
    return ElevatedButton(
        child: Text(widget.menuEntry.name),
        onPressed: _PerformAct
    );
  }

  @override void initState() {
    super.initState();
    pConfig.contentBuilder = (ctx){
      return PopupWindow.direction(
        child: MenuPopupContent(controller: pCtrl,),
        tracking:gHandle,
        direction: widget.direction,
        closeNotifier: closeNotifier,
      );
    };
    pConfig.onRemove = ()async{
      pCtrl.NotifyCloseAll();
      await closeNotifier.NotifyClose();
    };
  }

  @override void dispose() {
    super.dispose();
    pConfig.Close();
  }

  @override
  Widget build(BuildContext context) {
    return GeometryTracker(
        handle: gHandle,
        child: _BuildButton()
    );
  }

}

class MenuContentBase{
  String name;
  IconData? ico;

  MenuContentBase({
    required this.name,
    this.ico
  });

  void PerformAction(MenuContext ctx){

  }
}

abstract class MenuPage extends MenuContentBase{
  MenuPage({
    required String name,
    IconData? ico
  }) : super(name: name, ico: ico);

  Widget BuildContent(BuildContext bctx, MenuContext mctx);

  @override PerformAction(ctx){
    ctx.ShowNewPage(builder:(bctx)=>BuildContent(bctx, ctx), title: name);
  }
}

class MenuActionButton extends StatelessWidget{

  final String? label;
  final IconData icon;
  final Function() onPressed;

  MenuActionButton(
    {
      Key? key,
      this.label,
      required this.icon,
      required this.onPressed,
    }
  ):super(key: key);

  @override build(ctx){
    return TextButton(
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon),
            Text(label??"", overflow: TextOverflow.ellipsis,maxLines: 1,),
          ],
        ),
      ),
      onPressed: onPressed,
    );
  }
}

class SubMenu extends MenuPage{

  List<MenuContentBase> items = [];

  SubMenu({
    required String name,
    IconData? ico,
  }) : super(name: name, ico: ico);

  Widget _BuildEntry(MenuContentBase entry, MenuContext ctx){
    return MenuActionButton(
      icon: entry.ico??Icons.all_inclusive,
      label: entry.name,
      onPressed: (){
        entry.PerformAction(ctx);
      },
    );
  }

  @override BuildContent(bctx, mctx) {
    return Center(
      child: Wrap(
        runSpacing: 10,
        children: [
          for(var i in items) _BuildEntry(i, mctx)
        ],
      ),
    );
  }
}


class CustomMenuPage extends MenuPage{

  Widget Function(BuildContext, MenuContext) builder;

  CustomMenuPage({
    required String name,
    IconData? ico,
    required this.builder,
  }) : super(name: name, ico: ico);

  @override BuildContent(bctx, mctx) {
    return builder(bctx, mctx);
  }
}

class MenuAction extends MenuContentBase{

  final void Function() action;

  MenuAction({
    required String name,
    IconData? ico,
    required this.action
  }) : super(name: name, ico: ico);

  @override PerformAction(ctx){
    ctx.Close();
    action();
  }

}

class MenuPath{
  String name;
  IconData ico;
  MenuPath? next;
  MenuPath({
    this.name = "Menu",
    this.ico = Icons.menu_open
  });

  MenuPath.copySeg(MenuPath seg)
      :this.name = seg.name,
        this.ico = seg.ico
  {}

  MenuPath Next(String name, [IconData ico = Icons.menu_open]){
    if(next != null){
      next!.Next(name, ico);
    }else{
      next = MenuPath(name: name, ico:ico);
    }
    return this;
  }

  @override bool operator== (Object other){
    if(other.runtimeType != runtimeType) return false;
    if(other.hashCode != hashCode) return false;
    var o = other as MenuPath;
    if(next != null){
      if(next != other.next) return false;
    }
    return name == other.name;
  }

  @override get hashCode => (next.hashCode << 2) ^ name.hashCode;
}

class MenuBarManager extends WidgetController<MenuBar>{
  final root = SubMenu(name: "Menu");

  List<MenuContentBase> quickAccess = [];

  SubMenu? FindSubMenu(MenuPath? path){
    if(path == null) return null;
    SubMenu? menuSeg;
    MenuPath? pathSeg = path;
    //Init
    if(path.name == root.name){
      menuSeg = root;
    }else{
      for(var s in quickAccess){
        if(s.name == path.name){
          menuSeg = s as SubMenu;
          break;
        }
      }
      if(menuSeg == null){
        menuSeg = SubMenu(name: path.name, ico:path.ico);
        quickAccess.add(menuSeg);
      }
    }

    //Walk path
    while(true){
      pathSeg = pathSeg!.next;
      if(pathSeg == null) break;
      var menuList = menuSeg!.items;
      var currMenuSeg = menuSeg;

      //find matching segments
      for(var s in menuList){
        if(s.name == pathSeg.name){
          menuSeg = s as SubMenu;
          break;
        }
      }
      //No matching seg, create new
      if(menuSeg == currMenuSeg){
        menuSeg = SubMenu(name: pathSeg.name, ico:path.ico);
        currMenuSeg.items.add(menuSeg);
      }
    }

    return menuSeg;
  }

  void AddToPath(MenuPath? path, MenuContentBase item){

    SubMenu? parentSeg = FindSubMenu(path);
    var itemList = parentSeg?.items??quickAccess;

    itemList.removeWhere((e) => e.name == item.name);
    itemList.add(item);
  }

  _SplitPath(MenuPath path){
    MenuPath? mainPath, itemSeg;

    MenuPath? currSeg = path;
    while(true){
      if(currSeg!.next == null){
        itemSeg = MenuPath.copySeg(currSeg);
        break;
      }else{
        if(mainPath == null){
          mainPath = MenuPath.copySeg(currSeg);
        }else{
          mainPath.Next(currSeg.name, currSeg.ico);
        }
      }
      currSeg = currSeg.next;
    }

    return[mainPath, itemSeg];
  }

  void RegisterAction(MenuPath path, void Function() action){
    var split = _SplitPath(path);
    var mp = split.first;
    var ip = split.last;
    var mi = MenuAction(name: ip.name, ico:ip.ico, action: action);
    AddToPath(mp, mi);
  }

  void RegisterPage(MenuPath path, Widget Function(BuildContext, MenuContext) builder){
    var split = _SplitPath(path);
    var mp = split.first;
    var ip = split.last;
    var mi = CustomMenuPage(name: ip.name, ico:ip.ico, builder: builder);
    AddToPath(mp, mi);
  }

}


class MenuBar extends ControlledWidget<MenuBar> {

  MenuBar({
    Key? key,
    required MenuBarManager manager,
  }) : super(key: key, controller: manager);

  @override MenuBarManager get controller => super.controller as MenuBarManager;

  @override
  _MenuBarState createState() => _MenuBarState();
}

class _MenuBarState extends ControlledWidgetState<MenuBar> {

  MenuBarManager get manager => widget.controller;

  Iterable<Widget> _BuildQuickAccess()sync*{
    for(var c in manager.quickAccess){
      yield MenuButton(c, (ctx, showFn){
        return TextButton(
            child: Text(c.name.toUpperCase()),
            onPressed: showFn,
        );
      }, PopupDirection.bottom);
    }
  }

  Widget _BuildMenu(){
    return MenuButton(manager.root, (ctx, showFn){
      return SizedBox(
        width: 30, height: 30,
        child: TextButton(
            child: Icon(Icons.settings_outlined),
            onPressed: showFn
        ),
      );
    }, PopupDirection.bottom);
  }

  @override
  Widget build(BuildContext context) {

    return BuildDefaultWindowContent(Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for(var q in _BuildQuickAccess()) q,
        SizedBox(width: 10,),
        _BuildMenu(),
      ],
    ));
  }
}
