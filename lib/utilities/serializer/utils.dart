
bool Str2Bool(String str){
  return str.trim().toLowerCase() == 'true';
}

List<String> FindBlock(String content,
    {String start = '{', String end = '}'
    }){
  var startEncountered = [];
  int currPosition = 0;
  ///+:start token, -:end token
  int? _FindToken(int fromIdx){
    if(fromIdx > content.length) return null;
    bool preferStart = startEncountered.length%2 == 0;
    int startTkPos = content.indexOf(start, fromIdx);
    int endTkPos = content.indexOf(end, fromIdx);
    if(startTkPos == endTkPos){
      if(startTkPos == -1) return null;
      return preferStart?startTkPos:-startTkPos;
    }
    if(startTkPos == -1) return -endTkPos;//Only end found
    if(endTkPos == -1) return startTkPos;//Only start found
    if(startTkPos > endTkPos) return -endTkPos;
    return startTkPos;
  }

  List<String> blocks = [];

  int? tk;
  while((tk = _FindToken(currPosition)) != null){
    int id = tk!;
    int newPos = content.length;
    if(id < 0){
      id = -id;
      //encounters end
      //No matching start token
      newPos = end.length + id;
      if(startEncountered.isNotEmpty){
        int startID = startEncountered.last;
        startEncountered.removeLast();
        //matching start token presents
        if(startEncountered.isEmpty){
          int endID = id;
          var str = content.substring(startID, endID);
          blocks.add(str);
        }
      }

    }else{
      //encounters begin
      newPos = start.length + id;
      startEncountered.add(newPos);
    }
    currPosition = newPos;

  }

  return blocks;
}

///Basic format:
///  "prop1":"val1",
///  "prop2":"val2",
///  ...
Iterable<String> StrMap2Str(Map<String, String> map)sync*{
  for(var e in map.entries){
    yield "\"${e.key}\" : \"${e.value}\",";
  }
}

///Separated by ','
Map<String, String> Str2StrMap(String str){
  _GetStrVal(seg){
    var blks = FindBlock(seg,start: '"', end: '"');
    if(blks.isEmpty) return null;
    return blks.first;
  }

  Map<String, String> res = {};
  var exp = RegExp(r'"([^"\\]|\\[\s\S])*"\s*:\s*"([^"\\]|\\[\s\S])*"');
  for(var l in exp.allMatches(str)){
    var seg = l[0]!;
    var kv = seg.split(RegExp(r'\s*:\s*'));
    assert(kv.length == 2);
    var k = kv.first.replaceAll('"', '');
    var v = kv.last.replaceAll('"', '');
    res[k] = v;
  }

  return res;
}

class StructuredBlock{

  static int indentCnt = 4;
  StructuredBlock? parent;
  List<StructuredBlock> children = [];

  List<String> lines = [];

  int get indent => (parent?.contentIndent??0);
  int get contentIndent => indentCnt + indent;

  StructuredBlock NewBlock()
  {
    children.add(StructuredBlock()..parent = this);
    return children.last;
  }

  void AddLine(String line){
    lines.add(line);
  }

  void AddMap(Map<String, String> m){
    var mb = NewBlock();
    for(var l in StrMap2Str(m)){
      mb.AddLine(l);
    }
  }

  @override
  String toString(){
    var s = "";
    s += (''.padLeft(indent) + '{\n');
    for(var l in lines){
      s+=(''.padLeft(contentIndent) + l + '\n');
    }
    for(var c in children){
      s+= c.toString();
    }
    s += (''.padLeft(indent) + '}\n');
    return s;
  }
}