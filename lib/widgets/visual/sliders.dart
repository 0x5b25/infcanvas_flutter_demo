
import 'package:flutter/material.dart';

class CustomSliderThumbCircle extends SliderComponentShape {
  final double thumbRadius;
  final double min;
  final double max;

  const CustomSliderThumbCircle({
    required this.thumbRadius,
    this.min = 0,
    this.max = 10,
  });

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) {
    return Size.fromRadius(thumbRadius);
  }

  @override
  void paint(
      PaintingContext context,
      Offset center, {
        required Animation<double> activationAnimation,
        required Animation<double> enableAnimation,
        required bool isDiscrete,
        required TextPainter labelPainter,
        required RenderBox parentBox,
        required SliderThemeData sliderTheme,
        required TextDirection textDirection,
        required double value,
        required double textScaleFactor,
        required Size sizeWithOverflow,
      }) {
    final Canvas canvas = context.canvas;

    final paint = Paint()
      ..color = sliderTheme.thumbColor! //Thumb Background Color
      ..style = PaintingStyle.fill;

    TextSpan span = new TextSpan(
      style: sliderTheme.valueIndicatorTextStyle!.copyWith(
        fontSize: thumbRadius * .9,
        fontWeight: FontWeight.w700,
      ),
      text: getValue(value),
    );

    TextPainter tp = new TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr);
    tp.layout();
    Offset textCenter =
    Offset(center.dx - (tp.width / 2), center.dy - (tp.height / 2));

    canvas.drawCircle(center, thumbRadius, paint);
    tp.paint(canvas, textCenter);
  }

  String getValue(double value) {
    return (min+(max-min)*value).toStringAsFixed(1);
  }
}

class ThinSlider extends StatelessWidget {
  final double min, max, value;
  final Function(double)? onChanged;
  final Function(double)? onChangeEnd;

  ThinSlider({
    Key? key,
    required this.value,
    this.min = 0, this.max = 1,
    this.onChanged,
    this.onChangeEnd
  }):super(key: key);

  @override
  Widget build(BuildContext context) {
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        trackShape: RoundedRectSliderTrackShape(),
        trackHeight: 4.0,
        
        thumbShape: CustomSliderThumbCircle(thumbRadius: 12, min: min, max: max),
        overlayShape: RoundSliderOverlayShape(overlayRadius: 20.0),
        tickMarkShape: RoundSliderTickMarkShape(),
      ),
      child: Slider(
        value: value,
        min: min, max: max, onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      )
    );
  }
}
