
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'package:archive/archive.dart';

import 'package:infcanvas/scripting/brush_editor.dart';
import 'package:infcanvas/scripting/brush_serializer.dart';

class BrushTemplate{
  final String name;
  final Uint8List? thumbnail;
  final String data;
  const BrushTemplate({
    required this.name,
    required this.data,
    this.thumbnail
  });
}

BrushTemplate _DecodeTemplate(Archive archive){

  _UTF8FromBytes(List<int> bytes){
    var codec = Utf8Codec();
    return codec.decode(bytes);
  }

  Map<String, List<int>> files = {};
  for(var file in archive){
    if(file.isFile){
      files[file.name] = file.content as List<int>;
    }
  }

  var infoStr = _UTF8FromBytes(files["info.json"]!);
  Map<String,dynamic> info = jsonDecode(infoStr);
  var templateName = info["name"] as String;
  var thumbFile = info["thumbnail"] as String;
  var programFile = info["program"] as String;
  var thumbData = files[thumbFile] as List<int>?;
  var programStr = _UTF8FromBytes(files[programFile]!);
  var thumb = thumbData != null?Uint8List.fromList(thumbData):null;
  return BrushTemplate(name: templateName, data: programStr, thumbnail: thumb);
}

Future<BrushTemplate> _DecodeTemplateFromBundle(String name)async{
  var key = "assets/brush_templates/$name";
  var data = await rootBundle.load(key);
  var archive = ZipDecoder().decodeBytes(data.buffer.asUint8List());
  return _DecodeTemplate(archive);
}

const templates = <String>[
  "default_brush.zip",
];

Future<List<BrushTemplate>> LoadTemplates()async{
  var res = <BrushTemplate>[];
  for(var tname in templates){
    var t = await _DecodeTemplateFromBundle(tname);
    res.add(t);
  }
  return res;
}
