
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

import 'package:infcanvas/utilities/async/task_guards.dart';

class BinaryStorage{
  String fileName;
  Uint8List data;
  BinaryStorage(this.fileName, this.data);
}

class AppModel{

  static const fileName = "appmodel.json";
  static const storageKey = "storage";
  static const binMapKey = "files";

  Map<String, dynamic> _dataStorage = {};
  Map<String, BinaryStorage> _binaryStorage = {};
  Directory? _tempDir;
  FutureOr<Directory> GetStorageDir(){
    if(_tempDir != null) return _tempDir!;
    return getApplicationDocumentsDirectory().then<Directory>(
      (dir)async{
        var dirPath = join(dir.path, "InfCanvas");
        _tempDir = await Directory(dirPath).create();
        return _tempDir!;
      }
    );
  }

  Future<File?> GetAppModelFile()async{
    var dir = await GetStorageDir();
    await for(var entity in dir.list()){
      if(entity is File){
        var name = basename(entity.path);
        if(name == fileName) return entity;
      }
    }
    return null;
  }

  late final _storeTaskRunner = DelayedTaskGuard<void>(
    (_){
      _SaveModel();
    },
    Duration(seconds: 1),
    "DelayedAppModelSaver"
  );

  void _SaveModel()async{
    var jsonStr = jsonEncode({
      storageKey:_dataStorage
    });
    var dir = await GetStorageDir();
    var filePath = join(dir.path, fileName);
    await File(filePath).writeAsString(jsonStr);
  }

  void _ClearModel(){
    _dataStorage.clear();
    _binaryStorage.clear();
  }

  Future<bool> Load(){
    _ClearModel();
    return _LoadModel();
  }

  Future<bool> _LoadModel()async{
    var file = await GetAppModelFile();
    if(file == null) return false;
    try {
      var content = await file.readAsString();
      var map = jsonDecode(content);
      var storageObject = map[storageKey] as Map<String, dynamic>;
      _dataStorage = storageObject;
      var fileMappings = map[binMapKey] as Map<String, String>;
      var rootPath = file.parent.path;
      for(var e in fileMappings.entries){
        var k = e.key;
        var fileName = e.value;
        var filePath = join(rootPath, fileName);
        var file = File(filePath);
        var exists = await file.exists();
        if(exists){
          var content = await file.readAsBytes();
          _binaryStorage[k] = BinaryStorage(fileName, content);
        }
      }
      return true;
    }catch(e){
      debugPrint("Read appmodel failed: $e");
      return false;
    }
  }

  Future<void> SaveModel(String key, dynamic data)async{
    _dataStorage[key] = data;
    return _storeTaskRunner.Schedule();
  }

  ReadModel(String key){
    return _dataStorage[key]??<String, dynamic>{};
  }

  void SaveAll(){
    _storeTaskRunner.Schedule();
    _storeTaskRunner.FinishImmediately();
  }
}
