package solarflare.cdb;

import haxe.Json;
import solarflare.ui.ModPaths;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * Curated CastleDB rows for Auras (`assets/cdb/aura-catalog.json`).
 * Duration / cooldown / maxStacks — live getters still win when present.
 */
class CdbAuraTable {
	static var ready:Bool = false;
	static var names = new Map<String, String>();
	static var durs = new Map<String, Float>();
	static var cds = new Map<String, Float>();
	static var stacks = new Map<String, Int>();
	static var gfxStem = new Map<String, String>();
	static var orderedIds:Array<String> = [];
	static var orderedLabels:Array<String> = [];

	public static function keep():Void {
		ensure();
	}

	public static function name(id:String):String {
		ensure();
		if (id == null || id.length == 0)
			return "";
		var n = names.get(norm(id));
		return n != null ? n : "";
	}

	/** Cached picker data initialized by keep(); callers must treat the arrays as read-only. */
	public static function allIds():Array<String> { ensure(); return orderedIds; }
	public static function allLabels():Array<String> { ensure(); return orderedLabels; }

	/** CDB telegraph / status length, or 0. */
	public static function duration(id:String):Float {
		ensure();
		if (id == null || id.length == 0)
			return 0;
		if (!durs.exists(norm(id)))
			return 0;
		return durs.get(norm(id));
	}

	public static function cooldown(id:String):Float {
		ensure();
		if (id == null || id.length == 0)
			return 0;
		if (!cds.exists(norm(id)))
			return 0;
		return cds.get(norm(id));
	}

	public static function maxStacks(id:String):Int {
		ensure();
		if (id == null || id.length == 0)
			return 0;
		if (!stacks.exists(norm(id)))
			return 0;
		return stacks.get(norm(id));
	}

	public static function iconStem(id:String):String {
		ensure();
		if (id == null || id.length == 0)
			return "";
		var g = gfxStem.get(norm(id));
		return g != null ? g : "";
	}

	static function ensure():Void {
		if (ready)
			return;
		ready = true;
		var path = jsonPath();
		if (path == null)
			return;
		try {
			var raw:Dynamic = Json.parse(File.getContent(path));
			var list:Dynamic = Reflect.field(raw, "skills");
			if (list == null)
				return;
			var arr:Array<Dynamic> = cast list;
			for (row in arr)
				put(row);
		} catch (_:Dynamic) {}
	}

	static function put(row:Dynamic):Void {
		if (row == null)
			return;
		var id = dynStr(Reflect.field(row, "id"));
		if (id.length == 0)
			return;
		var key = norm(id);
		var nm = dynStr(Reflect.field(row, "name"));
		if (!names.exists(key)) {
			orderedIds.push(id);
			orderedLabels.push(nm.length > 0 ? nm : id);
		}
		if (nm.length > 0)
			names.set(key, nm);
		var d = firstPos(dynFloat(Reflect.field(row, "duration")), dynFloat(Reflect.field(row, "observedDuration")),
			dynFloat(Reflect.field(row, "channelDuration")));
		if (d >= 0.5 && d <= 120)
			durs.set(key, d);
		var cd = dynFloat(Reflect.field(row, "cooldown"));
		if (cd >= 0.5 && cd <= 120)
			cds.set(key, cd);
		var ms = Std.int(dynFloat(Reflect.field(row, "maxStacks")));
		if (ms > 1)
			stacks.set(key, ms);
		var gfx:Dynamic = Reflect.field(row, "gfx");
		var file = dynStr(Reflect.field(gfx, "file"));
		if (file.length > 0)
			gfxStem.set(key, file);
	}

	static function firstPos(a:Float, b:Float, c:Float):Float {
		if (a >= 0.5)
			return a;
		if (b >= 0.5)
			return b;
		if (c >= 0.5)
			return c;
		return 0;
	}

	static function jsonPath():String {
		var candidates = new Array<String>();
		try candidates.push(Path.join([ModPaths.modDir(), "assets", "aura-catalog.json"])) catch (_:Dynamic) {}
		try candidates.push(Path.join([ModPaths.modDir(), "assets", "cdb", "aura-catalog.json"])) catch (_:Dynamic) {}
		try candidates.push(Path.join([ModPaths.modDir(), "cdb", "aura-catalog.json"])) catch (_:Dynamic) {}
		try {
			var exeDir = Path.directory(Sys.programPath());
			candidates.push(Path.join([exeDir, "hlx", "mods", "solarflare", "cdb", "aura-catalog.json"]));
		} catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "hlx", "mods", "solarflare", "cdb", "aura-catalog.json"]))
		catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "assets", "cdb", "aura-catalog.json"]))
		catch (_:Dynamic) {}
		for (c in candidates) {
			try {
				if (c != null && FileSystem.exists(c))
					return c;
			} catch (_:Dynamic) {}
		}
		return null;
	}

	static function norm(id:String):String {
		return id.toLowerCase();
	}

	static function dynStr(v:Dynamic):String {
		if (v == null)
			return "";
		try {
			return Std.string(v);
		} catch (_:Dynamic) {
			return "";
		}
	}

	static function dynFloat(v:Dynamic):Float {
		if (v == null)
			return 0;
		try {
			var f = Std.parseFloat(Std.string(v));
			if (Math.isNaN(f))
				return 0;
			return f;
		} catch (_:Dynamic) {
			return 0;
		}
	}
}
