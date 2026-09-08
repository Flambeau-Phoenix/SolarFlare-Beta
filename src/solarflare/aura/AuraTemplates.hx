package solarflare.aura;

import solarflare.aura.signal.AuraConditionDef;
import solarflare.aura.signal.AuraRuleDef;

/**
 * Built-in Starter Templates for common Aura use cases:
 * Kill Counters, Low HP Alerts, Skill Ready Alerts, Combo Finishers, Buff Stack Trackers, Damage Spikes.
 */
class AuraTemplates {
	public static function createBossKillCounter():AuraDef {
		var a = new AuraDef("boss_kill_counter", "Boss Kill Counter");
		a.announce = "Boss Kills";
		a.syncAnnounceBuf();
		a.isCounter.set(true);
		a.alwaysOn.set(true);
		a.counterValue = 0;
		a.region = "text";
		a.showIcon.set(true);
		a.showLabel.set(true);
		a.stackCounter.set(true);

		var r = new AuraRuleDef();
		r.mode = "all";
		var c = new AuraConditionDef();
		c.signal = "combat.killKindMatches";
		c.op = "is";
		c.subject = "";
		c.subjectLabel = "";
		r.conditions.push(c);
		a.rule = r;

		a.effects = [new AuraEffect("win", AuraEffect.KIND_WINDOW, AuraEffect.WHEN_ON_RISE_HOLD)];
		a.effects[0].hold = 5.0;
		a.effects[0].holdRef.set(5.0);
		return a;
	}

	public static function createEmergencyLowHpAlert():AuraDef {
		var a = new AuraDef("emergency_low_hp", "Emergency Low HP");
		a.announce = "LOW HP! HEAL / DODGE!";
		a.syncAnnounceBuf();
		a.region = "ring";
		a.showIcon.set(true);
		a.progressRing.set(true);
		a.showLabel.set(true);
		a.audio.set(true);

		var r = new AuraRuleDef();
		r.mode = "all";
		var c = new AuraConditionDef();
		c.signal = "resource.health.ratio";
		c.op = "lte";
		c.numberValue = 0.35;
		r.conditions.push(c);
		a.rule = r;

		a.effects = [new AuraEffect("win", AuraEffect.KIND_ALERT, AuraEffect.WHEN_WHILE_TRUE)];
		return a;
	}

	public static function createSkillReadyAlert():AuraDef {
		var a = new AuraDef("skill_ready_alert", "Skill Cooldown Ready");
		a.announce = "SKILL READY!";
		a.syncAnnounceBuf();
		a.region = "icon";
		a.showIcon.set(true);
		a.progressRing.set(true);

		var r = new AuraRuleDef();
		r.mode = "all";
		var c = new AuraConditionDef();
		c.signal = "skill.ready";
		c.op = "is";
		c.boolValue = true;
		c.subject = "";
		c.subjectLabel = "Main Skill";
		r.conditions.push(c);
		a.rule = r;

		a.effects = AuraEffect.presetCdReady("SKILL READY!");
		return a;
	}

	public static function createMaxComboFinisher():AuraDef {
		var a = new AuraDef("max_combo_finisher", "Max Combo Finisher");
		a.announce = "MAX COMBO! CAST FINISHER!";
		a.syncAnnounceBuf();
		a.region = "text";
		a.showIcon.set(true);
		a.showLabel.set(true);
		a.stackCounter.set(true);

		var r = new AuraRuleDef();
		r.mode = "all";
		var c = new AuraConditionDef();
		c.signal = "resource.combo.count";
		c.op = "gte";
		c.numberValue = 5;
		r.conditions.push(c);
		a.rule = r;

		a.effects = [new AuraEffect("win", AuraEffect.KIND_ALERT, AuraEffect.WHEN_WHILE_TRUE)];
		return a;
	}

	public static function createBuffStackTracker():AuraDef {
		var a = new AuraDef("buff_stack_tracker", "Buff Stack Tracker");
		a.announce = "Buff Active";
		a.syncAnnounceBuf();
		a.region = "bar";
		a.showIcon.set(true);
		a.progressRing.set(true);
		a.stackCounter.set(true);
		a.showLabel.set(true);

		var r = new AuraRuleDef();
		r.mode = "all";
		var c = new AuraConditionDef();
		c.signal = "status.stacks";
		c.op = "gte";
		c.numberValue = 1;
		c.subject = "";
		c.subjectLabel = "Target Buff";
		r.conditions.push(c);
		a.rule = r;

		a.effects = [new AuraEffect("win", AuraEffect.KIND_WINDOW, AuraEffect.WHEN_WHILE_TRUE)];
		return a;
	}

	public static function createDamageTakenSpike():AuraDef {
		var a = new AuraDef("damage_taken_spike", "Heavy Damage Warning");
		a.announce = "HEAVY DAMAGE TAKEN!";
		a.syncAnnounceBuf();
		a.region = "ring";
		a.showIcon.set(true);
		a.showLabel.set(true);

		var r = new AuraRuleDef();
		r.mode = "all";
		var c = new AuraConditionDef();
		c.signal = "combatlog.damage_taken";
		c.op = "gte";
		c.numberValue = 500;
		r.conditions.push(c);
		a.rule = r;

		a.effects = [new AuraEffect("win", AuraEffect.KIND_ALERT, AuraEffect.WHEN_ON_RISE_HOLD)];
		a.effects[0].hold = 2.5;
		a.effects[0].holdRef.set(2.5);
		return a;
	}
}
