package solarflare.ui;

/** Raster validity checks only; user artwork has no configured size or session-memory cap. */
class RasterImagePolicy {
 public static function fileSize(bytes:Int):Void {
  if(bytes<=0) throw "Image file is empty.";
 }
 public static function dimensions(w:Int,h:Int):Void {
  if(w<=0 || h<=0) throw "Invalid image dimensions: "+w+"x"+h+".";
  // Haxe Bytes lengths are signed Ints. Reject arithmetic overflow, not artwork dimensions.
  if(w*1.0*h*8+h*7.0+1024>2147483647.0) throw "Image dimensions cannot be represented by the decoder: "+w+"x"+h+".";
 }
}
