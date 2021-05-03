import 'dart:ffi';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:infcanvas/widgets/scripting/vm_graphnodes.dart';
import 'package:infcanvas/utilities/scripting/script_graph.dart';
import 'package:infcanvas/widgets/functional/editor_widgets.dart';

import 'method_editor.dart';
import 'lib_inspector.dart';
import 'vm_editor_data.dart';
//List<String> _getAvailTypes(){
//    return ["Num|Int", "Num|Float", "Num|Vec3"];
//  }

List<DropdownMenuItem<String>> _ty2MenuItem(List<String> ty){
  return ty.map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList();
}

bool _checkTyAvail(String ty, List<String> types){
  return types.contains(ty);
}


class EditorClassInfoHolder extends InheritedNotifier<ChangeNotifier>{

  EditorClassData classData;

  EditorClassInfoHolder({
    Key? key,
    required this.classData,
    required Widget child
  }):
  super(key: key, child: child, notifier: ChangeNotifier()){

  }

  void NotifyUpdate(){
    notifier?.notifyListeners();
  }


  static EditorClassInfoHolder? of(BuildContext ctx){
    return ctx.dependOnInheritedWidgetOfExactType<EditorClassInfoHolder>();
  }
}


class FieldInspector extends StatefulWidget{

  VMFieldHolder field;
  bool canEdit;
  String? name;
  void Function(VMField)? onChange, onAdd, onRemove;

  FieldInspector(this.field, {this.name,
    this.onAdd, this.onChange, this.onRemove,
    this.canEdit = true,
  }){}

  @override
  _FieldInspectorState createState() => _FieldInspectorState();
}

class _FieldInspectorState extends State<FieldInspector> {

  bool _inEditMode = false;

  @override
  Widget build(BuildContext ctx){
    var holder = EditorClassInfoHolder.of(context);
    var availTy = holder!.classData.lib.Types().toList();
    return ListEditor(
      title: widget.name??"",
      listToEdit: FieldManInterface(this, availTy),
      canEdit: widget.canEdit,
    );

  }
}


class FieldManInterface extends ListInterface{

  _FieldInspectorState state;
  FieldInspector get widget =>state.widget;

  VMFieldHolder get field => widget.field;
  List<String> availableTypes;
  FieldManInterface(this.state, this.availableTypes);

  late EditorClassInfoHolder holder;
  @override
  void Init(BuildContext ctx){
    holder = EditorClassInfoHolder.of(ctx)!;
  }

  @override
  void AddEntry(TemplateFieldEntry entry) {
    field.AddField(entry.name, entry.type);
    widget.onAdd?.call(field.GetField(field.FieldCount() - 1));
    holder.NotifyUpdate();
  }

  @override
  void RemoveEntry(FieldEntry entry) {
    widget.onRemove?.call(entry.field);
    field.RemoveField(entry.field.idx);
    holder.classData.NotifyStructureChange();
    holder.NotifyUpdate();
  }

  @override
  ListEditEntry doCreateEntryTemplate() {
    return TemplateFieldEntry();
  }

  @override
  Iterable<FieldEntry> doGetEntry()sync* {
    for(var f in field.fields){
      yield FieldEntry(f);
    }
  }

}

abstract class FieldEntryBase extends ListEditEntry{

  FieldManInterface get interface => iface as FieldManInterface;

  String get name;
  set name(String val);

  String get type;
  set type(String val);

  @override
  bool CanEdit() => true;

  @override
  Iterable<ListEntryProperty> EditableProps(BuildContext ctx) {
    return[
      if(!IsConfigValid())
        StatusIndicator(EntryStatus.Error),

      StringProp((n)=>EditFieldName(ctx,n),
        initialContent: name,
        hint: "Field Name"
      ),
      SelectionProp<String>(
        requestSelections: ()=>interface.availableTypes,
        onSelect: (ty){
          type = ty??"";
          InvokeChangeCallback(ctx);
          EditorClassInfoHolder.of(ctx)!.NotifyUpdate();
        },
        initialValue: type
      )
    ];
  }

  void InvokeChangeCallback(BuildContext ctx){}

  @override
  bool IsConfigValid() {
    return ValidateName(name) && ValidateType(type);
  }

  bool ValidateType(String type){
    if(type == "") return false;
    if(interface.availableTypes.contains(type))return true;
    return false;
  }

  bool ValidateName(String name);

  bool EditFieldName(BuildContext ctx, String newName);

}

class FieldEntry extends FieldEntryBase{

  VMField field;
  FieldEntry(this.field);

  String get name => field.name;
  set name(String val){field.name = val;}

  String get type => field.type;
  set type(String val){field.type = val;}

  

  bool ValidateName(String name){
    if(name == "")return false;
    for(var f in interface.field.fields){
      if(f.IsSame(field))continue;
      if(f.name == name){return false;}
    }
    return true;
  }

  @override
  bool EditFieldName(ctx, String newName) {
    bool valid = ValidateName(newName);
    if(valid){
      field.name = newName;
      InvokeChangeCallback(ctx);
      EditorClassInfoHolder.of(ctx)!.NotifyUpdate();
    }
    return valid;
  }

  @override
  void InvokeChangeCallback(ctx){
    EditorClassInfoHolder.of(ctx)!.classData.NotifyStructureChange();
    interface.widget.onChange?.call(field);
  }

}


class TemplateFieldEntry extends FieldEntryBase{

  TemplateFieldEntry();

  String name = "";
  
  String type = "";


  bool ValidateName(String name){
    if(name == "")return false;
    for(var f in interface.field.fields){
      if(f.name == name){return false;}
    }
    return true;
  }

  @override
  bool EditFieldName(ctx, String newName) {
    name = newName;
    return ValidateName(newName);
  }

}


class MethodManInterface extends ListInterface{

  EditorClassData meta;
  //void Function() notifyChange;

  MethodManInterface(this.meta);

  late EditorClassInfoHolder holder;

  @override
  void Init(ctx){
    holder =  EditorClassInfoHolder.of(ctx)!;
  }

  @override
  void AddEntry(TemplateMethodEntry entry) {

    meta.AddMethod(entry.newMtd);
    
    holder.NotifyUpdate();
  }
  
  @override
  void RemoveEntry(MethodEntry entry) {
    meta.RemoveMethod(entry.md);
    holder.NotifyUpdate();

  }

  @override
  TemplateMethodEntry doCreateEntryTemplate() {
    return TemplateMethodEntry();
  }

  @override
  Iterable<MethodEntry> doGetEntry()sync* {
    for(var d in meta.methodData){
      yield MethodEntry(d);
    }
  }

}

abstract class MethodEntryBase extends ListEditEntry{

  bool canEdit;

  MethodEntryBase(this.canEdit);

  //VMMethodInfo get mtd;
  MethodManInterface get interface => iface as MethodManInterface;
  String get name;
  set name(String name);

  bool get isStatic;
  set isStatic(bool val);
  
  bool get isConstant;
  set isConstant(bool val);

  bool get hasError;
  bool get isValid;

  @override
  bool CanEdit() => canEdit;

  @override
  Iterable<ListEntryProperty> EditableProps(ctx) {
    var statIcon = 
      hasError?StatusIndicator(EntryStatus.Error):
      isValid?StatusIndicator(EntryStatus.Normal):
      StatusIndicator(EntryStatus.Unknown);

    return [
      statIcon,

      StringProp(
        (s){return EditMethodName(s, ctx);},
        initialContent: name,
        hint: "Method name",
      ),
      BoolProp("S", isStatic, 
        (val){
          isStatic = val;
          var holder = EditorClassInfoHolder.of(ctx)!;
          holder.classData.NotifyStructureChange();
          holder.NotifyUpdate();
        }
      ),
      BoolProp("C", isConstant, 
        (val){
          isConstant = val;
          var holder = EditorClassInfoHolder.of(ctx)!;
          holder.classData.NotifyStructureChange();
          holder.NotifyUpdate();
        }
      )
    ];
  }

  @override
  bool IsConfigValid()=>CheckIsNameValid(name);

  
  bool CheckIsNameValid(String name){
    if(name == "")return false;
    for(var mtd in interface.meta.cls.methods){
      if(mtd.IsSame(mtd)) continue;
      if(mtd.name == name)return false;
    }
    return true;
  }

  bool EditMethodName(String newName, BuildContext ctx){
    var valid = CheckIsNameValid(newName);
    if(valid){
      name = newName;
      var holder = EditorClassInfoHolder.of(ctx)!;
      holder.classData.NotifyStructureChange();
      holder.NotifyUpdate();
    }
    return valid;
  }
}

class MethodEntry extends MethodEntryBase{
  EditorMethodData md;

  MethodEntry(this.md, {bool canEdit = true})
    :super(canEdit){

  }

  @override
  VMMethodInfo get mtd => md.mtd;

  @override
  bool get hasError => md.hasError;

  @override
  bool get isValid => md.isBodyValid;

  @override bool get isConstant => md.isConstant;
  @override      set isConstant(val) => md.isConstant = val;

  @override bool get isStatic => md.isStatic;
  @override      set isStatic(val) => md.isStatic = val;

  @override String get name => md.mtd.name;
  @override        set name(String val) => md.mtd.name = val;

}

class TemplateMethodEntry extends MethodEntryBase{
  VMMethodInfo newMtd = VMMethodInfo("");

  TemplateMethodEntry() : super(true){
  }

  @override
  VMMethodInfo get mtd => newMtd;
  
  @override
  bool EditMethodName(String name, BuildContext ctx){
    newMtd.name = name;
    return IsConfigValid();
  }

  @override
  bool get hasError => !IsConfigValid();

  @override
  bool get isValid => false;

  @override bool get isConstant => mtd.isConstantMethod;
  @override      set isConstant(val) => mtd.isConstantMethod = val;

  @override bool get isStatic => mtd.isStaticMethod;
  @override      set isStatic(val) => mtd.isStaticMethod = val;

  @override String get name => mtd.name;
  @override        set name(String val) => mtd.name = val;


}

class ClassInspector extends StatefulWidget {
  
  EditorClassData cls;
  bool canEditMethod;
  bool canEditFields;
  bool canEditStaticFields;

  ClassInspector(this.cls,
  {
    this.canEditFields = true,
    this.canEditStaticFields = true,
    this.canEditMethod = true,
  });


  @override
  _ClassInspectorState createState() => _ClassInspectorState();
}

class _ClassInspectorState extends State<ClassInspector> {

  EditorMethodData? _selectedMeta;

  bool _inEditMode = false;

  //late EditorClassInfoHolder holder = EditorClassInfoHolder.of(context)!;

  @override 
  void initState(){
    super.initState();
  }

  @override
  void dispose(){
    super.dispose();
  }

  bool SetClassName(String newName){
    return false;
  }

  void SetClassParent(String newParent){

  }

  @override
  Widget build(BuildContext context) {
    var meta = widget.cls;
    return Material(
      child: EditorClassInfoHolder(
        classData: widget.cls,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 300,
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,

                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(meta.cls.name, style: Theme.of(context).textTheme.headline5,),

                        Divider(),
                        //Text("Fields", style: Theme.of(context).textTheme.bodyText1,),
                        Card(
                          child: FieldInspector(
                            meta.cls.Fields(), 
                            name:"Fields", 
                            canEdit: widget.canEditFields,
                          ),
                        ),

                        //Text("StaticFields", style: Theme.of(context).textTheme.bodyText1,),
                        Card(
                          child: FieldInspector(
                            meta.cls.StaticFields(),
                            name:"StaticFields",
                            canEdit: widget.canEditStaticFields,
                          )
                        ),

                        
                        Card(
                          child: ListEditor(
                            title: "Methods",
                            listToEdit: MethodManInterface(meta),
                            onSelect: (e){
                              var m = e as MethodEntry;
                              SelectMethod(m.md);
                            },
                            canEdit: widget.canEditMethod,
                          ),
                        )

                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: (){
                      Navigator.of(context).pop();
                    }, 
                    child: Text("Back")
                  ),
                ],
              )
            ),
            Expanded(
              child: Container(
                child: (_selectedMeta == null)?null:
                  MethodEditor(_selectedMeta!, canEditSig:widget.canEditMethod),
              )
            )
          ],
        ),
      ),
    );
  }

  void SelectMethod(EditorMethodData? md){
    if(md == _selectedMeta) return;

    setState(() {
      //if(_selectedMeta != null){
      //  _selectedMeta!.removeListener(UpdateCodeChange);
      //}
      _selectedMeta = md;
      //if(_selectedMeta != null){
      //  _selectedMeta!.addListener(UpdateCodeChange);
      //}
    });
  }

  void UpdateCodeChange(){
    setState(() {
      
    });
  }
}
