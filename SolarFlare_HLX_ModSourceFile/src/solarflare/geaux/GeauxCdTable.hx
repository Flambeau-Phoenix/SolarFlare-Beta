package solarflare.geaux;

import haxe.Json;
import solarflare.ui.ModPaths;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

/**
 * CastleDB cooldown / cost fallback when live getEffectiveCooldown is missing or still the base.
 * Loaded from assets/cdb/skill-cooldowns.json (deploy: hlx/mods/solarflare/assets/).
 */
class GeauxCdCost {
	public var atb:String = "";
	public var amount:Float = 0;

	public function new(atb:String, amount:Float) {
		this.atb = atb != null ? atb : "";
		this.amount = amount;
	}
}

class GeauxCdRow {
	public var id:String = "";
	public var base:Float = 0;
	public var varsCooldown:Float = 0;
	public var chargedCd:Bool = false;
	/** CastleDB props.charges — max uses before the skill is empty. 0 = not a charged skill. */
	public var charges:Int = 0;
	public var cdConditions:Int = 0;
	public var cdEnabledOnly:Bool = false;
	public var costs:Array<GeauxCdCost> = [];
	public var rankMins:Array<Int> = [];
	public var rankCds:Array<Float> = [];

	public function new() {}

	public function maxForRank(rank:Int):Float {
		var r = rank < 1 ? 1 : rank;
		var cd = base;
		if (cd <= 0 && varsCooldown > 0)
			cd = varsCooldown;
		var i = 0;
		while (i < rankMins.length) {
			if (r >= rankMins[i] && rankCds[i] > 0)
				cd = rankCds[i];
			i++;
		}
		return cd > 0 ? cd : 0;
	}
}

class GeauxCdTable {
	static var ready:Bool = false;
	static var byId = new Map<String, GeauxCdRow>();

	public static function keep():Void {
		ensure();
	}

	public static function baseFor(id:String):Float {
		var row = rowOf(id);
		if (row == null)
			return 0;
		if (row.base > 0)
			return row.base;
		return row.varsCooldown > 0 ? row.varsCooldown : 0;
	}

	public static function maxFor(id:String, rank:Int):Float {
		var row = rowOf(id);
		if (row == null)
			return 0;
		return row.maxForRank(rank);
	}

	public static function maxForAliases(ids:Array<String>, rank:Int):Float {
		if (ids == null)
			return 0;
		for (id in ids) {
			var m = maxFor(id, rank);
			if (m > 0.05)
				return m;
		}
		return 0;
	}

	public static function baseForAliases(ids:Array<String>):Float {
		if (ids == null)
			return 0;
		for (id in ids) {
			var b = baseFor(id);
			if (b > 0.05)
				return b;
		}
		return 0;
	}

	public static function costsFor(id:String):Array<GeauxCdCost> {
		var row = rowOf(id);
		if (row == null || row.costs == null)
			return [];
		return row.costs;
	}

	public static function costsForAliases(ids:Array<String>):Array<GeauxCdCost> {
		if (ids == null)
			return [];
		for (id in ids) {
			var c = costsFor(id);
			if (c != null && c.length > 0)
				return c;
		}
		return [];
	}

	public static function cdEnabledOnly(id:String):Bool {
		var row = rowOf(id);
		return row != null && row.cdEnabledOnly;
	}

	public static function chargesFor(id:String):Int {
		var row = rowOf(id);
		if (row == null || row.charges < 1)
			return 0;
		return row.charges;
	}

	public static function chargesForAliases(ids:Array<String>):Int {
		if (ids == null)
			return 0;
		for (id in ids) {
			var n = chargesFor(id);
			if (n > 0)
				return n;
		}
		return 0;
	}

	/**
	 * Prefer live effective max. If it is missing or still the CDB base while a rank
	 * override exists, use the written condition table.
	 */
	public static function resolveMax(id:String, aliases:Array<String>, rank:Int, liveMax:Float):Float {
		var ids:Array<String> = [];
		if (id != null && id.length > 0)
			ids.push(id);
		if (aliases != null) {
			for (a in aliases) {
				if (a != null && a.length > 0)
					ids.push(a);
			}
		}
		var tableMax = maxForAliases(ids, rank);
		var tableBase = baseForAliases(ids);
		if (Math.isNaN(liveMax) || liveMax <= 0.05) {
			if (tableMax > 0.05)
				return tableMax;
			return 0;
		}
		if (tableMax > 0.05 && tableBase > 0.05
			&& Math.abs(liveMax - tableBase) < 0.08
			&& Math.abs(tableMax - tableBase) > 0.08)
			return tableMax;
		return liveMax;
	}

	static function rowOf(id:String):GeauxCdRow {
		ensure();
		if (id == null || id.length == 0)
			return null;
		var row = byId.get(id);
		if (row != null)
			return row;
		return byId.get(id.toLowerCase());
	}

	static function ensure():Void {
		if (ready)
			return;
		ready = true;
		seedSignatures();
		var path = jsonPath();
		if (path == null)
			return;
		try {
			var raw:Dynamic = Json.parse(File.getContent(path));
			var list:Dynamic = Reflect.field(raw, "skills");
			if (list == null)
				return;
			var arr:Array<Dynamic> = cast list;
			for (item in arr)
				ingest(item);
		} catch (_:Dynamic) {}
	}

	static function seedSignatures():Void {
		putSimple("Mage_RayOfSpark", 10);
		putSimple("Priest_Sig_DivineIntervention", 12);
		putSimple("Rogue_Sig_Finisher", 8);
		var rage = new GeauxCdRow();
		rage.id = "Warrior_Rage_Strike";
		rage.costs = [new GeauxCdCost("Rage", 10)];
		putRow(rage);
		putSimple("Warrior_Charge", 15);
		putSimple("Warrior_IgnorePain", 60);
		putSimple("Warrior_BattleShout", 120);
		putSimple("Mage_Blink", 15);
		putSimple("Priest_FaithfulWinds", 25);
		putSimple("Rogue_Shadowstep", 15);
	}

	static function putSimple(id:String, cd:Float):Void {
		var row = new GeauxCdRow();
		row.id = id;
		row.base = cd;
		putRow(row);
	}

	static function ingest(item:Dynamic):Void {
		if (item == null)
			return;
		var id = dynStr(Reflect.field(item, "id"));
		if (id.length == 0)
			return;
		var row = new GeauxCdRow();
		row.id = id;
		row.base = dynFloat(Reflect.field(item, "cooldown"));
		row.varsCooldown = dynFloat(Reflect.field(item, "varsCooldown"));
		row.chargedCd = Reflect.field(item, "chargedCd") == true;
		try {
			var ch:Dynamic = Reflect.field(item, "charges");
			if (ch != null)
				row.charges = Std.int(ch);
		} catch (_:Dynamic) {}
		try {
			var c:Dynamic = Reflect.field(item, "cdConditions");
			if (c != null)
				row.cdConditions = Std.int(c);
		} catch (_:Dynamic) {}
		row.cdEnabledOnly = (row.cdConditions & 1) != 0;
		try {
			var costs:Array<Dynamic> = Reflect.field(item, "costs");
			if (costs != null) {
				for (c in costs) {
					var atb = dynStr(Reflect.field(c, "atb"));
					var amt = dynFloat(Reflect.field(c, "amount"));
					if (atb.length > 0)
						row.costs.push(new GeauxCdCost(atb, amt));
				}
			}
		} catch (_:Dynamic) {}
		try {
			var ranks:Array<Dynamic> = Reflect.field(item, "rankCooldown");
			if (ranks != null) {
				for (r in ranks) {
					var minR = 2;
					try {
						var m:Dynamic = Reflect.field(r, "minRank");
						if (m != null)
							minR = Std.int(m);
					} catch (_:Dynamic) {}
					var cd = dynFloat(Reflect.field(r, "cooldown"));
					if (cd > 0) {
						row.rankMins.push(minR);
						row.rankCds.push(cd);
					}
				}
			}
		} catch (_:Dynamic) {}
		putRow(row);
	}

	static function putRow(row:GeauxCdRow):Void {
		if (row == null || row.id == null || row.id.length == 0)
			return;
		byId.set(row.id, row);
		byId.set(row.id.toLowerCase(), row);
	}

	static function jsonPath():String {
		var candidates = new Array<String>();
		try candidates.push(Path.join([ModPaths.modDir(), "assets", "skill-cooldowns.json"])) catch (_:Dynamic) {}
		try candidates.push(Path.join([ModPaths.modDir(), "assets", "cdb", "skill-cooldowns.json"])) catch (_:Dynamic) {}
		try candidates.push(Path.join([ModPaths.modDir(), "cdb", "skill-cooldowns.json"])) catch (_:Dynamic) {}
		try {
			var exeDir = Path.directory(Sys.programPath());
			candidates.push(Path.join([exeDir, "hlx", "mods", "solarflare", "cdb", "skill-cooldowns.json"]));
		} catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "hlx", "mods", "solarflare", "cdb", "skill-cooldowns.json"]))
		catch (_:Dynamic) {}
		try
			candidates.push(Path.join([Sys.getCwd(), "assets", "cdb", "skill-cooldowns.json"]))
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
