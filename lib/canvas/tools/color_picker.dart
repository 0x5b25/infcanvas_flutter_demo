
import 'package:flutter/widgets.dart';
import 'package:infcanvas/canvas/canvas_tool.dart';
import 'package:infcanvas/utilities/async/task_guards.dart';
import 'package:infcanvas/utilities/storage/app_model.dart';
import 'package:infcanvas/widgets/functional/floating.dart';
import 'package:infcanvas/widgets/functional/tool_view.dart';
import 'package:infcanvas/widgets/tool_window/color_picker.dart';
import 'package:provider/provider.dart';

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

  get onColorChange => _ctrl.colorNotifier;

  late final _ctrl = ColorPickerController();
  late final _window = ColorPickerWindow(this);

  Color get currentColor => _ctrl.color;
  Color get previousColor => _ctrl.previousColor;

  void NotifyColorUsed() => _ctrl.NotifyColorUsed();

  late final MenuAction _showAction;
  AppModel? _model;

  @override OnInit(mgr, ctx){
    _showAction = mgr.menuBarManager.RegisterAction(
      MenuPath(name:"Color"),
      ShowColorPicker
    );
    _model = Provider.of<AppModel>(ctx, listen: false);
    try{
      RestoreState();
    }catch(e){
      debugPrint("ColorPicker restore state failed: $e");
    }
    _window.addListener((){_saveTaskGuard.Schedule();});
    onColorChange.addListener((){_saveTaskGuard.Schedule();});
  }

  void ShowColorPicker(){
    _showAction.isEnabled = true;
    manager.windowManager.ShowWindow(_window);
  }

  void _OnWndClose(){
    _showAction.isEnabled = false;
  }

  late final _saveTaskGuard = DelayedTaskGuard(
    (_)=>SaveState(), Duration(seconds: 3)
  );

  void SaveState(){
    _model?.SaveModel("tool_colorpicker",{
      "window":SaveToolWindowLayout(_window),
      "color":currentColor.value,
    });
  }

  void RestoreState(){
    Map<String, dynamic> data = _model!.ReadModel("tool_colorpicker");
    Map<String, dynamic>? wndlayout = ReadMapSafe(data,"window");
    RestoreToolWindowLayout(wndlayout, _window, ShowColorPicker);
    int? color = ReadMapSafe(data,"color");
    if(color is int){
      _ctrl.color = Color(color);
    }
  }

  @override Dispose(){
    _saveTaskGuard.FinishImmediately();
    _ctrl.Dispose();
  }

}
