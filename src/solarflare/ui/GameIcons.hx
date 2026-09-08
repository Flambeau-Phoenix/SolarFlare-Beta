package solarflare.ui;

import format.png.Reader;
import format.png.Tools;
import haxe.io.BytesInput;
import haxe.io.Path;
#if hl
import imgui.Enums.ImGuiStyleVar;
import imgui.ImGui;
#end
import sys.FileSystem;
import sys.io.File;

#if hl
typedef TextureHandle = hl.I64;
#else
typedef TextureHandle = Dynamic;
private typedef Single = Float;
#end

class AtlasFrame {
	public var key:String;
	public var x:Float;
	public var y:Float;
	public var w:Float;
	public var h:Float;
	public var u0:Single;
	public var v0:Single;
	public var u1:Single;
	public var v1:Single;
	/** Owning atlas texture — required when multiple atlas.png files are merged. */
	public var tex:TextureHandle;

	public function new(key:String, x:Float, y:Float, w:Float, h:Float, atlasW:Float, atlasH:Float, tex:TextureHandle = 0) {
		this.key = key;
		this.x = x;
		this.y = y;
		this.w = w;
		this.h = h;
		this.tex = tex;
		this.u0 = atlasW > 0 ? (x / atlasW) : 0;
		this.v0 = atlasH > 0 ? (y / atlasH) : 0;
		this.u1 = atlasW > 0 ? ((x + w) / atlasW) : 1;
		this.v1 = atlasH > 0 ? ((y + h) / atlasH) : 1;
	}
}

/**
 * Loads official skill/status PNGs via ImGui.registerTexture / ImGui.image.
 * IntegratesTexture Atlas support (`atlas.png` + `atlas.json`).
 * Callers fall back to DrawList glyphs when a PNG is missing.
 * Gate with AlertBlit.ENABLED (see docs/deadly-rift-mods/BLIT_READINESS.md).
 */
class GameIcons {
	/** registerTexture / image — flip with AlertBlit.ENABLED. */
	public static inline var ENABLED:Bool = true;
	static var cache = new Map<String, TextureHandle>();
	static var failed = new Map<String, Bool>();
	static var requested = new Map<String, Bool>();
	static var pending:Array<String> = [];
	static var searchDirs:Array<String> = null;

	public static function hasPending():Bool return pending.length > 0;

	static var atlasMap:Map<String, AtlasFrame> = null;
	/** @deprecated Kept for diagnostics; prefer AtlasFrame.tex after multi-atlas merge. */
	static var atlasTex:TextureHandle = 0;
	static var atlasAttempted = false;
	static var atlasSheetCount:Int = 0;

	static var dimW = new Map<String, Int>();
	static var dimH = new Map<String, Int>();

	public static var lastRequestedKey:String = null;
	public static var lastFailedKey:String = null;

	public static inline var PRAYER_SMITE = "Priest_Prayer_Smite";
	public static inline var PRAYER_LIFE = "Priest_Prayer_Life";
	public static inline var PRAYER_SHIELD = "Priest_Prayer_Shield";
	public static inline var CHAINCAST = "Mage_Talent_Chaincast_Accum_Status";
	public static inline var CHAINCAST_FALLBACK = "Mage_Talent_Chaincast_Status";
	public static inline var RIFT_SUN = "rift-sun";
	public static inline var RIFT_TIMER_BG = "rifttimerbg";
	public static inline var COMBO_POINT = "Rogue_ComboPoints";
	public static inline var COMBO_POINT_ALT = "ComboPoints";
	public static inline var COMBO_MAX = "Rogue_ComboPoints_Max";
	public static inline var COMBO_MAX_ALT = "ComboPoints_Max";
	public static inline var RESOURCE_MAX = "resource-max";
	public static inline var CHROME_SUN = "chrome-sun";
	public static inline var HUB_LOGO = "solarflarefulllogo";

	public static function prayerId(kind:String):String {
		if (kind == "smite")
			return PRAYER_SMITE;
		if (kind == "life")
			return PRAYER_LIFE;
		if (kind == "shield")
			return PRAYER_SHIELD;
		return "";
	}

	public static function initAtlas():Void {
		if (atlasAttempted)
			return;
		atlasAttempted = true;
		atlasMap = new Map<String, AtlasFrame>();
		atlasTex = 0;
		atlasSheetCount = 0;
		ensureDirs();
		if (searchDirs == null)
			return;
		var loadedSheets = new Map<String, Bool>();
		// Prefer assets/icons (mod-local atlas + atlas2) before legacy icons/ copies.
		var ordered = prioritizeAssetsIcons(searchDirs);
		for (root in ordered) {
			tryLoadAtlasPair(root, "atlas", loadedSheets);
			tryLoadAtlasPair(root, "atlas2", loadedSheets);
			tryLoadAtlasPair(root, "atlas3", loadedSheets);
		}
	}

	static function prioritizeAssetsIcons(dirs:Array<String>):Array<String> {
		var preferred:Array<String> = [];
		var rest:Array<String> = [];
		for (d in dirs) {
			if (d == null)
				continue;
			var low = d.toLowerCase();
			if (StringTools.endsWith(low, "assets\\icons") || StringTools.endsWith(low, "assets/icons"))
				preferred.push(d);
			else
				rest.push(d);
		}
		return preferred.concat(rest);
	}

	static function tryLoadAtlasPair(root:String, stem:String, loadedSheets:Map<String, Bool>):Void {
		var jsonPath = Path.join([root, stem + ".json"]);
		var pngPath = Path.join([root, stem + ".png"]);
		try {
			if (!FileSystem.exists(jsonPath) || !FileSystem.exists(pngPath))
				return;
		} catch (_:Dynamic) {
			return;
		}
		var sheetKey = pngPath.toLowerCase();
		if (loadedSheets.exists(sheetKey))
			return;
		loadedSheets.set(sheetKey, true);
		loadAtlasSheet(jsonPath, pngPath, stem);
	}

	static function loadAtlasSheet(jsonPath:String, pngPath:String, stem:String = "atlas"):Void {
		try {
			var tex = loadFilePng(pngPath, stem + ":" + Path.withoutDirectory(Path.directory(pngPath)));
			if (tex == 0)
				return;
			if (atlasTex == (0:TextureHandle))
				atlasTex = tex;
			atlasSheetCount++;
			var content = File.getContent(jsonPath);
			var parsed:Dynamic = haxe.Json.parse(content);
			var framesObj:Dynamic = Reflect.field(parsed, "frames");
			if (framesObj == null)
				return;
			for (field in Reflect.fields(framesObj)) {
				var f:Dynamic = Reflect.field(framesObj, field);
				if (f == null)
					continue;
				var x:Float = Std.parseFloat(Std.string(Reflect.field(f, "x")));
				var y:Float = Std.parseFloat(Std.string(Reflect.field(f, "y")));
				var w:Float = Std.parseFloat(Std.string(Reflect.field(f, "w")));
				var h:Float = Std.parseFloat(Std.string(Reflect.field(f, "h")));
				var aw:Float = Std.parseFloat(Std.string(Reflect.field(f, "atlas_w")));
				var ah:Float = Std.parseFloat(Std.string(Reflect.field(f, "atlas_h")));
				var frame = new AtlasFrame(field, x, y, w, h, aw, ah, tex);
				// First loaded sheet wins (assets/icons atlas before atlas2 before icons/).
				if (!atlasMap.exists(field))
					atlasMap.set(field, frame);
				if (StringTools.endsWith(field, ".png")) {
					var baseKey = field.substr(0, field.length - 4);
					if (!atlasMap.exists(baseKey))
						atlasMap.set(baseKey, frame);
				}
			}
		} catch (_:Dynamic) {}
	}

	static inline function atlasHandle(frame:AtlasFrame):TextureHandle {
		if (frame == null)
			return 0;
		if (frame.tex != (0:TextureHandle))
			return frame.tex;
		return atlasTex;
	}

	public static function getFrame(id:String):AtlasFrame {
		// Branding ships beside the atlases and must not use stale packed copies.
		if (id == CHROME_SUN || id == HUB_LOGO)
			return null;
		if (atlasMap != null && id != null) {
			if (atlasMap.exists(id))
				return atlasMap.get(id);
			if (atlasMap.exists(id + ".png"))
				return atlasMap.get(id + ".png");
		}
		return null;
	}

	public static function get(id:String):TextureHandle {
		if (!ENABLED)
			return 0;
		if (id == null || id.length == 0)
			return 0;
		lastRequestedKey = id;
		var frame = getFrame(id);
		var atex = atlasHandle(frame);
		if (frame != null && atex != (0:TextureHandle)) {
			dimW.set(id, Std.int(frame.w));
			dimH.set(id, Std.int(frame.h));
			return atex;
		}
		if (failed.exists(id))
			return 0;
		if (cache.exists(id))
			return cache.get(id);
		request(id);
		return 0;
	}

	/** Queue-only from draw; actual file/PNG/texture work runs in observe(). */
	static function request(id:String):Void {
		if (id == null || id.length == 0 || requested.exists(id))
			return;
		requested.set(id, true);
		pending.push(id);
	}

	/** Explicit observe-phase load for known assets. */
	public static function preload(id:String):TextureHandle {
		if (!ENABLED || id == null || id.length == 0)
			return 0;
		initAtlas();
		var frame = getFrame(id);
		var atex = atlasHandle(frame);
		if (frame != null && atex != (0:TextureHandle)) {
			dimW.set(id, Std.int(frame.w));
			dimH.set(id, Std.int(frame.h));
			requested.remove(id);
			return atex;
		}
		if (cache.exists(id)) {
			requested.remove(id);
			return cache.get(id);
		}
		if (failed.exists(id)) {
			requested.remove(id);
			return 0;
		}
		var tex = loadPng(id);
		if (tex == 0 && id == CHAINCAST)
			tex = loadPng(CHAINCAST_FALLBACK);
		if (tex == 0 && id == RIFT_TIMER_BG)
			tex = loadPng(RIFT_SUN);
		if (tex == 0 && id == "menubutton")
			tex = loadPng("cfg_f6");
		if (tex == 0 && id == "RiftModsButtonNew_Test")
			tex = loadPng("cfg_f7");
		if (tex == 0) {
			lastFailedKey = id;
			failed.set(id, true);
			requested.remove(id);
			return 0;
		}
		cache.set(id, tex);
		requested.remove(id);
		return tex;
	}

	/** Drain draw-time requests outside the presentation path. */
	public static function tickPreload(maxPerTick:Int = 24):Void {
		initAtlas();
		var count = 0;
		while (pending.length > 0 && count < maxPerTick) {
			var id = pending.shift();
			preload(id);
			count++;
		}
	}

	public static function texW(id:String):Int {
		get(id);
		if (dimW.exists(id))
			return dimW.get(id);
		return 0;
	}

	public static function texH(id:String):Int {
		get(id);
		if (dimH.exists(id))
			return dimH.get(id);
		return 0;
	}

	/** Compatibility accessors used by fixed-viewport custom-art renderers. */
	public static inline function cached(id:String):TextureHandle return get(id);
	public static inline function cachedW(id:String):Int return texW(id);
	public static inline function cachedH(id:String):Int return texH(id);

	/** Preload common UI and launcher icons during observe phase. */
	public static function preloadAll():Void {
		ensureDirs();
		initAtlas();
		var standardKeys = [
			"menubutton", "cfg_f6", "RiftModsButtonNew_Test", "cfg_f7",
			"chrome-sun", "rift-sun", "rifttimerbg", "resource-max", "BlankButton", "solarflarefulllogo",
			"cleric", "mage", "rogue", "warrior", "swords",
			PRAYER_SMITE, PRAYER_LIFE, PRAYER_SHIELD,
			CHAINCAST, CHAINCAST_FALLBACK, COMBO_POINT, COMBO_MAX
		];
		for (key in standardKeys) {
			preload(key);
		}
	}

	/** Re-scan asset folders and retry keys that previously failed to resolve. */
	public static function resetSearchDirs():Void {
		searchDirs = null;
		failed = new Map<String, Bool>();
		requested = new Map<String, Bool>();
		pending = [];
		atlasAttempted = false;
		atlasMap = null;
		atlasTex = 0;
		atlasSheetCount = 0;
	}

	/** Retry one asset without discarding already registered textures. */
	public static function retry(id:String):TextureHandle {
		if (id == null || id.length == 0)
			return 0;
		failed.remove(id);
		requested.remove(id);
		searchDirs = null;
		return preload(id);
	}

	/**
	 * Draw at screen position via ImGui.image (registerTexture handle).
	 * Native `image()` has no col/tint — dim via StyleVar.Alpha from tint's A channel (tintReady).
	 */
	public static function draw(dl:Dynamic, texId:TextureHandle, x:Single, y:Single, size:Single, tint:Int = 0xFFFFFFFF):Bool {
		return drawRect(dl, texId, x, y, size, size, tint);
	}

	public static function drawKey(dl:Dynamic, id:String, x:Single, y:Single, w:Single, h:Single, tint:Int = 0xFFFFFFFF):Bool {
		lastRequestedKey = id;
		var tex = get(id);
		return drawRectForKey(id, dl, tex, x, y, w, h, tint);
	}

	/** Draw a cached icon at the current ImGui cursor with the atlas frame UVs. */
	public static function imageKey(id:String, w:Single, h:Single):Bool {
		return imageKeyUv(id, w, h, 0, 0, 1, 1);
	}

	/** Draw a cropped portion of a cached icon without modifying the source PNG. */
	public static function imageKeyUv(id:String, w:Single, h:Single, u0:Single, v0:Single, u1:Single, v1:Single):Bool {
		#if !hl
		return false;
		#else
		if (id == null || id.length == 0)
			return false;
		var tex = get(id);
		if (tex == 0)
			return false;
		var frame = getFrame(id);
		var atex = atlasHandle(frame);
		if (frame != null && atex != (0:TextureHandle) && tex == atex) {
			var du = frame.u1 - frame.u0;
			var dv = frame.v1 - frame.v0;
			ImGui.image(tex, ImGui.vec2(w, h),
				ImGui.vec2(frame.u0 + du * u0, frame.v0 + dv * v0),
				ImGui.vec2(frame.u0 + du * u1, frame.v0 + dv * v1));
		} else
			ImGui.image(tex, ImGui.vec2(w, h), ImGui.vec2(u0, v0), ImGui.vec2(u1, v1));
		return true;
		#end
	}

	/** Non-square blit (clock plaque, logo, etc.). Supports Atlas sub-rects. */
	public static function drawRect(dl:Dynamic, texId:TextureHandle, x:Single, y:Single, w:Single, h:Single, tint:Int = 0xFFFFFFFF):Bool {
		return drawRectForKey(lastRequestedKey, dl, texId, x, y, w, h, tint);
	}

	static function drawRectForKey(key:String, dl:Dynamic, texId:TextureHandle, x:Single, y:Single, w:Single, h:Single, tint:Int):Bool {
		#if !hl
		return false;
		#else
		if (!ENABLED || texId == 0 || w < 1 || h < 1)
			return false;
		var pushed = false;
		try {
			var a:Single = ((tint >>> 24) & 0xFF) / 255.0;
			if (a < 0.999) {
				ImGui.pushStyleVar(ImGuiStyleVar.Alpha, a);
				pushed = true;
			}
			// Grow parent first — SetCursorScreenPos past CursorMaxPos without an item asserts at EndChild.
			var saved = ImGui.getCursorScreenPos();
			ImGui.setCursorScreenPos(ImGui.vec2(x, y));
			ImGui.dummy(ImGui.vec2(w, h));
			ImGui.setCursorScreenPos(ImGui.vec2(x, y));
			// Decorations must not steal hit-testing from invisibleButton / selectable underneath.
			ImGui.setNextItemAllowOverlap();
			var frame = getFrame(key);
			var atex = atlasHandle(frame);
			if (frame != null && atex != (0:TextureHandle) && texId == atex) {
				var uv0 = ImGui.vec2(frame.u0, frame.v0);
				var uv1 = ImGui.vec2(frame.u1, frame.v1);
				ImGui.image(texId, ImGui.vec2(w, h), uv0, uv1);
			} else {
				ImGui.image(texId, ImGui.vec2(w, h));
			}
			ImGui.setCursorScreenPos(saved);
			if (pushed) {
				ImGui.popStyleVar(1);
				pushed = false;
			}
			return true;
		} catch (_:Dynamic) {
			if (pushed) {
				try
					ImGui.popStyleVar(1)
				catch (_2:Dynamic) {}
			}
			return false;
		}
		#end
	}

	public static function tintReady(ready:Bool):Int {
		#if !hl
		return ready ? 0xFFFFFFFF : 0x61FFFFFF;
		#else
		if (ready)
			return 0xFFFFFFFF;
		return ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0.38));
		#end
	}

	/** Compact cached diagnostic containing resolved mod directory, icon dirs, requested key, and preload count. */
	public static function diagnostic():String {
		ensureDirs();
		var cachedN = 0;
		for (_ in cache.keys()) cachedN++;
		var failedN = 0;
		for (_ in failed.keys()) failedN++;
		var dirCount = searchDirs != null ? searchDirs.length : 0;
		var mod = ModPaths.modDir();
		var req = lastRequestedKey != null ? lastRequestedKey : "none";
		var fail = lastFailedKey != null ? lastFailedKey : "none";
		var atlasN = atlasMap != null ? Lambda.count(atlasMap) : 0;
		return "ModDir: " + mod + " | IconDirs: " + dirCount + " | AtlasSheets: " + atlasSheetCount + " | AtlasFrames: " + atlasN + " | Cached: " + cachedN + " | Failed: " + failedN + " | LastReq: " + req + " | LastFail: " + fail;
	}

	/** F6 / debug — which folders we search for `{SkillId}.png`. */
	public static function statusLine():String {
		return diagnostic();
	}

	static function loadPng(id:String):TextureHandle {
		if (id == CHROME_SUN) {
			var icoPath = resolvePath(id + ".ico");
			if (icoPath != null) {
				var tex = loadFilePng(icoPath, id);
				if (tex != (0:TextureHandle))
					return tex;
			}
		}
		var path = resolvePath(id + ".png");
		if (path == null)
			return 0;
		return loadFilePng(path, id);
	}

	/** Extract the largest PNG frame from the shipped Windows icon. */
	static function iconPng(bytes:haxe.io.Bytes):haxe.io.Bytes {
		if (bytes.length < 6 || bytes.getUInt16(0) != 0 || bytes.getUInt16(2) != 1)
			return bytes;
		var count = bytes.getUInt16(4);
		if (count == 0 || count > Std.int((bytes.length - 6) / 16))
			throw "Invalid ICO directory";
		var bestOffset = -1;
		var bestLength = 0;
		var bestArea = 0;
		for (i in 0...count) {
			var entry = 6 + i * 16;
			var length = bytes.getInt32(entry + 8);
			var offset = bytes.getInt32(entry + 12);
			if (length < 8 || offset < 6 + count * 16 || offset > bytes.length - length)
				continue;
			if (bytes.get(offset) != 137 || bytes.getString(offset + 1, 7) != "PNG\r\n\x1a\n")
				continue;
			var width = bytes.get(entry) == 0 ? 256 : bytes.get(entry);
			var height = bytes.get(entry + 1) == 0 ? 256 : bytes.get(entry + 1);
			if (width * height > bestArea) {
				bestArea = width * height;
				bestOffset = offset;
				bestLength = length;
			}
		}
		if (bestOffset < 0)
			throw "ICO contains no PNG frame";
		return bytes.sub(bestOffset, bestLength);
	}

	static function loadFilePng(path:String, id:String):TextureHandle {
		#if !hl
		return 0;
		#else
		try {
			if (path == null || !FileSystem.exists(path))
				return 0;
			var fileBytes = File.getBytes(path);
			if (fileBytes == null || fileBytes.length == 0)
				return 0;
			var data = new Reader(new BytesInput(iconPng(fileBytes))).read();
			if (data == null)
				return 0;
			var header = Tools.getHeader(data);
			if (header == null || header.width <= 0 || header.height <= 0)
				return 0;
			var bgra = Tools.extract32(data);
			if (bgra == null || bgra.length < header.width * header.height * 4)
				return 0;
			var rgba = haxe.io.Bytes.alloc(bgra.length);
			var i = 0;
			var n = bgra.length;
			while (i < n) {
				rgba.set(i, bgra.get(i + 2));
				rgba.set(i + 1, bgra.get(i + 1));
				rgba.set(i + 2, bgra.get(i));
				rgba.set(i + 3, bgra.get(i + 3));
				i += 4;
			}
			var pitch = header.width * 4;
			dimW.set(id, header.width);
			dimH.set(id, header.height);
			return ImGui.registerTexture(rgba.getData(), header.width, header.height, pitch);
		} catch (_:Dynamic) {
			return 0;
		}
		#end
	}

	static function resolvePath(fileName:String):String {
		ensureDirs();
		if (searchDirs == null)
			return null;
		for (root in prioritizeAssetsIcons(searchDirs)) {
			var p = Path.join([root, fileName]);
			try {
				if (FileSystem.exists(p))
					return p;
			} catch (_:Dynamic) {}
		}
		return null;
	}

	static function ensureDirs():Void {
		if (searchDirs != null)
			return;
		searchDirs = [];
		var candidates = new Array<String>();
		try {
			var modDir = ModPaths.modDir();
			candidates.push(Path.join([modDir, "icons"]));
			candidates.push(Path.join([modDir, "icons", "portraits"]));
			candidates.push(Path.join([modDir, "getrifty"]));
			candidates.push(Path.join([modDir, "assets", "icons"]));
			candidates.push(Path.join([modDir, "assets", "icons", "portraits"]));
			candidates.push(Path.join([modDir, "assets", "getrifty"]));
		} catch (_:Dynamic) {}
		try {
			var exeDir = Path.directory(Sys.programPath());
			// Mod-local pack (prayers / curated / GetRifty sun)
			candidates.push(Path.join([exeDir, "hlx", "mods", "solarflare", "icons"]));
			candidates.push(Path.join([exeDir, "hlx", "mods", "solarflare", "icons", "portraits"]));
			candidates.push(Path.join([exeDir, "hlx", "mods", "solarflare", "getrifty"]));
			candidates.push(Path.join([exeDir, "hlx", "mods", "solarflare", "assets", "icons"]));
			candidates.push(Path.join([exeDir, "hlx", "mods", "solarflare", "assets", "getrifty"]));
			candidates.push(Path.join([exeDir, "hlx", "mods", "SolarFlare", "icons"]));
			candidates.push(Path.join([exeDir, "hlx", "mods", "SolarFlare", "icons", "portraits"]));
			candidates.push(Path.join([exeDir, "hlx", "mods", "SolarFlare", "assets", "icons"]));
			// Full skill art already shipped with Farever DPS Meter
			candidates.push(Path.join([exeDir, "fareverDpsMeter", "group-dps-images", "skills"]));
		} catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "hlx", "mods", "solarflare", "icons"]))
		catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "hlx", "mods", "solarflare", "icons", "portraits"]))
		catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "hlx", "mods", "solarflare", "assets", "icons"]))
		catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "hlx", "mods", "solarflare", "getrifty"]))
		catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "fareverDpsMeter", "group-dps-images", "skills"]))
		catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "icons"]))
		catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "icons", "portraits"]))
		catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "assets", "getrifty"]))
		catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "assets", "icons"]))
		catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "assets", "icons", "portraits"]))
		catch (_:Dynamic) {}
		for (c in candidates) {
			try {
				if (c != null && FileSystem.exists(c) && FileSystem.isDirectory(c)) {
					var unique = true;
					for (existing in searchDirs) if (existing == c) { unique = false; break; }
					if (unique) searchDirs.push(c);
				}
			} catch (_:Dynamic) {}
		}
	}
}
