package solarflare;

import solarflare.ui.ConfigPanel;

/**
 * Per-frame observe demand + dirty wakeups.
 * SolarFlarePanel.publish() each observe; hooks mark dirty; samplers reconcile on cadence.
 */
class ObserveDemand {
	/** Overlay / feature demand (set from config visibility). */
	public static var resourceBars:Bool = false;
	public static var prayers:Bool = false;
	public static var comboPoints:Bool = false;
	public static var chaincast:Bool = false;
	public static var conduit:Bool = false;
	public static var attackCombo:Bool = false;
	public static var targetHud:Bool = false;
	public static var combatLog:Bool = false;
	public static var geaux:Bool = false;
	public static var geauxBuilder:Bool = false;
	public static var auras:Bool = false;
	public static var aurasNeedStatus:Bool = false;
	public static var statusIds:Array<String> = [];
	public static var aurasNeedInstant:Bool = false;
	public static var aurasNeedSpecial:Bool = false;
	public static var aurasNeedEnemyCast:Bool = false;
	/** Target snap for auras even when Target HUD is hidden. */
	public static var aurasNeedTarget:Bool = false;
	/** Skill subjects for skill.instantReady (sanitized IDs, rebuilt each publish). */
	public static var instantSkillIds:Array<String> = [];
	/** Skill subjects for skill.specialReady (sanitized IDs, rebuilt each publish). */
	public static var specialSkillIds:Array<String> = [];
	/** Skill subjects for event.cast.* (sanitized IDs, rebuilt each publish). */
	public static var castSkillIds:Array<String> = [];
	public static var auraBuilderOpen:Bool = false;
	public static var getRifty:Bool = false;
	/** Sample GetRiftyCache.inInstance even when clock overlay hidden (combat log / saber). */
	public static var riftFlag:Bool = false;
	/** Dirty wakeups from hooks (consume on reconcile). */
	public static var overlayDirty:Bool = true;
	public static var geauxDirty:Bool = true;
	public static var attackComboDirty:Bool = true;
	public static var targetPtrDirty:Bool = true;
	/** Local Status lifecycle / net status sync — StatusObserveHooks. */
	public static var auraStatusDirty:Bool = true;
	/** Rebuild statusIds / instant/special/cast subject lists when aura config mutates. */
	public static var statusDemandDirty:Bool = true;
	static var rawNeedInstant:Bool = false;
	static var rawNeedSpecial:Bool = false;
	static var rawNeedEnemyCast:Bool = false;
	static var rawNeedTarget:Bool = false;

	static var lastOverlayReconcile:Float = 0;
	static var lastIdentityReconcile:Float = 0;
	static var lastTargetHp:Float = 0;
	static var lastAuraStatus:Float = 0;
	static var lastGetRifty:Float = 0;
	static var lastAttackCombo:Float = 0;

	public static inline var OVERLAY_IDLE_S:Float = 0.25; // ~4 Hz fallback
	public static inline var OVERLAY_ACTIVE_S:Float = 0.12; // ~8 Hz when dirty/active
	public static inline var IDENTITY_S:Float = 1.0;
	public static inline var TARGET_HP_S:Float = 0.10; // 10 Hz
	/** Slow safety poll; StatusObserveHooks dirty-wake owns edges. */
	public static inline var AURA_STATUS_IDLE_S:Float = 1.0;
	public static inline var AURA_STATUS_HOT_S:Float = 0.35;
	/** Coalesce bursty Status mutators (init+stacks+refresh). */
	public static inline var AURA_STATUS_DIRTY_S:Float = 0.02;
	public static inline var GETRIFTY_OUT_S:Float = 0.75;
	public static inline var GETRIFTY_IN_S:Float = 0.25;
	public static inline var ATTACK_IDLE_S:Float = 0.25;
	public static inline var ATTACK_HOT_S:Float = 0.055;

	public static function publish(cfg:ConfigPanel):Void {
		if (cfg == null)
			return;
		resourceBars = cfg.vitals != null && cfg.vitals.anyBarVisible();
		prayers = cfg.vitals != null && !cfg.vitals.prayersHidden.get();
		comboPoints = cfg.combo != null && !cfg.combo.hidden.get();
		chaincast = cfg.chaincast != null && !cfg.chaincast.hidden.get();
		conduit = cfg.conduit != null && !cfg.conduit.hidden.get();
		attackCombo = cfg.attackCombo != null && (!cfg.attackCombo.hidden.get() || cfg.attackCombo.open.get());
		targetHud = cfg.target != null && !cfg.target.hidden.get();
		combatLog = cfg.combatLog != null && !cfg.combatLog.hidden.get();
		geaux = cfg.geaux != null && cfg.geaux.enabled.get();
		geauxBuilder = cfg.geauxBuilder != null && cfg.geauxBuilder.open.get();
		auras = cfg.auras != null && cfg.auras.enabled.get() && cfg.auras.auras != null && cfg.auras.auras.length > 0;
		auraBuilderOpen = cfg.auraBuilder != null && cfg.auraBuilder.open.get();
		if (statusDemandDirty) {
			statusDemandDirty = false;
			while (statusIds.length > 0)
				statusIds.pop();
			while (instantSkillIds.length > 0)
				instantSkillIds.pop();
			while (specialSkillIds.length > 0)
				specialSkillIds.pop();
			while (castSkillIds.length > 0)
				castSkillIds.pop();
			if (cfg.auras != null)
				auraRulesNeedStatus(cfg);
			rawNeedInstant = auraRulesNeedInstant(cfg);
			rawNeedSpecial = auraRulesNeedSpecial(cfg);
			rawNeedEnemyCast = auraRulesNeedEnemyCast(cfg);
			rawNeedTarget = auraRulesNeedTarget(cfg);
			// Instant-ready scripts gate on owner *_Proc only (not bare skill / *_Status).
			if (rawNeedInstant) {
				for (id in instantSkillIds)
					pushStatusId(id + "_Proc");
			}
		}
		aurasNeedInstant = auras && rawNeedInstant;
		aurasNeedSpecial = auras && rawNeedSpecial;
		aurasNeedEnemyCast = (auras && rawNeedEnemyCast) || auraBuilderOpen;
		aurasNeedTarget = (auras && rawNeedTarget) || auraBuilderOpen;
		aurasNeedStatus = statusIds.length > 0 || auraBuilderOpen;
		getRifty = cfg.getRifty != null && !cfg.getRifty.hidden.get();
		var saberRift = cfg.lightsaber != null && !cfg.lightsaber.hidden.get() && cfg.lightsaber.showRiftMeter.get();
		riftFlag = getRifty || combatLog || saberRift;
	}

	public static function markStatusDemandDirty():Void {
		statusDemandDirty = true;
	}

	static function auraRulesNeedStatus(cfg:ConfigPanel):Bool {
		try {
			for (a in cfg.auras.auras) {
				if (a == null || !a.enabled.get())
					continue;
				if (a.trigger == "status") addStatusId(a.skillId);
				if (a.rule != null && a.rule.conditions != null) {
					for (c in a.rule.conditions) {
						if (c == null || c.signal == null)
							continue;
						if (StringTools.startsWith(c.signal, "status."))
							addStatusId(c.subject);
					}
				}
			}
		} catch (_:Dynamic) {}
		return statusIds.length > 0;
	}

	static function addStatusId(id:String):Void {
		if (id == null) return;
		id = StringTools.trim(id);
		if (id.length == 0) return;
		pushStatusId(id);
		// Status alerts: plain skill ids expand to common companions on the hero.
		// Instant Cast subjects do not go through here (Proc-only above).
		if (!looksLikeStatusId(id)) {
			pushStatusId(id + "_Proc");
			pushStatusId(id + "_Status");
		}
	}

	static function pushStatusId(id:String):Void {
		if (id == null || id.length == 0) return;
		if (statusIds.indexOf(id) < 0) statusIds.push(id);
	}

	static function looksLikeStatusId(id:String):Bool {
		// Case-stable engine suffixes — no toLowerCase alloc.
		return StringTools.endsWith(id, "_Status") || StringTools.endsWith(id, "_status")
			|| StringTools.endsWith(id, "_Proc") || StringTools.endsWith(id, "_proc")
			|| StringTools.endsWith(id, "Status") || StringTools.endsWith(id, "status")
			|| id.indexOf("_Status_") >= 0 || id.indexOf("_status_") >= 0
			|| id.indexOf("Status_") >= 0 || id.indexOf("status_") >= 0
			|| id.indexOf("_Proc_") >= 0 || id.indexOf("_proc_") >= 0;
	}

	static function auraRulesNeedInstant(cfg:ConfigPanel):Bool {
		instantSkillIds = [];
		var need = false;
		try {
			for (a in cfg.auras.auras) {
				if (a == null || !a.enabled.get())
					continue;
				if (a.rule == null || a.rule.conditions == null)
					continue;
				for (c in a.rule.conditions) {
					if (c == null || c.signal != "skill.instantReady")
						continue;
					need = true;
					if (c.subject == null || c.subject.length == 0)
						continue;
					var id = solarflare.geaux.GeauxCache.sanitizeSkillId(c.subject);
					if (id.length == 0)
						continue;
					var dup = false;
					for (have in instantSkillIds)
						if (have == id) {
							dup = true;
							break;
						}
					if (!dup)
						instantSkillIds.push(id);
				}
			}
		} catch (_:Dynamic) {}
		return need;
	}

	static function auraRulesNeedSpecial(cfg:ConfigPanel):Bool {
		specialSkillIds = [];
		var need = false;
		try {
			for (a in cfg.auras.auras) {
				if (a == null || !a.enabled.get() || a.rule == null || a.rule.conditions == null)
					continue;
				for (c in a.rule.conditions) {
					if (c == null || c.signal != "skill.specialReady")
						continue;
					need = true;
					if (c.subject == null || c.subject.length == 0)
						continue;
					var id = solarflare.geaux.GeauxCache.sanitizeSkillId(c.subject);
					if (id.length == 0)
						continue;
					var dup = false;
					for (have in specialSkillIds)
						if (have == id) {
							dup = true;
							break;
						}
					if (!dup)
						specialSkillIds.push(id);
				}
			}
		} catch (_:Dynamic) {}
		return need;
	}

	static function auraRulesNeedEnemyCast(cfg:ConfigPanel):Bool {
		castSkillIds = [];
		var need = false;
		try {
			for (a in cfg.auras.auras) {
				if (a == null || !a.enabled.get() || a.rule == null || a.rule.conditions == null)
					continue;
				for (c in a.rule.conditions) {
					if (c == null || c.signal == null)
						continue;
					if (c.signal != "event.cast.recent" && c.signal != "event.cast.active")
						continue;
					need = true;
					if (c.subject == null || c.subject.length == 0)
						continue;
					var id = solarflare.geaux.GeauxCache.sanitizeSkillId(c.subject);
					if (id.length == 0)
						continue;
					var dup = false;
					for (have in castSkillIds)
						if (have == id) {
							dup = true;
							break;
						}
					if (!dup)
						castSkillIds.push(id);
				}
			}
		} catch (_:Dynamic) {}
		return need;
	}

	static function auraRulesNeedTarget(cfg:ConfigPanel):Bool {
		try {
			for (a in cfg.auras.auras) {
				if (a == null || !a.enabled.get() || a.rule == null || a.rule.conditions == null)
					continue;
				for (c in a.rule.conditions) {
					if (c == null || c.signal == null)
						continue;
					if (StringTools.startsWith(c.signal, "target."))
						return true;
				}
			}
		} catch (_:Dynamic) {}
		return false;
	}

	public static inline function markOverlayDirty():Void
		overlayDirty = true;

	public static inline function markGeauxDirty():Void
		geauxDirty = true;

	public static inline function markAttackComboDirty():Void
		attackComboDirty = true;

	public static inline function markTargetPtrDirty():Void
		targetPtrDirty = true;

	public static inline function markAuraStatusDirty():Void
		auraStatusDirty = true;

	public static function dueOverlayReconcile(now:Float):Bool {
		if (!(prayers || comboPoints || chaincast || conduit))
			return false;
		var need = OVERLAY_IDLE_S;
		if (overlayDirty)
			need = OVERLAY_ACTIVE_S;
		if (now - lastOverlayReconcile < need)
			return false;
		lastOverlayReconcile = now;
		overlayDirty = false;
		return true;
	}

	public static function dueIdentity(now:Float):Bool {
		if (now - lastIdentityReconcile < IDENTITY_S)
			return false;
		lastIdentityReconcile = now;
		return true;
	}

	public static function dueTargetHp(now:Float):Bool {
		if (!targetHud && !aurasNeedTarget && !auraBuilderOpen)
			return false;
		if (now - lastTargetHp < TARGET_HP_S)
			return false;
		lastTargetHp = now;
		return true;
	}

	public static function dueAuraStatus(now:Float, hot:Bool):Bool {
		if (!aurasNeedStatus)
			return false;
		var need = hot ? AURA_STATUS_HOT_S : AURA_STATUS_IDLE_S;
		if (auraStatusDirty)
			need = AURA_STATUS_DIRTY_S;
		if (now - lastAuraStatus < need)
			return false;
		lastAuraStatus = now;
		auraStatusDirty = false;
		return true;
	}

	public static function dueGetRifty(now:Float, inRift:Bool):Bool {
		if (!riftFlag)
			return false;
		var need = inRift ? GETRIFTY_IN_S : GETRIFTY_OUT_S;
		if (now - lastGetRifty < need)
			return false;
		lastGetRifty = now;
		return true;
	}

	public static function dueAttackCombo(now:Float, hot:Bool):Bool {
		if (!attackCombo)
			return false;
		if (attackComboDirty) {
			attackComboDirty = false;
			lastAttackCombo = now;
			return true;
		}
		var need = hot ? ATTACK_HOT_S : ATTACK_IDLE_S;
		if (now - lastAttackCombo < need)
			return false;
		lastAttackCombo = now;
		return true;
	}
}
