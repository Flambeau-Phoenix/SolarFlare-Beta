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

	/**
	 * Soft radial spotlight behind icons or active elements.
	 */
	public static function spotlight(dl:Dynamic, cx:Float, cy:Float, radius:Float, color:Int, alpha:Float = 0.3):Void {
		for (i in 0...10) {
			var t = (i + 1) / 10;
			var a = Std.int(alpha * 255 * (1 - t) * 0.8);
			if (a <= 0) continue;
			var col = (color & 0x00FFFFFF) | (a << 24);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), radius * t, col, 16);
		}
	}

	/**
	 * Expanding glow underline under a title.
	 */
	public static function glowLine(dl:Dynamic, x:Float, y:Float, width:Float, color:Int, thickness:Float = 2.0):Void {
		var mid = x + width * 0.5;
		for (i in 0...6) {
			var t = (i + 1) / 6;
			var alpha = Std.int(0.7 * (1 - t) * 255);
			if (alpha <= 0) continue;
			var col = (color & 0x00FFFFFF) | (alpha << 24);
			var w = width * (0.15 + t * 0.85);
			ImGui.ImDrawList_AddLine(dl,
				ImGui.vec2(mid - w * 0.5, y),
				ImGui.vec2(mid + w * 0.5, y),
				col, thickness + t * 1.5);
		}
	}

	/**
	 * Decorative double rule.
	 */
	public static function doubleLine(dl:Dynamic, x:Float, y:Float, width:Float, color1:Int, color2:Int):Void {
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x, y), ImGui.vec2(x + width, y), color1, 1.5);
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x, y + 3), ImGui.vec2(x + width, y + 3), color2, 1.0);
	}

	/**
	 * Frosted glass panel with top shine + bottom reflection.
	 * Accepts either (min/max) or (x,y,w,h) via maxX/maxY as right/bottom edges.
	 */
	public static function glassPanel(dl:Dynamic, minX:Float, minY:Float, maxX:Float, maxY:Float, baseColor:Int, glassiness:Float = 0.3):Void {
		var w = maxX - minX;
		var h = maxY - minY;
		// Support (x,y,w,h) callers where maxX/maxY are width/height.
		if (w < 1 || h < 1) {
			w = maxX;
			h = maxY;
			maxX = minX + w;
			maxY = minY + h;
		}

		var baseAlpha = (baseColor >>> 24) & 0xFF;
		if (baseAlpha == 0) baseAlpha = 0x33;
		var fill = (baseColor & 0x00FFFFFF) | (Std.int(baseAlpha * Math.min(1, glassiness + 0.35)) << 24);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(minX, minY), ImGui.vec2(maxX, maxY), fill, 6.0);

		var shineH = Math.min(24.0, h * 0.35);
		var shineTop = ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0.18 * glassiness + 0.08));
		var shineBottom = ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0));
		ImGui.ImDrawList_AddRectFilledMultiColor(dl,
			ImGui.vec2(minX + 2, minY + 2),
			ImGui.vec2(maxX - 2, minY + shineH),
			shineTop, shineTop, shineBottom, shineBottom);

		var reflect = ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0.06));
		ImGui.ImDrawList_AddRectFilled(dl,
			ImGui.vec2(minX + 4, maxY - 12),
			ImGui.vec2(maxX - 4, maxY - 2),
			reflect, 4.0);
	}

	/**
	 * Convenience glass panel from x/y/w/h.
	 */
	public static function glassRect(dl:Dynamic, x:Float, y:Float, w:Float, h:Float, tintColor:Int, shineIntensity:Float = 0.4):Void {
		glassPanel(dl, x, y, x + w, y + h, tintColor, shineIntensity);
	}
}
