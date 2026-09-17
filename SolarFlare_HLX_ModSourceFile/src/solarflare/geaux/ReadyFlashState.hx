package solarflare.geaux;

/** Pure cooldown edge state, using haxe.Timer.stamp seconds throughout. */
class ReadyFlashState {
	public static inline var DURATION:Float = 15;
	public var armed(default, null):Bool = false;
	public var until(default, null):Float = 0;
	public function new() {}
	public function observe(valid:Bool, cooling:Bool, now:Float):Float {
		if (!valid) { armed = false; until = 0; }
		else if (cooling) { armed = true; until = 0; }
		else if (armed) { armed = false; until = now + DURATION; }
		return until;
	}
	public static function opacity(until:Float, now:Float):Float {
		var u = Math.max(0, Math.min(1, (until - now) / DURATION));
		return u * u * (3 - 2 * u);
	}
}
