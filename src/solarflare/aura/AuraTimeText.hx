package solarflare.aura;

/** Text for the `{time}` token. Native-free so the rounding rules are unit tested. */
class AuraTimeText {
	/** "inf" for endless timers, "" when there is no time, otherwise one decimal or whole seconds rounded up. */
	public static function token(left:Float, infinite:Bool, whole:Bool):String {
		if (infinite) return "inf";
		if (!Math.isFinite(left) || left < 0) return "";
		if (whole) return Std.string(Std.int(Math.ceil(left - 1e-9)));
		return Std.string(Math.max(0, Math.round(left * 10) / 10));
	}
}
