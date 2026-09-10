package solarflare;

/**
 * Confirmed engine skill ids only (script-style `Class_Rest`).
 * Never CastleDB / menu names, never last-segment stubs, never "unknown".
 */
class EngineSkillId {
	static var ready:Bool = false;
	static var hashToScript:Map<String, String> = new Map();

	public static function keep():Void {
		ensure();
	}

	/** Full engine id, or "" if not confirmed. */
	public static function display(id:String):String {
		ensure();
		var s = clean(id);
		if (s.length == 0)
			return "";
		var mapped = hashToScript.get(s);
		if (mapped != null && mapped.length > 0)
			return mapped;
		if (isScriptStyle(s))
			return s;
		return "";
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

	static function ledgerSkill(id:String, method:String, name:String):Void {
		if (!solarflare.debug.ResolutionLedger.armed())
			return;
		solarflare.debug.ResolutionLedger.touch("skill.id", method, "EngineSkillId.ofSkill", name, "string", solarflare.debug.ResolutionLedger.clip(id, 48));
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
		var low = s.toLowerCase();
		if (low.indexOf("bytes") >= 0)
			return false;
		if (low.indexOf("haxe.io") >= 0)
			return false;
		return true;
	}

	static function field(obj:Dynamic, name:String):Dynamic {
		if (obj == null || name == null)
			return null;
		try
			return Reflect.field(obj, "_" + name)
		catch (_:Dynamic) {}
		try
			return Reflect.field(obj, name)
		catch (_:Dynamic) {}
		return null;
	}

	static function stringField(obj:Dynamic, name:String):String {
		var v = field(obj, name);
		if (v == null)
			return "";
		try {
			if (Std.isOfType(v, String))
				return cast v;
		} catch (_:Dynamic) {}
		return "";
	}
}
