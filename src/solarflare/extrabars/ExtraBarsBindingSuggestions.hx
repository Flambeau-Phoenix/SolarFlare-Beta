package solarflare.extrabars;

typedef ExtraBarsSuggestedChord = {var keyCode:Int; var modifiers:Int;}

/** Suggest only complete chords that pass the same read-only conflict validator. */
class ExtraBarsBindingSuggestions {
	public static function select(keys:Array<Int>, conflict:Int->Int->String, limit:Int = 3):Array<ExtraBarsSuggestedChord> {
		var out:Array<ExtraBarsSuggestedChord> = [];
		if (keys == null || conflict == null || limit <= 0) return out;
		limit = Std.int(Math.min(limit, 3));
		var seen = new Map<Int, Bool>();
		try {
			for (code in keys) {
				if (code <= 0 || seen.exists(code)) continue;
				seen.set(code, true);
				for (mods in [1, 2, 4]) {
					if (conflict(code, mods) != "") continue;
					out.push({keyCode:code, modifiers:mods});
					if (out.length >= limit) return out;
				}
			}
		} catch (_:Dynamic) {
			// An unavailable validator cannot leave a partially trusted suggestion list.
			out.resize(0);
		}
		return out;
	}
}
