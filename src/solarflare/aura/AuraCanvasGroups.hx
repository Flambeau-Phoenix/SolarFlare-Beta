package solarflare.aura;

/**
 * Layer groups for the freeform canvas. A group is just a name shared by layers (`AuraCanvasElement.group`),
 * so old saves and share keys need no migration. These helpers keep a group's layers side by side in the
 * stacking order and are unit tested without the game.
 */
class AuraCanvasGroups {
	public static inline var MAX_NAME:Int = 32;

	/** Indices of every layer in the group, bottom to top. */
	public static function members(els:Array<AuraCanvasElement>, name:String):Array<Int> {
		var out:Array<Int> = [];
		if (name == null || name.length == 0) return out;
		for (i in 0...els.length) if (els[i] != null && els[i].group == name) out.push(i);
		return out;
	}

	public static function names(els:Array<AuraCanvasElement>):Array<String> {
		var out:Array<String> = [];
		for (el in els) if (el != null && el.group.length > 0 && out.indexOf(el.group) < 0) out.push(el.group);
		return out;
	}

	public static function clean(raw:String):String {
		var s = raw == null ? "" : StringTools.trim(raw);
		return s.length > MAX_NAME ? StringTools.trim(s.substr(0, MAX_NAME)) : s;
	}

	/** "Group 1", "Group 2"... whichever is free, or `base` with a number when it is taken. */
	public static function uniqueName(els:Array<AuraCanvasElement>, base:String = "Group"):String {
		var taken = names(els);
		var root = clean(base).length > 0 ? clean(base) : "Group";
		if (base == "Group") { var n = 1; while (taken.indexOf("Group " + n) >= 0) n++; return "Group " + n; }
		if (taken.indexOf(root) < 0) return root;
		var k = 2;
		while (taken.indexOf(clean(root + " " + k)) >= 0) k++;
		return clean(root + " " + k);
	}

	/**
	 * Puts the given layers in a new group and gathers them into one block, in their existing order, where the
	 * topmost of them was. Returns the block's indices, or an empty list when fewer than two layers are given.
	 */
	public static function group(els:Array<AuraCanvasElement>, indices:Array<Int>, name:String):Array<Int> {
		var picks = [for (i in indices) if (i >= 0 && i < els.length && els[i] != null) i];
		picks.sort(function(a, b) return a - b);
		var seen = new Map<Int, Bool>();
		picks = [for (i in picks) if (!seen.exists(i)) { seen.set(i, true); i; }];
		if (picks.length < 2) return [];
		var block = [for (i in picks) els[i]];
		var top = picks[picks.length - 1];
		var at = top - (picks.length - 1);
		var j = picks.length - 1;
		while (j >= 0) { els.splice(picks[j], 1); j--; }
		for (k in 0...block.length) { block[k].group = clean(name); els.insert(at + k, block[k]); }
		return [for (k in 0...block.length) at + k];
	}

	/** Dissolves every group touched by the given layers. Returns how many layers were released. */
	public static function ungroup(els:Array<AuraCanvasElement>, indices:Array<Int>):Int {
		var touched = new Map<String, Bool>();
		for (i in indices) if (i >= 0 && i < els.length && els[i] != null && els[i].group.length > 0) touched.set(els[i].group, true);
		var released = 0;
		for (el in els) if (el != null && touched.exists(el.group)) { el.group = ""; released++; }
		return released;
	}

	public static function rename(els:Array<AuraCanvasElement>, from:String, to:String):Bool {
		var target = clean(to);
		if (target.length == 0 || target == from || names(els).indexOf(target) >= 0) return false;
		for (el in els) if (el != null && el.group == from) el.group = target;
		return true;
	}

	/**
	 * After layers from `firstCopy` onward were duplicated or pasted, give each copied group a fresh name
	 * ("Name 2") when the original is still present, so copies never silently merge with their source.
	 */
	public static function separateCopies(els:Array<AuraCanvasElement>, firstCopy:Int):Void {
		separate(els, [for (i in firstCopy...els.length) i]);
	}

	/** Same as separateCopies, for copies that sit next to their originals rather than at the end. */
	public static function separate(els:Array<AuraCanvasElement>, copyIdx:Array<Int>):Void {
		var isCopy = new Map<Int, Bool>();
		for (i in copyIdx) isCopy.set(i, true);
		var renamed = new Map<String, String>();
		for (i in copyIdx) {
			var el = i >= 0 && i < els.length ? els[i] : null;
			if (el == null || el.group.length == 0) continue;
			var existsBefore = false;
			for (k in 0...els.length) if (!isCopy.exists(k) && els[k] != null && els[k].group == el.group) { existsBefore = true; break; }
			if (!existsBefore) continue;
			if (!renamed.exists(el.group)) {
				var k = 2, candidate = clean(el.group + " " + k);
				while (names(els).indexOf(candidate) >= 0) { k++; candidate = clean(el.group + " " + k); }
				renamed.set(el.group, candidate);
			}
			el.group = renamed.get(el.group);
		}
	}

	/** Scales position, size, text and outline of the layers about the centre of their combined box (Default look values). */
	public static function scale(els:Array<AuraCanvasElement>, indices:Array<Int>, factor:Float, boxW:Float, boxH:Float):Void {
		if (!Math.isFinite(factor) || factor <= 0.01) return;
		var picks = [for (i in indices) if (i >= 0 && i < els.length && els[i] != null && !els[i].locked) i];
		if (picks.length == 0) return;
		var minX = 1e30, minY = 1e30, maxX = -1e30, maxY = -1e30;
		for (i in picks) {
			var el = els[i], w = el.w > 1 ? el.w : (el.kind == AuraCanvasElement.KIND_TEXT ? 0 : boxW), h = el.h > 1 ? el.h : (el.kind == AuraCanvasElement.KIND_TEXT ? 0 : boxH);
			minX = Math.min(minX, el.x); minY = Math.min(minY, el.y); maxX = Math.max(maxX, el.x + w); maxY = Math.max(maxY, el.y + h);
		}
		var cx = (minX + maxX) * 0.5, cy = (minY + maxY) * 0.5;
		for (i in picks) {
			var el = els[i];
			el.x = Math.round(cx + (el.x - cx) * factor); el.y = Math.round(cy + (el.y - cy) * factor);
			if (el.w > 1) el.w = Math.max(2, Math.round(el.w * factor));
			if (el.h > 1) el.h = Math.max(2, Math.round(el.h * factor));
			if (el.kind == AuraCanvasElement.KIND_TEXT) el.fontSize = Math.max(6, Math.min(120, Math.round(el.fontSize * factor)));
			if (el.stroke > 0) el.stroke = Math.max(1, Math.min(16, Math.round(el.stroke * factor)));
		}
	}
}
