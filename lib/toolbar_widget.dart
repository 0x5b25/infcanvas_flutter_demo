

import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:infcanvas/canvas_widget.dart';

import 'widgets/functional/floating.dart';
import 'widgets/tool_window/color_picker.dart';
import 'layerman_widget.dart';

import 'util.dart';

class ToolBar extends StatefulWidget{

  InfCanvasController cvCtrl;

  ToolBar({Key? key,required this.cvCtrl}):super(key: key);

  @override
  _ToolBarState createState() => _ToolBarState();
}

class _ToolBarState extends State<ToolBar> {

  late final ClosableWindow _wndLayerMan, _wndColorWheel;

  ValueNotifier<HSVColor> _color = ValueNotifier(HSVColor.fromAHSV(1, 0, 0, 0));

  @override
  void initState(){
    _wndLayerMan = ClosableWindow(
      context,
      (showFn, clsFn){
        return DraggableFloatingWindow(
          key: Key('layerman'),
          ctrl: DFWController()
            ..anchor = Offset(1,1)
            ..dx = -250
            ..dy = -400
            ..width = 250
            ..height = 400,
          child: CreateFWContent(showFn, clsFn, LayerManager(widget.cvCtrl), icon:Icons.layers, title:'Layers'),
        );
      }
    );

    _wndColorWheel = ClosableWindow(
      context,
      (showFn, clsFn){
        return DraggableFloatingWindow(
          key: Key('colorpick'),
          ctrl: DFWController()
            ..anchor = Offset(1,1)
            ..dx = -200
            ..dy = -400
            ..width = 200
            ..height = 400,
          child: CreateFWContent(
            showFn, clsFn, 
            ColorPicker(ctrl: ColorPickerController()), 
            icon:Icons.color_lens, 
            title:'Color'
          ),
        );
      }
    );
  }

  Widget CreateFWContent(
    void showFn(), 
    void clsFn(),
    Widget child,
    {
      IconData? icon,
      String? title, 
    }
    
  ) {
    return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 30,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child:Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e){showFn();},
                      child: FWMoveHandle(
                        child: Container(
                          color: Colors.red.withOpacity(0.0),
                          child: Row(
                            children: [
                              if(icon != null)
                                Container(width: 30, height: 30, child: Icon(icon)),
                              if(title != null)
                                Padding(
                                  padding: EdgeInsets.all(3),
                                  child: Align(
                                      alignment: Alignment.centerLeft,
                                      child:Text(title,)
                                    ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 30,
                    child: TextButton(child: Icon(Icons.close),onPressed: clsFn,)
                  )
                ],
              ),
            ),
            Flexible(
              fit:FlexFit.loose,
              child: child
            ),
          ],
        );
  }

  @override
  Widget build(BuildContext context) {
    return FloatingWindow(
      anchor: Rect.fromLTRB(1,0,1,0),
      align: Offset(1,0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton(
            child: Text('Layers'),
            onPressed: (){
              _wndLayerMan.OpenWnd();
            }
          ),
          
          ElevatedButton(
            child: Text('Color'),
            onPressed: (){
              _wndColorWheel.OpenWnd();
            }
          ),
        ],
      ),
    );
  }
}
