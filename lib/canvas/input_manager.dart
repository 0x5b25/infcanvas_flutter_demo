
import 'package:flutter/widgets.dart';

/*



*/

abstract class InputHandler{
  int get priority;

  bool _registered = false;
  InputManager? _mgr;

  bool get registered => _registered;

  bool AcceptPointer(PointerDownEvent pointer);

  void _NotifyRegister(InputManager mgr){
    _registered = true;
    _RemoveFromMgr();

    _mgr = mgr;
    OnRegister();
  }

  void OnRegister(){}

  void _NotifyUnregister(InputManager mgr){
    assert(_mgr == mgr);
    _registered = false;
    _mgr = null;
    OnUnregister();
  }

  void OnUnregister(){}

  void _RemoveFromMgr(){
    if(_mgr == null) return;
    _mgr!.RemoveHandler(this);
  }

  void Dispose(){
    _RemoveFromMgr();
  }
}

class InputManager{
  List<InputHandler> _handlers = [];

  void RegisterHandler(InputHandler handler){
    bool added = false;
    for(int i = 0; i < _handlers.length; i++){
      if(_handlers[i].priority == handler.priority){
        var old =  _handlers[i];
        _handlers[i] = handler;
        old._NotifyUnregister(this);
        added = true;
        break;
      }

      if(_handlers[i].priority > handler.priority){
        _handlers.insert(i, handler);
        added = true;
        break;
      }
    }
    if(!added){
      _handlers.add(handler);
    }
    handler._NotifyRegister(this);
  }

  T? GetHandlerOfType<T extends InputHandler>(){
    for(var h in _handlers){
      if(h is T) return h;
    }
  }

  InputHandler? GetHandlerOfPriority(int priority){
    for(var h in _handlers){
      if(h.priority == priority) return h;
    }
  }

  void RoutePointer(PointerDownEvent pointer){
    for(int i = _handlers.length - 1; i >= 0; i--){
      if(_handlers[i].AcceptPointer(pointer)) break;
    }
  }

  void Dispose(){
    var hs = _handlers;
    _handlers = [];
    for(var h in hs){
      h.Dispose();
    }
  }

  void RemoveHandler(InputHandler inputHandler) {
    if(_handlers.remove(inputHandler)){
      inputHandler._NotifyUnregister(this);
    }
  }
}

class PointerInputRegion extends StatefulWidget {

  final Widget child;

  const PointerInputRegion({
    Key? key,
    required this.child,
  }) : super(key: key);

  @override
  _PointerInputRegionState createState() => _PointerInputRegionState();

  static InputManager? GetManager(BuildContext ctx){
    return ctx.findAncestorStateOfType<_PointerInputRegionState>()?.inputMgr;
  }
}

class _PointerInputRegionState extends State<PointerInputRegion> {

  final inputMgr = InputManager();

  @override void dispose() {
    super.dispose();
    inputMgr.Dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }

}

