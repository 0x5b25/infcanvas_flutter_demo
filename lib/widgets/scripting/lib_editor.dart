import 'dart:ui';
import 'package:flutter/material.dart';

import 'package:infcanvas/utilities/scripting/vm_types.dart';
import 'package:infcanvas/utilities/scripting/graphnodes.dart';
import 'package:infcanvas/widgets/functional/text_input.dart';
import 'class_inspector.dart';

class EditorLibData{
  VMEnv env;
  VMLibInfo lib;

  List<EditorClassData> clsData = [];

  //TODO: node query, type inheritance lookup
  EditorLibData(this.env, this.lib){
    //Update classes
    assert(env.LoadedLibs().contains(lib));
  }

  Iterable<String> Types()sync*{
    for(var ty in env.loadedTypes){
      var parts = ty.split('|');
      if(parts[0] == lib.name) yield parts[1];
      else yield ty;
    }
  }

  void RemoveType(EditorClassData cls){
    lib.RemoveClassInfo(cls.idx);
    clsData.remove(cls);
  }

  EditorClassData AddType(VMClassInfo cls){
    int idx = lib.ClassInfoCnt();
    lib.AddClassInfo(cls);
    env.RegisterClass(cls);
    clsData.add(EditorClassData(this, idx));
    return clsData.last;
  }

  Iterable<NodeSearchInfo> FindMatchingNode(String? argType, String? retType)
  sync* {
    //Method calls
    yield* env.FindMatchingNode(argType, retType);

    //TODO:Search misc nodes
    

  }

}


class EditorInfoHolder extends InheritedNotifier<ChangeNotifier>{

  EditorLibData libData;

  EditorInfoHolder({
    Key? key,
    required this.libData,
    required Widget child
  }):
  super(key: key, child: child, notifier: ChangeNotifier()){

  }

  void NotifyUpdate(){
    notifier?.notifyListeners();
  }


  static EditorInfoHolder? of(BuildContext ctx){
    return ctx.dependOnInheritedWidgetOfExactType<EditorInfoHolder>();
  }
}

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

class LibEditor extends StatefulWidget{

  final VMLibInfo lib;

  Iterable<VMLibInfo> Function() queryLibs;

  LibEditor(this.lib, this.queryLibs);

  @override
  _LibEditorState createState() => _LibEditorState();
}

class _LibEditorState extends State<LibEditor> {


  void NavigateBack(){

  }


  @override
  void initState(){
    super.initState();
    ConstructEnv();
  }

  @override
  void didUpdateWidget(LibEditor oldWidget){
    super.didUpdateWidget(oldWidget);
    ConstructEnv();
  }

  VMEnv env = VMEnv();
  late EditorLibData lib;
  void ConstructEnv(){
    var deps = widget.lib.dependencies;
    var availLibs = widget.queryLibs();

    var depsFound = <VMLibInfo>[];
    for(var l in availLibs){
      if(deps.contains(l.name)){
        depsFound.add(l);
      }
    }
    depsFound.add(widget.lib);

    env.Reset();
    env.AddLibs(depsFound);
    lib = EditorLibData(env, widget.lib);
  }
  
  EditorClassData? selected;
  @override
  Widget build(BuildContext context) {
    return Material(
      child: EditorInfoHolder(
        libData:lib,
        child:IndexedStack(
          index: selected == null?0:1,
          children: [
            Positioned.fill(
              child: LibInspector(
                ShowDepSelPanel,
                OnSelectType
              )
            ),
            if(selected != null)
              Positioned.fill(
                child: ClassInspector(selected!, (){OnSelectType(null);})
              ),
          ],
        )
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
          child: DepSelPopup(widget.lib, names,
            onAddDep: AddDep,
          ),
        );
      },  
    );
  }

  void AddDep(String name){
    setState(() {
      for(var lib in widget.queryLibs()){
        if(lib.name == name){
          env.AddLibrary(lib);
        }
      }
    });
  }

  void OnSelectType(EditorClassData? selection){
    if(selection == selected) return;
    setState(() {
      selected = selection;
    });
  }

  
}

class DepSelPopup extends StatefulWidget {

  final VMLibInfo lib;
  final List<String> availLibs;
  void Function(String)? onAddDep;

  DepSelPopup(this.lib, this.availLibs,{this.onAddDep});

  @override
  _DepSelPopupState createState() => _DepSelPopupState();
}

class _DepSelPopupState extends State<DepSelPopup> {
  @override
  Widget build(BuildContext context) {
    var dep = widget.lib.dependencies;
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
              if(!dep.contains(n) && widget.lib.name != n)
                InputChip(
                  label: Text(n),
                  onPressed:(){AddDep(n);},
                ),
          ],
        )
      ]
    );
  }

  void AddDep(String depName){
    var dep = List<String>.from(widget.lib.dependencies);
    //if(dep.contains(depName)) return;
    setState(() {
      dep.add(depName);
      widget.lib..dependencies = dep;
    });

    widget.onAddDep?.call(depName);
  }
}

class LibInspector extends StatefulWidget {

  void Function() requestAddDep;
  void Function(EditorClassData?) onSelect;
  
  LibInspector(this.requestAddDep, this.onSelect){
    
  }

  @override
  _LibInspectorState createState() => _LibInspectorState();
}

class _LibInspectorState extends State<LibInspector> {

  late EditorInfoHolder holder = EditorInfoHolder.of(context)!;

  @override
  void initState(){
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          SizedBox(
            height: 50,
            child: Row(
              //mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LibNameEditor(holder.libData)
                ),

                ElevatedButton(
                  onPressed: (){
                  
                  },
                  child: Icon(Icons.save_sharp)
                )
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            children: [
              for(var d in holder.libData.lib.dependencies)
                InputChip(
                  backgroundColor: holder.libData.env.FindLib(d) == null?
                    Colors.red:null
                  ,
                  label: Text(d),
                  onDeleted:(){
                    setState((){
                      var dep = List<String>.from(holder.libData.lib.dependencies);
                      dep.remove(d);
                      holder.libData.lib.dependencies = dep;
                    });
                  }
                ),
              TextButton(
                onPressed:widget.requestAddDep,
                child:Icon(Icons.add),
              )
            ],
          ),
          
          LibTypeInspector(holder.libData, onSelect: widget.onSelect,)

        ],
      ),
    );
  }

}


class LibTypeInspector extends StatefulWidget {

  void Function(int)? onChange;
  void Function(EditorClassData?)? onSelect;
  EditorLibData meta;

  LibTypeInspector(this.meta,{Key? key, this.onChange, this.onSelect}):super(key: key);

  @override
  _LibTypeInspectorState createState() => _LibTypeInspectorState();
}

class _LibTypeInspectorState extends State<LibTypeInspector> {

  bool _inEditMode = false;
  EditorClassData? selected;

  //@override
  //void initState(){
  //  super.initState();
  //  var holder =  ClassInfoHolder.of(context)!;
  //  cls = holder.cls;
  //}

  @override
  Widget build(BuildContext context) {
    //var methods = widget.cls.methods;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4),
          child: SizedBox(
            height: 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: Text("Types")),
                SizedBox(width: 30, height: 30,
                  child:TextButton(
                    onPressed: (){
                      setState(() {
                        _inEditMode = !_inEditMode;
                      });
                    },
                    child: _inEditMode?
                    Icon(Icons.check,color: Colors.green,):
                    Icon(Icons.edit,),
                  ),
                ),
              ],
            ),
          ),
        ),
        Divider(),
        for(var cls in widget.meta.clsData)
          Padding(
            padding: const EdgeInsets.only(bottom:4.0),
            child: Container(
              height: 30,
              child: _inEditMode?_buildEditingEntry(cls):_buildNormalEntry(cls),
            ),
          ),
        if(_inEditMode)
          NewTypeButton(
            widget.meta, 
            onChange:(i){
              setState(() {
                widget.onChange?.call(i);
              });
            } ),
      ],
    );
  }  

  _buildEditingEntry(EditorClassData cd) {
    return TypeNameEditor(cd,CheckIsNameValid,
      onChange: (){widget.onChange?.call(cd.idx);},
      onDelete: (){RemoveType(cd);},
    );
    
  }

  _buildNormalEntry(EditorClassData cd) {
    var cls = cd.cls;
    var selColor = Theme.of(context).primaryColor.withOpacity(0.2);
    return GestureDetector(
      onTap: (){SelectFocusType(cd);},
      child: Container(
        color: cd == selected?selColor:null,
        child: Row(
          children: [
            Expanded(child: Text(cls.name)),
          ],
        ),
      ),
    );
  }

  void SelectFocusType(EditorClassData? md){
    setState(() {
      selected = md;
    });
    widget.onSelect?.call(md);
  }

  bool CheckIsNameValid(String name){
    if(name == "")return false;
    for(var cls in widget.meta.lib.types){
      if(cls.name == name)return false;
    }
    return true;
  } 


  void RemoveType(EditorClassData cd){
    if(cd == selected)SelectFocusType(null);
    widget.meta.RemoveType(cd);
    widget.onChange?.call(cd.idx);      
  }
}


class TypeNameEditor extends StatefulWidget {

  void Function()? onChange;
  void Function()? onDelete;
  bool Function(String) nameValidator;
  EditorClassData cd;

  TypeNameEditor(
    this.cd, 
    this.nameValidator,
    {Key? key, this.onChange, this.onDelete}
  );

  @override
  _TypeNameEditorState createState() => _TypeNameEditorState();
}

class _TypeNameEditorState extends State<TypeNameEditor> {

  @override
  Widget build(BuildContext context) {
    var cls = widget.cd.cls;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        
        SizedBox( width: 30, height: 30,
          child: TextButton(
            onPressed: widget.onDelete,
            child:Icon(Icons.delete, color: Colors.red,),
          ),
        ),

        Expanded(
          child:NameField(
            hint: "Type Name",
            initialText: cls.name,
            onChange: (name){
              return EditTypeName(cls, name);
            },
          )
        ),
        
              
      ],
    );
  }

  bool EditTypeName(VMClassInfo cls, String name){
    var valid = widget.nameValidator(name);
    if(valid){
      widget.cd.lib.env.RenameType(cls.fullName, name);
      widget.onChange?.call();
    }
    return valid;
  }

}


class NewTypeButton extends StatefulWidget {

  void Function(int)? onChange;
  EditorLibData meta;

  NewTypeButton(this.meta, {Key? key, this.onChange});

  @override
  _NewTypeButtonState createState() => _NewTypeButtonState();
}

class _NewTypeButtonState extends State<NewTypeButton> {
  bool inEditMode = false;
  bool nameHasError = true;
  String name = "";
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 30,
      child: inEditMode?
      _showFieldEditor():
      _showAddButton()
    );
  }

  bool CheckIsNameValid(String name){
    if(name == "")return false;
    for(var mtd in widget.meta.clsData){
      if(mtd.cls.name == name)return false;
    }
    return true;
  }

  void EditTypeName(name){
    setState(() {
      nameHasError = !CheckIsNameValid(name);
      this.name = name;
    });
  }

  bool IsConfValid(){
    return (!nameHasError);
  }

  void AddType(){
    if(!IsConfValid())return;
    setState(() {
      var cls =  VMClassInfo(name)
        ..isReferenceType = true
        ;
            
      inEditMode = false;
      nameHasError = true;
      name = "";

      var data = widget.meta.AddType(cls);
      widget.onChange?.call(data.idx);
    });
  }

  Widget _showAddButton(){
    return TextButton(
      onPressed: (){setState(() {
        inEditMode = true;
      });},
      child: Icon(Icons.add),
    );
  }

  Widget _showFieldEditor(){

    return Container(
      height: 30,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          
          Expanded(
            child:NameField(
              hint: "Type Name",
              onChange: (name){
                EditTypeName(name);
                return !nameHasError;
              },
            )
          ),
          
          SizedBox( width: 30, height: 30,
            child: TextButton(
              onPressed: IsConfValid()?AddType:null,
              child: IsConfValid()?
              Icon(Icons.check, color: Colors.green,):
              Icon(Icons.close, color: Colors.red,),
            ),
          ),
        ],
      ),
    );
  }
}

