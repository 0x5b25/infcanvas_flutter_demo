import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:infcanvas/utilities/scripting/vm_types.dart';
import 'package:infcanvas/widgets/scripting/vm_graphnodes.dart';
import 'package:infcanvas/widgets/functional/editor_widgets.dart';
import 'class_inspector.dart';
import 'vm_editor_data.dart';



class LibNameEditor extends StatefulWidget {

  final EditorLibData ld;

  LibNameEditor(this.ld);

  @override
  _LibNameEditorState createState() => _LibNameEditorState();
}

class _LibNameEditorState extends State<LibNameEditor> {
  bool _inEditMode = false;

  @override
  Widget build(BuildContext context) {
    return BuildContent();
  }

  Widget BuildContent(){
    if(_inEditMode){
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children:[
          Flexible(
            child: NameField(
              hint: "Library Name",
              initialText: widget.ld.lib.name,
              onChange: SetLibName,
            ),
          ),
          ElevatedButton(
            onPressed:(){setState(() {
              _inEditMode = false;
            });}, 
            child:Text("Done")
          ),
        ]
      );
    }else{
      return GestureDetector(
        onTap: (){setState((){_inEditMode = true;});},
        child: Text(widget.ld.lib.name,
          style: Theme.of(context).textTheme.headline4,
        ),
      );
    }
  }

  bool ValidateName(String name){
    if(name == "")return false;
    for(var lib in widget.ld.env.LoadedLibs()){
      if(lib.IsSame(widget.ld.lib)) continue;
      if(lib.name == name) return false;
    }

    return true;
  }

  bool SetLibName(String newName){
    if(!ValidateName(newName)) return false;

    setState(() {
      widget.ld.env.RenameLib(widget.ld.lib.name, newName); 
    });
    return true;
  }
}

class LibInspector extends StatefulWidget{

  final EditorLibData lib;

  Iterable<VMLibInfo> Function() queryLibs;

  LibInspector(this.lib, this.queryLibs);

  @override
  _LibInspectorState createState() => _LibInspectorState();
}

class _LibInspectorState extends State<LibInspector> {


  void NavigateBack(){

  }


  @override
  void initState(){
    super.initState();
    //ReconstructEnv();
  }

  @override
  void didUpdateWidget(LibInspector oldWidget){
    super.didUpdateWidget(oldWidget);
    //ReconstructEnv();
  }

  //VMEnv env = VMEnv();
  //late EditorLibData lib;
  void ReconstructEnv(){
    var deps = widget.lib.lib.dependencies;
    var availLibs = widget.queryLibs();
    var depsFound = <VMLibInfo>[];
    for(var l in availLibs){
      if(deps.contains(l.name)){
        depsFound.add(l);
      }
    }
    depsFound.add(widget.lib.lib);
    widget.lib.env.Reset();
    widget.lib.env.AddLibs(depsFound);
  }
  
  @override
  Widget build(BuildContext context) {
    return Material(
      child: SizedBox.expand(
        child: Column(
          children: [
            Row(
              children:[
                Expanded(
                  child: Text(widget.lib.lib.name,
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
            Wrap(
              spacing: 10,
              children: [
                for(var d in widget.lib.lib.dependencies)
                  InputChip(
                    backgroundColor: widget.lib.env.FindLib(d) == null?
                      Colors.red:null
                    ,
                    label: Text(d),
                    onDeleted:(){
                      setState((){
                        widget.lib.RemoveDep(d);
                      });
                    }
                  ),
                TextButton(
                  onPressed:ShowDepSelPanel,
                  child:Icon(Icons.add),
                )
              ],
            ),
            
            ListEditor(
              title:"Types",
              listToEdit: LibManInterface(widget.lib),
              onSelect:(e){
                if(e == null) return;
                var entry = e as LibTypeEntry;
                OnSelectType(entry.data);
              },
            ),

          ],
        ),
      ),
    );
  }

  
  void ShowDepSelPanel(){
    var names = <String>[];
    for(var l in widget.queryLibs()){
      names.add(l.name);
    }
    showDialog(
      context:context,
      builder:(ctx){
        return Dialog(
          child: DepSelPopup(widget.lib, widget.queryLibs(),
            onAddDep: AddDep,
          ),
        );
      },  
    );
  }

  void AddDep(VMLibInfo lib){
    setState(() {
      
    });
  }

  void OnSelectType(EditorClassData selection){
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx)=>ClassInspector(selection)
      )
    );
  }

  
}

class DepSelPopup extends StatefulWidget {

  final EditorLibData ld;
  final Iterable<VMLibInfo> availLibs;
  void Function(VMLibInfo)? onAddDep;

  DepSelPopup(this.ld, this.availLibs,{this.onAddDep});

  @override
  _DepSelPopupState createState() => _DepSelPopupState();
}

class _DepSelPopupState extends State<DepSelPopup> {
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children:[
        Padding(
          padding: EdgeInsets.all(10),
          child: Text('Avaliable Dependencies',
            style: Theme.of(context).textTheme.headline6,
          )
        ),
        
        Wrap(
          spacing: 10,
          children: [
            for(var n in widget.availLibs)
              if(widget.ld.env.FindLib(n.name) == null)
                InputChip(
                  label: Text(n.name),
                  onPressed:(){AddDep(n);},
                ),
          ],
        )
      ]
    );
  }

  void AddDep(VMLibInfo dep){
    //if(dep.contains(depName)) return;
    setState(() {
      widget.ld.AddDep(dep);
    });

    widget.onAddDep?.call(dep);
  }
}



class LibManInterface extends ListInterface{
  EditorLibData meta;

  LibManInterface(this.meta);

  @override
  void AddEntry(TemplateLibTypeEntry entry) {
    meta.AddType(entry._cls);
  }

  @override
  Iterable<ListEditEntry> doGetEntry() sync*{
    for(var d in meta.clsData){
      yield LibTypeEntry(d);
    }
  }

  @override
  TemplateLibTypeEntry doCreateEntryTemplate() {
    return TemplateLibTypeEntry();
  }

  @override
  void RemoveEntry(LibTypeEntry entry) {
    meta.RemoveType(entry.data);
  }
}

abstract class LibTypeEntryBase extends ListEditEntry{
  bool canEdit;
  LibTypeEntryBase(this.canEdit);

  VMClassInfo get cls;

  @override
  bool CanEdit()=>canEdit;

  bool IsValid();

  @override
  Iterable<ListEntryProperty> EditableProps(ctx)sync* {
    if(!IsValid())
      yield StatusIndicator(EntryStatus.Error);

    yield StringProp(
      EditTypeName, initialContent:cls.name, hint:"Type Name"
    );
  }

  @override
  bool IsConfigValid() {return CheckIsNameValid(cls.name); }

  bool CheckIsNameValid(String name){
    if(name == "")return false;
    var ld = (iface as LibManInterface).meta;
    for(var mtd in ld.clsData){
      if(mtd.cls.IsSame(cls)) continue;
      if(mtd.cls.name == name)return false;
    }
    return true;
  }

  bool EditTypeName(name){
    if(!CheckIsNameValid(name))return false;
    cls.name = name;
    return true;
  }
}


class LibTypeEntry extends LibTypeEntryBase{
  EditorClassData data;
  LibTypeEntry(this.data,{bool canEdit = true}):super(canEdit);

  @override
  VMClassInfo get cls => data.cls;

  @override
  bool IsValid() {
    return data.IsValid();
  }

}

class TemplateLibTypeEntry extends LibTypeEntryBase{

  String conf = "";

  VMClassInfo _cls = VMClassInfo("");
  TemplateLibTypeEntry():super(true){}

  @override
  VMClassInfo get cls => _cls;

  @override
  bool IsConfigValid() {return CheckIsNameValid(conf); }

  @override
  Iterable<ListEntryProperty> EditableProps(ctx)sync* {
    yield StringProp(
      EditTypeName, initialContent:conf, hint:"Type Name"
    );
  }

  @override
  bool EditTypeName(name){
    conf = name;
    return super.EditTypeName(name);
  }

  @override
  bool IsValid() =>IsConfigValid();

}
