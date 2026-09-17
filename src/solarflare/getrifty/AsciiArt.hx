package solarflare.getrifty;

import haxe.io.Bytes;
import haxe.io.Path;
import imgui.ImGui;
import sys.FileSystem;
import sys.io.File;

/**
 * Rasterize Braille / block ASCII to an ImGui texture. Default font cannot draw U+2800.
 */
class AsciiArt {
	static inline var DOT:Int = 2;
	static inline var CELL_W:Int = 4;
	static inline var CELL_H:Int = 8;
	static inline var MAX_DIM:Int = 512;
	static inline var FRAME_MARK:String = "===FRAME===";

	static var tex = new Map<String, hl.I64>();
	static var tw = new Map<String, Int>();
	static var th = new Map<String, Int>();
	static var failed = new Map<String, Bool>();
	static var frames = new Map<String, Array<hl.I64>>();
	static var searchDirs:Array<String> = null;

	public static function get(stem:String):hl.I64 {
		if (stem == null || stem.length == 0)
			return 0;
		if (failed.exists(stem))
			return 0;
		if (tex.exists(stem))
			return tex.get(stem);
		var path = resolve(stem + ".txt");
		if (path == null) {
			failed.set(stem, true);
			return 0;
		}
		try {
			var raw = File.getContent(path);
			var parts = splitFrames(raw);
			if (parts.length == 0) {
				failed.set(stem, true);
				return 0;
			}
			var list:Array<hl.I64> = [];
			var i = 0;
			while (i < parts.length) {
				var id = bake(stem + "#" + i, parts[i]);
				if (id.toInt() != 0)
					list.push(id);
				i++;
			}
			if (list.length == 0) {
				failed.set(stem, true);
				return 0;
			}
			frames.set(stem, list);
			tex.set(stem, list[0]);
			return list[0];
		} catch (_:Dynamic) {
			failed.set(stem, true);
			return 0;
		}
	}

	public static function frameCount(stem:String):Int {
		get(stem);
		if (!frames.exists(stem))
			return 0;
		return frames.get(stem).length;
	}

	public static function frameTex(stem:String, index:Int):hl.I64 {
		get(stem);
		if (!frames.exists(stem))
			return get(stem);
		var list = frames.get(stem);
		if (list.length == 0)
			return 0;
		var i = index % list.length;
		if (i < 0)
			i += list.length;
		return list[i];
	}

	public static function width(stem:String):Int {
		get(stem);
		if (tw.exists(stem + "#0"))
			return tw.get(stem + "#0");
		if (tw.exists(stem))
			return tw.get(stem);
		return 0;
	}

	public static function height(stem:String):Int {
		get(stem);
		if (th.exists(stem + "#0"))
			return th.get(stem + "#0");
		if (th.exists(stem))
			return th.get(stem);
		return 0;
	}

	static function splitFrames(raw:String):Array<String> {
		if (raw == null)
			return [];
		var t = StringTools.replace(raw, "\r\n", "\n");
		t = StringTools.replace(t, "\r", "\n");
		if (t.indexOf(FRAME_MARK) < 0)
			return [t];
		var out:Array<String> = [];
		var start = 0;
		while (start <= t.length) {
			var i = t.indexOf(FRAME_MARK, start);
			if (i < 0) {
				out.push(t.substr(start));
				break;
			}
			out.push(t.substr(start, i - start));
			start = i + FRAME_MARK.length;
			if (start < t.length && t.charAt(start) == "\n")
				start++;
		}
		var cleaned:Array<String> = [];
		for (p in out) {
			var s = StringTools.trim(p);
			if (s.length > 0)
				cleaned.push(p);
		}
		return cleaned;
	}

	static function bake(key:String, body:String):hl.I64 {
		var lines = body.split("\n");
		var cols = 0;
		for (line in lines) {
			var n = line.length;
			if (n > 0 && line.charCodeAt(n - 1) == 13)
				n--;
			if (n > cols)
				cols = n;
		}
		var rows = lines.length;
		if (cols < 1 || rows < 1)
			return 0;
		var w = cols * CELL_W;
		var h = rows * CELL_H;
		var step = 1;
		while (w / step > MAX_DIM || h / step > MAX_DIM)
			step++;
		var ow = Std.int(w / step);
		var oh = Std.int(h / step);
		if (ow < 1)
			ow = 1;
		if (oh < 1)
			oh = 1;
		var pix = Bytes.alloc(ow * oh * 4);
		var i = 0;
		var n = pix.length;
		while (i < n) {
			pix.set(i, 0);
			pix.set(i + 1, 0);
			pix.set(i + 2, 0);
			pix.set(i + 3, 0);
			i += 4;
		}
		var y = 0;
		while (y < rows) {
			var line = y < lines.length ? lines[y] : "";
			var x = 0;
			while (x < cols) {
				var code = 32;
				if (x < line.length)
					code = line.charCodeAt(x);
				stamp(pix, ow, oh, x * CELL_W, y * CELL_H, step, code);
				x++;
			}
			y++;
		}
		tw.set(key, ow);
		th.set(key, oh);
		var stem = key;
		var hash = key.indexOf("#");
		if (hash > 0)
			stem = key.substr(0, hash);
		if (!tw.exists(stem)) {
			tw.set(stem, ow);
			th.set(stem, oh);
		}
		return ImGui.registerTexture(pix.getData(), ow, oh, ow * 4);
	}

	static function stamp(pix:Bytes, ow:Int, oh:Int, ox:Int, oy:Int, step:Int, code:Int):Void {
		if (code == 32 || code == 9 || code == 0)
			return;
		if (code >= 0x2800 && code <= 0x28FF) {
			var bits = code - 0x2800;
			plotDot(pix, ow, oh, ox, oy, step, bits & 1);
			plotDot(pix, ow, oh, ox, oy + DOT, step, bits & 2);
			plotDot(pix, ow, oh, ox, oy + DOT * 2, step, bits & 4);
			plotDot(pix, ow, oh, ox + DOT, oy, step, bits & 8);
			plotDot(pix, ow, oh, ox + DOT, oy + DOT, step, bits & 16);
			plotDot(pix, ow, oh, ox + DOT, oy + DOT * 2, step, bits & 32);
			plotDot(pix, ow, oh, ox, oy + DOT * 3, step, bits & 64);
			plotDot(pix, ow, oh, ox + DOT, oy + DOT * 3, step, bits & 128);
			return;
		}
		var a = shadeOf(code);
		if (a <= 0)
			return;
		fillCell(pix, ow, oh, ox, oy, step, a);
	}

	static function shadeOf(code:Int):Int {
		if (code == 0x2588 || code == 0x2588)
			return 255;
		if (code == 0x2593)
			return 200;
		if (code == 0x2592)
			return 140;
		if (code == 0x2591)
			return 80;
		if (code == 0x2584 || code == 0x2580 || code == 0x258C || code == 0x2590)
			return 220;
		if (code == 35 || code == 42 || code == 64)
			return 200;
		if (code > 32)
			return 180;
		return 0;
	}

	static function plotDot(pix:Bytes, ow:Int, oh:Int, x:Int, y:Int, step:Int, on:Int):Void {
		if (on == 0)
			return;
		var dy = 0;
		while (dy < DOT) {
			var dx = 0;
			while (dx < DOT) {
				put(pix, ow, oh, Std.int((x + dx) / step), Std.int((y + dy) / step), 255);
				dx++;
			}
			dy++;
		}
	}

	static function fillCell(pix:Bytes, ow:Int, oh:Int, x:Int, y:Int, step:Int, a:Int):Void {
		var dy = 0;
		while (dy < CELL_H) {
			var dx = 0;
			while (dx < CELL_W) {
				put(pix, ow, oh, Std.int((x + dx) / step), Std.int((y + dy) / step), a);
				dx++;
			}
			dy++;
		}
	}

	static function put(pix:Bytes, ow:Int, oh:Int, x:Int, y:Int, a:Int):Void {
		if (x < 0 || y < 0 || x >= ow || y >= oh)
			return;
		var i = (y * ow + x) * 4;
		pix.set(i, 255);
		pix.set(i + 1, 240);
		pix.set(i + 2, 210);
		pix.set(i + 3, a);
	}

	static function resolve(fileName:String):String {
		ensureDirs();
		if (searchDirs == null)
			return null;
		for (root in searchDirs) {
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
			var mod = solarflare.ui.ModPaths.modDir();
			candidates.push(Path.join([mod, "assets", "ascii"]));
			candidates.push(Path.join([mod, "getrifty", "ascii"]));
			candidates.push(Path.join([mod, "getrifty"]));
		} catch (_:Dynamic) {}
		try {
			var exeDir = Path.directory(Sys.programPath());
			candidates.push(Path.join([exeDir, "hlx", "mods", "solarflare", "assets", "ascii"]));
			candidates.push(Path.join([exeDir, "hlx", "mods", "solarflare", "getrifty", "ascii"]));
			candidates.push(Path.join([exeDir, "hlx", "mods", "solarflare", "getrifty"]));
		} catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "assets", "ascii"]))
		catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "assets", "getrifty", "ascii"]))
		catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "docs", "GetRifty ASCII Themes"]))
		catch (_:Dynamic) {}
		for (c in candidates) {
			try {
				if (c != null && FileSystem.exists(c) && FileSystem.isDirectory(c))
					searchDirs.push(c);
			} catch (_:Dynamic) {}
		}
	}
}
