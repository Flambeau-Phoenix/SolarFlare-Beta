package solarflare;

import solarflare.chaincast.Chaincast;
import solarflare.attackcombo.AttackComboCache;
import solarflare.attackcombo.AttackComboArt;
import solarflare.attackcombo.AttackComboOverlay;
import solarflare.combo.Combo;
import solarflare.conduit.Conduit;
import solarflare.combatlog.CombatLogCache;
import solarflare.combatlog.CombatLogOverlay;
import solarflare.geaux.GeauxBar;
import solarflare.geaux.GeauxCache;
import solarflare.geaux.GeauxHooks;
import solarflare.getrifty.GetRifty;
import solarflare.lightsaber.Lightsaber;
import solarflare.preview.VitalsRenderer;
import solarflare.target.TargetOverlay;
import solarflare.ui.ConfigPanel;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.GameIcons;
import solarflare.ui.VitalsConfig;
import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Theme;

import solarflare.debug.PayloadProbe;
import solarflare.debug.PayloadProbeOverlay;
import solarflare.debug.ResolutionLedger;
import solarflare.debug.ResolutionLedgerOverlay;
import solarflare.HealthCache;

/**
 * SolarFlare panel: Resource Tracker vitals, Geaux, Auras, Notebook, Lightsaber.
 * observe() = Layer 1 cache tick; draw() = Layer 2 ImGui from snaps only.
 * GetRifty overlay draws only when the user unhides it (opt-in).
 */
class SolarFlarePanel {
	static inline var VITALS_FLAGS:Int = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse
		| ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse
		| ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.NoSavedSettings;
	static inline var BAR_GAP:Single = 4;
	static inline var PRAYER_ICON:Single = 30;

	var config:ConfigPanel;
	var geauxBar:GeauxBar;
	var comboOverlay:ComboOverlay;
	var chaincastOverlay:ChaincastOverlay;
	var conduitOverlay:ConduitOverlay;
	var attackComboOverlay:AttackComboOverlay;
	var combatLogOverlay:CombatLogOverlay;
	var targetOverlay:TargetOverlay;
	var launchers:solarflare.ui.HudLaunchers;
	var auraOverlay:solarflare.aura.AuraOverlay;
	var lightsaber:LightsaberOverlay;
	var getRiftyOverlay:GetRiftyOverlay;
	var payloadProbe:PayloadProbeOverlay;
	var resolutionLedger:ResolutionLedgerOverlay;
	var vitalsTheme:Theme;
	/** Persistent VitalSnap pool — reused every frame (DRAW-002). */
	var snapHp:VitalSnap;
	var snapRage:VitalSnap;
	var snapMana:VitalSnap;
	var nativeChatRestored = false;

	public function new() {
		snapHp = new VitalSnap();
		snapRage = new VitalSnap();
		snapMana = new VitalSnap();
		config = new ConfigPanel();
		solarflare.ui.UiActionQueue.bind(config);
		geauxBar = new GeauxBar();
		comboOverlay = new ComboOverlay();
		chaincastOverlay = new ChaincastOverlay();
		conduitOverlay = new ConduitOverlay();
		attackComboOverlay = new AttackComboOverlay();
		combatLogOverlay = new CombatLogOverlay();
		targetOverlay = new TargetOverlay();
		launchers = config.launchers;
		auraOverlay = new solarflare.aura.AuraOverlay(config.auras);
		auraOverlay.openBuilder = function() { config.auraBuilder.open.set(true); };
		geauxBar.openBuilder = function() { config.geauxBuilder.open.set(true); };
		comboOverlay.openBuilder = function() { config.resourceTracker.open.set(true); };
		conduitOverlay.openBuilder = function() { config.resourceTracker.open.set(true); };
		chaincastOverlay.openBuilder = function() { config.resourceTracker.open.set(true); };
		attackComboOverlay.openBuilder = function() { config.resourceTracker.open.set(true); };

		targetOverlay.openBuilder = function() { config.target.open.set(true); };
		lightsaber = new LightsaberOverlay();
		getRiftyOverlay = new GetRiftyOverlay();
		payloadProbe = new PayloadProbeOverlay();
		resolutionLedger = new ResolutionLedgerOverlay();
		vitalsTheme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(6, 6))
			.varV(ImGuiStyleVar.ItemSpacing, ImGui.vec2(4, BAR_GAP))
			.varF(ImGuiStyleVar.WindowRounding, 6)
			.varF(ImGuiStyleVar.FrameRounding, 3)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0.08, 0.09, 0.11, 0.82))
			.color(ImGuiCol.Border, ImGui.vec4(0.22, 0.24, 0.28, 0.55))
			.color(ImGuiCol.ResizeGrip, ImGui.vec4(0.35, 0.40, 0.48, 0.45));
		CursorCaptureFix.ensureHardwareCursor();
	}

	var lastFastPollSec:Float = 0.0;
	var lastHeavyPollSec:Float = 0.0;
	var lastSlowPollSec:Float = 0.0;

	var prevCursorFree:Bool = true;

	var lastAssetPollSec:Float = -1;
	var brandingRequested:Bool = false;

	/** UI assets also load at the title screen, before GameApp exists. */
	public function observeAssets():Void {
		var now = nowSec();
		if (now - lastAssetPollSec < 0.100)
			return;
		lastAssetPollSec = now;
		if (!brandingRequested) {
			brandingRequested = true;
			GameIcons.get(GameIcons.CHROME_SUN);
			GameIcons.get(GameIcons.RIFT_SUN);
			GameIcons.get(GameIcons.HUB_LOGO);
		}
		if (GameIcons.hasPending())
			GameIcons.tickPreload();
		if (AttackComboArt.hasPending())
			AttackComboArt.tickPreload();
	}

	/** Layer 1: cursor + caches. Reactionary polling driven by state change & visibility. */
	public function observe(app:GameApp):Void {
		if (app == null)
			return;

		try
			HealthCache.releaseStaleLocalHero(app)
		catch (_:Dynamic) {}

		CursorCaptureFix.apply(app);
		// Look-lock closes hub/builders only when no interactive editor is open.
		// Cursor lock must not tear down an active Aura/profile editor (keyboard
		// ownership is independent of cursorFree — leaked inventory hotkeys used
		// to flip cursor and cascade into suspendForCamera).
		if (prevCursorFree && !CursorCaptureFix.cursorFree) {
			var keepEditors = false;
			try
				keepEditors = config.anyInteractiveOpen()
			catch (_:Dynamic) {}
			if (!keepEditors) {
				try
					config.suspendForCamera()
				catch (_:Dynamic) {}
			}
		}
		prevCursorFree = CursorCaptureFix.cursorFree;

		try
			solarflare.ui.UiActionQueue.drain()
		catch (_:Dynamic) {}

		var now = nowSec();
		ObserveDemand.publish(config);

		// Hotkey codes come off the live engine module, so they are resolved here in
		// observe rather than from the settings draw. First call does the work.
		try
			solarflare.ui.HideAllBind.ensureCodes()
		catch (_:Dynamic) {}

		// Fast cadence (~30 Hz): HP/resources; overlay reconcile is demand+dirty gated inside.
		if (now - lastFastPollSec >= 0.033) {
			lastFastPollSec = now;
			// Identity must be acquired even when all resource bars are hidden.
			// A rejected Player.update trampoline must not suppress every runtime HUD.
			try
				HealthHooks.observeLocalPlayer(app)
			catch (_:Dynamic) {}
			try {
				if (ObserveDemand.resourceBars || ObserveDemand.auras || ObserveDemand.auraBuilderOpen || ObserveDemand.prayers
					|| ObserveDemand.comboPoints || ObserveDemand.chaincast || ObserveDemand.conduit)
					HealthHooks.observeLocal();
			} catch (_:Dynamic) {}
		try
			HealthHooks.reconcileOverlays()
		catch (_:Dynamic) {}
		try {
			if (ObserveDemand.dueAttackCombo(now, AttackComboCache.withinCombo || AttackComboCache.flashFinal))
				AttackComboCache.observe();
		} catch (_:Dynamic) {}
		}



		// Heavy cadence (~25 Hz outer) — feature visibility + inner adaptive rates:
		if (now - lastHeavyPollSec >= 0.040) {
			lastHeavyPollSec = now;

			try {
				// Warm liveById when script-ready Auras or Aura builder need Geaux.
				if (ObserveDemand.geaux || ObserveDemand.geauxBuilder || ObserveDemand.auras || ObserveDemand.aurasNeedInstant
					|| ObserveDemand.aurasNeedSpecial || ObserveDemand.auraBuilderOpen) {
					config.geaux.ensureSlots();
					GeauxCache.sample(HealthCache.localHero, config.geaux.visibleCount(), config.geaux.slotIds);
				}
			} catch (_:Dynamic) {}

			try {
				if (ObserveDemand.targetHud || ObserveDemand.combatLog || ObserveDemand.aurasNeedTarget
					|| ObserveDemand.auraBuilderOpen)
					CombatLogCache.tick(HealthCache.localHero);
			} catch (_:Dynamic) {}

			try {
				if (ObserveDemand.auras || ObserveDemand.auraBuilderOpen)
					solarflare.aura.AuraEngine.tick(config.auras);
			} catch (_:Dynamic) {}

			try {
				if (config.lightsaber != null && !config.lightsaber.hidden.get()) {
					LightsaberCache.enabled = true;
					LightsaberCache.ingestForConfig(config.lightsaber);
					LightsaberCache.tick(now);
					if (config.lightsaber.showLog.get())
						SaberJsonlArchive.tick();
				}
			} catch (_:Dynamic) {}

		}

		// Background cadence (10 Hz outer) — GetRifty further gated inside ObserveDemand:
		if (now - lastSlowPollSec >= 0.100) {
			lastSlowPollSec = now;

			try
				restoreNativeChat()
			catch (_:Dynamic) {}
			try {
				if (ObserveDemand.combatLog)
					solarflare.combatlog.CombatLogRecorder.tick();
			} catch (_:Dynamic) {}
			try {
				if (ObserveDemand.riftFlag) {
					var inRift = false;
					try
						inRift = GetRiftyCache.inInstance
					catch (_:Dynamic) {}
					if (ObserveDemand.dueGetRifty(now, inRift)) {
						GetRiftyCache.observeApp(app);
						if (ObserveDemand.getRifty)
							GetRiftyCache.tick();
					}
				}
			} catch (_:Dynamic) {}
			try
				solarflare.ui.SettingsStore.tick(config)
			catch (_:Dynamic) {}
			try {
				if (PayloadProbe.armed()) {
					PayloadProbe.sampleApp(app);
					PayloadProbe.tick();
				}
			} catch (_:Dynamic) {}
			try {
				if (ResolutionLedger.armed())
					ResolutionLedger.tick();
			} catch (_:Dynamic) {}
			try {
				if (solarflare.debug.FieldWalkLog.armed())
					solarflare.debug.FieldWalkLog.tick();
			} catch (_:Dynamic) {}
		}
	}

	/** Layer 2: ImGui presentation from caches only. */
	public function draw():Void {
		var interactive = config.anyInteractiveOpen();
		CursorCaptureFix.beginFrameCapture(interactive);
		solarflare.ui.ThemePalette.init();
		try
			solarflare.ui.ThemePalette.wrap(drawOverlays)
		catch (_:Dynamic) {}
		config.pollToggle();
		CursorCaptureFix.finishFrame(config.anyInteractiveOpen());
	}

	function drawOverlays():Void {
		try {
			solarflare.ui.DockingHelper.setupMainDockSpace();
		} catch (_:Dynamic) {}

		try
			config.draw()
		catch (_:Dynamic) {}

		// Only draw in-game HUD elements when the hero/world is active:
		if (!HealthCache.valid && HealthCache.localHero == null) {
			try {
				solarflare.ui.SettingsStore.tick(config);
			} catch (_:Dynamic) {}
			return;
		}

		// Hide All skips draws only; per-widget hidden refs stay untouched so the
		// HUD comes back exactly as configured once it is unhidden.
		var suppressed = false;
		try
			suppressed = solarflare.ui.HudSuppress.active()
		catch (_:Dynamic) {}
		try {
			if (!suppressed && config.anyBarVisible())
				vitalsTheme.wrap(drawVitals);
		} catch (_:Dynamic) {}
		// Each overlay isolated — a Geaux throw must not skip Lightsaber / Auras.
		try {
			if (!suppressed)
				geauxBar.draw(config.geaux);
		} catch (_:Dynamic) {}
		try {
			if (!suppressed)
				comboOverlay.draw(config.combo);
		} catch (_:Dynamic) {}
		try {
			if (!suppressed)
				chaincastOverlay.draw(config.chaincast);
		} catch (_:Dynamic) {}
		try {
			if (!suppressed)
				conduitOverlay.draw(config.conduit);
		} catch (_:Dynamic) {}
		try {
			if (!suppressed)
				attackComboOverlay.draw(config.attackCombo);
		} catch (_:Dynamic) {}
		try {
			if (!suppressed)
				combatLogOverlay.draw(config.combatLog);
		} catch (_:Dynamic) {}
		try {
			if (!suppressed)
				targetOverlay.draw(config.target);
		} catch (_:Dynamic) {}
		try {
			if (launchers != null && !suppressed)
				launchers.draw(config.open);
		} catch (_:Dynamic) {}
		try {
			if (auraOverlay != null && !suppressed)
				auraOverlay.draw();
		} catch (_:Dynamic) {}
		try {
			if (!suppressed)
				lightsaber.draw(config.lightsaber);
		} catch (_:Dynamic) {}
		try {
			if (getRiftyOverlay != null && !suppressed)
				getRiftyOverlay.draw(config.getRifty);
		} catch (_:Dynamic) {}
		try {
			if (payloadProbe != null)
				payloadProbe.draw(CursorCaptureFix.cursorFree);
		} catch (_:Dynamic) {}
		try {
			if (resolutionLedger != null)
				resolutionLedger.draw(CursorCaptureFix.cursorFree);
		} catch (_:Dynamic) {}
		try {
			solarflare.ui.PerformanceMonitor.draw();
		} catch (_:Dynamic) {}
		try {
			var dt:Float = 0.016;
			solarflare.ui.effects.VectorEffectSystem.update(dt);
			var fgDrawList = ImGui.getForegroundDrawList();
			if (fgDrawList != null) {
				solarflare.ui.effects.VectorEffectSystem.draw(fgDrawList);
			}
		} catch (_:Dynamic) {}
		try {
			solarflare.debug.DebugSystem.draw();
		} catch (_:Dynamic) {}
		try {
			solarflare.ui.ToastManager.draw();
		} catch (_:Dynamic) {}
		try {
			solarflare.ui.SettingsStore.tick(config);
		} catch (_:Dynamic) {}
	}

	/** Flush pending layout/toggles when GameApp is gone (logout / shutdown). */
	public function flushPendingSettings():Void {
		if (solarflare.ui.SettingsStore.isDirty())
			solarflare.ui.SettingsStore.save(config);
	}

	static function nowSec():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}

	/** Typed GameLib `ui.Hud.chat` — not FieldWalk. FieldWalk stays on the probe/ledger path. */
	function restoreNativeChat():Void {
		if (nativeChatRestored)
			return;
		var hud = ui.GameUI.getHud();
		if (hud == null)
			return;
		var box = hud.chat;
		if (box == null)
			return;
		box.set_visible(true);
		nativeChatRestored = true;
	}

	function drawVitals():Void {
		var v = config.vitals;
		if (v == null)
			return;
		// HP position is set once at startup (fresh-install default via ConfigPanel.new)
		// or restored from save. Never re-anchor per-frame — that would overwrite user drags.
		if (!v.hpHidden.get())
			drawResourceWindow(v, 0, "HP", v.hpHidden, v.chrome, v.hpWidth, v.hpHeight);
		if (!v.rageHidden.get())
			drawResourceWindow(v, 1, "Rage", v.rageHidden, v.rageChrome, v.rageWidth, v.rageHeight);
		if (!v.manaHidden.get() && HealthCache.resourceValid())
			drawResourceWindow(v, 2, HealthCache.sparkValid ? "Spark" : "Mana", v.manaHidden, v.manaChrome, v.manaWidth, v.manaHeight);
		if (!v.prayersHidden.get() && PrayerCache.active)
			drawResourceWindow(v, 3, "Prayers", v.prayersHidden, v.prayersChrome, v.prayersWidth, v.prayersHeight);
	}

	function drawResourceWindow(v:VitalsConfig, kind:Int, caption:String, hidden:imgui.ref.BoolRef,
			chrome:solarflare.ui.HudChrome, width:imgui.ref.FloatRef, height:imgui.ref.FloatRef):Void {
		var style = switch (kind) { case 0: v.hpStyle.get(); case 1: v.rageStyle.get(); case 2: v.manaStyle.get(); default: 0; };
		var vertical = switch (kind) { case 0: v.hpVertical.get(); case 1: v.rageVertical.get(); case 2: v.manaVertical.get(); default: false; };
		var compact = VitalsConfig.compactRow(style, vertical);
		var h:Single = Math.max(compact ? 38 : 28, height.get());
		var w:Single = Math.max(80, width.get());
		solarflare.ui.HUDWidgetWindow.draw("SolarFlare " + caption, caption, chrome, w, h, function(size) {
			var p = ImGui.getCursorScreenPos();
			ImGui.dummy(ImGui.vec2(size.x, size.y));
			ImGui.setCursorScreenPos(ImGui.vec2(p.x + 4, p.y + 4));
			var rowW:Single = size.x - 8;
			var rowH:Single = size.y - 8;
			switch (kind) {
				case 0: drawVital(true, false, false, VitalsConfig.normalizeStyle(style, true, true), rowW, rowH, vertical);
				case 1: drawVital(false, true, false, VitalsConfig.normalizeStyle(style, true, false), rowW, rowH, vertical);
				case 2: drawVital(false, false, true, VitalsConfig.normalizeStyle(style, true, !HealthCache.sparkValid), rowW, rowH, vertical);
				default: drawPrayerIcons(rowW, false);
			}
		}, function() { config.resourceTracker.open.set(true); }, function() { hidden.set(true); solarflare.ui.SettingsStore.markDirty(); }, false, null,
			function(newW:Single, newH:Single) {
				width.set(Math.max(80, newW));
				height.set(Math.max(compact ? 38 : 28, newH));
				solarflare.ui.SettingsStore.markDirty();
			});
	}

	static function isColumnStyle(style:Int):Bool {
		return style == VitalsConfig.STYLE_VERTICAL || style == VitalsConfig.STYLE_CRESCENT
			|| style == VitalsConfig.STYLE_HALF_DOME || style == VitalsConfig.STYLE_RING
			|| style == VitalsConfig.STYLE_THESD
			|| VitalsConfig.isPipStyle(style);
	}

	function drawVitalsStacked(v:VitalsConfig, showHp:Bool, showRage:Bool, showMana:Bool, showPrayers:Bool,
			availW:Single, availH:Single):Void {
		var rows:Single = (showHp ? 1 : 0) + (showRage ? 1 : 0) + (showMana ? 1 : 0);
		var prayerH:Single = showPrayers ? PRAYER_ICON + BAR_GAP : 0;
		var gaps:Single = Math.max(0, rows - 1) * BAR_GAP;
		var barW:Single = availW > 1 ? availW : 1;
		var barH:Single = rows > 0 ? (availH - gaps - prayerH) / rows : 8;
		if (barH < 8)
			barH = 8;
		if (showHp)
			drawVital(true, false, false, VitalsConfig.normalizeStyle(v.hpStyle.get(), true, true), barW, barH, v.hpVertical.get(), false);
		if (showRage)
			drawVital(false, true, false, VitalsConfig.normalizeStyle(v.rageStyle.get(), true, false), barW, barH, v.rageVertical.get(), false);
		if (showMana)
			drawVital(false, false, true, VitalsConfig.normalizeStyle(v.manaStyle.get(), true, !HealthCache.sparkValid), barW, barH, v.manaVertical.get(), false);
		if (showPrayers)
			drawPrayerIcons(barW, false);
	}

	function drawVitalsColumns(v:VitalsConfig, showHp:Bool, showRage:Bool, showMana:Bool, showPrayers:Bool,
			availW:Single, availH:Single):Void {
		var hpStyle = VitalsConfig.normalizeStyle(v.hpStyle.get(), true, true);
		var hpAsColumn = showHp && isColumnStyle(hpStyle);
		var prayerW:Single = showPrayers ? PRAYER_ICON + BAR_GAP : 0;
		if (showHp && !hpAsColumn) {
			var topH:Single = Math.min(36, availH * 0.22);
			if (topH < 22)
				topH = 22;
			drawVital(true, false, false, hpStyle, availW, topH, v.hpVertical.get(), false);
			availH -= topH + BAR_GAP;
		}
		var cols:Int = (hpAsColumn ? 1 : 0) + (showRage ? 1 : 0) + (showMana ? 1 : 0);
		var gaps:Single = Math.max(0, cols - 1) * BAR_GAP;
		var colW:Single = cols > 0 ? (availW - gaps - prayerW) / cols : availW;
		if (colW < 24)
			colW = 24;
		var colH:Single = availH > 1 ? availH : 80;
		var idx = 0;
		if (hpAsColumn) {
			drawVital(true, false, false, hpStyle, colW, colH, v.hpVertical.get(), idx == cols - 1 && cols > 1);
			idx++;
			if (showRage || showMana || showPrayers)
				ImGui.sameLine(0, BAR_GAP);
		}
		if (showRage) {
			drawVital(false, true, false, VitalsConfig.normalizeStyle(v.rageStyle.get(), true, false), colW, colH, v.rageVertical.get(),
				idx == cols - 1 && cols > 1);
			idx++;
			if (showMana || showPrayers)
				ImGui.sameLine(0, BAR_GAP);
		}
		if (showMana) {
			drawVital(false, false, true, VitalsConfig.normalizeStyle(v.manaStyle.get(), true, !HealthCache.sparkValid), colW, colH, v.manaVertical.get(),
				idx == cols - 1 && cols > 1);
			if (showPrayers)
				ImGui.sameLine(0, BAR_GAP);
		}
		if (showPrayers)
			drawPrayerIcons(PRAYER_ICON, true);
	}

	function drawVital(isHp:Bool, isRage:Bool, isMana:Bool, style:Int, w:Single, h:Single, vertical:Bool,
			thesdRight:Bool = false):Void {
		var origin = ImGui.getCursorScreenPos();
		VitalsRenderer.draw(cacheSnap(isHp, isRage), style, w, h, vertical, thesdRight);
		if (isRage && HealthCache.rageAlertActive())
			solarflare.ui.ResourceMaxAlert.drawOver(origin.x, origin.y, w, h);
	}

	/** Thin cache-reading shim: freezes HealthCache into a persistent renderer snapshot. */
	function cacheSnap(isHp:Bool, isRage:Bool):VitalSnap {
		var s:VitalSnap;
		if (isHp) s = snapHp;
		else if (isRage) s = snapRage;
		else s = snapMana;

		if (isHp) {
			s.kind = VitalSnap.HP;
			s.deadKnown = HealthCache.deadKnown;
			s.dead = HealthCache.dead;
			s.valid = HealthCache.valid;
			s.current = HealthCache.current;
			s.max = HealthCache.max;
			s.ratio = HealthCache.valid ? HealthCache.ratio() : 0;
			s.shield = HealthCache.shield;
			s.sparkValid = false;
		} else if (isRage) {
			s.kind = VitalSnap.RAGE;
			s.valid = HealthCache.rageValid;
			s.current = HealthCache.rage;
			s.max = HealthCache.rageMax;
			s.ratio = HealthCache.rageValid ? HealthCache.rageRatio() : 0;
			s.shield = 0;
			s.sparkValid = false;
		} else {
			s.kind = VitalSnap.MANA;
			s.valid = HealthCache.resourceValid();
			s.current = HealthCache.resourceCurrent();
			s.max = HealthCache.resourceMax();
			s.ratio = HealthCache.resourceValid() ? HealthCache.resourceRatio() : 0;
			s.shield = 0;
			s.sparkValid = HealthCache.sparkValid;
		}
		return s;
	}

	static function drawPrayerIcons(rowSpan:Single, vertical:Bool):Void {
		var size:Single = PRAYER_ICON;
		var gap:Single = 3;
		var origin = ImGui.getCursorScreenPos();
		if (vertical) {
			drawPrayerIcon(origin.x, origin.y, size, "smite", PrayerCache.smiteReady);
			drawPrayerIcon(origin.x, origin.y + size + gap, size, "life", PrayerCache.lifeReady);
			drawPrayerIcon(origin.x, origin.y + (size + gap) * 2, size, "shield", PrayerCache.shieldReady);
			ImGui.dummy(ImGui.vec2(size, size * 3 + gap * 2));
		} else {
			var total:Single = size * 3 + gap * 2;
			var startX:Single = origin.x;
			if (rowSpan > total)
				startX = origin.x + (rowSpan - total) * 0.5;
			drawPrayerIcon(startX, origin.y, size, "smite", PrayerCache.smiteReady);
			drawPrayerIcon(startX + size + gap, origin.y, size, "life", PrayerCache.lifeReady);
			drawPrayerIcon(startX + (size + gap) * 2, origin.y, size, "shield", PrayerCache.shieldReady);
			ImGui.dummy(ImGui.vec2(rowSpan > 1 ? rowSpan : total, size));
		}
	}

	static function prayerGlow(kind:String):Dynamic {
		if (kind == "smite")
			return ImGui.vec4(0.95, 0.22, 0.18, 0.95); // red
		if (kind == "life")
			return ImGui.vec4(0.95, 0.78, 0.22, 0.95); // yellow/gold
		return ImGui.vec4(0.28, 0.55, 0.98, 0.95); // shield blue
	}

	static function drawPrayerIcon(x:Single, y:Single, size:Single, kind:String, ready:Bool):Void {
		var dl = ImGui.getWindowDrawList();
		var tex = GameIcons.get(GameIcons.prayerId(kind));
		// Dim until prayer is ready; full tint when active. No colored border chrome.
		if (!GameIcons.draw(dl, tex, x, y, size, GameIcons.tintReady(ready))) {
			var glow = prayerGlow(kind);
			var fill = ready
				? ImGui.vec4(glow.x * 0.55, glow.y * 0.55, glow.z * 0.55, 1)
				: ImGui.vec4(0.16, 0.17, 0.19, 0.85);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + size, y + size),
				ImGui.colorConvertFloat4ToU32(fill), 6);
		}
	}
}
