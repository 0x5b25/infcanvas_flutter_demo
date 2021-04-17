//import 'package:infcanvas/utilities/scripting/graph_walker.dart';

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:infcanvas/utilities/scripting/opcodes.dart';

import 'script_graph.dart';


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
  late NodeTranslationUnit fromWhichUnit;
  String debugInfo = '';
  //late NodeTranslationUnit translationCell;
  
  Iterable<InstLine> EmitCode(int lineCnt);
  bool NeedsMod()=>false;
  void ModCode(List<InstLine> code){}

  @override
  String toString()=>'[${fromWhichUnit.fromWhichNode.displayName}]$debugInfo';

}


String? AddDep(slot, ctx){
  var e = slot.link;
  if(e == null){
    return "Incomplete input to setter node!";
  }
  var rear = e.from as ValueOutSlotInfo;
  ctx.AddValueDependency(rear.node, rear.outputOrder);
}

abstract class NodeTranslationUnit{

  late GraphNode fromWhichNode;
  CacheHandle? cached;
  bool get isCached => cached != null;
  
  bool CanHandleEOF() =>false;

  CodeBlock? HandleEOF(NodeTranslationUnit issued){
    throw UnimplementedError("Wrong return handler!");
  }
  
  String? Translate(GraphCompileContext ctx);

  int ReportStackUsage();

  CacheHandle CreateCacheHandle(){
    var c = doCreateCacheHandle();
    c.unitToCache = this;
    cached = c;
    return c;
  }

  CacheHandle doCreateCacheHandle(){return CacheHandle(ReportStackUsage());}

}

class GraphScope{

  GraphScope? parent;

  Map<GraphNode,NodeTranslationUnit> visitedNodes = {};

  NodeTranslationUnit? FindVisitedNode(GraphNode which){
    GraphScope? scope = this;
    while(scope != null){
      var res = scope.visitedNodes[which];
      if(res != null) return res;
      scope = scope.parent;
    }
    return null;
  }

}

class EntryCB extends CodeBlock{
  NodeTranslationUnit toWhich;

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
    //TODO: Unconditionally jump!
    yield InstLine(OpCode.JMPI, i:target);
  }

}

class RetGetterCB extends CodeBlock{
  int size;
  int idx;

  RetGetterCB(this.size, this.idx);

  @override
  Iterable<InstLine> EmitCode(int lineCnt)sync* {
    if(fromWhichUnit.isCached){
      yield* EmitCodeCached();
    }else{
      yield* EmitCodeNotCached();
    }
  }

  Iterable<InstLine> EmitCodeNotCached()sync* {
    if(idx > 0){
      yield InstLine(OpCode.ldi, i:size - idx - 1);
      yield InstLine(OpCode.sti, i:size);
    }

    if(size > 1)
      yield InstLine(OpCode.POPI, i:size - 1);
  }

  Iterable<InstLine> EmitCodeCached()sync* {
    var handle = fromWhichUnit.cached!;
    int slot = handle.slot;

    for(int i = size - 1; i >= 0 ;i--){
      yield InstLine(OpCode.starg, i:slot + i);
    }

    yield InstLine(OpCode.ldarg, i:slot+idx);
  }
}

///The explicit node must haneld its outputs
///Either save to local slot, or dump
class CacheHandle{
  late NodeTranslationUnit unitToCache;
  late List<CacheHandleGetterBlock?> lastGetter;
  late int slot;

  int size;
  CacheHandle(this.size){
    lastGetter = List<CacheHandleGetterBlock?>.filled(size, null);
  }

  CodeBlock NewGetter(int idx){
    var cg = doCreateNewHandle();
    cg.fromWhichHandle = this;
    cg.idx = idx;
    lastGetter[idx] = cg;
    return cg;
  }

  CacheHandleGetterBlock doCreateNewHandle(){
    return CacheHandleGetterBlock();
  }

}

class CacheHandleGetterBlock extends CodeBlock{
  late CacheHandle fromWhichHandle;
  late int idx;
  bool get isLastGetter{
    return fromWhichHandle.lastGetter == this;
  }
  @override
  List<InstLine> EmitCode(int line){
    return [
      InstLine(OpCode.ldarg, i:fromWhichHandle.slot + idx),
      //InstLine()..op = OpCode.LDLCNTI..i=fromWhichHandle.size,
    ];
  }
  @override
  String toString()=>'Get ${fromWhichHandle.unitToCache.fromWhichNode.displayName}';
}

class GraphCompileContext{

  GraphScope currentScope = GraphScope();
  List<CodeBlock> blocks = [];
  Map<NodeTranslationUnit, CodeBlock> entries = {}; 
  Map<NodeTranslationUnit, CacheHandle> cached = {}; 
  String? errMsg;
  bool get hasErr => errMsg != null;

  void EnterScope(){
    var s = GraphScope()..parent = currentScope;
    currentScope = s;
  }

  void ExitScope(){
    assert(currentScope.parent != null, "Exit scope unbalanced!");
    currentScope = currentScope.parent!;
  }

  void AddValueDependency(GraphNode from, int idx){
    if(hasErr) return;
    //Is visited?
    var visited = currentScope.FindVisitedNode(from);
    int retCnt = 0;
    if(visited == null){
      //
      if(from.needsExplicitExec){
        errMsg = "Depends on not executed non-explicit node!";
        return;
      }
      //Not visited, translate node
      retCnt = TranslateNode(from);
      visited = currentScope.FindVisitedNode(from);
      //Getter to filter which item we want
      var retGetter = RetGetterCB(retCnt, idx);
      retGetter.debugInfo = 'Read ${from.displayName}.${idx}';
      retGetter.fromWhichUnit = visited!;
      blocks.add(retGetter);
    }
    else{
      //Bring up the getters
      var cache = this.cached[visited];
      if(cache == null){
        cache = visited.CreateCacheHandle();
        this.cached[visited] = cache;
      }

      var getter = cache.NewGetter(idx);
      getter.fromWhichUnit = currentTU;
      blocks.add(getter);
      retCnt = cache.size;
    }

    
  }

  void AddNextExec(GraphNode? which){
    if(hasErr) return;
    if(which == null){
      HandleEOF();
      return;
    }

    assert(which.needsExplicitExec);
    if(!which.needsExplicitExec){
      errMsg = "Tried to run non-explicit node!";
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
    for(int i = workingList.length - 2; i>=0;i--){
      var tu = workingList[i];
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

    errMsg = "Return not handled!";
  }

  void EmitCode(CodeBlock block){
    if(hasErr) return;
    block.fromWhichUnit = currentTU;
    blocks.add(block);
  }

  List<NodeTranslationUnit> workingList = [];

  NodeTranslationUnit get currentTU => workingList.last;
  int get retCnt => currentTU.ReportStackUsage();

  int TranslateNode(GraphNode root){
    if(hasErr) return 0;
    
    var tu = root.CreateTranslationUnit();
    int retCnt = tu.ReportStackUsage();
    currentScope.visitedNodes[root] = tu;

    workingList.add(tu);

    AttachCodeEntry();

    errMsg = tu.Translate(this);

    workingList.removeLast();

    return retCnt;
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
  late GraphNode entry;
}

class GraphCompiler{

  List<InstLine> compiled = [InstLine(OpCode.HLT)];
  Graph graph;
  GraphCompiler(this.graph){
    Compile(graph.entry);
  }

  int get exchgSize => max(graph.argCnt, graph.retCnt);

  String? Compile(root){

    var ctx = GraphCompileContext();

    ctx.TranslateNode(root);
    if(ctx.hasErr) return ctx.errMsg;

    compiled = [];

    //Reserve exchange space and local space
    int localSize = ArrangeLocalSpace(ctx);
    int exchgDelta = graph.retCnt - graph.argCnt;
    if(exchgDelta < 0)exchgDelta = 0;
    compiled.add(InstLine(OpCode.PUSH, i:localSize + exchgDelta));

    //Emit Code
    compiled += EmitCode(ctx.blocks);
  }

  int ArrangeLocalSpace(GraphCompileContext ctx){
    assert(!ctx.hasErr);

    List<CacheHandle?> cacheReg = [];

    for(var block in ctx.blocks){

      //The last one, erase allocation
      if(block is CacheHandleGetterBlock){
        var h = block.fromWhichHandle;

        if(block == h.lastGetter[block.idx]){
          //The last one, erase allocation at index
          int slot = h.slot;
          int pos = slot + block.idx;
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
