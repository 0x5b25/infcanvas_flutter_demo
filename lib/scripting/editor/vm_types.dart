
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:infcanvas/scripting/graph_compiler.dart';
import 'package:infcanvas/scripting/editor_widgets.dart';
import 'package:infcanvas/scripting/codepage.dart';
import 'package:infcanvas/scripting/editor/codemodel.dart';

import 'vm_opcodes.dart';
import '../script_graph.dart';

class BuiltinLib extends CodeLibrary{
  final VMLibInfo lib;
  @override get editable => false;

  BuiltinLib(this.lib){
    name.value = lib.name;
    for(var ty in lib.types){
      var t = BuiltinType(ty);
      t.parentScope = this;
      types.add(t);
    }
  }

  @override final Set<BuiltinLib> deps = {};
  @override final Set<BuiltinType> types = {};
}

class BuiltinType extends CodeType{
  VMClassInfo cls;
  @override get editable => false;

  BuiltinType(this.cls)
    :isImplicitConstructable = cls.isImplicitConstructable
  {
    name.value = cls.name;
    isRef.value = cls.isReferenceType;
    for(var mtd in cls.methods){
      var m = BuiltinMethod(mtd);
      m.parentScope = this;
      methods.add(m);
    }
  }

  @override final Set<BuiltinMethod> methods = {};
  @override final bool isImplicitConstructable;

}

class BuiltinMethod extends CodeMethodBase{
  VMMethodInfo mtd;
  BuiltinMethod(this.mtd)
    :isEmbeddable = mtd.embeddable
  {
    name.value = mtd.name;
    isStatic.value = mtd.isStaticMethod;
    isConst.value = mtd.isConstantMethod;
  }

  @override final isEmbeddable;
}

//TODO: load builtin libs from vm proxy
// settles for now
class VMBuiltinTypes {

  static final _instance = VMBuiltinTypes._();
  final Map<String, CodeType> _types = {};
  final List<BuiltinLib> _rtLibs = [],
      _renderLibs = [];

  Iterable<BuiltinLib> get _libs sync* {
    yield* _rtLibs;
    yield* _renderLibs;
  }

  VMBuiltinTypes._(){
    _LoadBuiltins();
    _LoadType();
  }

  static Map<String, CodeType> get types => _instance._types;

  static Iterable<BuiltinLib> get libs => _instance._libs;

  _LoadType() {
    for (var l in _libs) {
      for (var t in l.types) {
        _types[t.fullName] = t;
      }
    }
  }

  _LoadBuiltins() {
    var libWrapper = <BuiltinLib>[];
    var rtLibs = VMRTLibs.RuntimeLibs;
    var rndLib = VMRTLibs.RenderPipeline();
    for (var lib in rtLibs) {
      var lw = BuiltinLib(lib);
      libWrapper.add(lw);
      _rtLibs.add(lw);
    }

    var rw = BuiltinLib(rndLib);
    libWrapper.add(rw);
    _renderLibs.add(rw);

    var tyMap = {};
    for (var l in libWrapper) {
      for (var t in l.types) {
        tyMap[t.fullName] = t;
      }
    }
    _lookupLib(name) {
      for (var l in libWrapper) {
        if (l.name.value = name) return l;
      }
    }

    for (var l in libWrapper) {

      _lookupTy(name) {
        var fullName = name;
        if(fullName.split('|').length < 2){
          fullName = "${l.name.value}|$name";
        }
        return tyMap[fullName];
      }

      _mapField(VMFieldHolder src, CodeFieldArray fArr) {
        for (var f in src.fields) {
          var fentry = fArr.NewField(f.name);
          var ty = _lookupTy(f.type);
          fentry.type = ty;
        }
      }

      //Map dependencies
      for (var d in l.lib.dependencies) {
        var cd = _lookupLib(d)!;
        l.deps.add(cd);
      }

      //Map fields
      for (var t in l.types) {
        var builtin = t.cls;
        var sf = builtin.StaticFields();
        var csf = t.staticFields;
        _mapField(sf, csf);
        var f = builtin.Fields();
        var cf = t.fields;
        _mapField(f, cf);

        //Map functions
        for (var m in t.methods) {
          var builtinM = m.mtd;
          var a = builtinM.Args();
          var ca = m.args;
          _mapField(a, ca);
          var r = builtinM.Rets();
          var cr = m.rets;
          _mapField(r, cr);
        }
      }
    }
  }

  static final List<BuiltinLib> runtimeLibs = _instance._rtLibs;
  static final List<BuiltinLib> renderLibs = _instance._renderLibs;

  static final CodeType intType = types["Num|Int"]!;
  static final CodeType floatType = types["Num|Float"]!;
  static final CodeType vec2Type = types["Vec|Vec2"]!;
  static final CodeType vec3Type = types["Vec|Vec3"]!;
  static final CodeType vec4Type = types["Vec|Vec4"]!;

  static final CodeType pipelineBuilderType = types["RenderPipeline|PipelineBuilder"]!;
  static final CodeType texEntryType = types["RenderPipeline|TexEntry"]!;
//TODO:Singleton builtin library loader
}
