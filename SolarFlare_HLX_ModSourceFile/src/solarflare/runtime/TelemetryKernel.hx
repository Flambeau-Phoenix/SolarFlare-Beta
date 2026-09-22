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
	static inline var ACTIVE_S:Float = 0.050;
	static inline var BACKGROUND_S:Float = 0.100;
	static inline var IDENTITY_S:Float = 1.0;
	static inline var SETTINGS_S:Float = 0.250;
	static inline var ASSET_S:Float = 0.100;

	public static var demand(default, null) = new DemandSnapshot();
	static var lastVitals:Float = 0;
	static var lastIdentity:Float = 0;
	static var lastActive:Float = 0;
	static var lastBackground:Float = 0;
	static var lastSettings:Float = 0;
	static var lastAsset:Float = -1;
	static var brandingRequested:Bool = false;
	static var settingsInitialized:Bool = false;

	public static function observeAssets():Void {
		var pending = !brandingRequested || GameIcons.hasPending()
			|| solarflare.attackcombo.AttackComboArt.hasPending();
		if (!pending)
			return;
		var now = stamp();
		if (now - lastAsset < ASSET_S)
			return;
		lastAsset = now;
		if (!brandingRequested) {
			brandingRequested = true;
			GameIcons.get(GameIcons.CHROME_SUN);
			GameIcons.get(GameIcons.RIFT_SUN);
			GameIcons.get(GameIcons.HUB_LOGO);
			GameIcons.get("castbar_solar");
			GameIcons.get("castbar_obsidian");
			GameIcons.get("castbar_gilded");
		}
		if (GameIcons.hasPending())
			GameIcons.tickPreload();
		if (solarflare.attackcombo.AttackComboArt.hasPending())
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
		ObserveDemand.publish(cfg);
		demand.capture(cfg);
		EventRing.drain(solarflare.combatlog.CombatLogCache.consumeHookEvent);

		try solarflare.ui.HideAllBind.ensureCodes() catch (_:Dynamic) {}

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

		try HealthHooks.reconcileOverlays() catch (_:Dynamic) {}
		try {
			if (ObserveDemand.dueAttackCombo(now,
					AttackComboCache.withinCombo || AttackComboCache.flashFinal))
				AttackComboCache.observe();
		} catch (_:Dynamic) {}

		var activeDirty = HookIngress.peek(DirtyDomains.STATUS | DirtyDomains.SKILLS
			| DirtyDomains.TARGET | DirtyDomains.OVERLAYS | DirtyDomains.ATTACK_COMBO);
		if (activeDirty || now - lastActive >= ACTIVE_S) {
			lastActive = now;
			RuntimeMetrics.heavyPasses++;
			if (demand.skills) {
				try {
					cfg.geaux.ensureSlots();
					GeauxCache.sample(HealthCache.localHero, cfg.geaux.visibleCount(), cfg.geaux.slotIds);
					RuntimeMetrics.skillPolls++;
					HookIngress.consume(DirtyDomains.SKILLS);
				} catch (_:Dynamic) {}
			}
			if (demand.target) {
				try {
					CombatLogCache.tick(HealthCache.localHero);
					RuntimeMetrics.targetPolls++;
					HookIngress.consume(DirtyDomains.TARGET);
				} catch (_:Dynamic) {}
			}
			if (demand.auras) {
				try {
					solarflare.aura.AuraEngine.tick(cfg.auras);
					RuntimeMetrics.auraTicks++;
					if (demand.status)
						RuntimeMetrics.statusPolls++;
					HookIngress.consume(DirtyDomains.STATUS);
				} catch (_:Dynamic) {}
			}
			if (demand.lightsaber) {
				try {
					LightsaberCache.enabled = true;
					LightsaberCache.ingestForConfig(cfg.lightsaber);
					LightsaberCache.tick(now);
					if (cfg.lightsaber.showLog.get())
						SaberJsonlArchive.tick();
				} catch (_:Dynamic) {}
			} else {
				LightsaberCache.enabled = false;
			}
		}

		if (now - lastBackground >= BACKGROUND_S) {
			lastBackground = now;
			RuntimeMetrics.backgroundPasses++;
			try if (restoreNativeChat != null) restoreNativeChat() catch (_:Dynamic) {}
			try {
				if (solarflare.combatlog.CombatLogRecorder.enabled.get())
					solarflare.combatlog.CombatLogRecorder.tick();
			} catch (_:Dynamic) {}
			if (demand.encounter) {
				try {
					var inRift = GetRiftyCache.inInstance;
					if (ObserveDemand.dueGetRifty(now, inRift)
							|| solarflare.debug.ResolutionLedger.armed()) {
						GetRiftyCache.observeApp(app);
						RuntimeMetrics.encounterPolls++;
						HookIngress.consume(DirtyDomains.ENCOUNTER);
						if (ObserveDemand.getRifty)
							GetRiftyCache.tick();
					}
				} catch (_:Dynamic) {}
			}
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
			#if solarflare_telemetry
			try solarflare.geaux.GeauxLog.tick() catch (_:Dynamic) {}
			#end
		}

		if (solarflare.ui.SettingsStore.isDirty() && now - lastSettings >= SETTINGS_S) {
			lastSettings = now;
			try solarflare.ui.SettingsStore.tick(cfg) catch (_:Dynamic) {}
		}
	}

	public static function reset():Void {
		lastVitals = lastIdentity = lastActive = lastBackground = lastSettings = 0;
		settingsInitialized = false;
		HookIngress.reset();
	}

	static function stamp():Float {
		try return haxe.Timer.stamp() catch (_:Dynamic) return Date.now().getTime() / 1000.0;
	}
}
