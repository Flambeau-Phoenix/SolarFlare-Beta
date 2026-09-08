package solarflare.aura.signal;

/** Pure legacy-field mapper used by the UI adapter and standalone tests. */
class LegacyTriggerRuleFactory {
	public static function convert(trigger:String, resource:String, skillId:String, op:String, pct:Float, requireAfford:Bool, invertLegacy:Bool, prayerKind:String = ""):AuraRuleDef {
		var r = new AuraRuleDef();
		switch (trigger) {
			case "resource": addNumber(r, resourceSignal(resource), op == "above" ? "gte" : "lte", pct / 100.0);
			case "cooldown": addBool(r, "skill.ready", skillId, true); if (requireAfford) addBool(r, "skill.affordable", skillId, true);
			case "prayer":
				if (prayerKind == "life") addBool(r, "prayer.lifeReady", "", true);
				else if (prayerKind == "shield") addBool(r, "prayer.shieldReady", "", true);
				else if (prayerKind == "smite") addBool(r, "prayer.smiteReady", "", true);
				else { r.mode = "any"; addBool(r, "prayer.lifeReady", "", true); addBool(r, "prayer.shieldReady", "", true); addBool(r, "prayer.smiteReady", "", true); }
			case "combo": if (pct < 1) addBool(r, "resource.combo.atMax", "", true); else addNumber(r, "resource.combo.count", "gte", Std.int(pct));
			case "chaincast":
				if (skillId != null && skillId.toLowerCase().indexOf("ready") >= 0) addBool(r, "chaincast.ready", "", true);
				else { addNumber(r, "chaincast.stacks", "gte", pct >= 1 ? Std.int(pct) : 4); addBool(r, "chaincast.ready", "", true); r.mode = "any"; }
			case "conduit": addNumber(r, "conduit.effectiveStacks", "gte", pct >= 1 ? Std.int(pct) : 1);
			default: return null;
		}
		if (invertLegacy) { r.mode = r.mode == "all" ? "any" : "all"; for (c in r.conditions) c.negate = !c.negate; }
		AuraConditionValidator.validateRule(r); return r;
	}
	static function resourceSignal(v:String):String return switch (v) { case "rage": "resource.rage.ratio"; case "mana": "resource.mana.ratio"; case "spark": "resource.spark.ratio"; case "shield": "resource.shield.ratio"; default: "resource.health.ratio"; };
	static function addNumber(r:AuraRuleDef, signal:String, op:String, value:Float):Void { var c = make(signal, "", op); c.numberValue = value; r.conditions.push(c); }
	static function addBool(r:AuraRuleDef, signal:String, subject:String, value:Bool):Void { var c = make(signal, subject, "is"); c.boolValue = value; r.conditions.push(c); }
	static function make(signal:String, subject:String, op:String):AuraConditionDef { var c = new AuraConditionDef(); c.signal = signal; c.subject = subject != null ? subject : ""; c.op = op; return c; }
}
