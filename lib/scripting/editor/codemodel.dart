import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:infcanvas/scripting/script_graph.dart';
import 'package:infcanvas/scripting/editor/vm_method_nodes.dart';
import 'package:infcanvas/scripting/shader_editor/shader_codemodel.dart';

import 'package:infcanvas/scripting/code_element.dart';
import 'codemodel_events.dart';


/// After Deserialization:
///   -> SerializedLibrary
///    +--> Deps : List<String>
///    +--> SerializedType
///    |  +--> Name : String
///    |  +--> BaseType : String
///    |  +--> IsRefType : bool
///    |  +--> Fields
///    |  |  +--> SerializedField [Name:Str, Type:Str]
///    |  |  +--> SerializedField [Name:Str, Type:Str]
///    |  |
///    |  +--> StaticFields
///    |  |  +--> SerializedField [Name:Str, Type:Str]
///    |  |  +--> SerializedField [Name:Str, Type:Str]
///    |  |
///    |  +--> Methods
///    |     +-->SerializedMethod
///    |        +--> Args
///    |        |  +--> SerializedField [Name:Str, Type:Str]
///    |        |  +--> SerializedField [Name:Str, Type:Str]
///    |        |
///    |        +--> Body : String
///    |
///    +--> SerializedType
///
/// After Reconstruction
///   -> Library
///    +--> Deps : List<Library>
///    +--> CodeType
///    |  +--> Name : String
///    |  +--> BaseType : CodeType?
///    |  +--> IsRefType : bool
///    |  +--> Fields
///    |  |  +--> CodeField [Name:Str, Type:CodeType]
///    |  |  +--> CodeField [Name:Str, Type:CodeType]
///    |  |
///    |  +--> StaticFields
///    |  |  +--> CodeField [Name:Str, Type:CodeType]
///    |  |  +--> CodeField [Name:Str, Type:CodeType]
///    |  |
///    |  +--> Methods
///    |     +-->CodeMethod
///    |        +--> Args
///    |        |  +--> CodeField [Name:Str, Type:CodeType]
///    |        |  +--> CodeField [Name:Str, Type:CodeType]
///    |        |
///    |        +--> Body : List<CodeNode>
///    |
///    +--> CodeType
///
/// So, a specialized library serializer is needed for the
/// transformation(Runtime -> Serialized form) and reconstruction
/// (Serialized -> Runtime form)
///



class _SerializedLibrary extends CodeElement{
  List<String> deps = [];
  List<_SerializedType> types = [];
}

class _SerializedType extends CodeElement{
  String baseType = "";
  bool isRefType = true;
  List<_SerializedField> fields = [];
  List<_SerializedField> staticFields = [];
  List<_SerializedMethod> methods = [];
}

class _SerializedMethod extends CodeElement{
  bool isStatic = false;
  bool isConst = false;
  List<_SerializedField> args = [];
  String body = "";
}

class _SerializedField{
  String name = "";
  String type = "";
}


class CodeLibrary extends CodeElement{

  @override
  CodeElement? get parentScope => null;

  final Set<CodeLibrary> deps = {};
  final Set<CodeType> types = {};

  @override String get fullName => name.toString();

  @override
  LibraryRenameEvent OnRename(o, n){
    return LibraryRenameEvent(o, n);
  }

  void RemoveDep(CodeLibrary dep){
    var removed = deps.remove(dep);
    if(removed){
      SendEventAlongChain(LibraryDepRemoveEvent(dep));
    }
  }

  void AddDep(CodeLibrary dep){
    var added = deps.add(dep);
    if(added){
      SendEventAlongChain(LibraryDepAddEvent(dep));
    }
  }

  void _RemoveType(CodeType ty){
    var removed = types.remove(ty);
    if(removed){
      SendEventAlongChain(LibraryTypeRemoveEvent(ty));
    }
  }

  void AddType(CodeType ty){
    var added = types.add(ty);
    if(added){
      ty.parentScope = this;
      SendEventAlongChain(LibraryTypeAddEvent(ty));
    }
  }

  void FillEvent(LibraryChangeEvent e){
    e.whichLib = this;
  }

  @override
  void DisposeElement(){
    for(var t in types){
      t.DisposeElement();
    }
    super.DisposeElement();
  }

}

///Represents the "class" elements
class CodeType extends CodeElement{
  CodeLibrary? get library => parentScope as CodeLibrary?;

  String get fullName =>
  "${library?.name??'Incomplete_Lib'}|${name}";

  late final CodeElementProperty<CodeType?> baseType
     = CodeElementProperty(null, this, (o, n)=>TypeRebaseEvent(o, n))
  ;

  bool get isImplicitConstructable => true;
  late final CodeElementProperty<bool> isRef
    = CodeElementProperty(true, this, (o, n)=>TypeStorageChangeEvent(n))
  ;

  late final CodeFieldArray fields = CodeFieldArray()
    ..parentScope = this
    ..name.value = "fields"
    ..evtForwarder = (e){
      SendEventAlongChain(TypeFieldChangeEvent(e));
    }
  ;

  late final CodeFieldArray staticFields = CodeFieldArray()
    ..parentScope = this
    ..name.value = "static fields"
    ..evtForwarder = (e){
      SendEventAlongChain(TypeStaticFieldChangeEvent(e));
    }
  ;

  final Set<CodeMethodBase> methods = {};

  @override
  TypeRenameEvent OnRename(o, n){
    return TypeRenameEvent(o, n);
  }

  void _RemoveMethod(CodeMethodBase m){
    var removed = methods.remove(m);
    if(removed)
      SendEventAlongChain(TypeMethodRemoveEvent(m));
  }

  void AddMethod(CodeMethodBase m) {
    var added = methods.add(m);
    if (added) {
      m.parentScope = this;
      SendEventAlongChain(TypeMethodAddEvent(m));
    }
  }

  CodeMethod NewMethod(String name){
    var m = CodeMethod()..name.value = name;
    AddMethod(m);
    return m;
  }

  void FillEvent(TypeChangeEvent evt){
    evt.whichType = this;
    library?.FillEvent(evt);
  }

  @override
  void DisposeElement(){
    for(var m in methods){
      m.DisposeElement();
    }
    staticFields.DisposeElement();
    fields.DisposeElement();
    super.DisposeElement();
  }

  @override
  void Dispose(){
    library?._RemoveType(this);
    super.Dispose();
  }

  bool IsSubTypeOf(CodeType? base){
    if(base == null) return false;
    CodeType? ty = this;
    while(ty != null){
      if(ty == base) return true;
      ty = ty.baseType.value;
    }
    return false;
  }
}

abstract class CodeMethodBase extends CodeElement{
  CodeType? get thisType => parentScope as CodeType?;

  @override String get fullName =>
  "${parentScope?.fullName??'Incomplete_TypeInfo'}|$name";

  bool get isEmbeddable;

  late final CodeElementProperty<bool> isStatic
    = CodeElementProperty(false, this,
        (o, n) => MethodStaticQualifierChangeEvent(n)
    );

  late final CodeElementProperty<bool> isConst
    = CodeElementProperty(false, this,
        (o, n) => MethodConstQualifierChangeEvent(n)
    );

  late final CodeFieldArray args
    = CodeFieldArray()
      ..parentScope = this
      ..name.value = "arguments"
      ..evtForwarder = (e){
        var evt = MethodArgChangeEvent(e);
        SendEventAlongChain(evt);
      }
    ;
  late final CodeFieldArray rets
    = CodeFieldArray()
      ..parentScope = this
      ..name.value = "returns"
      ..evtForwarder = (e){
        var evt = MethodReturnChangeEvent(e);
        SendEventAlongChain(evt);
      }
  ;

  @override
  MethodRenameEvent OnRename(o, n) => MethodRenameEvent(o, n);

  void FillEvent(MethodChangeEvent evt){
    evt.whichMethod = this;
    thisType?.FillEvent(evt);
  }

  @override
  void DisposeElement(){
    args.DisposeElement();
    rets.DisposeElement();
    super.DisposeElement();
  }

  @mustCallSuper @override
  void Dispose(){
    thisType?._RemoveMethod(this);
    super.Dispose();
  }
}

class CodeMethod extends CodeMethodBase{
  //Either entry or return
  CodeGraphNode? root;
  List<CodeGraphNode> body = [];
  Map<CodeGraphNode, List<String>> nodeMessage = {};

  @override get isEmbeddable => false;

  CodeMethod(){}

  void CreateBody(){
    var ent = CodeEntryNode(this);
    var ret = CodeReturnNode(this);
    var lnk = GraphEdge(ent.execOut, ret.execIn);
    ent.execOut.ConnectLink(lnk);
    ret.execIn.ConnectLink(lnk);
    root = ent;
    body.add(ret);

    ret.ctrl.dx = ret.ctrl.dx! + 400;
  }
}

class CodeFieldArray extends CodeElement{
  void Function(FieldArrayChangeEvent)? evtForwarder;


  @override String get fullName =>
      "${parentScope?.fullName??'Incomplete_TypeInfo'}";

  List<CodeField> fields = [];

  int get length => fields.length;

  void Clear(){
    for(var f in fields){
      f.DisposeElement();
    }
    fields.clear();
  }

  void _RemoveField(CodeField which){
    fields.remove(which);
    var evt = FieldRemoveEvent(which);
    evt.originator = this;
    evt.whichArray = this;
    evt.originalEvent = evt;
    ForwardEvent(evt);
  }

  CodeField NewField([String name = ""]){
    var f = CodeField(name);
    AddField(f);
    return f;
  }

  void AddField(CodeField f){
    f.parentScope = this;
    f.index = fields.length;
    fields.add(f);
    var evt = FieldAddEvent(f);
    evt.originator = this;
    evt.whichArray = this;
    evt.originalEvent = evt;
    ForwardEvent(evt);
  }

  @override
  void ForwardEvent(FieldArrayChangeEvent evt){
    super.ForwardEvent(evt);
    evtForwarder?.call(evt);
  }

  @override
  void DisposeElement(){
    Clear();
    super.DisposeElement();
  }

}

class CodeField extends CodeElement{

  CodeType? _type;

  static final CodeField emptyField = CodeField("Empty", -1);
  CodeType? get type => _type;

  @override String get fullName =>
      "${parentScope?.fullName??'Incomplete_TypeInfo'}|$name";

  late var _ob = Observer("${fullName}_ob");

  int index;

  CodeFieldArray? get array => parentScope as CodeFieldArray?;

  CodeField([String name = "", this.index = 0]){
    this.name.value = name;
  }

  set type(CodeType? val){
    if(_type == val) return;
    var oldTy = _type;
    ClearType();
    _type = val;
    AddWatcher();
    _SendTyChgEvt(oldTy, val);
  }

  @override
  FieldRenameEvent OnRename(o, n){
    var evt = FieldRenameEvent(o, n);
    evt.originator = this;
    evt.originalEvent = evt;
    return evt;
  }

  void ClearType(){
    if(_type == null) return;
    _ob.StopWatching(_type!);
    _type = null;
  }

  void AddWatcher(){
    if(_type == null) return;
    _ob.Watch<ElementDisposeEvent>(_type!, (e){
      var oldTy = _type;
      _type = null;
      _SendTyChgEvt(oldTy, null);
    });
  }

  void _SendTyChgEvt(oldType, newType){
    var evt = FieldTypeChangeEvent(oldType, newType);
    evt.originalEvent = evt;
    SendEventAlongChain(evt);
  }

  @override
  void Dispose(){
    _ob.Dispose();
    array?._RemoveField(this);
    super.Dispose();
  }
}
