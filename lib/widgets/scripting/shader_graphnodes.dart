
import 'package:flutter/widgets.dart';
import 'package:infcanvas/utilities/scripting/graph_compiler.dart';
import 'package:infcanvas/utilities/scripting/script_graph.dart';
import 'package:infcanvas/widgets/functional/editor_widgets.dart';

import 'codepage.dart';


Map<String, List<String>> typeCategories = {
  "@genType":["float","float2","float3","float4"],
};

class ShaderTU extends ShaderNodeTranslationUnit{
  ShaderGN get node => fromWhichNode as ShaderGN;

  List<String> AddValDeps(ShaderGraphCompileContext ctx){
    var inputs = [
      for(int i = 0; i < fromWhichNode.inSlot.length; i++) 
        "Input_$i"
    ];

    for(int i = 0; i < fromWhichNode.inSlot.length; i++){
      var slot = fromWhichNode.inSlot[i] as ValueInSlotInfo;
      var link = slot.link;
      if(link == null){
        ctx.ReportError("Input $i is empty");
        continue;
      }
      var argType = slot.type;

      var from = link.from as ValueOutSlotInfo;
      var valName = ctx.AddValueDependency(from.node);
      inputs[i] = "$argType($valName)";
    }

    return inputs;
  }

  @override
  void Translate(ShaderGraphCompileContext ctx) {

    var inputs = AddValDeps(ctx);

    var src = node.GetSrc(inputs);
    var assigned = ctx.AssignedName();
    ctx.EmitCode(
      "${node.outSlot.first.type} $assigned = "+src +";"
    );
  }

  @override
  String get retType => node.retType;

}

abstract class ShaderGN extends GraphNode{
  String get retType;

  @override
  ShaderTU doCreateTU() {
    return ShaderTU();
  }

  @override
  bool get needsExplicitExec => false;

  bool Validate()=>true;

  String GetSrc(List<String> argNames);

}

abstract class ShaderGNBuiltinFn extends ShaderGN{
  String name;
  List<String> inputName, inputType;
  String outputName, outputType;

  ShaderGNBuiltinFn(this.name, 
    this.inputName, this.inputType, 
    this.outputName, this.outputType
  ){
    displayName = "${name} ${outputType}";
    for(int i = 0; i < inputName.length; i++){
      inSlot.add(ValueInSlotInfo(this, 
        inputName[i], inputType[i])
      );
    }

    outSlot.add(ValueOutSlotInfo(this, outputName, outputType, 0));
  }

  @override
  String get retType => outputType;

  
}


class ShaderBuiltinBinOp extends ShaderGNBuiltinFn{
  String op;

  ShaderBuiltinBinOp(
    String name, this.op,
    List<String> inputName, List<String> inputType,
    String outputName, String outputType
  ) : super(name, inputName, inputType, outputName, outputType);

  @override
  GraphNode Clone() {
    return ShaderBuiltinBinOp(
      name, op,
      inputName, inputType,
      outputName, outputType
    );
  }

  @override
  String GetSrc(List<String> argNames) {
    return "${argNames[0]} $op ${argNames[1]}";
  }
}

class ShaderBuiltinUnaryOp extends ShaderGNBuiltinFn{
  String op;

  ShaderBuiltinUnaryOp(
    String name, this.op,
    List<String> inputName, List<String> inputType,
    String outputName, String outputType
  ) : super(name, inputName, inputType, outputName, outputType);

  @override
  GraphNode Clone() {
    return ShaderBuiltinUnaryOp(
      name, op,
      inputName, inputType,
      outputName, outputType
    );
  }

  @override
  String GetSrc(List<String> argNames) {
    return "$op ${argNames[0]}";
  }
}

class ShaderBuiltinFunction extends ShaderGNBuiltinFn{
  String op;

  ShaderBuiltinFunction(
    String name, this.op,
    List<String> inputName, List<String> inputType,
    String outputName, String outputType
  ) : super(name, inputName, inputType, outputName, outputType);

  @override
  GraphNode Clone() {
    return ShaderBuiltinFunction(
      name, op,
      inputName, inputType,
      outputName, outputType
    );
  }

  @override
  String GetSrc(List<String> argNames) {
    String arg = "";
    if(argNames.length > 0){
      arg = argNames.first;
      for(int i = 1; i < argNames.length; i++){
        arg += ", ${argNames[i]}";
      }
    }
    return "$op(" + arg + ")";
  }
}

class ExpandedConfig{
  Map<String, ExpandedConfig> segments = {};

  ExpandedConfig LookupOrAdd(String seg){
    var nextNode = segments[seg];
    if(nextNode == null){
      nextNode = ExpandedConfig();
      segments[seg] = nextNode;
    }

    return nextNode;
  }
}

abstract class TypeExpander{
  String name;
  List<List<String>> inputType;
  List<String> outputType;

  List<String> inputName;
  String outputName;

  TypeExpander(
    this.name,
    this.inputName, this.inputType,
    this.outputName, this.outputType
  );

  static String LookupMacro(String macro, int idx){
    var m = typeCategories[macro];
    if(m == null) return macro;
    return m[idx];
  }

  static int MacroElemCnt(String macro){
    var m = typeCategories[macro];
    if(m == null) return 1;
    return m.length;
  }

  static List<List<String>> GenerateConfig(template){
    List<int> configIdx = List<int>.filled(template.length, 0);
    var configs = <List<String>>[];
    while(true){
      List<String> config = [];
      for(int i = 0; i < configIdx.length; i++){
        var seg = template[i];
        var pos = configIdx[i];
        config.add(seg[pos]);
      }
      configs.add(config);

      for(int i = 0; i < template.length; i++){
        configIdx[i]++;
        if(configIdx[i] >= template[i].length){
          if(i < template.length - 1){
            configIdx[i] = 0;
          }
        }else{
          break;
        }
      }

      if(configIdx.last >= template.last.length){
        break;
      }
    }

    return configs;
  }

  static ExpandedConfig ExpandConfig(List<List<String>> gen){
    ExpandedConfig root = ExpandedConfig();
    for(var line in gen){
      ///Keep track of expandable macros and their position
      Map<String, List<int>> macros = {};

      //Register all macros
      for(int i = 0; i < line.length; i++){
        var seg = line[i];
        if(macros[seg] == null) macros[seg] = [];
        macros[seg]!.add(i);
      }

      //Expand the macros
      List<int> expandIdx = List<int>.filled(macros.length, 0);
      List<String> macroNames = macros.keys.toList();
      var macroPos = [for(var n in macroNames) macros[n]! ];
      var macroCnt = macros.length;

      var _writeCfg = (List<String> cfg) {
        
      };

      while(true){
        //Generate config using macros
        List<String> config = List.generate(line.length, (index) => '');
        for(int i = 0; i<macroCnt; i++){
          var macro = macroNames[i];
          var macroExpdIdx = expandIdx[i];
          var expanded = LookupMacro(macro, macroExpdIdx);
          for(var p in macroPos[i]){
            config[p] = expanded;
          }
        }

        //Write config to tree
        var currNode = root;
        for(var seg in config){
          currNode = currNode.LookupOrAdd(seg);
        }

        //Increment expansion counter
        for(int i = 0; i < macroCnt; i++){
          expandIdx[i]++;
          if(expandIdx[i] >= MacroElemCnt(macroNames[i])){
            if(i < macroCnt - 1){
              expandIdx[i] = 0;
            }
          }else{
            break;
          }
        }

        if(expandIdx.last >= MacroElemCnt(macroNames.last)){
          break;
        }
      }
    }
    return root;
  }

  static List<List<String>> OutputConfig(ExpandedConfig cfg){
    List<List<String>> res = [];
    for(var e in cfg.segments.entries){
      var nextCfg = e.value;
      if(nextCfg.segments.isEmpty){
        res.add([e.key]);
        continue;
      }
      var nextOutput = OutputConfig(nextCfg);
      for(var o in nextOutput){
        res.add([e.key] + o);
      }
    }
    return res;
  }

  List<ShaderGNBuiltinFn> Expand(
  ){
    var template = [outputType] + inputType;
    var gen = GenerateConfig(template);
    var expanded = ExpandConfig(gen);
    var res = OutputConfig(expanded);

    List<ShaderGNBuiltinFn> fn = [];
    for(var line in res){
      fn.add(BuildNode(name, 
        inputName, line.sublist(1),
        outputName, line.first
      ));
    }

    return fn;
  }

  ShaderGNBuiltinFn BuildNode(name, inName, inType, outName, outType);
}

class BuiltinBinOp extends TypeExpander{
  String op;

  BuiltinBinOp(
    name, this.op,
    inputName, inputType,
    outputName, outputType
  ):super(name, inputName, inputType, outputName, outputType);

  @override
  ShaderGNBuiltinFn BuildNode(name, inName, inType, outName, outType) {
    return ShaderBuiltinBinOp(name, op, inName, inType, outName, outType);
  }
}

class BuiltinShaderFn extends TypeExpander{
  String op;

  BuiltinShaderFn(
    name, this.op,
    inputName, inputType,
    outputName, outputType
  ):super(name, inputName, inputType, outputName, outputType);

  @override
  ShaderGNBuiltinFn BuildNode(name, inName, inType, outName, outType) {
    return ShaderBuiltinBinOp(name, op, inName, inType, outName, outType);
  }
}


class ShaderFloat2 extends ShaderBuiltinFunction{
  ShaderFloat2() 
    : super("Float2", "float2", 
      ["x", "y"], ["float","float"],
      "result", "float2"
    );
}


class ShaderFloat3 extends ShaderBuiltinFunction{
  ShaderFloat3() 
    : super("Float3", "float3", 
      ["x", "y", "z"], ["float","float","float"],
      "result", "float3"
    );
}


class ShaderFloat4 extends ShaderBuiltinFunction{
  ShaderFloat4() 
    : super("Float4", "float4", 
      ["x", "y", "z", "w"], ["float","float","float","float"],
      "result", "float4"
    );
}


class ShaderConstFloatNode extends ShaderGN with GNPainterMixin{
  double val = 0;
  ShaderConstFloatNode(){
    displayName = "Constant Float";
    outSlot.add(ValueOutSlotInfo(this, "f", "float", 0));
  }

  bool SetVal(String val){
    var newIVal = double.tryParse(val);
    if(newIVal == null) return false;
    this.val = newIVal;
    return true;
  }

  String GetVal(){
    return val.toString();
  }

  @override
  Widget Draw(BuildContext ctx, void Function() update){
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: SizedBox(
            height: 30,
            child: NameField(
              initialText: GetVal(),
              onChange: SetVal,
            ),
          ),
        ),
        DrawOutput(),
      ],
    );
  }

  @override
  GraphNode Clone() {
    return ShaderConstFloatNode()..val = val;
  }

  @override
  String GetSrc(List<String> argNames) {
    return val.toString();
  }

  @override
  String get retType => "float";

}

class ElementGetter extends ShaderGN{
  String elem;
  String type;

  ElementGetter(this.type, this.elem){
    displayName = "${type}.${elem}";
    inSlot.add(ValueInSlotInfo(this, "object", type));
    outSlot.add(ValueOutSlotInfo(this, elem, "float", 0));
  }

  @override
  GraphNode Clone() {
    return ElementGetter(type, elem);
  }

  @override
  String GetSrc(List<String> argNames) {
    return "$type(${argNames.single}).$elem";
  }

  @override
  String get retType => "float";
}

List<ShaderGN> _ElemAccessors(){
  var gen = (type, elems){
    return [
      for(var e in elems)
        ElementGetter(type, e)
    ];
  };
  return 
    gen("float4", ["x","y","z","w"]) +
    gen("float3", ["x","y","z"]) +
    gen("float2", ["x","y"]);
}

var ShaderBuiltins = 
<ShaderGN>[
  ShaderConstFloatNode(),
  ShaderFloat2(),
  ShaderFloat3(),
  ShaderFloat4(),
]
+
  _ElemAccessors()
+
  BuiltinBinOp("Add", "+", 
    ["a", "b"], 
    [["@genType"],["@genType"]],
    "result", 
    ["@genType"]
  ).Expand()
+
  BuiltinBinOp("Subtract", "-", 
    ["a", "b"], 
    [["@genType"],["@genType"]],
    "result", 
    ["@genType"]
  ).Expand()
+
  BuiltinBinOp("Multiply", "*", 
    ["a", "b"], 
    [["@genType"],["@genType"]],
    "result", 
    ["@genType"]
  ).Expand()
+
  BuiltinBinOp("Divide", "/", 
    ["a", "b"], 
    [["@genType"],["@genType"]],
    "result", 
    ["@genType"]
  ).Expand()
+
  BuiltinShaderFn("Mix", "mix", 
    ["x", "y", "alpha"], 
    [["@genType"],["@genType"],["@genType", "float"]],
    "result", 
    ["@genType"]
  ).Expand()
;