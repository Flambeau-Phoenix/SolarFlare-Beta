package solarflare.statusboard;

/**
 * StatusBoard — movable buff/status strip.
 * Evidence: Farever `hero.statuses` / AuraStatusCache walkList (REA MCP not in session).
 */
class StatusBoard {
	/** Stable HUD actions; callbacks read current model/configuration at invocation. */
	var hudEditFn:Void->Void;
	var hudHideFn:Void->Void;

	public var config:StatusBoardConfig;
	var overlay:StatusBoardOverlay;
	/** Opens the hub's Status Board settings page (wired by SolarFlarePanel). */
	public var openSettings:Void->Void;

	public function new() {
		hudEditFn = hudEdit;
		hudHideFn = hudHide;

		config = new StatusBoardConfig();
		overlay = new StatusBoardOverlay();
	}

	public function demand():Bool return config != null && config.demand();

	public function observe():Void {
		if (config != null) config.observe();
	}

	public function draw():Void {
		if (config == null) return;
		overlay.draw(config, hudEditFn, hudHideFn);
	}

	public function dump():Dynamic return config != null ? config.dump() : {};

	public function apply(data:Dynamic):Void {
		if (config == null) config = new StatusBoardConfig();
		config.apply(data);
	}

	function hudEdit():Void {
		if (openSettings != null) openSettings();
	}

	function hudHide():Void {
		config.hidden.set(true); solarflare.ui.SettingsStore.markDirty();
	}
}
