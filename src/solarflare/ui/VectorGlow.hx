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
	 * Thin/subtle only — wide blooms use `skillAlertBloom` (exp decay layers).
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
	 * Wide neon skill-ready bloom: multi-layer rects expand outward with exponential
	 * alpha falloff. Pulsates via ImGui.getTime(). Prefer over `rect` when glow must
	 * travel ~20–50px without blocky FringeScale rings.
	 *
	 * @param glowColor ABGR/ImU32 packed color (alpha = base intensity)
	 * @param maxGlowDistance outward travel in px at pulse peak
	 * @param layers 8–16; drop toward 8 if many skills light up at once
	 * @param power  exponential decay (2.5 = neon; ~1.8 with fewer layers)
	 */
	public static function skillAlertBloom(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, glowColor:Int,
			maxGlowDistance:Single = 40.0, rounding:Single = 4.0, layers:Int = 14, power:Single = 2.2):Void {
		if (dl == null || w < 1 || h < 1 || maxGlowDistance <= 0)
			return;
		if (layers < 4)
			layers = 4;
		if (layers > 16)
			layers = 16;

		var col = ImGui.colorConvertU32ToFloat4(glowColor);
		var time:Single = ImGui.getTime();
		var pulse:Single = 0.55 + 0.45 * Math.abs(Math.sin(time * 4.0));
		var currentMax:Single = maxGlowDistance * pulse;
		var stroke:Single = 2.8;

		// Outside → inward so denser layers overpaint near the core.
		var i = layers;
		while (i > 0) {
			var t:Single = i / layers;
			var alphaFalloff:Single = Math.pow(1.0 - t, power);
			var alpha:Single = col.w * alphaFalloff * 0.85;
			if (alpha > 0.01) {
				var pad:Single = currentMax * t;
				var layerCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(col.x, col.y, col.z, alpha));
				var p0 = ImGui.vec2(x - pad, y - pad);
				var p1 = ImGui.vec2(x + w + pad, y + h + pad);
				var round = rounding + pad * 0.2;
				// Soft body haze on outer layers so bloom reads on bright scenes.
				if (t > 0.35) {
					var fillA:Single = alpha * 0.22;
					if (fillA > 0.01) {
						ImGui.ImDrawList_AddRectFilled(dl, p0, p1,
							ImGui.colorConvertFloat4ToU32(ImGui.vec4(col.x, col.y, col.z, fillA)), round);
					}
				}
				ImGui.ImDrawList_AddRect(dl, p0, p1, layerCol, round, stroke, 0);
			}
			i--;
		}

		// Sharp core on the skill slot border (does not grow thickness inward over the icon).
		var coreCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(col.x, col.y, col.z, Math.min(1, col.w * pulse * 1.15)));
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), coreCol, rounding, 2.6, 0);
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

	/**
	 * procOverlay tinted from a packed 0xAARRGGBB colour. Alpha is ignored: procOverlay owns
	 * its own pulse alphas. Shared by the aura Glow tile and the Geaux ready-glow mode so the
	 * two effects cannot drift apart.
	 */
	public static function procTinted(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, time:Float, packed:Int):Void {
		var rgb = packed != 0 ? (packed & 0x00FFFFFF) : 0xFFB000;
		var core = rgb;
		var bloom = rgb;
		var r = (rgb >> 16) & 0xFF;
		var g = (rgb >> 8) & 0xFF;
		var b = rgb & 0xFF;
		// Warmer bloom behind a near-white core; lift the core out of a very dark tint.
		if (r > 220 && g > 200 && b > 140)
			bloom = 0xFFB000;
		else if (r + g + b < 120)
			core = 0xFFF6A0;
		procOverlay(dl, x, y, w, h, time, core, bloom);
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
