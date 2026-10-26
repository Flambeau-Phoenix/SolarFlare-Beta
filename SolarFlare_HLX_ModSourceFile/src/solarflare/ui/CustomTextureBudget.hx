package solarflare.ui;

/** Conservative allocation admission, not measured VRAM. Never forget committed allocations:
 * the renderer has no per-texture release API. A rejected image cannot displace a live texture. */
class CustomTextureBudget {
 public static inline var LIMIT_BYTES:Int = 512 * 1024 * 1024;
 public static inline var MAX_ENTRIES:Int = 4096;
 static var committed:Map<String,Bool> = new Map();
 public static var usedBytes(default,null):Int = 0;
 public static var entries(default,null):Int = 0;
 public static var rejected(default,null):Int = 0;
 public static function allocationBytes(w:Int,h:Int):Int {
  RasterImagePolicy.dimensions(w,h);
  var raw=w*1.0*h*4;
  return Std.int(Math.ceil(raw/65536)*65536);
 }
 public static function check(key:String,w:Int,h:Int):Void {
  var bytes=allocationBytes(w,h);
  if(committed.exists(key)) return;
  if(entries>=MAX_ENTRIES || bytes>LIMIT_BYTES-usedBytes) {
   rejected++;
   throw "Custom image safety budget reached (512 MiB this session). Loaded images remain available; restart to release renderer textures.";
  }
 }
 /** Call only after a successful registration. Duplicate content does not consume allowance again. */
 public static function commit(key:String,w:Int,h:Int):Void {
  if(committed.exists(key)) return;
  check(key,w,h);
  committed.set(key,true);entries++;usedBytes+=allocationBytes(w,h);
 }
 public static function admitPng(bytes:haxe.io.Bytes):String {
  RasterImagePolicy.fileSize(bytes.length);
  if(bytes.length<33 || bytes.sub(0,8).toHex()!="89504e470d0a1a0a" || bytes.getString(12,4)!="IHDR") throw "Not a readable PNG header.";
  var w=big32(bytes,16),h=big32(bytes,20);
  RasterImagePolicy.dimensions(w,h);
  var key=haxe.crypto.Sha256.make(bytes).toHex();
  check(key,w,h);return key;
 }
 static inline function big32(b:haxe.io.Bytes,p:Int):Int return (b.get(p)<<24)|(b.get(p+1)<<16)|(b.get(p+2)<<8)|b.get(p+3);
}
