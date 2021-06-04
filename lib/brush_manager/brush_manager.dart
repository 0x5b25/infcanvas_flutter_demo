
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:infcanvas/brush_manager/brush_manager_widget.dart';
import 'package:infcanvas/scripting/brush_editor.dart';
import 'package:infcanvas/scripting/brush_serializer.dart';
import 'package:infcanvas/utilities/async/task_guards.dart';
import 'package:infcanvas/widgets/functional/tree_view.dart';
import 'package:path/path.dart';

String Normalize(String val){
  var trimmed = val.replaceAll(RegExp(r'[^A-Za-z0-9_]'),'_');
  if(trimmed == "") return "_";
  return trimmed;
}

String UniqueName(Directory dir, String name){
  int id = 1;
  var ext = extension(name);
  var base = withoutExtension(name);

  var ubase = base;
  do{
    var uname = ubase+ext;
    var currPath = join(dir.path, uname);
    if(!Directory(currPath).existsSync())
      if(!File(currPath).existsSync())
        return uname;
    ubase = "${base}_${id++}";
  }while(true);
}

Directory RenameDir(Directory dir, String name){
  var normName = Normalize(name);
  if(normName == basename(dir.path)) return dir;
  var parent = dir.parent;

  _DoRename(String name){
    var path = join(parent.path, name);
    if(Directory(path).existsSync()) return null;
    return dir.renameSync(path);
  }
  var dirName = normName;
  int id = 1;

  do{
    var res = _DoRename(dirName);
    if(res != null) return res;
    dirName = "${normName}_${id++}";
  }while(true);
}


Directory CreateSubDir(Directory dir, String name){
  var normName = Normalize(name);
  var parent = dir;

  _DoCreate(String name){
    var path = join(parent.path, name);
    if(Directory(path).existsSync()) return null;
    var dir = Directory(path);
    dir.createSync();
    return dir;
  }
  var dirName = normName;
  int id = 1;

  do{
    var res = _DoCreate(dirName);
    if(res != null) return res;
    dirName = "${normName}_${id++}";
  }while(true);
}

Future<void> ShowBrushEditor(BuildContext context, BrushObject brush){
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (ctx)=>BrushEditor(
      brush.data,
      (evt){
        brush.ScheduleSave();
      }
    )
    )
  );
}

class BrushEditAction extends ContentAction{
  get name=>"Edit Brush";
  @override PerformAction(state, content){
    ShowBrushEditor(state.context, content as BrushObject);
  }
}

//Maps to folder
class BrushCategory extends IContentProvider with FolderIconMixin{
  Directory catDir;
  String name;
  String get fileName => basename(catDir.path);
  @override Rename(val){
    if(val == name) return;
    name = val;
    if(catDir != null){
      catDir = RenameDir(catDir, val);
      _WriteCategory(catDir, name);
    }
  }

  static void _WriteCategory(dir, cat){
    File(join(dir.path,'.category')).writeAsStringSync(
        cat
    );
  }

  static String _GetCatName(Directory dir){
    var catFile = File(join(dir.path,'.category'));
    if(!catFile.existsSync()) return basename(dir.path);
    return catFile.readAsStringSync();
  }

  BrushCategory(this.catDir):
      name = _GetCatName(catDir)
  {
  }

  @override
  void CopyTo(IContentProvider where) {
    var cat = where as BrushCategory;
  }

  @override
  void CreateSubProvider(String name) {
    var dir = CreateSubDir(catDir, name);
    _WriteCategory(dir, name);
  }

  @override
  void MoveChildTo(IContent which, IContentProvider where) {
    var cat = where as BrushCategory;
    if(equals(cat.catDir.path, catDir.path)) return;

    FileSystemEntity? targetEnt;
    if(which is BrushCategory) targetEnt = which.catDir;
    else if(which is BrushObject) targetEnt = which.file;

    assert(targetEnt!=null ,"Unknown content type: ${which.runtimeType}");

    var currName = basename(targetEnt!.path);
    var uniqueName = UniqueName(cat.catDir, currName);
    targetEnt.renameSync(join(cat.catDir.path, uniqueName));
  }

  @override
  void RemoveChild(IContent which) {
    which.Dispose();
    FileSystemEntity? targetEnt;
    if(which is BrushCategory) targetEnt = which.catDir;
    else if(which is BrushObject) targetEnt = which.file;
    if(targetEnt!.existsSync()){
      targetEnt.deleteSync(recursive: true);
    }
  }

  @override bool canModify = true;

  @override get content{
    if(!catDir.existsSync()) return [];
    var content = <IContent>[];
    for(var e in catDir.listSync()){
      if(e is Directory){
        content.add(BrushCategory(e));
        continue;
      }
      if(e is File){
        var o = BrushObject.fromFile(e);
        if(o!=null){
          content.add(o);
        }
        continue;
      }
    }
    return content;
  }

  IContent? Search(List<String> path){
    if(path.length == 1){
      var tgt = path.single;
      for(dynamic c in content){
        if(c.fileName == tgt) return c;
      }
      return null;
    }

    var tgt = path.first;
    for(dynamic c in content){
      if(c.fileName != tgt) continue;
      if(c is! BrushCategory) return null;
      return c.Search(path.sublist(1));
    }

  }

  @override Dispose(){}
}

BrushData? ReadFileAsBrushData(File f){
  try{
    var str = f.readAsStringSync();
    var json = jsonDecode(str);
    var brushData = DeserializeBrush(json);
    return brushData;
  }catch(e){
    debugPrint(
      "Can't decode file as brush data \n"
      "file : ${f.path}\n"
      "error: $e"
    );
  }
}

class BrushObject extends IContent with ChangeNotifier{
  late File file;
  late BrushData data;
  late final _saveTaskGuard = DelayedTaskGuard<void>(
    (_){
      if(!file.existsSync()) return;
      Save();
    },
    Duration(seconds: 1)
  );

  String get name => data.name;
  get thumbnail => Icon(Icons.brush);
  String get fileName => basename(file.path);

  static BrushObject? fromFile(File f){
    var decoded = ReadFileAsBrushData(f);
    if(decoded==null) return null;
    var obj = BrushObject._(f,decoded);
    return obj;
  }

  BrushObject(BrushCategory cat, String name){
    var dir = cat.catDir;
    var normName = Normalize(name);
    var uniqueName = UniqueName(dir, "$normName.brush");
    file = File(join(cat.catDir.path,uniqueName));
    data = BrushData.createNew(name);
    Save();
  }

  bool isDisposed = false;
  void ScheduleSave(){
    if(isDisposed) return;
    _saveTaskGuard.Schedule();
  }

  void Save(){
    _SaveToFile(data, file);
  }

  BrushObject._(this.file, this.data);

  static _SaveToFile(BrushData brush, File f){
    var data = SerializeBrush(brush);
    var jsonStr = jsonEncode(data);
    f.writeAsStringSync(jsonStr);
    return data;
  }

  _CloneTo(Directory dir){
    var name = basename(file.path);
    var uniqueName = UniqueName(dir, name);
    var clonedFile = File(join(dir.path, uniqueName));
    var ser = _SaveToFile(data, clonedFile);
    var clonedBrush = DeserializeBrush(ser);
    return BrushObject._(clonedFile, clonedBrush);
  }

  @override
  void CopyTo(IContentProvider where) {
    var cat = where as BrushCategory;
    _CloneTo(cat.catDir);
  }

  @override
  void Rename(String newName) {
    data.name = newName;
    var ext = extension(file.path);
    var dir = file.parent;
    var normName = "${Normalize(newName)}$ext";
    var uniqueName = UniqueName(dir, normName);
    file = file.renameSync(join(dir.path, uniqueName));
    _SaveToFile(data, file);
  }

  @override get canModify => true;

  @override get customActions =>[
    BrushSelectAction(),
    BrushEditAction(),
  ];

  @override get defaultAction => BrushSelectAction();

  @override Dispose(){
    isDisposed = true;
    _saveTaskGuard.FinishImmediately();
  }

  void RefreshData(){
    var newData = ReadFileAsBrushData(file);
    if(newData == null) return;
    data = newData;
  }

}

