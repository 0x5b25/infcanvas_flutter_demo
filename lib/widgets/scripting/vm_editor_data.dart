

import 'dart:ui';

import 'package:infcanvas/utilities/scripting/graph_compiler.dart';
import 'package:infcanvas/widgets/scripting/vm_graphnodes.dart';
import 'package:infcanvas/utilities/scripting/script_graph.dart';
import 'package:infcanvas/utilities/scripting/vm_types.dart';

import 'codepage.dart';
import 'method_editor.dart';

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


class EditorLibData{
  VMEnv env;
  VMLibInfo lib;

  List<EditorClassData> clsData = [];

  EditorLibData(this.env, this.lib){
    //Update classes
    assert(env.LoadedLibs().contains(lib));
  }

  void NotifyStructureChange(){
    for(var cls in clsData){
      cls.NotifyStructureChange();
    }
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
    NotifyStructureChange();
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

  void Rename(String newName) {
    env.RenameLib(lib.name, newName);
  }

  bool IsValid(){
    for(var depName in lib.dependencies){
      if(env.FindLib(depName) == null) return false;
    }

    for(var d in clsData){
      if(!d.IsValid()) return false;
    }
    return true;
  }

  void ReconstructEnv(Iterable<VMLibInfo> availLibs){
    var deps = lib.dependencies;
    var depsFound = <VMLibInfo>[];
    for(var l in availLibs){
      if(deps.contains(l.name)){
        depsFound.add(l);
      }
    }
    depsFound.add(lib);
    env.Reset();
    env.AddLibs(depsFound);
    NotifyStructureChange();
  }

  void AddDep(VMLibInfo dep){
    if(env.FindLib(dep.name) != null) return;
    var deps = List<String>.from(lib.dependencies);
    //if(dep.contains(depName)) return;
    deps.add(dep.name);
    lib.dependencies = deps;
    env.AddLibrary(dep);
  }

  void RemoveDep(String name){
    if(env.FindLib(name) == null) return;

    var deps = List<String>.from(lib.dependencies);
    //if(dep.contains(depName)) return;
    deps.remove(name);
    lib.dependencies = deps;
    env.RemoveLibrary(name);

    NotifyStructureChange();

  }

  void Compile(){
    for(var c in clsData){
      c.Compile();
    }
  }

}


class EditorClassData{
  EditorLibData lib;
  int idx;
  VMClassInfo get cls => lib.lib.GetClassInfo(idx);
  //VMClassInfo cls;

  List<EditorMethodData> methodData = [];

  EditorClassData(this.lib, this.idx){
    for(int i = 0; i < cls.MethodInfoCnt(); i++){
      methodData.add(EditorMethodData(this, i));
    }
  }

  void RemoveMethod(EditorMethodData mtd){
    cls.RemoveMethod(mtd.mtdIdx);
    methodData.remove(mtd);
    NotifyStructureChange();
  }

  EditorMethodData AddMethod(VMMethodInfo mtd){
    int idx = cls.MethodInfoCnt();
    cls.AddMethod(mtd);
    methodData.add(EditorMethodData(this, idx));
    return methodData.last;
  }

  Iterable<NodeSearchInfo> FindMatchingNode(String? argType, String? retType)
  sync* {
    //Method calls and control flow
    yield* lib.FindMatchingNode(argType, retType);

    //Getters and setters
    for(var f in cls.Fields().fields){

    }
  }

  void NotifyStructureChange() {
    for(var mtd in methodData){
      mtd.NotifyStructureChange();
    }
  }

  bool IsFieldValid(VMFieldHolder field){
    //Are names unique?
    {
      Set<String> names = {};
      var types = lib.Types().toSet();

      for(var f in field.fields){
        if(names.contains(f.name)) return false;
        if(!types.contains(f.type))return false;
        names.add(f.name);
      }
    }
    return true;
  }

  bool IsValid(){
    var types = lib.Types().toSet();
    if(!IsFieldValid(cls.Fields())) return false;
    if(!IsFieldValid(cls.StaticFields())) return false;
    for(var md in methodData){
      if(!md.IsValid()) return false;
    }
    return true;
  }

  void Compile() {
    for(var m in methodData){
      m.CompileGraph();
    }
  }

}


class EditorMethodData extends CodeData{
  EditorClassData classData;
  int mtdIdx;

  late NodeHolder entryNode = NodeHolder(FnEntryNode(this))
    ..ctrl.dx = 50
    ..ctrl.dy = 50
    ;
  List<NodeHolder> _nodes = [];

  NodeHolder? entry;

  //TODO:Distribute node validation into individual nodes
  void UpdateNodes(){

    CheckThisPointer();
    CheckEnvNode();

    //Check rets
    if(!mtd.isConstantMethod){
      _nodes.removeWhere(
        (element){
          if(element.info is FnEntryNode){
            element.info.RemoveLinks();
            return true;
          }
          return false;
        }
      );
      if(entry == null)
        entry = NodeHolder(FnEntryNode(this));
      else if(!(entry!.info is FnEntryNode)){
        entry!.info.RemoveLinks();
        var ctrl = entry!.ctrl;
        entry = NodeHolder(FnEntryNode(this))..ctrl = ctrl;
      }else{
        (entry!.info as FnEntryNode).Update();
      }
    }else{
      _nodes.removeWhere(
        (element){
          if(element.info is FnRetNode){
            element.info.RemoveLinks();
            return true;
          }
          return false;
        }
      );

      if(entry == null)
        entry = NodeHolder(FnRetNode(this));
      else if(!(entry!.info is FnRetNode)){
        entry!.info.RemoveLinks();
        var ctrl = entry!.ctrl;
        entry = NodeHolder(FnRetNode(this))..ctrl = ctrl;
      }else{
        (entry!.info as FnRetNode).Update();
      }      

    }
  }

  void CheckEnvNode(){
    _nodes.removeWhere((element){
      var n = element.info;
      if(!(n is EnvNode))return false;
      bool isValid = n.Validate(classData.lib.env);
      if(!isValid){
        n.RemoveLinks();
      }
      return !isValid;
    });
  }

  void CheckThisPointer(){
    bool allowThisPointer = !mtd.isStaticMethod;
    if(!allowThisPointer)
      _nodes.removeWhere((element){
        if(!(element.info is FnThisNode)) return false;
        element.info.RemoveLinks();
        return true;
      });
    else{
      for(var n in _nodes){
        if(!(n.info is FnThisNode)) continue;

        var tn = n.info as FnThisNode;
        tn.Update(mtd.thisType);
      }
    }
  }

  @override
  List<NodeHolder> GetNodes() {return [entry!] + _nodes;}

  @override
  void RemoveNode(NodeHolder n) {
    _nodes.remove(n);
    NotifyCodeChange();
  }

  @override
  void AddNode(NodeHolder n) {
    _nodes.add(n);
    NotifyCodeChange();
  }


  
  EditorMethodData(this.classData, this.mtdIdx){
    //UpdateNodes();
    //Check rets
    if(!mtd.isConstantMethod){
      var entryNode = FnEntryNode(this);
      var retNode = FnRetNode(this);
      var fromSlot = entryNode.execOut;
      var toSlot = retNode.execIn;
      var lnk = GraphEdge(fromSlot, toSlot);
      fromSlot.ConnectLink(lnk);
      toSlot.ConnectLink(lnk);
      var entryHolder = NodeHolder(entryNode);
      var retHolder = NodeHolder(retNode);
      retHolder.ctrl.dx = 500;
      entry = entryHolder;
      _nodes.add(retHolder);
    }else{
      entry = NodeHolder(FnRetNode(this));
    }
  }


  VMMethodInfo get mtd => classData.cls.GetMethodInfo(mtdIdx);

  bool get isStatic =>mtd.isStaticMethod;
  set isStatic(bool val){
    if(val == isStatic) return;
    mtd.isStaticMethod = val;
    NotifyCodeChange();
  }

  bool get isConstant =>mtd.isConstantMethod;
  set isConstant(bool val){
    if(val == isConstant) return;
    mtd.isConstantMethod = val;
    NotifyCodeChange();
  }

  @override
  Iterable<NodeSearchInfo> FindMatchingNode(String? argType, String? retType)sync* {
    yield* classData.FindMatchingNode(argType, retType);

    //This pointer
    if(!mtd.isStaticMethod){
      var node = FnThisNode(mtd.thisType);
      var result = MatchGraphNode(node, "", IsSubTypeOf, argType, retType);
      if(result != null)
        yield result;
    }

    //Add return nodes
    if(!mtd.isConstantMethod){
    
      if(argType == null && retType == null){
        var retNode = FnRetNode(this);
        yield (NodeSearchInfo(retNode, "", -1));
      }
      else if(argType != null){
        var retNode = FnRetNode(this);

        for(int i = 0; i < retNode.inSlot.length; i++){

          if(IsSubTypeOf(argType, retNode.inSlot[i].type)){
            yield (NodeSearchInfo(retNode, "", i));
            break;
          }
        }
      }
    }else{
      if(argType == null && retType == null){
        var entryNode = FnEntryNode(this);
        yield (NodeSearchInfo(entryNode, "", -1));
      }
      else if(retType != null){
        var entryNode = FnEntryNode(this);

        for(int i = 0; i < entryNode.outSlot.length; i++){

          if(IsSubTypeOf(entryNode.outSlot[i].type, retType)){
            yield (NodeSearchInfo(entryNode, "", i));
            break;
          }
        }
      }
    }

  }

  @override
  bool IsSubTypeOf(String type, String base) {
    return classData.lib.env.IsSubTypeOf(type, base);
  }


  ///Compiling the code
  
  List<InstLine>? body;

  @override
  void NotifyCodeChange(){
    ClearCompileResults();
  }

  void ClearCompileResults(){
    nodeMessage.clear();
    body = null;
  }

  

  bool get isBodyValid => body != null;
  bool get hasError => nodeMessage.isNotEmpty;
  
  void CompileGraph(){
    if(!IsArgFieldValid() || ! IsRetFieldValid()) return;
    Graph g = Graph()
      ..argCnt = mtd.Args().FieldCount()
      ..retCnt = mtd.Rets().FieldCount()
      ..entry = entry!.info
      ;

    var compiler = VMGraphCompiler(g);
    if(compiler.hasError){
      nodeMessage = compiler.errors;
      body = null;
    }else{
      nodeMessage.clear();
      body = compiler.compiled;
      SetBody();
    }
  }

  void SetBody(){
    List<int> ops = [];
    List<Object?> args = [];
    if(body!= null){
      for(var i in body!){
        ops.add(i.op.index);
        if(i.i!=null){
          args.add(i.i);
        }else if(i.f!=null){
          args.add(i.f);
        }else if(i.s != null){
          args.add(i.s);
        }else{
          args.add(null);
        }
      }
    }
    mtd.SetBody(ops, args);
  }

  void NotifyStructureChange() {
    ClearCompileResults();
  }

  bool IsArgFieldValid(){
    return classData.IsFieldValid(mtd.Args());
  }

  bool IsRetFieldValid(){
    return classData.IsFieldValid(mtd.Rets());
  }

  bool IsValid() {
    return IsArgFieldValid() && IsRetFieldValid() && !hasError;
  }
}
