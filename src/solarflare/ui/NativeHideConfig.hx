package solarflare.ui;

import imgui.ref.BoolRef;

/**
 * Global presentation preferences; never part of a character/gear profile.
 *
 * The only supported control is hiding the native bottom action bar (Utilities page).
 * Full-root hiding hid the entire game UI and is closed: `hideAll` is never read from or written
 * to settings, and NativeHideCache ignores it while FULL_ROOT_ENABLED is false.
 */
class NativeHideConfig {
	public static inline var FULL_ROOT_ENABLED:Bool = false;

	public var hideBottomBar = new BoolRef(true);
	/** Kept only so older callers compile; always false and never persisted. */
	public var hideAll = new BoolRef(false);
	/** Session-only. Only meaningful for the closed full-root path. */
	public var bottomBarAccepted = new BoolRef(false);
	public var status:String = "Waiting for native HUD";

	public function new() {}

	public function dump():Dynamic {
		return {hideBottomBar: hideBottomBar.get(), hideAll: false};
	}

	public function apply(data:Dynamic):Void {
		if (data == null) return;
		var bottom:Dynamic = Reflect.field(data, "hideBottomBar");
		if (Std.isOfType(bottom, Bool)) hideBottomBar.set(bottom);
		// A saved hideAll from older builds is ignored on purpose: it could hide the whole UI on load.
		hideAll.set(false);
	}
}
