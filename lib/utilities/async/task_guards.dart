
//Runs once

import 'dart:async';

import 'package:flutter/foundation.dart';

class Request<T>{
  Completer<T> c = Completer();
  dynamic arg;
  Request(this.arg);
}

class SequentialTaskGuard<T>{

  bool isRunning = false;
  List<Request<T>> queued = [];
  final Future<T> Function(List) task;
  SequentialTaskGuard(this.task);

  bool get isScheduled => queued.isNotEmpty;

  Future<void> _Runner()async{
    assert(isRunning);
    debugPrint("Task runner started.");
    while(true){
      //Enter critical 2
      if(!isScheduled) break;
      var _req = queued;
      queued = [];
      var args = [
        for(var r in _req) r.arg
      ];
      //Leave critical 2
      //error handles
      T? res;
      var error = null, st = null;
      try {
        res = await task(args);
      } catch(e, stackTrace){
        error = e; st = stackTrace;
        debugPrint("Task runner encounters an error.");
      } finally {
        for (var f in _req) {
          if(error == null)
            f.c.complete(res);
          else{
            f.c.completeError(error, st);
          }
        }
      }
    }
    debugPrint("Task runner finished.");
  }

  Future<T> RunNowOrSchedule([arg]){
    debugPrint("New task scheduled");
    var f = _ScheduleRun(arg);
    if(!isRunning){
      debugPrint("Launching task runner...");
      //Enter critical 1
      isRunning = true;
      //Leave critical 1
      _Runner().then(
        (v){
          debugPrint("Stopping task runner...");
          //Enter critical 1
          isRunning = false;
          //Leave critical 1
        }
      );
    }
    return f;
  }

  Future<T> _ScheduleRun(arg){
    var r = Request<T>(arg);
    //Enter critical 2
    queued.add(r);
    //Leave critical 2
    return r.c.future;
  }
}
