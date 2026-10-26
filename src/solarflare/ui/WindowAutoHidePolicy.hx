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
	public static inline var CODEX:Int = 256;
	public static inline var COLLECTION:Int = 512;
	/** Compatibility alias; the category now covers every collection page. */
	public static inline var MOUNT_GLIDER:Int = COLLECTION;
	public static inline var SOCIAL:Int = 1024;
	public static inline var ALL:Int = 2047;
	/** The narrower travel/portal subset of MapWindow, independent of the general Map category. */
	public static inline var TRAVEL_MAP:Int = TRAVEL;

	/**
	 * Engine window class by runtime type name.
	 * Bank, trader/vendor, crafting, gear upgrade and weapon-skill upgrade windows.
	 */
	public static function kindOfType(typeName:String):Int {
		return switch (typeName) {
			case "ui.win.CollectionUI": COLLECTION;
			case "ui.win.InfusionUI": CRAFT_UPGRADE;
			case "ui.win.InventoryUI" | "ui.win.InventoryWindow": INVENTORY;
			case "ui.win.BankWindow" | "ui.win.ShopUI": BANK_VENDOR;
			case "ui.win.CraftUI" | "ui.win.GearUpgrade" | "ui.win.WeaponSkills": CRAFT_UPGRADE;
			case "ui.win.MapWindow":
				MAP | TRAVEL_MAP;
			// Obelisk is a subset of Dialogue; the sampler resolves the current dialog target.
			case "ui.win.DialogBar":
				DIALOGUE | OBELISK;
			case "ui.win.EscapeMenu": ESC_MENU;
			case "ui.win.SocialUI" | "ui.win.SocialSettings": SOCIAL;
			case "ui.win.codex.CodexWindow": CODEX;
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
		if ((mask & CODEX) != 0) return "Codex open";
		if ((mask & COLLECTION) != 0) return "Collection open";
		if ((mask & SOCIAL) != 0) return "Social (Party / Friends) open";
		return "No selected game window is open";
	}
	public static inline function suppress(manual:Bool, automatic:Bool):Bool return manual || automatic;
	/** Plain map browsing and zone highlighting remain visible. */
	public static function hidesForMapMode(constructorName:String):Bool {
		return constructorName == "ObeliskFly" || constructorName == "HighlightActivities";
	}
}
