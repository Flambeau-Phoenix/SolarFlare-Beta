package solarflare.aura;

import solarflare.ui.GameIcons;
import solarflare.ui.VitalsConfig;
import imgui.ImGui;

/** Shared, presentation-only Aura renderer used by the live HUD and builder preview. */
class AuraVisualRenderer {
	public static function draw(dl:Dynamic, a:AuraDef, x:Single, y:Single, w:Single, h:Single,
			progress:Float, stacks:Int, counterValue:Int, ghost:Bool, effectAlpha:Float = 1):Void {
		if (a == null || w < 1 || h < 1)
			return;
		var p = clamp01(progress);
		var alpha:Float = a.opacity != null ? clamp01(a.opacity.get()) : 1;
		alpha *= clamp01(effectAlpha);
		if (ghost)
			alpha *= 0.38;
		var count = a.isCounter != null && a.isCounter.get() ? counterValue : stacks;
		var showCount = (a.isCounter != null && a.isCounter.get())
			|| (a.stackCounter != null && a.stackCounter.get() && count > 1);
		var label = a.region == "text" ? (a.announce != null ? a.announce : "") : a.displayLabel();
		if (showCount && a.region != "icon")
			label += " [" + Std.string(count) + "]";

		if (a.region == "icon") {
			drawIcon(dl, a, x, y, w, h, p, count, showCount, ghost, alpha);
			return;
		}
		var visibleLabel = a.showLabel != null && a.showLabel.get() ? label : "";
		var col = ImGui.vec4(0.35, 0.78, 0.95, alpha);
		if (a.region == "ring") {
			var rad:Single = (w < h ? w : h) * 0.42;
			RingGauge.draw(dl, ImGui.vec2(x + w * 0.5, y + h * 0.5), rad, p, col, visibleLabel);
			return;
		}
		if (a.region == "text") {
			var ts = ImGui.calcTextSize(label);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + (w - ts.x) * 0.5, y + (h - ts.y) * 0.5),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, alpha)), label);
			return;
		}
		VerticalBarGauge.draw(dl, x + 4, y + 4, w - 8, h - 8, p, col, visibleLabel);
	}

	static function drawIcon(dl:Dynamic, a:AuraDef, x:Single, y:Single, w:Single, h:Single,
			progress:Float, count:Int, showCount:Bool, ghost:Bool, alpha:Float):Void {
		var labelH:Single = a.showLabel != null && a.showLabel.get() ? Math.min(22, h * 0.24) : 0;
		var iconH:Single = h - labelH;
		var side:Single = w < iconH ? w : iconH;
		var ix = x + (w - side) * 0.5;
		var iy = y + (iconH - side) * 0.5;
		var stem = a.preferredIconId();
		var tex = GameIcons.get(stem);
		var tint = ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, alpha));
		if (!GameIcons.draw(dl, tex, ix, iy, side, tint)) {
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(ix, iy), ImGui.vec2(ix + side, iy + side),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.1, 0.12, 0.16, alpha * 0.85)), 6);
			var missing = stem.length > 0 ? "?" : "+";
			var mts = ImGui.calcTextSize(missing);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(ix + (side - mts.x) * 0.5, iy + (side - mts.y) * 0.5),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.7, 0.75, 0.82, alpha)), missing);
		}
		if (!ghost && a.iconGlow) {
			ImGui.ImDrawList_AddRect(dl, ImGui.vec2(ix - 2, iy - 2), ImGui.vec2(ix + side + 2, iy + side + 2),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 0.85, 0.25, 0.85 * alpha)), 8, 2.5, 0);
		}
		if (a.progressRing != null && a.progressRing.get() && progress > 0.001 && progress < 0.999) {
			var rad:Single = side * 0.46;
			RingGauge.draw(dl, ImGui.vec2(ix + side * 0.5, iy + side * 0.5), rad, progress,
				ImGui.vec4(0.95, 0.82, 0.28, 0.9 * alpha), "");
		}
		if (!ghost && a.showFuse != null && a.showFuse.get())
			drawFuse(dl, ix, iy, side, progress, alpha);
		if (!ghost && a.showCountdown != null && a.showCountdown.get())
			drawCountdown(dl, ix, iy, side, a, alpha);
		if (showCount) {
			var st = Std.string(count);
			var ts = ImGui.calcTextSize(st);
			var bx0 = ix + side - ts.x - 10;
			var by0 = iy + side - ts.y - 7;
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(bx0, by0), ImGui.vec2(ix + side - 1, iy + side - 1),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.02, 0.03, 0.05, 0.9 * alpha)), 5);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(bx0 + 4, by0 + 2),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, alpha)), st);
		}
		if (labelH > 0) {
			var label = a.displayLabel();
			var ts = ImGui.calcTextSize(label);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + (w - ts.x) * 0.5, y + h - labelH + 2),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, alpha)), label);
		}
	}

	/** Vertical fuse on the right edge: filled height = remaining ratio, drains top→bottom. */
	static function drawFuse(dl:Dynamic, ix:Single, iy:Single, side:Single, progress:Float, alpha:Float):Void {
		var p = clamp01(progress);
		var fw:Single = Math.max(3, side * 0.08);
		var pad:Single = 2;
		var x0 = ix + side - fw - pad;
		var y0 = iy + pad;
		var y1 = iy + side - pad;
		var fullH = y1 - y0;
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x0, y0), ImGui.vec2(x0 + fw, y1),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.05, 0.06, 0.08, 0.75 * alpha)), 2);
		if (p > 0.001) {
			var fillH = fullH * p;
			var fy0 = y1 - fillH;
			var hot = p < 0.25;
			var col = hot
				? ImGui.vec4(0.95, 0.35, 0.2, 0.95 * alpha)
				: ImGui.vec4(0.95, 0.78, 0.28, 0.92 * alpha);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x0, fy0), ImGui.vec2(x0 + fw, y1),
				ImGui.colorConvertFloat4ToU32(col), 2);
		}
	}

	static function drawCountdown(dl:Dynamic, ix:Single, iy:Single, side:Single, a:AuraDef, alpha:Float):Void {
		var text = "";
		if (a.timerInfinite)
			text = "∞";
		else if (Math.isFinite(a.timeLeft) && a.timeLeft >= 0) {
			var sec = Math.ceil(a.timeLeft - 0.001);
			if (sec < 0)
				sec = 0;
			text = Std.string(sec);
		} else
			return;
		var ts = ImGui.calcTextSize(text);
		var tx = ix + (side - ts.x) * 0.5;
		var ty = iy + (side - ts.y) * 0.5;
		var pad:Single = 4;
		ImGui.ImDrawList_AddRectFilled(dl,
			ImGui.vec2(tx - pad, ty - 2),
			ImGui.vec2(tx + ts.x + pad, ty + ts.y + 2),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.02, 0.03, 0.05, 0.72 * alpha)), 6);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 0.95, 0.75, alpha)), text);
	}

	static inline function clamp01(v:Float):Float {
		return v < 0 ? 0 : (v > 1 ? 1 : v);
	}
}
