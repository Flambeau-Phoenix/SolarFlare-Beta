package solarflare.cdb;

import haxe.Json;
import solarflare.ui.ModPaths;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * Curated CastleDB display names for Geaux class signatures
 * (`assets/cdb/class-signatures.json` from Farever `data.cdb`).
 */
class CdbNames {
	static var ready:Bool = false;
	static var names = new Map<String, String>();

	public static function keep():Void {
		ensure();
	}

	public static function lookup(id:String):String {
		ensure();
		if (id == null || id.length == 0)
			return "";
		var n = names.get(id.toLowerCase());
		if (n == null)
			return "";
		return n;
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
			for (row in arr) {
				var sid = dynStr(Reflect.field(row, "id"));
				var nm = dynStr(Reflect.field(row, "name"));
				if (sid.length > 0 && nm.length > 0)
					names.set(sid.toLowerCase(), nm);
			}
		} catch (_:Dynamic) {}
	}

	static inline function jsonPath():String {
		return ModPaths.findCdbFile("class-signatures.json");
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
}
