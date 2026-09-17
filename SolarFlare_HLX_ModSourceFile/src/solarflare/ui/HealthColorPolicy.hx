package solarflare.ui;

/** Packed ImGui ABGR colors. Unknown telemetry never implies a dead entity. */
class HealthColorPolicy {
	public static inline var GREEN:Int = 0xFF71CC2E;
	public static inline var GRAY:Int = 0xFF555555;
	public static function resolve(dead:Bool, tapped:Bool, intentional:Null<Int> = null, configuredGreen:Null<Int> = null):Int {
		if (dead || tapped) return GRAY;
		if (intentional != null) return intentional;
		return configuredGreen != null ? configuredGreen : GREEN;
	}
	public static function source(dead:Bool, tapped:Bool, intentional:Bool, configured:Bool = false):String {
		return dead ? "confirmed dead" : tapped ? "confirmed tapped" : intentional ? "intentional tint" : configured ? "configured green" : "fallback green";
	}
}
