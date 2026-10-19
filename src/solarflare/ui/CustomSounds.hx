package solarflare.ui;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * User sound files for canvas-layer cues, kept in `<mod>/custom_sounds/`. Layers store only the file stem, so
 * a share key never carries paths. Scans and imports run during observation, never while drawing.
 */
class CustomSounds {
	public static inline var FOLDER:String = "custom_sounds";
	public static inline var MAX_BYTES:Int = 2 * 1024 * 1024;
	public static var EXTENSIONS:Array<String> = ["wav", "ogg", "mp3"];
	/** Root used by tests; otherwise the installed mod's folder. */
	public static var dirOverride:String = null;
	public static var status(default, null):String = "Put .wav, .ogg or .mp3 files (2 MB max) in the folder, or import one.";

	static var listed:Array<String> = [];
	static var scanned = false;

	public static function dir():String {
		var root = dirOverride;
		if (root == null) {
			try root = ModPaths.modDir() catch (_:Dynamic) {}
			if (root == null || root.length == 0) root = Sys.getCwd();
		}
		var d = dirOverride != null ? root : Path.join([root, FOLDER]);
		try if (!FileSystem.exists(d)) FileSystem.createDirectory(d) catch (_:Dynamic) {}
		return d;
	}

	/** Cache-only: safe while drawing. */
	public static function names():Array<String> return listed;

	public static function hasScanned():Bool return scanned;

	static function validStem(stem:String):Bool {
		return stem != null && stem.length > 0 && stem.length <= 64 && stem.indexOf("/") < 0 && stem.indexOf("\\") < 0 && stem.indexOf("..") < 0 && stem.indexOf("\x00") < 0;
	}

	public static function refresh():Void {
		var out:Array<String> = [];
		var seen = new Map<String, Bool>();
		var skipped = 0;
		try {
			var d = dir();
			var files = FileSystem.readDirectory(d);
			files.sort(Reflect.compare);
			for (file in files) {
				var ext = Path.extension(file).toLowerCase();
				if (EXTENSIONS.indexOf(ext) < 0) continue;
				var stem = Path.withoutExtension(file);
				if (!validStem(stem)) { skipped++; continue; }
				try {
					var path = Path.join([d, file]);
					if (FileSystem.isDirectory(path)) continue;
					if (FileSystem.stat(path).size > MAX_BYTES) { skipped++; continue; }
				} catch (_:Dynamic) { skipped++; continue; }
				if (!seen.exists(stem.toLowerCase())) { seen.set(stem.toLowerCase(), true); out.push(stem); }
			}
			status = out.length + " sound" + (out.length == 1 ? "" : "s") + " available." + (skipped > 0 ? " Skipped " + skipped + " unsupported or oversized file(s)." : "");
		} catch (_:Dynamic) {
			status = "The custom_sounds folder could not be read.";
		}
		out.sort(function(a, b) return a.toLowerCase() < b.toLowerCase() ? -1 : (a.toLowerCase() > b.toLowerCase() ? 1 : 0));
		listed = out;
		scanned = true;
	}

	/** Absolute path for a stem, or null when the file is gone. Observe phase only. */
	public static function pathFor(stem:String):String {
		if (!validStem(stem)) return null;
		var d = dir();
		for (ext in EXTENSIONS) {
			var path = Path.join([d, stem + "." + ext]);
			try if (FileSystem.exists(path) && !FileSystem.isDirectory(path)) return path catch (_:Dynamic) {}
		}
		return null;
	}

	static function magicOk(b:haxe.io.Bytes, ext:String):Bool {
		if (b.length < 12) return false;
		return switch (ext) {
			case "wav": b.get(0) == 0x52 && b.get(1) == 0x49 && b.get(2) == 0x46 && b.get(3) == 0x46 && b.get(8) == 0x57 && b.get(9) == 0x41 && b.get(10) == 0x56 && b.get(11) == 0x45;
			case "ogg": b.get(0) == 0x4F && b.get(1) == 0x67 && b.get(2) == 0x67 && b.get(3) == 0x53;
			case "mp3": (b.get(0) == 0x49 && b.get(1) == 0x44 && b.get(2) == 0x33) || (b.get(0) == 0xFF && (b.get(1) & 0xE0) == 0xE0);
			default: false;
		};
	}

	/** Copy a sound into the folder and return its stem. Never overwrites; throws a user-facing message on bad input. */
	public static function importFile(raw:String):String {
		var src = raw == null ? "" : StringTools.trim(raw);
		if (src.length >= 2 && src.charAt(0) == '"' && src.charAt(src.length - 1) == '"') src = src.substr(1, src.length - 2);
		if (src.length == 0) throw "Paste the full path to a .wav, .ogg or .mp3 file.";
		var ext = Path.extension(src).toLowerCase();
		if (EXTENSIONS.indexOf(ext) < 0) throw "Only " + EXTENSIONS.join(", ") + " sounds are supported.";
		if (!FileSystem.exists(src) || FileSystem.isDirectory(src)) throw "File not found: " + src;
		if (FileSystem.stat(src).size > MAX_BYTES) throw "Sound is larger than 2 MB.";
		var bytes = File.getBytes(src);
		if (!magicOk(bytes, ext)) throw "That file is not a valid " + ext.toUpperCase() + " sound.";
		var base = sanitize(Path.withoutExtension(Path.withoutDirectory(src)));
		var stem = base, n = 2, d = dir();
		while (FileSystem.exists(Path.join([d, stem + "." + ext])) || names().indexOf(stem) >= 0) stem = base + "_" + (n++);
		File.saveBytes(Path.join([d, stem + "." + ext]), bytes);
		refresh();
		return stem;
	}

	static function sanitize(name:String):String {
		var b = new StringBuf();
		for (i in 0...name.length) {
			var c = name.charCodeAt(i);
			var ok = (c >= "a".code && c <= "z".code) || (c >= "A".code && c <= "Z".code) || (c >= "0".code && c <= "9".code) || c == "_".code || c == "-".code || c == " ".code;
			b.add(ok ? name.charAt(i) : "_");
		}
		var s = StringTools.trim(b.toString());
		if (s.length > 48) s = s.substr(0, 48);
		return s.length > 0 ? s : "sound";
	}
}
