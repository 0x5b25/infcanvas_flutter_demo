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
import 'dart:ui';

import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  // See https://github.com/flutter/flutter/wiki/Desktop-shells#target-platform-override
  debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  //instantiateImageCodec(list)
  runApp(new MyApp());
}


class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // See https://github.com/flutter/flutter/wiki/Desktop-shells#fonts
        fontFamily: 'Roboto',
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}


class CanvasParams{
    ImageExt tree;
    int height;
    Offset offset;

    CanvasParams(){
      height = 0;
      offset = Offset.zero;
      tree = instantiateImageExt();
    }
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  TestCanvas testPainter;
  ChangeNotifier cn;

  CanvasParams p = CanvasParams();

  _MyHomePageState(){
    cn = ChangeNotifier();
    testPainter = TestCanvas(cn,p);
  }

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: SizedBox.expand(
        child: Stack(
          children: <Widget>[
            Positioned.fill(
              child: SizedBox.expand(
                child: Listener(
                  //onPointerDown: OnMove,
                  onPointerMove: OnMove,
                  onPointerUp: OnMove,
                  child: CustomPaint(
                    painter: testPainter
                  )
                )
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              //height: 100,
              child: Container(
                decoration: BoxDecoration(
                  color: Color.fromARGB(210, 200, 200, 210),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(90),
                      blurRadius: 5.0, // has the effect of softening the shadow
                      spreadRadius: 5.0, // has the effect of extending the shadow
                      offset: Offset(
                        0,//10.0, // horizontal, move right 10
                        0.0, // vertical, move down 10
                      ),
                      
                    )
                  ]
                ),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 10.0,
                      sigmaY: 10.0,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        Text(
                          'You have pushed the button this many times:',
                        ),
                        Text(
                          '$_counter',
                          style: Theme.of(context).textTheme.display1,
                        ),
                        SizedBox(
                          width: double.infinity,
                          height: 30.0,
                          child: Row(
                            children: <Widget>[
                              RaisedButton(
                                child: Text(
                                  'Inc Height'
                                ),
                                onPressed: (){
                                  setState(() {
                                    p.height++;
                                  });
                                },
                              ),
                              RaisedButton(
                                child: Text(
                                  'Dec Height'
                                ),
                                onPressed: (){
                                  setState(() {
                                    p.height--;
                                  });
                                },
                              ),
                              Text(
                                'Current Height: ${p.height}'
                              ),
                              Text(
                                'Offset: ${p.offset}'
                              )
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            )
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

  void OnMove(PointerEvent e) {
    //_incrementCounter();
    //cn.notifyListeners();
    if(e.buttons & kPrimaryMouseButton != 0){
      p.tree.DrawPointToTree(p.offset, e.localPosition, p.height);
   
      p.tree.PrepareImages()
        .then((e){cn.notifyListeners();});
    }else if(e.buttons & kSecondaryMouseButton != 0){
      setState(() {
        p.offset += e.localDelta;
        cn.notifyListeners();
      });
    }
    
  }

}

class TestCanvas extends CustomPainter{

  CanvasParams cp;

  TestCanvas(Listenable l, CanvasParams this.cp):super(repaint:l){
    //img = instantiateImageExt();
  }


  @override
  void paint(Canvas canvas, Size size) {

    //print("Cursor pos: ${touchPoint}");

    cp.tree.DrawTreeToCanvas(canvas, size, cp.offset,cp.height);
  }
  @override
  bool shouldRepaint(TestCanvas oldDelegate) => true;

}
