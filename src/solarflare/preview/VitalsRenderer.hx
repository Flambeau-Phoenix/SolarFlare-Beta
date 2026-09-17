package solarflare.preview;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Structs.ImVec4;
import solarflare.ui.PipShapes;
import solarflare.ui.VitalsConfig;

/**
 * Frozen vitals snapshot consumed by the shared renderer. Built from live caches
 * by the HUD shims or from PreviewState by the preview; the renderer never reads
 * HealthCache / PrayerCache itself (Segment 1.3 contract).
 */
class VitalSnap {
	public static inline var HP:Int = 0;
	public static inline var RAGE:Int = 1;
	public static inline var MANA:Int = 2;

	public var kind:Int = HP;
	public var valid:Bool = false;
	public var deadKnown:Bool = false;
	public var dead:Bool = false;
	public var tapped:Bool = false;
	public var current:Float = 0;
	public var max:Float = 1;
	public var ratio:Float = 0;
	public var shield:Float = 0;
	public var sparkValid:Bool = false;

	public function new() {}
}

/**
 * Shared vitals presentation helpers (Segment 1.3).
 *
 * The live `SolarFlarePanel.drawVital` family renders through here, and the
 * ResourceTracker Builder preview will too, so both draw identical pixels from
 * the same primitives (current/max/valid/shield/ratio/style/rect).
 *
 * Contract (docs/SOLARFLARE_MODDER_GUIDE.md §6.3):
 * - Never reads or writes HealthCache / PrayerCache / any live cache.
 * - Never touches persisted positions, visibility, or window geometry.
 * - No texture loading and no JSON processing; fixed `##`-free calls are fine
 *   because the helpers draw content cells, not interactive widgets.
 * - Balanced ImGui style stack: every push inside drawBar() is popped.
 */
class VitalsRenderer {
	public static var lastHealthDiagnostic:String = "";
	static function healthTint(snap:VitalSnap, intentional:ImVec4):ImVec4 {
		var confirmedDead = snap.deadKnown && snap.dead;
		var col = solarflare.ui.HealthColorPolicy.resolve(confirmedDead, snap.tapped,
			snap.valid ? ImGui.colorConvertFloat4ToU32(intentional) : null);
		lastHealthDiagnostic = solarflare.ui.HealthColorPolicy.source(confirmedDead, snap.tapped, snap.valid)
			+ (snap.valid ? " | health valid" : " | health unavailable: empty fill");
		return ImGui.colorConvertU32ToFloat4(col);
	}
	public static function draw(snap:VitalSnap, style:Int, w:Single, h:Single, vertical:Bool, thesdRight:Bool = false):Void {
		var useSegs = style == VitalsConfig.STYLE_BAR_2X50 || style == VitalsConfig.STYLE_BAR_2X10;
		if (useSegs) {
			drawValueSegments(snap, w, h, style, vertical);
		} else if (VitalsConfig.isPipStyle(style)) {
			drawPips(snap, w, h, style, vertical);
		} else if (style == VitalsConfig.STYLE_THESD) {
			drawThesd(snap, w, h, thesdRight);
		} else if (snap.kind == VitalSnap.HP) {
			if (style == VitalsConfig.STYLE_VERTICAL || (vertical && style == VitalsConfig.STYLE_BAR))
				drawVertical(snap, w, h);
			else if (style == VitalsConfig.STYLE_CRESCENT)
				drawCrescent(snap, w, h);
			else if (style == VitalsConfig.STYLE_HALF_DOME)
				drawHalfDome(snap, w, h);
			else if (style == VitalsConfig.STYLE_RING)
				drawRing(snap, w, h);
			else
				drawBar(snap, w, h);
		} else if (style == VitalsConfig.STYLE_VERTICAL || (vertical && style == VitalsConfig.STYLE_BAR)) {
			drawVertical(snap, w, h);
		} else if (style == VitalsConfig.STYLE_CRESCENT || style == VitalsConfig.STYLE_HALF_DOME) {
			drawCrescent(snap, w, h);
		} else if (style == VitalsConfig.STYLE_RING) {
			drawRing(snap, w, h);
		} else {
			drawBar(snap, w, h);
		}
	}

	/** Primary fill tint per resource, mirrored from the live vitals palette. */
	static function fillColor(snap:VitalSnap):ImVec4 {
		if (snap.kind == VitalSnap.RAGE)
			return ImGui.vec4(0.88, 0.38, 0.12, 1);
		if (snap.kind == VitalSnap.MANA)
			return snap.sparkValid
				? ImGui.vec4(0.45, 0.72, 0.98, 1)
				: ImGui.vec4(0.28, 0.48, 0.92, 1);
		return healthTint(snap, ImGui.vec4(0.28, 0.82, 0.42, 1));
	}

	static function label(snap:VitalSnap):String {
		if (snap.kind == VitalSnap.RAGE)
			return "Rage";
		if (snap.kind == VitalSnap.MANA)
			return snap.sparkValid ? "Spark" : "Mana";
		return "HP";
	}

	/** Full overlay text while the resource has data (`642 / 642 (+50)`). */
	static function overlayValid(snap:VitalSnap):String {
		var cur = Std.string(Std.int(snap.current));
		var cap = Std.string(Std.int(snap.max));
		var base = cur + " / " + cap;
		if (snap.kind == VitalSnap.HP) {
			var s = Std.int(snap.shield);
			if (s > 0)
				base += " (+" + Std.string(s) + ")";
		}
		return base;
	}

	/** Full overlay text while the resource has no data (`HP --`). */
	static function overlayInvalid(snap:VitalSnap):String {
		if (snap.kind == VitalSnap.HP)
			return "HP --";
		if (snap.kind == VitalSnap.RAGE)
			return "Rage --";
		return label(snap) + " --";
	}

	/** Compact cell text while the resource has data (`428`, `428 +50`). */
	static function compactValid(snap:VitalSnap):String {
		if (snap.kind == VitalSnap.HP && snap.shield > 0.5)
			return Std.string(Std.int(snap.current)) + " +" + Std.string(Std.int(snap.shield));
		return Std.string(Std.int(snap.current));
	}

	/** Compact cell text while the resource has no data (`HP`, `Rage`, `Mana`). */
	static function compactInvalid(snap:VitalSnap):String {
		if (snap.kind == VitalSnap.HP)
			return "HP";
		if (snap.kind == VitalSnap.RAGE)
			return "Rage";
		return label(snap);
	}

	static function dimColor():ImVec4 {
		return ImGui.vec4(0.12, 0.14, 0.13, 0.95);
	}

	/** Classic horizontal bar (progressBar) with the per-resource theme colors. */
	static function drawBar(snap:VitalSnap, w:Single, h:Single):Void {
		var overlay = snap.valid ? overlayValid(snap) : overlayInvalid(snap);
		var fraction:Single = snap.valid ? snap.ratio : (0.0 : Single);
		var main:ImVec4;
		var hover:ImVec4;
		var frame:ImVec4;
		if (snap.kind == VitalSnap.HP) {
			main = healthTint(snap, ImGui.vec4(0.22, 0.72, 0.38, 1));
			hover = healthTint(snap, ImGui.vec4(0.30, 0.82, 0.46, 1));
			frame = ImGui.vec4(0.10, 0.14, 0.12, 0.95);
		} else if (snap.kind == VitalSnap.RAGE) {
			main = ImGui.vec4(0.88, 0.38, 0.12, 1);
			hover = ImGui.vec4(0.95, 0.48, 0.18, 1);
			frame = ImGui.vec4(0.16, 0.10, 0.08, 0.95);
		} else {
			main = ImGui.vec4(0.28, 0.48, 0.92, 1);
			hover = ImGui.vec4(0.38, 0.58, 0.98, 1);
			frame = ImGui.vec4(0.08, 0.10, 0.18, 0.95);
		}
		ImGui.pushStyleColor(ImGuiCol.PlotHistogram, main);
		ImGui.pushStyleColor(ImGuiCol.PlotHistogramHovered, hover);
		ImGui.pushStyleColor(ImGuiCol.FrameBg, frame);
		ImGui.progressBar(fraction, ImGui.vec2(w, h), overlay);
		ImGui.popStyleColor(3);
	}

	/** Full-value segmented bars (2×50 / 2×10). */
	static function drawValueSegments(snap:VitalSnap, w:Single, h:Single, style:Int, vertical:Bool):Void {
		var segs = 2;
		var perSeg:Float = style == VitalsConfig.STYLE_BAR_2X50 ? 50 : 10;
		var value:Single = snap.valid ? snap.current : 0;
		var text = snap.valid ? overlayValid(snap) : compactInvalid(snap);
		PipShapes.drawValueSegments(w, h, segs, value, perSeg, vertical, text, fillColor(snap), dimColor());
	}

	/** Pip blocks (Diamond / Circle / Hex / Ring pips). */
	static function drawPips(snap:VitalSnap, w:Single, h:Single, style:Int, vertical:Bool):Void {
		var ratio:Single = snap.valid ? snap.ratio : 0;
		var text = snap.valid ? compactValid(snap) : compactInvalid(snap);
		PipShapes.drawRatio(w, h, PipShapes.SLOTS, ratio, vertical, VitalsConfig.pipShapeOf(style), text,
			fillColor(snap), dimColor());
	}

	static function drawVertical(snap:VitalSnap, w:Single, h:Single):Void {
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var ratio:Single = snap.valid ? snap.ratio : 0;
		var text = snap.valid ? compactValid(snap) : compactInvalid(snap);
		var col = snap.kind == VitalSnap.HP ? healthTint(snap, ImGui.vec4(0.22, 0.72, 0.38, 1)) : fillColor(snap);
		VerticalBarGauge.draw(dl, origin.x, origin.y, w, h, ratio, col, text);
		ImGui.dummy(ImGui.vec2(w, h));
	}

	static function drawThesd(snap:VitalSnap, w:Single, h:Single, flip:Bool):Void {
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var ratio:Single = snap.valid ? snap.ratio : 0;
		var inner:Single = -1;
		var text = snap.valid ? overlayValid(snap) : overlayInvalid(snap);
		var col = ImGui.vec4(0.28, 0.82, 0.42, 1);
		var innerCol = ImGui.vec4(0.55, 0.82, 0.98, 1);
		if (snap.kind == VitalSnap.HP) {
			col = healthTint(snap, ImGui.vec4(0.82, 0.22, 0.20, 1));
			if (snap.valid && snap.shield > 0.5 && snap.max > 0.5) {
				inner = snap.shield / snap.max;
				if (inner > 1)
					inner = 1;
			}
		} else if (snap.kind == VitalSnap.RAGE) {
			col = ImGui.vec4(0.92, 0.72, 0.18, 1);
		} else {
			col = snap.sparkValid
				? ImGui.vec4(0.45, 0.72, 0.98, 1)
				: ImGui.vec4(0.22, 0.42, 0.92, 1);
		}
		ThesdGauge.draw(dl, origin.x, origin.y, w, h, ratio, col, text, flip, inner, inner > 0 ? innerCol : null);
		ImGui.dummy(ImGui.vec2(w, h));
	}

	static function drawCrescent(snap:VitalSnap, w:Single, h:Single):Void {
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var radius:Single = Math.min(w * 0.45, h * 0.45);
		if (radius < 14)
			radius = 14;
		var thickness:Single = Math.max(4, radius * 0.16);
		var cx:Single = origin.x + w * 0.5;
		var cy:Single = origin.y + h * 0.5;
		var ratio:Single = snap.valid ? snap.ratio : 0;
		var text = snap.valid ? compactValid(snap) : compactInvalid(snap);
		CrescentGauge.draw(dl, ImGui.vec2(cx, cy), radius, ratio, fillColor(snap), text, thickness);
		ImGui.dummy(ImGui.vec2(w, h));
	}

	static function drawHalfDome(snap:VitalSnap, w:Single, h:Single):Void {
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var radius:Single = Math.min(w * 0.45, h * 0.55);
		if (radius < 14)
			radius = 14;
		var cx:Single = origin.x + w * 0.5;
		var cy:Single = origin.y + h * 0.62;
		var ratio:Single = snap.valid ? snap.ratio : 0;
		var text = snap.valid ? compactValid(snap) : compactInvalid(snap);
		HalfDomeGauge.draw(dl, ImGui.vec2(cx, cy), radius, ratio, fillColor(snap), text);
		ImGui.dummy(ImGui.vec2(w, h));
	}

	static function drawRing(snap:VitalSnap, w:Single, h:Single):Void {
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var radius:Single = Math.min(w, h) * 0.42;
		if (radius < 14)
			radius = 14;
		var ratio:Single = snap.valid ? snap.ratio : 0;
		var text = snap.valid ? compactValid(snap) : compactInvalid(snap);
		RingGauge.draw(dl, ImGui.vec2(origin.x + w * 0.5, origin.y + h * 0.5), radius, ratio, fillColor(snap), text);
		ImGui.dummy(ImGui.vec2(w, h));
	}
}