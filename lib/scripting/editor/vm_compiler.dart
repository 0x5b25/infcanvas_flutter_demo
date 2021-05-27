
import 'dart:math';
import 'dart:ui';

import 'package:infcanvas/scripting/editor/vm_method_nodes.dart';
import 'package:infcanvas/scripting/editor/vm_opcodes.dart';
import 'package:infcanvas/scripting/graph_compiler.dart';
import 'package:infcanvas/scripting/editor/vm_editor.dart';
import 'package:infcanvas/scripting/script_graph.dart';

import 'codemodel.dart';


class InstLine{
  OpCode op = OpCode.HLT;
  double? f;
  int? i;
  String? s;

  InstLine(this.op, {this.f, this.i, this.s}){}

  @override
  String toString(){
    var arg =
    i!=null?".${i.toString()}":
    f!=null?".${f.toString()}":
    s!=null?".${s}":
    "";
    return "[${op.toString()}]$arg";
  }
}

abstract class CodeBlock{
  int startLine = 0;
  late VMNodeTranslationUnit fromWhichUnit;
  String debugInfo = '';
  //late NodeTranslationUnit translationCell;

  Iterable<InstLine> EmitCode(int lineCnt);
  bool NeedsMod()=>false;
  void ModCode(List<InstLine> code){}

  @override
  String toString()=>'[${fromWhichUnit.fromWhichNode.displayName}]$debugInfo';

}


class SimpleCB extends CodeBlock{

  List<InstLine> code;

  SimpleCB(this.code){}

  @override
  List<InstLine> EmitCode(int lineCnt) {
    return code;
  }

}

class CodeBuilderCB extends CodeBlock{

  Iterable<InstLine> Function(int) builder;

  CodeBuilderCB(this.builder);

  @override
  Iterable<InstLine> EmitCode(int lineCnt) {
    return builder(lineCnt);
  }

}

//Mainly for entry nodes
mixin VMAnchoredTUMixin on VMNodeTranslationUnit{
  int anchoredPosition = 0;
  int ReportStackUsage() => 0;
}

abstract class VMNodeTranslationUnit extends NodeTranslationUnit{

  //Stack position is calculated per scope
  int? stackPosition;

  bool CanHandleEOF() =>false;

  CodeBlock? HandleEOF(VMNodeTranslationUnit issued){
    throw UnimplementedError("Wrong return handler!");
  }

  int ReportStackUsage();
}

class VMGraphScope{

  VMGraphScope? parent;

  Map<CodeGraphNode,VMNodeTranslationUnit> visitedNodes = {};

  int stackUsage = 0;

  VMNodeTranslationUnit VisitNode(CodeGraphNode which){
    assert(FindVisitedNode(which) == null);

    var tu = which.CreateTranslationUnit() as VMNodeTranslationUnit;

    visitedNodes[which] = tu;
    return tu;
  }

  int GetCurrentStackUsage(){
    int usg = 0;
    VMGraphScope? s = this;
    while(s != null){
      usg += s.stackUsage;
      s = s.parent;
    }
    return usg;
  }

  VMNodeTranslationUnit? FindVisitedNode(CodeGraphNode which){
    VMGraphScope? scope = this;
    while(scope != null){
      var res = scope.visitedNodes[which];
      if(res != null) return res;
      scope = scope.parent;
    }
    return null;
  }

}

class EntryCB extends CodeBlock{
  VMNodeTranslationUnit toWhich;

  EntryCB(this.toWhich);

  @override
  Iterable<InstLine> EmitCode(int lineCnt)sync* {}

  @override
  String toString(){return "->${toWhich.fromWhichNode.displayName}";}

}

class JumpCB extends CodeBlock{

  CodeBlock to;
  JumpCB(this.to);

  @override
  Iterable<InstLine> EmitCode(int lineCnt) sync*{
    int target = to.startLine - startLine;
    yield InstLine(OpCode.JMPI, i:target);
  }

}

class VMGraphCompileContext extends GraphCompileContext{

  VMGraphScope currentScope = VMGraphScope();
  List<CodeBlock> blocks = [];
  Map<VMNodeTranslationUnit, CodeBlock> entries = {};
  //String? errMsg;

  VMGraphCompileContext([int reservedSpace = 0]){
    currentScope.stackUsage += reservedSpace;
  }

  int get stackUsage => currentScope.GetCurrentStackUsage();

  @override
  VMNodeTranslationUnit get currentTU =>
      super.currentTU as VMNodeTranslationUnit;

  void EnterScope(){
    var s = VMGraphScope()..parent = currentScope;
    currentScope = s;
    //For debugging purpose only
    blocks.add(SimpleCB([
    ])..debugInfo = "Enter scope");
  }

  void ExitScope(){
    assert(currentScope.parent != null, "Exit scope unbalanced!");
    var scopeStackSize = currentScope.stackUsage;
    currentScope = currentScope.parent!;
    blocks.add(SimpleCB([
      InstLine(OpCode.POPI, i:scopeStackSize)
    ])..debugInfo = "Exit scope");
  }

  void _AssignStackPosition(VMNodeTranslationUnit tu){
    if(tu is! VMAnchoredTUMixin) {
      assert(tu.stackPosition == null, "Can't reassign stack space!");
      tu.stackPosition = currentScope.GetCurrentStackUsage();
      currentScope.stackUsage += tu.ReportStackUsage();
    }
  }


  void AssignStackPosition(){
    _AssignStackPosition(currentTU);
  }

  void ArrangeValueDependencies(
    List<ValueInSlotInfo> deps
  ){
    var nodes = [];
    for(int i = 0; i < deps.length; i++){
      var link = deps[i].link;
      if(link == null)
        ReportError("input ${deps[i].name} is empty");
      nodes.add(link!.from.node);
    }

    if(hasErr) return;

  }

  //Returns stack position counted from entry
  int AddValueDependency(CodeGraphNode from, int idx){
    //if(hasErr) return;
    //Is visited?
    var visited = currentScope.FindVisitedNode(from);
    if(visited == null){
      //
      if(from.needsExplicitExec){
        ReportError("Depends on not executed non-explicit node!");
        return -1;
      }
      //Not visited, translate node
      visited = TranslateNode(from);
      if(visited.stackPosition == null) {
        _AssignStackPosition(visited);
      }
      //Getter to filter which item we want
      // var retGetter = RetGetterCB(retCnt, idx);
      // retGetter.debugInfo = 'Read ${from.displayName}.${idx}';
      // retGetter.fromWhichUnit = visited!;
      // blocks.add(retGetter);
    }
    if(visited is VMAnchoredTUMixin){
      return (visited as VMAnchoredTUMixin).anchoredPosition + idx;
    }
    assert(visited.stackPosition != null, "Stack position not assigned.");
    return visited.stackPosition! + idx;
  }

  //Explicitly executed nodes output value as-is, The stack base vm ensures
  //output position on stack is not changed during the nodes' lifetime
  void AddNextExec(CodeGraphNode? which){
    //if(hasErr) return;
    if(which == null){
      HandleEOF();
      return;
    }

    assert(which.needsExplicitExec);
    if(!which.needsExplicitExec){
      ReportError("Tried to run non-explicit node!");
      return;
    }

    var visited = currentScope.FindVisitedNode(which);
    if(visited == null){
      TranslateNode(which);
    }else{
      var entry = entries[visited]!;
      blocks.add(JumpCB(entry)..debugInfo = 'GOTO ${entry.toString()}}');
    }
  }

  void HandleEOF(){
    var issuedFrom = currentTU;
    for(int i = workingList.length - 1; i>=0;i--){
      var tu = workingList[i] as VMNodeTranslationUnit;
      if(tu.CanHandleEOF()){
        var cb = tu.HandleEOF(issuedFrom);
        if(cb!=null){
          cb.debugInfo = '<-EOF:${issuedFrom.fromWhichNode.displayName}';
          cb.fromWhichUnit = currentTU;
          blocks.add(cb);
        }
        return;
      }
    }
    //TODO:handle silently when there is no value to return
    ReportError("Return not handled!");
  }

  void EmitCode(CodeBlock block){
    //if(hasErr) return;
    block.fromWhichUnit = currentTU;
    blocks.add(block);
  }


  int get retCnt => currentTU.ReportStackUsage();

  VMNodeTranslationUnit TranslateNode(CodeGraphNode root){
    //if(hasErr) return 0;

    var tu = currentScope.VisitNode(root);

    workingList.add(tu);

    AttachCodeEntry();

    tu.Translate(this);

    workingList.removeLast();

    return tu;
  }

  void AttachCodeEntry(){
    var ent = EntryCB(currentTU);
    ent.fromWhichUnit = currentTU;
    entries[currentTU] = ent;
    blocks.add(ent);
  }

}

class CBModInfo{
  late CodeBlock block;
  late int start;
  late int end;
}

class Graph{
  late int argCnt;
  late int retCnt;
  late CodeGraphNode entry;
}

class VMGraphCompiler{

  List<InstLine> compiled = [InstLine(OpCode.HLT)];
  Map<GraphNode, List<String>> errors = {};

  bool hasError = true;

  int argCnt, retCnt;

  VMGraphCompiler.compile(CodeGraphNode entry, this.argCnt, this.retCnt){
    Compile(entry);
  }

  void Compile(root){
    compiled = [];
    //In order to increase performance, return val storing
    //uses back-to-front order, to avoid overlapping, we needs
    //to "pad" the size differences between return count and
    //argument count
    int deltaSpace = max(0, (retCnt - argCnt));
    if(deltaSpace > 0) {
      compiled = [
        InstLine(OpCode.PUSH, i:deltaSpace)
      ];
    }

    var ctx = VMGraphCompileContext(argCnt + deltaSpace);

    ctx.TranslateNode(root);

    if(ctx.hasErr){
      errors = ctx.errMsg;
      return;
    }


    //Reserve exchange space and local space
    //int localSize = ArrangeLocalSpace(ctx);
    // int exchgDelta = graph.retCnt - graph.argCnt;
    // if(exchgDelta < 0)exchgDelta = 0;
    // int reserveSpace = localSize + exchgDelta;
    // if(reserveSpace > 0)
    //   compiled.add(InstLine(OpCode.PUSH, i:localSize + exchgDelta));

    //Emit Code
    compiled += EmitCode(ctx.blocks);
    hasError = false;
  }
  /*
  int ArrangeLocalSpace(VMGraphCompileContext ctx){
    assert(!ctx.hasErr);

    List<CacheHandle?> cacheReg = [];

    for(var block in ctx.blocks){

      //The last one, erase allocation
      if(block is CacheHandleGetterBlock){
        var h = block.fromWhichHandle;

        if(block == h.lastGetter[block.idx]){
          //The last one, erase allocation at index
          int slot = h.slot;
          int pos = slot + block.idx - exchgSize;
          cacheReg[pos] = null;
          continue;
        }
      }

      //Allocate on first occurance
      if(block is EntryCB){
        var u = block.fromWhichUnit;
        if(!u.isCached) continue;

        var h = u.cached!;
        //Find or allocate
        int pos = -1;
        for(int i = 0; i < cacheReg.length; i++){
          if(cacheReg[i] == null){
            //Search for space
            bool adequte = true;
            for(int s = 1; s < h.size; s++){
              //We are at the end, so we can allocate
              if(s + i >= cacheReg.length){
                //cacheReg.add(null);
                break;
              }

              if(cacheReg[s+i] != null){
                  //There is another object in range,
                  //so we can't park here
                  adequte = false;
                  break;
                }
            }
            if(adequte){
              pos = i;
              break;
            }
          }
        }

        if(pos < 0){
          pos = cacheReg.length;
        }

        for(int s = 0; s < h.size; s++){
          //We are at the end, so we can allocate
          if(s + pos >= cacheReg.length)
            cacheReg.add(h);
          else{
            cacheReg[s+pos] = h;
          }
        }

        h.slot = pos + exchgSize;
      }
    }

    return cacheReg.length;

  }
*/
  List<InstLine> EmitCode(List<CodeBlock> blocks){
    List<CBModInfo> modPending = [];

    List<InstLine> insts = [];

    int lineCnt = 0;
    for(var cb in blocks){
      int start = lineCnt;
      for(var inst in cb.EmitCode(lineCnt)){
        insts.add(inst);
        lineCnt++;
      }
      if(cb.NeedsMod()){
        modPending.add(CBModInfo()
          ..block = cb
          ..start = start
          ..end = lineCnt
        );
      }


    }
    for(var i in modPending){
      var inst = insts.sublist(i.start, i.end);
      i.block.ModCode(inst);
    }

    return insts;
  }

}

///[result, errorMsg]
List CompileLibrary(CodeLibrary lib){
  //Startup env
  VMEditorEnv env = VMEditorEnv(debugName:"CompilerEnv");
  VMLibInfo compiledLib = VMLibInfo(lib.name.value);
  env.LoadLib(lib);
  for(var ty in lib.types){
    var res = CompileType(ty, env);
    if(res.last != null){
      env.Dispose();
      return [null, res.last];
    }
    VMClassInfo compiledClass = res.first;
    compiledLib.AddClassInfo(compiledClass);
  }
  env.Dispose();
  return [compiledLib, null];
}



///[result, errorMessage]
List CompileType(CodeType type, VMEditorEnv env){
  //var analyzer = VMMethodAnalyzer();
  //analyzer.env = env;
  _FieldValid(CodeField f){
    var ty = f.type;
    if(ty == null) return false;
    return env.TypeContainedInDeps(type, ty);
  }

  VMClassInfo compiledClass = VMClassInfo(type.name.value);

  var cf = compiledClass.Fields();
  for(var f in type.fields.fields){
    if(!_FieldValid(f)) {
      return [
        null,
        "Type ${f.type?.fullName ?? ''} not found, referenced in field ${f.fullName}"
      ];
    }
    cf.AddField(f.name.value, f.type!.fullName);
  }

  var csf = compiledClass.StaticFields();
  for(var f in type.staticFields.fields){
    if(!_FieldValid(f)) {
      return [
        null,
        "Type ${f.type?.fullName ?? ''} not found, referenced in static field ${f.fullName}"
      ];
    }
    csf.AddField(f.name.value, f.type!.fullName);
  }

  for(var mb in type.methods){
    var m = mb as CodeMethod;
    var res  = CompileMethod(m, env);
    if(res.last != null) return [null, res.last];

    compiledClass.AddMethod(res.first);
  }

  return [compiledClass, null];
}

List CompileMethod(CodeMethod m, VMEditorEnv env){
  var analyzer = VMMethodAnalyzer();
  analyzer.env = env;
  analyzer.whichMethod = m;
  var res = _CompileMethod(m,analyzer);
  analyzer.Dispose();
  return res;
}

List _CompileMethod(CodeMethod m,VMMethodAnalyzer analyzer){
  //Might not needs to dispose, since

  _FieldValid(CodeField f){
    var ty = f.type;
    if(ty == null) return false;
    return analyzer.TypeContainedInDeps(ty);
  }

  for(var f in m.args.fields){
    if(!_FieldValid(f)) return [
      null,
      "Type ${f.type?.fullName??''} not found,"
          " referenced in ${f.fullName}"
    ];
  }

  for(var f in m.rets.fields){
    if(!_FieldValid(f)) return [
      null,
      "Type ${f.type?.fullName??''} not found,"
          " referenced in ${f.fullName}"
    ];
  }
  analyzer.whichMethod = m;
  analyzer.SanitizeMethodBody();

  if(m.root == null) return [
    null,
    "Method ${m.fullName} doesn't have a body"
  ];
  var cpResult = VMGraphCompiler.compile(m.root!, m.args.length, m.rets.length);
  m.nodeMessage = Map.from(cpResult.errors);
  if(cpResult.hasError) return [
    null,
    "Method ${m.fullName} has error"
  ];

  var compiledMethod = VMMethodInfo(m.name.value);
  {
    var a = compiledMethod.Args();
    for(var f in m.args.fields){
      a.AddField(f.name.value, f.type!.fullName);
    }
  }

  {
    var r = compiledMethod.Rets();
    for(var f in m.rets.fields){
      r.AddField(f.name.value, f.type!.fullName);
    }
  }

  compiledMethod.isConstantMethod = m.isConst.value;
  compiledMethod.isStaticMethod = m.isStatic.value;
  {
    var opcodes = <int>[];
    var oprands = <Object?>[];
    for(var l in cpResult.compiled){
      opcodes.add(l.op.index);
      oprands.add(l.i??l.f??l.s);
    }
    compiledMethod.SetBody(opcodes, oprands);
  }

  return [compiledMethod, null];
}
