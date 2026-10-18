package solarflare.ui;

import format.png.Reader;
import format.png.Tools;
import haxe.io.BytesInput;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * User-supplied PNGs from a saved folder, with `<mod>/custom_images/` as a legacy fallback.
 * Elements keep portable `custom:<stem>` keys. Scans/imports run during observation only.
 */
class CustomImages {
	public static inline var FOLDER:String = "custom_images";
	public static inline var PREFIX:String = CustomImageKey.PREFIX;
	public static inline var MAX_DIM:Int = 1024;
	public static inline var MAX_BYTES:Int = 4 * 1024 * 1024;

	static var cachedDir:String = null;
	static var listed:Array<String> = [];
	static var scanned = false;
	static var refreshRequested = true;
	static var paths = new Map<String, String>();
	static var fingerprints = new Map<String, String>();
	public static var folder(default, null):String = "";
	public static var generation(default, null):Int = 0;
	public static var displayDir(default, null):String = FOLDER;
	public static var status(default, null):String = "Choose an images folder, or use the default custom_images folder.";
	public static var folderError(default, null):Bool = false;

	/** Default folder is created only by observe-phase operations, never by drawing. */
	static function defaultDir():String {
		if (cachedDir != null) return cachedDir;
		var root:String = null;
		try root = ModPaths.modDir() catch (_:Dynamic) {}
		if (root == null || root.length == 0) root = Sys.getCwd();
		var d = Path.join([root, FOLDER]);
		try if (!FileSystem.exists(d)) FileSystem.createDirectory(d) catch (_:Dynamic) {}
		cachedDir = d;
		return d;
	}
	public static function dir():String return folder.length > 0 ? folder : defaultDir();
	public static function dump():Dynamic return {folder:folder};
	/** Loading a preference must preserve disconnected drives without failing the whole settings load. */
	public static function apply(data:Dynamic):Void {
		var raw:Dynamic = data == null ? null : Reflect.field(data, "folder");
		var next = Std.isOfType(raw, String) ? cleanPath(cast raw) : "";
		configure(next);
	}
	static function configure(next:String):Void {
		if (folder != next) { folder = next; generation++; }
		refreshRequested = true;
	}
	/** Called from a queued explicit user action. Invalid candidates leave the current choice intact. */
	public static function useFolder(raw:String):Bool {
		var next = cleanPath(raw);
		if (next.length > 0) {
			if (!absolute(next)) throw "Paste the full path to an existing folder.";
			if (!FileSystem.exists(next) || !FileSystem.isDirectory(next)) throw "Folder not found: " + next;
			try FileSystem.readDirectory(next) catch (_:Dynamic) throw "Folder could not be read: " + next;
			next = FileSystem.fullPath(next);
		}
		var changed = folder != next;
		configure(next); refresh();
		return changed;
	}
	static function cleanPath(raw:String):String {
		var path = raw == null ? "" : StringTools.trim(raw);
		if (path.length >= 2 && path.charAt(0) == '"' && path.charAt(path.length - 1) == '"') path = path.substr(1, path.length - 2);
		return path;
	}
	static function absolute(path:String):Bool {
		if (!Path.isAbsolute(path) || path.indexOf("\x00") >= 0) return false;
		// Haxe considers C:relative absolute; Windows resolves it against a drive-specific cwd.
		return path.charAt(1) != ":" || path.charAt(2) == "/" || path.charAt(2) == "\\";
	}
	public static function requestRefresh():Void refreshRequested = true;
	public static function hasPending():Bool return refreshRequested;
	public static function observe():Void { if (refreshRequested) refresh(); }

	public static inline function key(stem:String):String return CustomImageKey.key(stem);

	public static function stemOf(key:String):String {
		return CustomImageKey.stemOf(key);
	}

	/** Absolute path for a stem, or null when the file is gone. Observe-phase only. */
	public static function pathFor(stem:String):String {
		if (!validStem(stem)) return null;
		if (!scanned || refreshRequested) refresh();
		var path = paths.get(stem.toLowerCase());
		try return path != null && FileSystem.exists(path) && !FileSystem.isDirectory(path) ? path : null catch (_:Dynamic) return null;
	}

	/** Cache-only: safe from builder drawing, including the first frame. */
	public static function names():Array<String> return listed;

	public static function refresh():Void {
		refreshRequested = false;
		var nextPaths = new Map<String, String>();
		var nextPrints = new Map<String, String>();
		var changes = new Map<String, Bool>();
		var labels = new Map<String, String>();
		var out:Array<String> = [];
		var defaultPath = defaultDir();
		displayDir = dir(); folderError = false;
		var skipped = 0;
		function scan(directory:String):Void {
			var files = FileSystem.readDirectory(directory);
			files.sort(Reflect.compare);
			for (file in files) {
				if (Path.extension(file).toLowerCase() != "png") continue;
				var stem = Path.withoutExtension(file);
				if (!validStem(stem)) { skipped++; continue; }
				try {
					var path = Path.join([directory, file]);
					if (FileSystem.isDirectory(path)) continue;
					var stat = FileSystem.stat(path);
					if (stat.size > MAX_BYTES) { skipped++; continue; }
					var id = stem.toLowerCase();
					nextPaths.set(id, path); labels.set(id, stem);
					nextPrints.set(id, path + "|" + stat.size + "|" + stat.mtime.getTime());
				} catch (_:Dynamic) { skipped++; }
			}
		}
		try scan(defaultPath) catch (_:Dynamic) { if (folder.length == 0) folderError = true; }
		try {
			if (folder.length > 0) {
				if (!absolute(folder)) throw "Folder path must be absolute";
				// Selected-folder names override matching legacy names; other legacy keys survive.
				scan(folder);
			}
		} catch (_:Dynamic) { folderError = true; }
		for (id => label in labels) {
			out.push(label);
			changes.set(id, fingerprints.get(id) != nextPrints.get(id));
		}
		for (id in paths.keys()) if (!nextPaths.exists(id)) changes.set(id, true);
		GameIcons.refreshCustomImages(changes);
		out.sort(function(a, b) return a.toLowerCase() < b.toLowerCase() ? -1 : (a.toLowerCase() > b.toLowerCase() ? 1 : 0));
		listed = out; paths = nextPaths; fingerprints = nextPrints; scanned = true;
		status = folderError ? (folder.length == 0 ? "The default custom_images folder could not be read. Choose another images folder."
			: "Selected folder is unavailable. Images from the default custom_images folder remain available.")
			: listed.length + " PNG image(s) available. Original custom_images files remain available.";
		if (skipped > 0) status += " Skipped " + skipped + " unsupported, unreadable or oversized file(s).";
	}
	static function validStem(stem:String):Bool return stem != null && stem.length > 0 && stem.indexOf("/") < 0 && stem.indexOf("\\") < 0 && stem.indexOf("..") < 0 && stem.indexOf("\x00") < 0;

	/**
	 * Copy a PNG into the folder and return its stem. Throws a user-facing message on bad input.
	 * Never overwrites: a taken name gets a numeric suffix, so cached textures stay valid.
	 */
	public static function importFile(rawPath:String):String {
		var src = rawPath != null ? StringTools.trim(rawPath) : "";
		// Explorer's "Copy as path" wraps the path in quotes.
		if (src.length >= 2 && src.charAt(0) == '"' && src.charAt(src.length - 1) == '"') src = src.substr(1, src.length - 2);
		if (src.length == 0) throw "Paste the full path to a .png file.";
		if (Path.extension(src).toLowerCase() != "png") throw "Only .png images are supported.";
		if (!FileSystem.exists(src) || FileSystem.isDirectory(src)) throw "File not found: " + src;
		var stat = FileSystem.stat(src);
		if (stat.size > MAX_BYTES) throw "Image is larger than 4 MB.";
		var bytes = File.getBytes(src);
		var header = try Tools.getHeader(new Reader(new BytesInput(bytes)).read()) catch (_:Dynamic) null;
		if (header == null) throw "Not a readable PNG file.";
		if (header.width > MAX_DIM || header.height > MAX_DIM)
			throw "Image is " + header.width + "x" + header.height + "; the limit is " + MAX_DIM + "x" + MAX_DIM + ".";
		var base = sanitize(Path.withoutExtension(Path.withoutDirectory(src)));
		var stem = base;
		var n = 2;
		while (FileSystem.exists(Path.join([dir(), stem + ".png"]))) stem = base + "_" + (n++);
		File.saveBytes(Path.join([dir(), stem + ".png"]), bytes);
		refresh();
		return stem;
	}

	static function sanitize(name:String):String {
		var b = new StringBuf();
		for (i in 0...name.length) {
			var c = name.charCodeAt(i);
			var ok = (c >= "a".code && c <= "z".code) || (c >= "A".code && c <= "Z".code) || (c >= "0".code && c <= "9".code)
				|| c == "_".code || c == "-".code;
			b.add(ok ? name.charAt(i) : "_");
		}
		var s = b.toString();
		if (s.length > 48) s = s.substr(0, 48);
		return s.length > 0 ? s : "image";
	}
}
