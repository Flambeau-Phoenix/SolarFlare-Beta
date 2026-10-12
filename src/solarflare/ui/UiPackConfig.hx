package solarflare.ui;

import imgui.ref.IntRef;

/**
 * Retired in v4.1b: the Native UI panel and its Custom | Native preset were removed.
 * Only the saved id is kept so existing settings files still load and re-save unchanged.
 */
class UiPackConfig {
	public static inline var PACK_CUSTOM:Int = 0;
	public static inline var PACK_NATIVE:Int = 1;

	public var pack = new IntRef(PACK_CUSTOM);

	public function new() {}

	public function isCustom():Bool return pack.get() != PACK_NATIVE;
	public function isNative():Bool return pack.get() == PACK_NATIVE;

	public function dump():Dynamic {
		return {id: isNative() ? "native" : "custom"};
	}

	public function apply(data:Dynamic):Void {
		if (data == null) return;
		var id:Dynamic = Reflect.field(data, "id");
		if (Std.isOfType(id, String)) {
			var s:String = id;
			pack.set(s == "native" ? PACK_NATIVE : PACK_CUSTOM);
		} else {
			var n:Dynamic = Reflect.field(data, "pack");
			if (Std.isOfType(n, Int))
				pack.set(n == PACK_NATIVE ? PACK_NATIVE : PACK_CUSTOM);
		}
	}
}
