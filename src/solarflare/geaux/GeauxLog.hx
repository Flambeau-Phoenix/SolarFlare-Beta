package solarflare.geaux;

import haxe.Json;
import sys.io.File;
import solarflare.ui.SettingsStore;

/**
 * Simple static logger that records mutation events for the Geaux system.
 * Logs are written as JSON lines to `logs/geaux.log`.
 * The logger is active only in explicit telemetry builds. Mutation paths only
 * enqueue; TelemetryKernel owns batched disk writes.
 */
class GeauxLog {
	static var seq:Int = 0;
	static var buf:Array<String> = [];
	static var lastFlush:Float = 0;
    /**
     * Record a mutation event.
     * @param event   Short identifier such as "ASSIGN_CELL", "PROFILE_STORE".
     * @param source  Caller identifier for easier debugging.
     * @param data    Arbitrary snapshot data (will be JSON‑stringified).
     */
	public static inline function log(event:String, source:String, data:Dynamic):Void {
		#if solarflare_telemetry
		var payload = {
			seq: ++seq,
			timestamp: Date.now().getTime(),
			event: event,
			source: source,
			data: data
		};
		buf.push(Json.stringify(payload));
		#end
	}

	public static function tick():Void {
		#if solarflare_telemetry
		if (buf.length == 0)
			return;
		var now = haxe.Timer.stamp();
		if (buf.length < 32 && now - lastFlush < 1.0)
			return;
		var path = SettingsStore.logFile("geaux.log");
		if (path == null || path.length == 0)
			return;
		try {
			var chunk = buf.join("\n") + "\n";
			buf = [];
			var out = File.append(path);
			out.writeString(chunk);
			out.close();
			lastFlush = now;
			solarflare.debug.LogRotation.enforce(path);
		} catch (_:Dynamic) {}
		#end
	}
}
