
import 'package:infcanvas/scripting/brush_editor.dart';
import 'package:infcanvas/scripting/editor/vm_node_serializer.dart';
import 'package:infcanvas/scripting/editor/vm_serializer.dart';
import 'package:infcanvas/scripting/shader_editor/shader_editor.dart';
import 'package:infcanvas/scripting/shader_editor/shader_node_serializer.dart';
import 'package:infcanvas/scripting/shader_editor/shader_serializer.dart';

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
    "program":prog,
    "shader":shd,
  };
}

BrushData DeserializeBrush(Map<String, dynamic> data){
  var name = data["brushName"];
  var data_shd = data["shader"];
  var data_prog = data["program"];
  var prog = CreateLibSkeleton (data_prog);
  var shd = CreateShaderLibSkeleton(data_shd);

  //Brush first because of pipeline nodes
  var sser = ShaderNodeSerializer();
  var env_shd = ShaderEditorEnv();
  env_shd.targetLib = shd;
  FillShaderLibSkeleton(env_shd, sser, shd, data_shd);

  var dummyBrush = BrushData.createNew("DummyBrush");
  dummyBrush.shaderLib = shd;
  var ser = BrushProgSerializer();
  var env_brush = BrushEditorEnv();
  env_brush.brushData = dummyBrush;
  FillLibSkeleton(env_brush, ser, prog, data_prog);

  env_shd.Dispose();
  env_brush.Dispose();

  return BrushData(name, prog, shd);
}

