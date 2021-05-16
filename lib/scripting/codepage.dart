import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:infcanvas/scripting/graph_compiler.dart';
import 'package:infcanvas/widgets/functional/anchor_stack.dart';

import '../widgets/functional/floating.dart';
import 'script_graph.dart';

ISlotPainter? _getIPainter(slot) => slot is ISlotPainter?slot : null;

IconData _getIconConnected(slot) => _getIPainter(slot)?.iconConnected??
    Icons.radio_button_on;
IconData _getIconDisconnected(slot) => _getIPainter(slot)?.iconDisconnected??
    Icons.radio_button_off;
Color GetColorForSlot(SlotInfo slot) => _getIPainter(slot)?.iconColor??
    Colors.grey;
IconData GetIconForSlot(SlotInfo slot)
  =>slot.IsLinked()?
  _getIconConnected(slot):_getIconDisconnected(slot);



class NodeStatus{
  int stat = 0;
  String msg = "";

  NodeStatus(){}

  NodeStatus.error(this.msg)
  :stat = 2{}

  
  NodeStatus.warning(this.msg)
  :stat = 1{}

}


class GraphNodeQueryResult{
  final GraphNode node;
  final String category;
  final bool isInput;
  final int slotIdx;
  const GraphNodeQueryResult(
      this.node,
      this.category,
      [this.isInput = true,
      this.slotIdx = -1])
  ;
}


abstract class ICodeData{


  Iterable<DrawableNodeMixin> GetNodes();
  void RemoveNode(covariant DrawableNodeMixin n);
  void AddNode(covariant DrawableNodeMixin n);


  ///The code change all comes from handle dragging
  void OnCodeChange();

  Iterable<GraphNodeQueryResult> FindNodeWithConnectableSlot(SlotInfo? slot);
  //bool IsSubTypeOf(String type, String base);

  //Map<GraphNode, List<String>> nodeMessage = {};

  List<String> GetNodeMessage(GraphNode node);
  //{
  //  if(nodeMessage.isEmpty) return [];
  //  var msg = nodeMessage[node];
  //  if(msg == null) return [];
  //  return msg;
  //}

  //TODO: reconstruct graph from saved data
}

mixin GNPainterMixin on GraphNode
{
  bool get closable => true;

  Widget DrawInput(){
    return IntrinsicWidth(
          child: Column(
            children: [
              for(var i in inSlot)
                InputSlot(info: i)
            ],
          ),
        );
  }

  Widget DrawOutput(){
    return IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                for(var o in outSlot)
                  OutputSlot(info: o)
              ],
          ),
        );
  }

  Widget Draw(BuildContext context, void Function() update){
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DrawInput(),
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(
            minWidth: 30,
          ),
            child: Container(),
          ),
        ),
        DrawOutput(),
      ],
    );
  }
}

class CodePage extends StatefulWidget {

  ICodeData data;
  void Function()? onChange;
  CodePage(this.data, {this.onChange});

  @override
  _CodePageState createState() => _CodePageState();
}
//
// class NodeHolder{
//   GraphNode info;
//   Key key = GlobalKey();
//   DFWController ctrl = DFWController()
//     ..dx = 50
//     ..dy = 50
//     ..layoutBehavior=null
//     ;
//   NodeHolder(this.info);
// }

mixin DrawableNodeMixin on GraphNode{
  Key key = GlobalKey();
  DFWController ctrl = DFWController()
    ..dx = 50
    ..dy = 50
    ..layoutBehavior=null
  ;

  bool get closable => true;

  Widget DrawInput(){
    return IntrinsicWidth(
      child: Column(
        children: [
          for(var i in inSlot)
            InputSlot(info: i)
        ],
      ),
    );
  }

  Widget DrawOutput(){
    return IntrinsicWidth(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for(var o in outSlot)
            OutputSlot(info: o)
        ],
      ),
    );
  }

  void Function()? _repaintCallback;
  Widget Draw(BuildContext context, void Function() update){
    _repaintCallback = update;
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DrawInput(),
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: 30,
            ),
            child: Container(),
          ),
        ),
        DrawOutput(),
      ],
    );
  }

  void NotifyRepaint(){
    _repaintCallback?.call();
  }
}

class HandleNode extends GraphNode with GNPainterMixin{
  DFWController ctrl = DFWController();
  SlotInfo slot;
  SlotInfo rear;
  HandleNode(this.rear, this.slot){}

  @override doCreateTU() => throw UnimplementedError();
  @override Clone() => throw UnimplementedError();
  @override get needsExplicitExec => throw UnimplementedError();

  @override get displayName => "Drag Handle";
  @override get inSlot => [];
  @override get outSlot => [];
}

class _CodePageState extends State<CodePage> {

  //List<PNodeLinkInfo> codeLinks = [];
  //
  //List<NodeHolder> get codeNodes => widget.nodes;

  //List<CodeNodeInfo> linkHandles = [];
  Set<HandleNode> linkHandleMaps  = {};
  
  

  _CodePageState()
  {
    
  }

  Widget? nsPopup;

  @override
  void didUpdateWidget(CodePage oldWidget){
    super.didUpdateWidget(oldWidget);

    if(oldWidget.data == widget.data) return;
    //Only clear sites when the code data is different
    nsPopup = null;
    for(var h in linkHandleMaps){
      h.slot?.Disconnect();
    }
    linkHandleMaps.clear();

    _sanitizeNodes();

  }

  //Check for and mark all errors
  void _sanitizeNodes(){
  }

  void _moveNodes(DragUpdateDetails d){
    setState(() {
      for(var info in widget.data.GetNodes()){
        var ctrl = info.ctrl;
        if(ctrl.dx != null)
        {
          ctrl.dx = ctrl.dx! + d.delta.dx; 
        }
        if(ctrl.dy != null)
        {
          ctrl.dy = ctrl.dy! + d.delta.dy; 
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> nodes = [];

    nodes.add(
      AnchoredPosition.fill(
        child:GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (d){

            ShowNodeSelPopup(
              DFWController()
                ..dx = d.localPosition.dx
                ..dy = d.localPosition.dy
                ,
              null,null);
          },
          onPanUpdate: (d){_moveNodes(d);},
        )
      )
    );

    for(var node in widget.data.GetNodes()){
      GeometryTrackHandle hndl = GeometryTrackHandle();
      nodes.add(PNode(node, hndl));
      var message = widget.data.GetNodeMessage(node);
      if(message.isNotEmpty){
        nodes.add(AnchoredPosition(
          tracking: hndl,
          anchor: Rect.fromLTRB(0, 0, 1, 0),
          alignX: 0.5,
          alignY: 1,
          bottom: -10,
          child: Container(
            color: Colors.red,
            child: Column(
              children: [
                for(var s in message)
                  Text(s, style: TextStyle(color: Colors.white),),
              ],
            ),
          )
        ));
      }
    }
    for(var h in linkHandleMaps)
      nodes.add(PHandle(h));

    

    if(nsPopup!=null){
      nodes.add(AnchoredPosition.fill(
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) {
              CloseNodeSelPopup();
            },
          ),
      ));
      nodes.add(nsPopup!);
    }

    return Container(
      color: Colors.grey[800],
      child: AnchorStack(
        bgPainter:(r,c,o){DrawLinks(this,r,c,o);},
        children: nodes,
      )
    );
  }

  static void DrawLinks(_CodePageState s, AnchorStackRO ro, PaintingContext ctx, Offset origin){
    ctx.canvas.drawCircle(s.htPos, 5, Paint()..style = PaintingStyle.fill..color = Colors.blue);
    for(var r in s.htRes){
      ctx.canvas.drawRect(r, Paint()..style = PaintingStyle.stroke..color = Colors.green);
    }
    //only track inputs
    for(var n in s.widget.data.GetNodes()){
      _DrawNodeLinks(n, ro, origin, ctx);
    }
    for(var h in s.linkHandleMaps){
      var slot = h.slot;
      if(slot is InSlotInfo)
        _DrawInputSlot(slot, ro, origin, ctx);
    }

    if(s.nsPopup != null){
      var popup = s.nsPopup as NodeSelPopup;
      if(popup.slot is InSlotInfo){
        _DrawInputSlot(popup.slot as InSlotInfo, ro, origin, ctx);
      }
    }
  }

  static void _DrawNodeLinks(GraphNode n, AnchorStackRO ro, Offset origin, PaintingContext ctx) {
    for(var i in n.inSlot){
      _DrawInputSlot(i, ro, origin, ctx);
    }
  }

  static void _DrawInputSlot(InSlotInfo i, AnchorStackRO ro, Offset origin, PaintingContext ctx) {
    if(!i.IsLinked()) return;
      if(i is MultiConnSlotMixin){
        for(var l in (i as MultiConnSlotMixin).links)
          _DrawLinkLine(l, ro, origin, ctx);
      }
      else if(i is SingleConnSlotMixin){
        var l = (i as SingleConnSlotMixin).link!;
        _DrawLinkLine(l, ro, origin, ctx);
      }
  }

  static void _DrawLinkLine(GraphEdge i, AnchorStackRO ro, Offset origin, PaintingContext ctx) {
    var lnk = i;
    var begin = lnk.from.gHandle;
    var end = lnk.to.gHandle;
    var bG = begin.RequestGeometry(relativeTo: ro);
    var eG = end.RequestGeometry(relativeTo: ro);
    if(bG == null || eG == null) return;
    var lStart = bG.centerRight + origin;
    var lEnd = eG.centerLeft + origin;

    var startColor = GetColorForSlot(lnk.from);
    var endColor = GetColorForSlot(lnk.to);
    

    
    var lSeg1 = Offset(lStart.dx + 10, lStart.dy);
    var lSeg2 = Offset(lEnd.dx - 10, lEnd.dy);

    Path path = new Path();

    path.addPolygon([lStart, lSeg1, lSeg2, lEnd], false);

    var gradient = ui.Gradient.linear(lStart, lEnd, [startColor, endColor]);

    Paint paint = Paint()
      //..color = Colors.cyan
      ..shader = gradient
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeJoin = StrokeJoin.round
      
      ;

    ctx.canvas.drawPath(path, paint);
    //ctx.canvas.drawLine(lStart, lEnd, Paint());
  }

  HandleNode? DoCreateDragHandle(OutSlotInfo? from, InSlotInfo? to){
    assert((from != null) != (to!=null));
    HandleNode? hndl;
    if(from == null){
      var slot = to!.CreateCounterpart();
      if(slot == null) return null;
      hndl = HandleNode(to!, slot);
    }else{
      var slot = from!.CreateCounterpart();
      if(slot == null) return null;
      hndl = HandleNode(from!, slot);
    }
    widget.data.OnCodeChange();
    widget.onChange?.call();
    //codeLinks.add(link);
    linkHandleMaps.add(hndl);
    return hndl;
  }

  void NotifyUpdate() {
    assert(mounted);
    setState(() {});
  }

  Iterable<T> _getDragTargets<T>(
    Iterable<HitTestEntry> path
  ) sync* {
    // Look for the RenderBoxes that corresponds to the hit target (the hit target
    // widgets build RenderMetaData boxes for us for this purpose).
    for (final HitTestEntry entry in path) {
      final HitTestTarget target = entry.target;
      if (target is RenderMetaData) {
        final dynamic metaData = target.metaData;
        if (metaData is T)
          yield metaData;
      }
    }
  }

  Offset htPos = Offset.zero;
  List<Rect> htRes = [];

  void ConvertHandleNode(HandleNode hndl) {
    assert(mounted);
    //Do a search
    bool contains = linkHandleMaps.remove(hndl);
    if(!contains) return;
    //Must have either input or output
    //assert(nif.slot != null);

    //Find drop postion
    var localPos = Offset(hndl.ctrl.dx??0, hndl.ctrl.dy??0);
    var ro = context.findRenderObject() as RenderBox;
    var globalPos = ro.localToGlobal(localPos);
    final HitTestResult result = HitTestResult();
    htPos = globalPos;
    WidgetsBinding.instance!.hitTest(result, globalPos);

    //Debug paint hitboxes
    htRes.clear();
    for (final HitTestEntry entry in result.path) {
      final HitTestTarget target = entry.target;
      if (target is RenderBox) {
        var t = target as RenderBox;
        var geo = t.localToGlobal(Offset.zero) & t.size;
        htRes.add(geo);
      }
    }

    var it = _getDragTargets<_SlotBaseState>(result.path);
    if(it.isNotEmpty){
      var slot = it.first.widget.info;
      bool compat = slot.CanEstablishLink(hndl.rear);
      //Output type must be input type's sub class
      //if(slot is OutSlotInfo){
      //  compat = lib.reg.IsSubTypeOf(slot.type, nif.slot.type);
      //}else{
      //  compat = lib.reg.IsSubTypeOf(nif.slot.type, slot.type);
      //}
      if(compat){
        setState(() {
          slot.ConcatSlot(hndl.slot);
          widget.data.OnCodeChange();
        });
        return;
      }
    }

    ShowNodeSelPopup(hndl.ctrl, hndl.slot, hndl.rear);

    /*
    if(hndl.isInput){
      //This is a "To" handle
      //Available drop points are "input slots"
      var it = _getDragTargets<_InputSlotState>(result.path);
      if(it.isNotEmpty){
        var slot = it.first.widget.info;
        if(slot.runtimeType == hndl.slot.runtimeType){
          bool compat = widget.data.IsSubTypeOf(hndl.slot.type, slot.type);
          //Output type must be input type's sub class
          //if(slot is OutSlotInfo){
          //  compat = lib.reg.IsSubTypeOf(slot.type, nif.slot.type);
          //}else{
          //  compat = lib.reg.IsSubTypeOf(nif.slot.type, slot.type);
          //}
          if(compat){
            setState(() {
              slot.ConcatSlot(hndl.slot);
            });
            return;
          }
        }
      }

      ShowNodeSelPopup(hndl.ctrl, hndl.slot);
    }else{
      //"From" handle
      //Available drop points are "output slots"
      var it = _getDragTargets<_OutputSlotState>(result.path);
      if(it.isNotEmpty){
        var slot = it.first.widget.info;
        if(slot.runtimeType == hndl.slot.runtimeType){
          bool compat = widget.data.IsSubTypeOf(slot.type, hndl.slot.type);
          //Output type must be input type's sub class
          //if(slot is OutSlotInfo){
          //  compat = lib.reg.IsSubTypeOf(slot.type, nif.slot.type);
          //}else{
          //  compat = lib.reg.IsSubTypeOf(nif.slot.type, slot.type);
          //}
          if(compat){
            setState(() {
              slot.ConcatSlot(hndl.slot);
            });
            return;
          }
        }
      }
      ShowNodeSelPopup(hndl.ctrl, hndl.slot);

    }
   */
      
    
  }

  void CloseNodeSelPopup(){
    if(nsPopup == null) return;
    setState(() {
      (nsPopup as NodeSelPopup).slot?.Disconnect();
      nsPopup = null;
      widget.data.OnCodeChange();
    });
  }

  
  Iterable<GraphNodeQueryResult> _QueryAvailableFn(SlotInfo? slot){
    return widget.data.FindNodeWithConnectableSlot(slot);
  }


  void ShowNodeSelPopup(
    DFWController pos,
    SlotInfo? hndlSlot,
    SlotInfo? rear
  ){
    setState(() {
      nsPopup = NodeSelPopup(pos, hndlSlot, _QueryAvailableFn(rear),
      (nif) { 
        setState(() {
          widget.data.AddNode(nif);
          nsPopup = null;
        });
      });
    });
  }

  void RemoveHandleNode(HandleNode nif) {
    //Do a search
    bool contains = linkHandleMaps.remove(nif);
    if(!contains) return;
    setState(() {
      nif.slot.Disconnect();
    });
  }

  void RemoveNode(DrawableNodeMixin node) {
    assert(mounted);
    setState(() {
      //Handle things before triggering events
      node.RemoveLinks();
      widget.data.RemoveNode(node);
    });
  }
  
  void NewNode(DrawableNodeMixin node){
    assert(mounted);
    setState(() {
      widget.data.AddNode(node);
    });
  }
      
}

class NodeSelPopup extends StatelessWidget{

  final SlotInfo? slot;
  final DFWController ctrl;
  void Function(DrawableNodeMixin) onSelect;

  late Iterable<GraphNodeQueryResult> availNodes;

  NodeSelPopup(this.ctrl, this.slot, this.availNodes, this.onSelect){
    ctrl.layoutBehavior = PositioningBehavior.StopAtEdge;
  }

  @override
  Widget build(BuildContext context) {
    return DraggableFloatingWindow(
      ctrl: ctrl,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: 500,
          maxWidth: 210
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children:[
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 200,
              ),

              child: GeometryTracker(
                handle: slot?.gHandle??GeometryTrackHandle(),
                child: Row(children: [
                  Container(width: 30, height: 30, child: Icon(Icons.book)),
                  Expanded(
                    child: Text("New...")
                  ),
                  Container(
                    width: 30, height: 30,
                    child: TextButton(
                      onPressed:(){
                        var cps = context.findRootAncestorStateOfType<_CodePageState>();
                        cps?.CloseNodeSelPopup();
                      }, 
                      child: Icon(Icons.close)
                    ),
                  )
                ],),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for(var fn in availNodes)
                    GestureDetector(
                      onTap: (){DoNodeSelection(fn);},
                      child: Row(
                        children:[
                          Text(fn.node.displayName),
                          Expanded(
                            child: Text(fn.category,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                              style: TextStyle(fontStyle: FontStyle.italic),
                            )
                          ),
                        ]
                      )
                    ),
                ],
              ),
            )
            
          ]
        ),
      )
    );
  }

  DrawableNodeMixin InstantiateNode(GraphNodeQueryResult result){
    var nif = result.node.Clone() as DrawableNodeMixin;

    nif.ctrl = ctrl..layoutBehavior = null;

    if(slot == null) return nif;

    slot!.node = nif;
    var tgtSlot = result.isInput?
      nif.inSlot[result.slotIdx]:
      nif.outSlot[result.slotIdx];
    tgtSlot.ConcatSlot(slot!);
    return nif;


  }

  void DoNodeSelection(GraphNodeQueryResult info){
    var inst = InstantiateNode(info);
    onSelect(inst);
  }

}


class PNode extends StatefulWidget {

  //String aVeryLongName;
  //DFWController ctrl;

  DrawableNodeMixin drawableNode;
  GeometryTrackHandle ghandle;

  PNode(this.drawableNode, this.ghandle):super(key: drawableNode.key);

  @override
  _PNodeState createState() => _PNodeState();
}

class _PNodeState extends State<PNode> {

  void UpdateNode(){
    setState(() {
      
    });
  }

  Widget _BuildNodeContent(BuildContext ctx){
    var n = widget.drawableNode;
    if(n is GNPainterMixin){
      return n.Draw(ctx, UpdateNode);
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicWidth(
          child: Column(
            children: [
              for(var i in n.inSlot)
                InputSlot(info: i)
            ],
          ),
        ),
        Expanded(
          child: ConstrainedBox(
            constraints: BoxConstraints(
            minWidth: 30,
          ),
            child: Container(),
          ),
        ),
        IntrinsicWidth(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
                for(var o in n.outSlot)
                  OutputSlot(info: o)
              ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    var n = widget.drawableNode;
    var closable = n.closable;

    return DraggableFloatingWindow(
      ctrl: widget.drawableNode.ctrl,
    child: GeometryTracker(
      handle: widget.ghandle,
      child: IntrinsicWidth(
        stepWidth: 30,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children:[
            ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: 200
              ),
              
              child: FWMoveHandle(
                child: Row(children: [
                  Container(width: 30, height: 30, child: Icon(Icons.book)),
                  Expanded(
                    child: Text(widget.drawableNode.displayName)
                  ),
                  if(closable)
                    Container(
                      width: 30, height: 30,
                      child: TextButton(
                        onPressed:(){
                          var cps = context.findRootAncestorStateOfType<_CodePageState>();
                          cps?.RemoveNode(widget.drawableNode);
                        }, 
                        child: Icon(Icons.close)
                      ),
                    )
                ],),
              ),
            ),
          
            //_BuildNodeContent(context),
            n.Draw(context, UpdateNode),
          ]
        ),
      ),
    ),);
  }
}

class PHandle extends StatelessWidget{

  HandleNode info;

  PHandle(this.info){}

  @override
  Widget build(BuildContext ctx){
    var gth = info.slot.gHandle;
    return AnchoredPosition(
      top:info.ctrl.dy,
      left: info.ctrl.dx,
      child: GeometryTracker(
        handle: gth,
        child: IgnorePointer(
          child: Container(
            width: 10,
            height: 10,
            color: Colors.red,
          ),
        ),
      ),
    );
  }
}
    
//class LinkHandle extends Drag{
//  CodeNodeInfo nif;
//  _CodePageState cps;
//  
//  LinkHandle(this.nif, this.cps);
//    
//  @override
//  void update(DragUpdateDetails details) {
//    if(nif.ctrl.dx != null){
//      nif.ctrl.dx = nif.ctrl.dx! + details.delta.dx;
//    }
//    if(nif.ctrl.dy != null){
//      nif.ctrl.dy = nif.ctrl.dy! + details.delta.dy;
//    }
//
//    cps.NotifyUpdate();
//  }
//
//  
//  @override
//  void end(DragEndDetails details) {
//    _dragFinished();
//  }
//
//
//  @override
//  void cancel() {
//    _dragFinished();
//  }
//
//  void _dragFinished(){
//    cps.ConvertHandleNode(nif);
//  }
//
//}


class InputSlot extends SlotBase {

  //final Widget child;
  //final InSlotInfo info;

  InputSlot(
    {
      Key? key,
      required InSlotInfo info,
      //required this.child
    }
  ):super(key: key, info:info);


  @override
  _InputSlotState createState() => _InputSlotState();
}

class _InputSlotState extends _SlotBaseState<InputSlot> {

  @override
  HandleNode? GetLinkHandle(){
    return cps!.DoCreateDragHandle(null, widget.info as InSlotInfo);
  }

  @override
  Widget CreateContent(){
    var slot = widget.info;
    return Row(
        children: [
          Listener(
            onPointerDown: OnPointerDown,
            child: GeometryTracker(
              handle:widget.info.gHandle,
              child:Padding(
                padding: EdgeInsets.all(3),
                child: Icon(
                  GetIconForSlot(slot),
                  size: 14,
                  color: GetColorForSlot(slot),
                ),
              ),
            ),
          ),
          Text(widget.info.name),
        ],
      );
  }

}

class OutputSlot extends SlotBase{

  OutputSlot(
    {
      Key? key,
      required OutSlotInfo info,
    }
  ):super(key: key, info: info,);

  @override
  _OutputSlotState createState() => _OutputSlotState();
}

class _OutputSlotState extends _SlotBaseState<OutputSlot> {


  @override
  HandleNode? GetLinkHandle(){
    return cps!.DoCreateDragHandle(widget.info as OutSlotInfo, null);
  }


  @override
  Widget CreateContent(){
    var slot = widget.info;
    return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(widget.info.name),

          GeometryTracker(
            handle:widget.info.gHandle,
            child: Listener(
              onPointerDown: OnPointerDown,
              child:
              Padding(
                padding: EdgeInsets.all(3),
                child: Icon(
                  GetIconForSlot(slot),
                  size: 14,
                  color: GetColorForSlot(slot),
                ),
              ),

            ),
          )
        ],
      );
  }

}

abstract class ISlotPainter{
  IconData get iconConnected;
  IconData get iconDisconnected;
  Color get iconColor;
}

abstract class SlotBase extends StatefulWidget{

  final SlotInfo info;



  SlotBase({
    Key? key,
    required this.info,
  }):super(key: key);
}

abstract class _SlotBaseState<T extends SlotBase> extends State<T>{
  
  late PanGestureRecognizer _gestureRecognizer = _createGR();
  _CodePageState? cps;

  ///Must use the gHandle and onPointerDown callback
  Widget CreateContent();

  @override
  Widget build(BuildContext context) {
    cps = context.findAncestorStateOfType<_CodePageState>();
    return MetaData(
      metaData: this,
      behavior: HitTestBehavior.translucent,
      child: CreateContent(),
    );
  }

  //bool isPressed = false;
  HandleNode? handle;

  void OnPointerDown(PointerDownEvent e){
    
    _gestureRecognizer.addPointer(e);
  }

  HandleNode? GetLinkHandle();

  Offset? dragBeginPos;
  PanGestureRecognizer _createGR(){
    return PanGestureRecognizer()
      ..onStart = (d){
        dragBeginPos = d.globalPosition;
      }
      ..onUpdate = (d){
        if(cps == null) return;
        if(dragBeginPos != null){
          var delta = d.globalPosition - dragBeginPos!;
          var len2 = delta.distanceSquared;
          if(len2 < 100) return;
          //Reached our threshold
          //var l = cps!.DoAddLink(widget.info, null);
          var l = GetLinkHandle();
          var ro = cps!.context.findRenderObject()as RenderBox;
          var localPos = ro.globalToLocal(d.globalPosition);

          l?.ctrl.dx = localPos.dx;
          l?.ctrl.dy = localPos.dy;

          handle = l;
          
          dragBeginPos = null; return;
        }
        //Do the work
        if(handle == null) return;

        if(handle!.ctrl.dx != null){
          handle!.ctrl.dx = handle!.ctrl.dx! + d.delta.dx;
        }
        if(handle!.ctrl.dy != null){
          handle!.ctrl.dy = handle!.ctrl.dy! + d.delta.dy;
        }

        cps!.NotifyUpdate();

      }
      ..onEnd = (d){
        if(handle == null) return;
        cps?.ConvertHandleNode(handle!);
      }
      ..onCancel = (){
        if(handle == null) return;
        cps?.RemoveHandleNode(handle!);
      }
    ;
  }

}
