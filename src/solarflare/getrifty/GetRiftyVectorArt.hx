package solarflare.getrifty;

import imgui.ImGui;
import imgui.Structs.ImVec4;
import solarflare.getrifty.GetRifty.GetRiftyCache;
import solarflare.getrifty.GetRifty.GetRiftyConfig;
import solarflare.ui.ThemePalette;

/**
 * Text-free draw-list art for the GetRifty overlay (styles 16+). Pure ASCII source, no textures, no state beyond
 * the static shape tables below. `GetRiftyOverlay` draws the countdown text afterwards through `drawHoleText`, so
 * every style leaves a dark plate under the configured text hole. Redrawn from cached values only: the alert
 * animation phase comes from `GetRiftyCache.animFrame`, which `tick` advances on the alert edge.
 */
class GetRiftyVectorArt {
	/** Crack path: fraction along the run, and sideways wobble in units of the window size. */
	static final CRACK_T:Array<Float> = [0.0, 0.26, 0.52, 0.78, 1.0];
	static final CRACK_UP:Array<Float> = [0.08, -0.02, 0.07, -0.05, 0.0];
	static final CRACK_DOWN:Array<Float> = [0.0, 0.06, -0.06, 0.05, -0.04];
	/** Sleeping Moon stars: x, y in window fractions, then radius fraction. */
	static final STARS:Array<Float> = [0.12, 0.40, 0.016, 0.82, 0.34, 0.012, 0.24, 0.80, 0.014, 0.74, 0.78, 0.018, 0.88, 0.60, 0.010];

	public static inline function isVectorStyle(style:Int):Bool {
		return style >= GetRiftyConfig.STYLE_VEC_PORTAL && style <= GetRiftyConfig.STYLE_VEC_MOON;
	}

	/**
	 * Draw one vector style into the square at (x, y, size). Hole is the text region in window fractions
	 * (already normalised by the caller). Unknown styles draw nothing and return false so the caller can fall back.
	 */
	public static function draw(dl:Dynamic, x:Single, y:Single, size:Single, style:Int, u0:Float, v0:Float, u1:Float, v1:Float):Bool {
		var hx:Single = x + size * u0;
		var hy:Single = y + size * v0;
		var hw:Single = size * (u1 - u0);
		var hh:Single = size * (v1 - v0);
		var glow = glowColor();
		switch (style) {
			case GetRiftyConfig.STYLE_VEC_PORTAL:
				drawPortal(dl, x, y, size, glow);
				plate(dl, hx, hy, hw, hh, glow, 0.55);
			case GetRiftyConfig.STYLE_VEC_HOURGLASS:
				drawHourglass(dl, x, y, size, glow);
				plate(dl, hx, hy, hw, hh, glow, 0.82);
			case GetRiftyConfig.STYLE_VEC_CRACK:
				drawCrack(dl, x, y, size, hx, hy, hw, hh, glow);
				plate(dl, hx, hy, hw, hh, glow, 0.92);
			case GetRiftyConfig.STYLE_VEC_MOON:
				drawMoon(dl, x, y, size, glow);
				plate(dl, hx, hy, hw, hh, glow, 0.6);
			default:
				return false;
		}
		return true;
	}

	/** Accent from the active theme; the alert kinds keep the banner's amber / violet. */
	static function glowColor():ImVec4 {
		if (GetRiftyCache.alertKind == GetRiftyCache.ALERT_RIFT)
			return ImGui.vec4(0.72, 0.35, 0.95, 1);
		if (GetRiftyCache.alertKind == GetRiftyCache.ALERT_PORTAL)
			return ImGui.vec4(1.0, 0.62, 0.18, 1);
		var pal = ThemePalette.current();
		return pal != null && pal.accent != null ? pal.accent : ImGui.vec4(0.85, 0.65, 0.25, 1);
	}

	static inline function col(c:ImVec4, a:Float):Int {
		return ImGui.colorConvertFloat4ToU32(ImGui.vec4(c.x, c.y, c.z, a));
	}

	static inline function rgba(r:Float, g:Float, b:Float, a:Float):Int {
		return ImGui.colorConvertFloat4ToU32(ImGui.vec4(r, g, b, a));
	}

	/** Dark rounded plate with a thin accent edge so the countdown stays readable on any art. */
	static function plate(dl:Dynamic, hx:Single, hy:Single, hw:Single, hh:Single, glow:ImVec4, alpha:Float):Void {
		var padX:Single = hw * 0.06;
		var padY:Single = hh * 0.1;
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(hx - padX, hy - padY), ImGui.vec2(hx + hw + padX, hy + hh + padY),
			rgba(0.02, 0.02, 0.05, alpha), 6);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(hx - padX, hy - padY), ImGui.vec2(hx + hw + padX, hy + hh + padY),
			col(glow, 0.85), 6, 1.5);
	}

	/** Concentric rings around a dark core; the tick ring turns while an alert plays. */
	static function drawPortal(dl:Dynamic, x:Single, y:Single, size:Single, glow:ImVec4):Void {
		var c = ImGui.vec2(x + size * 0.5, y + size * 0.5);
		ImGui.ImDrawList_AddCircleFilled(dl, c, size * 0.47, rgba(0.03, 0.02, 0.07, 0.86), 48);
		ImGui.ImDrawList_AddCircle(dl, c, size * 0.47, col(glow, 0.95), 48, 3);
		ImGui.ImDrawList_AddCircle(dl, c, size * 0.38, col(glow, 0.7), 48, 2.5);
		ImGui.ImDrawList_AddCircle(dl, c, size * 0.30, col(glow, 0.5), 40, 2);
		ImGui.ImDrawList_AddCircleFilled(dl, c, size * 0.27, rgba(0.01, 0.0, 0.03, 0.92), 40);
		var ticks = 24;
		var spin = GetRiftyCache.animFrame * 0.09;
		var tc = col(glow, 0.8);
		var r0 = size * 0.40;
		var r1 = size * 0.44;
		for (i in 0...ticks) {
			var a = i * Math.PI * 2 / ticks + spin;
			var ca = Math.cos(a);
			var sa = Math.sin(a);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(c.x + ca * r0, c.y + sa * r0), ImGui.vec2(c.x + ca * r1, c.y + sa * r1), tc,
				i % 6 == 0 ? 2.5 : 1.2);
		}
	}

	/** Caps, glass outline, sand above and below. The label plate covers the neck. */
	static function drawHourglass(dl:Dynamic, x:Single, y:Single, size:Single, glow:ImVec4):Void {
		var cx:Single = x + size * 0.5;
		var capL:Single = cx - size * 0.31;
		var capR:Single = cx + size * 0.31;
		var topY:Single = y + size * 0.13;
		var botY:Single = y + size * 0.87;
		var midY:Single = y + size * 0.5;
		var glass = rgba(0.75, 0.88, 0.95, 0.9);
		var sand = col(glow, 0.95);
		// Glass body (two triangles meeting at the neck), faint fill then outline.
		var tl = ImGui.vec2(cx - size * 0.26, topY);
		var tr = ImGui.vec2(cx + size * 0.26, topY);
		var bl = ImGui.vec2(cx - size * 0.26, botY);
		var br = ImGui.vec2(cx + size * 0.26, botY);
		var neck = ImGui.vec2(cx, midY);
		ImGui.ImDrawList_AddTriangleFilled(dl, tl, tr, neck, rgba(0.55, 0.75, 0.9, 0.16));
		ImGui.ImDrawList_AddTriangleFilled(dl, bl, br, neck, rgba(0.55, 0.75, 0.9, 0.16));
		// Sand: trapezoid in the top bulb, mound and falling stream below.
		ImGui.ImDrawList_AddQuadFilled(dl, ImGui.vec2(cx - size * 0.15, y + size * 0.29), ImGui.vec2(cx + size * 0.15, y + size * 0.29),
			ImGui.vec2(cx + size * 0.03, y + size * 0.46), ImGui.vec2(cx - size * 0.03, y + size * 0.46), sand);
		ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(cx - size * 0.21, botY), ImGui.vec2(cx + size * 0.21, botY),
			ImGui.vec2(cx, y + size * 0.66), sand);
		ImGui.ImDrawList_AddLine(dl, neck, ImGui.vec2(cx, y + size * 0.66), sand, 1.5);
		ImGui.ImDrawList_AddTriangle(dl, tl, tr, neck, glass, 2);
		ImGui.ImDrawList_AddTriangle(dl, bl, br, neck, glass, 2);
		// Caps and posts.
		var cap = col(glow, 1);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(capL, y + size * 0.08), ImGui.vec2(capR, topY), cap, 3);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(capL, botY), ImGui.vec2(capR, y + size * 0.92), cap, 3);
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(capL + 3, topY), ImGui.vec2(capL + 3, botY), col(glow, 0.55), 2);
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(capR - 3, topY), ImGui.vec2(capR - 3, botY), col(glow, 0.55), 2);
	}

	/** Jagged glowing crack from the top edge into the text hole and out the bottom: the hole is the rift opening. */
	static function drawCrack(dl:Dynamic, x:Single, y:Single, size:Single, hx:Single, hy:Single, hw:Single, hh:Single, glow:ImVec4):Void {
		var pad:Single = 4;
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + pad, y + pad), ImGui.vec2(x + size - pad, y + size - pad),
			rgba(0.04, 0.04, 0.07, 0.94), 6);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x + pad, y + pad), ImGui.vec2(x + size - pad, y + size - pad), col(glow, 0.45), 6, 1.5);
		var cx:Single = hx + hw * 0.5;
		crackRun(dl, size, cx, y + size * 0.05, hy, CRACK_UP, glow);
		crackRun(dl, size, cx, hy + hh, y + size * 0.95, CRACK_DOWN, glow);
	}

	static function crackRun(dl:Dynamic, size:Single, cx:Single, yFrom:Single, yTo:Single, wobble:Array<Float>, glow:ImVec4):Void {
		var wide = col(glow, 0.22);
		var mid = col(glow, 0.55);
		var core = rgba(1, 1, 1, 0.95);
		var n = wobble.length;
		var px:Single = cx + wobble[0] * size;
		var py:Single = yFrom + (yTo - yFrom) * CRACK_T[0];
		for (i in 1...n) {
			var nx:Single = cx + wobble[i] * size;
			var ny:Single = yFrom + (yTo - yFrom) * CRACK_T[i];
			var a = ImGui.vec2(px, py);
			var b = ImGui.vec2(nx, ny);
			ImGui.ImDrawList_AddLine(dl, a, b, wide, 7);
			ImGui.ImDrawList_AddLine(dl, a, b, mid, 3.5);
			ImGui.ImDrawList_AddLine(dl, a, b, core, 1.5);
			// Short side fracture alternating left and right off every inner joint.
			if (i < n - 1) {
				var dir:Single = i % 2 == 0 ? -1 : 1;
				ImGui.ImDrawList_AddLine(dl, b, ImGui.vec2(nx + dir * size * 0.09, ny + (yTo - yFrom) * 0.07), mid, 1.5);
			}
			px = nx;
			py = ny;
		}
	}

	/** Night disk with a crescent, stars and sleeping z's. */
	static function drawMoon(dl:Dynamic, x:Single, y:Single, size:Single, glow:ImVec4):Void {
		var c = ImGui.vec2(x + size * 0.5, y + size * 0.5);
		var sky = rgba(0.04, 0.05, 0.13, 1);
		ImGui.ImDrawList_AddCircleFilled(dl, c, size * 0.47, sky, 48);
		ImGui.ImDrawList_AddCircle(dl, c, size * 0.47, col(glow, 0.9), 48, 2.5);
		// Crescent = pale disk minus an offset sky disk.
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(x + size * 0.34, y + size * 0.29), size * 0.17, rgba(0.97, 0.93, 0.74, 1), 32);
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(x + size * 0.41, y + size * 0.25), size * 0.15, sky, 32);
		var starCol = rgba(0.95, 0.95, 1, 0.85);
		var i = 0;
		while (i + 2 < STARS.length) {
			var sx:Single = x + size * STARS[i];
			var sy:Single = y + size * STARS[i + 1];
			var r:Single = size * STARS[i + 2] + 1;
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(sx - r, sy), ImGui.vec2(sx + r, sy), starCol, 1.2);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(sx, sy - r), ImGui.vec2(sx, sy + r), starCol, 1.2);
			i += 3;
		}
		var zc = col(glow, 0.95);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + size * 0.57, y + size * 0.24), zc, "z");
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + size * 0.63, y + size * 0.17), zc, "Z");
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + size * 0.69, y + size * 0.11), zc, "Z");
	}
}
