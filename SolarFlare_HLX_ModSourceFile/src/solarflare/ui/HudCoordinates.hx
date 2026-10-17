package solarflare.ui;

/** Pure projection: never writes the preferred anchor or configured dimensions. */
class HudCoordinates {
 /**
  * `overhang` is invisible chrome (resize footer, padding) allowed to hang past the far edge, so art placed flush
  * with the screen edge stays put when the window is locked.
  */
 public static function project(value:Float,reference:Float,extent:Float,size:Float,inset:Float,overhang:Float=0):Float {
  var scaled=value*(reference>0 ? extent/reference : 1);
  var lo=Math.max(0,inset);
  var hi=Math.max(lo,extent-Math.max(40,size-Math.max(0,overhang))+inset);
  return Math.max(lo,Math.min(hi,scaled));
 }
}
