package solarflare.ui;

import imgui.ImGui;
import imgui.Structs.ImVec2;

/**
 * High-performance vector glows, blooming outlines, and ripple effects
 * rendered directly onto Dear ImGui's ImDrawList.
 */
class VectorGlow {
	/**
	 * Draw a smooth radial bloom glow around a point or icon center.
	 */
	public static function radial(dl:Dynamic, cx:Single, cy:Single, radius:Single, color:Int, intensity:Single = 0.6, samples:Int = 8):Void {
		var a = (color >> 24) & 0xFF;
		var rgb = color & 0x00FFFFFF;
		if (a == 0) a = 0xFF;

		for (i in 0...samples) {
			var t = (i + 1) / samples;
			var r = radius * (0.3 + t * 0.7);
			var alpha = Std.int(a * (1.0 - t * t) * intensity);
			if (alpha <= 0) continue;
			var col = rgb | (alpha << 24);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), r, col, 16);
		}
	}

	/**
	 * Draw a soft rounded rect glow outline.
	 */
	public static function rect(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, color:Int, rounding:Single = 4.0, thickness:Single = 2.0):Void {
		var a = (color >> 24) & 0xFF;
		var rgb = color & 0x00FFFFFF;
		if (a == 0) a = 0xFF;

		// Outer soft pass
		var outerCol = rgb | (Std.int(a * 0.35) << 24);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x - 2, y - 2), ImGui.vec2(x + w + 2, y + h + 2), outerCol, rounding + 2.0, thickness + 2.0, 0);

		// Core crisp pass
		var coreCol = rgb | (a << 24);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), coreCol, rounding, thickness, 0);
	}

	/**
	 * Draw text with a multi-directional shadow/glow for high legibility on 3D backgrounds.
	 */
	public static function textWithGlow(dl:Dynamic, x:Single, y:Single, text:String, color:Int, glowColor:Int = 0xCC000000):Void {
		var p = ImGui.vec2(x, y);
		// 4-point shadow pass
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x - 1, y), glowColor, text);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + 1, y), glowColor, text);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x, y - 1), glowColor, text);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x, y + 1), glowColor, text);
		// Main text pass
		ImGui.ImDrawList_AddText_Vec2(dl, p, color, text);
	}
}
