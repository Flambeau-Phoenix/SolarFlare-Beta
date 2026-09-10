package solarflare.ui;

import imgui.ImGui;
import imgui.Structs.ImVec2;

/**
 * High-fidelity skill icon renderer for Geaux action bar and Aura visual previews.
 */
class SkillIconRenderer {
	public static function draw(dl:Dynamic, iconId:String, x:Single, y:Single, size:Single,
								ready:Bool, affordable:Bool, cooldown:Single, maxCooldown:Single = 1.0,
								selected:Bool = false, hotkey:String = ""):Void {
		var pad:Single = size * 0.06;
		var iconSize:Single = size - pad * 2;

		// 1. Ready & Affordable Glow
		if (ready && affordable) {
			VectorGlow.radial(dl, x + size * 0.5, y + size * 0.5, size * 0.55, 0x44FFB833, 0.45, 6);
		}

		// 2. Base Icon Texture
		var tex = GameIcons.get(iconId);
		var tint = (ready && affordable) ? 0xFFFFFFFF : 0x99AABBCC;
		if (!GameIcons.draw(dl, tex, x + pad, y + pad, iconSize, tint)) {
			// Placeholder fallback
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + pad, y + pad), ImGui.vec2(x + pad + iconSize, y + pad + iconSize), 0x33223344, 4);
			var mark = iconId != null && iconId.length > 0 ? iconId.substr(0, 1).toUpperCase() : "?";
			var ts = ImGui.calcTextSize(mark);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + (size - ts.x) * 0.5, y + (size - ts.y) * 0.5), 0xCCFFFFFF, mark);
		}

		// 3. Cooldown Shade & Countdown
		if (cooldown > 0.05 && !ready) {
			// Dark overlay
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + size, y + size), 0x99000000, 4);

			var cdStr = cooldown >= 10.0 ? Std.string(Math.ceil(cooldown)) : Std.string(Math.round(cooldown * 10) / 10);
			var ts = ImGui.calcTextSize(cdStr);
			VectorGlow.textWithGlow(dl, x + (size - ts.x) * 0.5, y + (size - ts.y) * 0.5, cdStr, 0xFFFFFFFF, 0xDD000000);
		}

		// 4. Hotkey Label
		if (hotkey != null && hotkey.length > 0) {
			var ts = ImGui.calcTextSize(hotkey);
			var kx:Single = x + size - ts.x - 3;
			var ky:Single = y + size - ts.y - 2;
			// Badge pill
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(kx - 2, ky - 1), ImGui.vec2(kx + ts.x + 2, ky + ts.y + 1), 0xAA000000, 3);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(kx, ky), 0xFFEEEEEE, hotkey);
		}

		// 5. Unaffordable Marker
		if (!affordable && ready) {
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(x + size - 6, y + 6), 4.5, 0xEEFF3333, 8);
		}

		// 6. Selection Border
		if (selected) {
			VectorGlow.rect(dl, x, y, size, size, 0xFFFFAA22, 4.0, 2.5);
		} else {
			ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + size, y + size), 0x44FFFFFF, 4.0, 1.0, 0);
		}
	}
}
