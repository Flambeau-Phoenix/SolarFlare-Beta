package solarflare.cdb;

import haxe.Json;

/**
 * CastleDB timings for Auras, baked by `tools/refresh_cdb_assets.py` and embedded
 * as the `status-durations` resource. Identity, stack caps and timings; live getters still win
 * when present; this is the fallback when a status exposes no usable timer.
 *
 * Embedded so timing updates take effect with the rebuilt mod bytecode. Deployment
 * also refreshes the generated disk tables used by the other CDB consumers.
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

	/** Exact skill-row cast/telegraph duration only; never a granted Status or cooldown. */
	public static function castDuration(id:String):Float {
		return isStatus(id) ? 0 : duration(id);
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
		var itemSpan = ConsumableCatalog.listedSpan(id);
		if (itemSpan > 0) return itemSpan;
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

	/** Validated CastleDB status relationship generated for this ability. */
	public static function grantedStatusId(id:String):String {
		ensure();
		if (id == null || id.length == 0)
			return "";
		// Explicit status selections must never redirect to a companion.
		if (isStatus(id)) return "";
		var g = granted.get(norm(id));
		if (g != null && g.length > 0 && isStatus(g))
			return g;
		return "";
	}

	/** Resolve status signals only; unknown observed IDs retain their exact identity. */
	public static function statusSubjectId(id:String):String {
		if (id == null || id.length == 0 || isStatus(id)) return id;
		var grant = grantedStatusId(id);
		return grant.length > 0 ? grant : id;
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
		if (ConsumableCatalog.listedSpan(id) > 0) return "item effect duration";
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
	 * Labels and icons remain owned by AuraCatalog and GameIcons. Stack caps are
	 * authored props.status.maxStacks, independent of the observed live stack count.
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
		var maxStacks = dynFloat(Reflect.field(row, "maxStacks"));
		if (Math.isFinite(maxStacks) && maxStacks != 0 && Reflect.field(row, "isStatus") == true)
			stacks.set(key, Std.int(maxStacks));
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
