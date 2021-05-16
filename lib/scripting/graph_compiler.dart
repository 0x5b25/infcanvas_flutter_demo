//import 'package:infcanvas/utilities/scripting/graph_walker.dart';

import 'dart:math';

import 'package:flutter/material.dart';

import 'script_graph.dart';




//
// void AddDep(slot, ctx){
//   var e = slot.link;
//   if(e == null){
//     ctx.ReportError("Incomplete input to setter node!");
//     return;
//   }
//   var rear = e.from as ValueOutSlotInfo;
//   ctx.AddValueDependency(rear.node, rear.outputOrder);
// }

abstract class NodeTranslationUnit{
  late GraphNode fromWhichNode;
  void Translate(covariant GraphCompileContext ctx);
}


abstract class GraphCompileContext{
  bool get hasErr => errMsg.isNotEmpty;

  Map<GraphNode, List<String>> errMsg = {};

  List<NodeTranslationUnit> workingList = [];

  NodeTranslationUnit get currentTU => workingList.last;

  void ReportError(String message){
    var currNode = currentTU.fromWhichNode;
    if(errMsg[currNode] == null){
      errMsg[currNode] = [message];
    }
    else{
      errMsg[currNode]!.add(message);
    }
  }
}



