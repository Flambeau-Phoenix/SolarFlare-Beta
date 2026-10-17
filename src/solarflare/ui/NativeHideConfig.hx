package solarflare.ui;

import imgui.ref.BoolRef;

/**
 * Global presentation preferences; never part of a character/gear profile.
 *
 * Supported controls: hiding the native bottom action bar (Utilities page and the Native UI page share
 * `hideBottomBar`) and the per-widget rows in `elements` (Native UI page). Full-root hiding hid the entire
 * game UI and is closed: `hideAll` is never read from or written to settings, and NativeHideCache ignores it
 * while FULL_ROOT_ENABLED is false.
 */
class NativeHideConfig {
	public static inline var FULL_ROOT_ENABLED:Bool = false;

	public static inline var GROUP_ACTION:String = "Action bar";
	public static inline var GROUP_HUD:String = "HUD";

	public var hideBottomBar = new BoolRef(true);
	/** Kept only so older callers compile; always false and never persisted. */
	public var hideAll = new BoolRef(false);
	/** Session-only. Only meaningful for the closed full-root path. */
	public var bottomBarAccepted = new BoolRef(false);
	public var status:String = "Waiting for native HUD";
	/**
	 * Per-widget rows. One line per widget here, plus its lookup in NativeElementCache.TARGETS.
	 * Everything starts shown; saved choices are applied over this.
	 */
	public var elements:Array<NativeHideElement>;
	/** Set by the Native UI page while it is drawn; observation consumes it so state is only looked up then. */
	public var probe:Bool = false;
	/** Written by observation: empty when fine, otherwise why the per-widget rows are not working. */
	public var elementsStatus:String = "";

	public function new() {
		elements = [
			new NativeHideElement("skills", "Weapon skills", GROUP_ACTION, "Native weapon, passive and vehicle skills on keyboard or controller."),
			new NativeHideElement("baseActions", "Basic actions (2x2)", GROUP_ACTION, "Attack, dash, mount and block on the native keyboard bar."),
			new NativeHideElement("statuses", "Statuses", GROUP_ACTION, "Both native buff and debuff bars above the bottom bar."),
			new NativeHideElement("resources", "Health and resources", GROUP_ACTION, "Native health, class resources and Spark Surge gauge."),
			new NativeHideElement("consumables", "Consumables (2x2)", GROUP_ACTION,
				"The four quick-use consumable slots on the native bar. The skills and bars beside them stay."),
			new NativeHideElement("menuBar", "Menu buttons", GROUP_HUD,
				"The row of window buttons. Their hotkeys still open each window."),
			new NativeHideElement("chat", "Chat", GROUP_HUD,
				"The native chat box. Left alone while the Enhanced Chat mod owns it."),
			new NativeHideElement("compass", "Compass", GROUP_HUD, "The compass strip."),
			new NativeHideElement("groupBar", "Party frames", GROUP_HUD, "Group member frames."),
			new NativeHideElement("bossesInfo", "Boss frames", GROUP_HUD, "Boss health frames during encounters."),
			new NativeHideElement("castBar", "Cast bar", GROUP_HUD,
				"The game's own player cast bar. SolarFlare's Player Cast Bar overlay is separate and has its own Hidden option."),
			new NativeHideElement("oxygen", "Oxygen", GROUP_HUD, "The underwater breath gauge."),
			new NativeHideElement("combatMeter", "Combat meter", GROUP_HUD, "The native damage meter."),
			new NativeHideElement("feed", "Effects feed", GROUP_HUD, "The scrolling effects feed.")
		];
	}

	public function dump():Dynamic {
		var rows:Array<Dynamic> = [];
		for (e in elements)
			rows.push({id: e.id, hidden: e.hidden.get()});
		return {hideBottomBar: hideBottomBar.get(), hideAll: false, elements: rows};
	}

	public function apply(data:Dynamic):Void {
		if (data == null) return;
		var bottom:Dynamic = Reflect.field(data, "hideBottomBar");
		if (Std.isOfType(bottom, Bool)) hideBottomBar.set(bottom);
		// A saved hideAll from older builds is ignored on purpose: it could hide the whole UI on load.
		hideAll.set(false);
		var rows:Dynamic = Reflect.field(data, "elements");
		if (rows == null) return;
		try {
			var arr:Array<Dynamic> = cast rows;
			if (arr == null) return;
			var hasBase=false; var legacySkills:Null<Bool>=null;
			for (row in arr) {
				var id = Std.string(Reflect.field(row, "id"));
				var value:Dynamic = Reflect.field(row, "hidden");
				if (!Std.isOfType(value, Bool)) continue;
				if(id=="baseActions") hasBase=true;
				if(id=="skills") legacySkills=value;
				for (e in elements) {
					if (e.id == id) {
						e.hidden.set(value);
						break;
					}
				}
			}
			// Older Skills toggles included this block. Preserve that saved appearance once.
			if(!hasBase && legacySkills!=null) for(e in elements) if(e.id=="baseActions") e.hidden.set(legacySkills);
		} catch (_:Dynamic) {}
	}

	/** True when the user is hiding the bottom bar or any element row. */
	public function anyHidden():Bool {
		if (hideBottomBar.get()) return true;
		for (e in elements)
			if (e.hidden.get()) return true;
		return false;
	}

	/** Recovery: show every native piece again. Ownership is released by the next observation pass. */
	public function showAll():Void {
		hideAll.set(false);
		hideBottomBar.set(false);
		for (e in elements)
			e.hidden.set(false);
	}
}
