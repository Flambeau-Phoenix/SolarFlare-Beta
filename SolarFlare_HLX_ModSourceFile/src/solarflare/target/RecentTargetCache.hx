package solarflare.target;

/**
 * Session ring of recently observed target unit kinds (observe authority).
 * Drawn by Aura Builder only via frozen ids/labels — no live unit walks.
 */
class RecentTargetCache {
	public static inline var CAP:Int = 15;

	static var kinds:Array<String> = [];
	static var names:Array<String> = [];
	static var seenAt:Array<Float> = [];

	public static function note(kind:String, name:String):Void {
		if (kind == null || kind.length == 0)
			return;
		var k = kind;
		var n = name != null ? name : "";
		var i = 0;
		while (i < kinds.length) {
			if (kinds[i] == k) {
				kinds.splice(i, 1);
				names.splice(i, 1);
				seenAt.splice(i, 1);
				break;
			}
			i++;
		}
		kinds.insert(0, k);
		names.insert(0, n);
		seenAt.insert(0, haxe.Timer.stamp());
		while (kinds.length > CAP) {
			kinds.pop();
			names.pop();
			seenAt.pop();
		}
	}

	/** Draw-safe copy of kind ids (most recent first). */
	public static function ids():Array<String> {
		return kinds.copy();
	}

	/** Display labels parallel to ids() — snap name or kind. */
	public static function labels():Array<String> {
		var out:Array<String> = [];
		var i = 0;
		while (i < kinds.length) {
			var lab = names[i];
			if (lab == null || lab.length == 0)
				lab = kinds[i];
			out.push(lab);
			i++;
		}
		return out;
	}

	public static function lookupName(kind:String):String {
		if (kind == null || kind.length == 0)
			return "";
		var i = 0;
		while (i < kinds.length) {
			if (kinds[i] == kind) {
				var n = names[i];
				return n != null ? n : "";
			}
			i++;
		}
		return "";
	}

	public static function count():Int {
		return kinds.length;
	}
}
