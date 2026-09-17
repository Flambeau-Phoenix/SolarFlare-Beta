package solarflare.target;

/**
 * Session ring of recently observed target unit kinds (observe authority).
 * Drawn by Aura Builder only via frozen ids/labels — no live unit walks.
 */
class RecentTargetCache {
	public static inline var CAP:Int = 15;

	static var items:Array<RecentTargetItem> = [];
	static var idBuf:Array<String> = [];
	static var labelBuf:Array<String> = [];

	public static function note(kind:String, name:String):Void {
		if (kind == null || kind.length == 0)
			return;
		var k = kind;
		var n = name != null ? name : "";
		var now = haxe.Timer.stamp();
		var i = 0;
		var found = -1;
		while (i < items.length) {
			if (items[i].kind == k) {
				found = i;
				break;
			}
			i++;
		}
		if (found == 0) {
			items[0].name = n;
			items[0].seenAt = now;
			return;
		}
		if (found > 0) {
			var moved = items[found];
			while (found > 0) {
				items[found] = items[found - 1];
				found--;
			}
			items[0] = moved;
			moved.name = n;
			moved.seenAt = now;
			return;
		}
		var item:RecentTargetItem;
		if (items.length >= CAP) {
			item = items[items.length - 1];
			var j = items.length - 1;
			while (j > 0) {
				items[j] = items[j - 1];
				j--;
			}
			items[0] = item;
		} else {
			item = new RecentTargetItem();
			items.insert(0, item);
		}
		item.kind = k;
		item.name = n;
		item.seenAt = now;
	}

	/** Draw-safe copy of kind ids (most recent first). */
	public static function ids():Array<String> {
		while (idBuf.length > 0)
			idBuf.pop();
		var i = 0;
		while (i < items.length) {
			idBuf.push(items[i].kind);
			i++;
		}
		return idBuf;
	}

	/** Display labels parallel to ids() — snap name or kind. */
	public static function labels():Array<String> {
		while (labelBuf.length > 0)
			labelBuf.pop();
		var i = 0;
		while (i < items.length) {
			var lab = items[i].name;
			if (lab == null || lab.length == 0)
				lab = items[i].kind;
			labelBuf.push(lab);
			i++;
		}
		return labelBuf;
	}

	public static function lookupName(kind:String):String {
		if (kind == null || kind.length == 0)
			return "";
		var i = 0;
		while (i < items.length) {
			if (items[i].kind == kind) {
				var n = items[i].name;
				return n != null ? n : "";
			}
			i++;
		}
		return "";
	}

	public static function count():Int {
		return items.length;
	}
}

class RecentTargetItem {
	public var kind:String = "";
	public var name:String = "";
	public var seenAt:Float = 0;

	public function new() {}
}
