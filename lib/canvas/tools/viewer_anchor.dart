


import 'package:infcanvas/canvas/canvas_tool.dart';
import 'package:infcanvas/widgets/functional/tool_view.dart';


class ViewerAnchorManagerWindow extends ToolWindow{
  final ViewerAnchorManager tool;

  ViewerAnchorManagerWindow(this.tool){

  }

  @override BuildContent(context){
    return super.BuildContent(context);
  }
}

class ViewerAnchorManager extends CanvasTool{
  @override get displayName => "ViewAnchorManager";

  late ViewerAnchorManagerWindow _window;

  @override OnInit(mgr, bctx){
    mgr.menuBarManager.RegisterAction(
      MenuPath().Next("Anchor"),
      () { 

      }
    );
  }

}
