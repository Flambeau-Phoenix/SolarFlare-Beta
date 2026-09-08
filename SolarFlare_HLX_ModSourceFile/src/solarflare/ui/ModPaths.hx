package solarflare.ui;

import haxe.io.Path;
import sys.FileSystem;

class ModPaths {
	static var cachedModDir:String = null;

	public static function resetCache():Void {
		cachedModDir = null;
	}

	public static function modDir():String {
		if (cachedModDir != null)
			return cachedModDir;
		var starts:Array<String> = [];
		try addUnique(starts, Path.directory(Sys.programPath())) catch (_:Dynamic) {}
		try addUnique(starts, Sys.getCwd()) catch (_:Dynamic) {}
		for (start in starts) {
			var root = start;
			for (_ in 0...6) {
				var direct = findLoadedMod(root);
				if (direct != null) {
					cachedModDir = direct;
					return cachedModDir;
				}
				var parent = Path.directory(root);
				if (parent == null || parent.length == 0 || parent == root)
					break;
				root = parent;
			}
		}
		var base = starts.length > 0 ? starts[0] : ".";
		cachedModDir = Path.join([base, "hlx", "mods", "SolarFlare"]);
		return cachedModDir;
	}

	public static inline function child(name:String):String
		return Path.join([modDir(), name]);

	static function findLoadedMod(root:String):String {
		if (root == null || root.length == 0)
			return null;
		if (hasModule(root))
			return root;
		var mods = Path.join([root, "hlx", "mods"]);
		try {
			if (!FileSystem.exists(mods) || !FileSystem.isDirectory(mods))
				return null;
			var fallback:String = null;
			for (name in FileSystem.readDirectory(mods)) {
				var dir = Path.join([mods, name]);
				if (!hasModule(dir))
					continue;
				if (name.toLowerCase() == "solarflare")
					return dir;
				if (fallback == null)
					fallback = dir;
			}
			return fallback;
		} catch (_:Dynamic) {
			return null;
		}
	}

	static function hasModule(dir:String):Bool {
		try
			return FileSystem.exists(Path.join([dir, "solarflare.hl"]))
		catch (_:Dynamic)
			return false;
	}

	static function addUnique(out:Array<String>, value:String):Void {
		if (value == null || value.length == 0)
			return;
		for (existing in out)
			if (existing == value)
				return;
		out.push(value);
	}
}
