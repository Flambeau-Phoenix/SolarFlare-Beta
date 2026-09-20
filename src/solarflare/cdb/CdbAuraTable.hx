package solarflare.cdb;

import haxe.Json;

/**
 * CastleDB timings for Auras, baked by `tools/build_status_durations.py` and embedded
 * as the `status-durations` resource. Duration / cooldown only — live getters still win
 * when present; this is the fallback when a status exposes no usable timer.
 *
 * Embedded rather than read from disk so there is no path ladder and no dependency on
 * `deploy.ps1` asset sync, which skips existing `assets/cdb` files without -ForceAssets.
 */
class CdbAuraTable {
	static var ready:Bool = false;
	static var names = new Map<String, String>();
	static var durs = new Map<String, Float>();
	static var cds = new Map<String, Float>();
	static var stacks = new Map<String, Int>();
	/** Present only for rows the CDB marks nature Status. */
	static var statusKind = new Map<String, Bool>();
	static var gfxStem = new Map<String, String>();
	static var granted = new Map<String, String>();
	static var spanMod = new Map<String, String>();
	static var orderedIds:Array<String> = [];
	static var orderedLabels:Array<String> = [];

	public static function keep():Void {
		ensure();
	}

	public static function name(id:String):String {
		ensure();
		if (id == null || id.length == 0)
			return "";
		var n = names.get(norm(id));
		return n != null ? n : "";
	}

	/** Cached picker data initialized by keep(); callers must treat the arrays as read-only. */
	public static function allIds():Array<String> { ensure(); return orderedIds; }
	public static function allLabels():Array<String> { ensure(); return orderedLabels; }

	/** CDB telegraph / status length, or 0. */
	public static function duration(id:String):Float {
		ensure();
		if (id == null || id.length == 0)
			return 0;
		if (!durs.exists(norm(id)))
			return 0;
		return durs.get(norm(id));
	}

	public static function cooldown(id:String):Float {
		ensure();
		if (id == null || id.length == 0)
			return 0;
		if (!cds.exists(norm(id)))
			return 0;
		return cds.get(norm(id));
	}

	/** True when the CDB records this id with nature Status rather than a castable skill. */
	public static function isStatus(id:String):Bool {
		ensure();
		if (id == null || id.length == 0)
			return false;
		return statusKind.exists(norm(id));
	}

	/**
	 * The span to show for an id. A granted status wants its own duration — that is when
	 * it goes away. A castable skill wants its cooldown, since on a skill row `duration`
	 * is only the cast / animation window. Either falls back to the other.
	 */
	public static function listedSpan(id:String):Float {
		if (!isStatus(id)) {
			var g = grantedStatusId(id);
			if (g.length > 0 && g != id) {
				var gd = duration(g);
				if (gd > 0.05)
					return gd;
			}
		}
		var d = duration(id);
		var cd = cooldown(id);
		if (isStatus(id))
			return d > 0.05 ? d : cd;
		return cd > 0.05 ? cd : d;
	}

	/** CastleDB status id this skill grants, else naming-convention `_Proc` / `_Status`. */
	public static function grantedStatusId(id:String):String {
		ensure();
		if (id == null || id.length == 0)
			return "";
		var g = granted.get(norm(id));
		if (g != null && g.length > 0)
			return g;
		var proc = id + "_Proc";
		if (statusKind.exists(norm(proc)) || durs.exists(norm(proc)))
			return proc;
		var st = id + "_Status";
		if (statusKind.exists(norm(st)) || durs.exists(norm(st)))
			return st;
		return "";
	}

	/** gear | rank | reset | vars when the baked span can move in play. Empty = clean. */
	public static function listedSpanMod(id:String):String {
		ensure();
		if (id == null || id.length == 0)
			return "";
		var m = spanMod.get(norm(id));
		return m != null ? m : "";
	}

	/** Which CDB field listedSpan came from, for builder tooltips. Empty when neither. */
	public static function listedSpanSource(id:String):String {
		var g = grantedStatusId(id);
		if (g.length > 0 && g != id && duration(g) > 0.05)
			return "status duration";
		var d = duration(id);
		var cd = cooldown(id);
		if (isStatus(id))
			return d > 0.05 ? "duration" : (cd > 0.05 ? "cooldown" : "");
		return cd > 0.05 ? "cooldown" : (d > 0.05 ? "duration" : "");
	}

	public static function maxStacks(id:String):Int {
		ensure();
		if (id == null || id.length == 0)
			return 0;
		if (!stacks.exists(norm(id)))
			return 0;
		return stacks.get(norm(id));
	}

	public static function iconStem(id:String):String {
		ensure();
		if (id == null || id.length == 0)
			return "";
		var g = gfxStem.get(norm(id));
		return g != null ? g : "";
	}

	static function ensure():Void {
		if (ready)
			return;
		ready = true;
		try {
			var raw:Dynamic = Json.parse(haxe.Resource.getString("status-durations"));
			var list:Dynamic = Reflect.field(raw, "skills");
			if (list == null)
				return;
			var arr:Array<Dynamic> = cast list;
			for (row in arr)
				put(row);
		} catch (_:Dynamic) {}
	}

	/**
	 * Timings only. `name` / `gfx` / `maxStacks` are absent from the baked rows: the CDB
	 * skill sheet carries no maxStacks at all, and labels + icons already resolve through
	 * AuraCatalog and GameIcons, so populating them here would silently change what the
	 * builder displays.
	 */
	static function put(row:Dynamic):Void {
		if (row == null)
			return;
		var id = dynStr(Reflect.field(row, "id"));
		if (id.length == 0)
			return;
		var key = norm(id);
		orderedIds.push(id);
		orderedLabels.push(id);
		var d = dynFloat(Reflect.field(row, "duration"));
		if (d >= 0.5 && d <= 300)
			durs.set(key, d);
		var cd = dynFloat(Reflect.field(row, "cooldown"));
		if (cd >= 0.5 && cd <= 300)
			cds.set(key, cd);
		if (Reflect.field(row, "isStatus") == true)
			statusKind.set(key, true);
		var g = dynStr(Reflect.field(row, "grantedStatus"));
		if (g.length == 0)
			g = dynStr(Reflect.field(row, "granted"));
		if (g.length > 0)
			granted.set(key, g);
		var mod = dynStr(Reflect.field(row, "spanMod"));
		if (mod.length > 0)
			spanMod.set(key, mod);
		var gfx = Reflect.field(row, "gfx");
		if (gfx != null) {
			var stem = dynStr(Reflect.field(gfx, "stem"));
			if (stem.length == 0)
				stem = dynStr(gfx);
			if (stem.length > 0 && stem.indexOf("/") < 0 && stem.indexOf("\\") < 0)
				gfxStem.set(key, stem);
		}
	}

	static function norm(id:String):String {
		return id.toLowerCase();
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

	static function dynFloat(v:Dynamic):Float {
		if (v == null)
			return 0;
		try {
			var f = Std.parseFloat(Std.string(v));
			if (Math.isNaN(f))
				return 0;
			return f;
		} catch (_:Dynamic) {
			return 0;
		}
	}
}
