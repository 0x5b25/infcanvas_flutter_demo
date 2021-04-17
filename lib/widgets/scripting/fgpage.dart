import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:infcanvas/utilities/scripting/graph_compiler.dart';
import 'package:infcanvas/widgets/functional/anchor_stack.dart';
import 'package:infcanvas/widgets/scripting/method_inspector.dart';

import '../functional/floating.dart';

import '../../utilities/scripting/graphnodes.dart';
import '../../utilities/scripting/script_graph.dart';

Map<String, Color> _typeColors = {
  "":Colors.yellow,
  "Num|Int":Colors.green[400]!,
  "Num|Float":Colors.orange,
};

Color GetColorForType(String type){
  var color = _typeColors[type];
  return color??Colors.cyan;
}

Map<Type, IconData> _slotLinkedIcon = {

  ValueInSlotInfo: Icons.radio_button_on,
  ValueOutSlotInfo:Icons.radio_button_on,
  ExecInSlotInfo:  Icons.label,
  ExecOutSlotInfo: Icons.label,

};


Map<Type, IconData> _slotEmptyIcon = {
  ValueInSlotInfo: Icons.radio_button_off,
  ValueOutSlotInfo:Icons.radio_button_off,
  ExecInSlotInfo:  Icons.label_outline,
  ExecOutSlotInfo: Icons.label_outline,
};

IconData GetIconForSlot(SlotInfo slot){
  var lut = _slotEmptyIcon;
  if(slot.IsLinked())
    lut = _slotLinkedIcon;
  var ico = lut[slot.runtimeType];
  return ico??Icons.adb;
}

Color GetColorForSlot(SlotInfo slot){
  return GetColorForType(slot.type);
}

class NodeStatus{
  int stat = 0;
  String msg = "";

  NodeStatus(){}

  NodeStatus.error(this.msg)
  :stat = 2{}

  
  NodeStatus.warning(this.msg)
  :stat = 1{}

}

abstract class CodeData{


  List<NodeHolder> GetNodes();
  void RemoveNode(NodeHolder n);
  void AddNode(NodeHolder n);


  Iterable<NodeSearchInfo> FindMatchingNode(String? argType, String? retType);
  bool IsSubTypeOf(String type, String base);

  NodeStatus ValidateNode(GraphNode node);

  //TODO: reconstruct graph from saved datagg
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

  CodeData data;

  CodePage(this.data);

  @override
  _CodePageState createState() => _CodePageState();
}

class NodeHolder{
  GraphNode info;
  Key key = GlobalKey();
  DFWController ctrl = DFWController()
    ..dx = 50
    ..dy = 50
    ..layoutBehavior=null
    ;
  NodeHolder(this.info);
}

class HandleNode extends GraphNode with GNPainterMixin{
  DFWController ctrl = DFWController();
  late SlotInfo slot;
  late bool isInput;
  HandleNode(SlotInfo rear){
    slot = rear.GenerateLink(this, "temp");
    isInput = slot is InSlotInfo;
  }

  @override
  NodeTranslationUnit doCreateTC() {
    assert(false);
    throw UnimplementedError();
  }

  @override
  GraphNode Clone() {
    throw UnimplementedError();
  }

  @override
  // The property shouldn't be read for handles
  bool get needsExplicitExec => throw UnimplementedError();
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

    nsPopup = null;
    for(var h in linkHandleMaps){
      h.slot.DisconnectFromRear();
    }
    linkHandleMaps.clear();

    _sanitizeNodes();

  }

  //Check for and mark all errors
  void _sanitizeNodes(){
    for(var n in widget.data.GetNodes()){
      widget.data.ValidateNode(n.info);
    }
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
              null);
          },
          onPanUpdate: (d){_moveNodes(d);},
        )
      )
    );

    for(var info in widget.data.GetNodes())
      nodes.add(PNode(info));
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
      _DrawNodeLinks(n.info, ro, origin, ctx);
    }
    for(var h in s.linkHandleMaps){
      if(h.isInput)
        _DrawInputSlot(h.slot as InSlotInfo, ro, origin, ctx);
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
      else{
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

  HandleNode DoAddLink(OutSlotInfo? from, InSlotInfo? to){
    assert((from != null) != (to!=null));
    HandleNode? hndl;
    if(from == null){
      hndl = HandleNode(to!);
      from = hndl.slot as OutSlotInfo;
    }else{
      hndl = HandleNode(from);
      to = hndl.slot as InSlotInfo;
    }
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
  void ConvertHandleNode(HandleNode nif) {
    assert(mounted);
    //Do a search
    bool contains = linkHandleMaps.remove(nif);
    if(!contains) return;
    //Must have either input or output
    //assert(nif.slot != null);

    //Find drop postion
    var localPos = Offset(nif.ctrl.dx??0, nif.ctrl.dy??0);
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

    if(nif.isInput){
      //This is a "To" handle
      //Available drop points are "input slots"
      var it = _getDragTargets<_InputSlotState>(result.path);
      if(it.isNotEmpty){
        var slot = it.first.widget.info;
        if(slot.runtimeType == nif.slot.runtimeType){
          bool compat = widget.data.IsSubTypeOf(nif.slot.type, slot.type);
          //Output type must be input type's sub class
          //if(slot is OutSlotInfo){
          //  compat = lib.reg.IsSubTypeOf(slot.type, nif.slot.type);
          //}else{
          //  compat = lib.reg.IsSubTypeOf(nif.slot.type, slot.type);
          //}
          if(compat){
            setState(() {
              slot.ConcatSlot(nif.slot); 
            });
            return;
          }
        }
      }

      ShowNodeSelPopup(nif.ctrl, nif.slot);
    }else{
      //"From" handle
      //Available drop points are "output slots"
      var it = _getDragTargets<_OutputSlotState>(result.path);
      if(it.isNotEmpty){
        var slot = it.first.widget.info;
        if(slot.runtimeType == nif.slot.runtimeType){
          bool compat = widget.data.IsSubTypeOf(slot.type, nif.slot.type);
          //Output type must be input type's sub class
          //if(slot is OutSlotInfo){
          //  compat = lib.reg.IsSubTypeOf(slot.type, nif.slot.type);
          //}else{
          //  compat = lib.reg.IsSubTypeOf(nif.slot.type, slot.type);
          //}
          if(compat){
            setState(() {
              slot.ConcatSlot(nif.slot); 
            });
            return;
          }
        }
      }
      ShowNodeSelPopup(nif.ctrl, nif.slot);        

    }
   
      
    
  }

  void CloseNodeSelPopup(){
    if(nsPopup == null) return;
    setState(() {
      (nsPopup as NodeSelPopup).slot?.Disconnect();
      nsPopup = null;
    });
  }

  
  Iterable<NodeSearchInfo> _QueryAvailableFn(SlotInfo? slot)sync*{

    if(slot == null){
      yield* widget.data.FindMatchingNode(null, null);
    }

    if(slot is InSlotInfo){
      yield* widget.data.FindMatchingNode(slot.type, null);
    }

    if(slot is OutSlotInfo){
      yield* widget.data.FindMatchingNode(null, slot.type);
    }

  }


  void ShowNodeSelPopup(DFWController pos, SlotInfo? nif){
    setState(() {
      nsPopup = NodeSelPopup(pos, nif, _QueryAvailableFn(nif),
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

  void RemoveNode(NodeHolder inf) {
    assert(mounted);
    setState(() {
      widget.data.RemoveNode(inf);
      inf.info.RemoveLinks();
    });
  }
  
  void NewNode(NodeHolder inf){
    assert(mounted);
    setState(() {
      widget.data.AddNode(inf);
    });
  }
      
}

class NodeSelPopup extends StatelessWidget{

  final SlotInfo? slot;
  final DFWController ctrl;
  void Function(NodeHolder) onSelect;

  late Iterable<NodeSearchInfo> availNodes;

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
                          Expanded(child: Text(fn.node.displayName)),
                          Text(fn.cat),
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

  NodeHolder InstantiateNode(NodeSearchInfo info){
    NodeHolder nif = NodeHolder(info.node.Clone());

    nif.ctrl = ctrl..layoutBehavior = null;


    if(slot == null) return nif;

    slot!.node = nif.info;

    if(slot is OutSlotInfo){
      var tgtSlot = nif.info.outSlot[info.position];
      tgtSlot.ConcatSlot(slot!);
      
      //slot!.name = nif.info.outSlot[info.position].name;
      //slot!.type = nif.info.outSlot[info.position].type;
      //nif.info.outSlot[info.position] = slot as OutSlotInfo;
      return nif;
    }
    
    if(slot is InSlotInfo){
      //slot!.name = nif.info.inSlot[info.position].name;
      //slot!.type = nif.info.inSlot[info.position].type;
      var tgtSlot = nif.info.inSlot[info.position];
      tgtSlot.ConcatSlot(slot!);
      return nif;
      
    }

    return nif;
  }

  void DoNodeSelection(NodeSearchInfo info){
    var inst = InstantiateNode(info);
    onSelect(inst);
  }

}


class PNode extends StatefulWidget {

  //String aVeryLongName;
  //DFWController ctrl;

  NodeHolder inf;

  PNode(this.inf):super(key: inf.key);

  @override
  _PNodeState createState() => _PNodeState();
}

class _PNodeState extends State<PNode> {

  void UpdateNode(){
    setState(() {
      
    });
  }

  Widget _BuildNodeContent(BuildContext ctx){
    var n = widget.inf.info;
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
    var closable = true;
    if(widget.inf.info is GNPainterMixin) 
      closable = (widget.inf.info as GNPainterMixin).closable;
    return DraggableFloatingWindow(
      ctrl: widget.inf.ctrl,
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
                  child: Text(widget.inf.info.displayName)
                ),
                if(closable)
                  Container(
                    width: 30, height: 30,
                    child: TextButton(
                      onPressed:(){
                        var cps = context.findRootAncestorStateOfType<_CodePageState>();
                        cps?.RemoveNode(widget.inf);
                      }, 
                      child: Icon(Icons.close)
                    ),
                  )
              ],),
            ),
          ),
        
          _BuildNodeContent(context),
          
        ]
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
  HandleNode GetLinkHandle(){
    return cps!.DoAddLink(null, widget.info as InSlotInfo);
  }

  @override
  Widget CreateContent(){
    return Row(
        children: [
          Listener(
            onPointerDown: OnPointerDown,
            child: GeometryTracker(
              handle:widget.info.gHandle,
              child:Padding(
                padding: EdgeInsets.all(3),
                child: Icon(
                  GetIconForSlot(widget.info),
                  size: 14,
                  color: GetColorForSlot(widget.info),
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
      //required this.child
    }
  ):super(key: key, info: info);

  @override
  _OutputSlotState createState() => _OutputSlotState();
}

class _OutputSlotState extends _SlotBaseState<OutputSlot> {


  @override
  HandleNode GetLinkHandle(){
    return cps!.DoAddLink(widget.info as OutSlotInfo, null);
  }

  @override
  Widget CreateContent(){
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
                  GetIconForSlot(widget.info),
                  size: 14,
                  color: GetColorForSlot(widget.info),
                ),
              ),

            ),
          )
        ],
      );
  }

}


abstract class SlotBase extends StatefulWidget{

  final SlotInfo info;

  SlotBase({Key? key, required this.info}):super(key: key);
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

  HandleNode GetLinkHandle();

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

          l.ctrl.dx = localPos.dx;
          l.ctrl.dy = localPos.dy;

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
