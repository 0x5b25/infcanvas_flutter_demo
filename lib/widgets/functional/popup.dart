
import 'package:flutter/material.dart';

class PopupMenuContainer<T> extends StatefulWidget {
  final Widget child;
  final List<PopupMenuEntry<T>> items;
  final void Function(T?) onItemSelected;

  PopupMenuContainer({
    Key? key,
    required this.child, 
    required this.items,
    required this.onItemSelected, 
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() => PopupMenuContainerState<T>();
}


class PopupMenuContainerState<T> extends State<PopupMenuContainer<T>>{
  
  Offset _tapDownPosition = Offset.zero;

  _ShowPopup()async{
    final RenderBox overlay = Overlay.of(context)?.context.findRenderObject() as RenderBox;

    T? value = await showMenu<T>(
      context: context,
      items: widget.items,

      position: RelativeRect.fromLTRB(
        _tapDownPosition.dx,
        _tapDownPosition.dy,
        overlay.size.width - _tapDownPosition.dx,
        overlay.size.height - _tapDownPosition.dy,
      ),
    );

    widget.onItemSelected(value);
  }

  _RegisterPos(TapDownDetails details){
    _tapDownPosition = details.globalPosition;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _RegisterPos,
      onSecondaryTapDown: _RegisterPos,
      onLongPress: _ShowPopup,
      onSecondaryTap: _ShowPopup,
      child: widget.child
    );
  }
}