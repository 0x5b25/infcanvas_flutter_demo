
import 'package:flutter/material.dart';
import 'package:infcanvas/scripting/editor_widgets.dart';
import 'package:infcanvas/scripting/editor/codemodel.dart';
import 'package:infcanvas/scripting/editor/codemodel_events.dart';
import 'package:infcanvas/scripting/code_element.dart';

import 'vm_editor.dart';

class VMLibInspector extends StatefulWidget {

  final CodeLibrary lib;
  final VMEditorEnv env;

  final void Function(CodeType)? onSelect;

  const VMLibInspector(
    this.lib,
    this.env,
    {
      Key? key,
      this.onSelect
    }
  ) : super(key: key);

  @override
  _VMLibInspectorState createState() => _VMLibInspectorState();
}

class _VMLibInspectorState extends State<VMLibInspector> {

  final Observer _ob = Observer("LibInspector_ob");

  @override void initState() {
    super.initState();
    _ob.Watch<LibraryChangeEvent>(widget.lib, _HandleEvt);
  }

  @override void didUpdateWidget(covariant VMLibInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.lib == oldWidget.lib) return;
    _ob.StopWatching(oldWidget.lib);
    _ob.Watch<LibraryChangeEvent>(widget.lib, _HandleEvt);
  }

  @override void dispose() {
    _ob.Dispose();
    super.dispose();
  }

  _HandleEvt(e){
    setState(() {

    });
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
                  child: Text(widget.lib.fullName,
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
                for(var d in widget.lib.deps)
                  InputChip(
                      backgroundColor: widget.lib.isDisposed?
                      Colors.red:null
                      ,
                      label: Text(d.fullName),
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
              listToEdit: LibManInterface(this),
              onSelect:(e){
                if(e == null) return;
                var entry = e as LibTypeEntry;
                OnSelectType(entry.type);
              },
            ),

          ],
        ),
      ),
    );
  }


  void ShowDepSelPanel(){
    var availDeps = widget.env.LoadedLibs();
    showDialog(
      useRootNavigator: false,
      context:context,
      builder:(ctx){
        return Dialog(
          child: DepSelPopup(widget.lib, availDeps, AddDep,
          ),
        );
      },
    );
  }

  void AddDep(CodeLibrary lib){
    setState(() {
      widget.lib.AddDep(lib);
    });
  }

  void OnSelectType(CodeType selection){
    //Navigator.of(context).push(
    //    MaterialPageRoute(
    //        builder: (ctx)=>ClassInspector(selection)
    //    )
    //);
    widget.onSelect?.call(selection);
  }
}


class DepSelPopup extends StatefulWidget {

  final CodeLibrary ld;
  final Iterable<CodeLibrary> availLibs;
  void Function(CodeLibrary) onAddDep;

  DepSelPopup(this.ld, this.availLibs,this.onAddDep);

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
                if(widget.ld != n && !widget.ld.deps.contains(n))
                  InputChip(
                    label: Text(n.fullName),
                    onPressed:(){AddDep(n);},
                  ),
            ],
          )
        ]
    );
  }

  void AddDep(dep){
    //if(dep.contains(depName)) return;
    setState(() {
      widget.onAddDep.call(dep);
    });

  }
}

class LibManInterface extends ListInterface{
  _VMLibInspectorState state;
  LibManInterface(this.state);

  CodeLibrary get tgtLib => state.widget.lib;

  @override
  void AddEntry(LibTypeEntry entry) {
    tgtLib.AddType(entry.type);
  }

  @override
  Iterable<ListEditEntry> doGetEntry(){
    return [
      for(var ty in tgtLib.types)
        LibTypeEntry(ty),
    ];
  }

  @override doCreateEntryTemplate() => LibTypeEntry._();

  @override RemoveEntry(LibTypeEntry entry) {
    entry.type.Dispose();
  }
}

class LibTypeEntry extends ListEditEntry<LibManInterface>{

  CodeType type;
  String get name => type.name.value;

  LibTypeEntry(this.type);
  LibTypeEntry._():type = CodeType();

  @override bool CanEdit()=>type.editable;

  bool IsValid() {
    return IsConfigValid() && !type.isDisposed;
  }

  @override
  Iterable<ListEntryProperty> EditableProps(ctx)sync* {
    if(!IsValid())
      yield StatusIndicator(EntryStatus.Error);

    yield StringProp(
        EditTypeName, initialContent:type.name.value, hint:"Type Name"
    );
  }

  @override
  bool IsConfigValid() {return CheckIsNameValid(name);}

  bool CheckIsNameValid(String name){
    if(name == "")return false;
    var ld = (fromWhichIface).tgtLib;
    for(var ty in ld.types){
      if(ty == type) continue;
      if(ty.name.value == name)return false;
    }
    return true;
  }

  bool EditTypeName(name){
    if(!CheckIsNameValid(name))return false;
    type.name.value = name;
    return true;
  }
}

