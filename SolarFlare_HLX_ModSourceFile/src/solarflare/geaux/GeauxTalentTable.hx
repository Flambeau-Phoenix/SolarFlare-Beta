package solarflare.geaux;

import haxe.Json;
import solarflare.ui.ModPaths;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * One class talent and how it touches skills / cooldown.
 * Loaded from assets/cdb/talent-effects.json (deploy: hlx/mods/solarflare/assets/).
 */
class GeauxTalentEffect {
	public var id:String = "";
	public var name:String = "";
	public var klass:String = "";
	public var maxPoints:Int = 1;
	public var kinds:Array<String> = [];
	public var scope:String = "other";
	public var affectedSkills:Array<String> = [];
	public var procChance:Float = 0;
	public var reduceSeconds:Float = 0;
	public var selfCooldown:Float = 0;
	public var cdrPctRank1:Float = 0;
	public var cdrPctRank2:Float = 0;
	public var desc:String = "";

	public function new() {}

	public function touchesCooldown():Bool {
		for (k in kinds) {
			if (k == "cooldownReductionPct" || k == "reduceWeaponSkills" || k == "reduceNamedSkill"
				|| k == "selfCooldown")
				return true;
		}
		return false;
	}
}

class GeauxTalentTable {
	static var ready:Bool = false;
	static var byId = new Map<String, GeauxTalentEffect>();
	static var bySkill = new Map<String, Array<GeauxTalentEffect>>();
	static var all:Array<GeauxTalentEffect> = [];

	public static function keep():Void {
		ensure();
	}

	public static function allTalents():Array<GeauxTalentEffect> {
		ensure();
		return all;
	}

	public static function of(id:String):GeauxTalentEffect {
		ensure();
		if (id == null || id.length == 0)
			return null;
		var row = byId.get(id);
		if (row != null)
			return row;
		return byId.get(id.toLowerCase());
	}

	/** Talents that name this skill in refs / reduceCooldown(Skill.Id). */
	public static function affecting(skillId:String):Array<GeauxTalentEffect> {
		ensure();
		if (skillId == null || skillId.length == 0)
			return [];
		var list = bySkill.get(skillId);
		if (list != null)
			return list;
		list = bySkill.get(skillId.toLowerCase());
		return list != null ? list : [];
	}

	/** Global % CooldownReduction from a talent at the given invested points. */
	public static function cdrPctFor(id:String, points:Int):Float {
		var row = of(id);
		if (row == null)
			return 0;
		if (points >= 2 && row.cdrPctRank2 > 0)
			return row.cdrPctRank2;
		if (points >= 1 && row.cdrPctRank1 > 0)
			return row.cdrPctRank1;
		return 0;
	}

	static function ensure():Void {
		if (ready)
			return;
		ready = true;
		var path = jsonPath();
		if (path == null)
			return;
		try {
			var raw:Dynamic = Json.parse(File.getContent(path));
			var list:Dynamic = Reflect.field(raw, "talents");
			if (list == null)
				return;
			var arr:Array<Dynamic> = cast list;
			for (item in arr)
				ingest(item);
		} catch (_:Dynamic) {}
	}

	static function ingest(item:Dynamic):Void {
		if (item == null)
			return;
		var row = new GeauxTalentEffect();
		row.id = dynStr(Reflect.field(item, "id"));
		if (row.id.length == 0)
			return;
		row.name = dynStr(Reflect.field(item, "name"));
		row.klass = dynStr(Reflect.field(item, "class"));
		try {
			var mp:Dynamic = Reflect.field(item, "maxPoints");
			if (mp != null)
				row.maxPoints = Std.int(mp);
		} catch (_:Dynamic) {}
		row.scope = dynStr(Reflect.field(item, "scope"));
		row.procChance = dynFloat(Reflect.field(item, "procChance"));
		row.reduceSeconds = dynFloat(Reflect.field(item, "reduceSeconds"));
		row.selfCooldown = dynFloat(Reflect.field(item, "selfCooldown"));
		row.desc = dynStr(Reflect.field(item, "desc"));
		try {
			var ks:Array<Dynamic> = Reflect.field(item, "kinds");
			if (ks != null) {
				for (k in ks)
					row.kinds.push(dynStr(k));
			}
		} catch (_:Dynamic) {}
		try {
			var ids:Array<Dynamic> = Reflect.field(item, "affectedSkills");
			if (ids != null) {
				for (s in ids) {
					var id = dynStr(s);
					if (id.length > 0)
						row.affectedSkills.push(id);
				}
			}
		} catch (_:Dynamic) {}
		try {
			var cdr:Array<Dynamic> = Reflect.field(item, "cooldownReduction");
			if (cdr != null) {
				for (c in cdr) {
					var pct = dynFloat(Reflect.field(c, "val"));
					var minR = 1;
					try {
						var m:Dynamic = Reflect.field(c, "minRank");
						if (m != null)
							minR = Std.int(m);
					} catch (_:Dynamic) {}
					if (minR >= 2)
						row.cdrPctRank2 = pct;
					else if (row.cdrPctRank1 <= 0)
						row.cdrPctRank1 = pct;
				}
			}
		} catch (_:Dynamic) {}
		put(row);
	}

	static function put(row:GeauxTalentEffect):Void {
		byId.set(row.id, row);
		byId.set(row.id.toLowerCase(), row);
		all.push(row);
		for (sid in row.affectedSkills) {
			addAffect(sid, row);
		}
		if (row.scope == "weaponSkills" || row.scope == "global")
			addAffect("*", row);
	}

	static function addAffect(sid:String, row:GeauxTalentEffect):Void {
		if (sid == null || sid.length == 0)
			return;
		var list = bySkill.get(sid);
		if (list == null) {
			list = [];
			bySkill.set(sid, list);
			bySkill.set(sid.toLowerCase(), list);
		}
		list.push(row);
	}

	static function jsonPath():String {
		var candidates = new Array<String>();
		try candidates.push(Path.join([ModPaths.modDir(), "assets", "talent-effects.json"])) catch (_:Dynamic) {}
		try candidates.push(Path.join([ModPaths.modDir(), "assets", "cdb", "talent-effects.json"])) catch (_:Dynamic) {}
		try candidates.push(Path.join([ModPaths.modDir(), "cdb", "talent-effects.json"])) catch (_:Dynamic) {}
		try {
			var exeDir = Path.directory(Sys.programPath());
			candidates.push(Path.join([exeDir, "hlx", "mods", "solarflare", "cdb", "talent-effects.json"]));
		} catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "hlx", "mods", "solarflare", "cdb", "talent-effects.json"]))
		catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "assets", "cdb", "talent-effects.json"]))
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
			if (Std.isOfType(v, String)) {
				var s:String = v;
				return s != null ? s : "";
			}
		} catch (_:Dynamic) {}
		try {
			var s = Std.string(v);
			if (s == null || s == "null")
				return "";
			return s;
		} catch (_:Dynamic) {
			return "";
		}
	}

	static function dynFloat(v:Dynamic):Float {
		if (v == null)
			return 0;
		try {
			var f:Float = v;
			if (!Math.isNaN(f))
				return f;
		} catch (_:Dynamic) {}
		try {
			var f = Std.parseFloat(Std.string(v));
			if (!Math.isNaN(f))
				return f;
		} catch (_:Dynamic) {}
		return 0;
	}
}
