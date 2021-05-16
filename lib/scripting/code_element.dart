
import 'package:flutter/foundation.dart';

class Event{
  late Observable originator;
}

abstract class Observable{

  Set<Observer> _observers = {};
  String debugName = "";

  //Critical guards to allow for modify observer
  //list while sending events
  List<Observer> _criticalAdd = [];
  List<Observer> _criticalRemove = [];
  int _inCriticalCnt = 0;
  bool get inCritical => _inCriticalCnt > 0;
  _EnterCritical(){
    _inCriticalCnt++;
  }

  _ExitCritical(){
    if(_inCriticalCnt > 1){
      _inCriticalCnt--;
      return;
    }
    if(_inCriticalCnt == 1){
      //Process modifications
      for(var r in _criticalRemove){
        _observers.remove(r);
      }
      for(var a in _criticalAdd){
        _observers.add(a);
      }
    }
    _inCriticalCnt = 0;
  }

  void _RegisterObserver(Observer ob){
    if(inCritical){
      debugPrint("($debugName): observer ${ob.debugName}"
          " added during critical");
      _criticalAdd.add(ob);
    }else {
      debugPrint("($debugName): observer ${ob.debugName}"
          " added");
      _observers.add(ob);
    }
  }

  void _UnregisterObserver(Observer ob){
    if(inCritical){
      debugPrint("($debugName): observer ${ob.debugName}"
          " added during critical");
      _criticalRemove.add(ob);
    }else {
      debugPrint("($debugName): observer ${ob.debugName}"
          " removed");
      _observers.remove(ob);
    }
  }

  void SendEventRaw(Event e){
    _EnterCritical();
    for(var ob in _observers){
      ob._NotifyEvent(this, e);
    }
    _ExitCritical();
  }

  void SendEvent(covariant Event e){
    e.originator = this;
    SendEventRaw(e);
  }

  void Dispose(){
    for(var o in _observers){
      o._NotifyWatchingDisposed(this);
    }
  }
}

typedef EventHandler<T extends Event> = void Function(T);
class _EvtHandlerWrapper<T extends Event>{
  EventHandler<T> handler;
  _EvtHandlerWrapper(this.handler);
  void ProcessEvent(Event e){
    if(!(e is T)) return;
    handler(e);
  }
}
class _EvtListener{
  Observable _which;
  Map<Type, _EvtHandlerWrapper> _handlers = {};

  _EvtListener(this._which);

  void _AddHandler<T extends Event>(EventHandler<T> h){
    _handlers[T] = _EvtHandlerWrapper<T>(h);
  }

  void _HandleEvent(Event e) {
    for(var w in _handlers.values){
      w.ProcessEvent(e);
    }
  }
}

class Observer{

  Map<Observable, _EvtListener> _watching = {};
  String debugName = "";
  Observer([this.debugName = ""]);
  void _NotifyWatchingDisposed(Observable which){
    _watching.remove(which);
    debugPrint("one of the watching observable has gone dark.");
  }

  void _NotifyEvent(Observable from, Event e){
    var _listener = _watching[from];
    //assert(_listener != null);
    _listener?._HandleEvent(e);
  }

  void Watch<T extends Event>(Observable o, EventHandler<T> handler){
    var _listener = _watching[o];
    if(_listener == null){
      o._RegisterObserver(this);
      _listener = _EvtListener(o);
      _watching[o] = _listener;
    }
    _listener._AddHandler<T>(handler);
  }

  void StopWatching(Observable? o){
    if(!(_watching.containsKey(o)) ) return;
    o!._UnregisterObserver(this);
    _watching.remove(o);
  }

  void StopReceiving<T extends Event>(Observable? from){
    var _listener = _watching[from];
    if(_listener == null) return;

    var handlerList = _listener._handlers;
    handlerList.remove(T);
    if(handlerList.isEmpty){
      StopWatching(from);
    }
  }

  void Dispose(){
    Clear();
  }

  void Clear() {
    for(var e in _watching.entries){
      e.key._UnregisterObserver(this);
    }

    _watching.clear();
  }
}

abstract class ChainableObservable extends Observable{
  ChainableObservable? parent;

  void _NotifyChildDispose(covariant ChainableObservable child){}

  @override
  void Dispose(){
    super.Dispose();
    parent?._NotifyChildDispose(this);
  }

  void _PropagateEvent(Event e){
    if(e.originator == this) return;
    SendEventRaw(e);
  }
}

class MultiChildObservable extends ChainableObservable{

  List<ChainableObservable> _children = [];

  @override
  void SendEventRaw(e){
    super.SendEventRaw(e);
    for(var c in _children){
      c._PropagateEvent(e);
    }
  }

  @override
  void Dispose(){
    super.Dispose();
    for(var c in _children){
      c.Dispose();
    }
    _children.clear();
  }
}


class CodeElementChangeEvent extends Event{
  CodeElement get originator => super.originator as CodeElement;
  late Event originalEvent;
}

class ElementDisposeEvent extends CodeElementChangeEvent{}

abstract class CodeElement with Observable{
  CodeElement? parentScope;
  late final CodeElementProperty<String> name
  = CodeElementProperty("", this, OnRename);
  bool editable = true;
  bool isDisposed = false;

  @override get debugName => fullName;

  String get fullName => parentScope == null?
  name.value : "${parentScope!.fullName}|$name";

  CodeElementChangeEvent? OnRename(String oldName, String newName){}

  void FillEvent(covariant CodeElementChangeEvent evt){}

  void ForwardEvent(covariant CodeElementChangeEvent evt){
    this.SendEventRaw(evt);
    parentScope?.ForwardEvent(evt);
  }

  void SendEventAlongChain(CodeElementChangeEvent evt){
    evt.originator = this;
    FillEvent(evt);
    ForwardEvent(evt);
  }

  ///Don't use this method to dispose element, use [CodeElement.Dispose]
  ///instead.
  @mustCallSuper
  void DisposeElement(){
    assert(!isDisposed);
    isDisposed = true;
    parentScope = null;
    SendEvent(ElementDisposeEvent());
  }

  @mustCallSuper
  void Dispose(){
    DisposeElement();
    super.Dispose();
  }

  @override toString() => fullName;

}

class CodeElementProperty<T>{
  CodeElement _elem;
  CodeElementChangeEvent? Function(T oldValue,T newValue) _evtBuilder;
  T _val;
  T get value => _val;
  set value(T val){
    var oldVal = _val;
    _val = val;
    var evt = _evtBuilder(oldVal, val);
    if(evt == null) return;
    evt.originator = _elem;
    _elem.SendEventAlongChain(evt);
  }
  CodeElementProperty(this._val, this._elem, this._evtBuilder);

  @override
  String toString()=>_val.toString();
}
