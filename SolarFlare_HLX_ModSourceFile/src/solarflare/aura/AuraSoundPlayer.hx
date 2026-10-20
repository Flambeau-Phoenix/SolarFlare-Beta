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
	static var failedAt = new Map<String, Float>();
	/** Safety-net wait before a failed stem is probed again (a file dropped in later is picked up within this). */
	static inline var RETRY_S:Float = 5;
	public static var status(default, null):String = "";

	public static function play(stem:String, volume:Float):Void {
		if (stem == null || stem.length == 0) return;
		var now = haxe.Timer.stamp();
		var last = lastPlayed.get(stem);
		if (last != null && now - last < MIN_GAP) return;
		lastPlayed.set(stem, now);
		// A missing or undecodable file is remembered briefly so a flickering cue does not redo the filesystem probes.
		var failed = failedAt.get(stem);
		if (failed != null && now - failed < RETRY_S) return;
		try {
			var sound = cache.get(stem);
			if (sound == null) {
				var path = CustomSounds.pathFor(stem);
				if (path == null) { failedAt.set(stem, now); status = "Sound not found: " + stem; return; }
				var bytes = sys.io.File.getBytes(path);
				sound = hxd.res.Any.fromBytes(path, cast bytes).toSound();
				cache.set(stem, sound);
			}
			failedAt.remove(stem);
			sound.play(false, Math.max(0, Math.min(1, volume)), null, null);
			status = "";
		} catch (e:Dynamic) {
			// A bad cache entry (for example after the file changed) is dropped; the retry waits RETRY_S.
			cache.remove(stem);
			failedAt.set(stem, now);
			status = "Could not play " + stem + ": " + Std.string(e);
		}
	}

	/** Forget decoded sounds, e.g. after the folder changes. */
	public static function clearCache():Void { cache = new Map<String, hxd.res.Sound>(); failedAt.clear(); }
}
