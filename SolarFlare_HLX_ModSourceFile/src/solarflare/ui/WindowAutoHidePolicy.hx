package solarflare.ui;

/**
 * Pure rules for WindowAutoHide: which engine windows make the overlays step aside.
 * No engine or ImGui access, so the rules are testable on their own.
 */
class WindowAutoHidePolicy {
	public static inline var OTHER:Int = 0;
	/** A window that hides the overlays whenever it is open. */
	public static inline var HIDE:Int = 1;
	/** MapWindow: hides only in the travel/portal picker modes (see hidesForMapMode). */
	public static inline var TRAVEL_MAP:Int = 2;

	/**
	 * Engine window class by runtime type name.
	 * Bank, trader/vendor, crafting, gear upgrade and weapon-skill upgrade windows.
	 */
	public static function kindOfType(typeName:String):Int {
		return switch (typeName) {
			case "ui.win.BankWindow" | "ui.win.ShopUI" | "ui.win.CraftUI" | "ui.win.GearUpgrade" | "ui.win.WeaponSkillsUpgrade":
				HIDE;
			case "ui.win.MapWindow":
				TRAVEL_MAP;
			default:
				OTHER;
		}
	}

	/**
	 * MapMode constructors that are a travel/portal picker. The plain map (None) and zone highlight
	 * do not hide anything.
	 */
	public static function hidesForMapMode(constructorName:String):Bool {
		return constructorName == "ObeliskFly" || constructorName == "HighlightActivities";
	}
}
