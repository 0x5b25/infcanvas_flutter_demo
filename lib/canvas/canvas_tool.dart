
import 'dart:collection';
import 'dart:ffi';

import 'package:flutter/widgets.dart';
import 'package:infcanvas/widgets/functional/tool_view.dart';


///There are 3 types of tool:
/// - Main tool : can only activate one, have full control over
///               canvas, example: brush tool, mask brush tool
/// - Plugin    : Can activate multiple plugins, exclusivity is
///               defined by each plugin. example: line guide,
///               scratch pad, reference picture
/// - Utility   : Volatile tool, provides functionalities, example:
///               file importer,
class ToolManager extends ToolViewManager{

  final Map<Type, CanvasTool> _loadedTools = {};

  set tools(List<CanvasTool> val){
    _loadedTools.clear();
    for(var e in val){
      _loadedTools[e.runtimeType] = (e);
      e.manager = this;
    }

    for(var v in _loadedTools.values){
      v.OnInit(this);
    }
  }

  T? FindTool<T extends CanvasTool>(){
    return _loadedTools[T] as T?;
  }

}


abstract class CanvasTool{

  late ToolManager manager;

  String get displayName;

  void OnInit(ToolManager manager){

  }

}

