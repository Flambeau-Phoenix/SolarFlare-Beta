package solarflare.ui;

import solarflare.attackcombo.AttackComboConfig;
import solarflare.chaincast.Chaincast;
import solarflare.combo.Combo;
import solarflare.conduit.Conduit;
import solarflare.combatlog.CombatLogConfig;
import solarflare.geaux.GeauxConfig;
import solarflare.geaux.GeauxBuilder;
import solarflare.getrifty.GetRifty;
import solarflare.lightsaber.Lightsaber;
import solarflare.localtime.LocalTime;
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
	public var open:BoolRef;
	public var vitals:VitalsConfig;
	public var geaux:GeauxConfig;
	public var getRifty:GetRiftyConfig;
	public var combo:ComboConfig;
	public var chaincast:ChaincastConfig;
	public var conduit:ConduitConfig;
	public var localTime:LocalTimeConfig;
	public var combatLog:CombatLogConfig;
	public var target:TargetConfig;
	public var notebook:Notebook;
	public var launchers:HudLaunchers;
	public var auras:solarflare.aura.AuraConfig;
	public var lightsaber:LightsaberConfig;
	public var resourceTracker:ResourceTrackerBuilder;
	public var geauxBuilder:GeauxBuilder;
	public var auraBuilder:solarflare.aura.AuraBuilder;
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
	var showChain:BoolRef;
	var showConduit:BoolRef;
	var showF6Btn:BoolRef;
	var toggleCooldownUntil:Float = 0;
	var activeHubTab:Int = TAB_RESOURCES;
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
		showChain = new BoolRef(false);
		showConduit = new BoolRef(false);
		showF6Btn = new BoolRef(false);
		ThemePalette.init();
		vitals = new VitalsConfig();
		geaux = new GeauxConfig();
		getRifty = new GetRiftyConfig();
		combo = new ComboConfig();
		chaincast = new ChaincastConfig();
		conduit = new ConduitConfig();
		localTime = new LocalTimeConfig();
		combatLog = new CombatLogConfig();
		target = new TargetConfig();
		notebook = new Notebook();
		launchers = new HudLaunchers();
		auras = new solarflare.aura.AuraConfig();
		lightsaber = new LightsaberConfig();
		resourceTracker = new ResourceTrackerBuilder(this);
		geauxBuilder = new GeauxBuilder(geaux, this);
		auraBuilder = new solarflare.aura.AuraBuilder(auras, this);
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
		chaincast.hidden.set(true);
		conduit.hidden.set(true);
		geaux.enabled.set(false);
		auras.enabled.set(false);
		lightsaber.hidden.set(true);
		getRifty.hidden.set(true);
		localTime.enabled.set(false);
		combatLog.hidden.set(true);
		if (launchers != null) {
			if (launchers.f6 != null) launchers.f6.hidden.set(true);
			if (launchers.f7 != null) launchers.f7.hidden.set(true);
		}
		rebuildInteractiveRegistry();
		SettingsStore.bind(this);
		SettingsStore.load(this);
		FeatureProfiles.init(this);
		UiActionQueue.bind(this);
	}

	function rebuildInteractiveRegistry():Void {
		interactiveOpenRefs = [];
		registerInteractive(open);
		registerInteractive(dbgMetrics);
		registerInteractive(dbgLog);
		if (resourceTracker != null) registerInteractive(resourceTracker.open);
		if (geauxBuilder != null) registerInteractive(geauxBuilder.open);
		if (auraBuilder != null) registerInteractive(auraBuilder.open);
		if (notebook != null) registerInteractive(notebook.open);
		if (vitals != null) registerInteractive(vitals.open);
		if (geaux != null) registerInteractive(geaux.open);
		if (getRifty != null) registerInteractive(getRifty.open);
		if (combo != null) registerInteractive(combo.open);
		if (chaincast != null) registerInteractive(chaincast.open);
		if (conduit != null) registerInteractive(conduit.open);
		if (localTime != null) registerInteractive(localTime.open);
		if (target != null) registerInteractive(target.open);
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
		for (ref in interactiveOpenRefs) {
			if (ref != null)
				ref.set(false);
		}
		if (geauxBuilder != null)
			geauxBuilder.clearTransientState();
		if (auraBuilder != null)
			auraBuilder.clearTransientState();
		SettingsStore.markDirty();
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

		var hit = false;
		try
			hit = hxd.Key.isPressed(hxd.Key.F6)
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
			hitF12 = hxd.Key.isPressed(hxd.Key.F12)
		catch (_:Dynamic) {}
		if (!hitF12) {
			try
				hitF12 = ImGui.isKeyPressed(ImGuiKey.F12, false)
			catch (_:Dynamic) {}
		}
		if (hitF12) {
			solarflare.debug.DebugSystem.toggle();
		}
	}

	/** Hub, builders, or other editors that must block Farever menu shortcuts. */
	public function anyInteractiveOpen():Bool {
		if (solarflare.debug.DebugSystem.open.get())
			return true;
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
			var vis = ToolWindow.beginWithMenuBar("SolarFlare###SolarFlare.Hub", open,
				Math.max(720, hubW.get()), Math.max(820, hubH.get()), false, rememberHubLayout.get());
			if (vis) {
				var pos = ImGui.getWindowPos();
				var size = ImGui.getWindowSize();
				if (rememberHubLayout.get() && (pos.x != lastHubX || pos.y != lastHubY
					|| size.x != hubW.get() || size.y != hubH.get())) {
					lastHubX = pos.x;
					lastHubY = pos.y;
					hubW.set(size.x);
					hubH.set(size.y);
					SettingsStore.markDirty();
				}
				drawHubMenuBar();
				drawHubLogo();
				ImGui.separator();
				drawModuleTabs();
				ImGui.separator();
				HudChrome.safeChild("##hub_active_settings", ImGui.vec2(0, 0), 0, drawActiveModule,
					imgui.Enums.ImGuiChildFlags.Borders | imgui.Enums.ImGuiChildFlags.AutoResizeY | imgui.Enums.ImGuiChildFlags.AlwaysUseWindowPadding);
				ImGui.separator();
				if (ImGui.collapsingHeader("Show")) {
					if (ImGui.checkbox("Show Geaux##hub_geaux_on", geaux.enabled)) {
						if (geaux.enabled.get()) {
							geaux.sizeDirty = true;
							if (geaux.chrome != null)
								geaux.chrome.posDirty = true;
						}
						SettingsStore.markDirty();
					}
					if (lightsaber != null)
						visCheck("Show Lightsaber##hub_saber_show", lightsaber.hidden, showSaber);
					if (getRifty != null)
						visCheck("Show GetRifty##hub_rifty_show", getRifty.hidden, showGetRifty);
					if (auras != null && ImGui.checkbox("Show Auras##hub_aura_show", auras.enabled))
						SettingsStore.markDirty();
					if (launchers != null) {
						ImGui.separatorText("Launchers");
						visCheck("Show F6 MENU button##hub_f6b", launchers.f6.hidden, showF6Btn);
						if (ImGui.sliderFloat("MENU size##hub_f6s", launchers.f6.size, HudLaunchers.F6_MIN, HudLaunchers.F6_MAX, "%.0f")) {
							launchers.f6.sizeDirty = true;
							SettingsStore.markDirty();
						}
						launchers.f6.chrome.drawToggles("f6b");
						ImGui.textWrapped("Unlock MENU, then drag its sun icon to move; click the icon to collapse/expand. Resize from the bottom-right grip.");
					}
					ImGui.text(solarflare.geaux.GeauxBar.lastStatus);
					ImGui.text(solarflare.ui.GameIcons.statusLine());
				}

				if (ImGui.collapsingHeader("Workspace & Docking Layout")) {
					if (ImGui.checkbox("Remember F6 position and size##hub_remember", rememberHubLayout))
						SettingsStore.markDirty();
					ImGui.text('Layout Mode: ${solarflare.ui.DockingHelper.isWindowDocked() ? "Docked Tabbed Workspace" : "Floating Windows"}');
					ImGui.textWrapped("Drag tool windows onto each other or screen edges. Layout persists in imgui.ini.");
					if (ImGui.button("Save Layout Now##sf_save_dock", ImGui.vec2(130, 26)))
						UiActionQueue.save();
					ImGui.sameLine();
					if (ImGui.button("Reset Default Layout##sf_reset_dock", ImGui.vec2(150, 26)))
						UiActionQueue.enqueue(UiActionKind.ResetDockLayout);
				}

				if (ImGui.collapsingHeader("ImGui debug")) {
					ImGui.textWrapped("Font/style stacks are global with other HLX mods. Latin/Greek/Cyrillic is bundled.");
					ImGui.checkbox("Performance monitor##sf_perf", solarflare.ui.PerformanceMonitor.open);
					ImGui.checkbox("Metrics window##sf_metrics", dbgMetrics);
					ImGui.checkbox("Debug log window##sf_dbglog", dbgLog);
					ImGui.checkbox("Payload probe panel##sf_payload", solarflare.debug.PayloadProbe.enabled);
					ImGui.textWrapped("Opens panel only. Start/Stop recording inside the panel — session-only, not saved.");
					ImGui.checkbox("Resolution ledger panel##sf_ledger", solarflare.debug.ResolutionLedger.enabled);
					ImGui.textWrapped("Panel open is session-only (not saved). Recording never auto-starts. JSONL: hlx/mods/solarflare/logs/");
					if (solarflare.debug.FieldWalkLog.lastPath.length > 0)
						ImGui.text(solarflare.debug.FieldWalkLog.lastPath);
					if (ImGui.smallButton("Copy FieldWalk log path##sf_fwlog"))
						UiActionQueue.copyText(solarflare.debug.FieldWalkLog.lastPath, "FieldWalk path copied");
				}
			}
			ToolWindow.end();
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
		trackProfileWindowState();
		if (target != null) {
			try target.draw() catch (_:Dynamic) {}
		}
		try
			notebook.draw()
		catch (_:Dynamic) {}
		if (lightsaber != null) {
			try
				lightsaber.draw()
			catch (_:Dynamic) {}
		}
		if (getRifty != null) {
			try
				getRifty.draw()
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
			if (ImGui.menuItem("Resource Tracker"))
				resourceTracker.open.set(true);
			if (ImGui.menuItem("Notebook"))
				notebook.open.set(true);
			if (ImGui.menuItem("Lightsaber"))
				lightsaber.open.set(true);
			if (ImGui.menuItem("GetRifty"))
				getRifty.open.set(true);
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
		if (!CursorCaptureFix.cursorFree || !anyInteractiveOpen())
			return;
		try {
			var ctrl = ImGui.isKeyDown(ImGuiKey.LeftCtrl) || ImGui.isKeyDown(ImGuiKey.RightCtrl);
			if (ctrl && ImGui.isKeyPressed(ImGuiKey.S, false))
				UiActionQueue.save();
		} catch (_:Dynamic) {}
	}

	/** Close hub on Escape only — never letter keys (typing must not dismiss). */
	function pollHubDismissKeys():Void {
		if (!open.get() || !CursorCaptureFix.cursorFree)
			return;
		try {
			var typing = false;
			try
				typing = ImGui.isAnyItemActive()
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

		ImGui.setCursorPosX(startX);
	}

	/** Feature selection changes the option surface in-place; editors are secondary windows. */
	function drawModuleTabs():Void {
		var labels = ["Resources", "Geaux", "Attack Combo", "Auras", "Notebook", "Lightsaber", "Combat Log", "Theme"];
		var ids = [TAB_RESOURCES, TAB_GEAUX, TAB_ATTACK, TAB_AURAS, TAB_NOTEBOOK, TAB_LIGHTSABER, TAB_COMBAT_LOG, TAB_THEME];
		var available = ImGui.getContentRegionAvail().x;
		var used:Float = 0;
		for (i in 0...ids.length) {
			var width = Math.max(110, ImGui.calcTextSize(labels[i]).x + 28);
			if (used > 0 && used + 10 + width <= available) {
				ImGui.sameLine();
				used += 10;
			} else used = 0;
			if (moduleTab(labels[i], ids[i]) && ids[i] == TAB_NOTEBOOK) notebook.open.set(true);
			used += width;
		}
		drawGetRiftySunButton(used, available);
	}

	/** Sun icon after Theme — opens GetRifty settings only; does not unhide the overlay. */
	function drawGetRiftySunButton(used:Float, available:Float):Void {
		var side:Single = 38;
		if (used > 0 && used + 10 + side <= available)
			ImGui.sameLine(0, 10);
		var p = ImGui.getCursorScreenPos();
		var clicked = ImGui.invisibleButton("##hub_getrifty_sun", ImGui.vec2(side, side));
		var dl = ImGui.getWindowDrawList();
		var tex = GameIcons.get(GameIcons.RIFT_SUN);
		if (tex == 0)
			tex = GameIcons.get(GameIcons.CHROME_SUN);
		var tint = ImGui.isItemHovered()
			? ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 0.92, 0.55, 1))
			: ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.95, 0.82, 0.35, 1));
		if (tex == 0 || !GameIcons.draw(dl, tex, p.x + 3, p.y + 3, side - 6, tint)) {
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(p.x + side * 0.5, p.y + side * 0.5), side * 0.32, tint, 16);
		}
		if (ImGui.isItemHovered())
			ImGui.setTooltip("GetRifty settings (off until you enable Show)");
		if (clicked && getRifty != null)
			getRifty.open.set(true);
	}

	function moduleTab(label:String, id:Int):Bool {
		var selected = activeHubTab == id;
		var width:Single = Math.max(110, ImGui.calcTextSize(label).x + 28);
		var clicked = selected
			? UiChrome.accentButton(label + "##hub_tab_" + id, ImGui.vec2(width, 38))
			: UiChrome.ghostButton(label + "##hub_tab_" + id, ImGui.vec2(width, 38));
		if (clicked) {
			activeHubTab = id;
			SettingsStore.markDirty();
			return true;
		}
		return false;
	}

	function drawActiveModule():Void {
		switch (activeHubTab) {
			case TAB_GEAUX:
				FeatureProfiles.drawToolbar(this, "geaux", "hub_geaux");
				ImGui.textWrapped("Configure the shared Geaux grid in the Geaux Builder.");
				if (ImGui.checkbox("Show Geaux grid##tab_geaux_show", geaux.enabled)) {
					geaux.sizeDirty = true;
					if (geaux.chrome != null) geaux.chrome.posDirty = true;
					SettingsStore.markDirty();
				}
				if (geaux.chrome != null) geaux.chrome.drawToggles("tab_geaux");
				if (UiChrome.accentButton("Open Geaux Builder##tab_geaux_open", ImGui.vec2(-1, 40)))
					geauxBuilder.open.set(true);
			case TAB_ATTACK:
				ImGui.textWrapped("Weapon attack-chain overlay.");
				visCheck("Show Attack Combo##tab_attack_show", attackCombo.hidden, showAttack);
				if (UiChrome.accentButton("Open Attack Combo settings##tab_attack_open", ImGui.vec2(-1, 40)))
					resourceTracker.openFor("attack");
			case TAB_AURAS:
				FeatureProfiles.drawToolbar(this, "auras", "hub_auras");
				ImGui.textWrapped("Enable the aura system, then open the builder.");
				if (ImGui.checkbox("Enable aura system##tab_aura_show", auras.enabled))
					SettingsStore.markDirty();
				ImGui.text(Std.string(auras.auras.length) + " aura(s) configured");
				if (UiChrome.accentButton("Open Aura Builder##tab_aura_open", ImGui.vec2(-1, 40)))
					auraBuilder.open.set(true);
			case TAB_NOTEBOOK:
				ImGui.textWrapped("The Notebook opens when you select this tab. Pages auto-save while you type and are stored separately in notebook.json.");
			case TAB_LIGHTSABER:
				ImGui.textWrapped("Local combat-log DPS meter settings.");
				visCheck("Show Lightsaber##tab_saber_show", lightsaber.hidden, showSaber);
				if (UiChrome.accentButton("Lightsaber options##tab_saber_open", ImGui.vec2(-1, 40)))
					lightsaber.open.set(true);
			case TAB_COMBAT_LOG:
				ImGui.textWrapped("Skill casts and resolved combat events.");
				combatLog.drawEditorContents();
			case TAB_THEME:
				ThemePalette.drawThemeEditorPane();
			default:
				FeatureProfiles.drawToolbar(this, "resources", "hub_resources");
				ImGui.textWrapped("Configure resources and class trackers in the Resource Tracker Builder.");
				resourceQuickRow("Target Frame", "target", target.hidden, target.chrome);

				if (UiChrome.accentButton("Open Resource Tracker Builder##tab_rt_open", ImGui.vec2(-1, 40)))
					resourceTracker.open.set(true);
		}
	}

	public function profileUiTab():Int return activeHubTab;
	public function applyProfileUiTab(value:Int):Void {
		if (value >= TAB_RESOURCES && value <= TAB_THEME)
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

	function resourceQuickRow(label:String, id:String, hidden:BoolRef, chrome:HudChrome):Void {
		ImGui.spacing();
		UiChrome.subHeader(label);
		if (ImGui.checkbox("Hide##hub_rt_hide_" + id, hidden)) SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.checkbox("Lock##hub_rt_lock_" + id, chrome.locked)) SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.checkbox("Transparent##hub_rt_trans_" + id, chrome.transparent)) SettingsStore.markDirty();
		if (ImGui.button("Settings##hub_rt_settings_" + id, ImGui.vec2(-1, 0)))
			resourceTracker.openFor(StringTools.startsWith(id, "tab_") ? id.substr(4) : id);
		ImGui.separator();
	}

	static function bytesToString(bytes:hl.Bytes, cap:Int):String {
		return ByteUtil.readBytes(bytes, cap);
	}

	static function clearBytes(bytes:hl.Bytes, cap:Int):Void ByteUtil.clearBytes(bytes, cap);
}
