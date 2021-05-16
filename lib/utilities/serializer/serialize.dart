import 'utils.dart';

///In order to deal with cyclic referencing, split
///deserialize into 2: create and fill
typedef DeserializeFillFn = void Function(DeserializeContext);
typedef DeserializeCreateFn = Object Function();
typedef SerializeFn = void Function(Object, SerializeContext);

class SerializerException{}

class SerializeFnNotFoundException extends SerializerException{
  String tag;
  SerializeFnNotFoundException(this.tag);
}

class DataFormatErrorException extends SerializerException{
  String message;
  DataFormatErrorException([this.message = ""]);
}


bool IsTriviallySerializable<T>(){
  return
    T is int
    || T is double
    || T is String
    || T is bool
  ;
}


class DeserializeContext{
  Object? Function(String id,DeserializeCreateFn, DeserializeFillFn) _getObj;
  Map<String, String> data;
  Object object;

  DeserializeContext(this._getObj, this.object, this.data);


  Object? DeserializeObject(String id, DeserializeCreateFn ctor, DeserializeFillFn fill){
    var id_trim = id.replaceAll(RegExp("[{}]"), '');
    return _getObj(id_trim, ctor, fill);
  }

  int GetInt(String name){ var val = data[name]!; return int.tryParse(val)!; }
  double GetDouble(String name){ var val = data[name]!; return double.tryParse(val)!; }
  String GetString(String name){return data[name]!;}
  bool GetBool(String name){return Str2Bool(data[name]!);}

  Object? GetSerializable(String name, DeserializeCreateFn ctor, DeserializeFillFn fill ){
    var id = GetString(name);
    return DeserializeObject(id, ctor, fill);
  }

  List<T> GetList<T>(String name, [DeserializeCreateFn? ctor, DeserializeFillFn? fill]){
    if(IsTriviallySerializable<T>()){
      return GetSerializable(name, ()=><T>[], (ctx){
        var li = ctx.object as List<T>;
        var cvt = 
          T is int ? int.tryParse :
          T is double? double.tryParse :
          T is bool ? Str2Bool:
          (s)=>s;
        int i = 0;
        
        while(true){
          var name = "__\$elem$i";
          var data = ctx.data[name];
          if(data == null) break;
          T val = cvt(data);
          li.add(val);
          i++; 
        }
      }) as List<T>;
    }

    return GetSerializable(name, ()=><T>[], (ctx){
      var li = ctx.object as List<T>;
      int i = 0;
      while(true){
        var name = "__\$elem$i";
        var id = ctx.data[name]; 
        if(id == null) break;
        T val = ctx.DeserializeObject(id, ctor!, fill!) as T;
        li.add(val);
        i++;        
      }
    }) as List<T>;
  }
}


class SerializeContext{

  String Function(Object? o, SerializeFn serializer) _fn;
  String tag;
  String id;

  Map<String, String> _data = {};

  SerializeContext(this._fn, this.tag, this.id)
  {
  }  

  String SerializeObject(o, SerializeFn fn)=> _fn(o, fn);

  void WriteProperty(String name, value){
    _data[name] = value.toString();
  }

  void WriteSerializable(String name, o, SerializeFn fn){
    var id = SerializeObject(o, fn);
    WriteProperty(name, id);
  }

  void WriteList<T>(String name, List<T> li, [SerializeFn? mapper]){
    if(IsTriviallySerializable<T>()){
      WriteSerializable(name, li, (obj, ctx) {
        var li = obj as List<T>;
        for(int i = 0; i < li.length; i++){
          var name = "__\$elem$i";
          ctx.WriteProperty(name, li[i].toString());
        }
      });
      return;
    }

    assert (mapper != null);

    WriteSerializable(name, li, (obj, ctx) {
      var li = obj as List<T>;
      for(int i = 0; i < li.length; i++){
        var name = "__\$elem$i";
        ctx.WriteSerializable(name, li[i], mapper!);
      }
    });
  }

  @override
  String toString(){
    var blk = StructuredBlock();
    blk.AddMap({
      "id":id,
      "tag":tag,
    });

    blk.AddMap(_data);
    return blk.toString();
  }
}



class Serializer{
  ///Default tagging function, subsequent classes may
  ///override this to better suit their needs
  static String GetTag(o) => o.runtimeType.toString();

  static String get rootID => "ROOT";
  static String get nullObjID => "<!>";

  static String GenerateID(String tag, int index){
    return "<$tag-${index}>";
  }

  ///may throw [SerializeFnNotFoundException]
  static String SerializeObject(o, SerializeFn fn){

    Map<Object, SerializeContext> _visited = {};

    var tag = GetTag(o);

    String _SerDelegate(Object? o, SerializeFn fn){
      if(o == null) return nullObjID;
      var _ctx = _visited[o];
      if(_ctx == null){
        var tag = GetTag(o);
        var id = GenerateID(tag, _visited.length);
        _ctx = SerializeContext(_SerDelegate, tag, id);
        _visited[o] = _ctx;
        fn(o, _ctx);
      }

      return _ctx.id;
    }

    var rootCtx = SerializeContext(_SerDelegate, tag, rootID);
     _visited[o] = rootCtx;
    fn(o, rootCtx);

    var str = "";
    for(var e in _visited.entries){
      str += e.value.toString();
    }
    return str;
  }

  ///Object? errMsg?
  ///may throw [SerializeFnNotFoundException], [DataFormatErrorException]
  static Object DeserializeObject(String data,DeserializeCreateFn ct, DeserializeFillFn fill){
    var blks = FindBlock(data);
    //id->data
    Map<String, String> dataMap = {};
    Map<String, Object> _visited = {};

    Object? _DesDelegate(String id, DeserializeCreateFn ct, DeserializeFillFn fill){
      if(id == nullObjID) return null;
      var _o = _visited[id];
      if(_o == null){
        _o = ct();
        _visited[id] = _o;
        var data = Str2StrMap(dataMap[id]!);
        var ctx = DeserializeContext(_DesDelegate, _o, data);
        fill(ctx);
      }

      return _o;
    }

    for(var blk in blks){
      var parts = FindBlock(blk);
      if(parts.length != 2) throw DataFormatErrorException();
      var info = parts.first;
      var data = parts.last;

      var infoMap = Str2StrMap(info);
      var tag = infoMap["tag"];
      if(tag == null)
        throw DataFormatErrorException("Tag not found in info block");

      var id = infoMap["id"];
      if(id == null)
        throw DataFormatErrorException("ID not found in info block");

      //var fn = _GetDeserializeFn(tag);
      dataMap[id] = data;
    }

    var rootData = dataMap[rootID];
    if(rootData == null)
      throw DataFormatErrorException("No root object found");

    var root = ct();
    _visited[rootID] = root;
    var d = Str2StrMap(dataMap[rootID]!);
    var ctx = DeserializeContext(_DesDelegate, root, d);
    fill(ctx);

    return root;
  }
}
