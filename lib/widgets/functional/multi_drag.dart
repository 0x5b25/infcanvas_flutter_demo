
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';


class MultiDrag<T> extends StatefulWidget {

  final Widget? child;
  final T? Function(DragStartDetails)? onDragStart;
  final void Function(DragUpdateDetails, Duration, T?)? onDragUpdate;
  final void Function(DragEndDetails, T?)? onDragEnd;
  final void Function(T?)? onDragCancel;

  const MultiDrag({
    Key? key,
    this.child,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.onDragCancel
  }) : super(key: key);

  @override
  _MultiDragState createState() => _MultiDragState();
}

class _MultiDragState extends State<MultiDrag> {

  final Map<Offset, PointerDownEvent> _pointers = {};

  late final _gr = ImmediateMultiDragGestureRecognizer()
    ..onStart = (off){
      var evt = _pointers[off];
      assert(evt!=null, "Can't find corresponding pointer start");
      _pointers.remove(off);

      var d = DragStartDetails(
        sourceTimeStamp: evt!.timeStamp,
        globalPosition: evt!.position,
        localPosition: evt.localPosition,
        kind: evt!.kind
      );

      var data = widget.onDragStart?.call(d);

      return _MultiDragHandle(
        evt!, data,
        widget.onDragUpdate, widget.onDragEnd, widget.onDragCancel
      );
    }
  ;

  @override void dispose() {
    super.dispose();
    _pointers.clear();
    //REVIEW: Let's hope that disposing of the GR will
    //trigger all pending pointer's cancel() function call
    _gr.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      child: widget.child,
      onPointerDown: _HandlePointerDown,
    );
  }

  void _HandlePointerDown(PointerDownEvent event) {
    if(!_gr.isPointerAllowed(event)){
      return;
    }
    _pointers[event.position] = event;
    _gr.addAllowedPointer(event);
  }
}

class _MultiDragHandle<T> extends Drag{

  final PointerDownEvent startEvt;
  final T? data;
  final void Function(DragUpdateDetails, Duration, T?)? onDragUpdate;
  final void Function(DragEndDetails, T?)? onDragEnd;
  final void Function(T?)? onDragCancel;

  late Duration prevTimestamp;
  Duration deltaTime = Duration.zero;

  _MultiDragHandle(
    this.startEvt, this.data,
    this.onDragUpdate, this.onDragEnd, this.onDragCancel
  ){
    prevTimestamp = startEvt.timeStamp;
  }

  void UpdateDeltaTime(Duration? currTime){
    if(currTime == null){

      return;
    }
    deltaTime = currTime - prevTimestamp;
    prevTimestamp = currTime;
  }

  @override void update(DragUpdateDetails details) {
    UpdateDeltaTime(details.sourceTimeStamp);
    onDragUpdate?.call(details, deltaTime, data);
  }

  @override void end(DragEndDetails details) {
    onDragEnd?.call(details, data);
  }

  @override void cancel() {
    onDragCancel?.call(data);
  }
}
