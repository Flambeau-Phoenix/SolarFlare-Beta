package solarflare.ui;

import solarflare.attackcombo.AttackComboConfig;
import solarflare.chaincast.Chaincast;
import solarflare.combo.Combo;
import solarflare.conduit.Conduit;
import solarflare.combatlog.CombatLogConfig;
import solarflare.castbar.CastBarConfig;
import solarflare.geaux.GeauxConfig;
import solarflare.geaux.GeauxBuilder;
import solarflare.getrifty.GetRifty;
import solarflare.lightsaber.Lightsaber;
import solarflare.notebook.Notebook;
import solarflare.resourcetracker.ResourceTrackerBuilder;
import solarflare.target.TargetConfig;
import solarflare.ui.HudLaunchers;
import solarflare.ui.SettingsStore;
import solarflare.ui.ByteUtil;
import solarflare.ui.UiCol;
import solarflare.ui.UiActionQueue.UiActionKind;
import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiKey;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;

/**
 * F6 hub for SolarFlare: Auras, Geaux, Resource Tracker, Notebook, Lightsaber, Combat Log, Theme.
 * GetRifty is opt-in via the hub sun button (opens settings; overlay stays hidden until enabled).
 * Local Time remains a hidden settings field for persistence.
 */
class ConfigPanel {
	static inline var HUB_LOGO:String = GameIcons.HUB_LOGO;
	static inline var HUB_LOGO_MAX_W:Single = 180;
	static inline var HUB_LOGO_ASPECT:Single = 526.0 / 1071.0;
	static inline var HUB_LOGO_U0:Single = 137.0 / 1400.0;
	static inline var HUB_LOGO_V0:Single = 156.0 / 900.0;
	static inline var HUB_LOGO_U1:Single = 1208.0 / 1400.0;
	static inline var HUB_LOGO_V1:Single = 682.0 / 900.0;
	static inline var TAB_RESOURCES:Int = 0;
	static inline var TAB_GEAUX:Int = 1;
	static inline var TAB_ATTACK:Int = 2;
	static inline var TAB_AURAS:Int = 3;
	static inline var TAB_NOTEBOOK:Int = 4;
	static inline var TAB_LIGHTSABER:Int = 5;
	static inline var TAB_COMBAT_LOG:Int = 6;
	static inline var TAB_THEME:Int = 7;
	static inline var TAB_EXTRABARS:Int = 8;
	static inline var TAB_BARTER:Int = 9;
	static inline var TAB_NATIVE:Int = 10;
	static inline var TAB_STATUS:Int = 11;
	static inline var TAB_GETRIFTY:Int = 12;
	public var open:BoolRef;
	public var vitals:VitalsConfig;
	public var uiPack:UiPackConfig;
	public var nativeHide:NativeHideConfig;
	public var hideMove:HideMoveConfig;
	public var barter:solarflare.barter.BarTer;
	public var statusBoard:solarflare.statusboard.StatusBoard;
	public var geaux:GeauxConfig;
	public var getRifty:GetRiftyConfig;
	public var combo:ComboConfig;
	public var chaincast:ChaincastConfig;
	public var conduit:ConduitConfig;
	public var combatLog:CombatLogConfig;
	public var target:TargetConfig;
	public var castBar:CastBarConfig;
	public var notebook:Notebook;
	public var launchers:HudLaunchers;
	public var auras:solarflare.aura.AuraConfig;
	public var lightsaber:LightsaberConfig;
	public var resourceTracker:ResourceTrackerBuilder;
	public var geauxBuilder:GeauxBuilder;
	public var auraBuilder:solarflare.aura.AuraBuilder;
	public var extraBarsPrototype:solarflare.extrabars.ExtraBars;
	public var attackCombo:AttackComboConfig;
	public var hubChrome:HudChrome;
	public var hubW:FloatRef;
	public var hubH:FloatRef;
	public var hubSizeDirty = true;
	public var rememberHubLayout = new BoolRef(true);
	var lastHubX:Float = Math.NaN;
	var lastHubY:Float = Math.NaN;

	public var dbgMetrics:BoolRef;
	public var dbgLog:BoolRef;

	var showSaber:BoolRef;
	var showGetRifty:BoolRef;
	var showHp:BoolRef;
	var showRage:BoolRef;
	var showMana:BoolRef;
	var showPrayers:BoolRef;
	var showCombo:BoolRef;
	var showAttack:BoolRef;
	var showTarget:BoolRef;
	var showCastBar:BoolRef;
	var showChain:BoolRef;
	var showConduit:BoolRef;
	var showF6Btn:BoolRef;
	var toggleCooldownUntil:Float = 0;
	var activeHubTab:Int = TAB_RESOURCES;
	/** Session-only: hub collapsed to a narrow module rail while builders are in use. */
	var railed:Bool = false;
	var railExpandedW:Float = 0;
	var railExpandedH:Float = 0;
	var hubWinH:Float = 0;
	static inline var HUB_TITLE:String = "SolarFlare###SolarFlare.Hub";
	static inline var RAIL_W:Float = 340;
	var savedHubOpen:Bool = false;
	var savedResourceBuilderOpen:Bool = false;
	var savedGeauxBuilderOpen:Bool = false;
	var savedAuraBuilderOpen:Bool = false;
	var resumeHubAfterCamera:Bool = false;
	/** Central registry of interactive tool open refs (camera close). */
	var interactiveOpenRefs:Array<BoolRef> = [];

	public function new() {
		open = new BoolRef(true);
		hubW = new FloatRef(720);
		hubH = new FloatRef(820);
		dbgMetrics = new BoolRef(false);
		dbgLog = new BoolRef(false);
		showSaber = new BoolRef(false);
		showGetRifty = new BoolRef(false);
		showHp = new BoolRef(false);
		showRage = new BoolRef(false);
		showMana = new BoolRef(false);
		showPrayers = new BoolRef(false);
		showCombo = new BoolRef(false);
		showAttack = new BoolRef(false);
		showTarget = new BoolRef(false);
		showCastBar = new BoolRef(false);
		showChain = new BoolRef(false);
		showConduit = new BoolRef(false);
		showF6Btn = new BoolRef(false);
		ThemePalette.init();
		vitals = new VitalsConfig();
		uiPack = new UiPackConfig();
		nativeHide = new NativeHideConfig();
		hideMove = new HideMoveConfig();
		barter = new solarflare.barter.BarTer();
		barter.host = this;
		statusBoard = new solarflare.statusboard.StatusBoard();
		geaux = new GeauxConfig();
		getRifty = new GetRiftyConfig();
		combo = new ComboConfig();
		chaincast = new ChaincastConfig();
		conduit = new ConduitConfig();
		combatLog = new CombatLogConfig();
		target = new TargetConfig();
		castBar = new CastBarConfig();
		notebook = new Notebook();
		launchers = new HudLaunchers();
		auras = new solarflare.aura.AuraConfig();
		lightsaber = new LightsaberConfig();
		resourceTracker = new ResourceTrackerBuilder(this);
		geauxBuilder = new GeauxBuilder(geaux, this);
		auraBuilder = new solarflare.aura.AuraBuilder(auras, this);
		extraBarsPrototype = new solarflare.extrabars.ExtraBars(this);
		attackCombo = new AttackComboConfig();
		hubChrome = new HudChrome(40, 80);
		// Fresh installs start with only the F6 hub. Saved settings override these defaults.
		vitals.hpHidden.set(true);
		vitals.rageHidden.set(true);
		vitals.manaHidden.set(true);
		vitals.prayersHidden.set(true);
		combo.hidden.set(true);
		attackCombo.hidden.set(true);
		target.hidden.set(true);
		castBar.hidden.set(false);
		chaincast.hidden.set(true);
		conduit.hidden.set(true);
		geaux.enabled.set(false);
		auras.enabled.set(false);
		lightsaber.hidden.set(true);
		getRifty.hidden.set(true);
		combatLog.hidden.set(true);
		if (launchers != null) {
			if (launchers.f6 != null) launchers.f6.hidden.set(true);
			if (launchers.f7 != null) launchers.f7.hidden.set(true);
		}
		rebuildInteractiveRegistry();
		SettingsStore.bind(this);
		SettingsStore.load(this);
		// Stray HUD: never leave combo pips enabled from legacy profiles / max_combo auras.
		if (combo != null)
			combo.hidden.set(true);
		if (showCombo != null)
			showCombo.set(false);
		if (auras != null)
			auras.disableUnanchoredComboTrackers();
		// Personal HP: fixed screen coords above Geaux (not world-projected).
		if (vitals != null && geaux != null)
			vitals.anchorHpAboveGeaux(geaux);
		FeatureProfiles.init(this);
		UiActionQueue.bind(this);
	}

	function rebuildInteractiveRegistry():Void {
		interactiveOpenRefs = [];
		registerInteractive(open);
		registerInteractive(dbgMetrics);
		registerInteractive(dbgLog);
		registerInteractive(solarflare.debug.DebugSystem.open);
		#if solarflare_telemetry
		registerInteractive(solarflare.debug.PayloadProbe.enabled);
		registerInteractive(solarflare.debug.ResolutionLedger.enabled);
		#end
		if (resourceTracker != null) registerInteractive(resourceTracker.open);
		if (geauxBuilder != null) registerInteractive(geauxBuilder.open);
		if (auraBuilder != null) registerInteractive(auraBuilder.open);
		if (extraBarsPrototype != null) registerInteractive(extraBarsPrototype.open);
		if (barter != null && barter.config != null) registerInteractive(barter.config.open);
		if (uiPack != null) registerInteractive(uiPack.open);
		if (notebook != null) registerInteractive(notebook.open);
		if (vitals != null) registerInteractive(vitals.open);
		if (geaux != null) registerInteractive(geaux.open);
		if (combo != null) registerInteractive(combo.open);
		if (chaincast != null) registerInteractive(chaincast.open);
		if (conduit != null) registerInteractive(conduit.open);
		if (target != null) registerInteractive(target.open);
		if (castBar != null) registerInteractive(castBar.open);
		if (attackCombo != null) registerInteractive(attackCombo.open);
		if (lightsaber != null) {
			registerInteractive(lightsaber.open);
			registerInteractive(lightsaber.showLog);
		}
	}

	function registerInteractive(ref:BoolRef):Void {
		if (ref != null)
			interactiveOpenRefs.push(ref);
	}

	/** Close every independently retained editor. Explicit closes do not auto-resume. */
	public function closeInteractiveWindows():Void {
		resumeHubAfterCamera = false;
		closeInteractiveWindowsImpl();
	}

	/** Camera mode closes interactive windows to free the view. */
	public function suspendForCamera():Void {
		resumeHubAfterCamera = false;
		closeInteractiveWindowsImpl();
	}

	/** Transitions out of camera lock never auto-pop the F6 hub (F6 toggle is explicit only). */
	public function resumeAfterCamera():Void {
		resumeHubAfterCamera = false;
	}

	function closeInteractiveWindowsImpl():Void {
		var changed = false;
		for (ref in interactiveOpenRefs) {
			if (ref != null && ref.get()) {
				ref.set(false);
				changed = true;
			}
		}
		if (geauxBuilder != null)
			geauxBuilder.clearTransientState();
		if (auraBuilder != null)
			auraBuilder.clearTransientState();
		if (extraBarsPrototype != null) extraBarsPrototype.clearTransientState();
		if (barter != null) barter.clearTransientState();
		if (changed) SettingsStore.markDirty();
	}

	/**
	 * Engine key codes, resolved once.
	 *
	 * `hxd.Key.F6` is a GameLib proxy read: a native companion lookup plus a
	 * Reflect.field on every access. Reading the constant inline meant four of those
	 * per frame for two hotkeys, forever, on the draw path.
	 */
	static var f6Code:Int = -1;
	static var f12Code:Int = -1;

	static function ensureHotkeyCodes():Void {
		if (f6Code >= 0)
			return;
		try {
			f6Code = hxd.Key.F6;
			f12Code = hxd.Key.F12;
		} catch (_:Dynamic) {
			f6Code = 0;
			f12Code = 0;
		}
	}

	/** F6 toggle polled from draw(). */
	public function pollToggle():Void {
		var now = 0.0;
		try
			now = haxe.Timer.stamp()
		catch (_:Dynamic)
			now = Date.now().getTime() / 1000.0;
		if (now < toggleCooldownUntil)
			return;

		ensureHotkeyCodes();

		var hit = false;
		try
			hit = f6Code > 0 && hxd.Key.isPressed(f6Code)
		catch (_:Dynamic) {}
		if (!hit) {
			try
				hit = ImGui.isKeyPressed(ImGuiKey.F6, false)
			catch (_:Dynamic) {}
		}
		if (hit) {
			open.set(!open.get());
			SettingsStore.markDirty();
			toggleCooldownUntil = now + 0.25;
		}

		var hitF12 = false;
		try
			hitF12 = f12Code > 0 && hxd.Key.isPressed(f12Code)
		catch (_:Dynamic) {}
		if (!hitF12) {
			try
				hitF12 = ImGui.isKeyPressed(ImGuiKey.F12, false)
			catch (_:Dynamic) {}
		}
		if (hitF12) {
			solarflare.debug.DebugSystem.toggle();
		}

		pollHideAll(now);
	}

	/**
	 * Hide All blackout key. Polled next to F6/F12 so it works during plain HUD play,
	 * with no editor open and no keyboard capture.
	 */
	function pollHideAll(now:Float):Void {
		// A numpad digit is a character while a field has focus; never steal it.
		try {
			if (ImGui.isAnyItemActive())
				return;
		} catch (_:Dynamic) {}

		var hit = false;
		var code = solarflare.ui.HideAllBind.code();
		if (code > 0) {
			try
				hit = hxd.Key.isPressed(code)
			catch (_:Dynamic) {}
		}
		// Middle click is only honoured with a free cursor: during camera look it
		// belongs to Farever, and the player is not reaching for an NPC anyway.
		if (!hit && solarflare.ui.HideAllBind.middleMouse.get() && CursorCaptureFix.cursorFree) {
			try
				hit = ImGui.isMouseClicked(imgui.Enums.ImGuiMouseButton.Middle, false)
			catch (_:Dynamic) {}
		}
		if (!hit)
			return;

		var next = !solarflare.ui.HudSuppress.hideAll.get();
		solarflare.ui.HudSuppress.hideAll.set(next);
		toggleCooldownUntil = now + 0.25;
		try
			ToastManager.info(next ? "SolarFlare HUD hidden" : "SolarFlare HUD shown")
		catch (_:Dynamic) {}
	}

	/** Hub, builders, debug panels, or other editors that must block Farever menu shortcuts. */
	public function anyInteractiveOpen():Bool {
		for (ref in interactiveOpenRefs)
			if (ref != null && ref.get())
				return true;
		return false;
	}

	public function anyBarVisible():Bool {
		return vitals != null && vitals.anyBarVisible();
	}

	public function draw():Void {
		if (dbgMetrics.get())
			ImGui.showMetricsWindow(dbgMetrics);
		if (dbgLog.get())
			ImGui.showDebugLogWindow(dbgLog);

		pollHubDismissKeys();
		pollToolShortcuts();

		if (open.get()) {
			ImGui.setNextWindowSizeConstraints(ImGui.vec2(520, 600), ImGui.vec2(1920, 1200));
			EditorWindow.drawMenuWindow("SolarFlare###SolarFlare.Hub", open,
				Math.max(720, hubW.get()), Math.max(820, hubH.get()), function() {
				var pos = ImGui.getWindowPos();
				var size = ImGui.getWindowSize();
				hubWinH = size.y;
				if (!railed && rememberHubLayout.get() && (pos.x != lastHubX || pos.y != lastHubY
					|| size.x != hubW.get() || size.y != hubH.get())) {
					lastHubX = pos.x;
					lastHubY = pos.y;
					hubW.set(size.x);
					hubH.set(size.y);
					SettingsStore.markDirty();
				}
				drawHubMenuBar();
				if (railed) {
					drawHubRail();
					return;
				}
				drawHubLogo();
				// One profile strip for every module tab; builders show the same strip.
				FeatureProfiles.drawToolbar(this, "hub", "hub");
				ImGui.separator();
				drawModuleTabs();
				ImGui.separator();
				HudChrome.safeChild("##hub_active_settings", ImGui.vec2(0, 0), 0, drawActiveModule,
					imgui.Enums.ImGuiChildFlags.Borders | imgui.Enums.ImGuiChildFlags.AutoResizeY | imgui.Enums.ImGuiChildFlags.AlwaysUseWindowPadding);
				ImGui.separator();
				if (ImGui.collapsingHeader("MENU launcher")) {
					UiLayout.propertyGrid("##hub_show_props", function() {
						if (launchers != null) {
							UiLayout.propertyRow("MENU button", function() {
								visCheck("Show##hub_f6b", launchers.f6.hidden, showF6Btn);
							});
							UiLayout.propertyRow("MENU size", function() {
								if (ImGui.sliderFloat("##hub_f6s", launchers.f6.size, HudLaunchers.F6_MIN, HudLaunchers.F6_MAX, "%.0f")) {
									launchers.f6.sizeDirty = true;
									SettingsStore.markDirty();
								}
							});
							UiLayout.propertyRow("MENU chrome", function() {
								UiLayout.inlinePair(
									"##hub_f6_chrome",
									function(_:Single) {
										if (ImGui.checkbox("Lock##f6b", launchers.f6.chrome.locked))
											SettingsStore.markDirty();
									},
									function(_:Single) {
										if (ImGui.checkbox("Transparent##f6b", launchers.f6.chrome.transparent))
											SettingsStore.markDirty();
									}
								);
							}, "Unlock MENU, then drag its sun icon; click to collapse/expand. Resize from the bottom-right grip.");
						}
					});
					ImGui.textDisabled(solarflare.geaux.GeauxBar.lastStatus);
					ImGui.textDisabled(solarflare.ui.GameIcons.statusLine());
				}

				if (ImGui.collapsingHeader("Workspace & Docking Layout")) {
					UiLayout.propertyGrid("##hub_workspace_props", function() {
						UiLayout.propertyRow("Geometry", function() {
							if (ImGui.checkbox("Remember F6 position/size##hub_remember", rememberHubLayout))
								SettingsStore.markDirty();
						});
						UiLayout.propertyRow("Mode", function() {
							ImGui.text(solarflare.ui.DockingHelper.isWindowDocked() ? "Docked into another window" : "Floating windows");
						}, "Drag one tool window onto another to tab or split. No screen-edge dock anchors.");
					});
					UiLayout.inlinePair(
						"##hub_dock_actions",
						function(w:Single) {
							if (ImGui.button("Save Layout##sf_save_dock", ImGui.vec2(w, 26)))
								UiActionQueue.save();
						},
						function(w:Single) {
							if (ImGui.button("Reset Layout##sf_reset_dock", ImGui.vec2(w, 26)))
								UiActionQueue.enqueue(UiActionKind.ResetDockLayout);
						}
					);
				}

				if (ImGui.collapsingHeader("Advanced diagnostics")) {
					ImGui.textWrapped("Font/style stacks are global with other HLX mods. Latin/Greek/Cyrillic is bundled.");
					UiLayout.propertyGrid("##hub_debug_props", function() {
						UiLayout.propertyRow("Windows", function() {
							var avail:Single = ImGui.getContentRegionAvail().x;
							var colW:Single = avail / 2;
							ImGui.checkbox("Perf monitor##sf_perf", solarflare.ui.PerformanceMonitor.open);
							ImGui.sameLine(colW);
							ImGui.checkbox("Metrics##sf_metrics", dbgMetrics);
							ImGui.checkbox("Debug log##sf_dbglog", dbgLog);
							#if solarflare_telemetry
							ImGui.sameLine(colW);
							ImGui.checkbox("Payload probe##sf_payload", solarflare.debug.PayloadProbe.enabled);
							#end
						});
						#if solarflare_telemetry
						UiLayout.propertyRow("Ledger", function() {
							ImGui.checkbox("Resolution ledger##sf_ledger", solarflare.debug.ResolutionLedger.enabled);
						}, "Panel open is session-only. Recording never auto-starts. JSONL: hlx/mods/solarflare/logs/");
						#end
					});
					#if solarflare_telemetry
					if (solarflare.debug.FieldWalkLog.lastPath.length > 0)
						ImGui.textDisabled(solarflare.debug.FieldWalkLog.lastPath);
					if (ImGui.smallButton("Copy FieldWalk log path##sf_fwlog"))
						UiActionQueue.copyText(solarflare.debug.FieldWalkLog.lastPath, "FieldWalk path copied");
					#end
				}
			}, false, rememberHubLayout.get());
		}
		if (resourceTracker != null) {
			try
				resourceTracker.draw()
			catch (_:Dynamic) {}
		}
		if (geauxBuilder != null) {
			try geauxBuilder.draw() catch (_:Dynamic) {}
		}
		if (auraBuilder != null) {
			try auraBuilder.draw() catch (_:Dynamic) {}
		}
		if (extraBarsPrototype != null) {
			try extraBarsPrototype.draw() catch (_:Dynamic) {}
		}
		if (uiPack != null) {
			try uiPack.drawMenu(this) catch (_:Dynamic) {}
		}
		trackProfileWindowState();
		if (target != null) {
			try target.draw() catch (_:Dynamic) {}
		}
		if (castBar != null) {
			try castBar.draw() catch (_:Dynamic) {}
		}
		try
			notebook.draw()
		catch (_:Dynamic) {}
		if (lightsaber != null) {
			try
				lightsaber.draw()
			catch (_:Dynamic) {}
		}
	}

	function drawHubMenuBar():Void {
		if (!ImGui.beginMenuBar())
			return;
		if (ImGui.beginMenu("Open")) {
			if (ImGui.menuItem("Aura Builder", "F6"))
				auraBuilder.open.set(true);
			if (ImGui.menuItem("Geaux Builder"))
				geauxBuilder.open.set(true);
			if (ImGui.menuItem("ExtraBars"))
				extraBarsPrototype.open.set(true);
			if (ImGui.menuItem("BarTer"))
				if (barter != null) barter.config.open.set(true);
			if (ImGui.menuItem("Native UI"))
				if (uiPack != null) uiPack.open.set(true);
			if (ImGui.menuItem("Status Board"))
				showHubTab("status");
			if (ImGui.menuItem("Resource Tracker"))
				resourceTracker.open.set(true);
			if (ImGui.menuItem("Player Cast Bar"))
				castBar.open.set(true);
			if (ImGui.menuItem("Notebook"))
				notebook.open.set(true);
			if (ImGui.menuItem("Lightsaber"))
				lightsaber.open.set(true);
			if (ImGui.menuItem("GetRifty"))
				showHubTab("getrifty");
			ImGui.endMenu();
		}
		if (ImGui.beginMenu("File")) {
			if (ImGui.menuItem("Save", "Ctrl+S"))
				UiActionQueue.save();
			if (ImGui.menuItem("Reset Dock Layout"))
				UiActionQueue.enqueue(UiActionKind.ResetDockLayout);
			ImGui.endMenu();
		}
		ImGui.endMenuBar();
	}

	function pollToolShortcuts():Void {
		// Keyboard ownership follows interactive tools, not cursorFree.
		if (!anyInteractiveOpen())
			return;
		try {
			var ctrl = ImGui.isKeyDown(ImGuiKey.LeftCtrl) || ImGui.isKeyDown(ImGuiKey.RightCtrl);
			if (ctrl && ImGui.isKeyPressed(ImGuiKey.S, false))
				UiActionQueue.save();
		} catch (_:Dynamic) {}
	}

	/** Close hub on Escape only â€” never letter keys (typing must not dismiss). */
	function pollHubDismissKeys():Void {
		if (!open.get())
			return;
		try {
			// isAnyItemActive alone misses a text field that holds keyboard focus
			// without being in an active edit this frame; Escape there would throw
			// away what was typed. Both signals have to be clear.
			var typing = false;
			try
				typing = ImGui.isAnyItemActive() || ImGui.isAnyItemFocused()
			catch (_:Dynamic) {}
			if (typing)
				return;
			if (ImGui.isKeyPressed(ImGuiKey.Escape, false))
				open.set(false);
		} catch (_:Dynamic) {}
	}

	function drawHubLogo():Void {
		var avail = ImGui.getContentRegionAvail();
		if (avail == null || avail.x < 40)
			return;
		var w:Single = avail.x < HUB_LOGO_MAX_W ? avail.x : HUB_LOGO_MAX_W;
		var h:Single = w * HUB_LOGO_ASPECT;
		var startX = ImGui.getCursorPosX();
		ImGui.setCursorPosX(startX + (avail.x - w) * 0.5);
		var p = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();

		if (!GameIcons.imageKeyUv(HUB_LOGO, w, h, HUB_LOGO_U0, HUB_LOGO_V0, HUB_LOGO_U1, HUB_LOGO_V1))
			ImGui.dummy(ImGui.vec2(w, h));

	}

	static var NAV_GROUP_NAMES:Array<String> = ["Display", "Automation", "Tools"];
	static var NAV_GROUPS:Array<Array<Int>> = [
		[TAB_RESOURCES, TAB_GEAUX, TAB_BARTER, TAB_EXTRABARS, TAB_ATTACK, TAB_STATUS],
		[TAB_AURAS, TAB_COMBAT_LOG],
		[TAB_NOTEBOOK, TAB_LIGHTSABER, TAB_NATIVE, TAB_THEME, TAB_GETRIFTY]
	];

	static function tabLabel(id:Int):String {
		return switch (id) {
			case TAB_RESOURCES: "Resources";
			case TAB_GEAUX: "Geaux";
			case TAB_ATTACK: "Attack Combo";
			case TAB_AURAS: "Auras";
			case TAB_NOTEBOOK: "Notebook";
			case TAB_LIGHTSABER: "Lightsaber";
			case TAB_COMBAT_LOG: "Combat Log";
			case TAB_THEME: "Theme";
			case TAB_EXTRABARS: "ExtraBars";
			case TAB_BARTER: "BarTer";
			case TAB_NATIVE: "Native UI";
			case TAB_GETRIFTY: "GetRifty";
			default: "Status Board";
		}
	}

	/** 1 = module overlay on, 0 = off, -1 = no simple on/off flag. */
	function tabState(id:Int):Int {
		switch (id) {
			case TAB_GEAUX:
				return geaux != null ? (geaux.enabled.get() ? 1 : 0) : -1;
			case TAB_ATTACK:
				return attackCombo != null ? (attackCombo.hidden.get() ? 0 : 1) : -1;
			case TAB_AURAS:
				return auras != null ? (auras.enabled.get() ? 1 : 0) : -1;
			case TAB_LIGHTSABER:
				return lightsaber != null ? (lightsaber.hidden.get() ? 0 : 1) : -1;
			case TAB_STATUS:
				return statusBoard != null ? (statusBoard.config.hidden.get() ? 0 : 1) : -1;
			case TAB_GETRIFTY:
				return getRifty != null ? (getRifty.hidden.get() ? 0 : 1) : -1;
			default:
				return -1;
		}
	}

	/** Grouped module navigation: Display / Automation / Tools, with an on-dot per module. */
	function drawModuleTabs():Void {
		var available = ImGui.getContentRegionAvail().x;
		var columns = UiLayout.columnCount(available, 120, 4, 8);
		for (g in 0...NAV_GROUPS.length) {
			var ids = NAV_GROUPS[g];
			var total = ids.length;
			ImGui.textDisabled(NAV_GROUP_NAMES[g]);
			if (g == 0) {
				ImGui.sameLine(0, 0);
				ImGui.setCursorPosX(ImGui.getCursorPosX() + Math.max(0, available - 190));
				if (UiChrome.ghostButton("Collapse##hub_rail_toggle", ImGui.vec2(80, 22)))
					setRail(true);
			}
			var start = 0;
			var row = 0;
			while (start < total) {
				var rowCount = (total - start) < columns ? (total - start) : columns;
				var rowStart = start;
				UiLayout.inlineSplit("##hub_nav_" + g + "_" + row, columns, function(cell:Int, width:Single) {
					var index = rowStart + cell;
					if (index >= total) return;
					var id = ids[index];
					if (moduleTab(tabLabel(id), id, width))
						onModuleChosen(id);
				}, 8);
				start += rowCount;
				row++;
			}
			UiChrome.gap(UiChrome.SP_S);
		}
	}

	/** Selecting a module also opens the editors that are their own window. */
	function onModuleChosen(id:Int):Void {
		if (id == TAB_NOTEBOOK) notebook.open.set(true);
		if (id == TAB_EXTRABARS) extraBarsPrototype.open.set(true);
		if (id == TAB_BARTER && barter != null) barter.config.open.set(true);
	}

	/** Open the hub on a module's settings page (used by overlay context menus and the Open menu). */
	public function showHubTab(which:String):Void {
		var id = which == "status" ? TAB_STATUS : (which == "getrifty" ? TAB_GETRIFTY : -1);
		if (id < 0) return;
		open.set(true);
		activeHubTab = id;
		if (railed) setRail(false);
		SettingsStore.markDirty();
	}

	function moduleTab(label:String, id:Int, width:Single):Bool {
		var selected = activeHubTab == id;
		var clicked = UiChrome.navButton(label + "##hub_tab_" + id, selected, ImGui.vec2(width, 32));
		var state = tabState(id);
		if (state >= 0) {
			// Status dot (theme accent when on, hollow when off) in the chip's top-right corner.
			var max = ImGui.getItemRectMax();
			var min = ImGui.getItemRectMin();
			var dl = ImGui.getWindowDrawList();
			var theme = ThemePalette.current();
			var center = ImGui.vec2(max.x - 9, min.y + 9);
			if (state == 1)
				ImGui.ImDrawList_AddCircleFilled(dl, center, 3.5, ImGui.colorConvertFloat4ToU32(theme.accent), 12);
			else
				ImGui.ImDrawList_AddCircle(dl, center, 3.5, ImGui.colorConvertFloat4ToU32(theme.border), 12, 1.25);
		}
		if (clicked) {
			activeHubTab = id;
			SettingsStore.markDirty();
			return true;
		}
		return false;
	}

	/** Narrow window: profile strip plus one button per module; editors open as their own windows. */
	function setRail(on:Bool):Void {
		if (on == railed) return;
		if (on) {
			railExpandedW = Math.max(720, hubW.get());
			railExpandedH = Math.max(820, hubH.get());
			ToolWindow.requestSize(HUB_TITLE, RAIL_W, Math.max(420, Math.min(hubWinH, 760)), true);
		} else {
			ToolWindow.requestSize(HUB_TITLE, railExpandedW, railExpandedH, false);
		}
		railed = on;
	}

	function drawHubRail():Void {
		if (UiChrome.ghostButton("Expand hub##hub_rail_toggle", ImGui.vec2(-1, 28)))
			setRail(false);
		FeatureProfiles.drawInlineBar(this, "hub_rail");
		ImGui.separator();
		for (g in 0...NAV_GROUPS.length) {
			ImGui.textDisabled(NAV_GROUP_NAMES[g]);
			var ids = NAV_GROUPS[g];
			for (i in 0...ids.length) {
				var id = ids[i];
				if (moduleTab(tabLabel(id), id, ImGui.getContentRegionAvail().x)) {
					onModuleChosen(id);
					openModuleWindow(id);
				}
			}
			UiChrome.gap(UiChrome.SP_S);
		}
	}

	/** Rail click: open the module's own window if it has one, otherwise bring the hub back. */
	function openModuleWindow(id:Int):Void {
		switch (id) {
			case TAB_RESOURCES: if (resourceTracker != null) resourceTracker.open.set(true);
			case TAB_GEAUX: if (geauxBuilder != null) geauxBuilder.open.set(true);
			case TAB_AURAS: if (auraBuilder != null) auraBuilder.open.set(true);
			case TAB_LIGHTSABER: if (lightsaber != null) lightsaber.open.set(true);
			case TAB_NATIVE: if (uiPack != null) uiPack.open.set(true);
			case TAB_ATTACK: if (resourceTracker != null) resourceTracker.openFor("attack");
			case TAB_NOTEBOOK | TAB_EXTRABARS | TAB_BARTER:
			default: setRail(false);
		}
	}

	/** Module card header: title band, status line and one right-aligned primary action. */
	function drawModuleHeader(title:String, status:String, openLabel:String, id:String):Bool {
		UiChrome.sectionHeader(title);
		var startX = ImGui.getCursorPosX();
		var avail = ImGui.getContentRegionAvail().x;
		var btnW:Single = 168;
		var y = ImGui.getCursorPosY();
		ImGui.setCursorPosY(y + 5);
		ImGui.textDisabled(status);
		ImGui.sameLine(0, 0);
		var x = Math.max(ImGui.getCursorPosX() + 8, startX + avail - btnW);
		ImGui.setCursorPosY(y);
		ImGui.setCursorPosX(x);
		var clicked = UiChrome.accentButton(openLabel + "##" + id, ImGui.vec2(btnW, 30));
		UiChrome.gap(UiChrome.SP_S);
		return clicked;
	}

	function drawActiveModule():Void {
		switch (activeHubTab) {
			case TAB_GEAUX:
				drawGeauxHubSummary();
			case TAB_ATTACK:
				if (drawModuleHeader("Attack Combo", attackCombo.hidden.get() ? "Overlay hidden" : "Overlay shown", "Open settings", "tab_attack_open"))
					resourceTracker.openFor("attack");
				ImGui.textWrapped("Weapon attack-chain overlay.");
				visCheck("Show Attack Combo##tab_attack_show", attackCombo.hidden, showAttack);
			case TAB_AURAS:
				if (drawModuleHeader("Auras", Std.string(auras.auras.length) + " aura(s) / " + (auras.enabled.get() ? "enabled" : "disabled"), "Open builder", "tab_aura_open"))
					auraBuilder.open.set(true);
				ImGui.textWrapped("Enable the aura system, then open the builder.");
				if (ImGui.checkbox("Enable aura system##tab_aura_show", auras.enabled))
					SettingsStore.markDirty();
				ImGui.separator();
				UiChrome.heading("Status countdowns");
				UiLayout.propertyGrid("##tab_aura_countdown", function() {
					UiLayout.propertyRow("Every status", function() {
						if (ImGui.checkbox("##tab_aura_cd_all", auras.countdownAll))
							SettingsStore.markDirty();
					}, "Draws remaining seconds on any aura with a known duration, not just short buffs.");
					UiLayout.propertyRow("Only under", function() {
						if (ImGui.sliderFloat("##tab_aura_cd_max", auras.countdownAutoMax, 0, 300, "%.0f s (0 = no limit)"))
							SettingsStore.markDirty();
					});
					UiLayout.propertyRow("Text size", function() {
						if (ImGui.sliderFloat("##tab_aura_cd_scale", auras.countdownScale, 0.5, 3, "%.2fx"))
							SettingsStore.markDirty();
					});
				});
				ImGui.separator();
				UiChrome.heading("Timers window");
				UiLayout.propertyGrid("##tab_aura_timerboard", function() {
					UiLayout.propertyRow("Hide window", function() {
						if (ImGui.checkbox("##tab_aura_tb_hide", auras.timerBoardHidden))
							SettingsStore.markDirty();
					});
					UiLayout.propertyRow("Max rows", function() {
						if (ImGui.sliderInt("##tab_aura_tb_max", auras.timerBoardMax, 1, 20))
							SettingsStore.markDirty();
					});
					UiLayout.propertyRow("Row height", function() {
						if (ImGui.sliderFloat("##tab_aura_tb_row", auras.timerBoardRowH, 16, 64, "%.0f px"))
							SettingsStore.markDirty();
					});
				});
			case TAB_NOTEBOOK:
				ImGui.textWrapped("The Notebook opens when you select this tab. Pages auto-save while you type and are stored separately in notebook.json.");
			case TAB_LIGHTSABER:
				if (drawModuleHeader("Lightsaber", lightsaber.hidden.get() ? "Meter hidden" : "Meter shown", "Open options", "tab_saber_open"))
					lightsaber.open.set(true);
				ImGui.textWrapped("Local combat-log DPS meter settings.");
				visCheck("Show Lightsaber##tab_saber_show", lightsaber.hidden, showSaber);
			case TAB_COMBAT_LOG:
				ImGui.textWrapped("Skill casts and resolved combat events.");
				combatLog.drawEditorContents();
			case TAB_EXTRABARS:
				if (drawModuleHeader("ExtraBars", Std.string(extraBarsPrototype.model.bars.length) + " bar(s) configured", "Open editor", "extra_open"))
					extraBarsPrototype.open.set(true);
				ImGui.textWrapped("Configure consumable bars and the optional Spark Cube tracker. These settings are remembered across all characters and gear builds.");
			case TAB_NATIVE:
                if (uiPack != null) {
                    uiPack.drawHubPackBlurb();
                    if (UiChrome.accentButton("Open Native UI settings##native_settings", ImGui.vec2(-1,32))) uiPack.open.set(true);
                }
            case TAB_STATUS:
                if (statusBoard != null) statusBoard.config.drawContents();
            case TAB_BARTER:
				if (barter != null)
					barter.config.drawHubSummary();
			case TAB_THEME:
				ThemePalette.drawThemeEditorPane();
			case TAB_GETRIFTY:
				if (getRifty != null) {
					UiChrome.sectionHeader("GetRifty");
					getRifty.drawContents();
				}
			default:
				if (drawModuleHeader("Resources", "Tracking bars and overlay flags", "Open builder", "tab_rt_open"))
					resourceTracker.open.set(true);
				drawResourceToggleGrid();
		}
	}

	function drawResourceToggleGrid():Void {
		UiChrome.subHeader("Tracking Bars");
		var v = vitals;
		var items:Array<{id:String, label:String, hidden:BoolRef}> = [];
		if (v != null) items.push({id: "health", label: "Health Bar", hidden: v.hpHidden});
		if (v != null) items.push({id: "rage", label: "Rage Bar", hidden: v.rageHidden});
		if (v != null) items.push({id: "mana", label: "Mana/Spark", hidden: v.manaHidden});
		if (v != null) items.push({id: "prayers", label: "Prayers", hidden: v.prayersHidden});
		if (combo != null) items.push({id: "combo", label: "Combo Points", hidden: combo.hidden});
		if (attackCombo != null) items.push({id: "attack", label: "Combo Tracker", hidden: attackCombo.hidden});
		if (chaincast != null) items.push({id: "chaincast", label: "Chaincast", hidden: chaincast.hidden});
		if (conduit != null) items.push({id: "conduit", label: "Conduits", hidden: conduit.hidden});
		if (target != null) items.push({id: "target", label: "Target Frame", hidden: target.hidden});
		if (castBar != null) items.push({id: "castbar", label: "Player Cast Bar", hidden: castBar.hidden});
		if (statusBoard != null) items.push({id: "statuses", label: "Status Board", hidden: statusBoard.config.hidden});

		var avail = ImGui.getContentRegionAvail().x;
		var cols = UiLayout.columnCount(avail, 120, 3, 4);
		var start = 0;
		while (start < items.length) {
			var remaining = items.length - start;
			var rowCount = remaining < cols ? remaining : cols;
			var rowStart = start;
			UiLayout.inlineSplit("##hub_res_row_" + Std.int(start / cols), rowCount, function(col:Int, w:Single) {
				var item = items[rowStart + col];
				if (item != null && item.hidden != null) {
					if (UiChrome.showingTile("##res_" + item.id, item.label, item.hidden, w, 32)) {
						SettingsStore.markDirty();
						if (item.id == "statuses")
							solarflare.ObserveDemand.markAuraStatusDirty();
					}
				}
			}, 6);
			start += rowCount;
		}
	}

	function drawGeauxHubSummary():Void {
		if (drawModuleHeader("Geaux", geaux.enabled.get() ? "Grid visible" : "Grid hidden", "Open builder", "tab_geaux_open"))
			geauxBuilder.open.set(true);
		ImGui.textWrapped("TellMeWhen-style floating CD grid (not the skill action bar â€” use BarTer for that).");
		UiLayout.propertyGrid("##hub_geaux_properties", function() {
			UiLayout.propertyRow("Visible", function() {
				if (UiChrome.toggleTileRef("##tab_geaux_show", "Visible", geaux.enabled, 108, 28)) {
					geaux.sizeDirty = true;
					if (geaux.chrome != null)
						geaux.chrome.posDirty = true;
					SettingsStore.markDirty();
				}
			});
			if (geaux.chrome != null) {
				UiLayout.propertyRow("Window", function() {
					UiLayout.inlinePair("##hub_geaux_window_pair",
						function(w:Single) {
							if (UiChrome.toggleTileRef("##tab_geaux_lock", "Lock", geaux.chrome.locked, w, 28))
								SettingsStore.markDirty();
						},
						function(w:Single) {
							if (UiChrome.toggleTileRef("##tab_geaux_trans", "Transparent", geaux.chrome.transparent, w, 28))
								SettingsStore.markDirty();
						});
				});
			}
		});
	}

	public function profileUiTab():Int return activeHubTab;
	public function statusSettingsOpen():Bool return open.get() && activeHubTab == TAB_STATUS;
	public function applyProfileUiTab(value:Int):Void {
		if (value >= TAB_RESOURCES && value <= TAB_GETRIFTY)
			activeHubTab = value;
	}

	function trackProfileWindowState():Void {
		var r = resourceTracker != null && resourceTracker.open.get();
		var g = geauxBuilder != null && geauxBuilder.open.get();
		var a = auraBuilder != null && auraBuilder.open.get();
		if (savedHubOpen != open.get() || savedResourceBuilderOpen != r || savedGeauxBuilderOpen != g || savedAuraBuilderOpen != a)
			SettingsStore.markDirty();
		savedHubOpen = open.get(); savedResourceBuilderOpen = r; savedGeauxBuilderOpen = g; savedAuraBuilderOpen = a;
	}

	function visCheck(label:String, hidden:BoolRef, shown:BoolRef):Void {
		if (hidden == null || shown == null)
			return;
		shown.set(!hidden.get());
		if (ImGui.checkbox(label, shown)) {
			hidden.set(!shown.get());
			SettingsStore.markDirty();
		}
	}

	function resourceQuickRow(label:String, id:String, hidden:BoolRef, chrome:HudChrome,
			secondaryLabel:String = null, secondary:BoolRef = null):Void {
		ImGui.spacing();
		UiChrome.subHeader(label);
		UiLayout.propertyGrid("##hub_rt_quick_" + id, function() {
			UiLayout.propertyRow("Window", function() {
				var avail:Single = ImGui.getContentRegionAvail().x;
				var colW:Single = (avail - 12) / 3;
				if (UiChrome.showingTile("##hub_rt_show_" + id, "Showing", hidden, colW, 28))
					SettingsStore.markDirty();
				ImGui.sameLine(0, 6);
				if (chrome != null && UiChrome.toggleTileRef("##hub_rt_lock_" + id, "Lock", chrome.locked, colW, 28))
					SettingsStore.markDirty();
				ImGui.sameLine(0, 6);
				if (chrome != null && UiChrome.toggleTileRef("##hub_rt_trans_" + id, "Transparent", chrome.transparent, colW, 28))
					SettingsStore.markDirty();
			});
			if (secondary != null) {
				UiLayout.propertyRow(secondaryLabel != null ? secondaryLabel : "Feature", function() {
					if (UiChrome.toggleTileRef("##hub_rt_secondary_" + id, "Enabled", secondary, 108, 28))
						SettingsStore.markDirty();
				}, "Displays the target's active cast directly beneath its health bar.");
			}
		});
		if (ImGui.button("Settings##hub_rt_settings_" + id, ImGui.vec2(-1, 0)))
			resourceTracker.openFor(StringTools.startsWith(id, "tab_") ? id.substr(4) : id);
		ImGui.separator();
	}

	static function bytesToString(bytes:hl.Bytes, cap:Int):String {
		return ByteUtil.readBytes(bytes, cap);
	}

	static function clearBytes(bytes:hl.Bytes, cap:Int):Void ByteUtil.clearBytes(bytes, cap);
}
