

import 'package:flutter/material.dart';
import 'package:infcanvas/utilities/scripting/graph_compiler.dart';
import 'package:infcanvas/widgets/functional/editor_widgets.dart';
import 'package:infcanvas/widgets/scripting/shader_editor.dart';




class ShaderLib{

  String name;

  List<EditorShaderData> shaders = [];

  ShaderLib(this.name);

  void AddShader(EditorShaderData shader){
    shader.reg = this;
    for(int i = 0; i < shaders.length; i++){
      if(shaders[i].name == shader.name){
        shaders[i] = shader;
        return;
      }
    }

    shaders.add(shader);
  }

  void RemoveShader(String name){
    shaders.removeWhere((element) {
      return element.name == name;
    });

    for(var s in shaders){
      s.NotifyCodeChange();
    }
  }

  void NewShader(String name) {
    AddShader(EditorShaderData(name));
  }

  EditorShaderData? LookupShader(ShaderRef ref){
    if(ref.libName != name) return null;
    for(var s in shaders){
      if(ref.shaderName == s.name) return s;
    }
    return null;
  }
}

class ShaderLibInterface extends ListInterface{

  ShaderLib lib;

  ShaderLibInterface(this.lib);

  @override
  void AddEntry(TemplateShaderLibEntry entry) {
    lib.NewShader(entry.name);
  }
  
  @override
  void RemoveEntry(ShaderLibEntry entry) {
    lib.RemoveShader(entry.name);
  }

  @override
  TemplateShaderLibEntry doCreateEntryTemplate() {
    return TemplateShaderLibEntry();
  }

  @override
  Iterable<ListEditEntry> doGetEntry() {
    return [
      for(var s in lib.shaders)
        ShaderLibEntry(s)
    ];
  }

}

abstract class ShaderLibEntryBase extends ListEditEntry{

  ShaderLibInterface get interface => iface as ShaderLibInterface;

  @override
  bool CanEdit() => true;

  String get name;

  bool SetName(String val);
  bool ValidateName(String name);

  @override
  Iterable<ListEntryProperty> EditableProps(BuildContext ctx) {
    return [
      StringProp(
        SetName,
        initialContent: name,
        hint: "Shader Name",
      )
    ];
  }

  @override
  bool IsConfigValid() => ValidateName(name);

}

class ShaderLibEntry extends ShaderLibEntryBase{

  EditorShaderData data;

  ShaderLibEntry(this.data);

  String get name => data.name;

  @override
  bool SetName(String val) {
    bool valid = ValidateName(val);
    if(valid){
      data.name = val;
    }
    return valid;
  }

  @override
  bool ValidateName(String name) {
    if(name == "") return false;
    for(var l in interface.lib.shaders){
      if(l == data) continue;
      if(l.name == name) return false;
    }
    return true;
  }

}

class TemplateShaderLibEntry extends ShaderLibEntryBase{

  String name = "";

  @override
  bool SetName(String val) {
    name = val;
    return ValidateName(name);
  }

  @override
  bool ValidateName(String name) {
    if(name == "") return false;
    for(var l in interface.lib.shaders){
      if(l.name == name) return false;
    }
    return true;
  }

}



class ShaderLibInspector extends StatefulWidget {

  final ShaderLib lib;

  ShaderLibInspector(this.lib);

  @override
  _ShaderLibInspectorState createState() => _ShaderLibInspectorState();
}

class _ShaderLibInspectorState extends State<ShaderLibInspector> {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        children: [
          Row(
            children:[
              Expanded(
                child: Text(widget.lib.name,
                  style: Theme.of(context).textTheme.headline4,
                ),
              ),
              TextButton(
                onPressed: (){
                  Navigator.of(context).pop();
                },
                child: Icon(Icons.close)
              )
            ],
          ),

          ListEditor(
              title:"Types",
              listToEdit: ShaderLibInterface(widget.lib),
              onSelect:(e){
                if(e == null) return;
                var entry = e as ShaderLibEntry;
                OnSelectShader(entry.data);
              },
            ),
        ]
      ),
    );
  }

  void OnSelectShader(EditorShaderData data) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx)=>ShaderEditor(data)
      )
    );
  }
}

