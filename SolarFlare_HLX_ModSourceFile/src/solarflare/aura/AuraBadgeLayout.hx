package solarflare.aura;

import solarflare.ui.HUDVisualBounds;

/** Measured plate artwork; coordinates include padding and the 1px text shadow. */
class AuraBadgeSlot {
	public var enabled:Bool = false;
	public var place:Int = 0;
	public var text:String = "";
	public var fontSize:Float = 11;
	public var x:Float = 0;
	public var y:Float = 0;
	public var w:Float = 0;
	public var h:Float = 0;
	public function new() {}
}

/** Pure lane allocation shared by HUD bounds and rendering. Order: Timer, Stacks, Counter. */
class AuraBadgeLayout {
	public static inline var GAP:Float = 4;
	public static inline var PAD_X:Float = 4;
	public static inline var PAD_Y:Float = 2;
	public var slots(default, null):Array<AuraBadgeSlot>;
	public function new() {
		slots = [new AuraBadgeSlot(), new AuraBadgeSlot(), new AuraBadgeSlot()];
	}
	public function set(index:Int, enabled:Bool, place:Int, text:String, fontSize:Float, textW:Float, textH:Float):Void {
		var s = slots[index];
		s.enabled = enabled;
		s.place = place == 1 || place == 2 ? place : 0;
		s.text = text;
		s.fontSize = fontSize;
		s.w = Math.max(0, textW) + PAD_X * 2;
		s.h = Math.max(0, textH) + PAD_Y * 2;
	}
	public function resolve(x:Float, y:Float, w:Float, h:Float):Void {
		var centerH:Float = 0;
		for (s in slots) if (s.enabled && s.place == 0) centerH += s.h + GAP;
		if (centerH > 0) centerH -= GAP;
		var centerY = y + (h - centerH) * 0.5;
		// Small faces can have a central lane taller than the face. Outer lanes still clear it.
		var above = Math.min(y, centerY - GAP);
		var below = Math.max(y + h, centerY + centerH + GAP);
		if (centerH == 0) { above = y; below = y + h; }
		for (s in slots) {
			if (!s.enabled) continue;
			s.x = x + (w - s.w) * 0.5;
			s.y = switch (s.place) {
				case 1: above -= s.h; var at = above; above -= GAP; at;
				case 2: var at = below; below += s.h + GAP; at;
				default: var at = centerY; centerY += s.h + GAP; at;
			};
		}
	}
	public function includeBounds(out:HUDVisualBounds):Void {
		for (s in slots) if (s.enabled) out.include(s.x, s.y, s.w, s.h);
	}
}
