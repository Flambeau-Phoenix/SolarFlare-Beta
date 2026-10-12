package solarflare.ui;

import imgui.ImGui;

/**
 * Controls for the Utilities hub page: Hide All and auto-hide on game windows.
 * The Hide All rows are shared with the Resources builder so there is one implementation.
 */
class UtilitiesPanel {
	/** Hide All: toggle, hotkey dropdown, middle mouse, and the current state line. */
	public static function drawHideAll():Void {
		UiLayout.propertyGrid("##util_hide_all", function() {
			UiLayout.propertyRow("Hidden", function() {
				if (ImGui.checkbox("##util_ha_state", HudSuppress.hideAll))
					SettingsStore.markDirty();
			}, "Blanks every SolarFlare window so the game underneath is clickable.");
			UiLayout.propertyRow("Hotkey", function() {
				var labels = HideAllBind.LABELS;
				var current = HideAllBind.choice.get();
				if (current < 0 || current >= labels.length)
					current = HideAllBind.DEFAULT_CHOICE;
				// One entry per selectable. A single NUL-separated string cannot be passed to
				// ImGui.combo: HashLink's String.toUtf8 stops at the first NUL.
				if (ImGui.beginCombo("##util_ha_key", labels[current])) {
					for (i in 0...labels.length) {
						if (ImGui.selectable(HideAllBind.LABEL_IDS[i], i == current)) {
							HideAllBind.choice.set(i);
							SettingsStore.markDirty();
						}
					}
					ImGui.endCombo();
				}
			});
			UiLayout.propertyRow("Middle mouse", function() {
				if (ImGui.checkbox("##util_ha_mmb", HideAllBind.middleMouse))
					SettingsStore.markDirty();
			}, "Also toggle on middle click, but only while the cursor is free.");
		});
		if (HudSuppress.hideAll.get())
			ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "Hidden now — press the hotkey to bring the HUD back.");
		else
			ImGui.textDisabled("Never saved as hidden; every launch starts visible.");
	}

	/** Hide the game's own bottom action bar. */
	public static function drawNativeBottomBar(cfg:NativeHideConfig):Void {
		if (cfg == null)
			return;
		UiLayout.propertyGrid("##util_native_bar", function() {
			UiLayout.propertyRow("Bottom bar", function() {
				if (ImGui.checkbox("Hide native bottom bar##util_nb_hide", cfg.hideBottomBar))
					SettingsStore.markDirty();
			}, "Hides the game's own skill bar, for example when BarTer replaces it.");
			UiLayout.propertyRow("Recovery", function() {
				if (ImGui.button("Restore native UI##util_nb_restore")) {
					cfg.hideAll.set(false);
					cfg.hideBottomBar.set(false);
					SettingsStore.markDirty();
				}
			});
		});
		ImGui.textWrapped(cfg.status);
	}

	/** Auto-hide while a bank, trader, crafting/upgrade, obelisk-travel or portal window is open. */
	public static function drawAutoHide():Void {
		UiLayout.propertyGrid("##util_auto_hide", function() {
			UiLayout.propertyRow("On game windows", function() {
				if (ImGui.checkbox("Hide overlays while one is open##util_ah_on", WindowAutoHide.enabled))
					SettingsStore.markDirty();
			}, "Bank, trader, crafting and upgrade tables, obelisk travel and dungeon/rift portal pages. Off by default.");
		});
		if (WindowAutoHide.active())
			ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "Hidden now — a game window is open.");
		else
			ImGui.textDisabled("Overlays return as soon as the window closes.");
	}
}
