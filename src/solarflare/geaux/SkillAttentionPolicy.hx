package solarflare.geaux;

/** Shared presentation rules; all inputs are frozen primitive telemetry. */
class SkillAttentionPolicy {
 public static inline var NONE:Int=0;
 public static inline var PULSE:Int=1;
 public static inline var BRIGHT:Int=2;
 public static inline var AURA:Int=3;
 public static inline var CD_NONE:Int=0;
 public static inline var CD_DIM:Int=1;
 public static inline var CD_OUTLINE:Int=2;
 public static inline function hasCharges(max:Int,count:Int):Bool return max>0 && count>0;
 public static inline function cooling(present:Bool,ready:Bool,ammo:Bool,left:Float,remaining:Float):Bool
  return present && (left>0.05 || remaining>0.02 || (!ready && !ammo));
 public static inline function lit(present:Bool,ready:Bool,ammo:Bool,affordable:Bool,dimNoResource:Bool=true):Bool
  return present && (ready || ammo) && (affordable || !dimNoResource);
 public static inline function nearReady(present:Bool,cooling:Bool,ammo:Bool,left:Float):Bool
  return present && cooling && !ammo && left<=1.2 && left>0.05;
 public static function readyAlpha(present:Bool,lit:Bool,affordable:Bool,until:Float,now:Float):Float
  return present && lit && affordable ? ReadyFlashState.opacity(until,now) : 0;
 public static function procPhase(start:Float,now:Float):Float return Math.max(0,now-start)%2.6;
}
