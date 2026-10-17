package solarflare.aura;

import solarflare.getrifty.GetRifty.GetRiftyCache;

/**
 * The map the local player is in, as one frozen string. Bosses never appear in the open world, so the map is
 * what arms an Aura Set. Sampled from the existing background pass while something demands it (a map-bound
 * set, the recorder, the Aura Builder): one typed read and a string compare, with `revision` bumping only when
 * the map actually changes. Empty means unknown (title screen, loading); it is never an error.
 */
class AuraMapContext {
	static inline var POLL_S:Float = 0.5;

	public static var mapId(default, null):String = "";
	/** Bumps on every change of `mapId`; consumers rebuild only when it differs from what they last saw. */
	public static var revision(default, null):Int = 0;
	static var nextAt:Float = -1e9;

	public static function observe(app:Dynamic, now:Float):Void {
		// A clock that moved backwards (reload) must not stall the poll.
		if (now < nextAt && nextAt - now <= POLL_S * 2)
			return;
		nextAt = now + POLL_S;
		var id = read(app);
		if (id == mapId)
			return;
		mapId = id;
		revision++;
	}

	public static function reset():Void {
		nextAt = -1e9;
		if (mapId.length > 0) {
			mapId = "";
			revision++;
		}
	}

	/** Display text for a map id. Raw ids are shown as-is until a friendly table exists. */
	public static function label(id:String):String
		return id == null || id.length == 0 ? "Unknown map" : id;

	static function read(app:Dynamic):String {
		try {
			var layer:Dynamic = GetRiftyCache.resolveLayer(app);
			if (layer == null)
				return "";
			var gl:st.GameLayer = cast layer;
			var id:String = null;
			// Config carries the clean map id; the level getter is the fallback while config is empty.
			try {
				var cfg = gl.config;
				if (cfg != null)
					id = cfg.mapId;
			} catch (_:Dynamic) {}
			if (id == null || id.length == 0) {
				try id = gl.getMapId() catch (_:Dynamic) {}
			}
			return AuraSetDef.normalizeMap(id);
		} catch (_:Dynamic) {
			return "";
		}
	}
}
