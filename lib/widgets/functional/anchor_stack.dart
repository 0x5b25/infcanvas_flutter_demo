import 'dart:ui';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';

class LayoutParams{
  late Rect trackingGeom;
  late Rect anchorGeom;
  late Rect constraintGeom;
  late Size widgetSize;
  late Offset alignPos;
  late Size stackSize;
}

typedef Offset PositioningFn(LayoutParams params, Offset calculatedPos);
typedef BoxConstraints SizingFn(LayoutParams params);
typedef void PaintFn(AnchorStackRO thisRO, PaintingContext context, Offset offset);

class GeometryTrackHandle{

  Size size = Size.zero;

  Offset? Function(RenderBox?)? _req;
  Size Function()? _reqSize;
  Rect? RequestGeometry({RenderBox? relativeTo}) { 
    var pos = _req?.call(relativeTo);
    if(pos == null) return null;
    return pos & size;
  }

  Offset? RequestPosition({RenderBox? relativeTo}) {
    return _req?.call(relativeTo);
  }

}


class GeometryTracker extends SingleChildRenderObjectWidget{

  final GeometryTrackHandle handle;

  GeometryTracker({
    Key? key,
    required this.handle,
    required Widget child,
  }):super(key: key, child: child);

  @override
  RenderObject createRenderObject(BuildContext context) {
    return GeometryTrackerRO(handle);
  }

  @override
  void updateRenderObject(BuildContext context, GeometryTrackerRO ro){
    ro._SwapHandle(handle);
  }

}


class GeometryTrackerRO extends RenderProxyBox{

  GeometryTrackHandle _h;
  GeometryTrackerRO(this._h){_RegHandle();}

  void _RegHandle(){
    _h._req = (ancestor){
      if(!attached) return null;
      return localToGlobal(Offset.zero, ancestor: ancestor);
    };
  }

  void _SwapHandle(GeometryTrackHandle newHandle){
    newHandle.size = _h.size;

    _h._req = null;
    _h = newHandle;
    _RegHandle();
  }

  //@override
  //void paint(PaintingContext ctx, Offset o)
  //{
  //  super.paint(ctx, o);
  //}
  //
  @override
  //void layout(Constraints constraints, { bool parentUsesSize = false })
  void layout(Constraints c, {bool parentUsesSize = false}){
    super.layout(c, parentUsesSize:true);
    _h.size = size;
  }
  
  //@override
  //void performLayout(){
  //  super.performLayout();
  //}

}


class AnchorStack extends MultiChildRenderObjectWidget{

  StackFit fit;
  Clip clipBehavior;
  PaintFn? bgPainter, fgPainter;

  AnchorStack({
    Key? key,
    this.fit = StackFit.loose,
    this.clipBehavior = Clip.hardEdge,
    this.bgPainter,
    this.fgPainter,
    List<Widget> children = const []
  })
    :super(key:key, children: children){

  }


  @override
  AnchorStackRO createRenderObject(BuildContext context) {
    return AnchorStackRO(
      clipBehavior: clipBehavior
    )
    ..bgPainter = bgPainter
    ..fgPainter = fgPainter
    ;
  }

  @override
  void updateRenderObject(
    BuildContext context, AnchorStackRO object){
    object
      ..clipBehavior = clipBehavior
      ..bgPainter = bgPainter
      ..fgPainter=fgPainter
      ;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(EnumProperty<StackFit>('fit', fit));
    properties.add(EnumProperty<Clip>('clipBehavior', clipBehavior, defaultValue: Clip.hardEdge));
  }
}


class AnchoredPosition extends ParentDataWidget<ASParentData>{

  double? top, right, bottom, left;
  Rect anchor;

  double? width, height;

  double alignX, alignY;

  GeometryTrackHandle? tracking;

  PositioningFn? onPositioning;
  SizingFn? onSizing;

  AnchoredPosition({
    Key? key,
    this.top,
    this.right,
    this.bottom,
    this.left,
    this.width,
    this.height,
    this.anchor = const Rect.fromLTRB(0,0,0,0),
    this.alignX = 0,
    this.alignY = 0,
    this.tracking,
    this.onPositioning,
    this.onSizing,
    required Widget child
  })
  :super(key:key, child:child){

  }

  AnchoredPosition.fill({Key? key, required Widget child})
    :left = 0,top = 0, right = 0, bottom = 0,
    anchor = const Rect.fromLTRB(0, 0, 1, 1),
    alignX = 0, alignY = 0,
    super(key: key, child: child)
  {}

  AnchoredPosition.fixedSize({
    Key? key,
    this.top,
    this.left,
    this.bottom,
    this.right,
    this.width,
    this.height,
    this.tracking,
    double anchorX = 0,
    double anchorY = 0,
    this.alignX = 0,
    this.alignY = 0,
    this.onPositioning,
    this.onSizing,
    required Widget child
  }):
    anchor = Rect.fromLTWH(anchorX, anchorY, 0, 0),
    super(key:key, child:child)
  {
    //Can't set height and top/bottom simutaneously
    //assert((top!=null && bottom!= null)!=(height!=null));
    //assert((left!=null && right!= null)!=(width!=null));
  }

  @override
  void applyParentData(RenderObject renderObject) {
    assert(renderObject.parentData is ASParentData);
    final ASParentData parentData = renderObject.parentData! as ASParentData;
    bool needsLayout = false;

    if (parentData.left != left) {
      parentData.left = left;
      needsLayout = true;
    }

    if (parentData.top != top) {
      parentData.top = top;
      needsLayout = true;
    }

    if (parentData.right != right) {
      parentData.right = right;
      needsLayout = true;
    }

    if (parentData.bottom != bottom) {
      parentData.bottom = bottom;
      needsLayout = true;
    }

    if (parentData.anchor != anchor) {
      parentData.anchor = anchor;
      needsLayout = true;
    }

    if(parentData.trackingHandle != tracking){
      parentData.trackingHandle = tracking;
      needsLayout = true;
    }

    if(parentData.onPositioning != onPositioning && onPositioning != null){
      parentData.onPositioning = onPositioning;
      needsLayout = true;
    }

    if(parentData.onSizing != onSizing && onSizing != null){
      parentData.onSizing = onSizing;
      needsLayout = true;
    }

    if(parentData.alignX != alignX){
      parentData.alignX = alignX;
      needsLayout = true;
    }

    if(parentData.alignY != alignY){
      parentData.alignY = alignY;
      needsLayout = true;
    }

    if(parentData.width != width){
      parentData.width = width;
      needsLayout = true;
    }

    if(parentData.height != height){
      parentData.height = height;
      needsLayout = true;
    }

    if (needsLayout) {
      final AbstractNode? targetParent = renderObject.parent;
      if (targetParent is RenderObject)
        targetParent.markNeedsLayout();
    }
  }

  @override
  Type get debugTypicalAncestorWidgetClass => AnchorStack;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(DoubleProperty('left', left, defaultValue: null));
    properties.add(DoubleProperty('top', top, defaultValue: null));
    properties.add(DoubleProperty('right', right, defaultValue: null));
    properties.add(DoubleProperty('bottom', bottom, defaultValue: null));
    properties.add(DoubleProperty('anchor_l', anchor.left, defaultValue: null));
    properties.add(DoubleProperty('anchor_t', anchor.top, defaultValue: null));
    properties.add(DoubleProperty('anchor_r', anchor.right, defaultValue: null));
    properties.add(DoubleProperty('anchor_b', anchor.bottom, defaultValue: null));
  }
}

class ASParentData extends ContainerBoxParentData<RenderBox>{
  double? top, right, bottom, left;
  Rect anchor = const Rect.fromLTRB(0,0,0,0);
  GeometryTrackHandle? trackingHandle;

  //Returns new layout geometry.
  PositioningFn? onPositioning;
  SizingFn? onSizing;


  double? width, height;
  //Alignment for non constrainted axis(e.g. left = right = null)
  double alignX = 0, alignY = 0;


}


class AnchorStackRO extends RenderBox
    with ContainerRenderObjectMixin<RenderBox, ASParentData>,
         RenderBoxContainerDefaultsMixin<RenderBox, ASParentData>{

  PaintFn? bgPainter, fgPainter;

  AnchorStackRO({
    List<RenderBox>? children,
    Clip clipBehavior = Clip.hardEdge,
  }) : 
       assert(clipBehavior != null),
       _clipBehavior = clipBehavior {
    addAll(children);
  }

  bool _hasVisualOverflow = false;

  //static Offset DefaultPositioning(
  //  LayoutParams params, Offset calcPos
  //){
  //  var cl = tgtGeom.left;
  //  var ct = tgtGeom.top;
  //  var cr = tgtGeom.right;
  //  var cb = tgtGeom.bottom;
  //  double x = 0;
  //    if (cl.isFinite) {
  //      x = cl;
  //    } else if (cr.isFinite) {
  //      x = cr - widLayoutSize.width;
  //    }else{
  //      x = alignPos.dx - widLayoutSize.width * align.dx;
  //    }
  //
  //    
  //
  //    double y = 0;
  //    if (ct.isFinite) {
  //      y = ct;
  //    } else if (cb.isFinite) {
  //      y = cb - widLayoutSize.height;
  //    }else{
  //      y = alignPos.dy - widLayoutSize.height * align.dy;
  //    }
//
  //    return Offset(x,y);
  //}
  /*
  static BoxConstraints DefaultSizing(Rect anchorGeom,Rect widPos, Size widSize, Size psize){
    //Force child size
    var childConstraints = BoxConstraints();
    if(widSize.width.isFinite)
      childConstraints = childConstraints.tighten(width:widSize.width);
    if(widSize.height.isFinite)
      childConstraints = childConstraints.tighten(height:widSize.height);
    return childConstraints;
  }*/


  @override
  void setupParentData(RenderBox child) {
    if (!(child.parentData is ASParentData))
      child.parentData = ASParentData();

    var cpd = child.parentData as ASParentData;    
  }

  /// How to size the non-positioned children in the stack.
  ///
  /// The constraints passed into the [RenderStack] from its parent are either
  /// loosened ([StackFit.loose]) or tightened to their biggest size
  /// ([StackFit.expand]).
  //StackFit get fit => _fit;
  //StackFit _fit;
  //set fit(StackFit value) {
  //  assert(value != null);
  //  if (_fit != value) {
  //    _fit = value;
  //    markNeedsLayout();
  //  }
  //}

  /// {@macro flutter.material.Material.clipBehavior}
  ///
  /// Defaults to [Clip.hardEdge], and must not be null.
  Clip get clipBehavior => _clipBehavior;
  Clip _clipBehavior = Clip.hardEdge;
  set clipBehavior(Clip value) {
    assert(value != null);
    if (value != _clipBehavior) {
      _clipBehavior = value;
      markNeedsPaint();
      markNeedsSemanticsUpdate();
    }
  }


  /// Helper function for calculating the intrinsics metrics of a Stack.
  static double getIntrinsicDimension(RenderBox? firstChild, double mainChildSizeGetter(RenderBox child)) {
    double extent = 0.0;
    RenderBox? child = firstChild;
    while (child != null) {
      final ASParentData childParentData = child.parentData! as ASParentData;
      //There might have a problem...
      //if (!childParentData.isPositioned)
        extent = max(extent, mainChildSizeGetter(child));
      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }
    return extent;
  }

  @override
  double computeMinIntrinsicWidth(double height) {
    return getIntrinsicDimension(firstChild, (RenderBox child) => child.getMinIntrinsicWidth(height));
  }

  @override
  double computeMaxIntrinsicWidth(double height) {
    return getIntrinsicDimension(firstChild, (RenderBox child) => child.getMaxIntrinsicWidth(height));
  }

  @override
  double computeMinIntrinsicHeight(double width) {
    return getIntrinsicDimension(firstChild, (RenderBox child) => child.getMinIntrinsicHeight(width));
  }

  @override
  double computeMaxIntrinsicHeight(double width) {
    return getIntrinsicDimension(firstChild, (RenderBox child) => child.getMaxIntrinsicHeight(width));
  }

  @override
  double? computeDistanceToActualBaseline(TextBaseline baseline) {
    return defaultComputeDistanceToHighestActualBaseline(baseline);
  }

  
  @override
  Size computeDryLayout(BoxConstraints constraints) {
    return _computeSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.dryLayoutChild,
    );
  }

  Size _computeSize({required BoxConstraints constraints, required ChildLayouter layoutChild}) {
    return constraints.biggest;
    /*
    if (childCount == 0) {
      assert(constraints.biggest.isFinite);
      return constraints.biggest;
    }

    double width = constraints.minWidth;
    double height = constraints.minHeight;

    final BoxConstraints nonPositionedConstraints;
    assert(fit != null);
    switch (fit) {
      case StackFit.loose:
        nonPositionedConstraints = constraints.loosen();
        break;
      case StackFit.expand:
        nonPositionedConstraints = BoxConstraints.tight(constraints.biggest);
        break;
      case StackFit.passthrough:
        nonPositionedConstraints = constraints;
        break;
    }
    assert(nonPositionedConstraints != null);

    RenderBox? child = firstChild;
    while (child != null) {
      final ASParentData childParentData = child.parentData! as ASParentData;

      if (!childParentData.isPositioned) {
        hasNonPositionedChildren = true;

        final Size childSize = layoutChild(child, nonPositionedConstraints);

        width = max(width, childSize.width);
        height = max(height, childSize.height);
      }

      child = childParentData.nextSibling;
    }

    final Size size;
    if (hasNonPositionedChildren) {
      size = Size(width, height);
      assert(size.width == constraints.constrainWidth(width));
      assert(size.height == constraints.constrainHeight(height));
    } else {
      size = constraints.biggest;
    }

    assert(size.isFinite);
    return size;*/
  }


  
  /// Lays out the positioned `child` according to `alignment` within a Stack of `size`.
  ///
  /// Returns true when the child has visual overflow.
  bool layoutPositionedChild(RenderBox child, ASParentData childParentData, Size size) {
    assert(child.parentData == childParentData);

    bool tracking = false;
    Rect bnd = Offset.zero & size;
    if(childParentData.trackingHandle != null){
      //This widget tracks another widget
      tracking = true;
      var tbnd = childParentData.trackingHandle!.RequestGeometry(relativeTo:this);
      if(tbnd == null){
        child.layout(BoxConstraints.tight(Size.zero), parentUsesSize: false);
        childParentData.offset = Offset.zero;
        return false;
      }
      else{
        bnd = tbnd;
      }
    }

    //Calculate anchors
    var w = bnd.width;
    var h = bnd.height;
    var al = childParentData.anchor.left * w + bnd.left;
    var ar = childParentData.anchor.right * w + bnd.left;
    var at = childParentData.anchor.top * h + bnd.top;
    var ab = childParentData.anchor.bottom * h + bnd.top;

    var aw = ar - al;
    var ah = ab - at;

    //Calc alignment reference points
    var ax = al + aw * childParentData.alignX;
    var ay = at + ah * childParentData.alignY;

    bool hasVisualOverflow = false;
    BoxConstraints childConstraints = BoxConstraints();
    double cl = double.negativeInfinity;
    double ct = double.negativeInfinity;
    double cr = double.infinity;
    double cb = double.infinity;

    if (childParentData.left   != null)
      cl = al + childParentData.left!;
    if (childParentData.right  != null)
      cr = ar + childParentData.right!;
    if (childParentData.top    != null)
      ct = at + childParentData.top!;
    if (childParentData.bottom != null)
      cb = ab + childParentData.bottom!;

    //Try to calc unknown coords from given w/h
    double cw = cr - cl, ch = cb - ct;
    if(cw.isInfinite && childParentData.width != null){
      cw = childParentData.width!;
      if(cl.isFinite){cr = cl + cw;}
      else if(cr.isFinite){cl = cr - cw;}
      else{
        //Needs alignment to position child
        cl = ax - cw * childParentData.alignX;
        cr = ax + cw * (1-childParentData.alignX);
      }
    }

    if(ch.isInfinite && childParentData.height != null){
      ch = childParentData.height!;
      childConstraints = childConstraints.tighten(height:ch);
      if(ct.isFinite){cb = ct + ch;}
      else if(cb.isFinite){ct = cb - ch;}
      else{
        //Needs alignment to position child
        ct = ay - ch * childParentData.alignY;
        cr = ay + ch * (1-childParentData.alignY);
      }
    }

    if(cw.isFinite) childConstraints = childConstraints.tighten(width:cw);
    if(ch.isFinite) childConstraints = childConstraints.tighten(height:ch);
        
    LayoutParams lps = LayoutParams()
      ..anchorGeom = Rect.fromLTRB(al, at, ar, ab)
      ..constraintGeom = Rect.fromLTRB(cl, ct, cr, cb)
      ..alignPos = Offset(cw * childParentData.alignX,ch * childParentData.alignY)
      ..trackingGeom = bnd
      ..widgetSize = Size(cw, ch)
      ..stackSize = size
    ;
    
    if(childParentData.onSizing!= null)
    {
      childConstraints = childParentData.onSizing!(lps);
    }
    //else{

    //}
    //childConstraints = BoxConstraints.tight(childRect.size);
    
    child.layout(childConstraints, parentUsesSize: true);

    Offset childPos =  Offset.zero;

    

    double x = 0;
    if (cl.isFinite) {
      x = cl;
    } else if (cr.isFinite) {
      x = cr - child.size.width;
    }else{
      x = ax - child.size.width * childParentData.alignX;
    }

    

    double y = 0;
    if (ct.isFinite) {
      y = ct;
    } else if (cb.isFinite) {
      y = cb - child.size.height;
    }else{
      y = ay - child.size.height * childParentData.alignY;
    }

    if(childParentData.onPositioning != null){
      lps.widgetSize = child.size;
      childPos = childParentData.onPositioning!.call(
        lps, Offset(x, y)
      );
    }else{
      childPos =  Offset(x,y);
    }

    
    if (childPos.dx < 0.0 || childPos.dx + child.size.width > size.width)
      hasVisualOverflow = true;
    if (childPos.dy < 0.0 || childPos.dy + child.size.height > size.height)
      hasVisualOverflow = true;

    


    childParentData.offset = childPos;

    return hasVisualOverflow;
  }

  @override
  void performLayout() {
    final BoxConstraints constraints = this.constraints;
    _hasVisualOverflow = false;

    //Also layout all non-positioned children.
    size = _computeSize(
      constraints: constraints,
      layoutChild: ChildLayoutHelper.layoutChild,
    );

    RenderBox? child = firstChild;
    while (child != null) {
      final ASParentData childParentData = child.parentData! as ASParentData;

      //if (!childParentData.isPositioned) {
      //  childParentData.offset = Offset.zero;
      //} else {
        _hasVisualOverflow = layoutPositionedChild(child, childParentData, size) || _hasVisualOverflow;
      //}

      assert(child.parentData == childParentData);
      child = childParentData.nextSibling;
    }
  }

  @override
  bool hitTestChildren(BoxHitTestResult result, { required Offset position }) {
    return defaultHitTestChildren(result, position: position);
  }

  /// Override in subclasses to customize how the stack paints.
  ///
  /// By default, the stack uses [defaultPaint]. This function is called by
  /// [paint] after potentially applying a clip to contain visual overflow.
  @protected
  void paintStack(PaintingContext context, Offset offset) {
    bgPainter?.call(this,context, offset);
    defaultPaint(context, offset);
    fgPainter?.call(this,context, offset);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    if (clipBehavior != Clip.none && _hasVisualOverflow) {
      _clipRectLayer = context.pushClipRect(needsCompositing, offset, Offset.zero & size, paintStack,
          clipBehavior: clipBehavior, oldLayer: _clipRectLayer);
    } else {
      _clipRectLayer = null;
      paintStack(context, offset);
    }
  }

  ClipRectLayer? _clipRectLayer;

  @override
  Rect? describeApproximatePaintClip(RenderObject child) => _hasVisualOverflow ? Offset.zero & size : null;

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    //properties.add(DiagnosticsProperty<AlignmentGeometry>('alignment', alignment));
    //properties.add(EnumProperty<TextDirection>('textDirection', textDirection));
    properties.add(EnumProperty<Clip>('clipBehavior', clipBehavior, defaultValue: Clip.hardEdge));
  }
}
