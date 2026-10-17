package solarflare.ui;

import format.png.Reader;
import format.png.Tools;
import haxe.io.BytesInput;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * User-supplied PNGs for Aura canvases. Files live in `<mod>/custom_images/`; an element
 * references one as `custom:<stem>` and GameIcons loads it through its normal queued path.
 * Folder scans run only on explicit edges (picker opened, Refresh, import), never per frame.
 */
class CustomImages {
	public static inline var FOLDER:String = "custom_images";
	public static inline var MAX_DIM:Int = 1024;
	public static inline var MAX_BYTES:Int = 4 * 1024 * 1024;

	static var cachedDir:String = null;
	static var listed:Array<String> = [];
	static var scanned = false;

	public static function dir():String {
		if (cachedDir != null) return cachedDir;
		var root:String = null;
		try root = ModPaths.modDir() catch (_:Dynamic) {}
		if (root == null || root.length == 0) root = Sys.getCwd();
		var d = Path.join([root, FOLDER]);
		try if (!FileSystem.exists(d)) FileSystem.createDirectory(d) catch (_:Dynamic) {}
		cachedDir = d;
		return d;
	}

	public static inline function key(stem:String):String return solarflare.aura.AuraCanvasElement.CUSTOM_PREFIX + stem;

	public static function stemOf(key:String):String {
		var p = solarflare.aura.AuraCanvasElement.CUSTOM_PREFIX;
		return key != null && StringTools.startsWith(key, p) ? key.substr(p.length) : "";
	}

	/** Absolute path for a stem, or null when the file is gone. Observe-phase only. */
	public static function pathFor(stem:String):String {
		if (stem == null || stem.length == 0 || stem.indexOf("/") >= 0 || stem.indexOf("\\") >= 0 || stem.indexOf("..") >= 0)
			return null;
		var p = Path.join([dir(), stem + ".png"]);
		try return FileSystem.exists(p) ? p : null catch (_:Dynamic) return null;
	}

	/** Sorted stems from the last scan; scans once on first use. */
	public static function names():Array<String> {
		if (!scanned) refresh();
		return listed;
	}

	public static function refresh():Void {
		scanned = true;
		var out:Array<String> = [];
		try {
			for (f in FileSystem.readDirectory(dir())) {
				if (Path.extension(f).toLowerCase() == "png") out.push(Path.withoutExtension(f));
			}
		} catch (_:Dynamic) {}
		out.sort(function(a, b) return a.toLowerCase() < b.toLowerCase() ? -1 : (a.toLowerCase() > b.toLowerCase() ? 1 : 0));
		listed = out;
	}

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

	/** Open the folder in Explorer so users can drop files in directly. */
	public static function openFolder():Void {
		try new sys.io.Process("explorer.exe", [dir()]).close() catch (_:Dynamic) {}
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
