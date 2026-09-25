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
	var playerCastOverlay:PlayerCastOverlay;
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
		playerCastOverlay = new PlayerCastOverlay();
		launchers = config.launchers;
		auraOverlay = new solarflare.aura.AuraOverlay(config.auras);
		auraOverlay.openBuilder = function() { config.auraBuilder.open.set(true); };
		geauxBar.openBuilder = function() { config.geauxBuilder.open.set(true); };
		comboOverlay.openBuilder = function() { config.resourceTracker.open.set(true); };
		conduitOverlay.openBuilder = function() { config.resourceTracker.open.set(true); };
		chaincastOverlay.openBuilder = function() { config.resourceTracker.open.set(true); };
		attackComboOverlay.openBuilder = function() { config.resourceTracker.open.set(true); };

		targetOverlay.openBuilder = function() { config.target.open.set(true); };
		playerCastOverlay.openBuilder = function() { config.castBar.open.set(true); };
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

	var prevCursorFree:Bool = true;

	/** UI assets also load at the title screen, before GameApp exists. */
	public function observeAssets():Void {
		solarflare.runtime.TelemetryKernel.observeAssets();
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

		solarflare.runtime.TelemetryKernel.observe(app, config, restoreNativeChat);
		// Profile switching consumes the frozen identity only after telemetry has
		// refreshed it; no live game objects are touched from the profile system.
		try
			solarflare.ui.FeatureProfiles.observeCharacter(config)
		catch (_:Dynamic) {}

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
			if (!suppressed)
				playerCastOverlay.draw(config.castBar);
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
	}

	/** Flush pending layout/toggles when GameApp is gone (logout / shutdown). */
	public function flushPendingSettings():Void {
		if (solarflare.ui.SettingsStore.isDirty())
			solarflare.ui.SettingsStore.save(config);
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
