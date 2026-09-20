package solarflare.combatlog;

import imgui.ref.BoolRef;

/**
 * JSONL combat recording under hlx/mods/solarflare/logs/combatlog/.
 *
 * Recording is passive: it runs whenever `enabled` is true and does not depend on the
 * combat overlay being on screen. Writes are flushed on the recorder's own cadence from
 * `queue`, so a hidden meter or a stalled/crashed frame loop cannot discard queued combat.
 */
class CombatLogRecorder {
	public static inline var IDLE_S:Float = 30;
	/** Opportunistic flush cadence so recording never rides on the draw/observe loop. */
	public static inline var FLUSH_S:Float = 0.5;
	/** Hard per-session cap; once exceeded the oldest lines are dropped to keep the newest. */
	public static inline var MAX_BYTES:Int = 5 * 1024 * 1024;

	/** Fresh installs are silent; SettingsStore restores an explicit persisted opt-in. */
	public static var enabled = new BoolRef(false);
	public static var lastPath:String = "";
	public static var lastStatus:String = "record idle";
	public static var written:Int = 0;
	public static var trimmed:Int = 0;

	static var buf:Array<String> = [];
	static var bufBytes:Int = 0;
	static var sessionPath:String = "";
	static var lastFlushAt:Float = 0;
	static var lastEventAt:Float = 0;

	public static function queue(line:CombatLogLine):Void {
		if (!enabled.get() || line == null)
			return;
		ensureSession(false);
		try {
			var json = line.toJson();
			buf.push(json);
			bufBytes += json.length + 1;
		} catch (_:Dynamic) {}
		lastEventAt = stamp();
		// Passive durability: flush on our own cadence. A hidden overlay or a stalled
		// frame loop (modal exception dialog) must never discard queued combat.
		var now = stamp();
		if (bufBytes >= MAX_BYTES || now - lastFlushAt >= FLUSH_S)
			flush();
		// If the disk write failed we still bound RAM rather than grow forever.
		if (bufBytes > MAX_BYTES)
			trimBuf();
	}

	public static function tick():Void {
		var now = stamp();
		if (sessionPath.length > 0 && lastEventAt > 0 && now - lastEventAt >= IDLE_S)
			endSession();
		if (buf.length == 0)
			return;
		if (buf.length >= 24 || now - lastFlushAt >= 0.4)
			flush();
	}

	public static function flush():Void {
		if (buf.length == 0)
			return;
		ensureSession(false);
		if (sessionPath.length == 0)
			return;
		try {
			var chunk = buf.join("\n") + "\n";
			buf = [];
			bufBytes = 0;
			var out = sys.io.File.append(sessionPath);
			out.writeString(chunk);
			out.close();
			written += chunk.split("\n").length - 1;
			lastFlushAt = stamp();
			enforceCap();
			lastStatus = "recording " + written + "  " + fileName()
				+ (trimmed > 0 ? "  (trimmed " + trimmed + ")" : "");
		} catch (_:Dynamic) {
			lastStatus = "record fail";
		}
	}

	/** Bounds in-RAM queue when a disk write fails, so a stuck loop cannot leak. */
	static function trimBuf():Void {
		while (bufBytes > MAX_BYTES && buf.length > 0) {
			var first = buf.shift();
			bufBytes -= first.length + 1;
			trimmed++;
		}
	}

	/** Hard size cap: drop the oldest bytes so one session can never grow unbounded. */
	static function enforceCap():Void {
		if (sessionPath.length == 0)
			return;
		try {
			if (!sys.FileSystem.exists(sessionPath))
				return;
			if (sys.FileSystem.stat(sessionPath).size <= MAX_BYTES)
				return;
			var content = sys.io.File.getContent(sessionPath);
			var cut = content.length - MAX_BYTES;
			if (cut <= 0)
				return;
			var nl = content.indexOf("\n", cut);
			var head = nl >= 0 ? content.substr(nl + 1) : content.substr(cut);
			trimmed += nl >= 0 ? nl + 1 : cut;
			sys.io.File.saveContent(sessionPath, head);
		} catch (_:Dynamic) {}
	}

	public static function endSession():Void {
		flush();
		if (sessionPath.length == 0)
			return;
		lastStatus = "saved " + fileName() + "  " + written + " events";
		sessionPath = "";
	}

	public static function newSession():Void {
		endSession();
		ensureSession(true);
	}

	static function ensureSession(forceNew:Bool):Void {
		if (!forceNew && sessionPath.length > 0)
			return;
		if (forceNew && sessionPath.length > 0)
			endSession();
		var logDir = logDir();
		if (logDir == null)
			return;
		try {
			if (!sys.FileSystem.exists(logDir))
				sys.FileSystem.createDirectory(logDir);
		} catch (_:Dynamic) {}
		var d = Date.now();
		var name = "clog-"
			+ pad(d.getFullYear(), 4) + pad(d.getMonth() + 1, 2) + pad(d.getDate(), 2)
			+ "-" + pad(d.getHours(), 2) + pad(d.getMinutes(), 2) + pad(d.getSeconds(), 2)
			+ ".jsonl";
		sessionPath = haxe.io.Path.join([logDir, name]);
		lastPath = sessionPath;
		written = 0;
		try {
			var header = haxe.Json.stringify({
				type: "session",
				v: 1,
				mod: "solarflare",
				at: d.toString()
			});
			sys.io.File.saveContent(sessionPath, header + "\n");
			lastStatus = "recording " + name;
			lastEventAt = stamp();
		} catch (_:Dynamic) {
			sessionPath = "";
			lastStatus = "record fail (create)";
		}
	}

	static function logDir():String {
		try {
			solarflare.ui.SettingsStore.migrateCombatLogs();
			return solarflare.ui.SettingsStore.logSubdir("combatlog");
		} catch (_:Dynamic) {
			return null;
		}
	}

	static function fileName():String {
		if (lastPath.length == 0)
			return "";
		return haxe.io.Path.withoutDirectory(lastPath);
	}

	static function pad(n:Int, w:Int):String {
		var s = Std.string(n);
		while (s.length < w)
			s = "0" + s;
		return s;
	}

	static function stamp():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}
}
