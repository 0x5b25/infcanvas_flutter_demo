import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';



import 'canvas_widget.dart';


class LayerManager extends StatefulWidget{
  InfCanvasController controller;

  LayerManager(this.controller);

  @override
  _LayerManagerState createState() => _LayerManagerState();
}

class _LayerManagerState extends State<LayerManager> {

  void _UpdateList(){
    setState(() {
      
    });
  }

  @override
  Widget build(BuildContext context) {

    var layers = widget.controller.GetPaintLayers();
    //var activeLayer = widget.controller.GetActivePaintLayer();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: ReorderableListView(
            buildDefaultDragHandles: false,
            onReorder: (oldIndex, newIndex) {
              setState((){
                if(newIndex > oldIndex){
                  newIndex -= 1;
                  
                }

                widget.controller.MoveLayer(oldIndex, newIndex);
              });
            },
            children: 
              <Widget>[
                for(int i = 0; i < layers.length; i++)
                  _LayerEntry(Key("_layerman_entry_#${i}"),layers[i], widget.controller, _UpdateList)
                
              ]
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
          TextButton(onPressed: (){
            setState(() {
              widget.controller.AddPaintLayer();
              
            });
          }, child: Icon(Icons.add))
        ],)
      ],
    );
  }
}

class _LayerEntry extends StatefulWidget{

  ui.PaintLayer layer;
  InfCanvasController ctrl;
  void Function() updateParentState;

  _LayerEntry(Key key, this.layer, this.ctrl, this.updateParentState):super(key: key);

  @override
  _LayerEntryState createState() => _LayerEntryState();
}

class _LayerEntryState extends State<_LayerEntry> {

  bool get isActive=> widget.layer == widget.ctrl.GetActivePaintLayer();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: (isActive?Colors.blueGrey[200]!:Colors.grey[350]),
      child: ListTile(
        
        //key: Key("${widget.layer.index}"), 
        leading: Radio(
          value: widget.layer,
          groupValue: widget.ctrl.GetActivePaintLayer(),
          toggleable: true,
          onChanged: (ui.PaintLayer? val){
            
            widget.ctrl.SetActivePaintLayer(val);
            widget.updateParentState();
          },
        ),
        
        title: Row(children: [
          SizedBox(
            width: 30,
            height: 30,
            child: Center(
              child: TextButton(
                child: Icon(
                    widget.layer.isEnabled?Icons.lock_open:Icons.lock
                  ), 
                onPressed: (){
                  setState(() {
                    widget.layer.isEnabled = !widget.layer.isEnabled;
                  });
                }),
            ),
          ),
          SizedBox(
            width: 30,
            height: 30,
            child: TextButton(
              child: Icon(
                  widget.layer.isVisible?Icons.visibility:Icons.visibility_off_outlined
                ), 
              onPressed: (){
                setState(() {
                  widget.layer.isVisible = !widget.layer.isVisible;
                  widget.ctrl.NotifyUpdate();
                });
              }),
          ),
          SizedBox(
            width: 30,
            height: 30,
            child: TextButton(
              child: Icon(
                  Icons.delete_forever
                ), 
              onPressed: (){
                  widget.ctrl.RemovePaintLayer(widget.layer);
                  widget.updateParentState();
              }),
          ),
          
        ],),
        subtitle:  DropdownButton<BlendMode>(
                value: widget.layer.blendMode,
                onChanged: (BlendMode? newValue) {
                  setState(() {
                    widget.layer.blendMode = newValue??BlendMode.srcOver;
                    widget.ctrl.NotifyUpdate();
                  });
                },
                items: BlendMode.values.map((BlendMode classType) {
                  return DropdownMenuItem<BlendMode>(
                    value: classType,
                    child: Text(classType.toString().split('.').last));
                }).toList()
            ), 
        trailing:ReorderableDragStartListener(
          index: widget.layer.index,
          child:Icon(Icons.menu),
        ),
      ),
    );
  }
}
