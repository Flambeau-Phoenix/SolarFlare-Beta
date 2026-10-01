package solarflare.aura;

import solarflare.ui.GameIcons;
import solarflare.ui.VitalsConfig.RingGauge;
import solarflare.ui.VitalsConfig.VerticalBarGauge;
import imgui.ImGui;
import solarflare.ui.HUDVisualBounds;

/** Shared, presentation-only Aura renderer used by the live HUD and builder preview. */
class AuraVisualRenderer {
	/** Auto-draw seconds when follow-buff left is known and at or below this. */
	public static inline var AUTO_COUNTDOWN_MAX:Float = 30;

	/** Published once per frame by AuraOverlay; 0 = no ceiling. */
	public static var countdownCeiling:Float = 0;
	public static var countdownAll:Bool = true;
	public static var countdownGlobalScale:Float = 1;

	/** Bound for this draw() only — preview may seed remaining/glow without mutating AuraDef. */
	static var faceLeft:Float = Math.NaN;
	static var faceInf:Bool = false;
	static var faceGlow:Bool = false;
	static var faceFx:Bool = true;
	/** Maximum procOverlay reach: icon outset 2 + bloom 10 + stroke/AA 2. */
	public static inline var GLOW_REACH:Float = 14;

	/** Measure the same face and plates as draw(), before choosing the host/preview clip. */
	public static function measureBounds(a:AuraDef, w:Single, h:Single, stacks:Int, counterValue:Int,
			out:HUDVisualBounds, vectorScale:Float = 1, previewLeft:Null<Float> = null,
			previewGlow:Null<Bool> = null):Void {
		out.reset(w, h);
		bindFace(a, false, previewLeft, previewGlow);
		var fx:Single = 0;
		var fy:Single = 0;
		var fw:Single = w;
		var fh:Single = h;
		var icon = a.region == "icon" || (a.region == "canvas" && (a.canvasElements == null || a.canvasElements.length == 0));
		if (icon) {
			var labelH:Single = a.showLabel.get() ? Math.min(22, h * 0.24) : 0;
			fw = fh = Math.min(w, h - labelH);
			fx = (w - fw) * 0.5;
			fy = (h - labelH - fh) * 0.5;
			if (labelH > 0) {
				var ts = ImGui.calcTextSize(a.displayLabel());
				out.include((w - ts.x) * 0.5, h - labelH + 2, ts.x, ts.y + 1);
			}
		} else if (a.region == "text") {
			var ts = measureTextFace(a, w, vectorScale);
			out.include((w - ts.x) * 0.5, (h - ts.y) * 0.5, ts.x, ts.y);
			fy = (h + ts.y) * 0.5;
			fh = ts.y;
		} else if (a.region != "canvas" && a.showLabel.get()) {
			var ts = ImGui.calcTextSize(a.displayLabel());
			out.include((w - ts.x) * 0.5, (h - ts.y) * 0.5, ts.x, ts.y);
		}
		if (a.region == "ring") out.includeRing(w * 0.5, h * 0.5, Math.min(w, h) * 0.42, vectorScale);
		if (icon && a.progressRing.get()) out.includeRing(fx + fw * 0.5, fy + fh * 0.5, fw * 0.46, vectorScale);
		if (faceGlow && a.region != "text" && a.glowStrength.get() > 0) {
			var reach:Single = AuraGlowStyle.reach(a.glowStyle, a.glowOuter.get()) + (icon ? 2 : 0);
			out.include(fx - reach, fy - reach, fw + reach * 2, fh + reach * 2);
		}
		if (a.region == "canvas" && !icon) {
			for (el in a.canvasElements) {
				if (el == null) continue;
				if (el.kind == AuraCanvasElement.KIND_ICON) {
					out.include(el.x * vectorScale, el.y * vectorScale,
						el.w > 1 ? el.w * vectorScale : w, el.h > 1 ? el.h * vectorScale : h);
				} else {
					var ts = textSize(formatTokens(el.content, a, a.stackCounter.get() ? stacks : counterValue),
						(el.fontSize > 4 ? el.fontSize : 16) * vectorScale);
					out.include(el.x * vectorScale, el.y * vectorScale, ts.x, ts.y);
				}
			}
		}
		if (wantCountdown(a)) {
			var side = Math.min(fw, fh);
			var size = HUDVisualBounds.fontSize(side, 0.34, a.countdownScale.get() * countdownGlobalScale);
			var text = faceInf ? "\u221E" : formatRemain(faceLeft);
			var ts = textSize(text, size);
			// Reserve a stable usual timer width so second-by-second changes don't resize the host.
			var reserve = textSize("00:00", size);
			out.includePlate(fx, fy, fw, fh, Math.max(ts.x, reserve.x), Math.max(ts.y, reserve.y), a.countdownPlace);
		}
		if (a.region != "text" && ((a.stackCounter.get() && stacks >= 1) || a.isCounter.get())) {
			var count = a.stackCounter.get() && stacks >= 1 ? stacks : counterValue;
			var ts = textSize(Std.string(count), HUDVisualBounds.fontSize(Math.min(fw, fh), 0.28, a.stackScale.get()));
			out.includePlate(fx, fy, fw, fh, ts.x, ts.y, a.stackPlace);
		}
		if (a.showKey.get()) {
			var key = AuraDef.sanitizeKey(a.keyText);
			if (key.length > 0) {
				var side = Math.min(w, h);
				var ts = textSize(key, keyFontSize(side));
				out.include(1, 0, ts.x + Math.max(4, side * 0.06) + 3, ts.y + Math.max(2, side * 0.04) + 3);
			}
		}
	}

	static function textSize(text:String, size:Single):imgui.Structs.ImVec2 {
		ImGui.pushFont(ImGui.getFont(), size);
		var result:imgui.Structs.ImVec2 = null;
		try { result = ImGui.calcTextSize(text); }
		catch (e:Dynamic) { ImGui.popFont(); throw e; }
		ImGui.popFont();
		return result;
	}

	static function keyFontSize(side:Single):Single {
		return Math.max(12, Math.min(22, Math.max(ImGui.getFontSize() * 1.05, side * 0.28)));
	}
	static function textFace(a:AuraDef, width:Single, vectorScale:Float):String {
		return a.textWrapCache.resolve(a.announce != null ? a.announce : "", width,
			AuraTextLayout.fontSize(a.textSize.get() * vectorScale), ImGui.getFont(),
			function(value:String) return ImGui.calcTextSize(value).x);
	}
	static function measureTextFace(a:AuraDef, width:Single, vectorScale:Float):imgui.Structs.ImVec2 {
		ImGui.pushFont(ImGui.getFont(), AuraTextLayout.fontSize(a.textSize.get() * vectorScale));
		var ts:imgui.Structs.ImVec2 = null;
		try { ts = ImGui.calcTextSize(textFace(a, width, vectorScale)); }
		catch (e:Dynamic) { ImGui.popFont(); throw e; }
		ImGui.popFont();
		return ts;
	}

	/** Same key reminder in preview and live output. */
	public static function drawKeyChip(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, a:AuraDef, ghost:Bool):Void {
		if (!a.showKey.get()) return;
		var key = AuraDef.sanitizeKey(a.keyText);
		if (key.length == 0) return;
		var side = Math.min(w, h);
		ImGui.pushFont(ImGui.getFont(), keyFontSize(side));
		try {
			var ts = ImGui.calcTextSize(key);
			var tx:Single = x + 3;
			var ty:Single = y + 2;
			var alpha:Single = ghost ? 0.55 : 0.88;
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(tx - 1, ty - 1),
				ImGui.vec2(tx + ts.x + Math.max(4, side * 0.06), ty + ts.y + Math.max(2, side * 0.04)),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.02, 0.02, 0.03, alpha)), 4);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx + 1, ty + 1), 0xEE000000, key);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 0.96, 0.78, ghost ? 0.75 : 1)), key);
		} catch (e:Dynamic) { ImGui.popFont(); throw e; }
		ImGui.popFont();
	}

	public static function draw(dl:Dynamic, a:AuraDef, x:Single, y:Single, w:Single, h:Single,
			progress:Float, stacks:Int, counterValue:Int, ghost:Bool, effectAlpha:Float = 1,
			vectorScale:Float = 1, previewLeft:Null<Float> = null, previewGlow:Null<Bool> = null):Void {
		if (a == null || w < 1 || h < 1)
			return;
		bindFace(a, ghost, previewLeft, previewGlow);
		var p = clamp01(progress);
		var alpha:Float = a.opacity != null ? clamp01(a.opacity.get()) : 1;
		alpha *= clamp01(effectAlpha);
		if (ghost)
			alpha *= 0.38;
		var count = stacks;
		var showCount = false;
		// Prefer status/resource stacks over activation counter when both are armed —
		// otherwise "Count activations" silently steals the corner badge from Demonic Charge etc.
		if (a.stackCounter != null && a.stackCounter.get() && stacks >= 1) {
			showCount = true;
			count = stacks;
		} else if (a.isCounter != null && a.isCounter.get()) {
			showCount = true;
			count = counterValue;
		}
		var label = a.region == "text" ? (a.announce != null ? a.announce : "") : a.displayLabel();
		if (a.region == "canvas") {
			drawCanvas(dl, a, x, y, w, h, p, count, showCount, ghost, alpha, vectorScale);
			return;
		}
		if (a.region == "icon") {
			drawIcon(dl, a, x, y, w, h, p, count, showCount, ghost, alpha, vectorScale);
			return;
		}
		var visibleLabel = a.showLabel != null && a.showLabel.get() ? label : "";
		var col = ImGui.vec4(0.35, 0.78, 0.95, alpha);
		if (a.region == "ring") {
			var rad:Single = (w < h ? w : h) * 0.42;
			if (faceFx && faceGlow) drawGlowRect(dl, x, y, w, h, a, alpha);
			RingGauge.draw(dl, ImGui.vec2(x + w * 0.5, y + h * 0.5), rad, p, col, visibleLabel, vectorScale);
			if (faceFx && wantCountdown(a))
				drawCountdown(dl, x, y, w, h, a, alpha);
			if (showCount)
				drawStackDisplay(dl, x, y, w, h, count, a, alpha);
			return;
		}
		if (a.region == "text") {
			ImGui.pushFont(ImGui.getFont(), AuraTextLayout.fontSize(a.textSize.get() * vectorScale));
			var ts:imgui.Structs.ImVec2 = null;
			try {
				var wrapped = textFace(a, w, vectorScale);
				ts = ImGui.calcTextSize(wrapped);
				ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + (w - ts.x) * 0.5, y + (h - ts.y) * 0.5),
					ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, alpha)), wrapped);
			} catch (e:Dynamic) { ImGui.popFont(); throw e; }
			ImGui.popFont();
			if (faceFx && wantCountdown(a))
				drawCountdown(dl, x, y + (h + ts.y) * 0.5, w, ts.y, a, alpha);
			return;
		}
		if (faceFx && faceGlow) drawGlowRect(dl, x + 4, y + 4, w - 8, h - 8, a, alpha);
		VerticalBarGauge.draw(dl, x + 4, y + 4, w - 8, h - 8, p, col, visibleLabel);
		if (faceFx && wantCountdown(a))
			drawCountdown(dl, x + 4, y + 4, w - 8, h - 8, a, alpha);
		if (showCount)
			drawStackDisplay(dl, x, y, w, h, count, a, alpha);
	}

	/** Stack / counter plate with the same Top / Center / Bottom placement model as countdown text. */
	static function drawStackDisplay(dl:Dynamic, x:Single, y:Single, w:Single, h:Single,
			count:Int, a:AuraDef, alpha:Float):Void {
		var st = Std.string(count);
		var side:Single = w < h ? w : h;
		var scale = a.stackScale != null ? a.stackScale.get() : 1;
		var fontSize:Single = HUDVisualBounds.fontSize(side, 0.28, scale);
		ImGui.pushFont(ImGui.getFont(), fontSize);
		try {
			var ts = ImGui.calcTextSize(st);
			var tx = x + (w - ts.x) * 0.5;
			var ty:Single = HUDVisualBounds.plateY(y, h, ts.y, a.stackPlace);
			var pad:Single = 4;
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(tx - pad, ty - 2),
				ImGui.vec2(tx + ts.x + pad, ty + ts.y + 2),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.02, 0.03, 0.05, 0.82 * alpha)), 6);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx + 1, ty + 1),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0, 0, 0, 0.95 * alpha)), st);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, alpha)), st);
		} catch (e:Dynamic) { ImGui.popFont(); throw e; }
		ImGui.popFont();
	}

	static function bindFace(a:AuraDef, ghost:Bool, previewLeft:Null<Float>, previewGlow:Null<Bool>):Void {
		faceFx = !ghost;
		faceInf = a.timerInfinite;
		faceLeft = a.timeLeft;
		if (previewLeft != null) {
			faceLeft = previewLeft;
			faceInf = previewLeft < 0;
		}
		faceGlow = previewGlow != null ? previewGlow : a.iconGlow;
	}

	/** Freeform element placements + optional glow / fuse / countdown overlays. */
	static function drawCanvas(dl:Dynamic, a:AuraDef, x:Single, y:Single, w:Single, h:Single,
			progress:Float, count:Int, showCount:Bool, ghost:Bool, alpha:Float, vectorScale:Float):Void {
		var els = a.canvasElements;
		if (els == null || els.length == 0) {
			// Fallback: treat like icon region when no freeform layout yet.
			drawIcon(dl, a, x, y, w, h, progress, count, showCount, ghost, alpha, vectorScale);
			return;
		}
		if (faceFx && faceGlow) drawGlowRect(dl, x, y, w, h, a, alpha);

		var i = 0;
		while (i < els.length) {
			var el = els[i];
			i++;
			if (el == null)
				continue;
			if (el.kind == AuraCanvasElement.KIND_ICON) {
				var iw:Single = el.w > 1 ? el.w * vectorScale : w;
				var ih:Single = el.h > 1 ? el.h * vectorScale : h;
				var ex:Single = x + el.x * vectorScale;
				var ey:Single = y + el.y * vectorScale;
				var id = el.content != null && el.content.length > 0 ? el.content : a.preferredIconId();
				var tint = applyAlphaToPacked(el.color, alpha);
				if (!GameIcons.drawKey(dl, id, ex, ey, iw, ih, tint)) {
					ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(ex, ey),
						ImGui.vec2(ex + iw, ey + ih),
						ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.1, 0.12, 0.16, alpha * 0.85)), 6);
				}
			} else {
				var raw = el.content != null ? el.content : "";
				var formatted = formatTokens(raw, a, count);
				var fontSize:Single = (el.fontSize > 4 ? el.fontSize : 16) * vectorScale;
				ImGui.pushFont(ImGui.getFont(), fontSize);
				try {
					var col = applyAlphaToPacked(el.color, alpha);
					ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + el.x * vectorScale, y + el.y * vectorScale), col, formatted);
				} catch (e:Dynamic) { ImGui.popFont(); throw e; }
				ImGui.popFont();
			}
		}

		if (faceFx && wantFuse(a, progress)) {
			if (a.fuseBottom != null && a.fuseBottom.get())
				drawFuseBottom(dl, x, y, w, h, progress, alpha);
			else
				drawFuse(dl, x, y, Math.min(w, h), progress, alpha);
		}
		if (faceFx && wantCountdown(a))
			drawCountdown(dl, x, y, w, h, a, alpha);
		if (showCount) {
			drawStackDisplay(dl, x, y, w, h, count, a, alpha);
		}
	}

	static function drawIcon(dl:Dynamic, a:AuraDef, x:Single, y:Single, w:Single, h:Single,
			progress:Float, count:Int, showCount:Bool, ghost:Bool, alpha:Float, vectorScale:Float):Void {
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
		if (faceFx && faceGlow) {
			drawGlowRect(dl, ix - 2, iy - 2, side + 4, side + 4, a, alpha);
		}
		if (a.progressRing != null && a.progressRing.get() && progress > 0.001 && progress < 0.999) {
			var rad:Single = side * 0.46;
			RingGauge.draw(dl, ImGui.vec2(ix + side * 0.5, iy + side * 0.5), rad, progress,
				ImGui.vec4(0.95, 0.82, 0.28, 0.9 * alpha), "", vectorScale);
		}
		if (faceFx && wantFuse(a, progress)) {
			if (a.fuseBottom != null && a.fuseBottom.get())
				drawFuseBottom(dl, ix, iy, side, side, progress, alpha);
			else
				drawFuse(dl, ix, iy, side, progress, alpha);
		}
		if (faceFx && wantCountdown(a))
			drawCountdown(dl, ix, iy, side, side, a, alpha);
		if (showCount)
			drawStackDisplay(dl, ix, iy, side, side, count, a, alpha);
		if (labelH > 0) {
			var label = a.displayLabel();
			var ts = ImGui.calcTextSize(label);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + (w - ts.x) * 0.5, y + h - labelH + 2),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, alpha)), label);
		}
	}

	static function drawGlowRect(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, a:AuraDef, alpha:Float):Void {
		if (alpha <= 0.02)
			return;
		AuraGlowRenderer.draw(dl, a, x, y, w, h, alpha);
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

	/**
	 * Countdown plate over the aura face. Size/empty guards run before pushFont so the
	 * matching popFont can never be skipped by an early return.
	 */
	static function drawCountdown(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, a:AuraDef, alpha:Float):Void {
		var text = faceInf ? "\u221E" : formatRemain(faceLeft);
		if (text.length == 0 || w < 8 || h < 8)
			return;
		var side:Single = w < h ? w : h;
		var scale = (a.countdownScale != null ? a.countdownScale.get() : 1) * countdownGlobalScale;
		var fontSize:Single = HUDVisualBounds.fontSize(side, 0.34, scale);
		ImGui.pushFont(ImGui.getFont(), fontSize);
		try {
			var ts = ImGui.calcTextSize(text);
			var tx = x + (w - ts.x) * 0.5;
			var ty:Single = HUDVisualBounds.plateY(y, h, ts.y, a.countdownPlace);
			var pad:Single = 4;
			ImGui.ImDrawList_AddRectFilled(dl,
				ImGui.vec2(tx - pad, ty - 2),
				ImGui.vec2(tx + ts.x + pad, ty + ts.y + 2),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.02, 0.03, 0.05, 0.72 * alpha)), 6);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx + 1, ty + 1),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0, 0, 0, 0.95 * alpha)), text);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 0.95, 0.75, alpha)), text);
		} catch (e:Dynamic) { ImGui.popFont(); throw e; }
		ImGui.popFont();
	}

	/** mm:ss above 60s, whole seconds 10-60s, one decimal below 10s. Empty when unknown. */
	public static function formatRemain(secs:Float):String {
		if (!Math.isFinite(secs) || secs < 0)
			return "";
		if (secs >= 60) {
			var m = Std.int(secs / 60);
			var s = Std.int(secs % 60);
			return m + ":" + (s < 10 ? "0" + s : Std.string(s));
		}
		if (secs >= 10)
			return Std.string(Math.ceil(secs - 0.001));
		return Std.string(Math.round(secs * 10) / 10);
	}

	/**
	 * Explicit toggle, or auto for any known remaining under the published ceiling.
	 *
	 * A visible status always earns a mark: non-expiring ones draw the infinity glyph
	 * rather than nothing, since anything past SkillRemain's hour-long leftover cap is
	 * permanent in practice. A user-set ceiling asks for short timers only, and an
	 * infinite span has no seconds to compare against it, so the ceiling suppresses the glyph.
	 */
	static function wantCountdown(a:AuraDef):Bool {
		if (faceInf) {
			if (a.showCountdown != null && a.showCountdown.get())
				return true;
			return countdownAll && countdownCeiling <= 0;
		}
		if (!(Math.isFinite(faceLeft) && faceLeft >= 0))
			return false;
		if (a.showCountdown != null && a.showCountdown.get())
			return true;
		if (!countdownAll)
			return false;
		return countdownCeiling <= 0 || faceLeft <= countdownCeiling;
	}

	/** A fuse is artwork only when one of its explicit display options is enabled. */
	static function wantFuse(a:AuraDef, progress:Float):Bool {
		return (a.showFuse != null && a.showFuse.get()) || (a.fuseBottom != null && a.fuseBottom.get());
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
			if (faceInf)
				t = "inf";
			else if (Math.isFinite(faceLeft) && faceLeft >= 0)
				t = Std.string(Math.max(0, Math.round(faceLeft * 10) / 10));
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
