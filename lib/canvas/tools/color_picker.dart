
import 'package:flutter/widgets.dart';
import 'package:infcanvas/canvas/canvas_tool.dart';
import 'package:infcanvas/widgets/functional/floating.dart';
import 'package:infcanvas/widgets/functional/tool_view.dart';
import 'package:infcanvas/widgets/tool_window/color_picker.dart';

class ColorPickerWindow extends ToolWindow{

  ColorPicker tool;
  ColorPickerController get ctrl => tool._ctrl;

  ColorPickerWindow(this.tool);

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

  @override Future<void> OnRemove() {
    tool._OnWndClose();
    return super.OnRemove();
  }

}

class ColorPicker extends CanvasTool{
  @override get displayName => "ColorPicker";

  late final _ctrl = ColorPickerController();
  late final _window = ColorPickerWindow(this);

  Color get currentColor => _ctrl.color;
  Color get previousColor => _ctrl.previousColor;

  void NotifyColorUsed() => _ctrl.NotifyColorUsed();

  late final MenuAction _showAction;

  @override OnInit(mgr){
    _showAction = mgr.menuBarManager.RegisterAction(
      MenuPath(name:"Color"),
      _ShowWnd
    );
  }

  void _ShowWnd(){
    _showAction.isEnabled = true;
    manager.windowManager.ShowWindow(_window);
  }

  void _OnWndClose(){
    _showAction.isEnabled = false;
  }

}
