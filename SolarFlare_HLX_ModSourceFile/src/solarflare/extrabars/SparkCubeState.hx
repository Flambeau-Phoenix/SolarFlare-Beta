package solarflare.extrabars;

/** Local, observed combat metrics. No inferred storage cap or damage multiplier. */
class SparkCubeState {
 public static inline var DURATION:Float = 20;
 public var started:Float = -1;
 public var observedDamage:Float = 0;
 public var burstDamage:Float = 0;
 public var linked:Bool = false;
 public var partial:Bool = false;
 public var lastSequence:Float = 0;
 public var burstAt:Float = -1;
 public var stopped:Float = -1;
 public function new() {}
 public function reset():Void { started = -1; observedDamage = 0; burstDamage = 0; linked = false; partial = false; lastSequence = 0; burstAt = -1; stopped = -1; }
 public function stop(time:Float):Void { if(started>=0 && Math.isFinite(time) && time>=started && stopped<0) stopped=time; }
 public function accept(sequence:Float, kind:Int, skill:String, local:Bool, amount:Float, time:Float, minion:Bool = false):Void {
  if (sequence <= lastSequence) return;
  if (lastSequence > 0 && sequence > lastSequence + 1 && started >= 0) partial = true;
  lastSequence = sequence;
  if (!local || !Math.isFinite(time)) return;
  if (kind == 0 && skill == "SparkSurge_Status") {
   started = time; observedDamage = 0; burstDamage = 0; linked = false; partial = false; burstAt = -1; stopped = -1; return;
  }
  if (kind != 1 || started < 0 || !Math.isFinite(amount) || amount < 0 || time < started) return;
  if (skill == "SparkSurge_Mark") {
   // Multiple enemies can burst together; do not count these hits as stored-window damage.
   if (burstAt < 0 && time <= started + DURATION + 2) burstAt = time;
   if (burstAt >= 0 && time <= burstAt + 2) burstDamage += amount;
  } else if (time < started + DURATION && burstAt < 0 && (stopped<0 || time<stopped)) {
   observedDamage += amount; if (minion) linked = true;
  }
 }
 public function remaining(now:Float):Float return started < 0 || burstAt >= 0 || stopped >= 0 ? 0 : Math.max(0, Math.min(DURATION, started + DURATION - now));
}
