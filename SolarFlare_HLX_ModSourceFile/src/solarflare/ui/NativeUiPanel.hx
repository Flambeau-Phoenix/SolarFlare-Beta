package solarflare.ui;

import imgui.ImGui;

/**
 * Native UI hub page: show or hide the game's own HUD pieces, including the 2x2 consumable module.
 * Drawing only. Rows write BoolRefs on NativeHideConfig; NativeHideCache / NativeElementCache apply them
 * during observation and hand the native visibility back when a piece is shown again.
 */
class NativeUiPanel {
	public static function draw(cfg:NativeHideConfig):Void {
		if (cfg == null)
			return;
		// Observation only looks pieces up while this page is on screen (or something is hidden).
		cfg.probe = true;
		UiChrome.sectionHeader("Native UI");
		ImGui.textWrapped("Show or hide the game's own HUD pieces. Changes apply at once and are remembered. "
			+ "Showing a piece hands it back to the game.");
		UiChrome.subHeader(NativeHideConfig.GROUP_ACTION);
		UiLayout.propertyGrid("##nui_action", function() {
			UiLayout.propertyRow("Bottom bar", function() {
				if (UiChrome.showingTile("##nui_show_bottomBar", "Showing", cfg.hideBottomBar, 140, 28))
					SettingsStore.markDirty();
				hint("Skill bar, status icons and hero bars. Hiding it also hides the consumables.");
			});
			drawRows(cfg, NativeHideConfig.GROUP_ACTION);
		});
		UiChrome.subHeader(NativeHideConfig.GROUP_HUD);
		UiLayout.propertyGrid("##nui_hud", function() {
			drawRows(cfg, NativeHideConfig.GROUP_HUD);
		});
		UiChrome.gap(UiChrome.SP_S);
		UiLayout.propertyGrid("##nui_recovery", function() {
			UiLayout.propertyRow("Recovery", function() {
				if (UiChrome.ghostButton("Show everything##nui_show_all", ImGui.vec2(160, 28))) {
					cfg.showAll();
					SettingsStore.markDirty();
				}
			});
		});
		ImGui.textDisabled(cfg.status);
		if (cfg.elementsStatus.length > 0)
			ImGui.textWrapped(cfg.elementsStatus);
	}

	static function drawRows(cfg:NativeHideConfig, group:String):Void {
		for (e in cfg.elements) {
			if (e.group != group)
				continue;
			UiLayout.propertyRow(e.label, function() {
				var external = e.state == NativeHideElement.STATE_EXTERNAL;
				if (external)
					ImGui.beginDisabled();
				if (UiChrome.showingTile("##nui_show_" + e.id, "Showing", e.hidden, 140, 28))
					SettingsStore.markDirty();
				if (external)
					ImGui.endDisabled();
				hint(e.hint);
				var note = stateNote(e);
				if (note.length > 0) {
					ImGui.sameLine(0, 8);
					ImGui.textDisabled(note);
				}
			});
		}
	}

	/** Tooltip for the control just drawn. */
	static function hint(text:String):Void {
		if (ImGui.isItemHovered())
			ImGui.setTooltip(text);
	}

	static function stateNote(e:NativeHideElement):String {
		return switch (e.state) {
			case NativeHideElement.STATE_EXTERNAL: "managed by another mod";
			case NativeHideElement.STATE_ABSENT: "not on screen";
			default: "";
		}
	}
}
