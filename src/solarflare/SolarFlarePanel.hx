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
	static inline var PRAYER_ICON:Single = 36;

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
		if (prevCursorFree && !CursorCaptureFix.cursorFree) {
			try
				config.suspendForCamera()
			catch (_:Dynamic) {}
		}
		prevCursorFree = CursorCaptureFix.cursorFree;

		try
			solarflare.ui.UiActionQueue.drain()
		catch (_:Dynamic) {}

		var now = nowSec();
		ObserveDemand.publish(config);

		// Fast cadence (~30 Hz): HP/resources; overlay reconcile is demand+dirty gated inside.
		if (now - lastFastPollSec >= 0.033) {
			lastFastPollSec = now;
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

		try {
			if (config.anyBarVisible())
				vitalsTheme.wrap(drawVitals);
		} catch (_:Dynamic) {}
		// Each overlay isolated — a Geaux throw must not skip Lightsaber / Auras.
		try
			geauxBar.draw(config.geaux)
		catch (_:Dynamic) {}
		try
			comboOverlay.draw(config.combo)
		catch (_:Dynamic) {}
		try
			chaincastOverlay.draw(config.chaincast)
		catch (_:Dynamic) {}
		try
			conduitOverlay.draw(config.conduit)
		catch (_:Dynamic) {}
		try
			attackComboOverlay.draw(config.attackCombo)
		catch (_:Dynamic) {}
		try
			combatLogOverlay.draw(config.combatLog)
		catch (_:Dynamic) {}
		try
			targetOverlay.draw(config.target)
		catch (_:Dynamic) {}
		try {
			if (launchers != null)
				launchers.draw(config.open);
		} catch (_:Dynamic) {}
		try {
			if (auraOverlay != null)
				auraOverlay.draw();
		} catch (_:Dynamic) {}
		try
			lightsaber.draw(config.lightsaber)
		catch (_:Dynamic) {}
		try {
			if (getRiftyOverlay != null)
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
		var dirty = switch (kind) {
			case 0: v.hpSizeDirty;
			case 1: v.rageSizeDirty;
			case 2: v.manaSizeDirty;
			default: v.prayersSizeDirty;
		};
		if (chrome != null && chrome.takeExpandDirty())
			dirty = true;
		ImGui.setNextWindowBgAlpha(chrome != null && chrome.isTransparent() ? 0 : 0.82);
		ImGui.setNextWindowSizeConstraints(ImGui.vec2(VitalsConfig.HP_MIN_W, 28),
			ImGui.vec2(VitalsConfig.HP_MAX_W, VitalsConfig.HP_MAX_H));
		ImGui.setNextWindowSize(ImGui.vec2(width.get(), height.get()), dirty ? ImGuiCond.Always : ImGuiCond.FirstUseEver);
		switch (kind) {
			case 0: v.hpSizeDirty = false;
			case 1: v.rageSizeDirty = false;
			case 2: v.manaSizeDirty = false;
			default: v.prayersSizeDirty = false;
		}
		if (chrome != null) {
			chrome.clampToViewport();
			chrome.applyPos();
			if (!chrome.collapsed.get())
				ImGui.setNextWindowPos(ImGui.vec2(chrome.x.get(), chrome.y.get()), ImGuiCond.FirstUseEver);
		}
		var flags = chrome != null ? chrome.windowFlags(VITALS_FLAGS) : VITALS_FLAGS;
		var began = ImGui.begin("SolarFlare " + caption, null, flags);
		if (began) {
			if (chrome == null || !chrome.isLocked()) {
				var win = ImGui.getWindowSize();
				if (Math.abs(win.x - width.get()) > 1 || Math.abs(win.y - height.get()) > 1)
					solarflare.ui.SettingsStore.markDirty();
				if (chrome != null)
					chrome.capturePos();
				width.set(win.x);
				height.set(win.y);
			}
			var showBody = chrome == null || chrome.beginBody(function() {
				hidden.set(true);
				solarflare.ui.SettingsStore.markDirty();
			}, null, caption);
			if (showBody) {
				var avail = ImGui.getContentRegionAvail();
				var rowW:Single = avail.x > 1 ? avail.x : 1;
				var rowH:Single = avail.y > 1 ? avail.y : 24;
				switch (kind) {
					case 0: drawVital(true, false, false, VitalsConfig.normalizeStyle(v.hpStyle.get(), true, true), rowW, rowH, v.hpVertical.get());
					case 1: drawVital(false, true, false, VitalsConfig.normalizeStyle(v.rageStyle.get(), true, false), rowW, rowH, v.rageVertical.get());
					case 2: drawVital(false, false, true, VitalsConfig.normalizeStyle(v.manaStyle.get(), true, !HealthCache.sparkValid), rowW, rowH, v.manaVertical.get());
					default: drawPrayerIcons(rowW, false);
				}
			}
		}
		solarflare.ui.HudChrome.endOverlayWindow(began, chrome);
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
		var gap:Single = 8;
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
