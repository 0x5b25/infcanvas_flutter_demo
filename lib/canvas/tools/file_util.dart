

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:infcanvas/canvas/canvas_tool.dart';
import 'package:infcanvas/canvas/tools/infcanvas_viewer.dart';
import 'package:infcanvas/utilities/storage/file_chunk_manager.dart';
import 'package:infcanvas/widgets/functional/tool_view.dart';
import 'package:path/path.dart';

class FileUtil extends CanvasTool{
  @override get displayName => "FileUtil";

  File? _currFile;

  File? get currentFile => _currFile;
  set currentFile(File? f){
    if(f == _currFile) return;
    _currFile = f;
    _saveToCurr.isEnabled = f != null;
  }

  late MenuAction _saveToCurr;
  late InfCanvasViewer _cvTool;
  CanvasInstance get cvInst => _cvTool.cvInstance;

  @override OnInit(mgr, ctx){
    
    _cvTool = mgr.FindTool<InfCanvasViewer>()!;

    mgr.menuBarManager.RegisterAction(
      MenuPath()
        .Next("File", Icons.file_present_rounded)
        .Next("Open", Icons.file_upload_sharp),
      _Open
    );

    _saveToCurr = mgr.menuBarManager.RegisterAction(
      MenuPath()
        .Next("File", Icons.file_present_rounded)
        .Next("Save", Icons.file_download_sharp),
      _SaveCurr
    )..isEnabled = false;
    
    mgr.menuBarManager.RegisterAction(
      MenuPath()
        .Next("File", Icons.file_present_rounded)
        .Next("Save as", Icons.file_copy),
      _SaveAs
    );    
  }

  String _ProcFilePath(String path, String ext){
    return setExtension(path, ext);
  }

  Future<void> _SaveAs()async{
    var initial = currentFile?.path;
    final typeGroup = XTypeGroup(label: 'InfCanvas Document', extensions: ['.ics']);
    var f = await getSavePath(
      initialDirectory: initial,
      acceptedTypeGroups: [typeGroup]
    );    
    if(f == null) return;
    var filePath = setExtension(f,'.ics');
    currentFile = File(filePath);
    
    try{
      showDialog(
        context: manager.state.context, 
        builder: (ctx){
          return AlertDialog(
            title: Text("Saving file"),
          );
        }
      );
      await _SaveCV(cvInst, currentFile!);
      
      await showDialog(
        context: manager.state.context, 
        builder: (ctx){
          return AlertDialog(
            title: Text("File saved"),
            content: Text("path:$filePath"),
            actions: [
              TextButton(
                child: Text("OK"),
                onPressed:(){Navigator.of(ctx).pop();}
              )
            ],
          );
        }
      );
    }catch(e){
      await showDialog(
        context: manager.state.context, 
        builder: (ctx){
          return AlertDialog(
            title: Text("Can't save to file"),
            content: Text("error:$e"),
            actions: [
              TextButton(
                child: Text("Close"),
                onPressed:(){Navigator.of(ctx).pop();}
              )
            ],
          );
        }
      );
      return;
    }finally{
      Navigator.of(manager.state.context).pop();
    };
  }

  Future<void> _SaveCurr()async{
    if(currentFile == null) return;
    try{
      showDialog(
        context: manager.state.context, 
        builder: (ctx){
          return AlertDialog(
            title: Text("Saving file"),
          );
        }
      );

      await _SaveCV(cvInst, currentFile!);
      
      await showDialog(
        context: manager.state.context, 
        builder: (ctx){
          return AlertDialog(
            title: Text("File saved"),
            content: Text("path:${currentFile!.path}"),
            actions: [
              TextButton(
                child: Text("OK"),
                onPressed:(){Navigator.of(ctx).pop();}
              )
            ],
          );
        }
      );
    }catch(e){
      await showDialog(
        context: manager.state.context, 
        builder: (ctx){
          return AlertDialog(
            title: Text("Can't save to file"),
            content: Text("error:$e"),
            actions: [
              TextButton(
                child: Text("Close"),
                onPressed:(){Navigator.of(ctx).pop();}
              )
            ],
          );
        }
      );
      return;
    }finally{
      Navigator.of(manager.state.context).pop();
    };
  }

  Future<void> _Open()async{
    final typeGroup = XTypeGroup(label: 'InfCanvas Document', extensions: ['.ics']);
    var filePath = await openFile(acceptedTypeGroups: [typeGroup]);    
    if(filePath == null) return;

    await showDialog(
        context: manager.state.context, 
        builder: (ctx){
          return AlertDialog(
            title: Text("Save current canvas?"),
            content: Text("Or everything not saved will be lost"),
            actions: [
              TextButton(
                child: Text("Save"),
                onPressed:()async{
                  await _SaveAs();
                  Navigator.of(ctx).pop();
                }
              ),
              TextButton(
                child: Text("Cancel"),
                onPressed:(){Navigator.of(ctx).pop();}
              )
            ],
          );
        }
      );
    manager.ClearSession();
    currentFile = File(filePath.path);
    
    try{
      showDialog(
        barrierDismissible: false,
        context: manager.state.context, 
        builder: (ctx){
          return AlertDialog(
            title: Text("Loading file"),
            actions: [
              
            ],
          );
        }
      );
      _cvTool.canvasParam = CanvasParam();
      await _ReadCV(cvInst, currentFile!);
    }catch(e){
      cvInst.Clear();
      await showDialog(
        context: manager.state.context, 
        builder: (ctx){
          return AlertDialog(
            title: Text("Can't open file"),
            content: Text("error:$e"),
            actions: [
              TextButton(
                child: Text("Close"),
                onPressed:(){Navigator.of(ctx).pop();}
              )
            ],
          );
        }
      );
      return;
    }finally{
      _cvTool.NotifyOverlayUpdate();
      Navigator.of(manager.state.context).pop(); 
    };
  }

  static Future<void> _SaveCV(CanvasInstance cv, File f)async{
    var fmgr = FileChunkManager();
    await fmgr.CreateFile(f);

    try{
    Future<int> _SaveNode(CanvasNodeWrapper node , List<int> childID)async{
      var data = await node.GetImageData()??[];
      var mask = await node.GetMaskData()??[];
      var totalLen = 
          4*4 // Children ID
        + 1*4 + (data.length)   // Image Size
        + 1*4 + (mask.length)  // Mask Size
        ;
        
      var chunkID = fmgr.NewChunk(totalLen);
      var chunk = fmgr.SeekChunk(chunkID);
      assert(chunk.length == totalLen);
      fmgr.WriteNextInt(childID[0]);
      fmgr.WriteNextInt(childID[1]);
      fmgr.WriteNextInt(childID[2]);
      fmgr.WriteNextInt(childID[3]);
      fmgr.WriteNextInt(data.length);
      fmgr.WriteNext(data);
      fmgr.WriteNextInt(mask.length);
      fmgr.WriteNext(mask);
      return chunkID;
    }

    Future<int> _SaveTree(CanvasNodeWrapper root)async{
      //[Node, [child offsets]]
      List<List> _workingSet = [];
      _workingSet.add([
        root, <int>[]
      ]);

      while(_workingSet.isNotEmpty){
        var currNode = _workingSet.last.first as CanvasNodeWrapper;
        var chList = _workingSet.last.last as List<int>;
        var chToRead = chList.length;
        if(chToRead == 4){
          var id = await _SaveNode(currNode, chList);
          if(_workingSet.length == 1){
            return id;
          }
          _workingSet.removeLast();
          var prevChList = _workingSet.last.last as List<int>;
          prevChList.add(id);
          continue;
        }

        var ch = currNode.GetChild(chToRead);
        if(ch==null){
          chList.add(0);
          continue;
        }

        _workingSet.add([
          ch!, <int>[]
        ]);

      }

      throw "We shouldn't be here";
    }
  
    Future<int> _SaveLayer(CanvasLayerWrapper layer) async{
      var root = layer.GetRootNode();
      int rootID = await _SaveTree(root);
      int totalLen = 
         1*2 //Blend Mode
        +1*2 //IsVisible, IsEnabled
        +1*4 // Alpha
        +1*4 // Root Index
        ;
      var chunkID = fmgr.NewChunk(totalLen);
      var chunk = fmgr.SeekChunk(chunkID);

      var blendMode = layer.blendMode.index;
      var visible = layer.isVisible?1:0;
      var enabled = layer.isEnabled?1:0;
      {
        var hi = (blendMode >> 8) & 0xFF;
        var lo = (blendMode     ) & 0xFF;
        fmgr.WriteNext([lo, hi, visible, enabled]);
      }

      var alpha = layer.alpha;
      var bd = ByteData(4);
      bd.setFloat32(0, alpha, Endian.little);
      var dat = bd.buffer.asUint8List();
      fmgr.WriteNext(dat);
      fmgr.WriteNextInt(rootID);

      return chunkID;
    }
  
    var layerChkID = <int>[];

    for(var layer in cv.layers){
      var id = await _SaveLayer(layer);
      layerChkID.add(id);
    }

    var totalLen = layerChkID.length * 4 + 4;

    var lmapID = fmgr.NewChunk(totalLen);
    fmgr.SeekChunk(lmapID);
    fmgr.WriteNextInt(layerChkID.length);
    for(var id in layerChkID){
      fmgr.WriteNextInt(id);
    }

    //Write map id to master chunk
    fmgr.SeekChunk(0);
    fmgr.WriteNextInt(lmapID);
    fmgr.WriteNextInt(cv.height);

    fmgr.Flush();
    }catch(e){
      rethrow;
    }finally{
      fmgr.Reset();
    }
  }

  static Future<void> _ReadCV(CanvasInstance cv, File f)async{
    var fmgr = FileChunkManager();
    await fmgr.OpenFile(f);
    try{
    Future<List<int>> _RestoreNode(CanvasNodeWrapper node, int chunkID)async{
      //var data = await node.GetImageData()??[];
      //var mask = await node.GetMaskData()??[];
      //var totalLen = 
      //    4*4 // Children ID
      //  + 1 + (data.length)   // Image Size
      //  + 1 + (mask.length)  // Mask Size
      //  ;
      var chunk = fmgr.SeekChunk(chunkID);
      var childID = [
        fmgr.ReadNextInt(),
        fmgr.ReadNextInt(),
        fmgr.ReadNextInt(),
        fmgr.ReadNextInt(),
      ];
        
      var imgLen = fmgr.ReadNextInt();
      if(imgLen > 0){
        var imgData = fmgr.ReadNext(imgLen);
        await node.SetImageData(imgData);
      }
      var mskLen = fmgr.ReadNextInt();
      if(mskLen > 0){
        var mskData = fmgr.ReadNext(mskLen);
        await node.SetMaskData(mskData);
      }
      return childID;
    }

    Future<void> _RestoreTree(CanvasNodeWrapper root, int chunkID)async{
      //[Node, [child offsets]]
      List<List> _workingSet = [];
      _workingSet.add([
        root,
        await _RestoreNode(root, chunkID)
      ]);

      while(_workingSet.isNotEmpty){
        var currNode = _workingSet.last.first as CanvasNodeWrapper;
        var chList = _workingSet.last.last as List<int>;
        var chToRead = chList.length;
        if(chToRead == 0){
          
          _workingSet.removeLast();
         
          continue;
        }
        var chID = chList[chToRead - 1];
        chList.removeLast();
        if(chID==0){
          continue;
        }
        var ch = currNode.NewChild(chToRead - 1);

        _workingSet.add([
          ch, await _RestoreNode(ch, chID)
        ]);
      }

      //throw "We shouldn't be here";
    }
  
    Future<void> _RestoreLayer(CanvasLayerWrapper layer, int chunkID) async{
      int totalLen = 
         1*2 //Blend Mode
        +1*2 //IsVisible, IsEnabled
        +1*4 // Alpha
        +1*4 // Root Index
        ;
      var chunk = fmgr.SeekChunk(chunkID);

      var meta = fmgr.ReadNext(4);
      {
        var hi = meta[1];
        var lo = meta[0];
        var blendMode = BlendMode.values[(lo | (hi << 8))];
        var visible = meta[2] > 0;
        var enabled = meta[3] > 0;

        layer.blendMode = blendMode;
        layer.isVisible = visible;
        layer.isEnabled = enabled;
      }

      var buf = fmgr.ReadNext(4);
      var bd = ByteData.sublistView(buf);
      var alpha = bd.getFloat32(0, Endian.little);

      layer.alpha = alpha;

      var root = layer.GetRootNode();

      var rootID = fmgr.ReadNextInt();
      await _RestoreTree(root, rootID);
    }
  
    //Write map id to master chunk
    fmgr.SeekChunk(0);
    var lmapID = fmgr.ReadNextInt();
    var cvHeight = fmgr.ReadNextInt();

    fmgr.SeekChunk(lmapID);
    var mapLen = fmgr.ReadNextInt();

    var layerChkID = <int>[];

    for(int i = 0; i < mapLen; i++){
      var id = fmgr.ReadNextInt();
      layerChkID.add(id);
    }

    
    cv.Clear();
    for(var id in layerChkID){
      var layer = cv.CreatePaintLayer();
      await _RestoreLayer(layer, id);
    }
    cv.height = cvHeight;
    }catch(e){
      rethrow;
    }finally{
      fmgr.Reset();
    }

  }


}
