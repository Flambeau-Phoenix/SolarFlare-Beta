package solarflare;

import solarflare.chaincast.Chaincast;
import solarflare.attackcombo.AttackComboCache;
import solarflare.attackcombo.AttackComboArt;
import solarflare.attackcombo.AttackComboOverlay;
import solarflare.combo.Combo;
import solarflare.conduit.Conduit;
import solarflare.combatlog.CombatLogCache;
import solarflare.combatlog.CombatLogOverlay;
import solarflare.castbar.PlayerCastOverlay;
import solarflare.geaux.GeauxBar;
import solarflare.geaux.GeauxCache;
import solarflare.getrifty.GetRifty;
import solarflare.lightsaber.Lightsaber;
import solarflare.preview.VitalsRenderer;
import solarflare.target.TargetOverlay;
import solarflare.ui.ConfigPanel;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.GameIcons;
import solarflare.ui.HudChrome;
import solarflare.ui.VitalsConfig;
import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Theme;

#if solarflare_telemetry
import solarflare.debug.PayloadProbe;
import solarflare.debug.PayloadProbeOverlay;
import solarflare.debug.ResolutionLedger;
import solarflare.debug.ResolutionLedgerOverlay;
#end
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
	var hemorrhageOverlay:solarflare.hemorrhage.HemorrhageOverlay;
	var attackComboOverlay:AttackComboOverlay;
	var combatLogOverlay:CombatLogOverlay;
	var targetOverlay:TargetOverlay;
	var playerCastOverlay:PlayerCastOverlay;
	var launchers:solarflare.ui.HudLaunchers;
	var auraOverlay:solarflare.aura.AuraOverlay;
	var lightsaber:LightsaberOverlay;
	var getRiftyOverlay:GetRiftyOverlay;
	#if solarflare_telemetry
	var payloadProbe:PayloadProbeOverlay;
	var resolutionLedger:ResolutionLedgerOverlay;
	#end
	var vitalsTheme:Theme;
	/** Persistent VitalSnap pool — reused every frame (DRAW-002). */
	var snapHp:VitalSnap;
	var snapRage:VitalSnap;
	var snapMana:VitalSnap;
	var nativeChatRestored = false;
	/** Per-kind vitals callbacks and bound draw methods, created once (zero per-frame closures). */
	var resourceBodyFns:Array<imgui.Structs.ImVec2->Void> = [];
	var resourceHideFns:Array<Void->Void> = [];
	var resourceResizeFns:Array<Single->Single->Void> = [];
	var openResourceTrackerFn:Void->Void;
	var drawVitalsFn:Void->Void;
	var drawOverlaysFn:Void->Void;

	public function new() {
		snapHp = new VitalSnap();
		snapRage = new VitalSnap();
		snapMana = new VitalSnap();
		for (kind in 0...4) {
			var k = kind;
			resourceBodyFns.push(function(size) drawResourceBody(k, size));
			resourceHideFns.push(function() hideResource(k));
			resourceResizeFns.push(function(newW:Single, newH:Single) resizeResource(k, newW, newH));
		}
		openResourceTrackerFn = function() { config.resourceTracker.open.set(true); };
		drawVitalsFn = drawVitals;
		drawOverlaysFn = drawOverlays;
		config = new ConfigPanel();
		solarflare.ui.UiActionQueue.bind(config);
		geauxBar = new GeauxBar();
		comboOverlay = new ComboOverlay();
		chaincastOverlay = new ChaincastOverlay();
		conduitOverlay = new ConduitOverlay();
		hemorrhageOverlay = new solarflare.hemorrhage.HemorrhageOverlay();
		attackComboOverlay = new AttackComboOverlay();
		combatLogOverlay = new CombatLogOverlay();
		targetOverlay = new TargetOverlay();
		playerCastOverlay = new PlayerCastOverlay();
		launchers = config.launchers;
		auraOverlay = new solarflare.aura.AuraOverlay(config.auras);
		auraOverlay.openBuilder = function() { config.auraBuilder.open.set(true); };
		geauxBar.openBuilder = function() { config.geauxBuilder.open.set(true); };
		comboOverlay.openBuilder = function() { config.resourceTracker.open.set(true); };
		conduitOverlay.openBuilder = function() { config.resourceTracker.open.set(true); };
		chaincastOverlay.openBuilder = function() { config.resourceTracker.open.set(true); };
		attackComboOverlay.openBuilder = function() { config.resourceTracker.open.set(true); };
		if (config.statusBoard != null) config.statusBoard.openSettings = function() { config.showHubTab("status"); };

		targetOverlay.openBuilder = function() { config.target.open.set(true); };
		playerCastOverlay.openBuilder = function() { config.castBar.open.set(true); };
		lightsaber = new LightsaberOverlay();
		getRiftyOverlay = new GetRiftyOverlay();
		#if solarflare_telemetry
		payloadProbe = new PayloadProbeOverlay();
		resolutionLedger = new ResolutionLedgerOverlay();
		#end
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

	var prevCursorFree:Bool = true;
	var castTimesShutdownFlushed:Bool = false;

	/** UI assets also load at the title screen, before GameApp exists. */
	public function resetExtraBarsSession():Void {
		solarflare.hemorrhage.HemorrhageService.interrupt("World unloaded");
		if (config.extraBarsPrototype != null) config.extraBarsPrototype.clearSession();
		if (config.stacks != null) config.stacks.reset();
	}

	public function observeAssets():Void {
		solarflare.runtime.TelemetryKernel.observeAssets();
	}

	/** Layer 1: cursor + caches. Reactionary polling driven by state change & visibility. */
	public function observe(app:GameApp):Void {
		if (app == null)
			return;
		castTimesShutdownFlushed = false;

		try
			HealthCache.releaseStaleLocalHero(app)
		catch (_:Dynamic) {}

		CursorCaptureFix.apply(app);
		solarflare.ui.FullscreenShortcutGuard.observe(config);
		// Every independently retained editor closes on entry to camera mode.
		// An open editor cannot exempt itself: NoMouse alone leaves its lifetime
		// and drag/text state alive behind the hidden cursor.
		var enteringCamera = prevCursorFree && !CursorCaptureFix.cursorFree;
		if (enteringCamera) {
			try config.closeInteractiveWindows() catch (_:Dynamic) {}
		}
		prevCursorFree = CursorCaptureFix.cursorFree;

		try
			solarflare.ui.UiActionQueue.drain()
		catch (_:Dynamic) {}
		solarflare.ui.ImageDrop.observe();
		solarflare.ui.JpegBridge.install();

		solarflare.runtime.TelemetryKernel.observe(app, config, restoreNativeChat);
		// Character-owned widgets must exist before applying a profile/layout.
		if (config.extraBarsPrototype != null) {
			try config.extraBarsPrototype.observeLayoutCharacter() catch (_:Dynamic) {}
			try config.uiLayouts.reconcile(config) catch (_:Dynamic) {}
		}
		// Profile switching consumes the frozen identity only after telemetry has
		// refreshed it; no live game objects are touched from the profile system.
		try
			solarflare.ui.FeatureProfiles.observeCharacter(config)
		catch (_:Dynamic) {}
		// A character/profile restore in this observation can restore open refs.
		if (enteringCamera && config.anyInteractiveOpen()) {
			try config.closeInteractiveWindows() catch (_:Dynamic) {}
		}

		if (config.extraBarsPrototype != null) {
			try config.extraBarsPrototype.observe(app) catch (_:Dynamic) {}
		}
		if (config.barter != null) {
			try config.barter.observe() catch (_:Dynamic) {}
		}
		if (config.statusBoard != null) {
			try config.statusBoard.observe() catch (_:Dynamic) {}
		}
		if (config.stacks != null) {
			try config.stacks.observe() catch (_:Dynamic) {}
		}
		if (config.lootBrowser != null) {
			try config.lootBrowser.observe() catch (_:Dynamic) {}
		}
		try config.uiLayouts.reconcile(config) catch (_:Dynamic) {}
		solarflare.ui.NativeHideCache.apply(app, config.nativeHide);
		try
			solarflare.ui.HideMoveCache.apply(config.hideMove)
		catch (_:Dynamic) {}

	}

	/** Layer 2: ImGui presentation from caches only. */
	public function draw():Void {
		// Sample every present, including title/logout frames where HUD drawing skips.
		solarflare.ui.PerformanceMonitor.update();
		var interactive = config.anyInteractiveOpen();
		CursorCaptureFix.beginFrameCapture(interactive);
		solarflare.ui.ThemePalette.init();
		try
			solarflare.ui.ThemePalette.wrap(drawOverlaysFn)
		catch (_:Dynamic) {}
		// Safety net: no panel may stay open into the next frame. Empty on healthy frames.
		HudChrome.unwindPanels(0);
		config.pollToggle();
		CursorCaptureFix.finishFrame(config.anyInteractiveOpen());
	}

	function drawOverlays():Void {
		// Overlays are siblings: each must leave the panel stack where it found it.
		var panelBase = HudChrome.panelDepth();
		try {
			solarflare.ui.DockingHelper.setupMainDockSpace();
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);

		// Background layer under every overlay; ignores Hide All because it is a layout aid, not HUD.
		try
			solarflare.ui.AlignmentGrid.draw()
		catch (_:Dynamic) {}

		try
			config.draw()
		catch (_:Dynamic) {}
		try {
			config.hemorrhage.tool.draw(config.hemorrhage.autoScroll);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);

		// Editors remain reachable while automatic/manual HUD suppression is active.
		try {
			if (config.barter != null) config.barter.drawBuilder();
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);

		// Only draw in-game HUD elements when the hero/world is active:
		if (!HealthCache.valid && HealthCache.localHero == null) {
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
				vitalsTheme.wrap(drawVitalsFn);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (!suppressed && config.extraBarsPrototype != null) config.extraBarsPrototype.drawBar();
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (!suppressed && config.barter != null) {
				config.barter.draw();
			}
			if (!suppressed && config.statusBoard != null) {
				config.statusBoard.draw();
			}
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (!suppressed && config.stacks != null) config.stacks.draw();
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		// Each overlay isolated — a Geaux throw must not skip Lightsaber / Auras.
		try {
			if (!suppressed) hemorrhageOverlay.draw(config.hemorrhage);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (!suppressed)
				geauxBar.draw(config.geaux);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (!suppressed)
				comboOverlay.draw(config.combo);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (!suppressed)
				chaincastOverlay.draw(config.chaincast);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (!suppressed)
				conduitOverlay.draw(config.conduit);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (!suppressed)
				attackComboOverlay.draw(config.attackCombo);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (!suppressed)
				combatLogOverlay.draw(config.combatLog);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (!suppressed)
				targetOverlay.draw(config.target);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (!suppressed)
				playerCastOverlay.draw(config.castBar);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (launchers != null && !suppressed)
				launchers.draw(config.open);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (auraOverlay != null && !suppressed)
				auraOverlay.draw();
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (!suppressed)
				lightsaber.draw(config.lightsaber);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (getRiftyOverlay != null && !suppressed)
				getRiftyOverlay.draw(config.getRifty);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		#if solarflare_telemetry
		try {
			if (payloadProbe != null)
				payloadProbe.draw(CursorCaptureFix.cursorFree);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			if (resolutionLedger != null)
				resolutionLedger.draw(CursorCaptureFix.cursorFree);
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		#end
		try {
			solarflare.ui.PerformanceMonitor.draw();
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			solarflare.debug.DebugSystem.draw();
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
		try {
			solarflare.ui.ToastManager.draw();
		} catch (_:Dynamic) HudChrome.unwindPanels(panelBase);
	}

	/** Flush pending layout/toggles when GameApp is gone (logout / shutdown). */
	public function flushPendingSettings():Void {
		solarflare.ui.WindowAutoHide.reset();
		solarflare.ui.NativeHideCache.clearSession();
		solarflare.aura.TargetStatusCache.reset();
		try
			solarflare.ui.HideMoveCache.clearSession()
		catch (_:Dynamic) {}
		config.nativeHide.bottomBarAccepted.set(false);
		config.nativeHide.status = "Waiting for native HUD";
		nativeChatRestored = false;
		if (!castTimesShutdownFlushed) {
			castTimesShutdownFlushed = true;
			solarflare.castbar.CastCache.observe(null, null);
			solarflare.castbar.LearnedCastTimes.tick(haxe.Timer.stamp(), true);
		}
		solarflare.ui.SettingsStore.saveIfDue(config);
	}

	/** Typed GameLib `ui.Hud.chat` — not FieldWalk. FieldWalk stays on the probe/ledger path. */
	function restoreNativeChat():Void {
		if (nativeChatRestored)
			return;
		// Enhanced Chat owns its native ChatBox visibility after initialization/update.
		if (hlx.runtime.Registry.get("mods", "enhanced-chat") != null)
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
			drawResourceWindow(v, 0, "SolarFlare HP", "HP", v.chrome, v.hpWidth, v.hpHeight);
		if (!v.rageHidden.get())
			drawResourceWindow(v, 1, "SolarFlare Rage", "Rage", v.rageChrome, v.rageWidth, v.rageHeight);
		if (!v.manaHidden.get() && HealthCache.resourceValid()) {
			if (HealthCache.sparkValid)
				drawResourceWindow(v, 2, "SolarFlare Spark", "Spark", v.manaChrome, v.manaWidth, v.manaHeight);
			else
				drawResourceWindow(v, 2, "SolarFlare Mana", "Mana", v.manaChrome, v.manaWidth, v.manaHeight);
		}
		if (!v.prayersHidden.get() && PrayerCache.active)
			drawResourceWindow(v, 3, "SolarFlare Prayers", "Prayers", v.prayersChrome, v.prayersWidth, v.prayersHeight);
	}

	/** Literal ids/captions plus per-kind callbacks built once: no strings or closures per frame. */
	function drawResourceWindow(v:VitalsConfig, kind:Int, id:String, caption:String,
			chrome:solarflare.ui.HudChrome, width:imgui.ref.FloatRef, height:imgui.ref.FloatRef):Void {
		var compact = VitalsConfig.compactRow(resourceStyle(v, kind), resourceVertical(v, kind));
		var h:Single = Math.max(compact ? 38 : 28, height.get());
		var w:Single = Math.max(80, width.get());
		solarflare.ui.HUDWidgetWindow.draw(id, caption, chrome, w, h, resourceBodyFns[kind], openResourceTrackerFn,
			resourceHideFns[kind], false, null, resourceResizeFns[kind]);
	}

	static function resourceStyle(v:VitalsConfig, kind:Int):Int {
		return switch (kind) { case 0: v.hpStyle.get(); case 1: v.rageStyle.get(); case 2: v.manaStyle.get(); default: 0; };
	}

	static function resourceVertical(v:VitalsConfig, kind:Int):Bool {
		return switch (kind) { case 0: v.hpVertical.get(); case 1: v.rageVertical.get(); case 2: v.manaVertical.get(); default: false; };
	}

	static function resourceHidden(v:VitalsConfig, kind:Int):imgui.ref.BoolRef {
		return switch (kind) { case 0: v.hpHidden; case 1: v.rageHidden; case 2: v.manaHidden; default: v.prayersHidden; };
	}

	function drawResourceBody(kind:Int, size:imgui.Structs.ImVec2):Void {
		var v = config.vitals;
		if (v == null)
			return;
		var style = resourceStyle(v, kind);
		var vertical = resourceVertical(v, kind);
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
	}

	function hideResource(kind:Int):Void {
		var v = config.vitals;
		if (v == null)
			return;
		resourceHidden(v, kind).set(true);
		solarflare.ui.SettingsStore.markDirty();
	}

	function resizeResource(kind:Int, newW:Single, newH:Single):Void {
		var v = config.vitals;
		if (v == null)
			return;
		var compact = VitalsConfig.compactRow(resourceStyle(v, kind), resourceVertical(v, kind));
		var width = switch (kind) { case 0: v.hpWidth; case 1: v.rageWidth; case 2: v.manaWidth; default: v.prayersWidth; };
		var height = switch (kind) { case 0: v.hpHeight; case 1: v.rageHeight; case 2: v.manaHeight; default: v.prayersHeight; };
		width.set(Math.max(80, newW));
		height.set(Math.max(compact ? 38 : 28, newH));
		solarflare.ui.SettingsStore.markDirty();
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
