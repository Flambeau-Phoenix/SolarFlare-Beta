package solarflare.ui;

import imgui.ImGui;

/**
 * Visual effects for windows, panels, and containers
 * (drop shadows, glass, gradients, glow lines).
 */
class WindowEffects {
	/**
	 * Soft multi-pass drop shadow behind a window rectangle.
	 */
	public static function dropShadow(dl:Dynamic, minX:Float, minY:Float, maxX:Float, maxY:Float, shadowSize:Float = 8.0, opacity:Float = 0.25):Void {
		var steps = 8;
		for (i in 0...steps) {
			var t = (i + 1) / steps;
			var alpha = Std.int(opacity * 255 * (1.0 - t) * 0.75);
			if (alpha <= 0) continue;
			var col = (alpha << 24) | 0x000000;
			var offset = shadowSize * t;
			var radius:Single = 4.0 + t * 4.0;

			ImGui.ImDrawList_AddRectFilled(dl,
				ImGui.vec2(minX - offset, minY - offset),
				ImGui.vec2(maxX + offset, maxY + offset),
				col, radius);
		}
	}

	/**
	 * Glowing neon border around a rectangle.
	 */
	public static function glowBorder(dl:Dynamic, minX:Float, minY:Float, maxX:Float, maxY:Float, color:Int, intensity:Float = 0.5, width:Float = 1.5, glowWidth:Float = 8.0):Void {
		for (i in 0...5) {
			var t = (i + 1) / 5;
			var alpha = Std.int(intensity * 255 * (1.0 - t) * 0.5);
			if (alpha <= 0) continue;
			var col = (color & 0x00FFFFFF) | (alpha << 24);
			var w = width + glowWidth * t;
			ImGui.ImDrawList_AddRect(dl,
				ImGui.vec2(minX - w * 0.5, minY - w * 0.5),
				ImGui.vec2(maxX + w * 0.5, maxY + w * 0.5),
				col, 6.0, w);
		}

		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(minX, minY), ImGui.vec2(maxX, maxY), color, 6.0, width);
	}

	/**
	 * Vertical gradient band (title bars / panel headers).
	 */
	public static function gradientHeader(dl:Dynamic, x:Float, y:Float, width:Float, height:Float, colorTop:Int, colorBottom:Int):Void {
		ImGui.ImDrawList_AddRectFilledMultiColor(dl,
			ImGui.vec2(x, y),
			ImGui.vec2(x + width, y + height),
			colorTop, colorTop, colorBottom, colorBottom);
	}

}
