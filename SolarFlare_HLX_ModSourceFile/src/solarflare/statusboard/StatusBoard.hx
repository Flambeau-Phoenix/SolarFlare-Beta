package solarflare.statusboard;

/**
 * StatusBoard — movable buff/status strip.
 * Evidence: Farever `hero.statuses` / AuraStatusCache walkList (REA MCP not in session).
 */
class StatusBoard {
	public var config:StatusBoardConfig;
	var overlay:StatusBoardOverlay;
	/** Opens the hub's Status Board settings page (wired by SolarFlarePanel). */
	public var openSettings:Void->Void;

	public function new() {
		config = new StatusBoardConfig();
		overlay = new StatusBoardOverlay();
	}

	public function demand():Bool return config != null && config.demand();

	public function observe():Void {
		if (config != null) config.observe();
	}

	public function draw():Void {
		if (config == null) return;
		overlay.draw(config, function() {
			if (openSettings != null) openSettings();
		}, function() {
			config.hidden.set(true);
			solarflare.ui.SettingsStore.markDirty();
		});
	}

	public function dump():Dynamic return config != null ? config.dump() : {};

	public function apply(data:Dynamic):Void {
		if (config == null) config = new StatusBoardConfig();
		config.apply(data);
	}
}
