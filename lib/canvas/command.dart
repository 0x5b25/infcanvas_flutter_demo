

import 'package:flutter/cupertino.dart';
import 'package:infcanvas/canvas/canvas_tool.dart';

abstract class CanvasCommand{

  late CommandRecorder _recorder;

  T? FindTool<T extends CanvasTool>(){
    return _recorder.FindTool();
  }

  void Execute(CommandRecorder recorder, BuildContext ctx);

  @override toString() => runtimeType.toString();
  
}

mixin CommandRecorder on ToolManager{
  
  Set<void Function()> _replayBeginListeners = {};
  Set<void Function()> _replayFinishListeners = {};

  void RegisterReplayBeginListener(void Function() callback){
    _replayBeginListeners.add(callback);
  }

  void RegisterReplayFinishListener(void Function() callback){
    _replayFinishListeners.add(callback);
  }

   void RemoveReplayBeginListener(void Function() callback){
    _replayBeginListeners.remove(callback);
  }

  void RemoveReplayFinishListener(void Function() callback){
    _replayFinishListeners.remove(callback);
  }

  List<CanvasCommand> _commands = [];
  int get commandCnt => _commands.length;
  int _replayPos = -1;

  void RecordCommand(CanvasCommand command){
    if(_replayPos < commandCnt - 1){
      _commands.removeRange(_replayPos + 1, commandCnt);
    }
    command._recorder = this;
    _commands.add(command);
    _replayPos++;
  }

  void _NotifyBegin(){
    for(var c in _replayBeginListeners){
      c.call();
    }
  }

  void _NotifyFinish(){
    for(var c in _replayFinishListeners){
      c.call();
    }
  }

  void ReplayTo(int position){
    var validPos = position;
    if(validPos < -1) validPos = -1;
    if(validPos > commandCnt - 1) validPos = commandCnt - 1;
    if(_replayPos == validPos) return;
    _NotifyBegin();
    _replayPos = -1;
    while(_replayPos < validPos){
      _replayPos++;
      _commands[_replayPos].Execute(this, state.context);
    }
    _NotifyFinish();
    Repaint();
  }

  void UndoOneStep(){
    if(_replayPos >= 0 && _replayPos < commandCnt){
      var undoCmd = _commands[_replayPos];
      popupManager.ShowQuickMessage(
        Text("Undo $undoCmd")
      );
    }
    ReplayTo(_replayPos - 1);
  }

  void RedoOneStep(){
    if(_replayPos + 1 >= 0 && _replayPos + 1 < commandCnt){
      var undoCmd = _commands[_replayPos + 1];
      popupManager.ShowQuickMessage(
        Text("Redo $undoCmd")
      );
    }
    ReplayTo(_replayPos + 1);
  }

  void Reset(){
    _replayBeginListeners.clear();
    _replayFinishListeners.clear();
    _commands.clear();
    _replayPos = -1;
  }

  @override void Dispose() {
    super.Dispose();
    Reset();
  }

}
