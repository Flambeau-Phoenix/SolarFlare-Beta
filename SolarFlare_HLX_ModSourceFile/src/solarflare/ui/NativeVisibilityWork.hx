package solarflare.ui;

/** Primitive timings only; safe to inspect from the performance panel. */
class NativeVisibilityWork {
 public static var lastMs:Float=0;
 public static var maxMs:Float=0;
 public static var scans:Int=0;
 public static var nodes:Int=0;
 public static var lateMs:Float=0;
 public static var lateMaxMs:Float=0;
 public static function observe(ms:Float,count:Int):Void {
  lastMs=ms; if(ms>maxMs) maxMs=ms;
  if(count>0) { scans++; nodes=count; }
 }
 public static function late(ms:Float):Void { lateMs=ms; if(ms>lateMaxMs) lateMaxMs=ms; }
 public static function reset():Void { lastMs=maxMs=lateMs=lateMaxMs=0; scans=nodes=0; }
}
