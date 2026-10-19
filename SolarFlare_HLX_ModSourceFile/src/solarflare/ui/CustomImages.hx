package solarflare.ui;

import format.png.Reader;
import format.png.Tools;
import haxe.io.BytesInput;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

typedef ImportReport = {imported:Array<String>, errors:Array<String>};

/**
 * User-supplied PNGs from a saved folder, with `<mod>/custom_images/` as a legacy fallback.
 * Elements keep portable `custom:<stem>` keys. Scans/imports run during observation only.
 */
class CustomImages {
	public static inline var FOLDER:String = "custom_images";
	public static inline var PREFIX:String = CustomImageKey.PREFIX;
	public static inline var MAX_DIM:Int = 1024;
	public static inline var MAX_BYTES:Int = 4 * 1024 * 1024;
	/** Largest file accepted for import or conversion: it is scaled and re-encoded, so it may exceed MAX_BYTES. */
	public static inline var MAX_SOURCE_BYTES:Int = 32 * 1024 * 1024;
	static var CONVERTIBLE:Array<String> = ["jpg", "jpeg", "gif", "bmp", "tga"];
	/** Files in the active folders that cannot be used as they are (other formats, or too big), shown as a fix-it offer. */
	public static var fixable(default, null):Int = 0;

	static var cachedDir:String = null;
	/** Optional root used by filesystem tests; otherwise follows the installed mod. */
	public static var shareRootOverride:String=null;
	public static function shareDir():String return shareRootOverride!=null ? shareRootOverride : Path.join([ModPaths.modDir(),"aura_shares"]);
	public static function managedDir():String return Path.join([shareDir(),"_assets"]);
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
		fixable = 0;
		function scan(directory:String,managed:Bool=false):Void {
			var files = FileSystem.readDirectory(directory);
			files.sort(Reflect.compare);
			for (file in files) {
				var ext = Path.extension(file).toLowerCase();
				if (ext != "png") {
					if (!managed && CONVERTIBLE.indexOf(ext) >= 0 && !converted(directory, Path.withoutExtension(file), ext)) fixable++;
					continue;
				}
				var stem = Path.withoutExtension(file);
				if (!validStem(stem)) { skipped++; continue; }
				if (managed && !CustomImageKey.isManagedStem(stem)) continue;
				if (!managed && CustomImageKey.isManagedStem(stem)) continue;
				try {
					var path = Path.join([directory, file]);
					if (FileSystem.isDirectory(path)) continue;
					var stat = FileSystem.stat(path);
					if (stat.size > MAX_BYTES) { skipped++; if (!managed && !converted(directory, stem, "png")) fixable++; continue; }
					if (!managed && !converted(directory, stem, "png")) {
						var dims = pngSize(path);
						if (dims != null && (dims.w > MAX_DIM || dims.h > MAX_DIM)) fixable++;
					}
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
		// Managed, content-addressed share keys must not be shadowed by an images-folder choice.
		try { var managed=managedDir(); if(FileSystem.exists(managed) && FileSystem.isDirectory(managed)) scan(managed,true); } catch(_:Dynamic) {}
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
	/** Width and height from a PNG header without decoding it, or null. */
	static function pngSize(path:String):{w:Int, h:Int} {
		var f:sys.io.FileInput = null;
		try {
			f = File.read(path, true);
			var b = haxe.io.Bytes.alloc(24);
			var got = f.readBytes(b, 0, 24);
			f.close(); f = null;
			if (got < 24 || b.get(0) != 0x89 || b.get(1) != 0x50 || b.get(2) != 0x4E || b.get(3) != 0x47) return null;
			return {w: (b.get(16) << 24) | (b.get(17) << 16) | (b.get(18) << 8) | b.get(19), h: (b.get(20) << 24) | (b.get(21) << 16) | (b.get(22) << 8) | b.get(23)};
		} catch (_:Dynamic) {
			// Always release the handle: a leaked one blocks deleting or replacing the file on Windows.
			if (f != null) try f.close() catch (_:Dynamic) {}
			return null;
		}
	}

	/** A usable PNG already exists for this source, so it no longer needs converting. */
	static function converted(directory:String, stem:String, ext:String):Bool {
		return ext == "png" ? FileSystem.exists(Path.join([directory, stem + "_resized.png"]))
			: FileSystem.exists(Path.join([directory, stem + ".png"])) || FileSystem.exists(Path.join([directory, sanitize(stem) + ".png"]));
	}

	/**
	 * Make unusable files in the images folder usable: other formats become PNG, and PNGs over the size or
	 * 1024 px limits are scaled down into a new `_resized` copy. Originals are never touched.
	 */
	public static function convertFolder():ImportReport {
		var report:ImportReport = {imported: [], errors: []};
		var d = dir();
		var files = try FileSystem.readDirectory(d) catch (_:Dynamic) [];
		files.sort(Reflect.compare);
		for (file in files) {
			var ext = Path.extension(file).toLowerCase(), stem = Path.withoutExtension(file), path = Path.join([d, file]);
			try {
				if (FileSystem.isDirectory(path) || CustomImageKey.isManagedStem(stem)) continue;
				var base:String;
				if (ext == "png") {
					var oversized = FileSystem.stat(path).size > MAX_BYTES;
					if (!oversized) { var dims = pngSize(path); oversized = dims != null && (dims.w > MAX_DIM || dims.h > MAX_DIM); }
					if (!oversized || converted(d, stem, "png")) continue;
					base = stem + "_resized";
				} else if (CONVERTIBLE.indexOf(ext) >= 0) {
					if (converted(d, stem, ext)) continue;
					base = sanitize(stem);
				} else continue;
				if (FileSystem.stat(path).size > MAX_SOURCE_BYTES) throw "larger than 32 MB";
				var png = ImageConvert.toPng(File.getBytes(path), ext, MAX_DIM);
				if (png.length > MAX_BYTES) throw "still larger than 4 MB after resizing";
				var name = base, n = 2;
				while (FileSystem.exists(Path.join([d, name + ".png"]))) name = base + "_" + (n++);
				File.saveBytes(Path.join([d, name + ".png"]), png);
				report.imported.push(name);
			} catch (e:Dynamic) report.errors.push(file + ": " + Std.string(e));
		}
		refresh();
		return report;
	}

	static function validStem(stem:String):Bool return stem != null && stem.length > 0 && stem.indexOf("/") < 0 && stem.indexOf("\\") < 0 && stem.indexOf("..") < 0 && stem.indexOf("\x00") < 0;

	/**
	 * Copy a PNG into the folder and return its stem. Throws a user-facing message on bad input.
	 * Never overwrites: a taken name gets a numeric suffix, so cached textures stay valid.
	 */
	public static function importFile(rawPath:String):String {
		var stem = copyIn(rawPath);
		refresh();
		return stem;
	}

	/** Delete a user image from the active images folder. Managed share copies are never touched. */
	public static function deleteImage(stem:String):Void {
		var path = editablePath(stem);
		FileSystem.deleteFile(path);
		refresh();
	}

	/** Rename within the same folder; returns the new stem. Callers rewrite aura references to `custom:<stem>`. */
	public static function renameImage(stem:String, requested:String):String {
		var path = editablePath(stem);
		var next = sanitize(StringTools.trim(requested));
		if (next.toLowerCase() == stem.toLowerCase() && next == stem) return stem;
		var target = Path.join([Path.directory(path), next + ".png"]);
		// A case-only change targets the same file on Windows; anything else must not replace another image.
		if (next.toLowerCase() != stem.toLowerCase() && (FileSystem.exists(target) || paths.exists(next.toLowerCase()))) throw "An image named " + next + " already exists.";
		FileSystem.rename(path, target);
		refresh();
		return next;
	}

	static function editablePath(stem:String):String {
		if (!validStem(stem) || CustomImageKey.isManagedStem(stem)) throw "This image is managed by an imported share and cannot be changed.";
		var path = pathFor(stem);
		if (path == null) throw "Image not found: " + stem;
		return path;
	}

	/**
	 * Imports every path in `raw` (one per line, Explorer-quoted paths, or several quoted paths on a line).
	 * One bad file never blocks the rest. Observe-phase only.
	 */
	public static function importMany(raw:String):ImportReport {
		var report:ImportReport = {imported: [], errors: []};
		for (p in splitPaths(raw)) {
			try report.imported.push(copyIn(p)) catch (e:Dynamic) report.errors.push(Path.withoutDirectory(p) + ": " + Std.string(e));
		}
		if (report.imported.length > 0) refresh();
		return report;
	}

	public static function splitPaths(raw:String):Array<String> {
		var out:Array<String> = [];
		if (raw == null) return out;
		for (line in raw.split("\n")) {
			var t = StringTools.trim(line);
			if (t.length == 0) continue;
			if (t.indexOf('"') < 0) { out.push(t); continue; }
			var i = 0;
			while (i < t.length) {
				var open = t.indexOf('"', i);
				if (open < 0) break;
				var close = t.indexOf('"', open + 1);
				if (close < 0) break;
				var part = StringTools.trim(t.substring(open + 1, close));
				if (part.length > 0) out.push(part);
				i = close + 1;
			}
		}
		return out;
	}

	/** Validate, convert to PNG and copy one file into the images folder; returns the new stem. */
	static function copyIn(rawPath:String):String {
		var src = cleanPath(rawPath);
		if (src.length == 0) throw "Paste the full path to an image file.";
		var ext = Path.extension(src).toLowerCase();
		if (!ImageConvert.isSupportedExtension(ext)) throw "Unsupported file type. Use " + ImageConvert.EXTENSIONS.join(", ") + ".";
		if (!FileSystem.exists(src) || FileSystem.isDirectory(src)) throw "File not found: " + src;
		var stat = FileSystem.stat(src);
		if (stat.size > MAX_SOURCE_BYTES) throw "Image is larger than 32 MB.";
		var bytes = File.getBytes(src);
		var png = try ImageConvert.toPng(bytes, ext, MAX_DIM) catch (e:String) throw e catch (_:Dynamic) throw "Not a readable " + ext.toUpperCase() + " image.";
		if (png.length > MAX_BYTES) throw "Converted image is larger than 4 MB.";
		var base = sanitize(Path.withoutExtension(Path.withoutDirectory(src)));
		var stem = base;
		var n = 2;
		while (FileSystem.exists(Path.join([dir(), stem + ".png"]))) stem = base + "_" + (n++);
		File.saveBytes(Path.join([dir(), stem + ".png"]), png);
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
