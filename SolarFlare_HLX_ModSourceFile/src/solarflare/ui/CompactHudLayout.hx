package solarflare.ui;

/** Pure, idempotent saved-layout policy, independent of native ImGui refs. */
class CompactHudLayout {
	public static inline var VERSION:Int = 1;
	public static inline var HEIGHT:Float = 30;
	public static function horizontalRow(style:Int, vertical:Bool):Bool {
		return !vertical && (style == 0 || style == 10 || style == 11);
	}
	public static function migrateVitals(data:Dynamic):Void {
		if (data == null || (data.hudLayoutVersion != null && data.hudLayoutVersion >= VERSION)) return;
		for (key in ["hp", "rage", "mana"]) {
			var style:Dynamic = Reflect.field(data, key + "Style");
			var vertical:Dynamic = Reflect.field(data, key + "Vert");
			if (horizontalRow(style == null ? 0 : Std.int(style), vertical == true)) Reflect.setField(data, key + "H", HEIGHT);
		}
		Reflect.setField(data, "prayersH", HEIGHT);
		Reflect.setField(data, "hudLayoutVersion", VERSION);
	}
}
