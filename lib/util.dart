

class TaskQueue<T>{
  var _tasks = LinkedList<T>();

  Future<Object> Function(LinkedList<T>) _worker;
  void Function(Object) _finalizer;

  var _isProcessing = false;

  int maxIter;

  TaskQueue(
    this._worker, {void Function(Object) finalizer = null} 
  ){
    assert(this._worker != null);
    this._finalizer = finalizer;
  }

  void _RunWorker()async{

    _isProcessing = true;

    

    while(_tasks.length > 0){

      //Take all pending tasks
      var _tAdopt = _tasks;
      _tasks = LinkedList<T>();

      var ret = await _worker(_tAdopt);
      _finalizer(ret);
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
    LinkedListNode<T> prev, next;
}

class LinkedList<T>{

  LinkedListNode<T> _front, _back;
  int _len = 0;

  int get length => _len;
  LinkedListNode<T> get front => _front;
  LinkedListNode<T> get back => _back;

  LinkedListNode<T> Add(T val){
    var n = LinkedListNode<T>()..val = val;
    if(_back == null){
      _front = _back = n;
    }else{
      _back.next = n;
      n.prev = _back;
      _back = n;
    }
    _len++;
  }

  void Remove(LinkedListNode<T> node){
    if(node.prev != null){
      node.prev.next = node.next;
    }
    if(node.next != null){
      node.next.prev = node.prev;
    }
    if(_front == node){
      _front = node.next;
    }
    if(_back == node){
      _back = node.prev;
    }
    _len--;
  }
  

}
