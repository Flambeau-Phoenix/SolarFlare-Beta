package solarflare.debug;

import sys.FileSystem;
import sys.io.File;

/**
 * Unique FieldWalk winners → JSONL so we can promote typed helpers.
 * Arm Payload probe or Resolution ledger (F6 ImGui debug).
 */
@:keep
class FieldWalkLog {
	static var seen:Map<String, Bool> = new Map();
	static var buf:Array<String> = [];
	static var jsonlPath:String = "";
	public static var lastPath:String = "";
	static var ready:Bool = false;
	static var lastFlush:Float = 0;
	static var dumpedParents:Bool = false;

	public static function keep():Void {
		ensure();
	}

	public static function noteWin(typeName:String, field:String, step:String):Void {
		if (!armed())
			return;
		ensure();
		dumpParentsOnce();
		var t = typeName != null ? typeName : "";
		var f = field != null ? field : "";
		var s = step != null ? step : "";
		var key = t + "#" + f + "#" + s;
		if (seen.exists(key))
			return;
		seen.set(key, true);
		buf.push('{"type":"fieldwalk-win","hlType":"${esc(t)}","field":"${esc(f)}","step":"${esc(s)}"}');
		if (buf.length >= 12)
			flush();
	}

	public static function tick():Void {
		if (!armed())
			return;
		ensure();
		var now = stamp();
		if (buf.length > 0 && now - lastFlush >= 1.5)
			flush();
	}

	public static function armed():Bool {
		try {
			if (PayloadProbe.armed())
				return true;
		} catch (_:Dynamic) {}
		try {
			if (ResolutionLedger.armed())
				return true;
		} catch (_:Dynamic) {}
		return false;
	}

	static function dumpParentsOnce():Void {
		if (dumpedParents)
			return;
		dumpedParents = true;
		try {
			var pairs = solarflare.FieldWalkGraph.parentPairs;
			if (pairs == null)
				return;
			for (p in pairs)
				buf.push('{"type":"fieldwalk-parent","pair":"${esc(p)}"}');
		} catch (_:Dynamic) {}
	}

	static function flush():Void {
		lastFlush = stamp();
		if (buf.length == 0 || jsonlPath.length == 0)
			return;
		var chunk = buf.join("\n") + "\n";
		buf = [];
		try {
			var existing = "";
			if (FileSystem.exists(jsonlPath))
				existing = File.getContent(jsonlPath);
			File.saveContent(jsonlPath, existing + chunk);
		} catch (_:Dynamic) {}
	}

	static function ensure():Void {
		if (ready)
			return;
		ready = true;
		jsonlPath = solarflare.ui.SettingsStore.logFile("fieldwalk-wins.jsonl");
		lastPath = jsonlPath;
	}

	static function esc(s:String):String {
		if (s == null)
			return "";
		return StringTools.replace(StringTools.replace(s, "\\", "\\\\"), "\"", "\\\"");
	}

	static function stamp():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}
}
