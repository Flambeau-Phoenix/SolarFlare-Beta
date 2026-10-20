package solarflare.resourcetracker;

import imgui.ImGui;
import solarflare.ui.GameIcons;
import solarflare.ui.UiCol;

/**
 * Shared prayer icon row: the live HUD and the builder preview both draw through here, so they
 * match. Reads frozen booleans only; never touches PrayerCache.
 */
class PrayerRenderer {
	static final KINDS = ["smite", "life", "shield"];

	/** Total width and height the row will occupy for this look. */
	public static function rowWidth(look:PrayerLook, vertical:Bool):Single {
		var s:Single = look.size.get();
		var g:Single = look.gap.get();
		return vertical ? s : s * 3 + g * 2;
	}

	public static function rowHeight(look:PrayerLook, vertical:Bool):Single {
		var s:Single = look.size.get();
		var g:Single = look.gap.get();
		return vertical ? s * 3 + g * 2 : s;
	}

	/** Draws at the ImGui cursor and advances it by a dummy, like the other vitals helpers. */
	public static function draw(look:PrayerLook, skin:ResourceSkin, smite:Bool, life:Bool, shield:Bool, rowSpan:Single,
			vertical:Bool):Void {
		var size:Single = look.size.get();
		var gap:Single = look.gap.get();
		var origin = ImGui.getCursorScreenPos();
		var total:Single = size * 3 + gap * 2;
		var startX:Single = origin.x;
		if (!vertical && rowSpan > total)
			startX = origin.x + (rowSpan - total) * 0.5;
		for (i in 0...3) {
			var ready = i == 0 ? smite : (i == 1 ? life : shield);
			var x:Single = vertical ? origin.x : startX + (size + gap) * i;
			var y:Single = vertical ? origin.y + (size + gap) * i : origin.y;
			drawIcon(look, skin, i, x, y, size, ready);
		}
		if (vertical)
			ImGui.dummy(ImGui.vec2(size, total));
		else
			ImGui.dummy(ImGui.vec2(rowSpan > 1 ? rowSpan : total, size));
	}

	static function drawIcon(look:PrayerLook, skin:ResourceSkin, index:Int, x:Single, y:Single, size:Single, ready:Bool):Void {
		var dl = ImGui.getWindowDrawList();
		var alpha:Float = ready ? 1 : look.dimAlpha.get();
		var c = look.colorFor(index);
		var base = ImGui.colorConvertFloat4ToU32(ImGui.vec4(c.getF32(0), c.getF32(4), c.getF32(8), c.getF32(12)));
		var drawn = skin != null && skin.drawSlot(dl, index, x, y, size, size, alpha);
		if (!drawn) {
			var tint = ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, alpha));
			drawn = GameIcons.draw(dl, GameIcons.get(GameIcons.prayerId(KINDS[index])), x, y, size, tint);
		}
		if (!drawn) {
			var fill = ready ? UiCol.withAlpha(UiCol.darken(base, 0.45), 0xFF) : UiCol.rgba(41, 43, 48, 0xD9);
			shape(dl, look.shape.get(), x, y, size, fill, true, 0);
		}
		if (look.readyRing.get() && ready) {
			shape(dl, look.shape.get(), x - 1, y - 1, size + 2, UiCol.withAlpha(base, 0x40), false, 5);
			shape(dl, look.shape.get(), x, y, size, UiCol.withAlpha(base, 0xE0), false, 2);
		}
		if (look.border.get())
			shape(dl, look.shape.get(), x, y, size, UiCol.withAlpha(base, ready ? 0xE0 : 0x60), false, 1.2);
	}

	/** Filled or outlined shape inside the icon square. */
	static function shape(dl:Dynamic, kind:Int, x:Single, y:Single, s:Single, col:Int, filled:Bool, thickness:Single):Void {
		var cx:Single = x + s * 0.5;
		var cy:Single = y + s * 0.5;
		switch (kind) {
			case 1:
				if (filled)
					ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), s * 0.5, col, 28);
				else
					ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), s * 0.5, col, 28, thickness);
			case 2:
				if (filled)
					ImGui.ImDrawList_AddNgonFilled(dl, ImGui.vec2(cx, cy), s * 0.58, col, 4);
				else
					ImGui.ImDrawList_AddNgon(dl, ImGui.vec2(cx, cy), s * 0.58, col, 4, thickness);
			case 3:
				if (filled)
					ImGui.ImDrawList_AddNgonFilled(dl, ImGui.vec2(cx, cy), s * 0.52, col, 6);
				else
					ImGui.ImDrawList_AddNgon(dl, ImGui.vec2(cx, cy), s * 0.52, col, 6, thickness);
			default:
				if (filled)
					ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + s, y + s), col, 6);
				else
					ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + s, y + s), col, 6, thickness);
		}
	}
}
