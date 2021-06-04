
import 'package:infcanvas/scripting/codepage.dart';
import 'package:infcanvas/scripting/script_graph.dart';

class LinkNotation{
  final int from, to, fromSlot, toSlot;
  LinkNotation(
    this.from, this.fromSlot,
    this.to, this.toSlot
  );
}

_ElemIdx(elem, list){
  for(int i = 0; i < list.length; i++){
    if(list[i] == elem) return i;
  }
  throw ArgumentError("Element isn't contained in list");
}

List<LinkNotation> SerializeLink(List<GraphNode> nodes){
  List<LinkNotation> links = [];

  _NodeIdx(node)=>_ElemIdx(node, nodes);

  //Only count outgoing slot
  for(int i = 0; i < nodes.length; i++){
    var n = nodes[i];
    for(int si = 0; si < n.outSlot.length; si++){
      var slot = n.outSlot[si];
      var lnks = <GraphEdge>[];
      if(slot is MultiConnSlotMixin) lnks = (slot as MultiConnSlotMixin).links;
      else if(slot is SingleConnSlotMixin) {
        var ss = slot as SingleConnSlotMixin;
        if(ss.link != null)
          lnks.add(ss.link!);
      }
      else throw ArgumentError("Unknown slot type");

      for(var l in lnks){
        var rearSlot = l.to;
        var rearNode = rearSlot.node;
        if(rearNode is HandleNode) continue;
        int rearNodeIdx = _NodeIdx(rearNode);
        int rearSlotIdx = _ElemIdx(rearSlot, rearNode.inSlot);

        links.add(LinkNotation(i, si, rearNodeIdx, rearSlotIdx));
      }
    }
  }

  return links;
}

void DeserializeLink(List<GraphNode> nodes, Iterable<LinkNotation> data){

  for(var d in data){
    var fromNode = nodes[d.from];
    var toNode = nodes[d.to];
    var fromSlot = fromNode.outSlot[d.fromSlot];
    var toSlot = toNode.inSlot[d.toSlot];

    var link = GraphEdge(fromSlot, toSlot);
    fromSlot.ConnectLink(link);
    toSlot.ConnectLink(link);
  }
}
