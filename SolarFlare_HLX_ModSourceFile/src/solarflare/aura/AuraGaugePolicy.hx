package solarflare.aura;

/** Retained presentation state. Contains no game objects and is never serialized. */
class AuraGaugeState {
	public var fraction:Float = 0;
	public var total:Float = 0;
	public var active:Bool = false;
	public function new() {}
	public function reset():Void { fraction = total = 0; active = false; }
}

/** Pure cooldown presentation, shared by observation and simulated previews. */
class AuraGaugePolicy {
	public static inline var FOLLOW:String = "timer";
	public static inline var DRAIN:String = "remaining";
	public static inline var FILL:String = "elapsed";
	public static final MODES:Array<String> = [FOLLOW, DRAIN, FILL];
	public static final LABELS:Array<String> = ["Follow timer", "Drain during cooldown", "Fill during cooldown"];
	public static function normalize(value:Dynamic):String {
		return value == DRAIN ? DRAIN : value == FILL ? FILL : FOLLOW;
	}
	public static function fraction(mode:String, timerMode:Int, remaining:Float, source:Float):Float {
		if (mode == FOLLOW && timerMode == 0) return clamp(source);
		return mode == FILL || mode == FOLLOW && timerMode == 2 ? 1 - clamp(remaining) : clamp(remaining);
	}
	public static function observe(state:AuraGaugeState, mode:String, timerMode:Int, known:Bool, active:Bool,
			left:Float, total:Float, source:Float, fallback:Float = 0):Float {
		if (!known) return state.fraction;
		var remaining:Float = 0;
		if (active) {
			if (Math.isFinite(left) && left > 0) {
				var span = Math.isFinite(total) && total >= left ? total
					: state.active && state.total > 0 ? Math.max(state.total, left)
					: Math.isFinite(fallback) && fallback >= left ? fallback : left;
				state.total = span;
				remaining = left / span;
			} else if (Math.isFinite(source) && source > 0) remaining = source;
			else {
				if (!state.active) {
					state.active = true;
					state.fraction = fraction(mode, timerMode, 1, 1);
				}
				return state.fraction;
			}
		} else state.total = 0;
		state.active = active;
		state.fraction = fraction(mode, timerMode, remaining, source);
		return state.fraction;
	}
	static inline function clamp(v:Float):Float return !Math.isFinite(v) ? 0 : Math.max(0, Math.min(1, v));
}
