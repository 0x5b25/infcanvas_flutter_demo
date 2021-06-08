
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:infcanvas/scripting/editor/generic_slot.dart';
import 'package:infcanvas/scripting/editor/vm_compiler.dart';
import 'package:infcanvas/scripting/graph_compiler.dart';
import 'package:infcanvas/scripting/editor/vm_opcodes.dart';
import 'package:infcanvas/scripting/script_graph.dart';
import 'package:infcanvas/scripting/editor/vm_types.dart';
import 'package:infcanvas/scripting/editor_widgets.dart';
import 'package:infcanvas/scripting/codepage.dart';
import 'package:infcanvas/scripting/editor/vm_editor.dart';
import 'package:infcanvas/utilities/type_helper.dart';

import 'codemodel.dart';

void AlignLists<SrcTy, TgtTy>(
  List<SrcTy> srcList,
  List<TgtTy> targetList,
  SrcTy Function(TgtTy t) ctor,
  {
    void Function(SrcTy s)? finalizer,
    void Function(SrcTy s, TgtTy t)? updater
  }
){
  //Remove excess
  int cnt = targetList.length;
  for(int i = cnt; i < srcList.length; i++){
    var removed = srcList.last;
    finalizer?.call(removed);
    srcList.removeLast();
  }

  //Update
  for(int i = 0; i < cnt; i++){
    var matchTarget = targetList[i];
    if(i >= srcList.length){
      srcList.add(ctor(matchTarget));
      continue;
    }

    var matchSrc = srcList[i];
    updater?.call(matchSrc, matchTarget);
  }
}


Map<String, Color> _typeColors = {
  "":Colors.yellow,
  "Num|Int":Colors.green[400]!,
  "float":Colors.orange,
  "float2":Colors.deepOrange,
  "float3":Colors.pinkAccent,
  "float4":Colors.deepPurple,
  "Num|Float":Colors.orange,
  "Vec|Vec2":Colors.deepOrange,
  "Vec|Vec3":Colors.pinkAccent,
  "Vec|Vec4":Colors.deepPurple,
};

Color GetColorForType(String? type){
  var color = _typeColors[type];
  return color??Colors.cyan;
}

Map<Type, IconData> _slotLinkedIcon = {

  ValueInSlotInfo: Icons.radio_button_on,
  ValueOutSlotInfo:Icons.radio_button_on,
  ExecInSlotInfo:  Icons.label,
  ExecOutSlotInfo: Icons.label,

};


Map<Type, IconData> _slotEmptyIcon = {
  ValueInSlotInfo: Icons.radio_button_off,
  ValueOutSlotInfo:Icons.radio_button_off,
  ExecInSlotInfo:  Icons.label_outline,
  ExecOutSlotInfo: Icons.label_outline,
};

IconData GetConnectedIconForSlot(Type slotTy){
  var lut = _slotLinkedIcon;
  var ico = lut[slotTy];
  return ico??Icons.adb;
}


IconData GetDisconnectedIconForSlot(Type slotTy){
  var lut = _slotEmptyIcon;
  var ico = lut[slotTy];
  return ico??Icons.adb;
}

mixin PaintableSlot on SlotInfo implements ISlotPainter{
  String? get typeName => "";
  @override get iconColor => GetColorForType(typeName);
  @override get iconConnected => GetConnectedIconForSlot(this.runtimeType);
  @override get iconDisconnected => GetDisconnectedIconForSlot(this.runtimeType);
}

class ValueInSlotInfo extends InSlotInfo
    with SingleConnSlotMixin, PaintableSlot, PairConstructor
{

  CodeType? type;
  @override get typeName => type?.fullName;

  ValueInSlotInfo(GraphNode node, String name, [this.type]) : super(node, name);

  @override
  bool CanEstablishLink(SlotInfo slot) {
    if(type == null) return false;
    if(!(slot is ValueOutSlotInfo)) return false;
    var fromType = slot.type;
    if(fromType == null) return false;
    return fromType!.IsSubTypeOf(type!);
  }

  @override doCreateCounterpart()=>ValueOutSlotInfo(
      node, name,
      type
  );

  @override get iconConnected => GetConnectedIconForSlot(ValueInSlotInfo);
  @override get iconDisconnected => GetDisconnectedIconForSlot(ValueInSlotInfo);

}

class ValueOutSlotInfo extends OutSlotInfo
    with MultiConnSlotMixin, PaintableSlot, PairConstructor
{
  CodeType? type;
  @override get typeName => type?.fullName;

  int outputOrder;

  ValueOutSlotInfo(GraphNode node, String name,
      [this.type, this.outputOrder = 0]) : super(node, name);

  @override
  bool CanEstablishLink(SlotInfo slot) {
    if(type == null) return false;
    if(!(slot is ValueInSlotInfo)) return false;
    var toType = slot.type;
    if(toType == null) return false;
    return type!.IsSubTypeOf(toType!);
  }

  @override doCreateCounterpart()=>ValueInSlotInfo(
      node, name,
      type
  );

  @override get iconConnected => GetConnectedIconForSlot(ValueOutSlotInfo);
  @override get iconDisconnected => GetDisconnectedIconForSlot(ValueOutSlotInfo);

}

class FieldInSlotInfo extends ValueInSlotInfo{

  CodeField field;
  @override CodeType? get type => field.type;

  @override String get name => field.name.value;

  FieldInSlotInfo(GraphNode node, this.field)
      :super(node, ""){
    // Watch<FieldTypeChangeEvent>(field, (e){
    //   if(e.oldType == null || !e.oldType!.IsSubTypeOf(e.newType)){
    //     Disconnect();
    //   }
    // });
  }

  @override
  void Dispose(){
    super.Dispose();
    Disconnect();
    field = CodeField.emptyField;
  }

}

class FieldOutSlotInfo extends ValueOutSlotInfo{

  CodeField field;
  @override CodeType? get type => field.type;
  @override int get outputOrder => field.index;

  @override String get name => field.name.value;

  FieldOutSlotInfo(GraphNode node, this.field)
      :super(node, ""){
    // Watch<FieldTypeChangeEvent>(field, (e){
    //   if(e.newType == null || !e.newType!.IsSubTypeOf(e.oldType)){
    //     Disconnect();
    //   }
    // });
  }
  void Dispose(){
    super.Dispose();
    Disconnect();
    field = CodeField.emptyField;
  }

  //@override CreateCounterpart()=>FieldInSlotInfo(node, field);

}

class ExecInSlotInfo extends InSlotInfo
    with MultiConnSlotMixin, PaintableSlot, PairConstructor
{
  ExecInSlotInfo(GraphNode node,[String name = "Exec"]):super(node, name);

  @override
  bool CanEstablishLink(SlotInfo slot) {
    return slot is ExecOutSlotInfo;
  }

  @override doCreateCounterpart()=>ExecOutSlotInfo(node);


}

class ExecOutSlotInfo extends OutSlotInfo
    with SingleConnSlotMixin, PaintableSlot, PairConstructor
{
  ExecOutSlotInfo(GraphNode node, [String name = "Then"]):super(node, name);

  @override
  bool CanEstablishLink(SlotInfo slot) {
    return slot is ExecInSlotInfo;
  }

  @override doCreateCounterpart()=>ExecInSlotInfo(node);

}



abstract class CodeGraphNode extends GraphNode with DrawableNodeMixin
{

  late CodeMethodBase thisMethod;

  @override
  void RemoveLinks() {
    for(var s in inSlot) s.Disconnect();
    for(var s in outSlot) s.Disconnect();
  }

  @override String UniqueTag() => runtimeType.toString();


  void UpdateInputList(
      List<FieldInSlotInfo> slots,
      CodeFieldArray target
      ){
    AlignLists(slots, target.fields, (CodeField f) => FieldInSlotInfo(this,f));
  }

  void UpdateOutputList(
      List<FieldOutSlotInfo> slots,
      CodeFieldArray target
      ){
    AlignLists(slots, target.fields, (CodeField f) => FieldOutSlotInfo(this,f));
  }
  CodeGraphNode doCloneNode();

  @override CodeGraphNode Clone(){
    var gn = doCloneNode();
    gn.thisMethod = thisMethod;
    return gn;
  }

  @override void Dispose(){
    for(var s in inSlot){
      s.Dispose();
    }

    for(var s in outSlot){
      s.Dispose();
    }
  }
}

class VMNormalOpTU extends VMNodeTranslationUnit{

  List<ValueInSlotInfo> valDeps;
  List<ExecOutSlotInfo> subsequentExec;
  CodeBlock? code;
  int stackUsage;

  ///Assume that codeblock follows call convention
  ///and valDeps are needed arguments
  VMNormalOpTU({
    this.stackUsage = 0,
    this.valDeps = const [],
    this.subsequentExec = const [],
    this.code
  }){

  }

  @override int ReportStackUsage() => stackUsage;

  @override
  void Translate(VMGraphCompileContext ctx) {
    var n = fromWhichNode as CodeGraphNode;
    bool explicit = n.needsExplicitExec;
    assert(explicit == subsequentExec.isNotEmpty, "Explicit node must have a"
        " subsequent execute output");
    //valdeps
    var depAddr = List.filled(valDeps.length, 0);
    for(int i = 0; i < valDeps.length; i++){
      var slot = valDeps[i];
      var link = slot.link;
      if(link == null){
        ctx.ReportError("Input $i can't be null");
        continue;
      }
      var rear = link.from as ValueOutSlotInfo;
      var n = TryCast<CodeGraphNode>(rear.node);
      if(n==null){
        ctx.ReportError("Input $i is unknow type ${rear.node}");
        continue;
      }
      var idx = rear.outputOrder;
      depAddr[i] = ctx.AddValueDependency(n, idx);
    }
    //assign position
    ctx.AssignStackPosition();

    //code emits
    if(code != null) {
      ctx.EmitCode(SimpleCB(
        [
          for(var addr in depAddr)
            InstLine(OpCode.ldarg, i:addr),
        ]
      )..debugInfo = "Load arguments");
      ctx.EmitCode(code!);
    }

    //Subsequent executions
    for(var s in subsequentExec){
      var n = TryCast<CodeGraphNode>(s.link?.to.node);
      ctx.AddNextExec(n);
    }
  }
}

class DirectTU extends VMNodeTranslationUnit{

  DirectOpNode get dn => fromWhichNode as DirectOpNode;

  @override
  int ReportStackUsage() => dn.stackUsage;
  @override
  void Translate(VMGraphCompileContext ctx) {
    ctx.EmitCode(SimpleCB(dn.instructions));
  }

}

abstract class DirectOpNode extends CodeGraphNode{
  @override doCreateTU()=> DirectTU();
  List<InstLine> get instructions;
  int get stackUsage;
  ///Since there is often no input needs...
  @override List<InSlotInfo> get inSlot => [];
}

//Variables
//Const
class ConstIntNode extends DirectOpNode with GNPainterMixin{
  int val = 0;

  @override get displayName => "Constant Int";
  @override get needsExplicitExec => false;

  late final constOut = ValueOutSlotInfo(this, "i", VMBuiltinTypes.intType);

  @override get inSlot => [];
  @override get outSlot => [constOut];

  bool SetVal(String val){
    var newIVal = int.tryParse(val);
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

  @override CodeGraphNode doCloneNode() {
    return ConstIntNode()..val = val;
  }

  @override get stackUsage => 1;
  @override
  List<InstLine> get instructions => [
    InstLine(OpCode.PUSHIMM, i:val),
  ];
}

class ConstFloatNode extends DirectOpNode with GNPainterMixin{
  double val = 0;

  @override get displayName => "Constant Float";
  @override get needsExplicitExec => false;

  late final constOut = ValueOutSlotInfo(this, "i", VMBuiltinTypes.floatType);

  @override get inSlot => [];
  @override get outSlot => [constOut];

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

  @override doCloneNode()=>ConstFloatNode()..val = val;

  @override get stackUsage => 1;
  @override
  List<InstLine> get instructions => [
    InstLine(OpCode.PUSHIMM, f:val),
  ];
}

//Ref values
class InstantiateNode extends DirectOpNode implements IValidatableNode{
  CodeType type;

  @override String get displayName => "Instantiate ${type.name.value}";

  late final valOut = ValueOutSlotInfo(this, "object", type);

  InstantiateNode(this.type);

  @override doCloneNode() => InstantiateNode(type);

  @override Validate(analyzer){
    if(type.isDisposed || !type.isRef.value) return false;
    bool found = analyzer.TypeContainedInDeps(type);
    if(!found) return false;
    Update();
    return true;
  }

  @override bool get needsExplicitExec => false;
  @override List<OutSlotInfo> get outSlot => [valOut];

  @override List<InstLine> get instructions => [
    InstLine(OpCode.newobj, s:type.fullName)
  ];

  @override get stackUsage => 1;
}

class ConstructNode extends CodeGraphNode implements IValidatableNode{
  CodeType type;

  @override get displayName => "Construct ${type.name}";

  final List<FieldInSlotInfo> memIn = [];
  late final valOut = ValueOutSlotInfo(this, "object", type);

  @override get inSlot => memIn;
  @override get outSlot => [valOut];
  @override get needsExplicitExec => false;

  ConstructNode(this.type){Update();}

  @override doCloneNode() => ConstructNode(type);

  @override Update(){
    UpdateInputList(memIn, type.fields);
    super.Update();
  }

  @override Validate(analyzer){
    if(type.isDisposed || !type.isRef.value) return false;
    bool found = analyzer.TypeContainedInDeps(type);
    if(!found) return false;
    Update();
    return true;
  }


  @override
  NodeTranslationUnit doCreateTU() {
    return VMNormalOpTU(
      stackUsage: 1,
      valDeps: memIn,
      code: SimpleCB([InstLine(OpCode.newobj, s:type.fullName)])
        ..debugInfo = "ct ${type.fullName}"
    );
  }

}

//Entry
class CodeEntryNode extends CodeGraphNode with GNPainterMixin{

  CodeMethod method;

  String get displayName => "Entry";

  @override get closable => method.isConst.value;

  late final execOut = ExecOutSlotInfo(this);
  final valOut = <FieldOutSlotInfo>[];

  @override List<InSlotInfo> get inSlot => [];
  @override List<OutSlotInfo> get outSlot{
    if(needsExplicitExec){
      return <OutSlotInfo>[execOut] + valOut;
    }else{
      return valOut;
    }
  }

  @override bool get needsExplicitExec => !method.isConst.value;

  ///Doesn't observe until being cloned,
  ///because of DART'S SHITTY WEAK REFERENCING!
  CodeEntryNode(this.method){thisMethod = method;Update();}

  @override Update(){
    if(!needsExplicitExec)
      execOut.Disconnect();
    UpdateOutputList(valOut, thisMethod.args);
    super.Update();
  }
  @override NodeTranslationUnit doCreateTU()=>CodeEntryTU();
  @override CodeGraphNode doCloneNode() => CodeEntryNode(method);
}

class CodeEntryTU extends VMNodeTranslationUnit with VMAnchoredTUMixin{

  CodeEntryTU(){
    anchoredPosition = 0;
  }
  @override
  void Translate(VMGraphCompileContext ctx) {
    var n = fromWhichNode as CodeEntryNode;
    if(n.needsExplicitExec){
      var nextlnk = n.execOut.link;
      var node = nextlnk?.to.node;
      ctx.AddNextExec(TryCast<CodeGraphNode>(node));
    }
  }
}

//Return
class CodeReturnNode extends CodeGraphNode with GNPainterMixin{
  CodeMethod method;

  String get displayName => "Return";

  @override get closable => !method.isConst.value;

  late final execIn = ExecInSlotInfo(this);
  final valIn = <FieldInSlotInfo>[];

  @override List<OutSlotInfo> get outSlot => [];
  @override List<InSlotInfo> get inSlot{
    if(needsExplicitExec){
      return <InSlotInfo>[execIn] + valIn;
    }else{
      return valIn;
    }
  }

  @override bool get needsExplicitExec => !method.isConst.value;

  ///Doesn't observe until being cloned,
  ///because of DART'S SHITTY WEAK REFERENCING!
  CodeReturnNode(this.method){thisMethod = method;Update();}

  @override Update(){
    if(!needsExplicitExec)
      execIn.Disconnect();
    UpdateInputList(valIn, thisMethod!.rets);
    super.Update();
  }

  @override CodeGraphNode doCloneNode() => CodeReturnNode(method);

  @override doCreateTU() => CodeRetTU();
}


class CodeRetTU extends VMNodeTranslationUnit{

  CodeReturnNode get node => fromWhichNode as CodeReturnNode;

  int get inputCnt => node.thisMethod.rets.length;

  @override
  int ReportStackUsage() => 0;

  @override
  void Translate(VMGraphCompileContext ctx) {

    _doGetValDep(int idx) {
      var iSlot = node.valIn[idx];
      var link = iSlot.link;
      if(link == null) return null;
      var depSlot = link.from as ValueOutSlotInfo;
      return depSlot;
    }

    var addrs = [];

    for(int i = inputCnt - 1;i>=0;i--){
      var dep = _doGetValDep(i);
      if(dep == null)
      {
        ctx.ReportError("Return value input $i is empty");
        return;
      }
      var n = TryCast<CodeGraphNode>(dep.node);
      if(n == null)
      {
        ctx.ReportError("Return value input $i is of unknown type");
        return;
      }
      addrs.add(ctx.AddValueDependency(n , dep.outputOrder));
    }

    var retCnt = addrs.length;

    ctx.EmitCode(SimpleCB([
      //Gather ret vals
      for(var addr in addrs)
        InstLine(OpCode.ldarg, i:addr),
      //Store ret to place, reversed operation because of
      //stack implementation of VM
      for(int i = retCnt - 1; i>=0; i--)
        InstLine(OpCode.starg, i:i),
      InstLine(OpCode.RET)
    ])..debugInfo = "Function Return");
  }

}

//Function call

class CodeInvokeNode extends CodeGraphNode implements IValidatableNode{

  CodeMethodBase whichMethod;

  @override String get displayName => whichMethod.name.value;
  CodeType get targetType => whichMethod.thisType!;

  CodeInvokeNode(this.whichMethod){
    assert(whichMethod.thisType != null);
    Update();
  }


  late final ExecInSlotInfo execIn = ExecInSlotInfo(this);
  late final ExecOutSlotInfo execOut = ExecOutSlotInfo(this);

  late final ValueInSlotInfo targetIn = ValueInSlotInfo(this,
    "Target", targetType
  );

  late final List<FieldInSlotInfo> argIn = [];
  late final List<FieldOutSlotInfo> valOut = [];

  @override bool get needsExplicitExec => !whichMethod.isConst.value;

  @override List<InSlotInfo> get inSlot => <InSlotInfo>[
    if(needsExplicitExec) execIn,
    if(!whichMethod.isStatic.value) targetIn,
  ] + argIn;

  @override List<OutSlotInfo> get outSlot => <OutSlotInfo>[
    if(needsExplicitExec) execOut
  ] + valOut;

  Update(){
    if(!needsExplicitExec) {
      execIn.Disconnect();
      execOut.Disconnect();
    }
    UpdateInputList(argIn, whichMethod.args);
    UpdateOutputList(valOut, whichMethod.rets);
    super.Update();
  }

  @override
  CodeInvokeNode doCloneNode()=>CodeInvokeNode(whichMethod);

  @override
  NodeTranslationUnit doCreateTU() => VMNormalOpTU(
    stackUsage: whichMethod.rets.length,
    valDeps: argIn,
    subsequentExec: [if(needsExplicitExec) execOut],
    code: SimpleCB([
      InstLine(
        whichMethod.isEmbeddable?
          OpCode.d_embed:
        whichMethod.isStatic.value?
          OpCode.callstatic:
          OpCode.callmem,
        s:whichMethod.fullName
      )
    ])
  );

  @override
  bool Validate(VMMethodAnalyzer analyzer) {
    if(whichMethod.isDisposed) return false;
    if(whichMethod.thisType == null) return false;
    return analyzer.TypeContainedInDeps(whichMethod.thisType!);
  }

}

//Accessors
//Desc shouldn't be altered after creation
//field accessors assume that desc won't change
class FieldDesc{
  final CodeType targetType;
  final CodeField whichField;
  final bool isStatic;

  get fullName => whichField.fullName;

  bool get isValid => !(whichField.isDisposed) && !(targetType.isDisposed);

  static bool GetIsStatic(type, field){
    var f = type.fields.fields;
    if(f.contains(field)) {
      return false;
    }

    var sf = type.staticFields.fields;
    if(sf.contains(field)){
      return true;
    }

    throw ArgumentError("Field ${field.name} isn't contained in Type "
        "${type.name}");

  }

  static bool test() => true;

  FieldDesc(this.targetType, this.whichField)
    :isStatic =GetIsStatic(targetType, whichField)
  {}

  String get name => whichField.name.toString();
  CodeType? get type => whichField.type;
}
//    Getter
class CodeFieldGetterNode extends CodeGraphNode with IValidatableNode{

  FieldDesc whichField;

  CodeFieldGetterNode(this.whichField);

  @override String get displayName => "Get ${whichField.name}";

  @override bool get needsExplicitExec => false;

  late final ValueInSlotInfo tgtIn = ValueInSlotInfo(this, "Target"
    ,whichField.targetType
  );

  late final FieldOutSlotInfo valOut =
    FieldOutSlotInfo(this, whichField.whichField);

  @override List<OutSlotInfo> get outSlot => [valOut];
  @override List<InSlotInfo> get inSlot => [
    if(!whichField.isStatic) tgtIn,
  ];

  @override CodeFieldGetterNode doCloneNode()=>CodeFieldGetterNode
    (whichField);

  @override
  NodeTranslationUnit doCreateTU() => VMNormalOpTU(
      stackUsage: 1,
      valDeps: [if(!whichField.isStatic) tgtIn],
      code: SimpleCB([whichField.isStatic?
      InstLine(OpCode.ldstatic, s:whichField.fullName):
      InstLine(OpCode.ldmem, s:whichField.fullName)
      ])
  );

  @override
  bool Validate(VMMethodAnalyzer analyzer) {
    if(!whichField.isValid) return false;
    return analyzer.TypeContainedInDeps(whichField.targetType);
  }

  @override Update(){
    if(whichField.isStatic)
      tgtIn.Disconnect();
    super.Update();
  }
}
//    Setter
class CodeFieldSetterNode extends CodeGraphNode implements IValidatableNode{

  FieldDesc whichField;

  CodeFieldSetterNode(this.whichField);

  @override String get displayName => "Set ${whichField.name}";

  @override bool get needsExplicitExec => true;

  late final execIn = ExecInSlotInfo(this);
  late final execOut = ExecOutSlotInfo(this);

  late final ValueInSlotInfo tgtIn = ValueInSlotInfo(this, "Target",
    whichField.targetType
  );

  late final valIn =
    FieldInSlotInfo(this, whichField.whichField);

  @override List<OutSlotInfo> get outSlot => [execOut];
  @override List<InSlotInfo> get inSlot => [
    execIn, if(!whichField.isStatic) tgtIn, valIn
  ];

  @override CodeFieldSetterNode doCloneNode()=>CodeFieldSetterNode
    (whichField);

  // [val, target] <- stack top
  @override
  NodeTranslationUnit doCreateTU() => VMNormalOpTU(
    stackUsage: 0,
    subsequentExec: [execOut],
    valDeps: [valIn, if(!whichField.isStatic) tgtIn],
    code: SimpleCB([whichField.isStatic?
      InstLine(OpCode.ststatic, s:whichField.fullName):
      InstLine(OpCode.stmem, s:whichField.fullName)
    ])
  );

  @override Update(){
    if(whichField.isStatic)
      tgtIn.Disconnect();
    super.Update();
  }

  @override
  bool Validate(VMMethodAnalyzer analyzer) {
    if(!whichField.isValid) return false;
    return analyzer.TypeContainedInDeps(whichField.targetType);
  }

}
// is null
class AnyValInSlotInfo extends ValueInSlotInfo{
  AnyValInSlotInfo(GraphNode node, String name) : super(node, name);

  @override get type => null;

  @override bool CanEstablishLink(SlotInfo slot) {
    return slot is ValueOutSlotInfo;
  }

  @override SlotInfo? doCreateCounterpart() => null;  

}

class CodeIsObjNullNode extends CodeGraphNode{

  @override get displayName => "Is Null";
  @override doCloneNode() => CodeIsObjNullNode();
  @override get needsExplicitExec => false;

  GenericArgGroup genGroup = GenericArgGroup(GenericArg("Object"));

  late final GenericValueInSlotInfo tgtIn = 
    GenericValueInSlotInfo(this, "Target", genGroup);

  late final ValueOutSlotInfo valOut =
    ValueOutSlotInfo(this, "is null", VMBuiltinTypes.intType);

  @override List<OutSlotInfo> get outSlot => [valOut];
  @override List<InSlotInfo> get inSlot => [tgtIn];

  @override
  NodeTranslationUnit doCreateTU() => VMNormalOpTU(
      stackUsage: 1,
      valDeps: [tgtIn],
      code: SimpleCB([InstLine(OpCode.isnull)])
  );
}

//    GetThis

class CodeThisGetterNode extends DirectOpNode implements IValidatableNode{

  CodeThisGetterNode(CodeMethodBase method){this.thisMethod = method;}

  CodeType? get thisType => thisMethod.thisType;

  @override String get displayName => "Get this object";

  @override bool get needsExplicitExec => false;

  late final FieldOutSlotInfo valOut =
  FieldOutSlotInfo(this, CodeField("object")..type = thisType);

  @override List<OutSlotInfo> get outSlot => [valOut];

  @override CodeThisGetterNode doCloneNode()=>CodeThisGetterNode(thisMethod);

  @override List<InstLine> get instructions => [
    InstLine(OpCode.ldthis)
  ];

  @override get stackUsage => 1;

  @override Validate(analyzer){
    if(thisMethod.isStatic.value) return false;
    if(thisType == null) return false;
    return analyzer.TypeContainedInDeps(thisType!);
  }
}
//Control flow
//    if

class CodeIfNode extends CodeGraphNode{
  late final execIn = ExecInSlotInfo(this);
  late final condIn = ValueInSlotInfo(this, "Condition", VMBuiltinTypes.intType);

  late final execOutTrue = ExecOutSlotInfo(this, "True");
  late final execOutFalse = ExecOutSlotInfo(this, "False");

  @override String get displayName => "If";

  @override CodeIfNode doCloneNode() => CodeIfNode();

  @override bool get needsExplicitExec => true;

  @override doCreateTU() => IfNodeTU();

  @override get inSlot => [execIn, condIn];
  @override get outSlot => [execOutTrue, execOutFalse];
}


class IfNodeTU extends VMNodeTranslationUnit{
  @override ReportStackUsage()=>0;
  @override CanHandleEOF()=>false;

  @override
  void Translate(VMGraphCompileContext ctx) {
    var node = fromWhichNode as CodeIfNode;
    var condSlot = node.inSlot.last as ValueInSlotInfo;
    var condLink = condSlot.link;
    if(condLink == null){
      ctx.ReportError("Condition input is emply!");
      return;
    }
    var rear = condLink.from as ValueOutSlotInfo;
    var n = TryCast<CodeGraphNode>(rear.node);
    if(n == null){
      ctx.ReportError("Condition input is of unknown type: ${rear.node}");
      return;
    }
    var addr = ctx.AddValueDependency(n, rear.outputOrder);

    var jmpTarget = SimpleCB([]);
    ctx.EmitCode(SimpleCB([InstLine(OpCode.ldarg, i:addr)]));
    ctx.EmitCode(IfJmpCB(jmpTarget));

    //True branch
    {
      ctx.EnterScope();
      var slot = node.execOutTrue;
      var link = slot.link;
      ctx.AddNextExec(TryCast<CodeGraphNode>(link?.to.node));
      ctx.ExitScope();
    }

    ctx.EmitCode(jmpTarget);

    //False branch
    {
      ctx.EnterScope();
      var slot = node.execOutFalse;
      var link = slot.link;
      ctx.AddNextExec(TryCast<CodeGraphNode>(link?.to.node));
      ctx.ExitScope();
    }
  }

}

class IfJmpCB extends CodeBlock{

  CodeBlock target;
  IfJmpCB(this.target);

  @override bool NeedsMod()=>true;

  @override
  void ModCode(List<InstLine> code){
    var delta = target.startLine - startLine;
    code[startLine] = InstLine(OpCode.JZI, i:delta);
  }

  @override
  Iterable<InstLine> EmitCode(int lineCnt) {
    return[InstLine(OpCode.JZI, i:0)];
  }

}

//    sequence

class CodeSequenceNode extends CodeGraphNode with GNPainterMixin{

  @override get displayName => "Sequence";

  late final execIn = ExecInSlotInfo(this);
  final List<ExecOutSlotInfo> seqOut = [];

  @override get outSlot => seqOut;
  @override get inSlot => [execIn];

  @override get needsExplicitExec => true;
  int get seqCnt => seqOut.length;

  CodeSequenceNode(){
    seqOut.add(ExecOutSlotInfo(this, "1"));
    seqOut.add(ExecOutSlotInfo(this, "2"));
    seqOut.add(ExecOutSlotInfo(this, "3"));
  }

  void SetSeqCnt(int cnt){
    if(cnt < 1) cnt = 1;

    var delta = cnt - seqCnt;
    if(delta > 0){
      for(int i = 0; i < delta; i++){
        var idx = seqCnt + 1;
        outSlot.add(ExecOutSlotInfo(this, "$idx"));
      }
    }else{
      for(int i = 0; i < -delta; i++){
        outSlot.last.Disconnect();
        outSlot.removeLast();
      }
    }
  }

  @override
  Widget Draw(BuildContext ctx, update){
    var defaultWid = super.Draw(ctx, update);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        defaultWid,
        Row(children: [
          Expanded(child: TextButton(
            child: Icon(Icons.remove),
            onPressed: (){SetSeqCnt(seqCnt - 1); update();},
          ),),
          Expanded(child: TextButton(
            child: Icon(Icons.add),
            onPressed: (){SetSeqCnt(seqCnt + 1); update();},
          ),)
        ],)
      ],
    );
  }

  @override doCloneNode()=> CodeSequenceNode();

  @override
  VMNodeTranslationUnit doCreateTU() {
    return SeqNodeTU();
  }
}

class SeqNodeTU extends VMNodeTranslationUnit{

  CodeSequenceNode get node =>(fromWhichNode as CodeSequenceNode);

  int get cnt => node.seqCnt;
  int currCnt = 0;
  bool get isLast => currCnt == cnt-1;
  @override bool CanHandleEOF() => !isLast;

  @override
  CodeBlock? HandleEOF(VMNodeTranslationUnit issued){
    return null;
  }

  CodeGraphNode? doGetNode(int idx){
    var slot = node.seqOut[idx];
    var lnk = slot.link;
    return TryCast<CodeGraphNode>(lnk?.to.node);
  }

  @override int ReportStackUsage() => 0;

  @override
  void Translate(VMGraphCompileContext ctx) {
    while(currCnt < cnt){
      ctx.EnterScope();
      ctx.AddNextExec(doGetNode(currCnt));
      ctx.ExitScope();
      currCnt++;
    }
  }
}
