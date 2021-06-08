
import 'package:infcanvas/scripting/brush_editor.dart';
import 'package:infcanvas/scripting/editor/vm_node_serializer.dart';
import 'package:infcanvas/scripting/editor/vm_serializer.dart';
import 'package:infcanvas/scripting/shader_editor/shader_editor.dart';
import 'package:infcanvas/scripting/shader_editor/shader_node_serializer.dart';
import 'package:infcanvas/scripting/shader_editor/shader_serializer.dart';
import 'package:infcanvas/utilities/type_helper.dart';

class BrushProgSerializer extends VMNodeSerializer{

  @override doSerializeNode(node){
    if(node is! GNBrushPipelineAddStage)
      return super.doSerializeNode(node);
    return node.shader?.fullName??"";
  }


  @override doDeserializeNode(tag, analyzer, data){
    if(tag != "GNBrushPipelineAddStage")
      return super.doDeserializeNode(tag, analyzer, data);
    var env = analyzer.env as BrushEditorEnv;
    var brush = env.brushData!;
    var node = GNBrushPipelineAddStage(brush);
    for(var s in brush.shaderLib.functions){
      if(s.fullName == data){
        node.shader = s;
      }
    }
    return node;
  }

}


Map<String, dynamic> SerializeBrush(BrushData brush){
  var ser = BrushProgSerializer();
  var prog = SerializeCodeLibrary(ser, brush.progLib);
  var sser = ShaderNodeSerializer();
  var shd = SerializeShaderLibrary(sser, brush.shaderLib);
  return {
    "brushName":brush.name,
    "spacing":brush.spacing,
    "program":prog,
    "shader":shd,
  };
}

BrushData DeserializeBrush(Map<String, dynamic> data){

  var brush = BrushData.createSkeleton("");

  DeserializeBrushInPlace(brush, data);

  return brush;
}

void DeserializeBrushInPlace(BrushData brush, Map<String, dynamic> data){
  var name = TryCast<String>(data["brushName"])??"Unnamed";
  double spacing = TryCast(data["spacing"])??0.1;
  var data_shd = TryCast<Map<String,dynamic>>(data["shader"])??{};
  var data_prog = TryCast<Map<String,dynamic>>(data["program"])??{};
  var prog = CreateLibSkeleton (data_prog);
  var shd = CreateShaderLibSkeleton(data_shd);

  //Brush first because of pipeline nodes
  var sser = ShaderNodeSerializer();
  var env_shd = ShaderEditorEnv();
  env_shd.targetLib = shd;
  FillShaderLibSkeleton(env_shd, sser, shd, data_shd);

  brush.name = name;
  brush.spacing = spacing;
  brush.shaderLib = shd;
  brush.progLib = prog;
  var ser = BrushProgSerializer();
  var env_brush = BrushEditorEnv();
  env_brush.brushData = brush;
  FillLibSkeleton(env_brush, ser, prog, data_prog);
  brush.ValidateBrushEventGraph();

  env_shd.Dispose();
  env_brush.Dispose();
}

