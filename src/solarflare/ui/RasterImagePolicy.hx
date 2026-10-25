package solarflare.ui;

/** Raster limits are independent of vector/SVG complexity limits and of game-owned atlases. */
class RasterImagePolicy {
 // Encoded source size is not texture memory. Large PNGs are normalized to 1024px before use/sharing.
 public static inline var MAX_FILE_BYTES:Int=16*1024*1024;
 public static inline var MAX_SOURCE_PIXELS:Int=4*1024*1024;
 public static inline var MAX_TEXTURE_BYTES:Int=64*1024*1024;
 public static inline var FILE_LIMIT:String="16 MiB (16,777,216 bytes)";
 public static function fileSize(bytes:Int):Void {
  if(bytes<=0 || bytes>MAX_FILE_BYTES) throw "Raster image must be no larger than "+FILE_LIMIT+". Resize or compress it first.";
 }
 public static function dimensions(w:Int,h:Int):Void {
  if(w<=0 || h<=0 || w>16384 || h>16384 || w*1.0*h>MAX_SOURCE_PIXELS)
   throw "Image dimensions exceed the decoded-memory limit (4 million pixels): "+w+"x"+h+". Resize it first.";
 }
 /** Native texture handles survive cache invalidation; account for distinct content for the session. */
 public var used(default,null):Int=0;
 var registered=new Map<String,Int>();
 public function new() {}
 /** Charge at least one 64 KiB allocation per image so tiny textures cannot bypass the shared budget. */
 static function textureBytes(w:Int,h:Int):Int return Std.int(Math.ceil(w*1.0*h*4/65536))*65536;
 public function checkTexture(content:String,w:Int,h:Int):Void {
  dimensions(w,h);
  if(!registered.exists(content) && used+textureBytes(w,h)>MAX_TEXTURE_BYTES)
   throw "Custom image memory limit reached (64 MB this session). Remove unused images and restart the game.";
 }
 public function registeredTexture(content:String,w:Int,h:Int):Void {
  checkTexture(content,w,h);
  if(!registered.exists(content)) { var bytes=textureBytes(w,h); registered.set(content,bytes); used+=bytes; }
 }
}
