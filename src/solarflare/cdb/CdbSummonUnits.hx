package solarflare.cdb;

import haxe.Json;
import solarflare.ui.ModPaths;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * CDB-derived summon resolution (`assets/cdb/summon-units.json`).
 *
 * Baked from Farever `data.cdb` by `tools/build_summon_units.py` through the CDB
 * Agent CLI (`skill@steps@props@summon.unit` + each summoned unit's own skills).
 * It maps a skill id to the summoned unit that owns/named it, so a hit whose
 * DamageResult actor collapsed to the summoner can still be credited to the
 * actual minion (e.g. `Summon_Imp_Auto` -> `Summon_Imp` -> "Nightling Terror").
 */
class CdbSummonUnits {
	static var ready:Bool = false;
	static var skillToUnit = new Map<String, String>();
	static var unitIds:Array<String> = [];
	static var unitLabels = new Map<String, String>();

	public static function keep():Void {
		ensure();
	}

	/** Summoned unit id for a skill id, or "" when the skill is not a summon skill. */
	public static function unitForSkill(skillId:String):String {
		ensure();
		if (skillId == null || skillId.length == 0)
			return "";
		var key = skillId.toLowerCase();
		var exact = skillToUnit.get(key);
		if (exact != null)
			return exact;
		// Generic prefix fallback (longest unit id wins): Summon_Imp_Auto -> Summon_Imp.
		var best = "";
		for (id in unitIds) {
			if (key.length >= id.length && StringTools.startsWith(key, id) && id.length > best.length)
				best = id;
		}
		return best;
	}

	/** Display label for a summoned unit id (CDB unit sheet name; falls back to the id). */
	public static function label(unitId:String):String {
		ensure();
		if (unitId == null || unitId.length == 0)
			return "";
		var found = unitLabels.get(unitId.toLowerCase());
		if (found != null && found.length > 0)
			return found;
		var cdb = CdbUnitNames.lookup(unitId);
		return cdb.length > 0 ? cdb : unitId;
	}

	/** Convenience: minion label for the summoned unit that owns this skill id. */
	public static function labelForSkill(skillId:String):String {
		var unit = unitForSkill(skillId);
		return unit.length > 0 ? label(unit) : "";
	}

	static function ensure():Void {
		if (ready)
			return;
		ready = true;
		skillToUnit = new Map();
		unitIds = [];
		unitLabels = new Map();
		var path = jsonPath();
		if (path == null)
			return;
		try {
			var raw:Dynamic = Json.parse(File.getContent(path));
			var units:Dynamic = Reflect.field(raw, "units");
			if (units != null) {
				for (key in Reflect.fields(units)) {
					var nm = dynStr(Reflect.field(units, key));
					var lower = key.toLowerCase();
					unitIds.push(lower);
					unitLabels.set(lower, nm.length > 0 ? nm : key);
				}
			}
			var skills:Dynamic = Reflect.field(raw, "skills");
			if (skills != null) {
				for (key in Reflect.fields(skills)) {
					var unit = dynStr(Reflect.field(skills, key));
					if (unit.length > 0)
						skillToUnit.set(key.toLowerCase(), unit.toLowerCase());
				}
			}
		} catch (_:Dynamic) {}
	}

	static function jsonPath():String {
		var candidates = new Array<String>();
		try candidates.push(Path.join([ModPaths.modDir(), "assets", "cdb", "summon-units.json"])) catch (_:Dynamic) {}
		try candidates.push(Path.join([ModPaths.modDir(), "cdb", "summon-units.json"])) catch (_:Dynamic) {}
		try {
			var exeDir = Path.directory(Sys.programPath());
			candidates.push(Path.join([exeDir, "hlx", "mods", "solarflare", "cdb", "summon-units.json"]));
		} catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "assets", "cdb", "summon-units.json"]))
		catch (_:Dynamic) {}
		for (c in candidates) {
			try {
				if (c != null && FileSystem.exists(c))
					return c;
			} catch (_:Dynamic) {}
		}
		return null;
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
