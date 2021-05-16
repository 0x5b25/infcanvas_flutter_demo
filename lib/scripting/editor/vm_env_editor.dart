import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

import 'package:infcanvas/scripting/editor/vm_types.dart';
import 'package:infcanvas/scripting/editor_widgets.dart';
import 'package:infcanvas/scripting/editor/codemodel.dart';
import 'package:infcanvas/scripting/editor/vm_editor.dart';

///Manages all loaded libraries
///Provide lib registery and compiling services
///Lib creation templates

class NewLibDialog extends StatefulWidget {

  String title, info;
  bool Function(String) validator;
  NewLibDialog(this.title, this.info, this.validator);

  @override
  _NewLibDialogState createState() => _NewLibDialogState();
}

class _NewLibDialogState extends State<NewLibDialog> {

  String libName = "";
  bool isValid = false;

  @override
  Widget build(BuildContext ctx) {
    return Dialog(
      child: Padding(
        padding: EdgeInsets.all(8),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(ctx).textTheme.headline6,),
              Padding(
                padding: const EdgeInsets.only(
                  top: 20,
                  bottom: 20,
                ),
                child: Text(widget.info),
              ),
              SizedBox(
                height: 30,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: NameField(
                        hint: "Library Name",
                        initialText: libName,
                        onChange: (name){
                          libName = name;
                          var v = widget.validator(name);
                          if(isValid != v)setState(() {});
                          isValid = v;
                          return v;
                        },
                      )
                    ),
                    SizedBox(
                      width: 30,
                      child:
                        isValid?
                         TextButton(
                          onPressed: (){Navigator.of(ctx).pop<String?>(libName);},
                          child: Icon(Icons.check, color: Colors.green,),
                        ):
                        TextButton(
                          onPressed: (){Navigator.of(ctx).pop<String?>(null);},
                          child: Icon(Icons.close, color: Colors.red,),
                        ),
                    )
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class VMEnvExplorer extends StatefulWidget {
  final VMEditorEnv env;
  final void Function(CodeLibrary lib)? onSelect;

  const VMEnvExplorer(
    this.env,
    {
      Key? key,
      this.onSelect,
    }
  ):super(key: key);

  @override
  _VMEnvExplorerState createState() => _VMEnvExplorerState();

}

class _VMEnvExplorerState extends State<VMEnvExplorer> {
  @override
  Widget build(BuildContext context) {
    return Material(
      child: Column(
        children: [
          //Header
          Row(
            children:[
              Expanded(
                child: Text("Library Registry",
                  style: Theme.of(context).textTheme.headline4,
                ),
              ),
              TextButton(
                onPressed: (){Navigator.of(context).pop();},
                child: Icon(Icons.close)
              )
            ],
          ),

          //Contents
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: Card(
                  child: ListEditor(
                    listToEdit: EditorEnvInterface(widget.env),
                    onSelect: (l){
                      var e = l as EnvLibEntry;
                      widget.onSelect?.call(l.lib);
                    },
                  ),
                )),

                VerticalDivider(
                  width: 50,
                  indent: 50,
                  endIndent: 50,
                ),

                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom:8.0),
                      child: IconButton(
                        icon: Icons.sync,
                        label: "Reusable",
                        onPressed: ShowNewReusableDialog,
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(bottom:8.0),
                      child: IconButton(
                        icon: Icons.brush,
                        label: "Renderable",
                        onPressed: ShowNewRenderableDialog,
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.only(bottom:8.0),
                      child: IconButton(
                        icon: Icons.file_download,
                        label: "Import",
                      ),
                    ),
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }

  

  bool ValidateName(String name){
    if(name == "")return false;
    for(var lib in widget.env.LoadedLibs()){
      if(lib.name == name) return false;
    }

    return true;
  }



  void ShowNewReusableDialog(){
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx){return NewLibDialog(
        "New Reusable Library",
        "Create library that can be reused in other places",
        ValidateName,
      );},
    ).then<String?>((name){
      if(name != null){
        var lib = CodeLibrary()..name.value = name;
        widget.env.LoadLib(lib);
        setState(() {});
      }
    });
  }

  
  void ShowNewRenderableDialog(){
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (ctx){return NewLibDialog(
        "New Renderable Library",
        "Create library that can be used as brushes",
        ValidateName,
      );},
    ).then<String?>((name){
      if(name != null){
        var lib = CodeLibrary()..name.value = name;
        widget.env.LoadLib(lib);
        setState(() {});
      }
    });
  }
}

class IconButton extends StatelessWidget {

  final IconData icon;
  final String? label;
  final void Function()? onPressed;
  final void Function()? onLongPressed;

  const IconButton({
    Key? key,
    required this.icon,
    this.label,
    this.onPressed,
    this.onLongPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      onLongPress: onLongPressed,
      child:Column(
        children: [
          SizedBox(
            width: 80,
            height: 80,
            child:Center(
              child: Icon(icon, size: 40,)
            )
          ),
          if(label != null)
            Text(label!),
        ],
      ));
  }
}

class EditorEnvInterface extends ListInterface{

  VMEditorEnv env;

  EditorEnvInterface(this.env);

  @override
  void AddEntry(EnvLibEntry entry) {
    env.LoadLib(entry.lib);
  }

  @override
  void RemoveEntry(EnvLibEntry entry) {
    env.UnloadLib(entry.lib);
  }

  @override doCreateEntryTemplate() {
    return EnvLibEntry._();
  }

  @override doGetEntry()sync* {
    for(var l in env.LoadedLibs()){
      yield EnvLibEntry(l);
    }
  }
}

class EnvLibEntry extends ListEditEntry<EditorEnvInterface>{

  CodeLibrary lib;
  VMEditorEnv get env => fromWhichIface.env;

  EnvLibEntry(this.lib);
  EnvLibEntry._():lib = CodeLibrary();

  @override CanEdit()=>lib.editable;

  bool ValidateName(String name){
    if(name == "")return false;
    for(var lib in env.LoadedLibs()){
      if(lib == this.lib) continue;
      if(lib.name == name) return false;
    }
    return true;
  }

  bool SetLibName(String newName){
    if(!ValidateName(newName)) return false;
    lib.name.value = newName;
    return true;
  }

  @override
  bool IsConfigValid() => ValidateName(lib.name.value);

  bool HasError(){
    for(var ty in lib.types){
      for(var m in ty.methods){
        if(m is! CodeMethod) continue;
        if(m.nodeMessage.isNotEmpty) return true;
      }
    }

    return false;
  }

  @override
  Iterable<ListEntryProperty> EditableProps(BuildContext ctx) {
    if(CanEdit())
      return[
        if(HasError())
          StatusIndicator(EntryStatus.Error),

        StringProp(
          SetLibName,
          hint: "Library Name",
          initialContent: lib.name.value,
        ),
      ];

    return[
      LockName(lib.name.value),
      LockIndicator(),
    ];
  }

}

class LockIndicator extends ListEntryProperty{
  @override
  Widget Build(BuildContext ctx) {
    return Center(
      child: Text("built-in",
        style:TextStyle(color: Theme.of(ctx).disabledColor,fontStyle: FontStyle.italic)
      ),
    );
  }
}
class LockName extends ListEntryProperty{
  String name;
  LockName(this.name);
  @override
  Widget Build(BuildContext ctx) {
    return Expanded(
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(name,
          style:TextStyle(color: Theme.of(ctx).disabledColor,fontStyle: FontStyle.italic)
        ),
      ),
    );
  }
}
