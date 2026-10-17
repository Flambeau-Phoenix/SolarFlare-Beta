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
	/** Chaincast Cast Trail module is on: HealthHooks keeps LocalCastHistory fed for it. */
	public static var chainTrail:Bool = false;
	public static var conduit:Bool = false;
	public static var attackCombo:Bool = false;
	public static var targetHud:Bool = false;
	public static var castBars:Bool = false;
	public static var combatLog:Bool = false;
	/** Chaincast/conduit status ids are in statusIds (visible overlay and a mage hero). */
	static var mageStatusDemanded:Bool = false;
	/**
	 * Any reader of CombatLogCache lines (log window, recorder, Lightsaber, auras, Spark Cube).
	 * The damage/cast hooks return before attribution when false.
	 */
	public static var combatLines:Bool = false;
	public static var hemorrhage:Bool = false;
	public static var geaux:Bool = false;
	public static var geauxBuilder:Bool = false;
	/** BarTer skill bars — light sampleBarTer path, not full Geaux skills demand. */
	public static var barter:Bool = false;
	/** Assigned BarTer skill ids (rebuilt each publish when barter demanded). */
	public static var barterSkillIds:Array<String> = [];
	public static var barterStatusIds:Array<String> = [];
	public static var barterBuilderOpen:Bool = false;
	public static var auras:Bool = false;
	public static var aurasNeedStatus:Bool = false;
	/** status.count / status.overflow need length only, never per-entry ingestion. */
	public static var needsStatusContainer:Bool = false;
	/** Movable StatusBoard requests budgeted discovery of hero.statuses. */
	public static var statusBoard:Bool = false;
	public static var aurasNeedConsumables:Bool = false;
	public static var extraBarsNeedConsumables:Bool = false;
	public static var consumableIds:Array<String> = [];
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
	/** Every enabled aura skill subject, independent of visible overlay slots. */
	public static var auraSkillIds:Array<String> = [];
	/** Skill subjects for event.cast.* (sanitized IDs, rebuilt each publish). */
	public static var castSkillIds:Array<String> = [];
	public static var auraBuilderOpen:Bool = false;
	/** Sample the current map: a map-bound Aura Set, the combat recorder, or the Aura Builder wants it. */
	public static var mapContext:Bool = false;
	public static var getRifty:Bool = false;
	/** Sample GetRiftyCache.inInstance even when clock overlay hidden (combat log / saber). */
	public static var riftFlag:Bool = false;
	/** Dirty wakeups from hooks (consume on reconcile). */
	public static var overlayDirty:Bool = true;
	public static var geauxDirty:Bool = true;
	public static var attackComboDirty:Bool = true;
	public static var targetPtrDirty:Bool = true;
	/** Local skill-use/configuration requests; lifecycle hooks remain retired. */
	public static var auraStatusDirty:Bool = true;
	/** Coalesced discovery request; status scheduler must not consume it before the cache. */
	public static var statusDiscoveryDirty:Bool = true;
	/** Rebuild statusIds / instant/special/cast subject lists when aura config mutates. */
	public static var statusDemandDirty:Bool = true;
	static var auraConditions:Array<solarflare.aura.signal.AuraConditionDef> = [];
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
	static var lastBarTer:Float = 0;

	/** Continuous class state authority after removal of class-specific trampolines. */
	public static inline var OVERLAY_IDLE_S:Float = 0.05; // 20 Hz demanded sample
	public static inline var OVERLAY_ACTIVE_S:Float = 0.05;
	public static inline var IDENTITY_S:Float = 1.0;
	public static inline var TARGET_HP_S:Float = 0.10; // 10 Hz
	/** Sole 20 Hz authority for demanded local status values. */
	public static inline var AURA_STATUS_IDLE_S:Float = 0.05;
	public static inline var AURA_STATUS_HOT_S:Float = 0.05;
	/**
	 * Dirty wake ceiling. Was 0.0, which let a net-sync burst return due at full frame
	 * rate and made the HOT / IDLE split dead; AuraStatusCache.sample absorbed the extra
	 * calls but the gate lied. Status removal still lands instantly via markAbsent.
	 */
	public static inline var AURA_STATUS_DIRTY_S:Float = 0.05;
	public static inline var GETRIFTY_OUT_S:Float = 0.75;
	public static inline var GETRIFTY_IN_S:Float = 0.25;
	public static inline var ATTACK_IDLE_S:Float = 0.25;
	public static inline var ATTACK_HOT_S:Float = 0.055;
	/** Staggered vs ActivePassGate 50 ms / Geaux telemetry 50–120 ms. */
	public static inline var BARTER_IDLE_S:Float = 0.11;
	public static inline var BARTER_HOT_S:Float = 0.06;

	public static function publish(cfg:ConfigPanel):Void {
		if (cfg == null)
			return;
		resourceBars = cfg.vitals != null && cfg.vitals.anyBarVisible();
		prayers = cfg.vitals != null && !cfg.vitals.prayersHidden.get();
		comboPoints = cfg.combo != null && !cfg.combo.hidden.get();
		chaincast = cfg.chaincast != null && (!cfg.chaincast.hidden.get() || cfg.chaincast.modules.anyVisible());
		chainTrail = chaincast && cfg.chaincast.modules.trailWanted();
		conduit = cfg.conduit != null && !cfg.conduit.hidden.get();
		attackCombo = cfg.attackCombo != null && (!cfg.attackCombo.hidden.get() || cfg.attackCombo.open.get());
		targetHud = cfg.target != null && !cfg.target.hidden.get();
		castBars = (cfg.castBar != null && !cfg.castBar.hidden.get())
			|| (cfg.target != null && !cfg.target.hidden.get() && cfg.target.showCastBar.get());
		combatLog = cfg.combatLog != null && !cfg.combatLog.hidden.get();
		geaux = cfg.geaux != null && cfg.geaux.enabled.get();
		geauxBuilder = cfg.geauxBuilder != null && cfg.geauxBuilder.open.get();
		barter = cfg.barter != null && (cfg.barter.demand() || (cfg.barter.config != null && cfg.barter.config.open.get()));
		barterBuilderOpen = cfg.barter != null && cfg.barter.config.open.get();
		var barterNeedsItems = barter && cfg.barter != null && cfg.barter.config != null
			&& (cfg.barter.config.open.get() || solarflare.barter.BarTerCache.hasAnyItem(cfg.barter.config));
		extraBarsNeedConsumables = (cfg.extraBarsPrototype != null
			&& (cfg.extraBarsPrototype.model.demand() || cfg.extraBarsPrototype.open.get()))
			|| barterNeedsItems;
		auras = cfg.auras != null && cfg.auras.enabled.get() && cfg.auras.auras != null && cfg.auras.auras.length > 0;
		// Mage overlays read statuses from the one status owner; their ids join the demand set.
		var mageStatus = (chaincast || conduit) && solarflare.HealthHooks.localIsMage;
		if (mageStatus != mageStatusDemanded) {
			mageStatusDemanded = mageStatus;
			statusDemandDirty = true;
		}
		auraBuilderOpen = cfg.auraBuilder != null && cfg.auraBuilder.open.get();
		if (statusDemandDirty) {
			statusDemandDirty = false;
			needsStatusContainer = false;
			auraSkillIds.resize(0);
			while (statusIds.length > 0)
				statusIds.pop();
			while (instantSkillIds.length > 0)
				instantSkillIds.pop();
			while (specialSkillIds.length > 0)
				specialSkillIds.pop();
			while (castSkillIds.length > 0)
				castSkillIds.pop();
			consumableIds.resize(0);
			if (cfg.extraBarsPrototype != null && cfg.extraBarsPrototype.model.sparkEnabled) pushStatusId("SparkSurge_Status");
			if (cfg.stacks != null) {
				for (tracker in cfg.stacks.config.trackers) if (tracker.enabled && tracker.statusId.length > 0) pushStatusId(tracker.statusId);
			}
			if (mageStatusDemanded) {
				if (chaincast) {
					pushStatusId(solarflare.chaincast.Chaincast.ChaincastCache.statusId());
					pushStatusId(solarflare.chaincast.Chaincast.ChaincastCache.accumId());
				}
				if (conduit)
					for (id in solarflare.conduit.Conduit.ConduitCache.lookupIds()) pushStatusId(id);
			}
			auraConditions.resize(0);
			if (cfg.auras != null) {
				for (a in cfg.auras.auras) if (a != null && a.enabled.get()) {
					solarflare.aura.signal.AuraRuleDemand.append(a.rule, a.canvasElements, auraConditions);
					if (a.rule == null && a.trigger == "cooldown") pushAuraSkillId(a.skillId);
					if (a.trigger == "status") addStatusId(a.skillId);
				}
			}
			for (c in auraConditions) {
				if (c.signal == null) continue;
				if (StringTools.startsWith(c.signal, "skill.")) pushAuraSkillId(c.subject);
				if (StringTools.startsWith(c.signal, "consumable.")) {
					var entry = solarflare.cdb.ConsumableCatalog.find(c.subject);
					if (entry != null && consumableIds.indexOf(entry.id) < 0) {
						consumableIds.push(entry.id);
						for (effect in entry.statuses) pushStatusId(effect.id);
					}
				}
			}
			auraRulesNeedStatus(cfg);
			rawNeedInstant = auraRulesNeedInstant(cfg);
			rawNeedSpecial = auraRulesNeedSpecial(cfg);
			rawNeedEnemyCast = auraRulesNeedEnemyCast(cfg);
			rawNeedTarget = auraRulesNeedTarget(cfg);
			// Instant-ready scripts gate on owner *_Proc only (not bare skill / *_Status).
			if (rawNeedInstant) {
				for (id in instantSkillIds) {
					var proc = EngineSkillId.procOf(id);
					if (proc.length > 0)
						pushStatusId(proc);
				}
			}
		}
		// BarTer subjects: bounded rebuild (three active bars × 64 cells), own poll path.
		barterSkillIds.resize(0);
		barterStatusIds.resize(0);
		if (barter && cfg.barter != null && cfg.barter.config != null) {
			for (b in cfg.barter.config.bars) {
				if (b == null || !cfg.barter.config.isActive(b.id)) continue;
				for (i in 0...b.slotCount) {
					var slot = b.slots[i];
					if (slot == null) continue;
					if (slot.hasSkill() && slot.nativeActionId.length==0) pushBarTerSkillId(slot.skillId);
					if (slot.hasStatus() && barterStatusIds.indexOf(slot.statusId) < 0) barterStatusIds.push(slot.statusId);
				}
			}
		}
		statusBoard = cfg.statusBoard != null && (cfg.statusBoard.demand() || cfg.statusSettingsOpen());
		aurasNeedConsumables = (auras && consumableIds.length > 0) || auraBuilderOpen;
		aurasNeedInstant = auras && rawNeedInstant;
		aurasNeedSpecial = auras && rawNeedSpecial;
		aurasNeedEnemyCast = (auras && rawNeedEnemyCast) || auraBuilderOpen;
		aurasNeedTarget = (auras && rawNeedTarget) || auraBuilderOpen;
		aurasNeedStatus = statusIds.length > 0 || barterStatusIds.length > 0 || needsStatusContainer || auraBuilderOpen || barterBuilderOpen || statusBoard;
		getRifty = cfg.getRifty != null && !cfg.getRifty.hidden.get();
		var saberRift = cfg.lightsaber != null && !cfg.lightsaber.hidden.get() && cfg.lightsaber.showRiftMeter.get();
		var recording = false;
		try
			recording = solarflare.combatlog.CombatLogRecorder.enabled.get()
		catch (_:Dynamic)
			recording = false;
		riftFlag = getRifty || combatLog || saberRift || auras || auraBuilderOpen || recording;
		mapContext = auraBuilderOpen || recording || (cfg.auras != null && cfg.auras.anySetUsesMaps());
		var saber = cfg.lightsaber != null && (!cfg.lightsaber.hidden.get() || cfg.lightsaber.showLog.get());
		var sparkCube = cfg.extraBarsPrototype != null && cfg.extraBarsPrototype.model.sparkEnabled;
		hemorrhage = solarflare.hemorrhage.HemorrhageService.active();
		combatLines = combatLog || recording || saber || auras || auraBuilderOpen || sparkCube || hemorrhage;
		#if solarflare_telemetry
		riftFlag = riftFlag || solarflare.debug.ResolutionLedger.armed();
		#end
	}

	public static function markStatusDemandDirty():Void {
		statusDemandDirty = true;
		statusDiscoveryDirty = true;
	}

	static function pushAuraSkillId(id:String):Void {
		if (id == null) return;
		id = solarflare.geaux.GeauxCache.sanitizeSkillId(id);
		if (id.length > 0 && auraSkillIds.indexOf(id) < 0 && auraSkillIds.length < 256) auraSkillIds.push(id);
	}

	static function pushBarTerSkillId(id:String):Void {
		if (id == null) return;
		id = solarflare.geaux.GeauxCache.sanitizeSkillId(id);
		if (id.length > 0 && barterSkillIds.indexOf(id) < 0 && barterSkillIds.length < 192)
			barterSkillIds.push(id);
	}

	/** Staggered BarTer skill poll — idle ~9 Hz, hot ~16 Hz while any assigned CD. */
	public static function dueBarTer(now:Float, hot:Bool):Bool {
		if (!barter)
			return false;
		var need = hot ? BARTER_HOT_S : BARTER_IDLE_S;
		if (now - lastBarTer < need)
			return false;
		lastBarTer = now;
		return true;
	}

	static function auraRulesNeedStatus(cfg:ConfigPanel):Bool {
		for (c in auraConditions) {
			if (c.signal == "status.count" || c.signal == "status.overflow") needsStatusContainer = true;
			else if (c.signal != null && StringTools.startsWith(c.signal, "status.")) addStatusId(c.subject);
		}
		return statusIds.length > 0 || needsStatusContainer;
	}

	static function addStatusId(id:String):Void {
		if (id == null) return;
		// HL String subjects can look like String but Json/ImGui show {bytes:???}.
		id = solarflare.EngineText.cleanId(id);
		if (id.length == 0) return;
		pushStatusId(id);
		// Status alerts: plain skill ids expand to common companions on the hero.
		// Instant Cast subjects do not go through here (Proc-only above).
		if (!looksLikeStatusId(id)) {
			// From the game's data (EngineSkillId.procOf/statusesOf): only rows that exist; unknown ids keep the guess.
			var proc = EngineSkillId.procOf(id);
			if (proc.length > 0)
				pushStatusId(proc);
			for (st in EngineSkillId.statusesOf(id))
				pushStatusId(st);
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

	static function collectAuraSubjects(signal:String, ids:Array<String>, alternate:String = ""):Bool {
		ids.resize(0);
		var need = false;
		for (c in auraConditions) {
			if (c.signal != signal && (alternate.length == 0 || c.signal != alternate)) continue;
			need = true;
			var id = solarflare.geaux.GeauxCache.sanitizeSkillId(c.subject);
			if (id.length > 0 && ids.indexOf(id) < 0) ids.push(id);
		}
		return need;
	}
	static function auraRulesNeedInstant(cfg:ConfigPanel):Bool {
		return collectAuraSubjects("skill.instantReady", instantSkillIds);
	}
	static function auraRulesNeedSpecial(cfg:ConfigPanel):Bool {
		return collectAuraSubjects("skill.specialReady", specialSkillIds);
	}
	static function auraRulesNeedEnemyCast(cfg:ConfigPanel):Bool {
		return collectAuraSubjects("event.cast.recent", castSkillIds, "event.cast.active");
	}
	static function auraRulesNeedTarget(cfg:ConfigPanel):Bool {
		for (c in auraConditions) if (c.signal != null && StringTools.startsWith(c.signal, "target.")) return true;
		return false;
	}

	public static inline function markOverlayDirty():Void
	{
		overlayDirty = true;
		solarflare.runtime.HookIngress.mark(solarflare.runtime.DirtyDomains.OVERLAYS);
	}

	public static inline function markGeauxDirty():Void
	{
		geauxDirty = true;
		solarflare.runtime.HookIngress.mark(solarflare.runtime.DirtyDomains.SKILLS);
	}

	public static inline function markAttackComboDirty():Void
	{
		attackComboDirty = true;
		solarflare.runtime.HookIngress.mark(solarflare.runtime.DirtyDomains.ATTACK_COMBO);
	}


	public static inline function markAuraStatusDirty():Void
	{
		auraStatusDirty = true;
		statusDiscoveryDirty = true;
		solarflare.runtime.HookIngress.mark(solarflare.runtime.DirtyDomains.STATUS);
	}

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
