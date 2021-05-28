
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

class DetailedDragEvent<T extends PointerEvent>{
  T pointerEvent;
  DetailedDragEvent(this.pointerEvent);
}

class DetailedDragUpdate
  extends DetailedDragEvent<PointerMoveEvent>{

  final Velocity velocity;

  DetailedDragUpdate(PointerMoveEvent event, this.velocity):super(event);
}

class _DetailedDragPointerState<T>{
  /// Creates per-pointer state for a [MultiDragGestureRecognizer].
  ///
  _DetailedDragPointerState(this.initialEvent, this._gr, this._arenaEntry)
    : _velocityTracker = VelocityTracker.withKind(initialEvent.kind)
  {
    //Startup point
    _velocityTracker.addPosition(initialEvent.timeStamp, initialEvent.position);
  }

  final DetailedMultiDragGestureRecognizer<T> _gr;

  bool _isDragStarted = false;

  ///Per-pointer data storage
  T? data;

  /// The global coordinates of the pointer when the pointer contacted the screen.
  final PointerDownEvent initialEvent;

  final VelocityTracker _velocityTracker;

  /// The kind of pointer performing the multi-drag gesture.
  ///
  /// Used by subclasses to determine the appropriate hit slop, for example.
  PointerDeviceKind get kind => initialEvent.kind;

  GestureArenaEntry _arenaEntry;

  /// Resolve this pointer's entry in the [GestureArenaManager] with the given disposition.
  @protected
  @mustCallSuper
  void resolve(GestureDisposition disposition) {
    _arenaEntry!.resolve(disposition);
  }

  void _move(PointerMoveEvent event) {
    if (!event.synthesized)
      _velocityTracker.addPosition(event.timeStamp, event.position);
    
    var velocity = _velocityTracker.getVelocity();
    _gr.onDragUpdate?.call(
      DetailedDragUpdate(event, velocity), data
    );  
  }

  void _startDrag() {
    data = _gr.onDragStart?.call(DetailedDragEvent(initialEvent));
    _isDragStarted = true;
  }

  void _up(PointerUpEvent event) {
    _isDragStarted = false;
    _gr.onDragEnd?.call(DetailedDragEvent(event), data);
  }

  void _cancel(PointerCancelEvent event) {
    _isDragStarted = false;
    _gr.onDragCancel?.call(data);
  }

  /// Releases any resources used by the object.
  @protected
  @mustCallSuper
  void dispose() {
    _arenaEntry.resolve(GestureDisposition.rejected);
    if(_isDragStarted){
      _gr.onDragCancel?.call(data);
    }
  }
}


class DetailedMultiDragGestureRecognizer<T> extends GestureRecognizer {
  /// Initialize the object.
  DetailedMultiDragGestureRecognizer({
    Object? debugOwner,
    PointerDeviceKind? kind,
  }) : super(debugOwner: debugOwner, kind: kind);

  
  @override
  String get debugDescription => 'detailedMultiDrag';
  
  T? Function(DetailedDragEvent<PointerDownEvent>)? onDragStart;
  Function(DetailedDragUpdate, T?)? onDragUpdate;
  Function(DetailedDragEvent<PointerUpEvent>, T?)? onDragEnd;
  Function(T?)? onDragCancel;

  Map<int, _DetailedDragPointerState>? _pointers = {};

  @override
  void addAllowedPointer(PointerDownEvent event) {
    assert(_pointers != null);
    assert(event.pointer != null);
    assert(event.position != null);
    assert(!_pointers!.containsKey(event.pointer));
    //Immediately accept the gesture
    var entry = GestureBinding.instance!.gestureArena.add(event.pointer, this);
    entry.resolve(GestureDisposition.accepted);

    //Create state
    var state = _DetailedDragPointerState(event, this, entry);
    _pointers![event.pointer] = state;
    GestureBinding.instance!.pointerRouter.addRoute(event.pointer, _handleEvent);
  }

  void _removeState(int pointer) {
    if (_pointers == null) {
      // We've already been disposed. It's harmless to skip removing the state
      // for the given pointer because dispose() has already removed it.
      return;
    }
    assert(_pointers!.containsKey(pointer));
    GestureBinding.instance!.pointerRouter.removeRoute(pointer, _handleEvent);
    _pointers!.remove(pointer)!.dispose();
  }

  void _handleEvent(PointerEvent event) {
    assert(_pointers != null);
    assert(event.pointer != null);
    assert(event.timeStamp != null);
    assert(event.position != null);
    assert(_pointers!.containsKey(event.pointer));
    var state = _pointers![event.pointer]!;
    if (event is PointerMoveEvent) {
      state._move(event);
      // We might be disposed here.
    } else if (event is PointerUpEvent) {
      assert(event.delta == Offset.zero);
      state._up(event);
      // We might be disposed here.
      _removeState(event.pointer);
    } else if (event is PointerCancelEvent) {
      assert(event.delta == Offset.zero);
      state._cancel(event);
      // We might be disposed here.
      _removeState(event.pointer);
    } else if (event is! PointerDownEvent) {
      // we get the PointerDownEvent that resulted in our addPointer getting called since we
      // add ourselves to the pointer router then (before the pointer router has heard of
      // the event).
      assert(false);
    }
  }

  @override
  void acceptGesture(int pointer) {
    assert(_pointers != null);
    var state = _pointers![pointer];
    if (state == null)
      return; // We might already have canceled this drag if the up comes before the accept.
    state._startDrag();
  }

  @override
  void rejectGesture(int pointer) {
    assert(_pointers != null);
    _removeState(pointer);
  }  

  @override
  void dispose() {
    _pointers!.keys.toList().forEach(_removeState);
    assert(_pointers!.isEmpty);
    _pointers = null;
    super.dispose();
  }
}


