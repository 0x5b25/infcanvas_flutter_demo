
import 'package:flutter/widgets.dart';
import 'package:infcanvas/canvas/canvas_tool.dart';
import 'package:infcanvas/widgets/functional/floating.dart';
import 'package:infcanvas/widgets/functional/tool_view.dart';
import 'package:infcanvas/widgets/tool_window/color_picker.dart';

class ColorPickerWindow extends ToolWindow{

  ColorPickerController ctrl;

  ColorPickerWindow(this.ctrl);

  @override
  Widget BuildContent(ctx){
    return SizedBox(
      width: 200,
      child: CreateDefaultLayout(
        ColorPickerWidget(ctrl:ctrl),
        title:"Color Picker",
      ),
    );
  }

}

class ColorPicker extends CanvasTool{
  @override get displayName => "ColorPicker";

  late final _ctrl = ColorPickerController();
  late final _window = ColorPickerWindow(_ctrl);

  Color get currentColor => _ctrl.color;
  Color get previousColor => _ctrl.previousColor;

  void NotifyColorUsed() => _ctrl.NotifyColorUsed();

  @override OnInit(mgr){
    mgr.menuBarManager.RegisterAction(
      MenuPath(name:"Color"),
      () { mgr.windowManager.ShowWindow(_window);}
    );
  }

}
