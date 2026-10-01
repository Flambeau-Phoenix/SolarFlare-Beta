package solarflare.aura;

/** Configuration and maximum geometry shared by preview/live glow rendering. */
class AuraGlowStyle {
	public static function normalize(style:String):String {
		return style == "soft" || style == "pulse" ? style : "proc";
	}
	public static function strength(value:Float):Float return Math.isFinite(value) ? Math.max(0, Math.min(2, value)) : 1;
	public static function spread(value:Float):Float return Math.isFinite(value) ? Math.max(0, Math.min(96, value)) : 12;
	public static function reach(style:String, outer:Float):Float {
		return normalize(style) == "proc" ? Math.max(14, spread(outer) + 2) : spread(outer) + 3;
	}
	public static function intensity(style:String, value:Float, time:Float):Float {
		return strength(value) * (normalize(style) == "pulse" ? 0.65 + 0.35 * Math.sin(time * 4) : 1);
	}
}
