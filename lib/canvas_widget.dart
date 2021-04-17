import 'dart:ui' as ui;
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'util.dart';

class InfCanvasController{
  _InfCanvasWidgetState? _state;

  void _RegisterState(_InfCanvasWidgetState s){
    _state = s;
  }

  List<ui.PaintLayer> GetPaintLayers(){if(_state!=null)return _state!.instance.layers; return [];}
  ui.PaintLayer? GetActivePaintLayer(){if(_state!=null)return _state!.layer; return null;} 
  void SetActivePaintLayer(ui.PaintLayer? l){assert(_state!=null);_state!.layer = l;}
  void AddPaintLayer(){assert(_state!=null);_state!.instance.CreateNewPaintLayer();}
  void RemovePaintLayer(ui.PaintLayer l){
    assert(_state!=null);
    if(_state!.layer == l) _state!.layer = null; 
    l.Remove();
    NotifyUpdate();
  }

  void MoveLayer(int from, int to){
    assert(_state!=null);
    if(from == to) return;
    _state!.instance.layers[from].MoveTo(to);
    NotifyUpdate();
  }

  int get minHeight{if(_state!=null)return 1 - _state!.instance.height; return 0;}

  int get currentHeight{if(_state!=null)return _state!.p.height; return 0;}
  void set currentHeight(int val){if(_state!=null){_state!.p.height = max(val, minHeight); NotifyUpdate();}}

  void NotifyUpdate() {assert(_state!=null); _state!._UpdateSnapshot();}

}

class InfCanvasWidget extends StatefulWidget{

  InfCanvasController controller;

  InfCanvasWidget(this.controller);

  @override
  State<StatefulWidget> createState() {
    return _InfCanvasWidgetState(controller);
  }

}

class CanvasParams{
  Offset offset = Offset.zero;
  int height = 0;
}

class StrokePoint{
  Offset offset = Offset.zero;
  int height = 0;
}

class CanvasReq{
  Offset offset = Offset.zero;
  Size size = Size.zero;
  int height = 0;
}

class _InfCanvasWidgetState extends State<InfCanvasWidget>{

  InfCanvasController _controller;

  late InfCanvasPainter cvPainter;
  GlobalKey cvKey = GlobalKey();

  ValueNotifier<ui.Image?> vn = ValueNotifier(null);

  CanvasParams p = CanvasParams();

  late ui.PaintShader shader;

  ui.InfCanvasInstance instance = ui.InfCanvasInstance();
  ui.PaintLayer? layer;

  late TaskQueue<StrokePoint> _sps;
  late TaskQueue<CanvasReq> _rqs;  

  _InfCanvasWidgetState(this._controller){
    _controller._RegisterState(this);

    cvPainter = InfCanvasPainter(vn,p);
    
    layer = instance.CreateNewPaintLayer();
    ui.ShaderProgram shaderProg = ui.ShaderProgram(
      '''
in fragmentProcessor color_map;

uniform float2 texPos;
uniform float2 uvPos;
uniform float uvScale;
uniform half exp;
uniform float3 in_colors0;

float4 permute ( float4 x) { return mod ((34.0 * x + 1.0) * x , 289.0) ; }

half4 alphaComposite(half4 c0, half4 c1){
  //   * alpha composite: (color 0 over color 1)
  //   * a01 = (1 - a0)·a1 + a0
  //
  //     r01 = ((1 - a0)·a1·r1 + a0·r0) / a01
  //
  //     g01 = ((1 - a0)·a1·g1 + a0·g0) / a01
  //
  //     b01 = ((1 - a0)·a1·b1 + a0·b0) / a01
  //

  //Premultiplied color:
  //half a01 = (1 - c0.a) * c1.a + c0.a;
  half4 c01 = c0 + c1 * (1-c0.a);

  return c01;
}

half4 main(float2 p) {
  float2 localP = p - texPos;

	half4 bgColor = sample(color_map, localP);
	
  half4 fgColor = half4(float4(localP.x * uvScale + uvPos.x, localP.y * uvScale + uvPos.y, 0.0, 1.0)*0.5 );

  return alphaComposite(fgColor, bgColor);
  //return fgColor;
    //return half4(0.0, 0.0, 1.0, 1.0);
    //float s = pointSize;
    //return half4(float4(uvPos.x, uvPos.y, 0.0, 1.0));
}
      '''
    );

    shader = ui.PaintShader(shaderProg);
    _sps = TaskQueue(
      (queue)async{
        for(var pn = queue.front; pn != null; pn = pn.next){
            var point = pn.val;
            ui.HierarchicalPoint lt = ui.HierarchicalPoint(
              point.offset.dx - 25,
              point.offset.dy - 25
            );
            ui.HierarchicalPoint rb = lt.Translated(Offset(50,50));
            await layer?.DrawRect(lt, rb, point.height,shader, Matrix4.identity().storage);
        }

        return null;
      },
        finalizer: (res){
          double w  = 0, h = 0;
          final keyContext = cvKey.currentContext;
          if (keyContext != null) {
              // widget is visible
            final box = keyContext.findRenderObject() as RenderBox;
            w = box.size.width;
            h = box.size.height;
          }
          instance.GenSnapshot(ui.HierarchicalPoint(p.offset.dx,p.offset.dy), p.height, w.ceil(), h.ceil()).then(
            (img){
              vn.value = img;
            }
          );
        }
    );
    
    _rqs = TaskQueue(
      (queue)async{
        var p = queue.back!.val;
        var img = await instance.GenSnapshot(
          ui.HierarchicalPoint(p.offset.dx,p.offset.dy), 
          p.height, 
          p.size.width.ceil(), 
          p.size.height.ceil()
        );
        
        return img;
      },
      finalizer: (img){
        vn.value = img as ui.Image;
      }
    );
  }

  @override
  void didUpdateWidget(InfCanvasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(_controller != widget.controller){
      _controller = widget.controller;
      _controller._RegisterState(this);
    }
    
  }


  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: NotificationListener<SizeChangedLayoutNotification>(
        onNotification: _OnResize,
        child: Listener(
          onPointerDown: _OnMove,
          onPointerMove: _OnMove,
          child: SizeChangedLayoutNotifier(
            child: CustomPaint(
              key: cvKey,
              painter: cvPainter,
            ),
          ),
        ),
      )
    );
  }


  void _OnMove(PointerEvent e) {

    
    if(e.buttons & kPrimaryMouseButton != 0){

      _sps.PostTask(StrokePoint()..offset = p.offset + e.localPosition..height = p.height);

    }else if(e.buttons & kSecondaryMouseButton != 0){
      setState(() {
        p.offset -= e.localDelta;
        _UpdateSnapshot();
        
      });
    }
    
  }

  void _UpdateSnapshot(){
    double w  = 0, h = 0;
    final keyContext = cvKey.currentContext;
    if (keyContext != null) {
        // widget is visible
      final box = keyContext.findRenderObject() as RenderBox;
      w = box.size.width;
      h = box.size.height;
    }

    _rqs.PostTask(CanvasReq()
          ..offset = p.offset
          ..height = p.height
          ..size = Size(w, h)
    );

  }

  bool _OnResize(SizeChangedLayoutNotification e){
     _UpdateSnapshot();
     return true;//Handled
  }

}


class InfCanvasPainter extends CustomPainter{

  ValueNotifier<ui.Image?> vn;
  CanvasParams p;


  InfCanvasPainter(this.vn, this.p):super(repaint:vn){
    
  }


  @override
  void paint(Canvas canvas, Size size) {

    //print("Cursor pos: ${touchPoint}");
    Paint paint = Paint();

    //cp.tree.DrawTreeToCanvas(canvas, size, cp.offset,cp.height);
    if(vn.value != null){
      canvas.drawImage(vn.value!, Offset.zero, paint);
    }

    
    //p.shader = shaderProg.GenerateShader(uniforms);
    //canvas.drawRect(Rect.fromCenter(center:Offset.zero, width: 480, height: 480),p );
    paint.color = Color.fromARGB(255, 0, 255, 0);
    canvas.drawCircle(-p.offset, 3, paint);
    //canvas.drawRect(Rect.fromLTWH(-cp.offset.dx, -cp.offset.dy, 50, 50), p);
  }
  @override
  bool shouldRepaint(InfCanvasPainter oldDelegate) => true;

}


