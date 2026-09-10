package solarflare.combatlog;

import imgui.ref.BoolRef;

/**
 * JSONL combat recording under hlx/mods/solarflare/logs/combatlog/. Buffered; flushed from observe.
 */
class CombatLogRecorder {
	public static inline var IDLE_S:Float = 30;

	public static var enabled = new BoolRef(true);
	public static var lastPath:String = "";
	public static var lastStatus:String = "record idle";
	public static var written:Int = 0;

	static var buf:Array<String> = [];
	static var sessionPath:String = "";
	static var lastFlushAt:Float = 0;
	static var lastEventAt:Float = 0;

	public static function queue(line:CombatLogLine):Void {
		if (!enabled.get() || line == null)
			return;
		ensureSession(false);
		try
			buf.push(line.toJson())
		catch (_:Dynamic) {}
		lastEventAt = stamp();
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
			var out = sys.io.File.append(sessionPath);
			out.writeString(chunk);
			out.close();
			written += chunk.split("\n").length - 1;
			lastFlushAt = stamp();
			lastStatus = "recording " + written + "  " + fileName();
		} catch (_:Dynamic) {
			lastStatus = "record fail";
		}
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
