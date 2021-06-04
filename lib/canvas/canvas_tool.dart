
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
  }

  T? FindTool<T extends CanvasTool>(){
    return _loadedTools[T] as T?;
  }

  void InitTools(BuildContext ctx){
    for(var v in _loadedTools.values){
      v.OnInit(this, ctx);
    }
  }

  @override Dispose(){
    super.Dispose();
    for(var t in _loadedTools.values){
      t.Dispose();
    }
    _loadedTools.clear();
  }

}


T? ReadMapSafe<T>(Map<String, dynamic> map, String key){
  var data = map[key];
  if(data is T) return data as T;
  return null;
}

abstract class CanvasTool{

  late ToolManager manager;

  String get displayName;

  void OnInit(ToolManager manager, BuildContext ctx){

  }

  void Dispose(){

  }
}

void RestoreToolWindowLayout(
  Map<String, dynamic>? data,
  ToolWindow window,
  void Function() showWindow
){
  if(data == null) return;
  var visible = data["visible"];
  if(visible is! bool) visible = false;
  window.RestorePosition(data["layout"]);
  if(visible){
    showWindow();
  }
}

Map<String, dynamic> SaveToolWindowLayout(ToolWindow window,){
  return {
    "visible":window.isInstalled,
    "layout":window.SavePosition(),
  };
}