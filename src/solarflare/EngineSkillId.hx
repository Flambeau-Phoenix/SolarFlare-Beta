package solarflare;

/**
 * Confirmed engine skill ids only (script-style `Class_Rest`).
 * Never CastleDB / menu names, never last-segment stubs, never "unknown".
 */
class EngineSkillId {
	static var ready:Bool = false;
	static var hashToScript:Map<String, String> = new Map();
	static var displayCache:Map<String, String> = new Map();
	/** Every id in the CastleDB `skill` sheet (assets/cdb/skill-ids.json, built by tools/build_skill_ids.py). */
	static var known:Map<String, Bool> = null;

	/** Every skill id in the shipped CDB table, sorted (loads the resource on first use). */
	public static function allIds():Array<String> {
		isKnownSkillId("load_the_table");
		var out:Array<String> = [];
		if (known != null)
			for (k in known.keys())
				out.push(k);
		out.sort(function(a, b) return a < b ? -1 : (a > b ? 1 : 0));
		return out;
	}

	/** Per-skill relations from assets/cdb/skill-links.json (tools/build_skill_ids.py): `_Proc` partner + status rows. */
	static var links:Map<String, SkillLink> = null;
	static var linksReady:Bool = false;
	static var noStatuses:Array<String> = [];

	static function loadLinks():Void {
		links = new Map();
		try {
			var raw = haxe.Resource.getString("skill-links");
			if (raw == null)
				return;
			var doc:Dynamic = haxe.Json.parse(raw);
			var table:Dynamic = doc.links;
			if (table == null)
				return;
			for (k in Reflect.fields(table)) {
				var e:Dynamic = Reflect.field(table, k);
				var l = new SkillLink();
				if (Std.isOfType(e.p, String))
					l.proc = e.p;
				if (Std.isOfType(e.s, Array))
					for (x in (e.s : Array<Dynamic>))
						if (Std.isOfType(x, String))
							l.statuses.push(x);
				links.set(k, l);
			}
			linksReady = true;
		} catch (_:Dynamic) {}
	}

	/**
	 * The `<id>_Proc` row of a skill ("" when the game's data has none). Ids the table does not know (content added
	 * by a later patch, or no resource shipped) keep the old convention guess so new skills still resolve.
	 */
	public static function procOf(id:String):String {
		if (id == null || id.length == 0)
			return "";
		if (links == null)
			loadLinks();
		if (linksReady && isKnownSkillId(id)) {
			var l = links.get(id);
			return l == null ? "" : l.proc;
		}
		return id + "_Proc";
	}

	/** Status rows the skill is linked to in the game's data (suffix partners and script references). */
	public static function statusesOf(id:String):Array<String> {
		if (id == null || id.length == 0)
			return noStatuses;
		if (links == null)
			loadLinks();
		if (linksReady && isKnownSkillId(id)) {
			var l = links.get(id);
			return l == null ? noStatuses : l.statuses;
		}
		return [id + "_Status"];
	}

	/**
	 * True for an id the game's own data defines. Confirms single-word skills (Mount, PhysicalBlock, Gather...) that
	 * the `Class_Name` shape test cannot; ids are exact and case-sensitive, so menu names and stubs stay rejected.
	 */
	public static function isKnownSkillId(id:String):Bool {
		if (id == null || id.length < 3)
			return false;
		if (known == null) {
			known = new Map();
			try {
				var raw = haxe.Resource.getString("skill-ids");
				if (raw != null) {
					var rows:Array<Dynamic> = haxe.Json.parse(raw);
					for (r in rows)
						if (Std.isOfType(r, String))
							known.set(r, true);
				}
			} catch (_:Dynamic) {}
		}
		return known.exists(id);
	}

	public static function keep():Void {
		ensure();
	}

	/** Full engine id, or "" if not confirmed. */
	public static function display(id:String):String {
		if (id == null || id.length == 0)
			return "";
		var cached = displayCache.get(id);
		if (cached != null)
			return cached;
		ensure();
		var s = clean(id);
		var result = "";
		if (s.length > 0) {
			var mapped = hashToScript.get(s);
			if (mapped != null && mapped.length > 0)
				result = mapped;
			else if (isScriptStyle(s) || isKnownSkillId(s))
				result = s;
		}
		displayCache.set(id, result);
		return result;
	}

	public static function ofSkill(skill:Dynamic):String {
		if (skill == null)
			return "";
		try {
			var access:st.skill.BaseSkillAccess = skill;
			var id = access.get_skillId();
			var shown = display(id);
			if (shown.length > 0) {
				ledgerSkill(shown, "typed", "get_skillId");
				return shown;
			}
		} catch (_:Dynamic) {}
		try {
			var bs:st.skill.BaseSkill = skill;
			var shown = display(bs.kind);
			if (shown.length > 0) {
				ledgerSkill(shown, "typed", "kind");
				return shown;
			}
			if (bs.inf != null) {
				shown = display(bs.inf.id);
				if (shown.length > 0) {
					ledgerSkill(shown, "typed", "inf.id");
					return shown;
				}
			}
		} catch (_:Dynamic) {}
		var kind = stringField(skill, "kind");
		var shown = display(kind);
		if (shown.length > 0) {
			ledgerSkill(shown, "fieldwalk", "kind");
			return shown;
		}
		var inf = field(skill, "inf");
		shown = display(stringField(inf, "id"));
		if (shown.length > 0) {
			ledgerSkill(shown, "fieldwalk", "inf.id");
			return shown;
		}
		shown = display(stringField(inf, "script"));
		if (shown.length > 0) {
			ledgerSkill(shown, "fieldwalk", "inf.script");
			return shown;
		}
		shown = display(stringField(skill, "id"));
		if (shown.length > 0)
			ledgerSkill(shown, "fieldwalk", "id");
		return shown;
	}

	/** One bound row per (method, name) winner; ids repeat heavily so previews are deduped. */
	#if solarflare_telemetry
	static var skillBinds:Map<String, solarflare.debug.LedgerBinding> = new Map();
	static var lastSkillId:String = "";
	#end

	static inline function ledgerSkill(id:String, method:String, name:String):Void {
		#if solarflare_telemetry
		if (!solarflare.debug.ResolutionLedger.armed())
			return;
		var bindKey = method + "|" + name;
		var b = skillBinds.get(bindKey);
		if (b == null) {
			b = new solarflare.debug.LedgerBinding();
			skillBinds.set(bindKey, b);
		}
		if (!solarflare.debug.ResolutionLedger.bind(b, "skill.id", method, "EngineSkillId.ofSkill", name))
			return;
		var prev:String = null;
		if (id != lastSkillId) {
			lastSkillId = id;
			prev = solarflare.debug.ResolutionLedger.clip(id, 48);
		}
		solarflare.debug.ResolutionLedger.bump(b, prev);
		#end
	}

	static function ensure():Void {
		if (ready)
			return;
		ready = true;
		pin("Warrior_Rage_Strike");
		pin("Mage_RayOfSpark");
		pin("Priest_Sig_DivineIntervention");
		pin("Rogue_Sig_Finisher");
		pin("Rogue_ComboPoints");
		pin("Mage_Conduit_Power");
		pin("Mage_Conduit_Projectile");
		pin("Mage_Talent_ConduitSparkExplosion_Conduit");
		pin("Mage_Talent_ConduitLifebolt_Conduit");
		pin("Mage_Talent_Chaincast");
		pin("Mage_Talent_Chaincast_Status");
		pin("Mage_Talent_Chaincast_Accum_Status");
	}

	static function pin(scriptId:String):Void {
		if (scriptId != null && scriptId.length > 0)
			hashToScript.set(scriptId, scriptId);
	}

	static function isScriptStyle(s:String):Bool {
		if (s.length < 3)
			return false;
		if (s.indexOf("_") < 0)
			return false;
		return isClean(s);
	}

	static function clean(id:String):String {
		if (id == null)
			return "";
		var s = StringTools.trim(id);
		if (s.length < 3)
			return "";
		if (!isClean(s))
			return "";
		return s;
	}

	static function isClean(s:String):Bool {
		if (s == null || s.length == 0)
			return false;
		if (s.indexOf("{") >= 0 || s.indexOf("}") >= 0)
			return false;
		// Avoid toLowerCase alloc — dump markers appear in known casings.
		if (s.indexOf("bytes") >= 0 || s.indexOf("Bytes") >= 0)
			return false;
		if (s.indexOf("haxe.io") >= 0 || s.indexOf("haxe.Io") >= 0)
			return false;
		return true;
	}

	static function field(obj:Dynamic, name:String):Dynamic {
		if (obj == null || name == null)
			return null;
		return FieldWalk.extractObject(obj, name);
	}

	static function stringField(obj:Dynamic, name:String):String {
		if (obj == null || name == null)
			return "";
		return FieldWalk.extractString(obj, name, "");
	}
}

private class SkillLink {
	public var proc:String = "";
	public var statuses:Array<String> = [];
	public function new() {}
}
