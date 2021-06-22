
import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:file_picker_cross/file_picker_cross.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:infcanvas/widgets/visual/text_input.dart';
import 'package:path/path.dart' as path;

bool get _USE_FILE_SELECTOR{
  return Platform.isWindows
      || Platform.isLinux
      || Platform.isMacOS
       ;
}

final NotAllowedPathChars = RegExp(r'[^A-Za-z0-9_\-\. ]');


String Normalize(String val){
  var trimmed = val.replaceAll(RegExp(r'[^A-Za-z0-9_\-\. ]'),'_');
  if(trimmed == "") return "_";
  return trimmed;
}

String UniqueName(Directory dir, String name){
  int id = 1;
  var ext = path.extension(name);
  var base = path.withoutExtension(name);

  var ubase = base;
  do{
    var uname = ubase+ext;
    var currPath = path.join(dir.path, uname);
    if(!Directory(currPath).existsSync())
      if(!File(currPath).existsSync())
        return uname;
    ubase = "${base}_${id++}";
  }while(true);
}

class TypeGroup{
  String? label;
  List<String>? extensions;

  TypeGroup({
    this.label,
    this.extensions,
  });
}

Future<Uint8List?> SelectAndReadFile({
  String? initialPath,
  List<TypeGroup> acceptedTypeGroups = const [],
})async{
  List<String>? exts;
  if(acceptedTypeGroups.isNotEmpty){
    var ext = <String>{};
    for(var a in acceptedTypeGroups){
      if(a.extensions != null){
        for(var e in a.extensions!){
          var trimmed = e.replaceFirst(RegExp(r'^\.'), '');
          ext.add(trimmed);
        }
      }
    }
    exts = ext.toList();
  }
  try{
    var res = 
    exts == null?await FilePickerCross.importFromStorage():
    await FilePickerCross.importFromStorage(
      type: FileTypeCross.custom,
      fileExtension: (exts.join(','))
    );
    var data = res.toUint8List();
    return data;
  }catch(e){
    //mabe caused by permission denied or user cancellation
    debugPrint(e.toString());
  }

  return null;
}

Future<String?> ExportFile(
  Uint8List data,
  String defaultName,
)async{
  var f = FilePickerCross(data);
  try{
    var path = await f.exportToStorage(fileName: defaultName);

    return path??'';
  }catch(e){
    //mabe caused by permission denied or user cancellation
    debugPrint(e.toString());
  }
}

///Show dialog to choose existing file or folders
///return null if canceled
//Future<String?> SelectExistingFile(
//{
//  String? initialPath,
//  List<TypeGroup> acceptedTypeGroups = const [],
//}
//)async{
//  String? path;
//  if(_USE_FILE_SELECTOR){
//    var g = <XTypeGroup>[];
//    for(var a in acceptedTypeGroups){
//      g.add(XTypeGroup(label: a.label, extensions: a.extensions));
//    }
//
//    var filePath = await openFile(initialDirectory: initialPath, acceptedTypeGroups: g);
//    path = filePath?.path;
//  }else{
//    FilePickerResult? result;
//    if(acceptedTypeGroups.isEmpty){
//      result = await FilePicker.platform.pickFiles();
//    }else{
//      var ext = <String>{};
//      for(var a in acceptedTypeGroups){
//        if(a.extensions != null)
//          ext.addAll(a.extensions!);
//      }
//      result = await FilePicker.platform.pickFiles(
//        type: FileType.custom,
//        allowedExtensions: ext.toList()
//      );
//    }
//    path = result?.paths.single;
//  }
//  return path;
//}
//
//
//Future<String?> SelectExistingFolder(
//{
//  String? initialPath,
//  String label = "Folder",
//  List<String> extensions = const [],
//}
//)async{
//  
//}


//Future<String?> SelectExistingFolder(
//{
//  String? defaultName,
//  String? initialPath,
//  //List<TypeGroup> acceptedTypeGroups = const [],
//}
//)async{
//  String? path;
//  if(_USE_FILE_SELECTOR){
//    //var g = <XTypeGroup>[];
//    //for(var a in acceptedTypeGroups){
//    //  g.add(XTypeGroup(label: a.label, extensions: a.extensions));
//    //}
//    var filePath = await getDirectoryPath(
//      initialDirectory: initialPath,
//    );
//    path = filePath;
//  }else{
//    //No direct save methods, just name it
//    path = await FilePicker.platform.getDirectoryPath();
//    //if(dirPath != null){
//    //  var dir = Directory(dirPath);
//    //  if(defaultName == null){
//    //    defaultName = "file";
//    //  }
//    //  var normName = Normalize(defaultName);
//    //  var uniqueName = UniqueName(dir, normName);
//    //  path = join(dirPath, uniqueName);      
//    //}
//  }
//  return path;
//}


class _FileNameInput extends StatefulWidget {
  final String? defaultName;
  final String? extension;
  final Directory dir;
  const _FileNameInput({
    Key? key,
    required this.dir,
    this.defaultName,
    this.extension,
  }) : super(key: key);

  @override createState() => _FileNameInputState();
}

class _FileNameInputState extends State<_FileNameInput> {

  bool nameExists = false;
  bool nameNotAllowed = false;
  String errMsg = "";

  var ctrl = TextEditingController();
  String get name => ctrl.text;

  String get fullName => name + (widget.extension??'');

  void ValidateName(){
    
    nameNotAllowed = name.isEmpty;
    if(nameNotAllowed){
      errMsg = "Empty name not allowed";
    }else{

    nameNotAllowed = name.contains(NotAllowedPathChars);
    if(nameNotAllowed){
      errMsg = "Character not allowed";
    }
    }

    var tgtPath = path.join(widget.dir.path, fullName);
    nameExists = File(tgtPath).existsSync();
    
  }

  void SuggestName(){
    var unique = UniqueName(widget.dir, fullName);
    var uname = path.basename(unique);
    ctrl.text = uname;
  }

  void _Init(){
    ctrl.text = widget.defaultName??"";
    ValidateName();
  }

  @override void initState() {
    super.initState();
    _Init();
  }

  @override void didUpdateWidget(oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.defaultName != oldWidget.defaultName){
      _Init();
    }
  }

  @override void dispose() {
    super.dispose();
    ctrl.dispose();
  }

  List<Widget> _BuildActions(){
    var a = <Widget>[];

    if(nameExists){
      a.add(TextButton(
        child: Text("Suggest"),
        onPressed:
          nameNotAllowed?null:
        (){
          SuggestName();
          setState(() {
            
          });
        },
      ));
      a.add(TextButton(
        child: Text("Overwrite"),
        onPressed:
          nameNotAllowed?null:
        (){
          Navigator.of(context).pop(ctrl.text);
        },
      ));
    }else{
      a.add(TextButton(
        child: Text("Accept"),
        onPressed:
          nameNotAllowed?null:
        (){
          Navigator.of(context).pop(ctrl.text);
        },
      ));
    }
    a.add(TextButton(
      child: Text("Cancel"),
      onPressed: (){
        Navigator.of(context).pop(null);
      },
    ));
    return a;
  }

  @override
  Widget build(BuildContext ctx) {
    return AlertDialog(
      title: Text("File Name"),
      content: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Expanded(
            child: InputBox(
            hint: "Enter file name...",
            errorMessage: 
              nameNotAllowed?errMsg:
              nameExists?"File already exists":
              null
            ,
            ctrl: ctrl,
            onChange: (s){
              var onl = nameNotAllowed;
              var one = nameExists;
              ValidateName();
              if(onl != nameNotAllowed || one != nameExists){
                setState(() {
                  
                });
              }
            },
          ),),
          if(widget.extension != null)
            Text(widget.extension!),
        ],
      ),
      actions: _BuildActions()
    );
  }
}

Future<String?> ShowFileSaveNamingDialog(
  BuildContext context,
  Directory dir,
  {
    String? defaultName,
    String? extension
  }
)async{
  String? name = await showDialog(
    useRootNavigator: false,
    context:  context,
    builder: (_)=>_FileNameInput(
      dir:dir,
      defaultName: defaultName,
      extension: extension,
    )
  );
  return name;
}
