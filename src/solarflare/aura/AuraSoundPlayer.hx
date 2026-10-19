package solarflare.aura;

import solarflare.ui.CustomSounds;

/**
 * Plays a user sound through the game's own audio manager. Heaps decodes WAV/OGG/MP3 from memory, so no
 * extra libraries are needed. Observe-phase only (reads the file the first time a cue plays); any failure is
 * reported through `status` and never interrupts the aura engine.
 */
class AuraSoundPlayer {
	static var cache = new Map<String, hxd.res.Sound>();
	static var lastPlayed = new Map<String, Float>();
	/** Spacing between repeats of the same cue, so a flickering condition cannot machine-gun a sound. */
	static inline var MIN_GAP:Float = 0.15;
	public static var status(default, null):String = "";

	public static function play(stem:String, volume:Float):Void {
		if (stem == null || stem.length == 0) return;
		var now = haxe.Timer.stamp();
		var last = lastPlayed.get(stem);
		if (last != null && now - last < MIN_GAP) return;
		lastPlayed.set(stem, now);
		try {
			var sound = cache.get(stem);
			if (sound == null) {
				var path = CustomSounds.pathFor(stem);
				if (path == null) { status = "Sound not found: " + stem; return; }
				var bytes = sys.io.File.getBytes(path);
				sound = hxd.res.Any.fromBytes(path, cast bytes).toSound();
				cache.set(stem, sound);
			}
			sound.play(false, Math.max(0, Math.min(1, volume)), null, null);
			status = "";
		} catch (e:Dynamic) {
			// A bad cache entry (for example after the file changed) is dropped so the next play retries.
			cache.remove(stem);
			status = "Could not play " + stem + ": " + Std.string(e);
		}
	}

	/** Forget decoded sounds, e.g. after the folder changes. */
	public static function clearCache():Void cache = new Map<String, hxd.res.Sound>();
}
