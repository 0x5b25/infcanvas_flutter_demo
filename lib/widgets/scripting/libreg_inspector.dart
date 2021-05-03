import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';

import 'package:infcanvas/utilities/scripting/vm_types.dart';
import 'package:infcanvas/widgets/functional/editor_widgets.dart';
import 'package:infcanvas/widgets/scripting/lib_inspector.dart';

import 'vm_editor_data.dart';

///Manages all loaded libraries
///Provide lib registery and compiling services
///Lib creation templates

///Manages loaded libraries
class LibRegistery{
  List<VMLibInfo> _builtinLibs = [];
  List<EditorLibData> _editableLibs = [];

  List<EditorLibData> get editableLibs => _editableLibs;

  LibRegistery(){
    
    //VMTest vm = VMTest();
    //for(int i = 0; i < vm.LoadedLibCnt(); i++){
    //  _builtinLibs.add((vm.GetLoadedLib(i)));
    //}
    _builtinLibs = VMRTLibs.RuntimeLibs;
  }

  EditorLibData NewEditableLib(VMLibInfo lib){
    VMEnv libEnv = VMEnv();
    libEnv.AddLibs(_builtinLibs + [lib]);
    lib.dependencies = [
      for(var l in _builtinLibs)
        l.name,
    ];
    EditorLibData data = EditorLibData(libEnv, lib);
    _editableLibs.add(data);
    return data;
  }

  void RemoveEditableLib(VMLibInfo lib){
    var name = lib.name;
    _editableLibs.removeWhere((element){
      return element.lib.IsSame(lib);
    });

    var avail = LoadedLibs();
    for(var l in _editableLibs){
      if(l.env.FindLib(name) == null) continue;
      l.ReconstructEnv(avail);
    }

  }


  Iterable<VMLibInfo> LoadedLibs()sync*{
    for(var l in _builtinLibs){
      yield l;
    }

    for(var l in _editableLibs){
      yield l.lib;
    }
  }

}

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

class LibRegInspector extends StatefulWidget {
  final LibRegistery reg;

  const LibRegInspector(this.reg);

  @override
  _LibRegInspectorState createState() => _LibRegInspectorState();
}

class _LibRegInspectorState extends State<LibRegInspector> {
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
                    listToEdit: LibRegInterface(widget.reg),
                    onSelect: (l){
                      if(l is EditableLibRegEntry){
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>LibInspector(l.data, widget.reg.LoadedLibs)
                          ),
                        );
                      }
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
    for(var lib in widget.reg.LoadedLibs()){
      if(lib.name == name) return false;
    }

    return true;
  }

  void NewEditableLib(String name){
    VMLibInfo inf = VMLibInfo(name);
    widget.reg.NewEditableLib(inf);
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
        VMLibInfo lib = VMLibInfo(name);
        widget.reg.NewEditableLib(lib);
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
        VMLibInfo lib = VMLibInfo(name);
        widget.reg.NewEditableLib(lib);
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

class LibRegInterface extends ListInterface{

  LibRegistery reg;

  LibRegInterface(this.reg);

  @override
  bool get canAdd =>false;

  @override
  void AddEntry(TemplateLibRegEntry entry) {
    reg.NewEditableLib(entry.lib);
  }

  @override
  void RemoveEntry(EditableLibRegEntry index) {
    reg.RemoveEditableLib(index.lib);
  }

  @override
  TemplateLibRegEntry doCreateEntryTemplate() {
    return TemplateLibRegEntry();
  }

  @override
  Iterable<LibRegEntryBase> doGetEntry()sync* {
    for(var l in reg._builtinLibs){
      yield LockedLibRegEntry(l);
    }

    for(var l in reg._editableLibs){
      yield EditableLibRegEntry(l);
    }
  }
}

abstract class LibRegEntryBase extends ListEditEntry{

  LibRegInterface get interface => iface as LibRegInterface;
  VMLibInfo get lib;

  LibRegEntryBase();

  bool ValidateName(String name){
    if(name == "")return false;
    for(var lib in interface.reg.LoadedLibs()){
      if(lib.IsSame(lib)) continue;
      if(lib.name == name) return false;
    }

    return true;
  }

  bool SetLibName(String newName);

  @override
  bool IsConfigValid() => ValidateName(lib.name);

}

class EditableLibRegEntry extends LibRegEntryBase{
  
  EditorLibData data;

  EditableLibRegEntry(this.data);

  @override
  VMLibInfo get lib => data.lib;
  
  @override
  bool CanEdit()=>true;

  @override
  bool SetLibName(String newName){
    if(!ValidateName(newName)) return false;

    data.Rename(newName); 

    return true;
  }

  @override
  Iterable<ListEntryProperty> EditableProps(ctx) {
    return[
      if(!data.IsValid())
        StatusIndicator(EntryStatus.Error),

      StringProp(
        SetLibName,
        hint: "Library Name",
        initialContent: lib.name,
      ),
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

class LockedLibRegEntry extends LibRegEntryBase{

  VMLibInfo lib;
  LockedLibRegEntry(this.lib);

  @override
  bool CanEdit()=>false;

  @override
  Iterable<ListEntryProperty> EditableProps(ctx) {
    return[
      LockName(lib.name),
      LockIndicator(),
    ];
  }

  @override
  bool SetLibName(String newName) {
    throw UnimplementedError();
  }
}


class TemplateLibRegEntry extends LibRegEntryBase{

  String targetName = "";
  VMLibInfo lib = VMLibInfo("");
  TemplateLibRegEntry();

  @override
  bool CanEdit()=>true;


  @override
  Iterable<ListEntryProperty> EditableProps(ctx) {
    return[
      StringProp(
        SetLibName,
        hint: "Library Name",
        initialContent: lib.name,
      ),
    ];
  }

  @override
  bool SetLibName(String newName){
    targetName = newName;
    if(!ValidateName(newName)) return false;
    lib.name = newName;
    return true;
  }

  @override
  bool IsConfigValid() => ValidateName(targetName);
}
