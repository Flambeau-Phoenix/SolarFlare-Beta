package solarflare.runtime;

import solarflare.HealthCache;
import solarflare.HealthHooks;
import solarflare.ObserveDemand;
import solarflare.attackcombo.AttackComboCache;
import solarflare.combatlog.CombatLogCache;
import solarflare.geaux.GeauxCache;
import solarflare.getrifty.GetRifty.GetRiftyCache;
import solarflare.lightsaber.Lightsaber.LightsaberCache;
import solarflare.lightsaber.Lightsaber.SaberJsonlArchive;
import solarflare.ui.ConfigPanel;
import solarflare.ui.GameIcons;

/**
 * One scheduler for all engine observation. Hooks only update O(1) state or mark
 * HookIngress; continuous values reconcile here under frozen consumer demand.
 */
class TelemetryKernel {
	static inline var VITALS_S:Float = 0.033;
	static inline var BACKGROUND_S:Float = 0.100;
	static inline var IDENTITY_S:Float = 1.0;
	static inline var SETTINGS_S:Float = 0.250;
	static inline var ASSET_S:Float = 0.100;

	public static var demand(default, null) = new DemandSnapshot();
	static var lastVitals:Float = 0;
	static var lastIdentity:Float = 0;
	static var activeGate = new ActivePassGate();
	static var lastBackground:Float = 0;
	static var lastSettings:Float = 0;
	static var lastAsset:Float = -1;
	static var brandingRequested:Bool = false;
	static var settingsInitialized:Bool = false;
	static var statusHeroGeneration:Int = -1;
	static var statusProfileGeneration:Int = -1;

	public static function observeAssets():Void {
		var pending = !brandingRequested || GameIcons.hasPending()
			|| solarflare.ui.CustomImages.hasPending()
			|| solarflare.attackcombo.AttackComboArt.hasPending();
		if (!pending)
			return;
		var now = stamp();
		var due = now - lastAsset >= ASSET_S;
		// Icon decoding is time-budgeted per call (GameIcons.PRELOAD_BUDGET_S), so it may run every observe while work is queued.
		if (!due && !GameIcons.hasPending())
			return;
		if (due) {
			lastAsset = now;
			solarflare.ui.CustomImages.observe();
			if (!brandingRequested) {
				brandingRequested = true;
				GameIcons.get(GameIcons.CHROME_SUN);
				GameIcons.get(GameIcons.RIFT_SUN);
				GameIcons.get(GameIcons.HUB_LOGO);
				GameIcons.get("castbar_solar");
				GameIcons.get("castbar_obsidian");
				GameIcons.get("castbar_gilded");
			}
		}
		if (GameIcons.hasPending())
			GameIcons.tickPreload();
		if (due && solarflare.attackcombo.AttackComboArt.hasPending())
			solarflare.attackcombo.AttackComboArt.tickPreload();
	}

	public static function observe(app:GameApp, cfg:ConfigPanel,
			restoreNativeChat:Void->Void):Void {
		if (app == null || cfg == null)
			return;
		var now = stamp();
		if (!settingsInitialized) {
			settingsInitialized = true;
			try solarflare.ui.SettingsStore.tick(cfg) catch (_:Dynamic) {}
		}
		solarflare.hemorrhage.HemorrhageService.beforeDrain(now);
		cfg.hemorrhage.observe(HealthCache.localHero, now);
		if(cfg.auraBuilder!=null) cfg.auraBuilder.observeShares();
		ObserveDemand.publish(cfg);
		if((solarflare.aura.StatusTypeDemand.meMask|solarflare.aura.StatusTypeDemand.enemyMask)==0) solarflare.aura.StatusTypeService.reset();
		demand.capture(cfg);
		if(!ObserveDemand.aurasNeedTargetStatus) solarflare.aura.TargetStatusCache.reset();
		EventRing.drain(solarflare.combatlog.CombatLogCache.consumeHookEvent, 128, 0.0005);
		solarflare.hemorrhage.HemorrhageService.afterDrain(now, !cfg.hemorrhage.hidden.get() || cfg.hemorrhage.tool.open.get());

		try solarflare.ui.HideAllBind.ensureCodes() catch (_:Dynamic) {}
		try solarflare.ui.WindowAutoHide.observe(app, now) catch (_:Dynamic) {}

		var identityDirty = HookIngress.consume(DirtyDomains.IDENTITY);
		var identityDue = identityDirty || now - lastIdentity >= IDENTITY_S;
		var vitalsDirty = HookIngress.consume(DirtyDomains.VITALS);
		var vitalsDue = demand.vitals && (vitalsDirty || now - lastVitals >= VITALS_S);
		if (identityDue || vitalsDue) {
			RuntimeMetrics.fastPasses++;
			if (identityDue) {
				lastIdentity = now;
				RuntimeMetrics.identityPolls++;
			}
			try HealthHooks.observeLocalPlayer(app) catch (_:Dynamic) {}
			if (vitalsDue) {
				lastVitals = now;
				RuntimeMetrics.vitalsPolls++;
				try HealthHooks.observeLocal() catch (_:Dynamic) {}
			}
		}

		solarflare.aura.AuraMovementObserver.observe(now,ObserveDemand.aurasNeedDash || !cfg.dash.hidden.get());
		// One status owner for Aura, Board, Spark Cube and BarTer. Consumers never resample.
		if (statusHeroGeneration != HealthCache.statusOwnerGen
			|| statusProfileGeneration != solarflare.ui.FeatureProfiles.statusOwnerGen) {
			statusHeroGeneration = HealthCache.statusOwnerGen;
			statusProfileGeneration = solarflare.ui.FeatureProfiles.statusOwnerGen;
			solarflare.aura.AuraStatusCache.invalidateOwner();
			solarflare.aura.StatusTypeService.reset();
		}
		if (demand.status && ObserveDemand.dueAuraStatus(now, false)) {
			try {
				solarflare.aura.AuraStatusCache.sample(HealthCache.localHero, now);
				RuntimeMetrics.statusPolls++;
			} catch (_:Dynamic) {}
		}

		// These consumers own an independent ObserveDemand cadence.
		if (cfg != null && cfg.combo != null)
			solarflare.combo.Combo.ComboPointsCache.configureMax(cfg.combo.points());
		HookIngress.consume(DirtyDomains.OVERLAYS | DirtyDomains.ATTACK_COMBO);
		try HealthHooks.reconcileOverlays() catch (_:Dynamic) {}
		try {
			if (ObserveDemand.dueAttackCombo(now,
					AttackComboCache.withinCombo || AttackComboCache.flashFinal))
				AttackComboCache.observe();
			else
				AttackComboCache.tick(); // Hook-led state: expire a finisher flash without a poll.
		} catch (_:Dynamic) {}

		var wanted = (demand.skills ? DirtyDomains.SKILLS : 0)
			| (demand.target ? DirtyDomains.TARGET : 0)
			| (demand.auras ? DirtyDomains.STATUS : 0);
		LightsaberCache.enabled = demand.lightsaber;
		if (activeGate.due(now, wanted, demand.skills || demand.target || demand.auras || demand.lightsaber)) {
			RuntimeMetrics.heavyPasses++;
			if (demand.skills) {
				try {
					cfg.geaux.ensureSlots();
					GeauxCache.sample(HealthCache.localHero, cfg.geaux.visibleCount(), cfg.geaux.slotIds);
					RuntimeMetrics.skillPolls++;
				} catch (_:Dynamic) {}
			}
			if (demand.target) {
				try {
					CombatLogCache.tick(HealthCache.localHero);
					RuntimeMetrics.targetPolls++;
				} catch (_:Dynamic) {}
			}
			if (demand.auras) {
				try {
					solarflare.aura.StatusTypeService.observe(HealthCache.localHero,now);
					solarflare.aura.AuraEngine.tick(cfg.auras);
					RuntimeMetrics.auraTicks++;
				} catch (_:Dynamic) {}
			}
			if (demand.lightsaber) {
				try {
					LightsaberCache.ingestForConfig(cfg.lightsaber);
					LightsaberCache.tick(now);
					if (cfg.lightsaber.showLog.get())
						SaberJsonlArchive.tick();
				} catch (_:Dynamic) {}
			}
		}

		// BarTer: own cadence, offset from ActivePassGate / full Geaux sample.
		if (ObserveDemand.barter && ObserveDemand.dueBarTer(now, GeauxCache.barTerHot())) {
			try {
				var needSeed = cfg.barter != null && cfg.barter.needsActionBarSeed();
				GeauxCache.sampleBarTer(HealthCache.localHero, needSeed);
				RuntimeMetrics.skillPolls++;
			} catch (_:Dynamic) {}
		}

		if (now - lastBackground >= BACKGROUND_S) {
			lastBackground = now;
			try solarflare.castbar.LearnedCastTimes.tick(now) catch (_:Dynamic) {}
			RuntimeMetrics.backgroundPasses++;
			try if (restoreNativeChat != null) restoreNativeChat() catch (_:Dynamic) {}
			if (ObserveDemand.mapContext) {
				try solarflare.aura.AuraMapContext.observe(app, now) catch (_:Dynamic) {}
			}
			try {
				if (solarflare.combatlog.CombatLogRecorder.enabled.get())
					solarflare.combatlog.CombatLogRecorder.tick();
			} catch (_:Dynamic) {}
			if (demand.encounter) {
				try {
					var inRift = GetRiftyCache.inInstance;
					if (ObserveDemand.dueGetRifty(now, inRift)
							#if solarflare_telemetry
							|| solarflare.debug.ResolutionLedger.armed()
							#end
							) {
						GetRiftyCache.observeApp(app);
						RuntimeMetrics.encounterPolls++;
						HookIngress.consume(DirtyDomains.ENCOUNTER);
						try solarflare.combatlog.CombatLogCache.noteRiftState() catch (_:Dynamic) {}
						if (ObserveDemand.getRifty)
							GetRiftyCache.tick();
					}
				} catch (_:Dynamic) {}
			}
			#if solarflare_telemetry
			try {
				if (solarflare.debug.PayloadProbe.armed()) {
					solarflare.debug.PayloadProbe.sampleApp(app);
					solarflare.debug.PayloadProbe.tick();
				}
			} catch (_:Dynamic) {}
			try if (solarflare.debug.ResolutionLedger.armed())
				solarflare.debug.ResolutionLedger.tick() catch (_:Dynamic) {}
			try if (solarflare.debug.FieldWalkLog.armed())
				solarflare.debug.FieldWalkLog.tick() catch (_:Dynamic) {}
			try solarflare.geaux.GeauxLog.tick() catch (_:Dynamic) {}
			#end
		}

		if (solarflare.ui.SettingsStore.isDirty() && now - lastSettings >= SETTINGS_S) {
			lastSettings = now;
			try solarflare.ui.SettingsStore.tick(cfg) catch (_:Dynamic) {}
		}
	}

	public static function reset():Void {
		solarflare.aura.StatusTypeService.reset();
		solarflare.aura.AuraStatusCache.invalidateOwner();
		statusHeroGeneration = statusProfileGeneration = -1;
		lastVitals = lastIdentity = lastBackground = lastSettings = 0;
		activeGate.reset();
		settingsInitialized = false;
		HookIngress.reset();
	}

	static function stamp():Float {
		try return haxe.Timer.stamp() catch (_:Dynamic) return Date.now().getTime() / 1000.0;
	}
}
