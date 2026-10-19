package solarflare.ui;

/** Optional ABI extension: an older sfcursor.hdll must still let the mod load. */
class MouseGuardNative {
	@:hlNative("?sfcursor", "mouse_guard")
	public static function configure(enabled:Bool):Int return -1;
}

/**
 * Keeps clicks and wheel turns on an open SolarFlare window from also reaching the game's own UI underneath.
 * The work happens in sfcursor.hdll's window subclass; this only tells it when to be on. Runs during observation.
 */
class MouseGuard {
	/** 1 active, 0 off, negative = the helper could not start (-1 SFImGui API, -2 thread, -3 install, -9 old helper). */
	public static var status(default, null):Int = 0;
	static var sampleAt:Float = 0;
	static var retryAt:Float = 0;
	static var wasWanted:Bool = false;
	static var missing:Bool = false;

	public static function observe(wanted:Bool):Void {
		var now = haxe.Timer.stamp();
		if (now < sampleAt || missing) return;
		sampleAt = now + 0.05;
		// Idle and never armed: nothing to tell the helper.
		if (!wanted && !wasWanted && status <= 0) return;
		if (wanted && status < 0 && now < retryAt) return;
		try {
			#if hl
			if (!hl.Api.isPrimLoaded(MouseGuardNative.configure)) { missing = true; status = wanted ? -9 : 0; return; }
			#end
			status = MouseGuardNative.configure(wanted);
			if (status < 0) retryAt = now + 5;
		} catch (_:Dynamic) { status = -1; retryAt = now + 5; }
		wasWanted = wanted;
	}
}
