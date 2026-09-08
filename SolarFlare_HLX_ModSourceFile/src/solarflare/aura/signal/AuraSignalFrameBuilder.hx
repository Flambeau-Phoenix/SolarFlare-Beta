package solarflare.aura.signal;

import solarflare.HealthCache;
import solarflare.attackcombo.AttackComboCache;
import solarflare.aura.AuraStatusCache;
import solarflare.chaincast.Chaincast;
import solarflare.combo.Combo;
import solarflare.conduit.Conduit;
import solarflare.geaux.GeauxCache;
import solarflare.geaux.GeauxCache.GeauxSlotSnap;
import solarflare.getrifty.GetRifty;
import solarflare.combatlog.CombatLogCache;

class AuraSignalFrameBuilder {
	public static function build(frame:AuraSignalFrame, now:Float):Void {
		frame.resetCollections(); frame.generation++; frame.builtAt = now;
		frame.heroKnown = HealthCache.localHero != null;
		frame.healthKnown = HealthCache.valid; frame.healthCurrent = HealthCache.current;
		frame.healthRatio = HealthCache.valid ? HealthCache.ratio() : 0;
		frame.shieldRatio = HealthCache.valid ? clamp01(HealthCache.shield / (HealthCache.max > 0 ? HealthCache.max : 1)) : 0;
		frame.rageKnown = HealthCache.rageValid; frame.rageRatio = frame.rageKnown ? HealthCache.rageRatio() : 0;
		frame.manaKnown = HealthCache.manaValid; frame.manaRatio = frame.manaKnown ? HealthCache.manaRatio() : 0;
		frame.sparkKnown = HealthCache.sparkValid; frame.sparkRatio = frame.sparkKnown ? HealthCache.sparkRatio() : 0;
		frame.genericKnown = HealthCache.resourceValid(); frame.genericRatio = frame.genericKnown ? HealthCache.resourceRatio() : 0;
		frame.comboKnown = ComboPointsCache.valid; frame.comboCount = ComboPointsCache.current; frame.comboMax = ComboPointsCache.max;
		frame.prayerKnown = PrayerCache.active; frame.prayerCharged = PrayerCache.chargedCount;
		frame.prayerLifeReady = PrayerCache.lifeReady; frame.prayerShieldReady = PrayerCache.shieldReady; frame.prayerSmiteReady = PrayerCache.smiteReady;
		frame.chaincastKnown = ChaincastCache.valid; frame.chaincastStacks = ChaincastCache.current; frame.chaincastReady = ChaincastCache.ready;
		frame.chaincastRemaining = ChaincastCache.readyLeft; frame.chaincastProgress = ChaincastCache.readyProgress;
		frame.conduitKnown = ConduitCache.valid; frame.conduitFilled = ConduitCache.filledCount;
		frame.conduitPowerStacks = ConduitCache.powerStacks; frame.conduitPowerLeft = ConduitCache.powerLeft;
		frame.attackComboKnown = frame.heroKnown; frame.attackComboStep = AttackComboCache.step;
		frame.attackComboWithin = AttackComboCache.withinCombo; frame.attackComboFinal = AttackComboCache.flashFinal;
		frame.inRift = GetRiftyCache.inInstance; frame.encounterKnown = true;
		fillTarget(frame);
		var kk = CombatLogCache.consumeKillKind();
		frame.killKind = kk;
		frame.killKnown = kk.length > 0;
		addSkills(frame, GeauxCache.slots); addSkills(frame, GeauxCache.weapons); addSkills(frame, GeauxCache.signatures);
		frame.statusDomainKnown = frame.heroKnown;
		var n = AuraStatusCache.count; if (n > AuraSignalFrame.MAX_STATUSES) n = AuraSignalFrame.MAX_STATUSES;
		for (i in 0...n) {
			var src = AuraStatusCache.snaps[i]; if (src == null || src.id == null || src.id.length == 0) continue;
			var dst = frame.statuses[frame.statusCount++]; dst.rawId = src.id; dst.label = "";
			dst.stacks = src.stacks; dst.durationLeft = src.left; dst.durationProgress = clamp01(src.progress); dst.known = true;
		}
	}

	static function fillTarget(frame:AuraSignalFrame):Void {
		var snap = CombatLogCache.currentTargetSnap();
		frame.targetKnown = true;
		frame.targetValid = snap != null && snap.valid;
		if (!frame.targetValid) {
			frame.targetKind = "";
			frame.targetName = "";
			frame.targetRatio = 0;
			frame.targetIsBoss = false;
			frame.targetIsElite = false;
			frame.targetIsMiniboss = false;
			return;
		}
		frame.targetKind = snap.kind != null ? snap.kind : "";
		frame.targetName = snap.name != null ? snap.name : "";
		frame.targetRatio = snap.ratio;
		frame.targetIsBoss = snap.isBoss;
		frame.targetIsElite = snap.isElite;
		frame.targetIsMiniboss = snap.isMiniboss;
	}
	static function addSkills(frame:AuraSignalFrame, list:Array<GeauxSlotSnap>):Void {
		if (list == null) return;
		for (src in list) {
			if (src == null || !src.present || src.id == null || src.id.length == 0 || frame.skillCount >= AuraSignalFrame.MAX_SKILLS) continue;
			if (frame.findSkill(src.id) != null) continue;
			var dst = frame.skills[frame.skillCount++]; dst.rawId = src.id; dst.aliasId = src.iconId; dst.label = src.label;
			dst.ready = src.ready; dst.affordable = src.affordable; dst.cooldownLeft = src.cdLeft;
			dst.cooldownProgress = clamp01(src.remaining); dst.inCooldown = !src.ready || src.cdLeft > 0.05; dst.known = true;
		}
	}
	static inline function clamp01(v:Float):Float return v < 0 ? 0 : (v > 1 ? 1 : v);
}
