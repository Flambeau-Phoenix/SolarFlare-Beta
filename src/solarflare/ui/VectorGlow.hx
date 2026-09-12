package solarflare.ui;

import imgui.ImGui;

/**
 * High-performance vector glows, blooming outlines, and ripple effects
 * rendered directly onto Dear ImGui's ImDrawList.
 */
class VectorGlow {
	/** Scratch for perimeter sparks — draw-path only, no per-spark alloc. */
	static var _px:Single = 0;
	static var _py:Single = 0;
	static var _nx:Single = 0;
	static var _ny:Single = 0;

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
	 * Blizzard-style Spell Activation Overlay: soft gold bloom, bright core border, perimeter sparks.
	 * @param coreRgb 0xRRGGBB (alpha ignored / computed from pulse)
	 * @param bloomRgb 0xRRGGBB outer amber bloom
	 */
	public static function procOverlay(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, time:Float,
			coreRgb:Int = 0xFFF6A0, bloomRgb:Int = 0xFFB000):Void {
		if (dl == null || w < 1 || h < 1)
			return;
		var core = coreRgb & 0x00FFFFFF;
		var bloom = bloomRgb & 0x00FFFFFF;
		var pad:Single = 4.0;
		var x0:Single = x - pad;
		var y0:Single = y - pad;
		var x1:Single = x + w + pad;
		var y1:Single = y + h + pad;
		var rounding:Single = 4.0;
		var pulse = 0.875 + 0.125 * Math.sin(time * 6.0);

		// 1. Soft outer bloom (layered alpha falloff)
		var bloomAlpha = Std.int(0x44 * pulse);
		if (bloomAlpha < 1)
			bloomAlpha = 1;
		var bloomColor = (bloomAlpha << 24) | bloom;
		var i = 0;
		while (i < 3) {
			var expand:Single = (i + 1) * 2.0;
			ImGui.ImDrawList_AddRect(dl,
				ImGui.vec2(x0 - expand, y0 - expand),
				ImGui.vec2(x1 + expand, y1 + expand),
				bloomColor, rounding + expand, 2.0, 0);
			i++;
		}

		// 2. High-intensity core border
		var coreAlpha = Std.int(0xEE * pulse);
		if (coreAlpha < 1)
			coreAlpha = 1;
		var coreColor = (coreAlpha << 24) | core;
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x0, y0), ImGui.vec2(x1, y1), coreColor, rounding, 2.5, 0);

		// 3. Animated perimeter spark teeth
		var pw:Single = x1 - x0;
		var ph:Single = y1 - y0;
		var perimeter = 2.0 * (pw + ph);
		if (perimeter < 1)
			return;
		var sparkCount = 10;
		var speed = 40.0;
		var step = perimeter / sparkCount;
		var baseOffset = (time * speed) % step;
		var flareA = Std.int(0xE6 * pulse);
		if (flareA < 1)
			flareA = 1;
		var flareColor = (flareA << 24) | 0x00FFF8D9;
		var s = 0;
		while (s < sparkCount) {
			var dist = (baseOffset + s * step) % perimeter;
			writePerimeterPoint(dist, x0, y0, x1, y1);
			var p1 = ImGui.vec2(_px, _py);
			var p2 = ImGui.vec2(_px + _nx * 5.0, _py + _ny * 5.0);
			ImGui.ImDrawList_AddLine(dl, p1, p2, flareColor, 2.5);
			s++;
		}
	}

	/** Distance along rect perimeter → point + outward normal into static scratch. */
	static function writePerimeterPoint(dist:Float, x0:Single, y0:Single, x1:Single, y1:Single):Void {
		var w:Single = x1 - x0;
		var h:Single = y1 - y0;
		var d:Single = dist;
		if (d < 0)
			d = 0;
		// Top edge → right
		if (d < w) {
			_px = x0 + d;
			_py = y0;
			_nx = 0;
			_ny = -1;
			return;
		}
		d -= w;
		// Right edge → down
		if (d < h) {
			_px = x1;
			_py = y0 + d;
			_nx = 1;
			_ny = 0;
			return;
		}
		d -= h;
		// Bottom edge → left
		if (d < w) {
			_px = x1 - d;
			_py = y1;
			_nx = 0;
			_ny = 1;
			return;
		}
		d -= w;
		// Left edge → up
		_px = x0;
		_py = y1 - d;
		_nx = -1;
		_ny = 0;
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
