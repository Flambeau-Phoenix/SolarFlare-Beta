package solarflare;

/** Materialize engine identifiers without depending on investigation logging. */
class EngineText {
	public static function cleanId(raw:Dynamic):String {
		if (raw == null) return "";
		if (Std.isOfType(raw, String)) {
			var s:String = cast raw;
			if (s.length == 0) return "";
			var mat = "";
			try mat = solarflare.ui.ByteUtil.materialize(s) catch (_:Dynamic) mat = "";
			mat = StringTools.trim(mat);
			if (mat.length > 0 && !isDumpId(mat)) return mat;
		}
		var coerced = solarflare.geaux.GeauxCache.coerceSkillId(raw);
		coerced = StringTools.trim(coerced);
		return coerced.length > 0 && !isDumpId(coerced) ? coerced : "";
	}
	static function isDumpId(s:String):Bool {
		return s == null || s.length == 0 || s.indexOf("{") >= 0 || s.indexOf("}") >= 0
			|| s.toLowerCase().indexOf("bytes") >= 0;
	}
}
