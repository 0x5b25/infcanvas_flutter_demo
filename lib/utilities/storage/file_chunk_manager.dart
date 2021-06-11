import 'dart:io';

import 'dart:typed_data';

///File structure
/// +--------------------------+-------------+
/// | Signature                |             |
/// +--------------------------+             |
/// | Master chunk ID (0)      |             |
/// +--------------------------+             |
/// | Master chunk Length (4)  |             |
/// +--------------------------+ File header |
/// | Next chunk offset        |  32 Bytes   |
/// +--------------------------+             |
/// | Master record 0          |             |
/// | ...                      |             |
/// | Master record 3          |             |
/// +--------------------------+-------------+
/// +--------------------------+
/// | Other data...            |


///Represents a chunk inside a single file
/// +-------------------+
/// | ID                |
/// +-------------------+
/// | Length            |
/// +-------------------+
/// | Next              |
/// +----+----+----+----+
/// |    | Pay|load|    |
/// +----+----+----+----+
///
class FileChunk{
  int id;
  int offset;
  int length;
  FileChunk? prev,next;
  FileChunk(this.id, this.offset, this.length){

  }

  static const int headerSize = 4*3;
}

class FileChunkManager{

static const int signature = 0x1cecaffe;
static const int masterOffset = 4;
static const int masterRecordSize = 4*4;

  Map<int, FileChunk> _chunks = {};
  FileChunk? _masterChunk, _lastChunk;

  RandomAccessFile? _fHandle;
  FileMode _mode = FileMode.read;

  void Flush(){
    assert(IsWritable());
    _fHandle!.flushSync();
  }

  //Little endian
  int ReadNextInt(){
    var data = _fHandle!.readSync(4);
    return data[0]
         | data[1] << 8
         | data[2] << 16
         | data[3] << 24
         ;
  }

  int ReadNextByte(){
    var val = _fHandle!.readByteSync();
    if(val == -1){
      throw Exception("Unexpected file ending");
    }
    return val;
  }

  Uint8List ReadNext(int len){
    return _fHandle!.readSync(len);
  }

  void WriteNextInt(int val){
    _fHandle!.writeFromSync([
      val & 0xFF,
      (val>>8) & 0xFF,
      (val>>16) & 0xFF,
      (val>>24) & 0xFF,
    ]);
  }

  void WriteNextByte(int val){
    _fHandle!.writeByteSync(val);
  }

  
  void WriteNext(List<int> bytes){
    _fHandle!.writeFromSync(bytes);
  }

  Future<FileChunk?> _ScanNextChunk()async{
    //_fHandle!.setPositionSync(pos);
    var currPos = await _fHandle!.position();
    if(currPos == 0) return null;
    int id = ReadNextInt();
    int len = ReadNextInt();
    int next = ReadNextInt();
    await _fHandle!.setPosition(next);
    return FileChunk(id, currPos, len);
  }

  bool IsOpened(){return _fHandle != null;}
  bool IsWritable(){return IsOpened() && (_mode != FileMode.read);}

  Future<void> OpenFile(File f, [bool readOnly = false])async{
    try{
      _mode = readOnly?FileMode.read:FileMode.append;
      _fHandle = await f.open(mode: _mode);
      await _fHandle!.setPosition(0);
      //Verify signature
      var sig = ReadNextInt();
      if(sig != signature){
        throw Exception("File signature incorrect");
      }
      //Recover chunks
      _masterChunk = await _ScanNextChunk();
      if(_masterChunk == null){
        throw Exception("File master chunk is empty!");
      }
      var prevChunk = _masterChunk;
      while(prevChunk != null){
        var chunk = await _ScanNextChunk();
        if(chunk == null){ 
          //Found Last chunk
          _chunks[prevChunk.id] = prevChunk;
          _lastChunk = prevChunk;
          break; 
        }
        if(_chunks.containsKey(chunk.id)){
          throw Exception(
            "Cyclic chunk link detected at\n"
            "  pos : ${prevChunk.offset}\n"
            "  id  : ${prevChunk.id.toRadixString(16)}\n"
            "  link: ${prevChunk.offset} -> ${chunk.offset}\n"
          );
        }
        prevChunk.next = chunk;
        chunk.prev = prevChunk;
        _chunks[prevChunk.id] = prevChunk;
        prevChunk = chunk;
      }

    }catch(e){
      _masterChunk = null;
      _lastChunk = null;
      _chunks.clear();
      await _fHandle?.close();
      _fHandle = null;
      rethrow;
    }
  }

  Future<void> CreateFile(File f)async{
    try{
      _mode = FileMode.write;
      _fHandle = await f.open(mode:_mode);
      WriteNextInt(signature);
      WriteNextInt(4);            //Offset
      WriteNextInt(4);            //Length
      WriteNextInt(0);            //NextNode
      await _fHandle!.writeFrom(
        List<int>.filled(masterRecordSize, 0x1C)
      );
      _masterChunk = FileChunk(0, 4, masterRecordSize);
      _lastChunk = _masterChunk;
      _chunks[0] = _masterChunk!;
    }catch(e){
      _masterChunk = null;
      _lastChunk = null;
      _chunks.clear();
      await _fHandle?.close();
      _fHandle = null;
      rethrow;
    }
  }

  void _SaveChunkHeader(FileChunk ch){
    _fHandle!.setPositionSync(ch.offset);
    WriteNextInt(ch.id);
    WriteNextInt(ch.length);
    WriteNextInt(ch.next?.offset??0);
  }

  
  FileChunk _SeekAvailPos(int size){
    assert(size >= 0 && size <= 2 << 32);
    assert(_masterChunk != null);
    var curr = _masterChunk;
    
    int GetAvailPos(FileChunk from){
      var next = from.next;
      if(next == null) return 2<<32;
      return from.next!.offset - from.offset
        - FileChunk.headerSize - from.length;
    }

    while(curr!=null){
      if(GetAvailPos(curr!) >= size + FileChunk.headerSize) return curr;
      curr = curr!.next;
    }

    throw "???";
  }

  void _Resize(int id, int newSize){
    assert(id != 0, "Can't resize master chunk!");
    assert(newSize >= 0 && newSize <= 2 << 32);
    var chunk = _chunks[id];
    assert(chunk != null);
    int maxNotMove = chunk!.next == null? 
      2 << 32:
      chunk.next!.offset - chunk.offset - FileChunk.headerSize;
    if(newSize <= maxNotMove){
      chunk!.length = newSize;
      _SaveChunkHeader(chunk);
      return;
    }

    //Or we need to move
    var avail = _SeekAvailPos(newSize);
    //Remove from old position
    var oldPrev = chunk.prev;
    oldPrev!.next = chunk.next;
    chunk.next?.prev = oldPrev;

    //Add to new position
    chunk.next = avail.next;
    chunk.next?.prev = chunk;

    chunk.prev = avail;
    avail.next = chunk;

    chunk.offset = avail.offset + FileChunk.headerSize + avail.length;
    chunk.length = newSize;

    if(avail == _lastChunk){
      _lastChunk = chunk;
    }

    _SaveChunkHeader(chunk);
    _SaveChunkHeader(avail);
    _SaveChunkHeader(oldPrev);
  }

  bool ContainsChunkID(int id){
    return _chunks.containsKey(id);
  }

  int NewChunk(int size){
    assert(IsWritable());
    assert(size >= 0 && size <= 2 << 32);
    int id = _chunks.length;
    //Appends to last
    var pos = _lastChunk!.offset + _lastChunk!.length + FileChunk.headerSize;
    var chunk = FileChunk(id, pos, size);
    _lastChunk!.next = chunk;
    chunk.prev = _lastChunk;
    _chunks[id] = chunk;
    _SaveChunkHeader(_lastChunk!);
    _lastChunk = chunk;
    _SaveChunkHeader(_lastChunk!);
    return id;
  }

  bool RemoveChunk(int id){
    assert(id != 0, "Can't remove master chunk!");
    assert(IsWritable());
    var chunk = _chunks[id];
    if(chunk == null) return false;
    chunk.prev!.next = chunk.next;
    chunk.next?.prev = chunk.prev;
    if(chunk == _lastChunk){
      _lastChunk = chunk.prev;
    }
    _SaveChunkHeader(chunk.prev!);
    return true;
  }

  void WriteData(int id, List<int> u8Data){
    assert(IsWritable());
    var chunk = _chunks[id];
    assert(chunk!=null);
    if(u8Data.length != chunk!.length){
      _Resize(id, u8Data.length);
    }
    //Seek position
    _fHandle!.setPositionSync(chunk.offset + FileChunk.headerSize);
    _fHandle!.writeFromSync(u8Data);
  }

  int AddData(List<int> u8Data){
    var id = NewChunk(u8Data.length);
    WriteData(id, u8Data);
    return id;
  }

  
  Uint8List ReadData(int id){
    var chunk = SeekChunk(id);
    return _fHandle!.readSync(chunk.length);
  }

  FileChunk SeekChunk(int id){
    assert(IsOpened());
    var chunk = _chunks[id];
    assert(chunk!=null);
    _fHandle!.setPositionSync(chunk!.offset + FileChunk.headerSize);
    return chunk;
  }



  void Reset() async{
    _masterChunk = null;
    _lastChunk = null;
    _chunks.clear();
    await _fHandle?.flush();
    await _fHandle?.close();
    _fHandle = null;
    _mode = FileMode.read;
  }

  void Dispose(){

  }

}
