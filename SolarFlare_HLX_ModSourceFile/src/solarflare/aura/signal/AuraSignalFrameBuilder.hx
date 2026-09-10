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
		frame.damageTakenRecent = CombatLogCache.maxDamageTakenRecent(5.0);
		frame.damageTakenKnown = true;
		addSkills(frame, GeauxCache.slots); addSkills(frame, GeauxCache.weapons); addSkills(frame, GeauxCache.signatures);
		if (solarflare.ObserveDemand.aurasNeedInstant)
			ensureSkillSubjects(frame, solarflare.ObserveDemand.instantSkillIds);
		if (solarflare.ObserveDemand.aurasNeedSpecial)
			ensureSkillSubjects(frame, solarflare.ObserveDemand.specialSkillIds);
		if (solarflare.ObserveDemand.aurasNeedEnemyCast)
			fillEnemyCasts(frame, now);
		if (solarflare.ObserveDemand.aurasNeedInstant)
			fillInstantReady(frame);
		if (solarflare.ObserveDemand.aurasNeedSpecial)
			fillSpecialReady(frame);
		frame.statusDomainKnown = AuraStatusCache.isCurrent(HealthCache.localHero) && AuraStatusCache.domainKnown;
		frame.setStatusContainerLength(AuraStatusCache.isCurrent(HealthCache.localHero) ? AuraStatusCache.containerLength : -1);
		var n = AuraStatusCache.count; if (n > AuraSignalFrame.MAX_STATUSES) n = AuraSignalFrame.MAX_STATUSES;
		for (i in 0...n) {
			var src = AuraStatusCache.snaps[i]; if (src == null || src.id == null || src.id.length == 0) continue;
			var dst = frame.statuses[frame.statusCount++]; dst.rawId = src.id; dst.label = "";
			dst.ids = src.ids.copy(); dst.present = src.present; dst.durationKnown = src.durationKnown;
			dst.stacks = src.stacks; dst.durationLeft = src.left; dst.durationProgress = clamp01(src.progress);
			dst.known = src.known && AuraStatusCache.isCurrent(HealthCache.localHero);
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
			dst.cooldownProgress = clamp01(src.remaining); dst.inCooldown = !src.ready || src.cdLeft > 0.05;
			dst.charges = src.charges; dst.chargesMax = src.chargesMax; dst.known = true;
		}
	}

	/** Append demanded script-ready subjects even when not on Geaux bar strips. */
	static function ensureSkillSubjects(frame:AuraSignalFrame, ids:Array<String>):Void {
		if (ids == null) return;
		for (id in ids) {
			if (id == null || id.length == 0 || frame.skillCount >= AuraSignalFrame.MAX_SKILLS) continue;
			if (frame.findSkill(id) != null) continue;
			var dst = frame.skills[frame.skillCount++];
			dst.rawId = id;
			dst.aliasId = "";
			dst.label = solarflare.cdb.AuraCatalog.label(id);
			dst.ready = false;
			dst.affordable = false;
			dst.cooldownLeft = 0;
			dst.cooldownProgress = 0;
			dst.inCooldown = false;
			dst.instantReady = false;
			dst.instantReadyKnown = false;
			dst.specialReady = false;
			dst.specialReadyKnown = false;
			dst.known = true;
		}
	}

	static function fillInstantReady(frame:AuraSignalFrame):Void {
		var ids = solarflare.ObserveDemand.instantSkillIds;
		if (ids == null || ids.length == 0) {
			// Demand on but no subjects yet — still scan known snaps if any condition lacks subject.
			var i = 0;
			while (i < frame.skillCount) {
				var dst = frame.skills[i];
				if (dst != null && dst.known)
					readScriptReady(dst, dst.rawId, true, false);
				i++;
			}
			return;
		}
		for (id in ids) {
			var dst = frame.findSkill(id);
			if (dst == null || !dst.known)
				continue;
			readScriptReady(dst, id, true, true);
		}
	}

	static function fillSpecialReady(frame:AuraSignalFrame):Void {
		var ids = solarflare.ObserveDemand.specialSkillIds;
		if (ids == null || ids.length == 0)
			return;
		for (id in ids) {
			var dst = frame.findSkill(id);
			if (dst == null || !dst.known)
				continue;
			readScriptReady(dst, id, false, true);
		}
	}

	static function readScriptReady(dst:SkillSignalSnap, skillId:String, instant:Bool, probe:Bool):Void {
		var ready = false;
		var known = false;
		try {
			var skill = GeauxCache.liveSkill(skillId);
			if (skill != null) {
				var bs:st.skill.BaseSkill = skill;
				var sc:script.SkillScript = bs.script;
				if (sc != null) {
					ready = instant ? sc.shouldPlayInstantly() : sc.shouldHighlightSkill();
					known = true;
				}
			}
		} catch (_:Dynamic) {}
		// Pyroclasm-style scripts: shouldPlayInstantly == owner.getStatusCount(Skill.*_Proc)>0.
		// Fallback when script virtual path misses but the proc status is live on the hero.
		if (instant && !ready) {
			try {
				var hero = HealthCache.localHero;
				if (hero != null) {
					var h:ent.GameObject = cast hero;
					var procId = skillId + "_Proc";
					var n = h.getStatusCount(procId, null);
					if (n > 0) {
						ready = true;
						known = true;
					} else if (!known) {
						known = true; // typed count succeeded; absence is known false
					}
				}
			} catch (_:Dynamic) {}
		}
		if (instant) {
			dst.instantReady = ready;
			dst.instantReadyKnown = known;
		} else {
			dst.specialReady = ready;
			dst.specialReadyKnown = known;
		}
		if (probe && instant) {
			try
				solarflare.debug.PayloadProbe.noteInstant(skillId, known, ready)
			catch (_:Dynamic) {}
		}
		if (instant && solarflare.debug.ResolutionLedger.armed())
			solarflare.debug.ResolutionLedger.touch(
				"skill.instantReady",
				known ? "script" : "miss",
				"AuraSignalFrameBuilder.readScriptReady",
				skillId,
				"bool",
				ready ? "true" : "false",
				known ? "known" : "unknown"
			);
	}

	static function fillEnemyCasts(frame:AuraSignalFrame, now:Float):Void {
		var ids = solarflare.ObserveDemand.castSkillIds;
		if (ids == null || ids.length == 0) {
			// Builder open / demand without subjects: expose all known cache entries.
			fillCastFromCache(frame, null);
			return;
		}
		for (id in ids) {
			if (id == null || id.length == 0 || frame.castCount >= AuraSignalFrame.MAX_CASTS)
				continue;
			if (frame.findCast(id) != null)
				continue;
			var dst = frame.casts[frame.castCount++];
			dst.skillId = id;
			dst.known = true;
			dst.active = solarflare.aura.EnemyCastCache.isActive(id);
			var age = solarflare.aura.EnemyCastCache.ageOf(id);
			dst.age = Math.isFinite(age) ? age : 1e9;
		}
	}

	static function fillCastFromCache(frame:AuraSignalFrame, onlyId:String):Void {
		// Demand without allowlist: still nothing to list until noteStart; leave empty.
	}

	static inline function clamp01(v:Float):Float return v < 0 ? 0 : (v > 1 ? 1 : v);
}
