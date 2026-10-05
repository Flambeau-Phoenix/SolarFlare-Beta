package solarflare.aura;

/** Pure compatibility and timer-text decisions shared by load and rendering. */
class AuraPresentationPolicy {
 public static function flag(saved:Dynamic,name:String,fallback:Bool):Bool {
  if (saved==null) return fallback;
  var value=Reflect.field(saved,name);
  return Std.isOfType(value,Bool) ? value : fallback;
 }
 public static function countdown(explicit:Bool,useGlobal:Bool,globalEnabled:Bool,left:Float,infinite:Bool,ceiling:Float):Bool {
  if (infinite) return explicit || (useGlobal && globalEnabled && ceiling<=0);
  if (!Math.isFinite(left) || left<0) return false;
  return explicit || (useGlobal && globalEnabled && (ceiling<=0 || left<=ceiling));
 }
}
