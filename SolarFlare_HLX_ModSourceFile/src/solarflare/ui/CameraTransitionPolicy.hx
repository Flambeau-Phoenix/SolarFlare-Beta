package solarflare.ui;

/**
 * Decides whether the cursor leaving "free" mode should close every open SolarFlare window.
 *
 * Entering camera mode on purpose (the player locks the cursor while the game has focus) closes them. Alt-tabbing
 * away makes the game drop the free cursor as well, and again when it takes the cursor back on return; that is
 * not a request to close anything, so those transitions leave the windows open. Native-free for unit tests.
 */
class CameraTransitionPolicy {
	/** Seconds after the game regains or loses focus during which a cursor change is treated as part of the focus change. */
	public static inline var GRACE:Float = 5.0;

	var lastFocused:Bool = true;
	var changedAt:Float = -1e9;

	public function new() {}

	/** Call once per observation with the game window's focus. */
	public function note(now:Float, focused:Bool):Void {
		if (focused == lastFocused) return;
		lastFocused = focused;
		changedAt = now;
	}

	/** True when the cursor went from free to locked and that was the player's own doing. */
	public function closesWindows(wasFree:Bool, nowFree:Bool, now:Float, focused:Bool):Bool {
		if (!wasFree || nowFree) return false;
		return focused && now - changedAt > GRACE;
	}
}
