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
      tree = ImageExt();
    }
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  int _vramTotal = 0;
  int _vramUsed = 0;
  int _vramCachedItem = 0;

  TestCanvas testPainter;
  ChangeNotifier cn;
  Timer pt;

  CanvasParams p = CanvasParams();

  _MyHomePageState(){
    cn = ChangeNotifier();
    testPainter = TestCanvas(cn,p);
    pt = Timer.periodic(Duration(milliseconds: 300), (timer) {setState(() {
      
    }); });
    
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
                  //color: Color.fromARGB(210, 200, 200, 210),
                  boxShadow: [
                    /*BoxShadow(
                      color: Colors.black.withAlpha(90),
                      blurRadius: 5.0, // has the effect of softening the shadow
                      spreadRadius: 5.0, // has the effect of extending the shadow
                      offset: Offset(
                        0,//10.0, // horizontal, move right 10
                        0.0, // vertical, move down 10
                      ),
                      
                    )*/
                  ]
                ),
                child: ClipRect(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: 30.0,
                      sigmaY: 30.0,
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
                              ),
                              RaisedButton(
                                child: Text('Query VRAM'),
                                onPressed: (){
                                 
                                  var totalBytes = QueryGPUBudgetTotalBytes();
                                  var cacheUsage = QueryGPUBudgetCacheUsage();

                                  Future.wait([totalBytes, cacheUsage]).then((value){
                                    setState((){
                                      _vramTotal = value[0];
                                      var usage = value[1] as GPUCacheStatus;
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

  SkSLProgram shaderProg;
  ByteData uniforms;

  TestCanvas(Listenable l, CanvasParams this.cp):super(repaint:l){
    //img = instantiateImageExt();
    shaderProg = SkSLProgram(
      '''
//in fragmentProcessor color_map;

uniform float scale;
uniform half exp;
uniform float3 in_colors0;

float4 permute ( float4 x) { return mod ((34.0 * x + 1.0) * x , 289.0) ; }

float2 cellular2x2 ( float2 P) {
    const float K = 1.0/7.0;
    const float K2 = 0.5/7.0;
    const float jitter = 0.8; // jitter 1.0 makes F1 wrong more often
    float2 Pi = mod ( floor (P ) , 289.0) ;
    float2 Pf = fract ( P);
    float4 Pfx = Pf .x + float4 ( -0.5 , -1.5 , -0.5 , -1.5) ;
    float4 Pfy = Pf .y + float4 ( -0.5 , -0.5 , -1.5 , -1.5) ;
    float4 p = permute ( Pi .x + float4 (0.0 , 1.0 , 0.0 , 1.0) );
    p = permute (p + Pi .y + float4 (0.0 , 0.0 , 1.0 , 1.0) );
    float4 ox = mod (p , 7.0) *K+ K2 ;
    float4 oy = mod ( floor (p *K) ,7.0) * K+ K2 ;
    float4 dx = Pfx + jitter * ox ;
    float4 dy = Pfy + jitter * oy ;
    float4 d = dx * dx + dy * dy ; // distances squared
    // Cheat and pick only F1 for the return value
    d.xy = min (d.xy , d.zw ) ;
    d.x = min (d.x , d. y);
    return d.xx ; // F1 duplicated , F2 not computed
}


half4 main(float2 p) {
	//half4 texColor = sample(color_map, p);
	//if (length(abs(in_colors0 - pow(texColor.rgb, half3(exp)))) < scale)
	//	discard;
	//color = texColor;
    float2 F = cellular2x2 ( p );
    float n = 1.0 -1.5* F.x;
    return half4(float4(n, n, n, 1.0));
}
      '''
    );
    uniforms = ByteData(shaderProg.UniformSizeInBytes());
  }


  @override
  void paint(Canvas canvas, Size size) {

    //print("Cursor pos: ${touchPoint}");

    cp.tree.DrawTreeToCanvas(canvas, size, cp.offset,cp.height);

    Paint p = Paint();
    p.shader = shaderProg.GenerateShader(uniforms);
    canvas.drawRect(Rect.fromCenter(center:Offset.zero, width: 480, height: 480),p );
  }
  @override
  bool shouldRepaint(TestCanvas oldDelegate) => true;

}
