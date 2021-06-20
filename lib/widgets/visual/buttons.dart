
import 'package:flutter/material.dart';

class SizedTextButton extends StatelessWidget {

  final double? width, height;

  final Widget child;
  final void Function()? onPressed;
  final void Function()? onLongPressed;

  const SizedTextButton({
    Key? key,
    required this.child,
    this.onPressed,
    this.onLongPressed,
    this.width, this.height
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      child: TextButton(
        style: TextButton.styleFrom(
          padding: EdgeInsets.zero
        ),
        child: Center(
          child: child
        ),
        onPressed: onPressed,
        onLongPress: onLongPressed,
      ),
    );
  }
}
