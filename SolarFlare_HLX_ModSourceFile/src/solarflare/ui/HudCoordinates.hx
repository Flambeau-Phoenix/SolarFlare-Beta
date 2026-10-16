package solarflare.ui;

/** Pure projection: never writes the preferred anchor or configured dimensions. */
class HudCoordinates {
 public static function project(value:Float,reference:Float,extent:Float,size:Float,inset:Float):Float {
  var scaled=value*(reference>0 ? extent/reference : 1);
  var lo=Math.max(0,inset);
  var hi=Math.max(lo,extent-Math.max(40,size)+inset);
  return Math.max(lo,Math.min(hi,scaled));
 }
}
