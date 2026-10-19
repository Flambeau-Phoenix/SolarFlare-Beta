package solarflare.aura;

import solarflare.ui.CustomImageKey;

/** Finds and rewrites `custom:<stem>` references in a library. Same fields the share package visits. */
class AuraImageUsage {
	static inline function same(a:String, b:String):Bool return a != null && b != null && a.toLowerCase() == b.toLowerCase();

	/** Number of fields (aura icon, plate, canvas image layers) that use the given custom image stem. */
	public static function count(auras:Array<AuraDef>, stem:String):Int {
		var key = CustomImageKey.key(stem), n = 0;
		for (a in auras) {
			if (a == null) continue;
			if (same(a.iconId, key)) n++;
			if (same(a.plate, key)) n++;
			if (a.canvasElements != null) for (el in a.canvasElements) if (el != null && el.kind == AuraCanvasElement.KIND_ICON && same(el.content, key)) n++;
		}
		return n;
	}

	/** Point every reference at a new stem; returns how many fields changed. Callers snapshot/mark dirty. */
	public static function rewrite(auras:Array<AuraDef>, oldStem:String, newStem:String):Int {
		var from = CustomImageKey.key(oldStem), to = CustomImageKey.key(newStem), n = 0;
		for (a in auras) {
			if (a == null) continue;
			if (same(a.iconId, from)) { a.iconId = to; a.syncIconBuf(); n++; }
			if (same(a.plate, from)) { a.plate = to; n++; }
			if (a.canvasElements != null) for (el in a.canvasElements) if (el != null && el.kind == AuraCanvasElement.KIND_ICON && same(el.content, from)) { el.content = to; n++; }
		}
		return n;
	}
}
