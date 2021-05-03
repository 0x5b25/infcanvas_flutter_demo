import 'dart:collection';

import 'package:flutter/cupertino.dart';

import 'widgets/functional/floating.dart';

class TaskQueue<T>{
  var _tasks = LinkedList<T>();

  Future<Object?> Function(LinkedList<T>) _worker;
  void Function(Object?)? finalizer;

  var _isProcessing = false;

  int maxIter = 0;

  TaskQueue(
    this._worker, {this.finalizer} 
  ){
  }

  void _RunWorker()async{

    _isProcessing = true;

    

    while(_tasks.length > 0){

      //Take all pending tasks
      var _tAdopt = _tasks;
      _tasks = LinkedList<T>();

      var ret = await _worker(_tAdopt);
      finalizer?.call(ret);
      //currIter++;
      //if(currIter == maxIter){
      //  currIter = 0;
      //  _finalizer(ret);
      //}
    }


    _isProcessing = false;

  }

  void PostTask(T task){
    _tasks.Add(task);
      
    if(!_isProcessing){

        _RunWorker();
        
    }
  }
}

class LinkedListNode<T>{
    T val;
    LinkedList<T>? list;
    LinkedListNode<T>? prev, next;
    LinkedListNode(this.val);
}

class LinkedListIterator<T> implements Iterator<T>{

  final LinkedList<T> _list;
  LinkedListNode<T>? _currNode;
  bool _started = false;


  LinkedListIterator(this._list){
    _currNode = _list.front;
  }

  @override
  T get current => _currNode!.val;

  @override
  bool moveNext() {
    if(!_started){
      _currNode = _list.front;
      _started = true;
      return _currNode != null;
    }

    _currNode = _currNode?.next;
    return _currNode != null;
  }

}

class LinkedList<T> with IterableMixin<T>{

  LinkedListNode<T>? _front, _back;
  int _len = 0;

  int get length => _len;
  LinkedListNode<T>? get front => _front;
  LinkedListNode<T>? get back => _back;

  LinkedListNode<T> Add(T val){
    var n = LinkedListNode<T>(val)..list = this;
    if(_back == null){
      _front = _back = n;
    }else{
      _back!.next = n;
      n.prev = _back;
      _back = n;
    }
    _len++;
    return n;
  }

  void InsertAfter(LinkedListNode<T>? at, LinkedListNode<T> n){
    assert(at?.list == this && n.list == null);
    n.list = this;

    if(at == null){
      if(_front == null){
        _front = _back = n;
      }else{
        _front!.next = n;
        n.prev = _front;
        _front = n;
      }
    }else{
      n.next = at.next;
      n.prev = at;
      at.next = n;
      if(n.next == null){
        _back = n;
      }else{
        n.next!.prev = n;
      }
    }
    _len++;
  }

  void InsertBack(LinkedListNode<T> n){
    assert(n.list == null);
    n.list = this;

    if(_back == null){
      _front = _back = n;
    }else{
      n.prev = _back;
      _back!.next = n;
      _back = n;
    }

    _len++;
  }

  void Remove(LinkedListNode<T> node){
    //if(node.prev != null){
      node.prev?.next = node.next;
    //}
    //if(node.next != null){
      node.next?.prev = node.prev;
    //}
    if(_front == node){
      _front = node.next;
    }
    if(_back == node){
      _back = node.prev;
    }
    node.list = node.prev = node.next = null;
    _len--;
  }

  @override
  Iterator<T> get iterator =>  LinkedListIterator(this);

  @override
  bool get isEmpty => _len == 0;

  @override
  T get first {
    if (_front == null) {
      throw "Collection is empty!";
    }
    return _front!.val;
  }

  @override
  T get last {
    if (_back == null) {
      throw "Collection is empty!";
    }
    return _back!.val;
  }

  @override
  T get single {
    if (_len < 1) throw "Collection is empty!";
    if (_len > 1) throw "Collection has more than one element!";
    return _front!.val;
  }
  

}

typedef Widget WndBuilderFn(
    void Function() show,
    void Function() close);
///Helper function for closable floating windows
class ClosableWindow{

  WndBuilderFn _builder;
  final BuildContext _ctx;

  late Widget _wnd;
  bool _opened = false;

  ClosableWindow(this._ctx, this._builder){
    _wnd = _builder(OpenWnd, CloseWnd);
  }

  void Update({WndBuilderFn? builder}){
    bool shouldReopen = _opened;
    CloseWnd();
    if(builder != null){
      this._builder = builder;
    }
    _wnd = _builder(OpenWnd, CloseWnd);
    if(shouldReopen){
      OpenWnd();
    }

  }

  void CloseWnd(){
    if(!_opened) return;
    _opened = false;
    FloatingWindowPanelState.of(_ctx)?.CloseWindow(_wnd);
  }

  void OpenWnd(){
    _opened = true;
    FloatingWindowPanelState.of(_ctx)?.ShowWindow(_wnd);
  }

}

//Enum name getter
class EnumNameGetter<T>{

  T value;

  EnumNameGetter(this.value);

  String get name{
    return value.toString().split('.').last;
  }

  @override
  String toString()=>name;
}

