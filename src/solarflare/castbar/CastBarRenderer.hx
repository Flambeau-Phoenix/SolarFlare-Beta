package solarflare.castbar;

import solarflare.ui.EnhancedText;
import solarflare.ui.GameIcons;
import solarflare.ui.SkillIconRenderer;
import solarflare.ui.ThemePalette;
import solarflare.ui.ThemePalette.ThemeColors;
import solarflare.ui.UiCol;
import imgui.ImGui;
import imgui.Structs.ImVec4;

/**
 * One visual language for the large player cast bar and compact target row.
 *
 * Skins 0-2 are textured (castbar_* art with a vector fallback). Skins 3+ are pure vector:
 * chrome (track, border, ticks) follows ThemePalette, the fill keeps fixed game-art colours.
 * Append new skins only; saved profiles store the index.
 */
class CastBarRenderer {
	public static var SKIN_NAMES(default, null):Array<String> = [
		"Solar", "Obsidian", "Gilded",
		"Ember Rail", "Glass Prism", "Rune Arc", "Hairline", "Tide", "Shard"
	];
	/** Texture keys for the textured skins only (index < FIRST_VECTOR_SKIN). */
	public static var SKIN_KEYS(default, null):Array<String> = ["castbar_solar", "castbar_obsidian", "castbar_gilded"];

	static inline var FIRST_VECTOR_SKIN:Int = 3;
	static inline var SKIN_EMBER_RAIL:Int = 3;
	static inline var SKIN_GLASS_PRISM:Int = 4;
	static inline var SKIN_RUNE_ARC:Int = 5;
	static inline var SKIN_HAIRLINE:Int = 6;
	static inline var SKIN_TIDE:Int = 7;
	static inline var SKIN_SHARD:Int = 8;

	public static function drawPlayer(s:CastSnap, skin:Int, showIcon:Bool, showName:Bool,
			showTime:Bool, x:Single, y:Single, w:Single, h:Single):Void {
		var dl = ImGui.getWindowDrawList();
		var idx = clampSkin(skin);
		var iconGap:Single = showIcon ? 6 : 0;
		var iconSize:Single = showIcon ? h : 0;
		var bx:Single = x + iconSize + iconGap;
		var bw:Single = Math.max(1, w - iconSize - iconGap);

		if (showIcon)
			SkillIconRenderer.draw(dl, s.skillId, x, y, iconSize, true, true, 0);
		if (idx >= FIRST_VECTOR_SKIN) {
			drawVectorSkin(dl, s, idx, bx, y, bw, h, showName ? s.label : "", showTime ? formatTime(s.remaining) : "");
			return;
		}
		var insetX:Single = idx == 2 ? bw * 0.205 : bw * 0.105;
		var insetY:Single = h * (idx == 0 ? 0.20 : 0.22);
		var ix:Single = bx + insetX;
		var iy:Single = y + insetY;
		var iw:Single = Math.max(1, bw - insetX * 2);
		var ih:Single = Math.max(4, h - insetY * 2);

		if (!GameIcons.drawKey(dl, SKIN_KEYS[idx], bx, y, bw, h))
			drawFallbackFrame(dl, bx, y, bw, h, idx);
		drawFill(dl, ix, iy, iw, ih, s.progress, idx, 2);

		var label = showName ? s.label : "";
		var time = showTime ? formatTime(s.remaining) : "";
		drawCenteredLabels(dl, ix, iy, iw, ih, label, time);
	}

	public static function drawCompact(s:CastSnap, skin:Int, x:Single, y:Single, w:Single, h:Single):Void {
		var dl = ImGui.getWindowDrawList();
		var idx = clampSkin(skin);
		if (idx >= FIRST_VECTOR_SKIN) {
			drawVectorSkin(dl, s, idx, x, y, w, h, s.label, formatTime(s.remaining));
			return;
		}
		drawFallbackFrame(dl, x, y, w, h, idx);
		drawFill(dl, x + 2, y + 2, Math.max(1, w - 4), Math.max(2, h - 4), s.progress, idx, 2);
		drawCenteredLabels(dl, x + 4, y, Math.max(1, w - 8), h, s.label, formatTime(s.remaining));
	}

	/** Target strip: fixed unstyled palette. No skin textures / Solar-Obsidian-Gilded tint. */
	public static function drawPlainCompact(s:CastSnap, x:Single, y:Single, w:Single, h:Single):Void {
		var dl = ImGui.getWindowDrawList();
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), 0xCC12141A, 3);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), 0x66888888, 3, 1.5);
		var ix:Single = x + 2;
		var iy:Single = y + 2;
		var iw:Single = Math.max(1, w - 4);
		var ih:Single = Math.max(2, h - 4);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(ix, iy), ImGui.vec2(ix + iw, iy + ih), 0xD6121115, 2);
		var fw:Single = iw * (s.progress < 0 ? 0 : (s.progress > 1 ? 1 : s.progress));
		if (fw > 1) {
			var top = UiCol.rgb(0xE8C040);
			var bottom = UiCol.rgb(0xA67C20);
			ImGui.ImDrawList_AddRectFilledMultiColor(dl,
				ImGui.vec2(ix, iy), ImGui.vec2(ix + fw, iy + ih), top, top, bottom, bottom);
		}
		drawCenteredLabels(dl, x + 4, y, Math.max(1, w - 8), h, s.label, formatTime(s.remaining));
	}

	static function drawFill(dl:Dynamic, x:Single, y:Single, w:Single, h:Single,
			progress:Float, skin:Int, rounding:Single):Void {
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), 0xD6121115, rounding);
		var fw:Single = w * (progress < 0 ? 0 : (progress > 1 ? 1 : progress));
		if (fw > 1) {
			var top = skin == 0 ? UiCol.rgb(0xFFD36A) : (skin == 1 ? UiCol.rgb(0xBFC8D8) : UiCol.rgb(0xE8B84E));
			var bottom = skin == 0 ? UiCol.rgb(0xA64B16) : (skin == 1 ? UiCol.rgb(0x596474) : UiCol.rgb(0x8C5A20));
			ImGui.ImDrawList_AddRectFilledMultiColor(dl, ImGui.vec2(x, y), ImGui.vec2(x + fw, y + h), top, top, bottom, bottom);
		}
	}

	static function drawFallbackFrame(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, skin:Int):Void {
		var border = skin == 0 ? UiCol.rgb(0xC98235) : (skin == 1 ? UiCol.rgb(0x8992A0) : UiCol.rgb(0xB78A36));
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), 0xE0121318, 3);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), border, 3, 1.5);
	}

	static function drawCenteredLabels(dl:Dynamic, x:Single, y:Single, w:Single, h:Single,
			label:String, time:String):Void {
		var timeW:Single = time.length > 0 ? ImGui.calcTextSize(time).x : 0;
		if (time.length > 0)
			EnhancedText.shadowed(dl, ImGui.vec2(x + w - timeW, y + (h - ImGui.calcTextSize(time).y) * 0.5), time, 0xFFFFFFFF, 0xCC000000, 1, 1);
		if (label.length > 0) {
			var room:Single = Math.max(1, w - timeW - (timeW > 0 ? 10 : 0));
			var shown = fit(label, room);
			var ts = ImGui.calcTextSize(shown);
			EnhancedText.shadowed(dl, ImGui.vec2(x + (room - ts.x) * 0.5, y + (h - ts.y) * 0.5), shown, 0xFFFFFFFF, 0xCC000000, 1, 1);
		}
	}

	static function fit(value:String, width:Single):String {
		var text = value;
		if (ImGui.calcTextSize(text).x <= width) return text;
		while (text.length > 0 && ImGui.calcTextSize(text + "...").x > width)
			text = text.substr(0, text.length - 1);
		return text.length > 0 ? text + "..." : "";
	}

	static function formatTime(v:Float):String {
		if (!Math.isFinite(v) || v < 0) v = 0;
		return v >= 10 ? Std.string(Math.ceil(v)) + "s" : Std.string(Math.round(v * 10) / 10) + "s";
	}

	/** Unknown / out-of-range saved indices fall back to the first skin. */
	static inline function clampSkin(v:Int):Int return v < 0 || v >= SKIN_NAMES.length ? 0 : v;

	// ---- vector skins (index >= FIRST_VECTOR_SKIN) -------------------------------------------

	static function drawVectorSkin(dl:Dynamic, s:CastSnap, idx:Int, x:Single, y:Single, w:Single, h:Single,
			label:String, time:String):Void {
		var theme = ThemePalette.current();
		var p:Float = clamp01(s.progress);
		switch (idx) {
			case SKIN_EMBER_RAIL: drawEmberRail(dl, theme, p, x, y, w, h, label, time);
			case SKIN_GLASS_PRISM: drawGlassPrism(dl, theme, p, x, y, w, h, label, time);
			case SKIN_RUNE_ARC: drawRuneArc(dl, theme, p, x, y, w, h, label, time);
			case SKIN_HAIRLINE: drawHairline(dl, theme, p, x, y, w, h, label, time);
			case SKIN_TIDE: drawTide(dl, theme, p, x, y, w, h, label, time);
			default: drawShard(dl, theme, p, x, y, w, h, label, time);
		}
	}

	/** Segmented rail: lit cells heat from red to amber, the head cell glows. Needs ~11 px per cell. */
	static function drawEmberRail(dl:Dynamic, theme:ThemeColors, p:Float, x:Single, y:Single, w:Single, h:Single,
			label:String, time:String):Void {
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), themeCol(theme.windowBg, 0.30, 228), 3);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), themeCol(theme.border, 1, 235), 3, 1.5);
		var pad:Single = Math.max(3, h * 0.16);
		var ix:Single = x + pad;
		var iy:Single = y + pad;
		var iw:Single = Math.max(8, w - pad * 2);
		var ih:Single = Math.max(4, h - pad * 2);
		var cells = clampInt(Std.int(iw / 11), 8, 40);
		var gap:Single = 2;
		var cw:Single = (iw - gap * (cells - 1)) / cells;
		var lit:Float = p * cells;
		var unlit = themeCol(theme.border, 0.30, 150);
		for (i in 0...cells) {
			var cx:Single = ix + i * (cw + gap);
			var f:Float = clamp01(lit - i);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cx, iy), ImGui.vec2(cx + cw, iy + ih), unlit, 1);
			if (f <= 0)
				continue;
			var t:Float = i / (cells - 1);
			var top = lerpCol(UiCol.rgb(0xE0561A), UiCol.rgb(0xFFC04A), t);
			var bottom = lerpCol(UiCol.rgb(0x7A1E0A), UiCol.rgb(0xD2561A), t);
			var head = f < 1 || i == cells - 1 || lit < i + 1.001;
			if (head)
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cx - 2, iy - 2), ImGui.vec2(cx + cw * f + 2, iy + ih + 2), UiCol.rgb(0xFFA030, 70), 2);
			ImGui.ImDrawList_AddRectFilledMultiColor(dl, ImGui.vec2(cx, iy), ImGui.vec2(cx + cw * f, iy + ih), top, top, bottom, bottom);
			if (head)
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(cx, iy), ImGui.vec2(cx + cw * f, iy + Math.max(1, ih * 0.28)), UiCol.rgb(0xFFF0B0, 150), 1);
		}
		drawCenteredLabels(dl, ix + 2, y, iw - 4, h, label, time);
	}

	/** Translucent glass: alpha ramps up towards a bright leading edge with a soft gloss. Fine at any size. */
	static function drawGlassPrism(dl:Dynamic, theme:ThemeColors, p:Float, x:Single, y:Single, w:Single, h:Single,
			label:String, time:String):Void {
		var rounding:Single = Math.min(8, h * 0.28);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), themeCol(theme.windowBg, 0.40, 128), rounding);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), themeCol(theme.border, 1, 205), rounding, 1);
		var pad:Single = Math.max(2, rounding * 0.7);
		var ix:Single = x + pad;
		var iy:Single = y + pad;
		var iw:Single = Math.max(4, w - pad * 2);
		var ih:Single = Math.max(4, h - pad * 2);
		var fw:Single = iw * p;
		if (fw > 1) {
			var fx:Single = ix + fw;
			ImGui.ImDrawList_AddRectFilledMultiColor(dl, ImGui.vec2(ix, iy), ImGui.vec2(fx, iy + ih),
				UiCol.rgb(0x9BE8FF, 36), UiCol.rgb(0xDDF8FF, 175), UiCol.rgb(0x4FB4E6, 150), UiCol.rgb(0x3A8FD0, 56));
			ImGui.ImDrawList_AddRectFilledMultiColor(dl, ImGui.vec2(ix, iy), ImGui.vec2(fx, iy + ih * 0.5),
				UiCol.rgb(0xFFFFFF, 52), UiCol.rgb(0xFFFFFF, 70), UiCol.rgb(0xFFFFFF, 0), UiCol.rgb(0xFFFFFF, 0));
			var streakX:Single = Math.max(ix, fx - ih * 0.9);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(streakX, iy + ih), ImGui.vec2(Math.min(fx, streakX + ih * 0.7), iy), UiCol.rgb(0xFFFFFF, 34), 3);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(fx, iy), ImGui.vec2(fx, iy + ih), UiCol.rgb(0xBFF0FF, 60), 6);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(fx, iy), ImGui.vec2(fx, iy + ih), UiCol.rgb(0xFFFFFF, 240), 2);
		}
		drawCenteredLabels(dl, ix + 4, y, iw - 8, h, label, time);
	}

	/**
	 * Curved bar: a shallow bowl-shaped arc stroked with PathArcTo. Fill runs left to right along
	 * the arc, a glowing orb marks the head, runic ticks divide it in eighths. Needs h >= 34 (bar >= 160 px wide).
	 */
	static function drawRuneArc(dl:Dynamic, theme:ThemeColors, p:Float, x:Single, y:Single, w:Single, h:Single,
			label:String, time:String):Void {
		var thick:Single = Math.max(10, Math.min(34, h * 0.60));
		var padX:Single = thick * 0.2 + 3;
		var span:Single = Math.max(60, w - padX * 2);
		var sag:Single = Math.max(3, Math.min(Math.min(h * 0.22, 26), span * 0.10));
		var y0:Single = y + (h - (sag + thick)) * 0.5;
		var yBot:Single = y0 + thick * 0.5 + sag;
		var r:Single = (span * span * 0.25 + sag * sag) / (2 * sag);
		var th:Float = Math.asin(Math.min(1, span * 0.5 / r));
		var ccx:Single = x + w * 0.5;
		var ccy:Single = yBot - r;
		var aL:Float = Math.PI * 0.5 + th;
		var aR:Float = Math.PI * 0.5 - th;
		var segs = clampInt(Std.int(th * 2 * r / 6) + 2, 6, 64);
		var center = ImGui.vec2(ccx, ccy);

		ImGui.ImDrawList_PathArcTo(dl, center, r, aR, aL, segs);
		ImGui.ImDrawList_PathStroke(dl, themeCol(theme.border, 1, 235), thick + 3);
		ImGui.ImDrawList_PathArcTo(dl, center, r, aR, aL, segs);
		ImGui.ImDrawList_PathStroke(dl, themeCol(theme.windowBg, 0.30, 235), thick);

		var head:Float = aL - 2 * th * p;
		if (p > 0.004) {
			var fsegs = clampInt(Std.int(th * 2 * r * p / 6) + 2, 2, 64);
			ImGui.ImDrawList_PathArcTo(dl, center, r, head, aL, fsegs);
			ImGui.ImDrawList_PathStroke(dl, UiCol.rgb(0x7B4DFF), thick - 3);
			ImGui.ImDrawList_PathArcTo(dl, center, r, head, aL, fsegs);
			ImGui.ImDrawList_PathStroke(dl, UiCol.rgb(0xC9B4FF, 190), Math.max(2, (thick - 3) * 0.38));
		}
		var tick = themeCol(theme.border, 1, 190);
		for (i in 1...8) {
			var a:Float = aL - 2 * th * (i / 8);
			var ca = Math.cos(a);
			var sa = Math.sin(a);
			ImGui.ImDrawList_AddLine(dl,
				ImGui.vec2(ccx + ca * (r - thick * 0.5), ccy + sa * (r - thick * 0.5)),
				ImGui.vec2(ccx + ca * (r + thick * 0.5), ccy + sa * (r + thick * 0.5)), tick, 1);
		}
		if (p > 0.004 && p < 0.999) {
			var hx:Single = ccx + Math.cos(head) * r;
			var hy:Single = ccy + Math.sin(head) * r;
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(hx, hy), thick * 0.85, UiCol.rgb(0xB59CFF, 70), 16);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(hx, hy), thick * 0.38, UiCol.rgb(0xFFFFFF, 245), 12);
		}

		// Labels ride the arc: the name sits on the lowest point, the time follows the arc height at its x.
		var timeW:Single = time.length > 0 ? ImGui.calcTextSize(time).x : 0;
		var edge:Single = thick * 0.5 + 6;
		if (time.length > 0) {
			var tx:Single = ccx + span * 0.5 - edge - timeW;
			var dx:Float = tx + timeW * 0.5 - ccx;
			var ty:Float = ccy + Math.sqrt(Math.max(0, r * r - dx * dx));
			EnhancedText.shadowed(dl, ImGui.vec2(tx, ty - ImGui.calcTextSize(time).y * 0.5), time, 0xFFFFFFFF, 0xCC000000, 1, 1);
		}
		if (label.length > 0) {
			var room:Single = Math.max(1, span - (edge + timeW + 8) * 2);
			var shown = fit(label, room);
			var ts = ImGui.calcTextSize(shown);
			EnhancedText.shadowed(dl, ImGui.vec2(ccx - ts.x * 0.5, yBot - ts.y * 0.5), shown, 0xFFFFFFFF, 0xCC000000, 1, 1);
		}
	}

	/** Thin line with the text above it (name left, time right); fill uses the theme accent. Needs h >= 30. */
	static function drawHairline(dl:Dynamic, theme:ThemeColors, p:Float, x:Single, y:Single, w:Single, h:Single,
			label:String, time:String):Void {
		var lineH:Single = Math.max(2, Math.min(5, h * 0.10));
		var ly:Single = y + h - lineH * 0.5 - 2;
		var l0:Single = ly - lineH * 0.5;
		var l1:Single = ly + lineH * 0.5;
		var ix:Single = x + 2;
		var iw:Single = Math.max(4, w - 4);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(ix, l0), ImGui.vec2(ix + iw, l1), themeCol(theme.border, 0.45, 175), lineH * 0.5);
		var accent = themeCol(theme.accent, 1, 255);
		var fw:Single = iw * p;
		if (fw > 1) {
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(ix, l0 - 1.5), ImGui.vec2(ix + fw, l1 + 1.5), themeCol(theme.accent, 1, 60), lineH);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(ix, l0), ImGui.vec2(ix + fw, l1), accent, lineH * 0.5);
		}
		var tick = themeCol(theme.border, 1, 170);
		for (i in 1...4) {
			var tx:Single = ix + iw * (i / 4);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(tx, l0 - 2), ImGui.vec2(tx, l1 + 2), tick, 1);
		}
		if (fw > 1 && p < 0.999) {
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(ix + fw, ly), lineH * 2.2, themeCol(theme.accent, 1, 70), 14);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(ix + fw, ly), lineH * 0.95 + 0.5, 0xFFFFFFFF, 10);
		}
		var band:Single = Math.max(8, l0 - 2 - y);
		if (time.length > 0) {
			var tw = ImGui.calcTextSize(time);
			EnhancedText.shadowed(dl, ImGui.vec2(ix + iw - tw.x, y + (band - tw.y) * 0.5), time, 0xFFFFFFFF, 0xCC000000, 1, 1);
		}
		if (label.length > 0) {
			var timeW:Single = time.length > 0 ? ImGui.calcTextSize(time).x + 10 : 0;
			var shown = fit(label, Math.max(1, iw - timeW));
			var ts = ImGui.calcTextSize(shown);
			EnhancedText.shadowed(dl, ImGui.vec2(ix, y + (band - ts.y) * 0.5), shown, 0xFFFFFFFF, 0xCC000000, 1, 1);
		}
	}

	/**
	 * Rolling water: the fill's leading edge is a travelling wave (a lighter back wave trails ahead of it).
	 * Phase advances with ImGui time plus cast progress so a frozen preview still moves. Needs h >= 30.
	 */
	static function drawTide(dl:Dynamic, theme:ThemeColors, p:Float, x:Single, y:Single, w:Single, h:Single,
			label:String, time:String):Void {
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), themeCol(theme.windowBg, 0.32, 228), 3);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), themeCol(theme.border, 1, 235), 3, 1.5);
		var pad:Single = Math.max(3, h * 0.13);
		var ix:Single = x + pad;
		var iy:Single = y + pad;
		var iw:Single = Math.max(8, w - pad * 2);
		var ih:Single = Math.max(4, h - pad * 2);
		var fw:Single = iw * p;
		if (fw > 1) {
			var n = clampInt(Std.int(ih / 2), 6, 28);
			var sh:Single = ih / n;
			var amp:Float = Math.min(Math.min(ih * 0.16, 3.5), Math.min(fw * 0.5, (iw - fw) * 0.5));
			var phase:Float = ImGui.getTime() * 3.0 + p * 10;
			var topC = UiCol.rgb(0x7BEFF0);
			var botC = UiCol.rgb(0x14788F);
			for (j in 0...n) {
				var yy:Single = iy + j * sh;
				var back:Float = fw + amp * 1.3 * Math.sin(phase * 0.7 + 2 + j * 0.6) + amp * 1.2;
				back = back < 0 ? 0 : (back > iw ? iw : back);
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(ix, yy), ImGui.vec2(ix + back, yy + sh + 0.5), UiCol.rgb(0x58D8E8, 70));
			}
			for (j in 0...n) {
				var yy:Single = iy + j * sh;
				var edge:Float = fw + amp * Math.sin(phase + j * 0.9);
				edge = edge < 1 ? 1 : (edge > iw ? iw : edge);
				var col = lerpCol(topC, botC, (j + 0.5) / n);
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(ix, yy), ImGui.vec2(ix + edge, yy + sh + 0.5), col);
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(ix + Math.max(0, edge - 2), yy), ImGui.vec2(ix + edge, yy + sh + 0.5), UiCol.rgb(0xFFFFFF, 130));
			}
		}
		drawCenteredLabels(dl, ix + 3, y, iw - 6, h, label, time);
	}

	/** Slanted parallelogram frame and fill with a bright cut at the leading edge. Slant is capped at 14 px. */
	static function drawShard(dl:Dynamic, theme:ThemeColors, p:Float, x:Single, y:Single, w:Single, h:Single,
			label:String, time:String):Void {
		var k:Single = Math.min(h * 0.42, 14);
		ImGui.ImDrawList_AddQuadFilled(dl, ImGui.vec2(x + k, y), ImGui.vec2(x + w, y), ImGui.vec2(x + w - k, y + h), ImGui.vec2(x, y + h),
			themeCol(theme.windowBg, 0.34, 228));
		ImGui.ImDrawList_AddQuad(dl, ImGui.vec2(x + k, y), ImGui.vec2(x + w, y), ImGui.vec2(x + w - k, y + h), ImGui.vec2(x, y + h),
			themeCol(theme.border, 1, 240), 1.5);
		var pad:Single = 3;
		var ix:Single = x + pad;
		var iy:Single = y + pad;
		var ih:Single = Math.max(4, h - pad * 2);
		var iw:Single = Math.max(8, w - pad * 2);
		var kk:Single = k * ih / h;
		var u:Single = Math.max(0, (iw - kk) * p);
		if (u > 1) {
			var bands = 4;
			var top = UiCol.rgb(0xFF86A4);
			var bottom = UiCol.rgb(0xB3123F);
			for (b in 0...bands) {
				var ya:Single = iy + ih * b / bands;
				var yb:Single = iy + ih * (b + 1) / bands;
				var la:Single = ix + kk * (1 - (ya - iy) / ih);
				var lb:Single = ix + kk * (1 - (yb - iy) / ih);
				ImGui.ImDrawList_AddQuadFilled(dl, ImGui.vec2(la, ya), ImGui.vec2(la + u, ya), ImGui.vec2(lb + u, yb), ImGui.vec2(lb, yb),
					lerpCol(top, bottom, (b + 0.5) / bands));
			}
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(ix + kk + u, iy), ImGui.vec2(ix + u, iy + ih), UiCol.rgb(0xFFD0DC, 70), 6);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(ix + kk + u, iy), ImGui.vec2(ix + u, iy + ih), UiCol.rgb(0xFFFFFF, 245), 2);
		}
		drawCenteredLabels(dl, x + k + 2, y, Math.max(1, w - k * 2 - 4), h, label, time);
	}

	// ---- colour / math helpers ---------------------------------------------------------------

	static inline function clamp01(v:Float):Float return v < 0 || v != v ? 0 : (v > 1 ? 1 : v);

	static inline function clampInt(v:Int, lo:Int, hi:Int):Int return v < lo ? lo : (v > hi ? hi : v);

	static inline function c8(v:Float):Int return v <= 0 ? 0 : (v >= 1 ? 255 : Std.int(v * 255));

	/** Theme colour scaled by `mul` (darken chrome so white text stays legible on light custom themes). */
	static inline function themeCol(c:ImVec4, mul:Float, a:Int):Int
		return UiCol.rgba(c8(c.x * mul), c8(c.y * mul), c8(c.z * mul), a);

	/** Per-channel lerp of two packed ImGui U32 colours. */
	static function lerpCol(a:Int, b:Int, t:Float):Int {
		var ar = a & 0xFF;
		var ag = (a >> 8) & 0xFF;
		var ab = (a >> 16) & 0xFF;
		var aa = (a >>> 24) & 0xFF;
		return UiCol.rgba(Std.int(ar + ((b & 0xFF) - ar) * t), Std.int(ag + (((b >> 8) & 0xFF) - ag) * t),
			Std.int(ab + (((b >> 16) & 0xFF) - ab) * t), Std.int(aa + (((b >>> 24) & 0xFF) - aa) * t));
	}
}
