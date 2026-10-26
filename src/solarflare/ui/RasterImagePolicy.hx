package solarflare.ui;

/** Generous safety ceilings; originals are never resized or overwritten. */
class RasterImagePolicy {
 public static inline var MAX_FILE_BYTES:Int = 64 * 1024 * 1024;
 public static inline var MAX_PIXELS:Int = 16 * 1024 * 1024;
 public static inline var MAX_SIDE:Int = 16384;
 public static function fileSize(bytes:Int):Void {
  if(bytes<=0) throw "Image file is empty.";
  if(bytes>MAX_FILE_BYTES) throw "Image exceeds the 64 MiB source-file safety limit.";
 }
 public static function dimensions(w:Int,h:Int):Void {
  if(w<=0 || h<=0) throw "Invalid image dimensions: "+w+"x"+h+".";
  if(w>MAX_SIDE || h>MAX_SIDE || w*1.0*h>MAX_PIXELS)
   throw "Image exceeds the safety limit: 16 million pixels and 16384 pixels per side.";
 }
}
