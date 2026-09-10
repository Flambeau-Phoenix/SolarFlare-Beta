package solarflare.ui;

import imgui.ImGui;
import imgui.Structs.ImVec2;

/**
 * Drop-shadows, beveled containers, and card panels for Solar Flare windows.
 */
class EnhancedBorders {
	public static function shadow(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, offX:Single = 3.0, offY:Single = 3.0, radius:Single = 8.0, alpha:Float = 0.18):Void {
		var col = (Std.int(alpha * 255) << 24);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + offX, y + offY), ImGui.vec2(x + w + offX, y + h + offY), col, radius);
	}

	public static function card(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, fillColor:Int, borderColor:Int, rounding:Single = 6.0, borderW:Single = 1.0):Void {
		// Shadow pass
		shadow(dl, x, y, w, h, 2.0, 2.0, rounding, 0.15);
		// Fill pass
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), fillColor, rounding);
		// Border pass
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), borderColor, rounding, borderW, 0);
	}
}
