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
	public static var getRifty:Bool = false;

	/** Dirty wakeups from hooks (consume on reconcile). */
	public static var overlayDirty:Bool = true;
	public static var geauxDirty:Bool = true;
	public static var attackComboDirty:Bool = true;
	public static var targetPtrDirty:Bool = true;

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
	public static inline var AURA_STATUS_IDLE_S:Float = 0.15; // ~7 Hz
	public static inline var AURA_STATUS_HOT_S:Float = 0.055; // ~18 Hz
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
		aurasNeedStatus = auras && auraRulesNeedStatus(cfg);
		getRifty = cfg.getRifty != null && !cfg.getRifty.hidden.get();
	}

	static function auraRulesNeedStatus(cfg:ConfigPanel):Bool {
		try {
			for (a in cfg.auras.auras) {
				if (a == null || !a.enabled.get())
					continue;
				if (a.trigger == "status")
					return true;
				if (a.rule != null && a.rule.conditions != null) {
					for (c in a.rule.conditions) {
						if (c == null || c.signal == null)
							continue;
						if (StringTools.startsWith(c.signal, "status."))
							return true;
					}
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
		if (!targetHud)
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
		if (now - lastAuraStatus < need)
			return false;
		lastAuraStatus = now;
		return true;
	}

	public static function dueGetRifty(now:Float, inRift:Bool):Bool {
		if (!getRifty)
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
