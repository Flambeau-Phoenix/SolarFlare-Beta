package solarflare.cdb;

import haxe.Json;
import solarflare.ui.ModPaths;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * CastleDB unit display names (`assets/cdb/unit-names.json` from Farever `data.cdb` unit sheet).
 */
class CdbUnitNames {
	static var ready:Bool = false;
	static var names = new Map<String, String>();
	static var ids:Array<String> = [];
	static var labels:Array<String> = [];

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

	public static function allIds():Array<String> {
		ensure();
		return ids;
	}

	public static function allLabels():Array<String> {
		ensure();
		return labels;
	}

	static function ensure():Void {
		if (ready)
			return;
		ready = true;
		ids = [];
		labels = [];
		var path = jsonPath();
		if (path == null)
			return;
		try {
			var raw:Dynamic = Json.parse(File.getContent(path));
			var list:Dynamic = Reflect.field(raw, "units");
			if (list == null)
				return;
			var arr:Array<Dynamic> = cast list;
			for (row in arr) {
				var uid = dynStr(Reflect.field(row, "id"));
				var nm = dynStr(Reflect.field(row, "name"));
				if (uid.length == 0)
					continue;
				if (nm.length == 0)
					nm = uid;
				names.set(uid.toLowerCase(), nm);
				ids.push(uid);
				labels.push(nm);
			}
		} catch (_:Dynamic) {}
	}

	static inline function jsonPath():String {
		return ModPaths.findCdbFile("unit-names.json");
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
