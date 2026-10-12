package solarflare.aimcast;

/**
 * The engine's own ground-aim arithmetic (`client.UnitController.startTargetMode`, per-frame aim job), kept as pure
 * primitives so it is testable without the engine. Source: lowered body of the aim job, constants named in
 * `Const.Controls.Skill_PointTarget_*`.
 *
 *   a    = PI/2 - (PitchMin + |cameraPitch|) ^ PitchPow
 *   t    = clamp01((a - Pitch.min) / (Pitch.max - Pitch.min))
 *   dist = max(0.01, t * aimStep.range)
 *   x,y  = heroPosition + dist * (cos(cameraYaw), sin(cameraYaw))
 */
class AimCastMath {
	public static inline var MIN_DIST:Float = 0.01;

	public static function distance(pitch:Float, range:Float, pitchMin:Float, pitchPow:Float, lo:Float, hi:Float):Float {
		var a = Math.PI / 2 - Math.pow(pitchMin + Math.abs(pitch), pitchPow);
		var span = hi - lo;
		var t = span == 0 ? 0 : (a - lo) / span;
		if (!(t >= 0)) t = 0; // NaN or negative
		if (t > 1) t = 1;
		var d = t * range;
		return d < MIN_DIST ? MIN_DIST : d;
	}

	public static inline function x(heroX:Float, dist:Float, yaw:Float):Float return heroX + dist * Math.cos(yaw);
	public static inline function y(heroY:Float, dist:Float, yaw:Float):Float return heroY + dist * Math.sin(yaw);

	/** All inputs must be finite; a malformed engine value must never produce a cast. */
	public static function finite(values:Array<Float>):Bool {
		for (v in values) if (!Math.isFinite(v)) return false;
		return true;
	}
}
