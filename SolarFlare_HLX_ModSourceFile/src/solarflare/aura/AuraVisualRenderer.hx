package solarflare.aura;

import solarflare.ui.GameIcons;
import solarflare.ui.VitalsConfig.RingGauge;
import solarflare.ui.VitalsConfig.VerticalBarGauge;
import imgui.ImGui;

/** Shared, presentation-only Aura renderer used by the live HUD and builder preview. */
class AuraVisualRenderer {
	/** Auto-draw seconds when follow-buff left is known and at or below this. */
	public static inline var AUTO_COUNTDOWN_MAX:Float = 30;

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
		if (showCount && a.region != "icon" && a.region != "canvas")
			label += " [" + Std.string(count) + "]";

		if (a.region == "canvas") {
			drawCanvas(dl, a, x, y, w, h, p, count, showCount, ghost, alpha);
			return;
		}
		if (a.region == "icon") {
			drawIcon(dl, a, x, y, w, h, p, count, showCount, ghost, alpha);
			return;
		}
		var visibleLabel = a.showLabel != null && a.showLabel.get() ? label : "";
		var col = ImGui.vec4(0.35, 0.78, 0.95, alpha);
		if (a.region == "ring") {
			var rad:Single = (w < h ? w : h) * 0.42;
			if (!ghost && (a.show || (a.alwaysOn != null && a.alwaysOn.get()))) {
				var ringGlowCol = a.glowColor != 0 ? (a.glowColor & 0x00FFFFFF) : ImGui.colorConvertFloat4ToU32(col);
				solarflare.ui.VectorGlow.radial(dl, x + w * 0.5, y + h * 0.5, rad * 1.08, (Std.int(0x55 * alpha) << 24) | (ringGlowCol & 0x00FFFFFF), 0.35, 4);
			}
			RingGauge.draw(dl, ImGui.vec2(x + w * 0.5, y + h * 0.5), rad, p, col, visibleLabel);
			return;
		}
		if (a.region == "text") {
			var ts = ImGui.calcTextSize(label);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + (w - ts.x) * 0.5, y + (h - ts.y) * 0.5),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, alpha)), label);
			return;
		}
		if (!ghost && (a.show || (a.alwaysOn != null && a.alwaysOn.get()))) {
			var barGlowCol = a.glowColor != 0 ? (a.glowColor & 0x00FFFFFF) : ImGui.colorConvertFloat4ToU32(col);
			solarflare.ui.VectorGlow.rect(dl, x + 4, y + 4, w - 8, h - 8, (Std.int(0x77 * alpha) << 24) | (barGlowCol & 0x00FFFFFF), 4.0, 1.5);
		}
		VerticalBarGauge.draw(dl, x + 4, y + 4, w - 8, h - 8, p, col, visibleLabel);
	}

	/** Freeform element placements + optional glow / fuse / countdown overlays. */
	static function drawCanvas(dl:Dynamic, a:AuraDef, x:Single, y:Single, w:Single, h:Single,
			progress:Float, count:Int, showCount:Bool, ghost:Bool, alpha:Float):Void {
		if (!ghost && a.iconGlow) {
			drawGlowRect(dl, x, y, w, h, a.glowColor, alpha);
		} else if (!ghost && (a.show || (a.alwaysOn != null && a.alwaysOn.get()))) {
			var canvasGlowCol = a.glowColor != 0 ? (a.glowColor & 0x00FFFFFF) : 0x44CCFF;
			solarflare.ui.VectorGlow.rect(dl, x, y, w, h, (Std.int(0x66 * alpha) << 24) | (canvasGlowCol & 0x00FFFFFF), 6.0, 1.5);
		}

		var els = a.canvasElements;
		if (els == null || els.length == 0) {
			// Fallback: treat like icon region when no freeform layout yet.
			drawIcon(dl, a, x, y, w, h, progress, count, showCount, ghost, alpha);
			return;
		}

		var i = 0;
		while (i < els.length) {
			var el = els[i];
			i++;
			if (el == null)
				continue;
			if (el.kind == AuraCanvasElement.KIND_ICON) {
				var iw:Single = el.w > 1 ? el.w : w;
				var ih:Single = el.h > 1 ? el.h : h;
				var id = el.content != null && el.content.length > 0 ? el.content : a.preferredIconId();
				var tint = applyAlphaToPacked(el.color, alpha);
				if (!GameIcons.drawKey(dl, id, x + el.x, y + el.y, iw, ih, tint)) {
					ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + el.x, y + el.y),
						ImGui.vec2(x + el.x + iw, y + el.y + ih),
						ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.1, 0.12, 0.16, alpha * 0.85)), 6);
				}
			} else {
				var raw = el.content != null ? el.content : "";
				var formatted = formatTokens(raw, a, count);
				var fontSize:Single = el.fontSize > 4 ? el.fontSize : 16;
				ImGui.pushFont(ImGui.getFont(), fontSize);
				var col = applyAlphaToPacked(el.color, alpha);
				ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + el.x, y + el.y), col, formatted);
				ImGui.popFont();
			}
		}

		if (!ghost && wantFuse(a, progress)) {
			if (a.fuseBottom != null && a.fuseBottom.get())
				drawFuseBottom(dl, x, y, w, h, progress, alpha);
			else
				drawFuse(dl, x, y, Math.min(w, h), progress, alpha);
		}
		if (!ghost && wantCountdown(a))
			drawCountdown(dl, x, y, Math.min(w, h), a, alpha);
		if (showCount) {
			var st = Std.string(count);
			var ts = ImGui.calcTextSize(st);
			var bx0 = x + w - ts.x - 10;
			var by0 = y + h - ts.y - 7;
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(bx0, by0), ImGui.vec2(x + w - 1, y + h - 1),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.02, 0.03, 0.05, 0.9 * alpha)), 5);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(bx0 + 4, by0 + 2),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, alpha)), st);
		}
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
			drawGlowRect(dl, ix - 2, iy - 2, side + 4, side + 4, a.glowColor, alpha);
		} else if (!ghost && (a.show || (a.alwaysOn != null && a.alwaysOn.get()))) {
			var iconGlowCol = a.glowColor != 0 ? (a.glowColor & 0x00FFFFFF) : 0x44CCFF;
			solarflare.ui.VectorGlow.rect(dl, ix, iy, side, side, (Std.int(0x77 * alpha) << 24) | (iconGlowCol & 0x00FFFFFF), 6.0, 1.5);
		}
		if (a.progressRing != null && a.progressRing.get() && progress > 0.001 && progress < 0.999) {
			var rad:Single = side * 0.46;
			RingGauge.draw(dl, ImGui.vec2(ix + side * 0.5, iy + side * 0.5), rad, progress,
				ImGui.vec4(0.95, 0.82, 0.28, 0.9 * alpha), "");
		}
		if (!ghost && wantFuse(a, progress)) {
			if (a.fuseBottom != null && a.fuseBottom.get())
				drawFuseBottom(dl, ix, iy, side, side, progress, alpha);
			else
				drawFuse(dl, ix, iy, side, progress, alpha);
		}
		if (!ghost && wantCountdown(a))
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

	static function drawGlowRect(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, packed:Int, alpha:Float):Void {
		if (alpha <= 0.02)
			return;
		// packed is 0xAARRGGBB — strip alpha; procOverlay owns pulse alphas.
		var rgb = packed != 0 ? (packed & 0x00FFFFFF) : 0xFFB000;
		var core = rgb;
		var bloom = rgb;
		// Prefer warmer bloom when packed looks near-white core.
		var r = (rgb >> 16) & 0xFF;
		var g = (rgb >> 8) & 0xFF;
		var b = rgb & 0xFF;
		if (r > 220 && g > 200 && b > 140)
			bloom = 0xFFB000;
		else if (r + g + b < 120)
			core = 0xFFF6A0;
		solarflare.ui.VectorGlow.procOverlay(dl, x, y, w, h, ImGui.getTime(), core, bloom);
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

	/** Bottom strip fuse: remaining ratio fills left→right. */
	static function drawFuseBottom(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, progress:Float, alpha:Float):Void {
		var p = clamp01(progress);
		var barH:Single = Math.max(4, h * 0.08);
		var y0 = y + h - barH;
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y0), ImGui.vec2(x + w, y0 + barH),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0, 0, 0, 0.45 * alpha)), 0);
		if (p > 0.001) {
			var hot = p < 0.25;
			var col = hot
				? ImGui.vec4(0.95, 0.35, 0.2, 0.95 * alpha)
				: ImGui.vec4(0.0, 1.0, 0.8, 0.92 * alpha);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y0), ImGui.vec2(x + w * p, y0 + barH),
				ImGui.colorConvertFloat4ToU32(col), 0);
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

	/** Explicit toggle, or auto when known remaining is at/under AUTO_COUNTDOWN_MAX. */
	static function wantCountdown(a:AuraDef):Bool {
		if (a.showCountdown != null && a.showCountdown.get())
			return true;
		if (a.timerInfinite)
			return false;
		return Math.isFinite(a.timeLeft) && a.timeLeft >= 0 && a.timeLeft <= AUTO_COUNTDOWN_MAX;
	}

	/** Explicit fuse, or auto alongside short known remaining timers. */
	static function wantFuse(a:AuraDef, progress:Float):Bool {
		if (a.showFuse != null && a.showFuse.get())
			return true;
		if (a.timerInfinite)
			return false;
		if (!(Math.isFinite(a.timeLeft) && a.timeLeft >= 0 && a.timeLeft <= AUTO_COUNTDOWN_MAX))
			return false;
		return progress > 0.001 && progress < 0.999;
	}

	/** Substitute canvas tokens. `stacks` is the effective count already resolved by drawCanvas. */
	static function formatTokens(content:String, a:AuraDef, stacks:Int = 0):String {
		if (content == null || content.length == 0)
			return "";
		var s = content;
		if (s.indexOf("{name}") >= 0)
			s = s.split("{name}").join(a != null ? a.displayLabel() : "");
		if (s.indexOf("{time}") >= 0) {
			var t = "";
			if (a != null && a.timerInfinite)
				t = "inf";
			else if (a != null && Math.isFinite(a.timeLeft) && a.timeLeft >= 0)
				t = Std.string(Math.max(0, Math.round(a.timeLeft * 10) / 10));
			s = s.split("{time}").join(t);
		}
		if (s.indexOf("{stacks}") >= 0)
			s = s.split("{stacks}").join(Std.string(stacks));
		return s;
	}

	/** Apply opacity to 0xAARRGGBB packed color → ImGui U32. */
	static function applyAlphaToPacked(packed:Int, alpha:Float):Int {
		var a = ((packed >>> 24) & 0xFF) / 255.0;
		var r = ((packed >>> 16) & 0xFF) / 255.0;
		var g = ((packed >>> 8) & 0xFF) / 255.0;
		var b = (packed & 0xFF) / 255.0;
		a *= clamp01(alpha);
		return ImGui.colorConvertFloat4ToU32(ImGui.vec4(r, g, b, a));
	}

	static inline function clamp01(v:Float):Float {
		return v < 0 ? 0 : (v > 1 ? 1 : v);
	}
}
