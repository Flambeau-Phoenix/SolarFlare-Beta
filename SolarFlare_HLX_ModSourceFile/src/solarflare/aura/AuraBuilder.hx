package solarflare.aura;

import solarflare.aura.signal.AuraConditionEditor;
import solarflare.aura.signal.AuraSignalCatalog;
import solarflare.cdb.CdbAuraTable;
import solarflare.geaux.GeauxCache;
import solarflare.ui.HudChrome;
import solarflare.ui.ToolWindow;
import solarflare.ui.UiChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.ByteUtil;
import solarflare.ui.GameIcons;
import solarflare.ui.ConfigPanel;
import solarflare.ui.FeatureProfiles;
import solarflare.ui.SearchBar;
import solarflare.ui.ToastManager;
import solarflare.ui.UndoManager;
import solarflare.ui.DragDropHelper;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.UiActionQueue;
import solarflare.ui.UiActionQueue.UiActionKind;
import solarflare.ui.ContextMenuSystem;
import imgui.ImGui;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiKey;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import haxe.Json;

/** Focused three-step editor for the AuraDef objects owned by AuraConfig. */
class AuraBuilder {
	public var open = new BoolRef(false);
	var cfg:AuraConfig;
	var host:ConfigPanel;
	var selected:Int = -1;
	var deleteArmed:Int = -1;
	/** Managed multi-select by stable Aura id (demo pattern). */
	var selectedIds:Map<String, Bool> = new Map();
	var rangeAnchorId:String = "";

	var undoManager = new UndoManager<String>(40);
	var auraSearch = new SearchBar("Filter auras by name, signal, or target...", 128);

	var previewProgress = new FloatRef(0.65);
	var previewCount = new IntRef(3);
	/** UI percentages are 0–100 while the Aura model retains 0–1 fractions. */
	var previewPercent = new FloatRef(65);
	var opacityPercent = new FloatRef(100);
	var volumePercent = new FloatRef(100);
	var search:String = "";
	var scopeFilter:String = "All";
	var iconSearchBuf = new hl.Bytes(80);
	var iconSearch:String = "";

	var visualBuilder = new solarflare.aura.signal.VisualConditionBuilder();
	var testHarness = new solarflare.aura.test.AuraTestHarness();
	var advancedPreview = new solarflare.aura.preview.AdvancedAuraPreview();
	var centerTab:Int = 0;
	var mainTab:Int = 0;
	var looksTab:Int = 0;
	var logicSubTab:Int = 0;

	static inline var JSON_BUF:Int = 32768;
	var exportBuf = new hl.Bytes(JSON_BUF);
	var importBuf = new hl.Bytes(JSON_BUF);
	var exportString:String = "";
	var ioStatus:String = "";
	var ioStatusError:Bool = false;

	public function new(cfg:AuraConfig, host:ConfigPanel) {
		this.cfg = cfg;
		this.host = host;
		solarflare.ui.ByteUtil.clearBytes(iconSearchBuf, 80);
		solarflare.ui.ByteUtil.clearBytes(exportBuf, JSON_BUF);
		solarflare.ui.ByteUtil.clearBytes(importBuf, JSON_BUF);
	}

	function snapshot(actionName:String):Void {
		if (cfg == null) return;
		try {
			var state = Json.stringify(AuraPack.toObj("shared", "snapshot", "undo", cfg.auras));
			undoManager.push(actionName, state);
		} catch (_:Dynamic) {}
	}

	function restoreSnapshot(jsonStr:String):Void {
		try {
			var imported = AuraPack.unpackAuras(AuraPack.decode(jsonStr));
			cfg.auras = imported;
			selected = cfg.auras.length > 0 ? 0 : -1;
			deleteArmed = -1;
			SettingsStore.markDirty();
		} catch (_:Dynamic) {}
	}

	public function clearTransientState():Void {
		selected = -1;
		deleteArmed = -1;
		selectedIds = new Map();
		rangeAnchorId = "";
	}

	public function importFromClipboardQueued():Void {
		try {
			var clipBytes = ImGui.getClipboardText();
			var clip = clipBytes != null ? ByteUtil.readString(clipBytes, JSON_BUF, true) : null;
			if (clip == null || clip.length < 2) {
				ToastManager.error("Clipboard contains no valid JSON.");
				return;
			}
			ByteUtil.fillBuf(importBuf, JSON_BUF, clip);
			applyImportBuffer();
		} catch (e:Dynamic) {
			ToastManager.error("Import failed: " + e);
		}
	}

	function applyImportBuffer():Void {
		importJson();
	}

	public function exportPackQueued():Void {
		if (cfg == null)
			return;
		try {
			var json = Json.stringify(AuraPack.toObj("shared", "export", "pack", cfg.auras), null, "  ");
			ImGui.setClipboardText(json);
			ToastManager.success(cfg.auras.length + " Auras copied to clipboard!");
		} catch (e:Dynamic) {
			ToastManager.error("Export failed: " + e);
		}
	}

	public function draw():Void {
		if (!open.get() || cfg == null)
			return;
		if (!CursorCaptureFix.cursorFree)
			return;

		var vis = ToolWindow.begin("Aura Builder###SolarFlare.AuraBuilder", open, 1480, 920, 0, false);
		if (vis) {
			drawTopToolbar();
			drawStatusBanner();
			drawBatchToolbar();
			ImGui.separator();

			var avail = ImGui.getContentRegionAvail();
			var leftW:Single = 260;
			var paneH:Single = avail.y - 4;
			if (paneH < 360) paneH = 360;

			solarflare.ui.UiChrome.celChild("##ab_list", ImGui.vec2(leftW, paneH), drawLeftPane);
			ImGui.sameLine();
			solarflare.ui.UiChrome.celChild("##ab_main", ImGui.vec2(0, paneH), drawMainPane);
		}
		ToolWindow.end();
	}

	function drawTopToolbar():Void {
		if (ImGui.checkbox("Enable Aura System##ab_system_enable", cfg.enabled)) {
			SettingsStore.markDirty();
			ToastManager.info(cfg.enabled.get() ? "Aura system enabled" : "Aura system suspended");
		}

		ImGui.sameLine();
		FeatureProfiles.drawToolbar(host, "auras", "aura_builder");

		ImGui.sameLine();
		var currentJson = try Json.stringify(AuraPack.toObj("shared", "current", "undo", cfg.auras)) catch (_) "";
		undoManager.drawButtons(currentJson, restoreSnapshot);

		ImGui.sameLine(0, 16);
		if (UiChrome.accentButton("Test My Aura##ab_test_top")) {
			mainTab = 0;
			logicSubTab = 2;
			ToastManager.info("Open Test Station below — simulate trigger values.");
		}
		ImGui.sameLine();
		if (UiChrome.accentButton("Save##ab_save_top"))
			UiActionQueue.save();
	}

	function drawMainPane():Void {
		var a = selectedAura();
		if (a == null) {
			solarflare.ui.UiChrome.sectionHeader("Get Started");
			ImGui.textWrapped("Pick an aura from the list, or create one from a template. Then set When It Shows — How It Looks comes last.");
			return;
		}

		drawWindowToggles(a, "quick");
		// Step flow: conditions first, appearance as the final stage.
		ImGui.pushStyleVar(imgui.Enums.ImGuiStyleVar.FrameRounding, 12);
		if (mainTab == 0) {
			if (UiChrome.accentButton("1 · When It Shows##ab_step_logic", ImGui.vec2(200, 30)))
				mainTab = 0;
			ImGui.sameLine();
			if (UiChrome.ghostButton("2 · How It Looks##ab_step_looks", ImGui.vec2(200, 30)))
				mainTab = 1;
		} else {
			if (UiChrome.ghostButton("1 · When It Shows##ab_step_logic", ImGui.vec2(200, 30)))
				mainTab = 0;
			ImGui.sameLine();
			if (UiChrome.accentButton("2 · How It Looks##ab_step_looks", ImGui.vec2(200, 30)))
				mainTab = 1;
		}
		ImGui.popStyleVar();
		ImGui.separator();

		if (mainTab == 0)
			drawLogicTab(a);
		else
			drawLooksTab(a);
	}

	function drawLogicTab(a:AuraDef):Void {
		solarflare.ui.UiChrome.sectionHeader("When It Shows");
		drawAuraDetails();
		var issue = setupIssue(a);
		if (issue.length > 0)
			ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "Next: " + issue);

		if (ImGui.beginTabBar("##ab_logic_sub")) {
			if (ImGui.beginTabItem("Conditions##ab_ls_cond")) {
				logicSubTab = 0;
				AuraConditionEditor.draw(a);
				ImGui.endTabItem();
			}
			if (ImGui.beginTabItem("Node Graph##ab_ls_nodes")) {
				if (logicSubTab != 1 && a.rule != null)
					visualBuilder.syncFromRule(a.rule);
				logicSubTab = 1;
				if (a.rule != null && visualBuilder.draw(a.rule))
					SettingsStore.markDirty();
				ImGui.endTabItem();
			}
			if (ImGui.beginTabItem("Test##ab_ls_test")) {
				logicSubTab = 2;
				testHarness.draw(a);
				ImGui.endTabItem();
			}
			ImGui.endTabBar();
		}

		ImGui.spacing();
		ImGui.separator();
		ImGui.spacing();
		solarflare.ui.UiChrome.premiumHeader("Ready for Appearance?");
		ImGui.textWrapped("After your conditions are set, open How It Looks to style the aura window.");
		if (UiChrome.accentButton("Continue to How It Looks →##ab_to_looks", ImGui.vec2(-1, 40))) {
			mainTab = 1;
			ToastManager.info("Style your aura — preview updates live.");
		}
	}

	function drawLooksTab(a:AuraDef):Void {
		solarflare.ui.UiChrome.sectionHeader("How It Looks");
		ImGui.textDisabled("Final step — preview updates as you change settings.");
		if (UiChrome.ghostButton("← Back to Conditions##ab_back_logic"))
			mainTab = 0;
		ImGui.separator();
		var prevW = ImGui.getContentRegionAvail().x;
		advancedPreview.draw(a, prevW, 150);
		ImGui.separator();

		var sections = ["Appearance", "Window & Size", "Behavior", "Effects", "Share"];
		for (i in 0...sections.length) {
			if (i > 0) ImGui.sameLine();
			if (ImGui.selectable(sections[i] + "##ab_section_" + i, looksTab == i, 0, ImGui.vec2(125, 28))) looksTab = i;
		}
		ImGui.separator();
		switch (looksTab) {
			case 0: drawAppearance(a);
			case 1: drawWindowLayout(a);
			case 2: drawBehavior(a); drawDrmSound(a, false);
			case 3: cfg.drawEffects(a, false);
			case 4: drawShare(a);
		}

	}

	function drawBatchToolbar():Void {
		var n = countSelected();
		if (n <= 0)
			return;
		ImGui.text('Selected: $n');
		ImGui.sameLine();
		if (ImGui.smallButton("Enable##ab_batch_en")) {
			snapshot("Batch Enable");
			forEachSelected(a -> a.enabled.set(true));
			SettingsStore.markDirty();
			ToastManager.info("Enabled " + n + " aura(s)");
		}
		ImGui.sameLine();
		if (ImGui.smallButton("Disable##ab_batch_dis")) {
			snapshot("Batch Disable");
			forEachSelected(a -> a.enabled.set(false));
			SettingsStore.markDirty();
			ToastManager.info("Disabled " + n + " aura(s)");
		}
		ImGui.sameLine();
		if (ImGui.smallButton("Export##ab_batch_exp")) {
			var pack:Array<AuraDef> = [];
			forEachSelected(a -> pack.push(a));
			var json = try Json.stringify(AuraPack.toObj("shared", "selection", "export", pack), null, "  ") catch (_) "";
			if (json.length > 0)
				UiActionQueue.enqueue(UiActionKind.ExportAuraSelection(json, n + " aura(s) exported"));
		}
		ImGui.sameLine();
		if (ImGui.smallButton("Clear Selection##ab_batch_clr")) {
			selectedIds = new Map();
			rangeAnchorId = "";
		}
		if (ImGui.isKeyPressed(ImGuiKey.Escape, false)) {
			selectedIds = new Map();
			rangeAnchorId = "";
		}
	}

	function countSelected():Int {
		var n = 0;
		for (_ in selectedIds.keys())
			n++;
		return n;
	}

	function forEachSelected(fn:AuraDef->Void):Void {
		if (cfg == null)
			return;
		for (a in cfg.auras) {
			if (a != null && selectedIds.exists(a.id))
				fn(a);
		}
	}

	function isAuraSelected(id:String):Bool {
		return selectedIds.exists(id);
	}

	function applyManagedSelect(clickedId:String, visibleIds:Array<String>):Void {
		var isShift = ImGui.isKeyDown(ImGuiKey.LeftShift) || ImGui.isKeyDown(ImGuiKey.RightShift);
		var isCtrl = ImGui.isKeyDown(ImGuiKey.LeftCtrl) || ImGui.isKeyDown(ImGuiKey.RightCtrl);
		if (isShift && rangeAnchorId.length > 0) {
			var start = visibleIds.indexOf(rangeAnchorId);
			var end = visibleIds.indexOf(clickedId);
			if (start < 0) start = end;
			if (end < 0) end = start;
			if (start > end) {
				var t = start;
				start = end;
				end = t;
			}
			if (!isCtrl)
				selectedIds = new Map();
			for (k in start...end + 1) {
				if (k >= 0 && k < visibleIds.length)
					selectedIds.set(visibleIds[k], true);
			}
		} else if (isCtrl) {
			if (selectedIds.exists(clickedId))
				selectedIds.remove(clickedId);
			else
				selectedIds.set(clickedId, true);
			rangeAnchorId = clickedId;
		} else {
			selectedIds = new Map();
			selectedIds.set(clickedId, true);
			rangeAnchorId = clickedId;
		}
	}

	function drawStatusBanner():Void {
		if (selected < 0 || selected >= cfg.auras.length) {
			ImGui.textColored(ImGui.vec4(0.45, 0.78, 1, 1), "Start by creating an Aura or choosing a template.");
			return;
		}
		var a = cfg.auras[selected];
		if (!cfg.enabled.get())
			ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "SYSTEM DISABLED · You can keep editing, but no Auras will appear.");
		else if (!a.enabled.get())
			ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "DISABLED · " + a.name + " will not appear until enabled.");
		else {
			var issue = setupIssue(a);
			if (issue.length > 0)
				ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "NEEDS SETUP · " + issue);
			else
				ImGui.textColored(ImGui.vec4(0.35, 0.9, 0.5, 1), "READY · " + a.name);
		}
	}

	function drawLeftPane():Void {
		solarflare.ui.UiChrome.sectionHeader("Auras");
		ImGui.textDisabled(Std.string(cfg.auras.length) + " / " + AuraEngine.MAX);

		var atCap = cfg.auras.length >= AuraEngine.MAX;
		if (atCap) ImGui.beginDisabled();
		if (UiChrome.accentButton("+ New Aura##ab_add", ImGui.vec2(-1, 32))) {
			snapshot("Create Aura");
			addBlankAura();
			ToastManager.success("New aura created!");
		}
		if (atCap) ImGui.endDisabled();

		if (atCap) ImGui.beginDisabled();
		if (ImGui.beginCombo("##ab_templates", "Starter template...")) {
			if (ImGui.selectable("Emergency Low Health", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createEmergencyLowHpAlert()); ToastManager.success("Template: Low Health"); }
			if (ImGui.selectable("Skill Cooldown Ready", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createSkillReadyAlert()); ToastManager.success("Template: Skill Ready"); }
			if (ImGui.selectable("Buff / Debuff Stacks", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createBuffStackTracker()); ToastManager.success("Template: Stack Tracker"); }
			if (ImGui.selectable("Max Combo Finisher", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createMaxComboFinisher()); ToastManager.success("Template: Combo Finisher"); }
			if (ImGui.selectable("Boss / Run Counter", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createBossKillCounter()); ToastManager.success("Template: Boss Counter"); }
			if (ImGui.selectable("Heavy Damage Warning", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createDamageTakenSpike()); ToastManager.success("Template: Damage Warning"); }
			ImGui.endCombo();
		}
		if (atCap) ImGui.endDisabled();

		search = auraSearch.draw("##ab_search");
		if (ImGui.beginCombo("Filter##ab_scope", scopeFilter)) {
			for (filter in ["All", "Shared", "Encounter-specific", "Needs setup"])
				if (ImGui.selectable(filter + "##ab_scope_" + filter, scopeFilter == filter))
					scopeFilter = filter;
			ImGui.endCombo();
		}

		ImGui.separator();
		HudChrome.safeChild("##ab_list_child", ImGui.vec2(0, 0), 0, drawAuraList);
	}

	function drawAuraList():Void {
		var visibleIds:Array<String> = [];
		var visibleIndices:Array<Int> = [];
		for (i in 0...cfg.auras.length) {
			var a = cfg.auras[i];
			if (a == null || !matchesFilter(a))
				continue;
			visibleIds.push(a.id);
			visibleIndices.push(i);
		}
		for (vi in 0...visibleIndices.length) {
			var i = visibleIndices[vi];
			var a = cfg.auras[i];
			if (a == null) continue;
			ImGui.pushID_Str(a.id);
			try {

			// Eye toggle
			var eyeLabel = a.enabled.get() ? "O##ab_eye" : "-##ab_eye";
			if (ImGui.smallButton(eyeLabel)) {
				a.enabled.set(!a.enabled.get());
				SettingsStore.markDirty();
			}
			ImGui.sameLine();

			var state = setupIssue(a).length > 0 ? " SETUP" : "";
			var displayName = a.name.length > 0 ? a.name : a.id;
			var rowSelected = isAuraSelected(a.id) || selected == i;
			if (ImGui.selectable(displayName + state + "##ab_item", rowSelected)) {
				applyManagedSelect(a.id, visibleIds);
				selected = i;
				deleteArmed = -1;
			}
			if (ImGui.isItemClicked(1)) {
				selected = i;
				selectedIds = new Map();
				selectedIds.set(a.id, true);
				rangeAnchorId = a.id;
				deleteArmed = -1;
				ImGui.openPopup("ab_ctx_pop_" + a.id);
			}
			drawAuraItemContextMenu(i, a);

			if (DragDropHelper.beginAuraDrag(i, displayName))
				DragDropHelper.endAuraDrag();
			var droppedIdx = DragDropHelper.acceptAuraDrop(i);
			if (droppedIdx >= 0 && droppedIdx < cfg.auras.length && droppedIdx != i) {
				snapshot("Reorder Aura");
				var moved = cfg.auras.splice(droppedIdx, 1)[0];
				cfg.auras.insert(i, moved);
				selected = i;
				if (moved != null) {
					selectedIds = new Map();
					selectedIds.set(moved.id, true);
					rangeAnchorId = moved.id;
				}
				SettingsStore.markDirty();
			}
			} catch (e:Dynamic) {
				ImGui.popID();
				throw e;
			}
			ImGui.popID();
		}
		if (visibleIndices.length == 0)
			ImGui.textDisabled("No auras match.");
	}

	function drawAuraItemContextMenu(index:Int, a:AuraDef):Void {
		if (ImGui.beginPopup("ab_ctx_pop_" + a.id) || ImGui.beginPopupContextItem("##ab_ctx_" + a.id, 1)) {
			try {
			ImGui.separatorText('${a.name}');
			if (ImGui.menuItem(a.enabled.get() ? "Disable Aura" : "Enable Aura")) {
				a.enabled.set(!a.enabled.get());
				SettingsStore.markDirty();
				ToastManager.info(a.enabled.get() ? '${a.name} enabled' : '${a.name} disabled');
			}
			if (ImGui.menuItem("Duplicate Aura")) {
				snapshot("Duplicate Aura");
				var copy = AuraConfig.cloneAura(a, uniqueAuraId(a.id + "_copy"), a.name + " Copy");
				if (copy != null && cfg.auras.length < AuraEngine.MAX) {
					cfg.auras.push(copy);
					selected = cfg.auras.length - 1;
					SettingsStore.markDirty();
					ToastManager.success('Duplicated: ${a.name}');
				}
			}
			if (ImGui.menuItem("Copy Aura JSON")) {
				var json = Json.stringify(AuraEngine.toObj(a), null, "  ");
				UiActionQueue.copyText(json, 'Copied JSON for ${a.name}');
			}
			if (a.isCounter.get() && ImGui.menuItem("Reset Counter")) {
				a.counterValue = 0;
				a.stacks = 1;
				SettingsStore.markDirty();
				ToastManager.info('Counter reset for ${a.name}');
			}
			ImGui.separator();
			if (ImGui.menuItem("Delete Aura")) {
				snapshot('Delete ${a.name}');
				cfg.auras.splice(index, 1);
				selected = cfg.auras.length > 0 ? Std.int(Math.min(index, cfg.auras.length - 1)) : -1;
				SettingsStore.markDirty();
				ToastManager.info('Deleted ${a.name}');
			}
			} catch (e:Dynamic) {
				ImGui.endPopup();
				throw e;
			}
			ImGui.endPopup();
		}
	}

	function drawCenterPane():Void {
		ImGui.separatorText("2. Choose When It Appears");
		var a = selectedAura();
		if (a == null) {
			ImGui.textWrapped("Select an Aura from the library, or create one to begin.");
			return;
		}

		HudChrome.safeChild("##ab_details_card", ImGui.vec2(0, 0), 0, drawAuraDetails,
			ImGuiChildFlags.Borders | ImGuiChildFlags.AutoResizeY | ImGuiChildFlags.AlwaysUseWindowPadding);

		var issue = setupIssue(a);
		if (issue.length > 0)
			ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "Next: " + issue);
		ImGui.spacing();

		// Center pane tabs
		if (ImGui.beginTabBar("##ab_center_tabs")) {
			if (ImGui.beginTabItem("Conditions##ab_tab_cond")) {
				centerTab = 0;
				AuraConditionEditor.draw(a);
				ImGui.endTabItem();
			}
			if (ImGui.beginTabItem("Visual Nodes##ab_tab_nodes")) {
				if (centerTab != 1 && a.rule != null)
					visualBuilder.syncFromRule(a.rule);
				centerTab = 1;
				if (a.rule != null && visualBuilder.draw(a.rule))
					SettingsStore.markDirty();
				ImGui.endTabItem();
			}
			if (ImGui.beginTabItem("Test Station##ab_tab_test")) {
				centerTab = 2;
				testHarness.draw(a);
				ImGui.endTabItem();
			}
			ImGui.endTabBar();
		}
	}

	function drawAuraDetails():Void {
		var a = selectedAura();
		if (a == null) return;
		ImGui.text("Aura Details");
		if (ImGui.inputText("Aura Name##ab_ed_name", a.nameBuf, AuraDef.NAME_BUF)) {
			a.name = readBytes(a.nameBuf, AuraDef.NAME_BUF);
			SettingsStore.markDirty();
		}
		var scope = isShared(a) ? "Shared / any encounter" : a.fight;
		if (ImGui.beginCombo("Use In##ab_ed_scope", scope)) {
			if (ImGui.selectable("Shared / any encounter##ab_scope_shared", isShared(a))) {
				a.fight = ""; a.syncFightBuf(); SettingsStore.markDirty();
			}
			for (fight in AuraPack.FIGHTS) {
				if (fight == "shared") continue;
				if (ImGui.selectable(fight + "##ab_fight_" + fight, a.fight == fight)) {
					a.fight = fight; a.syncFightBuf(); SettingsStore.markDirty();
				}
			}
			ImGui.endCombo();
		}
		if (ImGui.collapsingHeader("Custom encounter tag##ab_custom_scope")) {
			if (ImGui.inputText("Tag##ab_ed_fight", a.fightBuf, AuraDef.FIGHT_BUF)) {
				a.fight = readBytes(a.fightBuf, AuraDef.FIGHT_BUF);
				SettingsStore.markDirty();
			}
		}
	}

	function drawRightPane():Void {
		ImGui.separatorText("3. Choose What It Shows");
		var a = selectedAura();
		if (a == null) {
			ImGui.textWrapped("Select an Aura to configure its alert and preview.");
			return;
		}

		ImGui.separatorText("Live Preview & FX");
		advancedPreview.draw(a, ImGui.getContentRegionAvail().x, 130);

		ImGui.separatorText("Configure");
		if (ImGui.beginTabBar("##ab_config_sections")) {
			if (ImGui.beginTabItem("Appearance##ab_tab_appearance")) {
				drawAppearance(a);
				ImGui.endTabItem();
			}
			if (ImGui.beginTabItem("Window##ab_tab_window")) {
				drawWindowLayout(a);
				ImGui.endTabItem();
			}
			if (ImGui.beginTabItem("Behavior##ab_tab_behavior")) {
				drawBehavior(a);
				ImGui.separatorText("DRM Export Sound");
				drawDrmSound(a, false);
				ImGui.endTabItem();
			}
			if (ImGui.beginTabItem("Advanced Effects##ab_tab_effects")) {
				cfg.drawEffects(a, false);
				ImGui.endTabItem();
			}
			if (ImGui.beginTabItem("Import / Export##ab_tab_share")) {
				drawShare(a);
				ImGui.endTabItem();
			}
			ImGui.endTabBar();
		}
	}

	function drawAppearance(a:AuraDef):Void {
		if (ImGui.beginCombo("Display Style##ab_region", regionLabel(a.region))) {
			for (rKey in ["bar", "ring", "text", "icon"])
				if (ImGui.selectable(regionLabel(rKey) + "##ab_reg_" + rKey, a.region == rKey)) {
					a.region = rKey; SettingsStore.markDirty();
				}
			ImGui.endCombo();
		}
		if (ImGui.inputText("Alert Text##ab_announce", a.announceBuf, AuraDef.ANN_BUF)) {
			a.announce = readBytes(a.announceBuf, AuraDef.ANN_BUF);
			SettingsStore.markDirty();
		}
		if (a.region == "icon")
			drawIconPicker(a);
		if (a.region == "bar" || a.region == "ring" || a.region == "icon") {
			if (ImGui.checkbox("Show Label##ab_fx_lbl", a.showLabel)) SettingsStore.markDirty();
		}
		if (a.region == "icon") {
			ImGui.sameLine();
			if (ImGui.checkbox("Progress Ring##ab_fx_ring", a.progressRing)) SettingsStore.markDirty();
			ImGui.sameLine();
			if (ImGui.checkbox("Stack / Count Badge##ab_fx_stacks", a.stackCounter)) SettingsStore.markDirty();
		}
		opacityPercent.set(a.opacity.get() * 100);
		if (solarflare.ui.BuilderSlider.draw("Visual Opacity##ab_opacity", opacityPercent, 10, 100, "%.0f%%")) {
			a.opacity.set(opacityPercent.get() * 0.01);
			SettingsStore.markDirty();
		}
		if (solarflare.ui.BuilderSlider.draw("Scale##ab_scale", a.scale, 0.5, 2.5, "%.2fx")) { a.sizeDirty = true; SettingsStore.markDirty(); }
	}

	function drawWindowToggles(a:AuraDef, area:String):Void {
		ImGui.pushID_Str("ab_window_controls_" + area);
		if (ImGui.checkbox("Show Aura##ab_visible", a.enabled)) {
			if (a.enabled.get()) a.visual.set(true);
			SettingsStore.markDirty();
		}
		ImGui.sameLine();
		if (ImGui.checkbox("Lock##ab_lock", a.chrome.locked)) {
			cfg.unlockAll.set(false);
			SettingsStore.markDirty();
		}
		ImGui.sameLine();
		if (ImGui.checkbox("Always On##ab_always", a.alwaysOn)) SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.checkbox("Transparent##ab_transparent", a.chrome.transparent)) SettingsStore.markDirty();
		ImGui.popID();
	}

	function drawWindowLayout(a:AuraDef):Void {
		drawWindowToggles(a, "layout");
		ImGui.textWrapped("Always On keeps display visible; conditions still drive counters and alerts.");
		if (solarflare.ui.BuilderSlider.draw("Width##ab_w", a.w, 32, 720, "%.0f px")) { a.sizeDirty = true; SettingsStore.markDirty(); }
		if (solarflare.ui.BuilderSlider.draw("Height##ab_h", a.h, 24, 480, "%.0f px")) { a.sizeDirty = true; SettingsStore.markDirty(); }
		if (ImGui.checkbox("Show Key Reminder##ab_show_key", a.showKey)) SettingsStore.markDirty();
		if (a.showKey.get() && ImGui.inputText("Key Text##ab_key", a.keyBuf, AuraDef.KEY_BUF)) {
			a.keyText = AuraDef.sanitizeKey(readBytes(a.keyBuf, AuraDef.KEY_BUF));
			SettingsStore.markDirty();
		}
	}

	function drawPreviewCanvas():Void {
		var a = selectedAura();
		if (a == null) return;
		var p = ImGui.getCursorScreenPos();
		var area = ImGui.getContentRegionAvail();
		var canvasW:Single = area.x > 40 ? area.x : 320;
		var configuredW:Single = a.w.get() > 1 ? a.w.get() : 96;
		var configuredH:Single = a.h.get() > 1 ? a.h.get() : 96;
		var maxScale:Single = 2.5;
		var fitX:Single = (canvasW - 8) / (configuredW * maxScale);
		var fitY:Single = 94 / (configuredH * maxScale);
		var fit:Single = fitX < fitY ? fitX : fitY;
		var visualScale:Single = a.scale.get();
		var w:Single = configuredW * fit * visualScale;
		var h:Single = configuredH * fit * visualScale;
		var x:Single = p.x + (canvasW - w) * 0.5;
		var y:Single = p.y + (94 - h) * 0.5;
		AuraVisualRenderer.draw(ImGui.getWindowDrawList(), a, x, y, w, h,
			previewProgress.get(), previewCount.get(), previewCount.get(), false, 1);
		ImGui.dummy(ImGui.vec2(canvasW, 96));
	}

	function drawIconPicker(a:AuraDef):Void {
		var key = a.preferredIconId();
		if (!GameIcons.imageKey(key, 44, 44)) {
			drawIconPlaceholder(key, 44, 44);
			ImGui.sameLine();
			ImGui.textDisabled(key.length > 0 ? "Icon art is loading or unavailable." : "No automatic icon is available.");
		} else {
			ImGui.sameLine();
			ImGui.textWrapped((a.iconId.length > 0 ? "Custom: " : "Automatic: ") + key);
		}
		if (a.iconId.length > 0 && ImGui.button("Use Automatic Icon##ab_icon_auto")) {
			a.iconId = ""; a.plate = ""; a.syncIconBuf(); SettingsStore.markDirty();
		}
		if (ImGui.inputText("Custom Icon ID##ab_icon_custom", a.iconBuf, AuraDef.ICON_BUF)) {
			a.iconId = StringTools.trim(readBytes(a.iconBuf, AuraDef.ICON_BUF));
			a.plate = "";
			SettingsStore.markDirty();
		}
		{
			if (ImGui.inputText("Search Icons##ab_icon_search", iconSearchBuf, 80))
				iconSearch = readBytes(iconSearchBuf, 80).toLowerCase();
			ImGui.beginChild("##ab_icon_results", ImGui.vec2(0, 300), ImGuiChildFlags.Borders);
			drawIconCandidates(a);
			ImGui.endChild();
		}
	}

	function drawIconCandidates(a:AuraDef):Void {
		var shown = 0;
		for (entry in solarflare.cdb.AuraCatalog.entries) {
			if (!matchesIcon(entry.id, entry.name)) continue;
			drawIconChoice(a, entry.id, entry.name, entry.kind);
			shown++;
		}
		ImGui.textDisabled(shown + " matching icons");
	}

	function drawIconChoice(a:AuraDef, id:String, label:String, source:String, fallbackId:String = ""):Void {
		if (!ImGui.isRectVisible(ImGui.vec2(ImGui.getContentRegionAvail().x, 28))) {
			ImGui.dummy(ImGui.vec2(1, 28));
			return;
		}
		var thumbnailId = id;
		var hasArt = GameIcons.imageKey(thumbnailId, 28, 28);
		if (!hasArt && fallbackId.length > 0 && fallbackId != thumbnailId) {
			if (GameIcons.imageKey(fallbackId, 28, 28)) {
				thumbnailId = fallbackId;
				hasArt = true;
			}
		}
		if (!hasArt)
			drawIconPlaceholder(thumbnailId, 28, 28);
		ImGui.sameLine();
		if (ImGui.selectable(label + " [" + source + "]##ab_icon_" + source + "_" + id, a.iconId == thumbnailId)) {
			a.iconId = thumbnailId; a.plate = ""; a.syncIconBuf(); SettingsStore.markDirty();
		}
	}

	/** Visible placeholder while the queued thumbnail loads, or when an id has no matching art. */
	function drawIconPlaceholder(id:String, w:Single, h:Single):Void {
		var p = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(w, h));
		var dl = ImGui.getWindowDrawList();
		ImGui.ImDrawList_AddRectFilled(dl, p, ImGui.vec2(p.x + w, p.y + h),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.13, 0.16, 0.21, 1)), 4);
		ImGui.ImDrawList_AddRect(dl, p, ImGui.vec2(p.x + w, p.y + h),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.36, 0.45, 0.58, 1)), 4, 1);
		var mark = id != null && id.length > 0 ? id.substr(0, 1).toUpperCase() : "?";
		var ts = ImGui.calcTextSize(mark);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(p.x + (w - ts.x) * 0.5, p.y + (h - ts.y) * 0.5),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.72, 0.8, 0.92, 1)), mark);
	}

	function drawBehavior(a:AuraDef):Void {
		var mode = behaviorMode(a);
		if (ImGui.beginCombo("Show Alert##ab_behavior", behaviorLabel(mode))) {
			for (key in ["whileTrue", "onRiseHold", "whileFalse"])
				if (ImGui.selectable(behaviorLabel(key) + "##ab_behavior_" + key, mode == key)) {
					applyBehavior(a, key); SettingsStore.markDirty();
				}
			ImGui.endCombo();
		}
		if (mode == "onRiseHold" && solarflare.ui.BuilderSlider.draw("Alert Duration##ab_hold", a.durRef, 0.5, 10, "%.1f s")) {
			a.duration = a.durRef.get();
			for (e in a.effects) if (e != null) {
				e.hold = a.duration; e.holdRef.set(a.duration);
			}
			SettingsStore.markDirty();
		}
		if (ImGui.checkbox("Count each time the conditions become true##ab_counter", a.isCounter))
			SettingsStore.markDirty();
		if (a.isCounter.get()) {
			ImGui.textDisabled("Saved count: " + a.counterValue);
			ImGui.sameLine();
			if (ImGui.smallButton("Reset Count##ab_reset_count")) {
				a.counterValue = 0; a.stacks = 1;
				SettingsStore.markDirty();
			}
		}

		ImGui.separatorText("Boss Mod Alert");
		if (ImGui.checkbox("Large typed alert##ab_boss_alert", a.showBanner)) {
			if (a.showBanner.get() && !hasAlertEffect(a))
				a.effects.push(new AuraEffect("boss_alert", AuraEffect.KIND_ALERT, AuraEffect.WHEN_ON_RISE_HOLD));
			SettingsStore.markDirty();
		}
		if (a.showBanner.get()) {
			if (ImGui.inputTextMultiline("Alert message##ab_boss_alert_text", a.bannerBuf, AuraDef.BANNER_BUF, ImGui.vec2(-1, 64))) {
				a.bannerText = readBytes(a.bannerBuf, AuraDef.BANNER_BUF);
				SettingsStore.markDirty();
			}
			if (solarflare.ui.BuilderSlider.draw("Alert size##ab_boss_alert_scale", a.bannerScale, 1, 3, "%.1fx"))
				SettingsStore.markDirty();
		}
	}

	static function hasAlertEffect(a:AuraDef):Bool {
		if (a == null || a.effects == null)
			return false;
		for (e in a.effects)
			if (e != null && e.enabled.get() && e.kind == AuraEffect.KIND_ALERT)
				return true;
		return false;
	}

	function drawDrmSound(a:AuraDef, collapsed:Bool = true):Void {
		if (collapsed && !ImGui.collapsingHeader("DRM Export Sound##ab_drm_sound"))
			return;
		ImGui.textDisabled("SolarFlare does not play audio. These settings are included only in DRM exports.");
		if (ImGui.checkbox("Include sound cue in DRM export##ab_audio", a.audio)) SettingsStore.markDirty();
		if (a.audio.get()) {
			var cue = a.cue.length > 0 ? a.cue : "Choose a cue...";
			if (ImGui.beginCombo("Cue##ab_cue", cue)) {
				for (id in AuraPack.CUE_IDS)
					if (ImGui.selectable(id + "##ab_cue_" + id, a.cue == id)) {
						a.cue = id; a.syncCueBuf(); SettingsStore.markDirty();
					}
				ImGui.endCombo();
			}
			volumePercent.set(a.volume.get() * 100);
			if (solarflare.ui.BuilderSlider.draw("DRM Sound Volume##ab_volume", volumePercent, 0, 100, "%.0f%%")) {
				a.volume.set(volumePercent.get() * 0.01);
				SettingsStore.markDirty();
			}
		}
	}

	function drawShare(a:AuraDef):Void {
		if (ImGui.collapsingHeader("Share or Back Up##ab_export_sec", imgui.Enums.ImGuiTreeNodeFlags.DefaultOpen)) {
			if (ImGui.button("Copy Selected to Clipboard##ab_copy_sel", ImGui.vec2(190, 26))) {
				exportString = Json.stringify(AuraEngine.toObj(a), null, "  ");
				fillBuf(exportBuf, JSON_BUF, exportString);
				UiActionQueue.copyText(exportString, 'Aura "${a.name}" copied to clipboard!');
				setIoStatus('Aura "${a.name}" queued for clipboard copy.', false);
			}
			ImGui.sameLine();
			if (ImGui.button("Copy Entire Library##ab_copy_all", ImGui.vec2(160, 26))) {
				UiActionQueue.enqueue(UiActionKind.ExportAuraPack);
				setIoStatus("Aura pack export queued.", false);
			}
			if (exportString.length > 0)
				ImGui.inputTextMultiline("##ab_export_area", exportBuf, JSON_BUF, ImGui.vec2(-1, 80));
		}

		if (ImGui.collapsingHeader("Import Aura JSON##ab_import_sec", imgui.Enums.ImGuiTreeNodeFlags.DefaultOpen)) {
			if (ImGui.button("Paste & Import from Clipboard##ab_clip_import", ImGui.vec2(220, 26))) {
				UiActionQueue.enqueue(UiActionKind.ImportAuraClipboard);
				setIoStatus("Aura import queued from clipboard.", false);
			}
			ImGui.sameLine();
			if (ImGui.button("Import from Text Box##ab_do_import", ImGui.vec2(160, 26)))
				importJson();

			ImGui.inputTextMultiline("##ab_import_area", importBuf, JSON_BUF, ImGui.vec2(-1, 70));
		}
		if (ioStatus.length > 0)
			ImGui.textColored(ioStatusError ? ImGui.vec4(1, 0.35, 0.35, 1) : ImGui.vec4(0.35, 0.9, 0.5, 1), ioStatus);
	}

	function importJson():Void {
		var raw = StringTools.trim(readBytes(importBuf, JSON_BUF));
		if (raw.length < 2) {
			setIoStatus("Paste Aura JSON before importing.", true);
			ToastManager.error("Paste Aura JSON before importing.");
			return;
		}
		try {
			var imported = AuraPack.unpackAuras(AuraPack.decode(raw));
			var added = 0;
			snapshot("Import JSON");
			for (item in imported) {
				if (item == null || cfg.auras.length >= AuraEngine.MAX) break;
				item.id = uniqueAuraId(item.id);
				cfg.auras.push(item); added++;
			}
			if (added == 0) {
				setIoStatus(cfg.auras.length >= AuraEngine.MAX ? "The Aura library is full." : "No valid Aura objects were found.", true);
				ToastManager.error("No valid Aura objects found.");
			} else {
				selected = cfg.auras.length - 1; deleteArmed = -1; SettingsStore.markDirty();
				var msg = added + " Aura(s) imported successfully!";
				setIoStatus(msg, false);
				ToastManager.success(msg);
			}
		} catch (_:Dynamic) {
			setIoStatus("Import failed: invalid Aura JSON.", true);
			ToastManager.error("Import failed: invalid Aura JSON.");
		}
	}

	function addBlankAura():Void {
		if (cfg.auras.length >= AuraEngine.MAX) return;
		var index = cfg.auras.length + 1;
		var a = new AuraDef(uniqueAuraId("aura_" + index), "New Aura " + index);
		a.rule = new solarflare.aura.signal.AuraRuleDef();
		a.enabled.set(false);
		cfg.auras.push(a);
		selected = cfg.auras.length - 1; deleteArmed = -1; SettingsStore.markDirty();
	}

	function addTemplate(a:AuraDef):Void {
		if (a == null || cfg.auras.length >= AuraEngine.MAX) return;
		a.id = uniqueAuraId(a.id);
		if (setupIssue(a).length > 0)
			a.enabled.set(false);
		cfg.auras.push(a);
		selected = cfg.auras.length - 1; deleteArmed = -1; SettingsStore.markDirty();
	}

	function duplicateSelected():Void {
		var source = selectedAura();
		if (source == null || cfg.auras.length >= AuraEngine.MAX) return;
		var copy = AuraConfig.cloneAura(source, uniqueAuraId(source.id + "_copy"), source.name + " Copy");
		if (copy == null) return;
		cfg.auras.push(copy);
		selected = cfg.auras.length - 1; deleteArmed = -1; SettingsStore.markDirty();
	}

	function applyBehavior(a:AuraDef, key:String):Void {
		if (key == "onRiseHold")
			AuraEffects.applyPresetDormant(a);
		else if (key == "whileFalse")
			AuraEffects.applyPresetOnCd(a);
		else
			AuraEffects.applyPresetContinuous(a);
	}

	function behaviorMode(a:AuraDef):String {
		if (a.effects != null)
			for (e in a.effects) if (e != null && e.enabled.get() && (e.kind == AuraEffect.KIND_WINDOW || e.kind == AuraEffect.KIND_ICON)) {
				if (e.when == AuraEffect.WHEN_WHILE_FALSE) return "whileFalse";
				if (e.when == AuraEffect.WHEN_ON_RISE || e.when == AuraEffect.WHEN_ON_RISE_HOLD) return "onRiseHold";
			}
		return "whileTrue";
	}

	static function behaviorLabel(key:String):String {
		return switch (key) {
			case "onRiseHold": "Show briefly when conditions become true";
			case "whileFalse": "Show while conditions are not true";
			default: "Show while conditions are true";
		};
	}

	function setupIssue(a:AuraDef):String {
		if (a == null) return "Select an Aura.";
		if (StringTools.trim(a.name).length == 0) return "Give this Aura a name.";
		if (a.rule == null || a.rule.conditions == null || a.rule.conditions.length == 0) return "Add at least one condition.";
		for (c in a.rule.conditions) {
			if (c == null || AuraSignalCatalog.find(c.signal) == null) return "Choose what each condition should check.";
			var d = AuraSignalCatalog.find(c.signal);
			if (d != null && d.subjectKind.length > 0 && StringTools.trim(c.subject).length == 0)
				return "Choose a specific target for the highlighted condition.";
		}
		if (a.region == "text" && StringTools.trim(a.announce).length == 0) return "Enter the text this Aura should show.";
		if (a.region == "icon" && a.preferredIconId().length == 0) return "Choose an icon or a condition with an automatic icon.";
		return "";
	}

	function matchesFilter(a:AuraDef):Bool {
		if (scopeFilter == "Shared" && !isShared(a)) return false;
		if (scopeFilter == "Encounter-specific" && isShared(a)) return false;
		if (scopeFilter == "Needs setup" && setupIssue(a).length == 0) return false;
		if (search.length == 0) return true;
		if (contains(a.name, search) || contains(a.id, search) || contains(a.fight, search)) return true;
		if (a.rule != null && a.rule.conditions != null)
			for (c in a.rule.conditions) if (c != null && (contains(c.subject, search) || contains(c.subjectLabel, search) || contains(c.signal, search))) return true;
		return false;
	}

	function matchesIcon(id:String, label:String):Bool {
		return iconSearch.length == 0 || contains(id, iconSearch) || contains(label, iconSearch);
	}

	static function contains(value:String, query:String):Bool {
		return value != null && value.toLowerCase().indexOf(query) >= 0;
	}

	static function isShared(a:AuraDef):Bool {
		return a == null || a.fight == null || a.fight.length == 0 || a.fight == "shared";
	}

	function selectedAura():AuraDef {
		return selected >= 0 && selected < cfg.auras.length ? cfg.auras[selected] : null;
	}

	function uniqueAuraId(requested:String):String {
		return cfg.allocateAuraId(requested);
	}

	function setIoStatus(message:String, error:Bool):Void {
		ioStatus = message;
		ioStatusError = error;
	}

	static function regionLabel(region:String):String {
		return switch (region) {
			case "bar": "HUD Status Bar";
			case "ring": "Hero Ring";
			case "text": "Screen Text Banner";
			case "icon": "Icon Alert";
			default: "HUD Status Bar";
		};
	}

	static function fillBuf(buf:hl.Bytes, cap:Int, value:String):Void {
		ByteUtil.fillBuf(buf, cap, value);
	}

	static function readBytes(buf:hl.Bytes, cap:Int):String {
		return ByteUtil.readBytes(buf, cap);
	}
}
