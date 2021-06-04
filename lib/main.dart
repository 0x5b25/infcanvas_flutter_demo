// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:infcanvas/canvas/canvas_widget.dart';
import 'package:infcanvas/utilities/storage/app_model.dart';
import 'package:infcanvas/scripting/brush_editor.dart';

import 'package:infcanvas/widgets/visual/loading_page.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(new MyApp());
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}
/*
class EditorWrapper extends StatefulWidget {
  @override
  _EditorWrapperState createState() => _EditorWrapperState();
}

class _EditorWrapperState extends State<EditorWrapper> {

  late ui.VMLibInfo libData;
  late int idx;

  var libs = [
    ui.VMLibInfo("DummyLibA"),
    ui.VMLibInfo("DummyLibB"),
  ];

  _EditorWrapperState(){
    libData = ui.VMLibInfo("DummyLib")
      ..AddClassInfo(ui.VMClassInfo("MyClass"))
      ..dependencies = ["Shouldn't be here","Also shouldn't be here"]
    ;
    //VMEnv libMan = VMEnv();
    //idx = libMan.LoadedLibs().length;
    //libMan.AddLibrary(dummyLib);
    //libData = EditorLibData(libMan, dummyLib);
  }

  LibRegistery reg = LibRegistery();
  @override
  Widget build(BuildContext context) {
    return LibRegInspector(reg);
  }
}
*/
class MyHomePage extends StatefulWidget {
  MyHomePage({Key? key, this.title}) : super(key: key);

  final String? title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}



class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  int _vramTotal = 0;
  int _vramUsed = 0;
  int _vramCachedItem = 0;

  
  //InfCanvasController cvCtrl = InfCanvasController();
  //GlobalKey fwPanelKey = GlobalKey();
  AppModel _model = AppModel();
  bool isInitialized = false;

  //Trigger repaint for frame debuggers
  late Timer timer;

  @override initState(){
    super.initState();
    _model.Load().then((value){
      isInitialized = true;
      setState(() {});
    });
    //timer = Timer.periodic(Duration(milliseconds: 100), (_){
    //  setState(() {
//
    //  });
    //});
  }

  @override dispose(){
    super.dispose();
    _model.SaveAll();
    //timer.cancel();
  }

  _MyHomePageState(){    

  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }
/*
  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text("Hello"),
      ),
      body: SizedBox.expand(
        child: FloatingWindowPanel(
          key: fwPanelKey,
          children: <Widget>[
            AnchoredPosition.fill(
              child: InfCanvasWidget(
                cvCtrl
              ),
            ),

            FloatingWindow(
              anchor: Rect.fromLTRB(0.5,0,0.5,0),
              align: Offset(0.5,0),
              top: 10,
              width: 600,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'You have pushed the button this many times:',
                  ),
                  Text(
                    '$_counter',
                    style: Theme.of(context).textTheme.headline4,
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 30.0,
                    child: Row(
                      children: <Widget>[
                        
                        ElevatedButton(
                          child: Text(
                            '+'
                          ),
                          onPressed: (){
                            setState(() {
                              cvCtrl.currentHeight++;
                            });
                          },
                        ),
                        ElevatedButton(
                          child: Text(
                            '-'
                          ),
                          onPressed: (){
                            setState(() {
                              cvCtrl.currentHeight--;
                            });
                          },
                        ),
                        Text(
                          'Current Height: ${cvCtrl.currentHeight}'
                        ),
                        ElevatedButton(
                          child: Text('Query VRAM'),
                          onPressed: (){
                           
                            var totalBytes = ui.QueryGPUBudgetTotalBytes();
                            var cacheUsage = ui.QueryGPUBudgetCacheUsage();

                            Future.wait([totalBytes, cacheUsage]).then((value){
                              setState((){
                                _vramTotal = value[0] as int;
                                var usage = value[1] as ui.GPUCacheStatus;
                                _vramUsed = usage.usedBytes;
                                _vramCachedItem = usage.cachedItemCount;
                              });
                            });

                            
                        }),
                        Text('Total:$_vramTotal Used:$_vramUsed Items:$_vramCachedItem')
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            FloatingWindow(
              left: 10,
              anchor: Rect.fromLTRB(0,0.5,0,0.5),
              align: Offset(0, 0.5),
              //initialPosition: Offset(10,100),
              //width: 40,
              height: 400,
              child: BrushToolbar((brush){
                cvCtrl.brush = brush;
              }),
            ),

            ToolBar(cvCtrl: cvCtrl,),
            
          ],
        )
      ),
      
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: Icon(Icons.add),
      ),
    );
  }

 */
  @override build(ctx){
    return Provider.value(
      value: _model,
      child:isInitialized?CanvasWidget():LoadingPage()
    );
  }
}

class BrushToolbar extends StatefulWidget {

  void Function(ui.BrushInstance? b) onSelect;

  BrushToolbar(this.onSelect);

  @override
  _BrushToolbarState createState() => _BrushToolbarState();
}

class _BrushToolbarState extends State<BrushToolbar> {

  List<BrushData> _brushes = [];
  BrushData? selected;

  Map<BrushData, ui.BrushInstance> _inst = {};

  Widget BuildEntry(BrushData data){
    Widget button;
    if(data == selected){
      button = ElevatedButton(
        onPressed: (){ShowEditor(data);}, 
        child: Icon(Icons.brush, size: 16,)
      );
    }else{
      button = TextButton(
        onPressed: (){SelectBrush(data);}, 
        child: Icon(Icons.brush, size: 16,)
      );
    }

    return SizedBox(
      width: 30,
      height: 30,
      child: button,
    );
  }

  void SelectBrush(BrushData? b){
    var inst = _inst[b];
    if(selected != b){
      setState(() {
        selected = b;
      });
    }
    widget.onSelect(inst);
  }

  bool UpdateInstance(BrushData d){
    var res = d.PackageBrush();
    ui.PipelineDesc? desc = res.first;
    String? errMsg = res.last;
    if(desc != null){
      var newInst = ui.BrushInstance(desc);
      var oldInst = _inst[d];
      if(oldInst != null){
        oldInst.Dispose();
      }
      _inst[d] = newInst;
      return true;
    }
    return false;
  }

  void ShowEditor(BrushData d){
    Navigator.of(context).push(
      MaterialPageRoute(builder: (c)=>BrushEditor(d))
    ).then((value){
      if(UpdateInstance(d)){
        //Brush is actually updated
        SelectBrush(d);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: Column(
                children: [
                  for(var b in _brushes) BuildEntry(b)
                ]
              ),
            ),
          ),
        ),
        SizedBox(
          width: 30,
          height: 30,
          child: TextButton(
            onPressed: (){
              setState(() {
                _brushes.add(BrushData.createNew("Brush ${_brushes.length}"));
              });
            },
            child: Icon(Icons.add)
          ),
        ),
      ],
    );
  }
}
