package solarflare.geaux;

import haxe.Json;
import sys.io.File;
import solarflare.ui.SettingsStore;

/**
 * Simple static logger that records mutation events for the Geaux system.
 * Logs are written as JSON lines to `logs/geaux.log`.
 * The logger is active only in debug builds (`#if debug`).
 */
class GeauxLog {
	static var seq:Int = 0;
    /**
     * Record a mutation event.
     * @param event   Short identifier such as "ASSIGN_CELL", "PROFILE_STORE".
     * @param source  Caller identifier for easier debugging.
     * @param data    Arbitrary snapshot data (will be JSON‑stringified).
     */
	public static inline function log(event:String, source:String, data:Dynamic):Void {
		#if debug
		var payload = {
			seq: ++seq,
			timestamp: Date.now().getTime(),
			event: event,
			source: source,
			data: data
		};
		var path = SettingsStore.logFile("geaux.log");
		if (path == null || path.length == 0)
			return;
		try {
			var out = File.append(path);
			out.writeString(Json.stringify(payload) + "\n");
			out.close();
		} catch (_:Dynamic) {}
		#end
	}
}
