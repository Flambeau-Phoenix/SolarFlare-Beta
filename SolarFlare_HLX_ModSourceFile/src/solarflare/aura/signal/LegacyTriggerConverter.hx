package solarflare.aura.signal;

import solarflare.HealthCache;
import solarflare.aura.AuraDef;
import solarflare.aura.AuraEngine;

class LegacyTriggerConverter {
	public static function canConvert(a:AuraDef):Bool {
		if (a == null) return false;
		if (a.trigger == "cooldown") {
			var f = AuraEngine.signalFrame();
			return f != null && f.findSkill(a.skillId) != null;
		}
		if (a.trigger == "prayer") {
			var id = a.skillId != null ? StringTools.trim(a.skillId) : "";
			var kind = PrayerCache.prayerKind(id);
			return id.length == 0 || id.toLowerCase() == "any" || id.toLowerCase() == "prayer"
				|| kind == "life" || kind == "shield" || kind == "smite";
		}
		return a.trigger == "resource" || a.trigger == "combo" || a.trigger == "chaincast" || a.trigger == "conduit";
	}
	public static function reason(a:AuraDef):String {
		if (a == null) return "No Aura selected.";
		if (a.trigger == "status") return "Legacy status triggers include cache-gap hold behavior and cannot be converted exactly in cache-only v1.";
		if (a.trigger == "combatlog") return "Combat-event predicates are deferred from cache-only v1.";
		if (a.trigger == "cooldown") return "Convert after the selected skill is present in the frozen Geaux skill catalog.";
		if (a.trigger == "prayer") return "This prayer identifier has no exact life/shield/smite mapping.";
		return canConvert(a) ? "" : "This legacy trigger has no exact declarative mapping.";
	}
	public static function convert(a:AuraDef):AuraRuleDef {
		if (!canConvert(a)) return null;
		var kind = a.trigger == "prayer" && a.skillId != null ? PrayerCache.prayerKind(a.skillId) : "";
		return LegacyTriggerRuleFactory.convert(a.trigger, a.resource, a.skillId, a.op, a.pct, a.requireAfford.get(), a.invert.get(), kind);
	}
}
