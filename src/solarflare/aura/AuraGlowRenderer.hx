package solarflare.aura;

import imgui.ImGui;

/** Optional Aura artwork only. Never draws without the configured glow effect. */
class AuraGlowRenderer {
	public static function draw(dl:Dynamic, a:AuraDef, x:Single, y:Single, w:Single, h:Single, alpha:Float):Void {
		drawStyle(dl, a.glowStyle, a.glowStrength.get(), a.glowOuter.get(), a.glowInner.get(), a.glowColor, x, y, w, h, alpha);
	}
	public static function drawStyle(dl:Dynamic, glowStyle:String, glowStrength:Float, glowOuter:Float, glowInner:Float, packed:Int,
			x:Single, y:Single, w:Single, h:Single, alpha:Float):Void {
		var style = AuraGlowStyle.normalize(glowStyle);
		var strength = AuraGlowStyle.intensity(style, glowStrength, ImGui.getTime()) * alpha * ((packed >>> 24) & 255) / 255;
		if (strength <= 0.001 || w < 1 || h < 1) return;
		var outer:Single = AuraGlowStyle.spread(glowOuter);
		var inner:Single = Math.min(AuraGlowStyle.spread(glowInner), Math.max(0, Math.min(w, h) * 0.5 - 2));
		if (style == "proc") {
			var extra:Single = Math.max(0, outer - 12);
			solarflare.ui.VectorGlow.procTinted(dl, x - extra, y - extra, w + extra * 2, h + extra * 2,
				ImGui.getTime(), packed, strength);
		} else {
			for (i in 0...12) {
				var t:Single = (i + 1) / 12;
				var pad:Single = outer * t;
				stroke(dl, x - pad, y - pad, w + pad * 2, h + pad * 2, packed,
					strength * (1 - t) * (1 - t) * 0.4, 2.8);
			}
			stroke(dl, x, y, w, h, packed, strength * 0.9, 2);
		}
		if (inner > 0) {
			for (i in 0...12) {
				var t:Single = (i + 1) / 12;
				var inset:Single = inner * t;
				stroke(dl, x + inset, y + inset, w - inset * 2, h - inset * 2, packed,
					strength * (1 - t) * (1 - t) * 0.35, 2.8);
			}
		}
	}
	static function stroke(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, packed:Int, alpha:Float, thickness:Single):Void {
		var col = ImGui.colorConvertFloat4ToU32(ImGui.vec4(((packed >> 16) & 255) / 255,
			((packed >> 8) & 255) / 255, (packed & 255) / 255, Math.min(1, alpha)));
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), col, 4, thickness, 0);
	}
}
