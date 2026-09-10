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

	/** Buff/debuff on local hero — pick any status ID (e.g. SuperEliteDemon_Bomb_Status). */
	public static function createStatusOnMeAlert():AuraDef {
		var a = new AuraDef("status_on_me", "Status on me");
		a.announce = "Status!";
		a.syncAnnounceBuf();
		a.region = "icon";
		a.showIcon.set(true);
		a.showLabel.set(true);
		a.showBanner.set(true);
		a.bannerText = "Status on me";
		a.syncBannerBuf();

		var r = new AuraRuleDef();
		r.mode = "all";
		var c = new AuraConditionDef();
		c.signal = "status.present";
		c.op = "present";
		c.subject = "";
		c.subjectLabel = "";
		r.conditions.push(c);
		a.rule = r;

		var win = new AuraEffect("win", AuraEffect.KIND_WINDOW, AuraEffect.WHEN_WHILE_TRUE);
		win.hold = 1.5;
		win.holdRef.set(1.5);
		var alert = new AuraEffect("rise_alert", AuraEffect.KIND_ALERT, AuraEffect.WHEN_ON_RISE_HOLD);
		alert.hold = 1.5;
		alert.holdRef.set(1.5);
		a.effects = [win, alert];
		return a;
	}

	/**
	 * Mage Pyroclasm free-cast / proc ready.
	 * Signal: skill.instantReady on Staff_Craft_S1 (script shouldPlayInstantly / haveProc;
	 * ObserveDemand also warms Geaux for that skill). Not Staff_Craft_S1_Status (enemy debuff).
	 */
	public static function createPyroclasmProcAlert():AuraDef {
		var a = new AuraDef("pyroclasm_proc", "Pyroclasm Proc");
		a.announce = "PYROCLASM!";
		a.syncAnnounceBuf();
		a.skillId = "Staff_Craft_S1";
		a.syncSkillBuf();
		a.iconId = "Staff_Craft_S1";
		a.syncIconBuf();
		a.region = "icon";
		a.showIcon.set(true);
		a.showLabel.set(true);
		a.showBanner.set(true);
		a.bannerText = "PYROCLASM!";
		a.syncBannerBuf();

		var r = new AuraRuleDef();
		r.mode = "all";
		var c = new AuraConditionDef();
		c.signal = "skill.instantReady";
		c.op = "is";
		c.boolValue = true;
		c.subject = "Staff_Craft_S1";
		c.subjectLabel = "Pyroclasm";
		r.conditions.push(c);
		a.rule = r;

		var win = new AuraEffect("win", AuraEffect.KIND_WINDOW, AuraEffect.WHEN_WHILE_TRUE);
		var alert = new AuraEffect("boss_alert", AuraEffect.KIND_ALERT, AuraEffect.WHEN_ON_RISE_HOLD);
		alert.hold = 2.0;
		alert.holdRef.set(2.0);
		alert.text = "PYROCLASM!";
		alert.syncTextBuf();
		a.effects = [win, alert];
		return a;
	}

	/** Universal enemy cast edge — pick any skill ID (Night Queen, trash casts, etc.). */
	public static function createEnemySpellCastAlert():AuraDef {
		var a = new AuraDef("enemy_spell_cast", "Enemy Spell Cast");
		a.announce = "ENEMY CAST!";
		a.syncAnnounceBuf();
		a.region = "icon";
		a.showIcon.set(true);
		a.showLabel.set(true);
		a.showBanner.set(true);
		a.bannerText = "ENEMY CAST!";
		a.syncBannerBuf();

		var r = new AuraRuleDef();
		r.mode = "all";
		var c = new AuraConditionDef();
		c.signal = "event.cast.recent";
		c.op = "within";
		c.numberValue = 5.0;
		c.subject = "";
		c.subjectLabel = "";
		r.conditions.push(c);
		a.rule = r;

		var win = new AuraEffect("win", AuraEffect.KIND_WINDOW, AuraEffect.WHEN_ON_RISE_HOLD);
		win.hold = 2.5;
		win.holdRef.set(2.5);
		var alert = new AuraEffect("boss_alert", AuraEffect.KIND_ALERT, AuraEffect.WHEN_ON_RISE_HOLD);
		alert.hold = 2.5;
		alert.holdRef.set(2.5);
		a.effects = [win, alert];
		return a;
	}

	/** Channel-while-running example: Night Queen Deceitful Illusions (editable subject). */
	public static function createEnemyChannelActiveAlert():AuraDef {
		var a = new AuraDef("enemy_channel_active", "Enemy Channel Active");
		a.announce = "CLONES CHANNEL!";
		a.syncAnnounceBuf();
		a.skillId = "FairieSuperElite_Clones";
		a.syncSkillBuf();
		a.iconId = "FairieSuperElite_Clones";
		a.syncIconBuf();
		a.region = "icon";
		a.showIcon.set(true);
		a.showLabel.set(true);
		a.showBanner.set(true);
		a.bannerText = "CLONES CHANNEL!";
		a.syncBannerBuf();

		var r = new AuraRuleDef();
		r.mode = "all";
		var c = new AuraConditionDef();
		c.signal = "event.cast.active";
		c.op = "is";
		c.boolValue = true;
		c.subject = "FairieSuperElite_Clones";
		c.subjectLabel = "Deceitful Illusions";
		r.conditions.push(c);
		a.rule = r;

		var win = new AuraEffect("win", AuraEffect.KIND_WINDOW, AuraEffect.WHEN_WHILE_TRUE);
		var alert = new AuraEffect("boss_alert", AuraEffect.KIND_ALERT, AuraEffect.WHEN_ON_RISE_HOLD);
		alert.hold = 2.0;
		alert.holdRef.set(2.0);
		a.effects = [win, alert];
		return a;
	}

	public static function createDamageTakenSpike():AuraDef {
		var a = new AuraDef("damage_taken_spike", "Heavy Damage Warning");
		a.announce = "HEAVY DAMAGE TAKEN!";
		a.syncAnnounceBuf();
		a.region = "ring";
		a.showIcon.set(true);
		a.showLabel.set(true);
		a.showBanner.set(true);
		a.bannerText = "HEAVY DAMAGE!";
		a.syncBannerBuf();

		var r = new AuraRuleDef();
		r.mode = "all";
		var c = new AuraConditionDef();
		c.signal = "combat.damageTakenRecent";
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
