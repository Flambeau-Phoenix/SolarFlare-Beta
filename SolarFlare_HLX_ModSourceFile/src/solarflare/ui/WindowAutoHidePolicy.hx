package solarflare.ui;

/**
 * Pure rules for WindowAutoHide: which engine windows make the overlays step aside.
 * No engine or ImGui access, so the rules are testable on their own.
 */
class WindowAutoHidePolicy {
	public static inline var OTHER:Int = 0;
	/** A window that hides the overlays whenever it is open. */
	public static inline var INVENTORY:Int = 1;
	public static inline var BANK_VENDOR:Int = 2;
	public static inline var CRAFT_UPGRADE:Int = 4;
	public static inline var TRAVEL:Int = 8;
	/** The "Obelisk: <name>" interaction dialog (Fly to another obelisk, Set point, ...). */
	public static inline var OBELISK:Int = 16;
	public static inline var DIALOGUE:Int = 32;
	public static inline var MAP:Int = 64;
	public static inline var ESC_MENU:Int = 128;
	public static inline var ALL:Int = 255;
	/** The narrower travel/portal subset of MapWindow, independent of the general Map category. */
	public static inline var TRAVEL_MAP:Int = TRAVEL;

	/**
	 * Engine window class by runtime type name.
	 * Bank, trader/vendor, crafting, gear upgrade and weapon-skill upgrade windows.
	 */
	public static function kindOfType(typeName:String):Int {
		return switch (typeName) {
			case "ui.win.InventoryUI" | "ui.win.InventoryWindow": INVENTORY;
			case "ui.win.BankWindow" | "ui.win.ShopUI": BANK_VENDOR;
			case "ui.win.CraftUI" | "ui.win.GearUpgrade" | "ui.win.WeaponSkills": CRAFT_UPGRADE;
			case "ui.win.MapWindow":
				MAP | TRAVEL_MAP;
			// Obelisk is a subset of Dialogue; the sampler resolves the current dialog target.
			case "ui.win.DialogBar":
				DIALOGUE | OBELISK;
			case "ui.win.EscapeMenu": ESC_MENU;
			default:
				OTHER;
		}
	}

	/** A stable presentation reason; the bit mask exposes all simultaneously active categories. */
	public static function reason(mask:Int):String {
		if ((mask & INVENTORY) != 0) return "Inventory open";
		if ((mask & BANK_VENDOR) != 0) return "Bank or vendor open";
		if ((mask & CRAFT_UPGRADE) != 0) return "Crafting or upgrade window open";
		if ((mask & TRAVEL) != 0) return "Travel or portal picker open";
		if ((mask & OBELISK) != 0) return "Obelisk window open";
		if ((mask & DIALOGUE) != 0) return "Dialogue open";
		if ((mask & MAP) != 0) return "Map open";
		if ((mask & ESC_MENU) != 0) return "ESC Menu open";
		return "No selected game window is open";
	}
	public static inline function suppress(manual:Bool, automatic:Bool):Bool return manual || automatic;
	/** Plain map browsing and zone highlighting remain visible. */
	public static function hidesForMapMode(constructorName:String):Bool {
		return constructorName == "ObeliskFly" || constructorName == "HighlightActivities";
	}
}
