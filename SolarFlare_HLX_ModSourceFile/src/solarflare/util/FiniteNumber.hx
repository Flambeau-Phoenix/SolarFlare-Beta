package solarflare.util;

/** Numeric JSON/config boundary, including boxed HashLink Single values. Never coerces text or booleans. */
class FiniteNumber {
 public static function isFinite(value:Dynamic):Bool {
  #if hl
  if(value==null) return false;
  switch(hl.Type.getDynamic(value).kind) {
   case HUI8, HUI16, HI32, HF32, HF64:
   default: return false;
  }
  #else
  if(!Std.isOfType(value,Float) && !Std.isOfType(value,Int)) return false;
  #end
  var number:Float=value;
  return Math.isFinite(number);
 }
}
