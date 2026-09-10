package solarflare.ui;

import solarflare.HealthCache;
import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Structs.ImVec2;
import imgui.Structs.ImVec4;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;

/**
 * F6 → Vitals. Hide toggles, chrome, size, HP/Rage/Mana visual styles.
 * Styles: classic/segmented bars · Crescent · Thesd · Vertical · Half dome · Ring · pip shapes.
 */
class VitalsConfig {
	public static inline var HP_MIN_W:Single = 80;
	public static inline var HP_MAX_W:Single = 1200;
	public static inline var HP_MIN_H:Single = 80;
	public static inline var HP_MAX_H:Single = 720;

	public static inline var STYLE_BAR:Int = 0;
	public static inline var STYLE_CRESCENT:Int = 1;
	public static inline var STYLE_HALF_DOME:Int = 2;
	public static inline var STYLE_VERTICAL:Int = 3;
	public static inline var STYLE_RING:Int = 4;
	public static inline var STYLE_DIAMOND:Int = 5;
	public static inline var STYLE_CIRCLE:Int = 6;
	public static inline var STYLE_HEX:Int = 7;
	public static inline var STYLE_RING_PIPS:Int = 8;
	/** Inward vertical arcs (Thesd / ElvUI-style parentheses around the hero). */
	public static inline var STYLE_THESD:Int = 9;
	public static inline var STYLE_BAR_2X50:Int = 10;
	public static inline var STYLE_BAR_2X10:Int = 11;

	public static inline var LAYOUT_STACKED:Int = 0;
	public static inline var LAYOUT_COLUMNS:Int = 1;

	public var open = new BoolRef(false);
	public var hpHidden = new BoolRef(false);
	public var rageHidden = new BoolRef(false);
	public var manaHidden = new BoolRef(false);
	public var prayersHidden = new BoolRef(false);
	public var hpWidth = new FloatRef(320);
	public var hpHeight = new FloatRef(120);
	public var hpSizeDirty = true;
	public var rageWidth = new FloatRef(220);
	public var rageHeight = new FloatRef(44);
	public var rageSizeDirty = true;
	public var manaWidth = new FloatRef(220);
	public var manaHeight = new FloatRef(44);
	public var manaSizeDirty = true;
	public var prayersWidth = new FloatRef(180);
	public var prayersHeight = new FloatRef(56);
	public var prayersSizeDirty = true;
	public var hpStyle = new IntRef(STYLE_BAR);
	public var rageStyle = new IntRef(STYLE_BAR);
	public var manaStyle = new IntRef(STYLE_BAR);
	public var hpVertical = new BoolRef(false);
	public var rageVertical = new BoolRef(false);
	public var manaVertical = new BoolRef(false);
	public var layout = new IntRef(LAYOUT_STACKED);
	public var chrome:HudChrome;
	public var rageChrome:HudChrome;
	public var manaChrome:HudChrome;
	public var prayersChrome:HudChrome;

	public function new() {
		chrome = new HudChrome(40, 80);
		rageChrome = new HudChrome(40, 210);
		manaChrome = new HudChrome(40, 270);
		prayersChrome = new HudChrome(40, 330);
	}

	public function anyBarVisible():Bool {
		return !hpHidden.get()
			|| !rageHidden.get()
			|| (!manaHidden.get() && HealthCache.resourceValid())
			|| (!prayersHidden.get() && PrayerCache.active);
	}

	public function draw():Void {
		if (!open.get())
			return;
		ImGui.setNextWindowSize(ImGui.vec2(380, 0), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel("Vitals", open, "Vitals")) {
			ImGui.text("HP / Rage / Spark·Mana / Prayers overlay.");
			ImGui.text("Thesd: inward arcs. HP left + Rage/Spark Thesd to flank the hero.");
			ImGui.separatorText("Arrangement");
			drawLayoutCombo();
			ImGui.separatorText("Health");
			if (ImGui.checkbox("Hide##hp", hpHidden))
				SettingsStore.markDirty();
			if (ImGui.checkbox("Vertical stack##hp_vert", hpVertical))
				SettingsStore.markDirty();
			drawStyleCombo("HP style##vitals", hpStyle, true, true);
			ImGui.separatorText("Rage");
			if (ImGui.checkbox("Hide##rage", rageHidden))
				SettingsStore.markDirty();
			if (ImGui.checkbox("Vertical stack##rage_vert", rageVertical))
				SettingsStore.markDirty();
			drawStyleCombo("Rage style##vitals", rageStyle, true, false);
			ImGui.separatorText(HealthCache.sparkValid ? "Spark" : "Mana");
			if (ImGui.checkbox("Hide##mana", manaHidden))
				SettingsStore.markDirty();
			if (ImGui.checkbox("Vertical stack##mana_vert", manaVertical))
				SettingsStore.markDirty();
			drawStyleCombo((HealthCache.sparkValid ? "Spark" : "Mana") + " style##vitals", manaStyle, true,
				!HealthCache.sparkValid);
			ImGui.separatorText("Prayers");
			if (ImGui.checkbox("Hide##prayers", prayersHidden))
				SettingsStore.markDirty();
			chrome.drawToggles("vitals");
			ImGui.separatorText("Window size");
			if (ImGui.sliderFloat("Width##vitals", hpWidth, HP_MIN_W, HP_MAX_W, "%.0f px")) {
				hpSizeDirty = true;
				SettingsStore.markDirty();
			}
			if (ImGui.sliderFloat("Height##vitals", hpHeight, HP_MIN_H, HP_MAX_H, "%.0f px")) {
				hpSizeDirty = true;
				SettingsStore.markDirty();
			}
		}
		HudChrome.endPanel();
	}

	/** Clamp unknown styles to Bar. Pip shapes are Combo-only unless allowPips. */
	public static function normalizeStyle(style:Int, allowVertical:Bool, allowPips:Bool = true):Int {
		if (!allowPips && isPipStyle(style))
			return STYLE_BAR;
		if (style == STYLE_HALF_DOME || style == STYLE_CRESCENT || style == STYLE_BAR || style == STYLE_RING
			|| style == STYLE_THESD || style == STYLE_BAR_2X50 || style == STYLE_BAR_2X10)
			return style;
		if (allowPips && (style == STYLE_DIAMOND || style == STYLE_CIRCLE || style == STYLE_HEX
			|| style == STYLE_RING_PIPS))
			return style;
		if (style == STYLE_VERTICAL)
			return allowVertical ? STYLE_VERTICAL : STYLE_BAR;
		return STYLE_BAR;
	}

	public static function isPipStyle(style:Int):Bool {
		return style == STYLE_DIAMOND || style == STYLE_CIRCLE || style == STYLE_HEX || style == STYLE_RING_PIPS;
	}

	public static function pipShapeOf(style:Int):Int {
		return switch (style) {
			case STYLE_CIRCLE: PipShapes.CIRCLE;
			case STYLE_HEX: PipShapes.HEX;
			case STYLE_RING_PIPS: PipShapes.RING;
			default: PipShapes.DIAMOND;
		};
	}

	static function styleName(style:Int):String {
		return switch (style) {
			case STYLE_CRESCENT: "Crescent";
			case STYLE_THESD: "Thesd";
			case STYLE_VERTICAL: "Vertical";
			case STYLE_HALF_DOME: "Half dome";
			case STYLE_RING: "Ring";
			case STYLE_DIAMOND: "Diamond";
			case STYLE_CIRCLE: "Circle";
			case STYLE_HEX: "Hexagon";
			case STYLE_RING_PIPS: "Ring pips";
			case STYLE_BAR_2X50: "Bar (2 × 50)";
			case STYLE_BAR_2X10: "Bar (2 × 10)";
			default: "Bar (classic)";
		};
	}

	static function pickStyle(label:String, style:IntRef, id:Int):Void {
		if (ImGui.selectable(label + "##vit_style_" + Std.string(id), style.get() == id)) {
			style.set(id);
			SettingsStore.markDirty();
		}
	}

	public function drawLayoutCombo():Void {
		var cur = layout.get();
		if (cur != LAYOUT_STACKED && cur != LAYOUT_COLUMNS) {
			layout.set(LAYOUT_STACKED);
			cur = LAYOUT_STACKED;
		}
		var preview = cur == LAYOUT_COLUMNS ? "Side by side" : "Stacked";
		if (ImGui.beginCombo("Arrangement##vitals", preview)) {
			if (ImGui.selectable("Stacked", cur == LAYOUT_STACKED)) {
				layout.set(LAYOUT_STACKED);
				SettingsStore.markDirty();
			}
			if (ImGui.selectable("Side by side", cur == LAYOUT_COLUMNS)) {
				layout.set(LAYOUT_COLUMNS);
				SettingsStore.markDirty();
			}
			ImGui.endCombo();
		}
	}

	public static function drawStyleCombo(label:String, style:IntRef, allowVertical:Bool, allowPips:Bool = true):Void {
		var cur = normalizeStyle(style.get(), allowVertical, allowPips);
		if (cur != style.get())
			style.set(cur);
		if (ImGui.beginCombo(label, styleName(cur))) {
			pickStyle("Bar (classic)", style, STYLE_BAR);
			pickStyle("Bar (2 × 50)", style, STYLE_BAR_2X50);
			pickStyle("Bar (2 × 10)", style, STYLE_BAR_2X10);
			if (allowVertical)
				pickStyle("Vertical", style, STYLE_VERTICAL);
			pickStyle("Crescent", style, STYLE_CRESCENT);
			pickStyle("Thesd", style, STYLE_THESD);
			pickStyle("Half dome", style, STYLE_HALF_DOME);
			pickStyle("Ring", style, STYLE_RING);
			if (allowPips) {
				pickStyle("Diamond", style, STYLE_DIAMOND);
				pickStyle("Circle", style, STYLE_CIRCLE);
				pickStyle("Hexagon", style, STYLE_HEX);
				pickStyle("Ring pips", style, STYLE_RING_PIPS);
			}
			ImGui.endCombo();
		}
	}
}

/**
 * Thick vertical inward arc (Thesd): left bars bulge left, right bars bulge right.
 * Fill runs bottom → top along the arc. Optional inner ribbon (shield / nested resource).
 */
class ThesdGauge {
	static inline var SWEEP:Single = 2.18;
	static inline var SEGS:Int = 36;

	public static function draw(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, ratio:Single, color:ImVec4,
			label:String = "", flip:Bool = false, innerRatio:Single = -1, ?innerColor:ImVec4):Void {
		if (ratio < 0)
			ratio = 0;
		if (ratio > 1)
			ratio = 1;
		var pad:Single = 4;
		var innerGap:Single = 5;
		var thick:Single = Math.min(w * 0.38, h * 0.14);
		if (thick < 10)
			thick = 10;
		if (thick > 28)
			thick = 28;
		var halfSweep:Single = SWEEP * 0.5;
		var sinHalf:Single = Math.sin(halfSweep);
		if (sinHalf < 0.2)
			sinHalf = 0.2;
		var rVert:Single = ((h - pad * 2) * 0.5) / sinHalf;
		var rHorz:Single = w - pad - thick * 0.55;
		var r:Single = rVert < rHorz ? rVert : rHorz;
		if (r < 28)
			r = 28;
		var cx:Single = flip ? (x + pad + thick * 0.55) : (x + w - pad - thick * 0.55);
		var cy:Single = y + h * 0.48;
		var mid:Single = flip ? 0 : Math.PI;
		var a0:Single = mid - halfSweep;
		var a1:Single = mid + halfSweep;

		strokeArc(dl, cx, cy, r, a0, a1, thick + 3.5, ImGui.vec4(0, 0, 0, 0.72));
		strokeArc(dl, cx, cy, r, a0, a1, thick, ImGui.vec4(0.08, 0.09, 0.10, 0.92));

		if (ratio > 0.001) {
			var fillA0:Single;
			var fillA1:Single;
			if (flip) {
				fillA0 = a1 - SWEEP * ratio;
				fillA1 = a1;
			} else {
				fillA0 = a0;
				fillA1 = a0 + SWEEP * ratio;
			}
			strokeArc(dl, cx, cy, r, fillA0, fillA1, thick, color);
			cap(dl, cx, cy, r, fillA0, thick * 0.5, color);
			cap(dl, cx, cy, r, fillA1, thick * 0.5, color);
		}
		cap(dl, cx, cy, r, a0, thick * 0.42, ImGui.vec4(0.05, 0.05, 0.06, 0.9));
		cap(dl, cx, cy, r, a1, thick * 0.42, ImGui.vec4(0.05, 0.05, 0.06, 0.9));

		if (innerRatio >= 0 && innerColor != null && r > thick + innerGap + 12) {
			var ir:Single = r - thick * 0.5 - innerGap - thick * 0.38;
			var ithick:Single = thick * 0.72;
			if (ithick < 7)
				ithick = 7;
			strokeArc(dl, cx, cy, ir, a0, a1, ithick + 2.5, ImGui.vec4(0, 0, 0, 0.65));
			strokeArc(dl, cx, cy, ir, a0, a1, ithick, ImGui.vec4(0.08, 0.09, 0.10, 0.9));
			if (innerRatio > 0.001) {
				if (innerRatio > 1)
					innerRatio = 1;
				var ia0:Single;
				var ia1:Single;
				if (flip) {
					ia0 = a1 - SWEEP * innerRatio;
					ia1 = a1;
				} else {
					ia0 = a0;
					ia1 = a0 + SWEEP * innerRatio;
				}
				strokeArc(dl, cx, cy, ir, ia0, ia1, ithick, innerColor);
				cap(dl, cx, cy, ir, ia0, ithick * 0.5, innerColor);
				cap(dl, cx, cy, ir, ia1, ithick * 0.5, innerColor);
			}
		}

		if (label != null && label.length > 0) {
			var ts = ImGui.calcTextSize(label);
			var tx:Single = x + (w - ts.x) * 0.5;
			var ty:Single = y + h - ts.y - 2;
			if (ty < y + h * 0.72)
				ty = y + h * 0.72;
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0.92)), label);
		}
	}

	static function strokeArc(dl:Dynamic, cx:Single, cy:Single, r:Single, a0:Single, a1:Single, thickness:Single,
			color:ImVec4):Void {
		if (a1 <= a0 + 0.01)
			return;
		ImGui.ImDrawList_PathClear(dl);
		ImGui.ImDrawList_PathArcTo(dl, ImGui.vec2(cx, cy), r, a0, a1, SEGS);
		ImGui.ImDrawList_PathStroke(dl, ImGui.colorConvertFloat4ToU32(color), thickness, 0);
	}

	static function cap(dl:Dynamic, cx:Single, cy:Single, r:Single, a:Single, cr:Single, color:ImVec4):Void {
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx + Math.cos(a) * r, cy + Math.sin(a) * r), cr,
			ImGui.colorConvertFloat4ToU32(color), 14);
	}
}

/**
 * Transparent arc-style ("crescent") radial gauge via ImDrawList path primitives.
 */
class CrescentGauge {
	static inline var GAP:Single = 0.6;

	static function startAngle():Single {
		return -Math.PI / 2 - (Math.PI - GAP / 2);
	}

	public static function draw(dl:Dynamic, center:ImVec2, radius:Single, ratio:Single, color:ImVec4, label:String = "",
			thickness:Single = 6):Void {
		if (ratio < 0)
			ratio = 0;
		if (ratio > 1)
			ratio = 1;

		var start:Single = startAngle();
		var sweepTotal:Single = (Math.PI * 2) - GAP;
		var end:Single = start + sweepTotal;
		var fillEnd:Single = start + sweepTotal * ratio;

		var trackCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(color.x * 0.22, color.y * 0.22, color.z * 0.22, 0.55));
		var fillCol = ImGui.colorConvertFloat4ToU32(color);

		ImGui.ImDrawList_PathClear(dl);
		ImGui.ImDrawList_PathArcTo(dl, center, radius, start, end, 48);
		ImGui.ImDrawList_PathStroke(dl, trackCol, thickness, 0);

		if (ratio > 0.001) {
			ImGui.ImDrawList_PathClear(dl);
			ImGui.ImDrawList_PathArcTo(dl, center, radius, start, fillEnd, 48);
			ImGui.ImDrawList_PathStroke(dl, fillCol, thickness, 0);

			var capR:Single = thickness * 0.5;
			var startPt = ImGui.vec2(center.x + Math.cos(start) * radius, center.y + Math.sin(start) * radius);
			var endPt = ImGui.vec2(center.x + Math.cos(fillEnd) * radius, center.y + Math.sin(fillEnd) * radius);
			ImGui.ImDrawList_AddCircleFilled(dl, startPt, capR, fillCol, 12);
			ImGui.ImDrawList_AddCircleFilled(dl, endPt, capR, fillCol, 12);
		}

		if (label != null && label.length > 0) {
			var ts = ImGui.calcTextSize(label);
			var tx:Single = center.x - ts.x * 0.5;
			var ty:Single = center.y - ts.y * 0.5;
			var textCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0.92));
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty), textCol, label);
		}
	}
}

/**
 * Upper semicircle ("half dome") fill gauge — bowl fills left→right with ratio.
 */
class HalfDomeGauge {
	public static function draw(dl:Dynamic, center:ImVec2, radius:Single, ratio:Single, color:ImVec4, label:String = "",
			thickness:Single = 5):Void {
		if (ratio < 0)
			ratio = 0;
		if (ratio > 1)
			ratio = 1;

		// Upper semicircle: PI → 2PI in ImGui/math (clockwise from left through top to right = -PI..0)
		var start:Single = Math.PI; // left
		var end:Single = 2 * Math.PI; // right via bottom in standard math...
		// Use -PI .. 0 for upper dome (left → top → right)
		start = -Math.PI;
		end = 0;

		var trackCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(color.x * 0.22, color.y * 0.22, color.z * 0.22, 0.55));
		var fillCol = ImGui.colorConvertFloat4ToU32(color);
		var dimFill = ImGui.colorConvertFloat4ToU32(ImGui.vec4(color.x * 0.35, color.y * 0.35, color.z * 0.35, 0.35));

		// Soft dome fill under the arc
		ImGui.ImDrawList_PathClear(dl);
		ImGui.ImDrawList_PathArcTo(dl, center, radius, start, end, 40);
		ImGui.ImDrawList_PathLineTo(dl, center);
		ImGui.ImDrawList_PathFillConvex(dl, dimFill);

		ImGui.ImDrawList_PathClear(dl);
		ImGui.ImDrawList_PathArcTo(dl, center, radius, start, end, 40);
		ImGui.ImDrawList_PathStroke(dl, trackCol, thickness, 0);

		if (ratio > 0.001) {
			var fillEnd:Single = start + (end - start) * ratio;
			ImGui.ImDrawList_PathClear(dl);
			ImGui.ImDrawList_PathArcTo(dl, center, radius, start, fillEnd, 40);
			ImGui.ImDrawList_PathLineTo(dl, center);
			ImGui.ImDrawList_PathFillConvex(dl, fillCol);

			ImGui.ImDrawList_PathClear(dl);
			ImGui.ImDrawList_PathArcTo(dl, center, radius, start, fillEnd, 40);
			ImGui.ImDrawList_PathStroke(dl, fillCol, thickness, 0);
		}

		if (label != null && label.length > 0) {
			var ts = ImGui.calcTextSize(label);
			var tx:Single = center.x - ts.x * 0.5;
			var ty:Single = center.y - radius * 0.35 - ts.y * 0.5;
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0.92)), label);
		}
	}
}

/**
 * Vertical fill bar (bottom → top) with optional overlay label.
 */
class VerticalBarGauge {
	public static function draw(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, ratio:Single, color:ImVec4,
			label:String = ""):Void {
		if (ratio < 0)
			ratio = 0;
		if (ratio > 1)
			ratio = 1;
		var track = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.10, 0.11, 0.12, 0.95 * color.w));
		var fill = ImGui.colorConvertFloat4ToU32(color);
		var border = ImGui.colorConvertFloat4ToU32(ImGui.vec4(color.x * 0.5, color.y * 0.5, color.z * 0.5, 0.55 * color.w));
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), track, 4);
		if (ratio > 0.001) {
			var fillH:Single = h * ratio;
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y + h - fillH), ImGui.vec2(x + w, y + h), fill, 4);
		}
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), border, 4, 1);
		if (label != null && label.length > 0) {
			var ts = ImGui.calcTextSize(label);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + (w - ts.x) * 0.5, y + (h - ts.y) * 0.5),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0.92 * color.w)), label);
		}
	}
}

class RingGauge {
	public static function draw(dl:Dynamic, center:imgui.Structs.ImVec2, radius:Single, ratio:Float, color:imgui.Structs.ImVec4, label:String = ""):Void {
		if (ratio < 0)
			ratio = 0;
		if (ratio > 1)
			ratio = 1;
		var start:Single = -Math.PI / 2;
		var end:Single = start + Math.PI * 2;
		var fillEnd:Single = start + Math.PI * 2 * ratio;
		var trackCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(color.x * 0.22, color.y * 0.22, color.z * 0.22, 0.55 * color.w));
		var fillCol = ImGui.colorConvertFloat4ToU32(color);
		var thickness:Single = Math.max(4, radius * 0.16);
		ImGui.ImDrawList_PathClear(dl);
		ImGui.ImDrawList_PathArcTo(dl, center, radius, start, end, 48);
		ImGui.ImDrawList_PathStroke(dl, trackCol, thickness, 0);
		if (ratio > 0.001) {
			ImGui.ImDrawList_PathClear(dl);
			ImGui.ImDrawList_PathArcTo(dl, center, radius, start, fillEnd, 48);
			ImGui.ImDrawList_PathStroke(dl, fillCol, thickness, 0);
		}
		if (label != null && label.length > 0) {
			var ts = ImGui.calcTextSize(label);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(center.x - ts.x * 0.5, center.y - ts.y * 0.5),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0.92 * color.w)), label);
		}
	}
}
