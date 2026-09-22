package solarflare.castbar;

import solarflare.ui.HUDWidgetWindow;
import solarflare.ui.SettingsStore;
import imgui.ImGui;

class PlayerCastOverlay {
	var snap = new CastSnap();
	public var openBuilder:Void->Void;

	public function new() {}

	public function draw(cfg:CastBarConfig):Void {
		if (cfg == null || cfg.hidden.get()) return;
		snap.copyFrom(CastCache.playerSnap());
		// When locked and no cast is active the window is intentionally invisible —
		// same behaviour as all other HUD widgets: locked = position is committed,
		// no need to see the frame. When unlocked the window stays visible so the
		// user can drag it into position even outside a combat scenario.
		if (!snap.active && cfg.chrome.isLocked()) return;
		var w:Single = Math.max(CastBarConfig.MIN_W, Math.min(CastBarConfig.MAX_W, cfg.width.get()));
		var h:Single = Math.max(CastBarConfig.MIN_H, Math.min(CastBarConfig.MAX_H, cfg.height.get()));
		HUDWidgetWindow.draw("SolarFlare Player Cast", "Cast Bar", cfg.chrome, w, h, function(size) {
			var p = ImGui.getCursorScreenPos();
			ImGui.dummy(size);
			if (snap.active) {
				CastBarRenderer.drawPlayer(snap, cfg.skin.get(), cfg.showIcon.get(), cfg.showName.get(), cfg.showTime.get(), p.x, p.y, size.x, size.y);
			} else {
				// Idle placeholder — visible only while unlocked so the user can position the bar.
				var dl = ImGui.getWindowDrawList();
				ImGui.ImDrawList_AddRectFilled(dl, p, ImGui.vec2(p.x + size.x, p.y + size.y),
					ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.08, 0.09, 0.11, 0.72)), 6);
				ImGui.setCursorScreenPos(ImGui.vec2(p.x + 8, p.y + (size.y - 14) * 0.5));
				ImGui.textDisabled("Cast Bar — no active cast");
			}
		}, openBuilder, function() { cfg.hidden.set(true); SettingsStore.markDirty(); }, false, null, function(newW:Single, newH:Single) {
			cfg.width.set(Math.max(CastBarConfig.MIN_W, Math.min(CastBarConfig.MAX_W, newW)));
			cfg.height.set(Math.max(CastBarConfig.MIN_H, Math.min(CastBarConfig.MAX_H, newH)));
			SettingsStore.markDirty();
		});
	}
}