package solarflare.statusboard;

import imgui.ImGui;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;
import solarflare.ui.NumberField;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiLayout;

/**
 * StatusBoard - movable buff/status strip, with an optional second window that holds only debuffs.
 * Evidence: Farever `hero.statuses` / AuraStatusCache walkList. Both windows read the same observed list;
 * "debuff" is the engine's own Debuff type (or crowd control), resolved once per application.
 */
class StatusBoard {
	/** Stable HUD actions; callbacks read current model/configuration at invocation. */
	var hudEditFn:Void->Void;
	var hudHideFn:Void->Void;
	var debuffHideFn:Void->Void;
	var splitRowFn:Void->Void;

	public var config:StatusBoardConfig;
	/** The separate debuff window's own settings (size, columns, position, lock). Off until split is enabled. */
	public var debuffs:StatusBoardConfig;
	var overlay:StatusBoardOverlay;
	var debuffOverlay:StatusBoardOverlay;
	var splitRef = new BoolRef(false);
	var debuffSize = new IntRef(40);
	/** Opens the hub's Status Board settings page (wired by SolarFlarePanel). */
	public var openSettings:Void->Void;

	public function new() {
		hudEditFn = hudEdit;
		hudHideFn = hudHide;
		debuffHideFn = debuffHide;
		splitRowFn = splitRow;

		config = new StatusBoardConfig();
		debuffs = newDebuffBoard();
		overlay = new StatusBoardOverlay("SolarFlare.StatusBoard", "Statuses");
		debuffOverlay = new StatusBoardOverlay("SolarFlare.StatusBoard.Debuffs", "Debuffs");
	}

	static function newDebuffBoard():StatusBoardConfig {
		var d = new StatusBoardConfig(260);
		d.view = 2;
		d.hidden.set(true);
		return d;
	}

	public function demand():Bool return config != null && (config.demand() || debuffs.demand());

	public function observe():Void {
		if (config != null) config.observe();
		if (debuffs != null && debuffs.demand()) debuffs.observe();
	}

	public function draw():Void {
		if (config == null) return;
		// "Buffs" once the harmful effects have their own window; "Statuses" while this board still shows everything.
		overlay.draw(config, hudEditFn, hudHideFn, config.view == 1 ? "Buffs" : config.view == 2 ? "Debuffs" : "Statuses");
		debuffOverlay.draw(debuffs, hudEditFn, debuffHideFn);
	}

	public function dump():Dynamic {
		if (config == null) return {};
		var d = config.dump();
		Reflect.setField(d, "debuffBoard", debuffs.dump());
		return d;
	}

	public function apply(data:Dynamic):Void {
		if (config == null) config = new StatusBoardConfig();
		config.apply(data);
		debuffs.apply(data == null ? null : Reflect.field(data, "debuffBoard"));
		debuffs.view = 2;
	}

	/** Hub page: the main board's settings, then the debuff window's own once it is on. */
	public function drawContents():Void {
		config.drawContents("Status Board", splitRowFn);
		if (!debuffs.demand()) return;
		ImGui.separator();
		ImGui.pushID_Str("sb_debuffs");
		try debuffs.drawContents("Debuff window") catch (e:Dynamic) { ImGui.popID(); throw e; }
		ImGui.popID();
	}

	function splitRow():Void {
		UiLayout.propertyRow("Debuffs", function() {
			splitRef.set(debuffs.demand() && config.view == 1);
			if (ImGui.checkbox("Separate window##sb_split", splitRef)) setSplit(splitRef.get());
		}, "Buffs stay on this board. Harmful effects move to their own window that you can place anywhere.");
		if (!debuffs.demand()) return;
		UiLayout.propertyRow("Debuff icon size", function() {
			debuffSize.set(debuffs.slotSize);
			if (NumberField.drawInt("##sb_debuff_icon", debuffSize, 28, 72, "%.0f px")) {
				debuffs.slotSize = debuffSize.get();
				debuffs.contentWidth = 0;
				SettingsStore.markDirty();
			}
		}, "Size of the icons in the debuff window. Buff icons keep their own size above.");
	}

	function setSplit(on:Bool):Void {
		if (on) {
			config.view = 1;
			debuffs.view = 2;
			debuffs.enabled.set(true);
			debuffs.hidden.set(false);
			debuffs.chrome.locked.set(false);
		} else {
			config.view = 0;
			debuffs.hidden.set(true);
		}
		SettingsStore.markDirty();
	}

	function hudEdit():Void {
		if (openSettings != null) openSettings();
	}

	function hudHide():Void {
		config.hidden.set(true); SettingsStore.markDirty();
	}

	function debuffHide():Void {
		debuffs.hidden.set(true); SettingsStore.markDirty();
	}
}
