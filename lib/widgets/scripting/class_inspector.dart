import 'dart:ffi';
import 'dart:ui';
import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart';
import 'package:infcanvas/utilities/scripting/graphnodes.dart';
import 'package:infcanvas/utilities/scripting/script_graph.dart';
import 'package:infcanvas/widgets/functional/text_input.dart';

import 'method_inspector.dart';
import 'lib_editor.dart';

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



///Binds to classinfo.
///Available node queries:
/// +--------------------------
/// | Misc : Control flow
/// |         |
/// +---------+----------------------
/// | Library |--> Lib.queryNodes
/// +---------+  |
/// | Class   |  +--> Field accessors
/// |         |  |
/// |         |  +--> This reference access
/// +---------+     |
/// | Method  |     +--> Entry, Return
/// +---------+---------------------
/// 


class EditorClassData{
  EditorLibData lib;
  int idx;
  VMClassInfo get cls => lib.lib.GetClassInfo(idx);

  List<EditorMethodData> methodData = [];

  EditorClassData(this.lib, this.idx){
    for(int i = 0; i < cls.MethodInfoCnt(); i++){
      methodData.add(EditorMethodData(this, i));
    }
  }

  void NotifyMethodChange(int idx){

  }

  void RemoveMethod(EditorMethodData mtd){
    cls.RemoveMethod(mtd.mtdIdx);
    methodData.remove(mtd);
  }

  EditorMethodData AddMethod(VMMethodInfo mtd){
    int idx = cls.MethodInfoCnt();
    cls.AddMethod(mtd);
    methodData.add(EditorMethodData(this, idx));
    return methodData.last;
  }

  //TODO: node query, type inheritance lookup
  Iterable<NodeSearchInfo> FindMatchingNode(String? argType, String? retType)
  sync* {
    //Method calls and control flow
    yield* lib.FindMatchingNode(argType, retType);

    //Getters and setters
    for(var f in cls.Fields().fields){

    }
  }

}





class FieldNameEditor extends StatelessWidget{
  VMFieldHolder field;
  int idx;
  void Function(VMFieldHolder, int)? onChange;

  FieldNameEditor(this.field, this.idx, this.onChange){
        
  }

  @override
  Widget build(BuildContext context) {
    return NameField(
      initialText: field.GetName(idx),
      onChange: (name){
        return EditFieldName(idx, name);
      },
    );
  }
  
  bool EditFieldName(int idx, String name){
    assert(idx < field.FieldCount() && idx >= 0);

    if(name == "")return false;
    for(int i = 0; i < field.FieldCount(); i++){
      if(i == idx) continue;
      if(field.GetName(i) == name){return false;}
    }
  
    field.SetName(idx, name);
    onChange?.call(field, idx);
  
    return true;
  }
}

class NewFieldButton extends StatefulWidget {
  VMFieldHolder field;
  void Function(VMFieldHolder, int)? onChange;

  NewFieldButton(this.field, this.onChange);
  @override
  _NewFieldButtonState createState() => _NewFieldButtonState();
}

class _NewFieldButtonState extends State<NewFieldButton> {
  bool inEditMode = false;
  bool nameHasError = true;
  bool typeHasError = true;
  String name = "", type  ="";

  late EditorInfoHolder holder = EditorInfoHolder.of(context)!;
  @override
  void initState(){
    super.initState();
  }

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
    for(int i = 0; i < widget.field.FieldCount(); i++){
      if(widget.field.GetName(i) == name)return false;
    }
    return true;
  }

  void EditFieldName(name){
    setState(() {
      nameHasError = !CheckIsNameValid(name);
      this.name = name;
    });
  }

  bool IsFieldConfValid(){
    return (!nameHasError) && (!typeHasError);
  }

  void AddField(){
    if(!IsFieldConfValid())return;
    setState(() {
      widget.field.AddField(name, type);
      widget.onChange?.call(widget.field, widget.field.FieldCount()-1);      
    
      inEditMode = false;
      nameHasError = true;
      typeHasError = true;
      name = "";
      type  ="";
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
    var availTy =  holder.libData.Types().toList();
    return Container(
      height: 30,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          
          Expanded(
            child:NameField(
              hint: "Field Name",
              onChange: (name){
                EditFieldName(name);
                return !nameHasError;
              },
            )
          ),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton(
                isExpanded: true,
                hint: Text("Field Type"),
                value: _checkTyAvail(type,availTy)?type:null,
                onChanged: (String? newValue) {
                  setState(() {
                    type = newValue??"";
                    typeHasError = false;
                  });
                },
                items: _ty2MenuItem(availTy),
              ),
            )
          ),
          SizedBox( width: 30, height: 30,
            child: TextButton(
              onPressed: IsFieldConfValid()?AddField:null,
              child: IsFieldConfValid()?
              Icon(Icons.check, color: Colors.green,):
              Icon(Icons.close, color: Colors.red,),
            ),
          ),
        ],
      ),
    );
  }

}

class FieldInspector extends StatefulWidget{

  VMFieldHolder field;
  String? name;
  void Function(VMFieldHolder, int)? onChange;

  FieldInspector(this.field, {this.name, this.onChange}){}

  @override
  _FieldInspectorState createState() => _FieldInspectorState();
}

class _FieldInspectorState extends State<FieldInspector> {

  bool _inEditMode = false;

  @override
  Widget build(BuildContext ctx){

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4),
          child: SizedBox(
            height: 30,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if(widget.name != null)
                  Expanded(child: Text(widget.name!)),
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

        Flexible(
          child: ListView(
            shrinkWrap: true,
            children: [
              for(int i = 0; i < widget.field.FieldCount();i++)
                Padding(
                  padding: const EdgeInsets.only(bottom:4.0),
                  child: Container(
                    height: 30,
                    child: _inEditMode?_buildEditingEntry(i):_buildNormalEntry(i)
                  ),
                ),
            ]
          ),
        ),
        if(_inEditMode)NewFieldButton(
          widget.field, 
          (f, i){
            setState(
              (){
                widget.onChange?.call(f,i);
              }
            );
          }
        ),
      ],
    );

  }

  Widget _buildNormalEntry(int idx){
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child:Text(widget.field.GetName(idx))),
        Text(
          widget.field.GetType(idx),
          style:TextStyle(fontStyle: FontStyle.italic),
        ),
      ],
    );
  }

  

  Widget _buildEditingEntry(int idx){
    var holder = EditorInfoHolder.of(context);
    var availTy = holder!.libData.Types().toList();
    var oldTy = widget.field.GetType(idx);
    

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox( width: 30, height: 30,
          child: TextButton(
            onPressed: (){RemoveField(idx);},
            child: Icon(Icons.delete, color: Colors.red,),
          ),
        ),
        Expanded(
          child:FieldNameEditor(widget.field, idx, widget.onChange),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: DropdownButtonHideUnderline(
              child: DropdownButton(
                isExpanded: true,
                value: _checkTyAvail(oldTy,availTy)?oldTy:null,
                onChanged: (String? newValue) {
                  EditFieldType(idx, newValue!);
                },
                items: _ty2MenuItem(availTy),
              ),
            ),
          )
        ),
      ],
    );
  }

  void RemoveField(int idx){
    assert(idx < widget.field.FieldCount() && idx >= 0);
    setState(() {
      widget.field.RemoveField(idx);
      widget.onChange?.call(widget.field, idx);
    });
    
  }


  void EditFieldType(int idx, String type){
    assert(idx < widget.field.FieldCount() && idx >= 0);
    setState(() {
      widget.field.SetType(idx, type);
      widget.onChange?.call(widget.field, idx);
    });
  }
  
  void AddField(String name, String type){
    setState(() {
      widget.field.AddField(name, type);
      widget.onChange?.call(widget.field, widget.field.FieldCount()-1);      
    });
  }
}


class NewMethodButton extends StatefulWidget {

  void Function(int)? onChange;
  EditorClassData meta;

  NewMethodButton(this.meta, {Key? key, this.onChange});

  @override
  _NewMethodButtonState createState() => _NewMethodButtonState();
}

class _NewMethodButtonState extends State<NewMethodButton> {
  bool inEditMode = false;
  bool nameHasError = true;
  String name = "";
  bool isStatic = false;
  bool isConst = false;
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
    for(var mtd in widget.meta.methodData){
      if(mtd.mtd.name == name)return false;
    }
    return true;
  }

  void EditMethodName(name){
    setState(() {
      nameHasError = !CheckIsNameValid(name);
      this.name = name;
    });
  }

  bool IsConfValid(){
    return (!nameHasError);
  }

  void AddMethod(){
    if(!IsConfValid())return;
    setState(() {
      var mtd =  VMMethodInfo(name)
          ..isStaticMethod = isStatic
          ..isConstantMethod = isConst
          ;
            
      inEditMode = false;
      nameHasError = true;
      name = "";
      isStatic = false;
      isConst = false;

      var data = widget.meta.AddMethod(mtd);
      widget.onChange?.call(data.mtdIdx);
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
              hint: "Method Name",
              onChange: (name){
                EditMethodName(name);
                return !nameHasError;
              },
            )
          ),
          
          SizedBox( width: 30, height: 30,
            child: TextButton(
              onPressed: (){setState((){isStatic = !isStatic;});},
              child: Text("S",
                style: isStatic?
                TextStyle(color: Colors.green):
                TextStyle(color: Colors.grey),
              )
            ),
          ),
          SizedBox( width: 30, height: 30,
            child: TextButton(
              onPressed: (){setState((){isConst = !isConst;});},
              child: Text("C",
                style: isConst?
                TextStyle(color: Colors.green):
                TextStyle(color: Colors.grey),
              )
            ),
          ),

          SizedBox( width: 30, height: 30,
            child: TextButton(
              onPressed: IsConfValid()?AddMethod:null,
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

class MethodSigEditor extends StatefulWidget {

  void Function()? onChange;
  void Function()? onDelete;
  bool Function(String) nameValidator;
  EditorMethodData md;

  MethodSigEditor(
    this.md, 
    this.nameValidator,
    {Key? key, this.onChange, this.onDelete}
  );

  @override
  _MethodSigEditorState createState() => _MethodSigEditorState();
}

class _MethodSigEditorState extends State<MethodSigEditor> {

  @override
  Widget build(BuildContext context) {
    var mtd = widget.md.mtd;
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
            hint: "Method Name",
            initialText: mtd.name,
            onChange: (name){
              return EditMethodName(mtd, name);
            },
          )
        ),
        
        SizedBox( width: 30, height: 30,
          child: TextButton(
            onPressed: (){
              setState(() {
                mtd.isStaticMethod = !mtd.isStaticMethod;
                widget.onChange?.call();
              });
            },
            child: Text("S",
              style: mtd.isStaticMethod?
              TextStyle(color: Colors.green):
              TextStyle(color: Colors.grey),
            )
          ),
        ),
        SizedBox( width: 30, height: 30,
          child: TextButton(
            onPressed: (){
              setState(() {
                mtd.isConstantMethod = !mtd.isConstantMethod;
                widget.onChange?.call();
              });
            },
            child: Text("C",
              style: mtd.isConstantMethod?
              TextStyle(color: Colors.green):
              TextStyle(color: Colors.grey),
            )
          ),
        ),

        
      ],
    );
  }

  bool EditMethodName(VMMethodInfo mtd, String name){
    var valid = widget.nameValidator(name);
    if(valid){
      mtd.name = name;
      widget.onChange?.call();
    }
    return valid;
  }

}

class MethodInspector extends StatefulWidget {

  void Function(int)? onChange;
  void Function(EditorMethodData?)? onSelect;
  EditorClassData meta;


  MethodInspector(this.meta,{Key? key, this.onChange, this.onSelect}):super(key: key);

  @override
  _MethodInspectorState createState() => _MethodInspectorState();
}

class _MethodInspectorState extends State<MethodInspector> {

  bool _inEditMode = false;
  EditorMethodData? selected;

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
                Expanded(child: Text("Methods")),
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
        for(var md in widget.meta.methodData)
          Padding(
            padding: const EdgeInsets.only(bottom:4.0),
            child: Container(
              height: 30,
              child: _inEditMode?_buildEditingEntry(md):_buildNormalEntry(md),
            ),
          ),
        if(_inEditMode)NewMethodButton(widget.meta, onChange:widget.onChange),
      ],
    );
  }

  

  _buildEditingEntry(EditorMethodData md) {
    return MethodSigEditor(md,CheckIsNameValid,
      onChange: (){widget.onChange?.call(md.mtdIdx);},
      onDelete: (){RemoveMethod(md);},
    );
    
  }

  _buildNormalEntry(EditorMethodData md) {
    var mtd = md.mtd;
    var selColor = Theme.of(context).primaryColor.withOpacity(0.2);
    return GestureDetector(
      onTap: (){SelectFocusMethod(md);},
      child: Container(
        color: md == selected?selColor:null,
        child: Row(
          children: [
            Expanded(child: Text(mtd.name)),
            SizedBox(width: 30,
              child: mtd.isStaticMethod?Text("S"):null,
            ),
            SizedBox(width: 30,
              child: mtd.isConstantMethod?Text("C"):null,
            ),
          ],
        ),
      ),
    );
  }

  void SelectFocusMethod(EditorMethodData? md){
    setState(() {
      selected = md;
    });
    widget.onSelect?.call(md);
  }

  bool CheckIsNameValid(String name){
    if(name == "")return false;
    for(var mtd in widget.meta.cls.methods){
      if(mtd.name == name)return false;
    }
    return true;
  } 


  void RemoveMethod(EditorMethodData md){
    if(md == selected)SelectFocusMethod(null);
    widget.meta.RemoveMethod(md);
    widget.onChange?.call(md.mtdIdx);      
  }
}

class ClassInspector extends StatefulWidget {
  
  EditorClassData cls;
  void Function() requestExit;

  ClassInspector(this.cls, this.requestExit);


  @override
  _ClassInspectorState createState() => _ClassInspectorState();
}

class _ClassInspectorState extends State<ClassInspector> {

  EditorMethodData? _selectedMeta;

  bool _inEditMode = false;

  late EditorInfoHolder holder = EditorInfoHolder.of(context)!;

  @override 
  void initState(){
    super.initState();
  }

  bool SetClassName(String newName){
    return false;
  }

  void SetClassParent(String newParent){

  }

  @override
  Widget build(BuildContext context) {
    var meta = widget.cls;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: 300,
          color: Colors.white,
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
                  onChange: (f,i){holder.NotifyUpdate();},
                ),
              ),

              //Text("StaticFields", style: Theme.of(context).textTheme.bodyText1,),
              Card(child: FieldInspector(meta.cls.StaticFields(), name:"StaticFields", onChange: (f,i){holder.NotifyUpdate();})),

              //Text("Methods", style: Theme.of(context).textTheme.bodyText1,),
              Card(
                child: MethodInspector(
                  meta,
                  onChange: (i){holder.NotifyUpdate();},
                  onSelect: (meta){setState(() {
                    _selectedMeta = meta;
                  });},
                )
              ),

              ElevatedButton(onPressed: widget.requestExit, child: Text("Back")),
            ],
          )
        ),
        Expanded(
          child: 
          _selectedMeta == null?Container():
            MethodEditor(_selectedMeta!, onChange:(m){holder.NotifyUpdate();}),
        )
      ],
    );
  }
}
