package solarflare.castbar;

import solarflare.ui.EnhancedText;
import solarflare.ui.GameIcons;
import solarflare.ui.SkillIconRenderer;
import solarflare.ui.UiCol;
import imgui.ImGui;

/** One visual language for the large player cast bar and compact target row. */
class CastBarRenderer {
	public static var SKIN_NAMES(default, null):Array<String> = ["Solar", "Obsidian", "Gilded"];
	public static var SKIN_KEYS(default, null):Array<String> = ["castbar_solar", "castbar_obsidian", "castbar_gilded"];

	public static function drawPlayer(s:CastSnap, skin:Int, showIcon:Bool, showName:Bool,
			showTime:Bool, x:Single, y:Single, w:Single, h:Single):Void {
		var dl = ImGui.getWindowDrawList();
		var idx = clampSkin(skin);
		var iconGap:Single = showIcon ? 6 : 0;
		var iconSize:Single = showIcon ? h : 0;
		var bx:Single = x + iconSize + iconGap;
		var bw:Single = Math.max(1, w - iconSize - iconGap);
		var insetX:Single = idx == 2 ? bw * 0.205 : bw * 0.105;
		var insetY:Single = h * (idx == 0 ? 0.20 : 0.22);
		var ix:Single = bx + insetX;
		var iy:Single = y + insetY;
		var iw:Single = Math.max(1, bw - insetX * 2);
		var ih:Single = Math.max(4, h - insetY * 2);

		if (showIcon)
			SkillIconRenderer.draw(dl, s.skillId, x, y, iconSize, true, true, 0);
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

	static inline function clampSkin(v:Int):Int return v < 0 ? 0 : (v >= SKIN_KEYS.length ? SKIN_KEYS.length - 1 : v);
}
