package solarflare.aura;

/** Persistence migration and token semantics, independent of native UI/runtime. */
class AuraBadgePolicy {
	public static function legacy(d:Dynamic):Bool {
		return !Reflect.hasField(d, "counterPlace") && !Reflect.hasField(d, "counterScale");
	}
	public static function place(raw:Dynamic, fallback:Int):Int {
		return raw == 0 ? 0 : raw == 1 ? 1 : raw == 2 ? 2 : fallback;
	}
	public static function scale(raw:Dynamic, fallback:Float = 1):Float {
		if (!Std.isOfType(raw, Int) && !Std.isOfType(raw, Float)) return fallback;
		var n:Float = raw;
		return Math.isFinite(n) ? Math.max(0.5, Math.min(3, n)) : fallback;
	}
	public static function stackPlace(d:Dynamic):Int return place(d.stackPlace, legacy(d) ? 2 : 1);
	public static function counterPlace(d:Dynamic):Int return place(d.counterPlace, legacy(d) ? stackPlace(d) : 2);
	public static function counterScale(d:Dynamic):Float return scale(d.counterScale, legacy(d) ? scale(d.stackScale) : 1);
	public static function migrateContent(d:Dynamic, kind:String, content:String):String {
		return legacy(d) && d.isCounter == true && d.stackCounter != true && kind == "text"
			? content.split("{stacks}").join("{counter}") : content;
	}
	public static function countTokens(content:String, stacks:Int, counter:Int):String {
		return content.split("{stacks}").join(Std.string(stacks)).split("{counter}").join(Std.string(counter));
	}
}
