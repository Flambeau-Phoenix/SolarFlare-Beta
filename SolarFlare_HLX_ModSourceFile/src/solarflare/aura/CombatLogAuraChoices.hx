package solarflare.aura;

import solarflare.aura.signal.AuraConditionDef;
import solarflare.combatlog.CombatLogDocument;
import solarflare.combatlog.CombatLogDocument.CombatLogEvent;
import solarflare.combatlog.CombatLogAnalysis.CombatLogSkillStats;

typedef CombatLogStatusInfo = {
	var id:String;
	var label:String;
	var duration:Float;
	var stacks:Int;
}

/** A trigger proposal, never an AuraDef or library entry. */
class CombatLogAuraChoice {
	public var id(default, null):String;
	public var title(default, null):String;
	public var reason(default, null):String;
	public var condition(default, null):AuraConditionDef;
	public var preset(default, null):String;
	public function new(id:String, title:String, reason:String, signal:String, op:String,
			subject:String = "", label:String = "", number:Float = 0, preset:String = "plain") {
		this.id = id; this.title = title; this.reason = reason; this.preset = preset;
		condition = new AuraConditionDef();
		condition.signal = signal; condition.op = op; condition.subject = subject; condition.subjectLabel = label;
		condition.numberValue = number; condition.boolValue = true;
	}
}

/** Deterministic capability policy. Catalog associations are not observed status applications. */
class CombatLogAuraChoices {
	public static function damage(event:CombatLogEvent):Array<CombatLogAuraChoice> {
		if (event == null || event.kind != "hit" || event.targetRole != CombatLogDocument.YOU || event.amount <= 0) return [];
		return [new CombatLogAuraChoice("damage", "Warn about a hit this large",
			"Observed hit: " + event.amount + ". Watches the largest recent hit on you from ANY source, not only this skill.",
			"combat.damageTakenRecent", "gte", "", "", event.amount, "damage")];
	}
	public static function skill(stats:CombatLogSkillStats, label:String, status:CombatLogStatusInfo = null):Array<CombatLogAuraChoice> {
		var out:Array<CombatLogAuraChoice> = [];
		if (stats == null || StringTools.trim(stats.skill).length == 0) return out;
		if (stats.role == CombatLogDocument.ENEMY) {
			var evidence = stats.casts > 0 ? "" : "Only hits were recorded for this skill; this choice watches future casts. ";
			out.push(new CombatLogAuraChoice("enemy_recent", "Alert after this enemy skill is cast",
				evidence + "Watches this skill cast by ANY enemy within 5 seconds. The selected enemy is browsing context, not a trigger filter.",
				"event.cast.recent", "within", stats.skill, label, 5, "enemy"));
			out.push(new CombatLogAuraChoice("enemy_active", "Show while this cast or channel is active",
				evidence + "Watches this skill running on any enemy. Very brief casts may finish before an aura evaluation.",
				"event.cast.active", "is", stats.skill, label));
		} else if (stats.role == CombatLogDocument.YOU) {
			out.push(new CombatLogAuraChoice("my_recent", "Alert after I cast this skill",
				"Watches your cast of this skill within 5 seconds.", "event.playerCast.recent", "within", stats.skill, label, 5, "flash"));
			out.push(new CombatLogAuraChoice("ready", "Show when this skill is ready",
				"Requires this skill to be available on your current character. A previous fight does not prove current readiness.",
				"skill.ready", "is", stats.skill, label));
			out.push(new CombatLogAuraChoice("cooldown", "Track this skill's cooldown",
				"Shows while cooldown remains. Requires this skill on your current character; follows the live cooldown timer.",
				"skill.cooldownLeft", "gt", stats.skill, label, 0, "timer"));
		}
		if (status != null && status.id.length > 0) {
			var reference = "Catalog association, not a recorded application. Watches " + status.label + " ON YOU, not on an enemy.";
			out.push(new CombatLogAuraChoice("status", "Track related status on me", reference,
				"status.present", "present", status.id, status.label));
			if (Math.isFinite(status.duration) && status.duration > 0)
				out.push(new CombatLogAuraChoice("status_time", "Track related status time remaining",
					reference + " Listed duration: " + status.duration + " seconds; live duration takes precedence.",
					"status.durationLeft", "gt", status.id, status.label, 0, "timer"));
			if (status.stacks > 1)
				out.push(new CombatLogAuraChoice("status_stacks", "Track related status stacks", reference,
					"status.stacks", "gte", status.id, status.label, 1, "stacks"));
		}
		return out;
	}
}
