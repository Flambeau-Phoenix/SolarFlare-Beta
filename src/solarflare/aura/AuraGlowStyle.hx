package solarflare.aura;

/** Configuration and maximum geometry shared by preview/live glow rendering. */
class AuraGlowStyle {
	/** Convert ImGui's ABGR packing to the Aura renderer's ARGB packing. */
	public static inline function fromImGuiColor(packed:Int):Int {
		return (packed & 0xFF00FF00) | ((packed & 255) << 16) | ((packed >>> 16) & 255);
	}
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
