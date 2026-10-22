package solarflare.util;
import haxe.io.Bytes;

interface AppendStorage {
 public function size(path:String):Int;
 public function tail(path:String,offset:Int):Bytes;
 public function append(path:String,bytes:Bytes,offset:Int):Void;
}

class DiskAppendStorage implements AppendStorage {
 public function new() {}
 public function size(path:String):Int return sys.FileSystem.exists(path) ? sys.FileSystem.stat(path).size : 0;
 public function tail(path:String,offset:Int):Bytes {
  var n=size(path)-offset; if(n<0) throw "append target shrank";
  if(n==0) return Bytes.alloc(0);
  var input=sys.io.File.read(path,true);
  try { input.seek(offset,sys.io.FileSeek.SeekBegin); var bytes=input.read(n); input.close(); return bytes; }
  catch(e:Dynamic) { try input.close() catch(_:Dynamic) {} throw e; }
 }
 public function append(path:String,bytes:Bytes,offset:Int):Void {
  var out=sys.io.File.append(path,true);
  try { out.writeFullBytes(bytes,offset,bytes.length-offset); out.close(); }
  catch(e:Dynamic) { try out.close() catch(_:Dynamic) {} throw e; }
 }
}

/** A fixed file+offset+byte batch. A retry resumes only a byte-identical prefix. */
class AppendTransaction {
 public var path(default,null):String;
 public var bytes(default,null):Bytes;
 public var offset(default,null):Int=-1;
 public var error(default,null):String="";
 public var complete(default,null):Bool=false;
 public function new(path:String,bytes:Bytes) { this.path=path; this.bytes=bytes; }
 public function commit(storage:AppendStorage):Bool {
  if(complete) return true;
  try {
   if(offset<0) offset=storage.size(path);
   var suffix=storage.tail(path,offset);
   if(suffix.length>bytes.length) throw "append tail conflict";
   for(i in 0...suffix.length) if(suffix.get(i)!=bytes.get(i)) throw "append tail conflict";
   if(suffix.length<bytes.length) storage.append(path,bytes,suffix.length);
   var verified=storage.tail(path,offset);
   if(verified.length!=bytes.length) throw "append length mismatch";
   for(i in 0...bytes.length) if(verified.get(i)!=bytes.get(i)) throw "append verification mismatch";
   complete=true; error=""; return true;
  } catch(e:Dynamic) { error=Std.string(e); return false; }
 }
}
