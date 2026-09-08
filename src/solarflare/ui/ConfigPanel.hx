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
 * F6 hub for SolarFlare: Auras, Geaux, Resource Tracker, Notebook, Lightsaber.
 * GetRifty / Local Time / Combat Log remain as hidden settings fields for persistence
 * and Lightsaber observation; they are not hub entries.
 */
class ConfigPanel {
	static inline var HUB_LOGO:String = GameIcons.HUB_LOGO;
	static inline var HUB_LOGO_MAX_W:Single = 280;
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

	public var dbgMetrics:BoolRef;
	public var dbgLog:BoolRef;

	var showSaber:BoolRef;
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
		hubW = new FloatRef(360);
		hubH = new FloatRef(420);
		dbgMetrics = new BoolRef(false);
		dbgLog = new BoolRef(false);
		showSaber = new BoolRef(false);
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
		if (combatLog != null) registerInteractive(combatLog.open);
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
			ImGui.setNextWindowSizeConstraints(ImGui.vec2(280, 200), ImGui.vec2(1920, 1200));
			var vis = ToolWindow.beginWithMenuBar("SolarFlare###SolarFlare.Hub", open, hubW.get(), hubH.get());
			if (vis) {
				drawHubMenuBar();
				drawHubLogo();
				ImGui.separator();
				drawModuleTabs();
				ImGui.separator();
				drawActiveModule();
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
					if (auras != null && ImGui.checkbox("Show Auras##hub_aura_show", auras.enabled))
						SettingsStore.markDirty();
					if (vitals != null) {
						ImGui.separatorText("Resources");
						resourceQuickRow("Health", "health", vitals.hpHidden, vitals.chrome);
						resourceQuickRow("Rage", "rage", vitals.rageHidden, vitals.rageChrome);
						resourceQuickRow("Mana/Spark", "mana", vitals.manaHidden, vitals.manaChrome);
						resourceQuickRow("Prayers", "prayers", vitals.prayersHidden, vitals.prayersChrome);
						resourceQuickRow("Combo Points", "combo", combo.hidden, combo.chrome);
						resourceQuickRow("Attack Combo", "attack", attackCombo.hidden, attackCombo.chrome);
						resourceQuickRow("Current Target", "target", target.hidden, target.chrome);
						resourceQuickRow("Chaincast", "chaincast", chaincast.hidden, chaincast.chrome);
						resourceQuickRow("Conduits", "conduit", conduit.hidden, conduit.chrome);
					}
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
					ImGui.checkbox("Payload probe##sf_payload", solarflare.debug.PayloadProbe.enabled);
					ImGui.textWrapped("Session only (not saved). Hit/cast/chat payloads + GameApp spine.");
					if (ImGui.checkbox("Resolution ledger##sf_ledger", solarflare.debug.ResolutionLedger.enabled))
						SettingsStore.markDirty();
					ImGui.textWrapped("Saved in solarflare.json. JSONL: hlx/mods/solarflare/logs/resolution-ledger.jsonl");
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
		if (combatLog != null) {
			try combatLog.draw() catch (_:Dynamic) {}
		}
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
		drawHubLogoBackdrop(dl, p.x, p.y, w, h);
		if (!GameIcons.imageKeyUv(HUB_LOGO, w, h, HUB_LOGO_U0, HUB_LOGO_V0, HUB_LOGO_U1, HUB_LOGO_V1))
			ImGui.dummy(ImGui.vec2(w, h));
		drawHubFlareLine(dl, p.x, p.y, w, h);
		ImGui.setCursorPosX(startX);
	}

	/** Soft sun glow behind the wordmark — sits under "SOLAR", pulses gently. */
	static function drawHubLogoBackdrop(dl:Dynamic, x:Single, y:Single, w:Single, h:Single):Void {
		var t = ImGui.getTime();
		var pulse = 0.55 + 0.45 * Math.sin(t * 1.65);
		var cx:Single = x + w * 0.30;
		var cy:Single = y + h * 0.42;
		var r:Single = h * 0.58;
		var aOuter = Std.int((0.10 + 0.10 * pulse) * 255);
		var aMid = Std.int((0.16 + 0.14 * pulse) * 255);
		var aCore = Std.int((0.22 + 0.18 * pulse) * 255);
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), r * 1.15, UiCol.rgb(0xFFA028, aOuter), 32);
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), r * 0.82, UiCol.rgb(0xFFC040, aMid), 28);
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), r * 0.48, UiCol.rgb(0xFFE060, aCore), 24);
		// Ray accents
		var rayA = Std.int((0.18 + 0.22 * pulse) * 255);
		var rayCol = UiCol.rgb(0xFFD040, rayA);
		var i = 0;
		while (i < 10) {
			var ang = i * Math.PI / 5 + t * 0.15;
			var c = Math.cos(ang);
			var s = Math.sin(ang);
			ImGui.ImDrawList_AddLine(dl,
				ImGui.vec2(cx + c * r * 0.42, cy + s * r * 0.42),
				ImGui.vec2(cx + c * r * 1.05, cy + s * r * 1.05),
				rayCol, 1.6);
			i++;
		}
	}

	/** Faint solar-flare underline under the wordmark — mirrors the logo stroke with a live pulse. */
	static function drawHubFlareLine(dl:Dynamic, x:Single, y:Single, w:Single, h:Single):Void {
		var t = ImGui.getTime();
		var y0:Single = y + h * 0.78;
		var x0:Single = x + w * 0.18;
		var x1:Single = x + w * 0.94;
		var amp:Single = h * 0.045;
		var pulse = 0.45 + 0.55 * (0.5 + 0.5 * Math.sin(t * 2.4));
		var a = Std.int((0.25 + 0.45 * pulse) * 255);
		var col = UiCol.rgb(0xFF8C20, a);
		var colHot = UiCol.rgb(0xFFC040, Std.int(a * 0.7));
		var prevX:Single = x0;
		var prevY:Single = y0;
		var segs = 28;
		var i = 1;
		while (i <= segs) {
			var u = i / segs;
			var px:Single = x0 + (x1 - x0) * u;
			var wave = Math.sin(u * Math.PI * 2.2 + t * 3.1) * amp
				+ Math.sin(u * Math.PI * 5.0 - t * 2.0) * amp * 0.35;
			var py:Single = y0 + wave;
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(prevX, prevY), ImGui.vec2(px, py), col, 2.2);
			if (i % 3 == 0)
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(prevX, prevY + 1.5), ImGui.vec2(px, py + 1.5), colHot, 1.1);
			prevX = px;
			prevY = py;
			i++;
		}
	}

	/** Feature selection changes the option surface in-place; editors are secondary windows. */
	function drawModuleTabs():Void {
		moduleTab("Resources", TAB_RESOURCES);
		ImGui.sameLine();
		moduleTab("Geaux", TAB_GEAUX);
		ImGui.sameLine();
		moduleTab("Attack Combo", TAB_ATTACK);
		ImGui.sameLine();
		moduleTab("Auras", TAB_AURAS);
		if (moduleTab("Notebook", TAB_NOTEBOOK))
			notebook.open.set(true);
		ImGui.sameLine();
		moduleTab("Lightsaber", TAB_LIGHTSABER);
		ImGui.sameLine();
		moduleTab("Combat Log", TAB_COMBAT_LOG);
		ImGui.sameLine();
		moduleTab("Theme", TAB_THEME);
	}

	function moduleTab(label:String, id:Int):Bool {
		var shown = activeHubTab == id ? "[" + label + "]" : label;
		if (ImGui.button(shown + "##hub_tab_" + id)) {
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
				if (UiChrome.accentButton("Open Geaux Builder##tab_geaux_open", ImGui.vec2(-1, 36)))
					geauxBuilder.open.set(true);
			case TAB_ATTACK:
				ImGui.textWrapped("Weapon attack-chain overlay.");
				visCheck("Show Attack Combo##tab_attack_show", attackCombo.hidden, showAttack);
				if (ImGui.button("Open Attack Combo settings##tab_attack_open", ImGui.vec2(-1, 0)))
					resourceTracker.openFor("attack");
			case TAB_AURAS:
				FeatureProfiles.drawToolbar(this, "auras", "hub_auras");
				ImGui.textWrapped("Enable the aura system, then open the builder.");
				if (ImGui.checkbox("Enable aura system##tab_aura_show", auras.enabled))
					SettingsStore.markDirty();
				ImGui.text(Std.string(auras.auras.length) + " aura(s) configured");
				if (UiChrome.accentButton("Open Aura Builder##tab_aura_open", ImGui.vec2(-1, 36)))
					auraBuilder.open.set(true);
			case TAB_NOTEBOOK:
				ImGui.textWrapped("The Notebook opens when you select this tab. Pages auto-save while you type and are stored separately in notebook.json.");
			case TAB_LIGHTSABER:
				ImGui.textWrapped("Local combat-log DPS meter settings.");
				visCheck("Show Lightsaber##tab_saber_show", lightsaber.hidden, showSaber);
				if (ImGui.button("Lightsaber options##tab_saber_open", ImGui.vec2(-1, 0)))
					lightsaber.open.set(true);
			case TAB_COMBAT_LOG:
				ImGui.textWrapped("Skill casts and resolved combat events.");
				if (ImGui.button("Combat Log options##tab_log_open", ImGui.vec2(-1, 0)))
					combatLog.open.set(true);
				ImGui.separatorText("Current Target");
				ImGui.textWrapped("Live target name and HP bar from the same observe path.");
				visCheck("Show Current Target##tab_tgt_show", target.hidden, showTarget);
				if (ImGui.button("Current Target options##tab_tgt_open", ImGui.vec2(-1, 0)))
					target.open.set(true);
			case TAB_THEME:
				ThemePalette.drawThemeEditorPane();
			default:
				FeatureProfiles.drawToolbar(this, "resources", "hub_resources");
				ImGui.textWrapped("Resource windows are independent; configure each one without leaving F6.");
				resourceQuickRow("Health", "tab_health", vitals.hpHidden, vitals.chrome);
				resourceQuickRow("Rage", "tab_rage", vitals.rageHidden, vitals.rageChrome);
				resourceQuickRow("Mana/Spark", "tab_mana", vitals.manaHidden, vitals.manaChrome);
				resourceQuickRow("Prayers", "tab_prayers", vitals.prayersHidden, vitals.prayersChrome);
				if (ImGui.button("Open Resource Tracker Builder##tab_rt_open", ImGui.vec2(-1, 0)))
					resourceTracker.open.set(true);
		}
	}

	public function profileUiTab():Int return activeHubTab;
	public function applyProfileUiTab(value:Int):Void {
		if (value >= TAB_RESOURCES && value <= TAB_THEME) activeHubTab = value;
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
		ImGui.text(label);
		if (ImGui.checkbox("Hide##hub_rt_hide_" + id, hidden)) SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.checkbox("Lock##hub_rt_lock_" + id, chrome.locked)) SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.checkbox("Transparent##hub_rt_trans_" + id, chrome.transparent)) SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.smallButton("Settings##hub_rt_settings_" + id)) resourceTracker.openFor(id);
	}

	static function bytesToString(bytes:hl.Bytes, cap:Int):String {
		return ByteUtil.readBytes(bytes, cap);
	}

	static function clearBytes(bytes:hl.Bytes, cap:Int):Void ByteUtil.clearBytes(bytes, cap);
}
