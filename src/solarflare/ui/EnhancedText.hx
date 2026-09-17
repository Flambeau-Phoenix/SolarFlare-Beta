package solarflare.ui;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import solarflare.ui.UiCol;

/**
 * Enhanced text rendering helpers (drop shadow, outline, glow, extrusion).
 * Prefer stroked/shadowed for section titles; glowStroke only on main window titles.
 */
class EnhancedText {
	public static function shadowed(dl:Dynamic, pos:ImVec2, text:String, color:Int, shadowColor:Int = 0x88000000, offsetX:Float = 1.0, offsetY:Float = 1.0):Void {
		if (text == null || text.length == 0) return;
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(pos.x + offsetX, pos.y + offsetY), shadowColor, text);
		ImGui.ImDrawList_AddText_Vec2(dl, pos, color, text);
	}

	public static function glow(dl:Dynamic, pos:ImVec2, text:String, color:Int, glowColor:Int = 0, glowRadius:Float = 2.0):Void {
		if (text == null || text.length == 0) return;
		if (glowColor == 0)
			glowColor = UiCol.rgb(0xFFAA00, 0x55);
		for (dx in [-glowRadius, 0.0, glowRadius]) {
			for (dy in [-glowRadius, 0.0, glowRadius]) {
				if (dx == 0.0 && dy == 0.0) continue;
				ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(pos.x + dx, pos.y + dy), glowColor, text);
			}
		}
		ImGui.ImDrawList_AddText_Vec2(dl, pos, color, text);
	}

	/** 8-direction stroke outline. Use for titles / key labels only. */
	public static function stroked(dl:Dynamic, pos:ImVec2, text:String, textColor:Int, strokeColor:Int, thickness:Float = 1.0):Void {
		if (text == null || text.length == 0) return;
		var steps = 8;
		for (i in 0...steps) {
			var angle = (i / steps) * Math.PI * 2;
			var dx = Math.cos(angle) * thickness;
			var dy = Math.sin(angle) * thickness;
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(pos.x + dx, pos.y + dy), strokeColor, text);
		}
		ImGui.ImDrawList_AddText_Vec2(dl, pos, textColor, text);
	}

	/** Soft outer glow + fill. Heavier — main window titles only. */
	public static function glowStroke(dl:Dynamic, pos:ImVec2, text:String, textColor:Int, glowColor:Int, radius:Float = 3.0):Void {
		if (text == null || text.length == 0) return;
		for (i in 0...6) {
			var t = (i + 1) / 6;
			var alpha = Std.int(0.35 * (1 - t) * 255);
			if (alpha <= 0) continue;
			var col = (glowColor & 0x00FFFFFF) | (alpha << 24);
			var r = radius * t;
			for (j in 0...8) {
				var angle = (j / 8) * Math.PI * 2;
				ImGui.ImDrawList_AddText_Vec2(dl,
					ImGui.vec2(pos.x + Math.cos(angle) * r, pos.y + Math.sin(angle) * r), col, text);
			}
		}
		ImGui.ImDrawList_AddText_Vec2(dl, pos, textColor, text);
	}

	/** Stacked offset shadow for a light 3D extrusion. */
	public static function extruded(dl:Dynamic, pos:ImVec2, text:String, textColor:Int, shadowColor:Int, depth:Float = 3):Void {
		if (text == null || text.length == 0) return;
		var n = Std.int(depth);
		if (n < 1) n = 1;
		for (i in 0...n) {
			var a = Std.int(((shadowColor >>> 24) & 0xFF) * (1.0 - i / (n + 1)));
			var col = (shadowColor & 0x00FFFFFF) | (a << 24);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(pos.x + i, pos.y + i), col, text);
		}
		ImGui.ImDrawList_AddText_Vec2(dl, pos, textColor, text);
	}
}
