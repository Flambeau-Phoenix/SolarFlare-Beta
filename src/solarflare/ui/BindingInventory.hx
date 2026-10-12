package solarflare.ui;

import haxe.io.Path;
import solarflare.EngineText;
import sys.FileSystem;
import sys.io.File;

typedef BindingEntry = {
	var code:Null<Int>;
	var key:String;
	var modifier:Null<Int>;
	var modifierText:String;
	var mode:Null<Int>;
	var pad:String;
}

typedef BindingRow = {
	var action:String;
	/** default, user, or both: which engine map the action id came from. */
	var source:String;
	var isDefault:Bool;
	var conflict:Bool;
	var entries:Array<BindingEntry>;
}

typedef ModifierLegendRow = {
	var id:Int;
	var supported:Bool;
	var code:Null<Int>;
	var key:String;
	var text:String;
}

/**
 * Read-only snapshot of the engine's effective input bindings, including the modifier and mode
 * fields that the rest of the mod has not used so far. Runs from the observation-phase action
 * queue only; draw code reads the stored result.
 */
class BindingInventory {
	public static var rows(default, null):Array<BindingRow> = [];
	public static var legend(default, null):Array<ModifierLegendRow> = [];
	public static var status(default, null):String = "Not read yet. Press Read bindings.";
	public static var filePath(default, null):String = "";
	static inline var MAX_ACTIONS:Int = 512;
	static inline var MAX_ENTRIES:Int = 32;

	/** Observation phase only (queue it through UiActionQueue.custom). */
	public static function capture():Void {
		try {
			var defaults = lib.Input.defaultBinds;
			var users = lib.Input.userBinds;
			if (defaults == null || users == null)
				throw "Native binding maps unavailable.";
			var ids:Array<String> = [];
			var source = new Map<String, String>();
			collect(defaults, "default", ids, source);
			collect(users, "user", ids, source);
			ids.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
			var out:Array<BindingRow> = [];
			var modifierIds = new Map<Int, Bool>();
			for (i in 0...4)
				modifierIds.set(i, true);
			var bindingCount = 0;
			var withModifier = 0;
			for (id in ids) {
				var row = readRow(id, source.get(id));
				out.push(row);
				for (e in row.entries) {
					bindingCount++;
					if (e.modifier != null) {
						modifierIds.set(e.modifier, true);
						if (e.modifier != 0)
							withModifier++;
					}
				}
			}
			rows = out;
			legend = readLegend(modifierIds);
			filePath = writeFile();
			status = "Read " + out.length + " actions / " + bindingCount + " bindings (" + withModifier
				+ " with a modifier)." + (filePath.length > 0 ? " Saved to logs/bindings.json." : " File write failed.");
		} catch (e:Dynamic) {
			status = "Binding read failed: " + Std.string(e);
		}
	}

	static function collect(map:hlx.std.haxe.ds.StringMap, label:String, ids:Array<String>, source:Map<String, String>):Void {
		var it = map.keys();
		if (it == null)
			throw "Native key iterator unavailable.";
		var n = 0;
		while (it.hasNext()) {
			if (++n > MAX_ACTIONS)
				throw "Native binding inventory exceeds the bounded read.";
			var id = EngineText.cleanId(it.next());
			if (id.length == 0)
				continue;
			var prior = source.get(id);
			if (prior == null) {
				ids.push(id);
				source.set(id, label);
			} else if (prior != label)
				source.set(id, "both");
		}
	}

	static function readRow(id:String, source:String):BindingRow {
		var entries:Array<BindingEntry> = [];
		try {
			var list = lib.Input.getBindings(id);
			if (list != null && list.length >= 0 && list.length <= MAX_ENTRIES) {
				// getBindings returns a shared scratch array: copy the raw values out before
				// any further native call can overwrite it.
				var raws:Array<Dynamic> = [];
				for (i in 0...list.length)
					raws.push(list.getDyn(i));
				for (raw in raws)
					if (raw != null)
						entries.push(readEntry(raw));
			}
		} catch (_:Dynamic) {}
		var isDefault = false;
		var conflict = false;
		try isDefault = lib.Input.isDefault(id) catch (_:Dynamic) {}
		try conflict = lib.Input.isConflict(id) catch (_:Dynamic) {}
		return {action: id, source: source, isDefault: isDefault, conflict: conflict, entries: entries};
	}

	static function readEntry(raw:Dynamic):BindingEntry {
		var code = nullableInt(raw, "code");
		var modifier = nullableInt(raw, "modifier");
		var mode = nullableInt(raw, "mode");
		var pad = "";
		try {
			var p:Dynamic = HlxRuntime.resolveField(raw, "padCode");
			if (p != null)
				pad = Std.string(p);
		} catch (_:Dynamic) {}
		return {
			code: code,
			key: code != null ? keyName(code) : "",
			modifier: modifier,
			modifierText: modifier != null ? modifierName(modifier) : "",
			mode: mode,
			pad: pad
		};
	}

	static function nullableInt(raw:Dynamic, field:String):Null<Int> {
		try {
			var v:Dynamic = HlxRuntime.resolveField(raw, field);
			if (v != null && Std.isOfType(v, Int)) {
				var i:Int = v;
				return i;
			}
		} catch (_:Dynamic) {}
		return null;
	}

	static function keyName(code:Int):String {
		var name = "";
		try name = EngineText.cleanId(lib.Input.getKeyName(code)) catch (_:Dynamic) {}
		return name.length == 0 || name == "?" ? "code " + code : name;
	}

	static function modifierName(modifier:Int):String {
		var text = "";
		try text = EngineText.cleanId(lib.Input.getModifierText(modifier)) catch (_:Dynamic) {}
		return text;
	}

	static function readLegend(ids:Map<Int, Bool>):Array<ModifierLegendRow> {
		var order:Array<Int> = [for (k in ids.keys()) k];
		order.sort(function(a, b) return a - b);
		var out:Array<ModifierLegendRow> = [];
		for (id in order) {
			var supported = false;
			try supported = lib.Input.supportsModifier(id) catch (_:Dynamic) {}
			var code:Null<Int> = null;
			var key = "";
			var text = "";
			if (supported) {
				try code = lib.Input.getModifierCode(id) catch (_:Dynamic) {}
				if (code != null)
					key = keyName(code);
				text = modifierName(id);
			}
			out.push({id: id, supported: supported, code: code, key: key, text: text});
		}
		return out;
	}

	/** Plain-text table for the clipboard and the log. */
	public static function table():String {
		var lines:Array<String> = [];
		lines.push("Modifier ids: " + [for (l in legend) l.id + "=" + (l.supported ? (l.text.length > 0 ? l.text : l.key) : "unsupported")].join(", "));
		lines.push("Action | Key | Modifier | Mode | Pad | Source | Flags");
		for (row in rows) {
			var flags = (row.isDefault ? "default" : "custom") + (row.conflict ? ", CONFLICT" : "");
			if (row.entries.length == 0) {
				lines.push(row.action + " | (none) | | | | " + row.source + " | " + flags);
				continue;
			}
			for (e in row.entries) {
				var modifier = e.modifier == null ? "" : (e.modifierText.length > 0 ? e.modifierText : "id " + e.modifier);
				lines.push(row.action + " | " + (e.code == null ? "(no key)" : e.key) + " | " + modifier + " | "
					+ (e.mode == null ? "" : Std.string(e.mode)) + " | " + e.pad + " | " + row.source + " | " + flags);
			}
		}
		return lines.join("\n");
	}

	static function writeFile():String {
		try {
			var dir = Path.join([ModPaths.modDir(), "logs"]);
			if (!FileSystem.exists(dir))
				FileSystem.createDirectory(dir);
			var path = Path.join([dir, "bindings.json"]);
			var data = {
				version: 1,
				capturedAt: Date.now().toString(),
				modifierLegend: legend,
				actions: rows
			};
			File.saveContent(path, haxe.Json.stringify(data, null, "  "));
			return path;
		} catch (_:Dynamic) {
			return "";
		}
	}
}
