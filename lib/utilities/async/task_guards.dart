
//Runs once

import 'dart:async';

import 'package:flutter/foundation.dart';

class SequentialTaskGuard<T>{

  bool isRunning = false;
  List<Completer<T>> queued = [];
  final Future<T> Function() task;
  SequentialTaskGuard(this.task);

  bool get isScheduled => queued.isNotEmpty;

  Future<void> _Runner()async{
    assert(isRunning);
    debugPrint("Task runner started.");
    while(true){
      //Enter critical 2
      if(!isScheduled) break;
      var _futures = queued;
      queued = [];
      //Leave critical 2
      //error handles
      T? res;
      var error = null, st = null;
      try {
        res = await task();
      } catch(e, stackTrace){
        error = e; st = stackTrace;
        debugPrint("Task runner encounters an error.");
      } finally {
        for (var f in _futures) {
          if(error == null)
            f.complete(res);
          else{
            f.completeError(error, st);
          }
        }
      }
    }
    debugPrint("Task runner finished.");
  }

  Future<T> RunNowOrSchedule(){
    debugPrint("New task scheduled");
    var f = _ScheduleRun();
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

  Future<T> _ScheduleRun(){
    var c = Completer<T>();
    //Enter critical 2
    queued.add(c);
    //Leave critical 2
    return c.future;
  }
}
