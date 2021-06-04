import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:infcanvas/widgets/functional/anchor_stack.dart';


class ColorPickerController{
  _ColorPickerWidgetState? _state;
  late final ValueNotifier<HSVColor> colorNotifier;
  late HSVColor _oldColor;

  ColorPickerController(
    {
      HSVColor color = const HSVColor.fromAHSV(1, 0, 0, 0)
    }
  ){
    colorNotifier = ValueNotifier(color);
    _oldColor = color;
  }

  Color get previousColor => _oldColor.toColor();
  Color get color => colorNotifier.value.toColor();
  set color(Color c) => colorNotifier.value = HSVColor.fromColor(c);

  void NotifyColorUsed(){
    _oldColor = colorNotifier.value;
    _state?.MarkNewColorUsed();
  }

  void Dispose(){
    _state = null;
    colorNotifier.dispose();
  }
    
}
  
class ColorPickerWidget extends StatefulWidget{
  
  final ColorPickerController ctrl;

  

  ColorPickerWidget({
    Key? key,
    required this.ctrl,
  }){

  }

  @override
  _ColorPickerWidgetState createState() => _ColorPickerWidgetState();
}
  
class _ColorPickerWidgetState extends State<ColorPickerWidget> {

  @override void initState() {
    super.initState();
    widget.ctrl._state = this;
  }

  @override didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    oldWidget.ctrl._state = null;
    widget.ctrl._state = this;
  }

  @override dispose(){
    super.dispose();
    widget.ctrl._state = null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.all(3.0),
            child: SizedBox(
              height: 20,
              width: 60,
              child: ColorDiffBox(
                oldColor: widget.ctrl._oldColor,
                newColor: widget.ctrl.colorNotifier,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(3.0),
          child: AspectRatio(
            aspectRatio: 1,
            child: HSVColorPickerWheel(color: widget.ctrl.colorNotifier, wheelWidth: 15,),
          ),
        ),
        ColorIndicator(color: widget.ctrl.colorNotifier,)
      ],
    );
  }

  void MarkNewColorUsed() {
    setState(() {
      
    });
  }
}

class ColorIndicator extends StatefulWidget {

  final ValueNotifier<HSVColor> color;

  ColorIndicator({
    Key? key,
    required this.color
  }):super(key: key);

  @override
  _ColorIndicatorState createState() => _ColorIndicatorState();
}

class _ColorIndicatorState extends State<ColorIndicator> {

  static String Color2Hex(Color c, {bool leadingHashSign = true}) => '${leadingHashSign ? '#' : ''}'
      //'${c.alpha.toRadixString(16).padLeft(2, '0')}'
      '${c.red.toRadixString(16).padLeft(2, '0')}'
      '${c.green.toRadixString(16).padLeft(2, '0')}'
      '${c.blue.toRadixString(16).padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    var rgb = widget.color.value.toColor();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(child:_BuildLabel('#',Color2Hex(rgb,leadingHashSign:false)),flex:2),
        Expanded(child:_BuildLabel('R','${rgb.red}',onVerticalDrag: (e){
          var rgb = widget.color.value.toColor();
          var r = rgb.red;
          r = (r - (e.delta.dy).floor()).clamp(0,255);
          widget.color.value = HSVColor.fromColor(rgb.withRed(r));
        }),),
        Expanded(child:_BuildLabel('G','${rgb.green}',onVerticalDrag: (e){
          var rgb = widget.color.value.toColor();
          var r = rgb.green;
          r = (r - (e.delta.dy).floor()).clamp(0,255);
          widget.color.value = HSVColor.fromColor(rgb.withGreen(r));
        }),),
        Expanded(child:_BuildLabel('B','${rgb.blue}',onVerticalDrag: (e){
          var rgb = widget.color.value.toColor();
          var r = rgb.blue;
          r = (r - (e.delta.dy).floor()).clamp(0,255);
          widget.color.value = HSVColor.fromColor(rgb.withBlue(r));
        }),),
        Expanded(child:_BuildLabel('A','${rgb.alpha}',onVerticalDrag: (e){
          var rgb = widget.color.value.toColor();
          var r = rgb.alpha;
          r = (r - (e.delta.dy).floor()).clamp(0,255);
          widget.color.value = HSVColor.fromColor(rgb.withAlpha(r));
        }),),
      ],
    );
  }

  Widget _BuildLabel(String name, String val, {
    void onVerticalDrag(DragUpdateDetails e)?,
    void onTap()?,
  }){
    return GestureDetector(
      onVerticalDragUpdate: onVerticalDrag,
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(name,style: Theme.of(context).textTheme.headline6,),
          Text(val,style: Theme.of(context).textTheme.bodyText2)
        ],
      ),
    );
  }

  void HandleColorChange(){
    setState(() {
      
    });
  }

  @override
  void initState(){
    super.initState();
    widget.color.addListener(HandleColorChange);
  }

  @override
  void didUpdateWidget(ColorIndicator old){
    old.color.removeListener(HandleColorChange);
    widget.color.addListener(HandleColorChange);
    super.didUpdateWidget(old);
  }

  @override
  void dispose(){
    widget.color.removeListener(HandleColorChange);
    super.dispose();
  }
}

class ColorDiffBox extends StatelessWidget {

  final HSVColor oldColor;
  final ValueNotifier<HSVColor> newColor;

  ColorDiffBox({
    Key? key,
    required this.oldColor,
    required this.newColor
  });

  
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.all(Radius.circular(3)),
      child: Row(
        children: [
          //New color
          Expanded(
            child: SizedBox.expand(
              child: CustomPaint(
                painter: ColorDiffPainter(color: newColor),
              ),
            )
          ),
          //Old color
          Expanded(

            child: SizedBox.expand(
              child: GestureDetector(
                onTap: (){newColor.value = oldColor;},
                child: CustomPaint(
                  painter: ColorDiffPainter(color: 
                    ValueNotifier(oldColor)),
                ),
              ),
            )
          ),
        ],
      ),
    );
  }
}

final ChessboardShaderProg = ui.ShaderProgram(
    '''
half4 main(float2 p) {

  float2 cycle = fract(p / 10);
  bool cycleX = cycle.x < 0.5;
  bool cycleY = cycle.y < 0.5;

  float3 c = (cycleX == cycleY)?float3(0.8):float3(0.4);

  return half4(c.xyz, 1.0);
}
      '''
);

class ColorDiffPainter extends CustomPainter{


  
  
  final ValueNotifier<HSVColor> color;

  ColorDiffPainter({
    Key? key,
    required this.color
  }):super(repaint: color);

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    assert(ChessboardShaderProg.IsProgramValid());
    {
      Paint cp = Paint()
        ..shader = ui.PaintShader(ChessboardShaderProg).MakeShaderInstance()
        ;
      canvas.drawRect(Offset.zero & size, cp);
    }
    {
      Paint cp = Paint()
        ..color = color.value.toColor()
        ..blendMode = BlendMode.srcATop
        ;
      canvas.drawRect(Offset.zero & size, cp);
    }
  }

  @override
  bool shouldRepaint(covariant ColorDiffPainter oldDelegate) {
    if(oldDelegate.color.value != color.value) return true;
    return false;
  }

}

class HSVColorPickerWheel extends StatefulWidget{

  final ValueNotifier<HSVColor> color;

  final double wheelWidth;
  final double boxMargin;

  HSVColorPickerWheel({
    Key? key,
    required this.color,
    this.wheelWidth = 20,
    this.boxMargin = 10,
  });

  @override
  _HSVColorPickerWheelState createState() => _HSVColorPickerWheelState();
}

class _HSVColorPickerWheelState extends State<HSVColorPickerWheel> {
  final _geoHandle = GeometryTrackHandle();

  @override
  Widget build(BuildContext ctx){
    return GeometryTracker(
      handle: _geoHandle,
      child: Listener(
        onPointerDown: _OnPointerLock,
        onPointerMove: _OnPointerInput,
        onPointerCancel: (_){_focus = 0;},
        onPointerUp: (_){_focus = 0;},
        child: CustomPaint(
          painter: HSVColorWheelPainter(widget.color, widget.wheelWidth, widget.boxMargin),

        ),
      ),
    );
  }

  ///0: none  1:box  2:ring
  int _focus = 0;
  double get len2 => (_geoHandle.size.shortestSide / 2 - widget.wheelWidth - widget.boxMargin) * sqrt1_2;


  void _OnPointerLock(PointerEvent e){
    var size = _geoHandle.size;
    double width = size.shortestSide;
    double cx = size.width / 2;
    double cy = size.height / 2;
    var center = Offset(cx, cy);

    var localP = e.localPosition - center;
    if(
      localP.dx > -(len2)  && localP.dx < len2 &&
      localP.dy > -(len2)  && localP.dy < len2
    ){
      _focus = 1;
      _HandleColor(localP);
      return;
    }
    
    var rad = localP.distance;
    if(rad > (width / 2 - widget.wheelWidth) && rad < (width/2)){
      _focus = 2;
      _HandleColor(localP);
    }

  }

  void _OnPointerInput(PointerEvent e){
    var size = _geoHandle.size;
    double cx = size.width / 2;
    double cy = size.height / 2;
    var center = Offset(cx, cy);

    var localP = e.localPosition - center;
    _HandleColor(localP);
  }

  void _HandleColor(Offset pos){
    switch(_focus){
      case 1:
      double sat = ((pos.dx / (len2 * 2)) + 0.5).clamp(0, 1);
      double val = 1-((pos.dy / (len2 * 2)) + 0.5).clamp(0, 1);
      setState(() {
        var alpha = widget.color.value.alpha;
        widget.color.value = HSVColor.fromAHSV(alpha, widget.color.value.hue, sat, val);
      });
      break;

      case 2:
      double ang = (atan2(pos.dy, pos.dx) / pi / 2);
      ang = ang < 0? ang + 1:ang;
      setState(() {
        widget.color.value = widget.color.value.withHue(ang * 360);
      });
      break;

      default: return;
    }

  }

}

class HSVColorWheelPainter extends CustomPainter{

  ValueNotifier<HSVColor> _color;
  double wheelWidth;
  double boxMargin;

  static final ui.ShaderProgram BoxShaderProg = ui.ShaderProgram(
      '''
uniform float uvScale;
uniform float2 originPoint;
uniform float3 color;

// All components are in the range [0…1], including hue.
float3 hue2rgb(float hue)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(hue + K.xyz) * 6.0 - K.www);
    return clamp(p - K.xxx, 0.0, 1.0);
}

half4 main(float2 p) {
  float2 uv = (p - originPoint) * uvScale;

  float3 c = hue2rgb(color.x);

  float s = uv.x;
  float v = 1.0 - uv.y;
  c = c * s + float3(1,1,1) * (1-s);
  c = c * v;
  return half4(c.xyz, 1.0);
}
      '''
  );

  static final ui.ShaderProgram RingShaderProg = ui.ShaderProgram(
      '''

uniform float uvScale;
uniform float2 originPoint;

const float M_PI=3.1415926535897932384626433832795;
 
// All components are in the range [0…1], including hue.
float3 hue2rgb(float hue)
{
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(fract(hue + K.xyz) * 6.0 - K.www);
    return clamp(p - K.xxx, 0.0, 1.0);
}

half4 main(float2 p) {
  //Topleft
  float2 uv = (p - originPoint) * uvScale;

  float2 dir = uv - float2(0.5,0.5);

  float ang = (atan(dir.y, dir.x) / M_PI / 2);
  ang = ang < 0? ang + 1:ang;

  float3 c = hue2rgb(ang);
  return half4(c.xyz, 1.0);
}
      '''
  );

  HSVColorWheelPainter(this._color, this.wheelWidth, this.boxMargin):super(repaint: _color);

  static void DrawHandle(Canvas cv, Color c, Offset pos, double rad){
    var x = pos.dx;
    var y = pos.dy;

    Paint handleP = Paint()
      ..style = PaintingStyle.fill
      ;

    double border = 3;

    handleP.color = c;
    cv.drawCircle(pos, rad, handleP);
    //handleP.color = Color.fromARGB(255, 0, 0, 0);
    //cv.drawCircle(Offset(x, y + 1), rad + border, handleP);

    {
      Paint p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Color.fromARGB(180, 0, 0, 0)
        ..imageFilter = ui.ImageFilter.blur(sigmaX:4, sigmaY: 4)
        ;
      cv.drawCircle(Offset(x, y), rad + 1, p);
    }

    {
      Paint p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Color.fromARGB(255, 255, 255, 255)
        ;
      cv.drawCircle(Offset(x, y), rad, p);
    }

    
  }

  @override
  void paint(Canvas canvas, Size size) {

    double width = size.shortestSide;
    double cx = size.width / 2;
    double cy = size.height / 2;
    var center = Offset(cx, cy);

    Paint handleP = Paint()
      ..style = PaintingStyle.fill
      ..color = HSVColor.fromAHSV(1, _color.value.hue, 1, 1).toColor()
      ;

    {
      //Stroke width lies in center
      double rad = (width - wheelWidth) / 2;

      double rngHandleAng = pi * 2 * _color.value.hue / 360;

      double rngBackAng = atan2(wheelWidth, rad) + 0.05;

      ui.PaintShader ringProg = ui.PaintShader(RingShaderProg);
      ringProg.SetUniformFloat(0, 1/width);
      ringProg.SetUniformFloat2(1, cx - width/2, cy- width/2);

      Paint p = Paint()
        ..strokeWidth = wheelWidth
        ..style = PaintingStyle.stroke
        ..shader = ringProg.MakeShaderInstance()
        ..strokeCap = StrokeCap.round
        ;
      canvas.drawArc(
        Rect.fromCenter(center: center, width: rad*2, height: rad*2), 
        rngHandleAng + rngBackAng, 
        (pi - rngBackAng) * 2 , false, p);

      double hx = cx + rad * cos(rngHandleAng);
      double hy = cy + rad * sin(rngHandleAng);

      //canvas.drawCircle(Offset(hx, hy), wheelWidth / 2, handleP);

      DrawHandle(canvas, HSVColor.fromAHSV(1, _color.value.hue, 1, 1).toColor(),
        Offset(hx, hy), wheelWidth / 2
      );
    }
    
    {
      double len = (width / 2 - wheelWidth - boxMargin) * sqrt2;

      ui.PaintShader boxProg = ui.PaintShader(BoxShaderProg);
      boxProg.SetUniformFloat(0, 1/len);
      boxProg.SetUniformFloat2(1, cx - len/2, cy- len/2);
      boxProg.SetUniformFloat3(2, _color.value.hue / 360, _color.value.saturation, _color.value.value);
      Paint p = Paint()
        ..style = PaintingStyle.fill
        ..shader = boxProg.MakeShaderInstance()
        ;
      canvas.drawRect(Rect.fromCenter(center: center, width: len, height:len), p);

      double hx = cx - (len / 2) + len * _color.value.saturation;
      double hy = cy + (len / 2) - len * _color.value.value;

      DrawHandle(canvas, _color.value.toColor(),
        Offset(hx, hy), wheelWidth / 2
      );
    }

  }
  
  @override
  bool shouldRepaint(covariant HSVColorWheelPainter oldDelegate) {
    
    if(oldDelegate._color !=_color) return true;
    if(oldDelegate.boxMargin != boxMargin)return true;
    if(oldDelegate.wheelWidth != wheelWidth)return true;

    return false;
  }

}
