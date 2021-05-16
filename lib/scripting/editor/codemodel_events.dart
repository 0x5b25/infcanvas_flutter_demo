
import 'codemodel.dart';
import 'package:infcanvas/scripting/code_element.dart';

///Events:
class LibraryChangeEvent extends CodeElementChangeEvent{
  late CodeLibrary whichLib;
}

class LibraryDepRemoveEvent extends LibraryChangeEvent{
  CodeLibrary removedDep;
  LibraryDepRemoveEvent(this.removedDep);
}
class LibraryDepAddEvent extends LibraryChangeEvent{
  CodeLibrary addedDep;
  LibraryDepAddEvent(this.addedDep);
}

class LibraryRenameEvent extends TypeChangeEvent{
  String oldValue, newValue;
  LibraryRenameEvent(this.oldValue, this.newValue);
}

class LibraryTypeRemoveEvent extends LibraryChangeEvent{
  CodeType removedType;
  LibraryTypeRemoveEvent(this.removedType);
}
class LibraryTypeAddEvent extends LibraryChangeEvent{
  CodeType addedType;
  LibraryTypeAddEvent(this.addedType);
}

///Types
class TypeChangeEvent extends LibraryChangeEvent{
  late CodeType whichType;
}

class TypeRenameEvent extends TypeChangeEvent{
  String oldValue, newValue;
  TypeRenameEvent(this.oldValue, this.newValue);
}

class TypeStorageChangeEvent extends TypeChangeEvent{
  bool isRef;
  TypeStorageChangeEvent(this.isRef);
}

class TypeRebaseEvent extends TypeChangeEvent{
  CodeType? oldBaseType, newBaseType;
  TypeRebaseEvent(this.oldBaseType, this.newBaseType);
}

class TypeFieldStructChangeEvent extends TypeChangeEvent{
  TypeFieldStructChangeEvent(Event originalEvent)
  {
    this.originalEvent = originalEvent;
  }
}
class TypeStaticFieldChangeEvent extends TypeFieldStructChangeEvent{
  TypeStaticFieldChangeEvent(originalEvent) : super(originalEvent);
}
class TypeFieldChangeEvent extends TypeFieldStructChangeEvent{
  TypeFieldChangeEvent(originalEvent) : super(originalEvent);
}


class TypeMethodAddEvent extends TypeChangeEvent{
  CodeMethodBase whichMethod;
  TypeMethodAddEvent(this.whichMethod);
}
class TypeMethodRemoveEvent extends TypeChangeEvent{
  CodeMethodBase whichMethod;
  TypeMethodRemoveEvent(this.whichMethod);
}

///Methods
class MethodChangeEvent extends TypeChangeEvent{
  late CodeMethodBase whichMethod;
}

class MethodBodyChangeEvent extends MethodChangeEvent{}

class MethodRenameEvent extends MethodChangeEvent{
  String oldValue, newValue;
  MethodRenameEvent(this.oldValue, this.newValue);
}
///Signature
class MethodSignatureChangeEvent extends MethodChangeEvent{
  MethodSignatureChangeEvent(Event originalEvent){
    this.originalEvent = originalEvent;
  }
}

class MethodArgChangeEvent extends MethodSignatureChangeEvent{
  MethodArgChangeEvent(originalEvent):super(originalEvent);
}

class MethodReturnChangeEvent extends MethodSignatureChangeEvent{
  MethodReturnChangeEvent(originalEvent):super(originalEvent);
}

///Qualifiers
class MethodQualifierChangeEvent extends MethodChangeEvent{
  bool value;
  MethodQualifierChangeEvent(this.value);
}
class MethodConstQualifierChangeEvent
    extends MethodQualifierChangeEvent{
  bool get isConst => value;
  MethodConstQualifierChangeEvent(value):super(value);

}
class MethodStaticQualifierChangeEvent
    extends MethodQualifierChangeEvent{
  bool get isStatic => value;
  MethodStaticQualifierChangeEvent(value):super(value);
}
//We don't concern about body change for now

///Field changes
class FieldArrayChangeEvent extends CodeElementChangeEvent{
  late CodeFieldArray whichArray;
}
class FieldAddEvent extends FieldArrayChangeEvent{
  CodeField field;
  FieldAddEvent(this.field);
}
class FieldRemoveEvent extends FieldArrayChangeEvent{
  CodeField field;
  FieldRemoveEvent(this.field);
}

class FieldChangeEvent extends FieldArrayChangeEvent{
  late CodeField whichField;
}

class FieldRenameEvent extends FieldChangeEvent{
  String oldName, newName;
  FieldRenameEvent(this.oldName, this.newName);
}
class FieldTypeChangeEvent extends FieldChangeEvent{
  CodeType? oldType, newType;
  FieldTypeChangeEvent(this.oldType, this.newType);
}
