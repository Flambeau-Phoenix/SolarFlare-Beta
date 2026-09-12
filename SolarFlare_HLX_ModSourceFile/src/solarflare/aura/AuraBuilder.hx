package solarflare.aura;

import solarflare.aura.signal.AuraConditionEditor;
import solarflare.aura.signal.AuraSignalCatalog;
import solarflare.aura.signal.AuraConditionValidator;
import solarflare.aura.signal.AuraValueKind;
import solarflare.cdb.CdbAuraTable;
import solarflare.cdb.AuraCatalog;
import solarflare.cdb.AuraQuickStartCatalog;
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
import solarflare.util.ShareCodec;
import solarflare.util.JsonSchema;
import imgui.ImGui;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiKey;
import imgui.Enums.ImGuiStyleVar;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import haxe.Json;

/**
 * Aura Builder - 2-column layout: Library (left ~22%) + tabbed Workspace (right ~78%).
 *
 * Workspace tabs:
 *   Build       - WHEN / THEN / SUMMARY (default tab)
 *   Appearance  - visual style, icon, size, canvas, glow/fuse
 *   Preview     - full interactive preview with sim controls
 *
 * All existing condition/effect/canvas/icon/undo/import-export capability is preserved.
 * Creation mode wizard (Boss / Skill / Utility / Free) adds guided entry without new engine.
 */
class AuraBuilder {
	public var open = new BoolRef(false);
	var cfg:AuraConfig;
	var host:ConfigPanel;
	var selected:Int = -1;
	var deleteArmed:Int = -1;
	var selectedIds:Map<String, Bool> = new Map();
	var rangeAnchorId:String = "";

	var undoManager = new UndoManager<String>(40);
	var auraSearch = new SearchBar("Filter auras by name, signal, or target...", 128);

	var previewProgress = new FloatRef(0.65);
	var previewCount = new IntRef(3);
	var previewPercent = new FloatRef(65);
	var opacityPercent = new FloatRef(100);
	var volumePercent = new FloatRef(100);
	var search:String = "";
	var scopeFilter:String = "All";
	var iconSearchBuf = new hl.Bytes(80);
	var iconSearch:String = "";
	var iconKindFilter:String = "All";

	var visualBuilder = new solarflare.aura.signal.VisualConditionBuilder();
	var testHarness = new solarflare.aura.test.AuraTestHarness();
	var advancedPreview = new solarflare.aura.preview.AdvancedAuraPreview();

	/** Right workspace: 0=Build, 1=Appearance, 2=Preview */
	var workspaceTab:Int = 0;
	var tabSelectRequest:Int = 0;
	var inspectorTab:Int = 0;
	var triggerSubTab:Int = 0;

	var canvasSel:Int = -1;
	var canvasEditX = new FloatRef(0);
	var canvasEditY = new FloatRef(0);
	var canvasEditW = new FloatRef(48);
	var canvasEditH = new FloatRef(48);
	var canvasEditFs = new FloatRef(16);
	var canvasColBuf:hl.Bytes;
	var lastCanvasColorAuraId:String = "";
	var lastCanvasColorSel:Int = -1;
	var iconGlowRef = new BoolRef(false);
	var glowColBuf:hl.Bytes;
	var lastGlowAuraId:String = "";
	var canvasContentBuf = new hl.Bytes(160);
	static inline var CANVAS_CONTENT_BUF:Int = 160;

	static inline var JSON_BUF:Int = 32768;
	var exportBuf = new hl.Bytes(JSON_BUF);
	var importBuf = new hl.Bytes(JSON_BUF);
	var exportString:String = "";
	var ioStatus:String = "";
	var ioStatusError:Bool = false;
	var ioModalRequest:Bool = false;

	// Wizard state
	var wizardMode:String = "";
	var wizardStep:Int = 0;
	var wizardSignal:String = "";
	var wizardSubject:String = "";
	var wizardBossId:String = "";
	var wizardCatalogSearch:String = "";
	var wizardFight:String = "";
	var wizardBehavior:String = "whileTrue";
	var wizardSubjectBuf = new hl.Bytes(128);
	var wizardCatalogSearchBuf = new hl.Bytes(96);
	var wizardFightBuf = new hl.Bytes(32);
	var wizardOpenRequest:Bool = false;

	public function new(cfg:AuraConfig, host:ConfigPanel) {
		this.cfg = cfg;
		this.host = host;
		glowColBuf = ImGui.v4(1, 0.53, 0, 1);
		canvasColBuf = ImGui.v4(1, 1, 1, 1);
		solarflare.ui.ByteUtil.clearBytes(iconSearchBuf, 80);
		solarflare.ui.ByteUtil.clearBytes(exportBuf, JSON_BUF);
		solarflare.ui.ByteUtil.clearBytes(importBuf, JSON_BUF);
		solarflare.ui.ByteUtil.clearBytes(canvasContentBuf, CANVAS_CONTENT_BUF);
		solarflare.ui.ByteUtil.clearBytes(wizardSubjectBuf, 128);
		solarflare.ui.ByteUtil.clearBytes(wizardCatalogSearchBuf, 96);
		solarflare.ui.ByteUtil.clearBytes(wizardFightBuf, 32);
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
			if (clip == null || clip.length < 2) { ToastManager.error("Clipboard contains no valid share key or JSON."); return; }
			ByteUtil.fillBuf(importBuf, JSON_BUF, clip);
			applyImportBuffer();
		} catch (e:Dynamic) { ToastManager.error("Import failed: " + e); }
	}

	function applyImportBuffer():Void { importJson(); }

	public function exportPackQueued():Void {
		if (cfg == null) return;
		try {
			var share = AuraPack.encode("shared", "export", "pack", cfg.auras);
			ImGui.setClipboardText(share);
			ToastManager.success(cfg.auras.length + " Auras copied as share key!");
		} catch (e:Dynamic) { ToastManager.error("Export failed: " + e); }
	}

	// ----------------------------------------------------------------
	// Main Draw - 2-column layout
	// ----------------------------------------------------------------

	public function draw():Void {
		if (!open.get() || cfg == null) return;
		if (!CursorCaptureFix.cursorFree) return;

		var vis = ToolWindow.begin("Aura Builder###SolarFlare.AuraBuilder", open, 1480, 920, 0, false);
		if (vis) {
			drawTopToolbar();
			ImGui.separator();

			var avail = ImGui.getContentRegionAvail();
			var paneH:Single = avail.y < 280 ? 280 : avail.y;
			var leftW:Single = avail.x * 0.22;
			if (leftW < 200) leftW = 200;
			var rightW:Single = avail.x - leftW - 10;
			if (rightW < 400) rightW = 400;

			solarflare.ui.UiChrome.celChild("##ab_list", ImGui.vec2(leftW, paneH), drawLeftPane);
			ImGui.sameLine();
			solarflare.ui.UiChrome.celChild("##ab_workspace", ImGui.vec2(rightW > 0 ? rightW : 0, paneH), drawWorkspace);

			drawIoModal();
			drawWizardModal();
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
		drawStatusPill();
		ImGui.sameLine();
		var currentJson = try Json.stringify(AuraPack.toObj("shared", "current", "undo", cfg.auras)) catch (_) "";
		undoManager.drawButtons(currentJson, restoreSnapshot);
		ImGui.sameLine(0, 16);
		if (UiChrome.accentButton("Save##ab_save_top")) UiActionQueue.save();
		if (SettingsStore.isDirty()) { ImGui.sameLine(0, 12); ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "* Unsaved"); }
	}

	function drawStatusPill():Void {
		if (selected < 0 || selected >= cfg.auras.length) { ImGui.textColored(ImGui.vec4(0.45, 0.78, 1, 1), "Create or select an Aura"); return; }
		var a = cfg.auras[selected];
		if (!cfg.enabled.get()) ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "SYSTEM DISABLED");
		else if (!a.enabled.get()) ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "DISABLED * " + a.name);
		else {
			var issue = setupIssue(a);
			if (issue.length > 0) ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "NEEDS SETUP * " + a.name);
			else ImGui.textColored(ImGui.vec4(0.35, 0.9, 0.5, 1), "READY * " + a.name);
		}
	}

	// ----------------------------------------------------------------
	// Workspace (right panel, tabbed)
	// ----------------------------------------------------------------

	function drawWorkspace():Void {
		var a = selectedAura();
		if (a == null) {
			solarflare.ui.UiChrome.sectionHeader("Aura Workspace");
			ImGui.spacing();
			ImGui.textWrapped("Select or create an Aura from the library on the left.");
			ImGui.spacing();
			ImGui.textDisabled("Use the mode picker (Boss / Skill / Utility / Free) for guided creation.");
			return;
		}

		if (ImGui.beginTabBar("##ab_workspace_tabs")) {
			var buildFlags = tabSelectRequest == 0 ? imgui.Enums.ImGuiTabItemFlags.SetSelected : 0;
			if (beginWorkspaceTab("  Build  ##ab_tab_build", buildFlags)) {
				workspaceTab = 0;
				drawBuildTab(a);
				ImGui.endTabItem();
			}
			var appearFlags = tabSelectRequest == 1 ? imgui.Enums.ImGuiTabItemFlags.SetSelected : 0;
			if (beginWorkspaceTab("  Appearance  ##ab_tab_appear", appearFlags)) {
				workspaceTab = 1;
				drawAppearanceTab(a);
				ImGui.endTabItem();
			}
			var prevFlags = tabSelectRequest == 2 ? imgui.Enums.ImGuiTabItemFlags.SetSelected : 0;
			if (beginWorkspaceTab("  Preview  ##ab_tab_prev", prevFlags)) {
				workspaceTab = 2;
				drawPreviewTab(a);
				ImGui.endTabItem();
			}
			tabSelectRequest = -1;
			ImGui.endTabBar();
		}
	}

	function beginWorkspaceTab(label:String, flags:Int):Bool {
		var theme = solarflare.ui.ThemePalette.current();
		var idle = ImGui.vec4(
			theme.cellBg.x * 0.86 + theme.accent.x * 0.14,
			theme.cellBg.y * 0.86 + theme.accent.y * 0.14,
			theme.cellBg.z * 0.86 + theme.accent.z * 0.14, 1);
		var hovered = ImGui.vec4(
			theme.cellBg.x * 0.66 + theme.accent.x * 0.34,
			theme.cellBg.y * 0.66 + theme.accent.y * 0.34,
			theme.cellBg.z * 0.66 + theme.accent.z * 0.34, 1);
		var selected = ImGui.vec4(
			theme.titleBg.x * 0.58 + theme.accent.x * 0.42,
			theme.titleBg.y * 0.58 + theme.accent.y * 0.42,
			theme.titleBg.z * 0.58 + theme.accent.z * 0.42, 1);
		ImGui.pushStyleColor(ImGuiCol.Tab, idle);
		ImGui.pushStyleColor(ImGuiCol.TabHovered, hovered);
		ImGui.pushStyleColor(ImGuiCol.TabSelected, selected);
		ImGui.pushStyleColor(ImGuiCol.TabSelectedOverline, theme.accent);
		var font = ImGui.getFont();
		if (font != null) ImGui.pushFont(font, ImGui.getFontSize() * 1.10);
		var open = ImGui.beginTabItem(label, null, flags);
		if (font != null) ImGui.popFont();
		ImGui.popStyleColor(4);
		return open;
	}

	// ----------------------------------------------------------------
	// BUILD TAB
	// ----------------------------------------------------------------

	function drawBuildTab(a:AuraDef):Void {
		var avail = ImGui.getContentRegionAvail();
		HudChrome.safeChild("##ab_build_scroll", ImGui.vec2(0, avail.y), 0, function() {
			drawAuraDetails();
			ImGui.spacing();
			drawSectionCard("WHEN", "Conditions that trigger this Aura", true, function() {
				AuraConditionEditor.draw(a, true);
				ImGui.spacing();
				var issue = setupIssue(a);
				if (issue.length > 0)
					ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "! " + issue);
			});
			ImGui.spacing();
			drawSectionCard("THEN", "What happens when conditions are met", false, function() {
				drawBehavior(a);
				ImGui.spacing();
				ImGui.separator();
				cfg.drawEffects(a, false);
				ImGui.separator();
				drawBossAlert(a);
				ImGui.separator();
				drawDrmSound(a, true);
			});
			ImGui.spacing();
			drawSectionCard("SUMMARY", "", false, function() {
				var summary = buildSummary(a);
				if (summary.length > 0) ImGui.textWrapped(summary);
				else ImGui.textDisabled("Complete conditions above for a plain-language summary.");
			});
		});
	}

	function drawSectionCard(title:String, subtitle:String, primary:Bool, body:Void->Void):Void {
		var p = ImGui.getCursorScreenPos();
		var w = ImGui.getContentRegionAvail().x;
		var dl = ImGui.getWindowDrawList();
		var theme = solarflare.ui.ThemePalette.current();
		var bandH:Single = subtitle.length > 0 ? 44 : 34;
		var mix:Single = primary ? 0.24 : 0.10;
		var bandBg = ImGui.vec4(
			theme.cellBg.x * (1 - mix) + theme.accent.x * mix,
			theme.cellBg.y * (1 - mix) + theme.accent.y * mix,
			theme.cellBg.z * (1 - mix) + theme.accent.z * mix,
			0.98);
		var bandMax = ImGui.vec2(p.x + w, p.y + bandH);
		ImGui.ImDrawList_AddRectFilled(dl, p, bandMax, ImGui.colorConvertFloat4ToU32(bandBg), 6);
		ImGui.ImDrawList_AddRect(dl, p, bandMax,
			ImGui.colorConvertFloat4ToU32(primary ? theme.accent : theme.border), 6, primary ? 2.0 : 1.25);
		if (primary)
			ImGui.ImDrawList_AddRectFilled(dl, p, ImGui.vec2(p.x + 4, p.y + bandH),
				ImGui.colorConvertFloat4ToU32(theme.accent), 6);

		var font = ImGui.getFont();
		if (font != null) ImGui.pushFont(font, ImGui.getFontSize() * (primary ? 1.24 : 1.18));
		var titleSize = ImGui.calcTextSize(title);
		ImGui.setCursorScreenPos(ImGui.vec2(p.x + Math.max(8, (w - titleSize.x) * 0.5), p.y + 5));
		ImGui.textColored(primary ? theme.accent : theme.text, title);
		if (font != null) ImGui.popFont();
		if (subtitle.length > 0) {
			var subtitleSize = ImGui.calcTextSize(subtitle);
			ImGui.setCursorScreenPos(ImGui.vec2(p.x + Math.max(8, (w - subtitleSize.x) * 0.5), p.y + 25));
			ImGui.textColored(theme.textDisabled, subtitle);
		}
		ImGui.setCursorScreenPos(ImGui.vec2(p.x, p.y + bandH + 8));
		var bodyIndent:Single = primary ? 12 : 8;
		ImGui.indent(bodyIndent);
		body();
		ImGui.unindent(bodyIndent);
		ImGui.spacing();
	}

	inline function builderSectionHeader(label:String):Void {
		UiChrome.heading(label, 1.22);
	}

	static function buildSummary(a:AuraDef):String {
		if (a == null) return "";
		var parts = new StringBuf();
		if (a.rule != null && a.rule.conditions != null && a.rule.conditions.length > 0) {
			var isAll = a.rule.mode == "all";
			parts.add("When ");
			var condParts:Array<String> = [];
			for (c in a.rule.conditions) {
				if (c == null) continue;
				condParts.push(AuraConditionEditor.humanConditionSummary(c));
			}
			if (condParts.length == 1) parts.add(condParts[0]);
			else if (condParts.length > 1) {
				parts.add("(");
				parts.add(condParts.join(isAll ? " AND " : " OR "));
				parts.add(")");
			}
		} else if (a.trigger != null && a.trigger.length > 0) {
			parts.add("When " + a.trigger);
			if (a.skillId != null && a.skillId.length > 0) parts.add(' ["${a.skillId}"]');
		} else return "";
		var mode = behaviorMode2(a);
		parts.add(" -> ");
		var visual = regionLabel(a.region);
		switch (mode) {
			case "onRiseHold":
				var dur = a.duration > 0 ? Std.string(Math.round(a.duration * 10) / 10) + "s" : "briefly";
				parts.add('show $visual for $dur');
			case "whileFalse": parts.add('show $visual while NOT true');
			default: parts.add('show $visual while true');
		}
		if (a.showFuse.get()) parts.add(" + fuse");
		if (a.showCountdown.get()) parts.add(" + countdown");
		if (a.iconGlow) parts.add(" + glow");
		if (a.isCounter.get()) parts.add(" (counter)");
		parts.add(".");
		return parts.toString();
	}

	// Static helper for buildSummary (avoids closure over instance method)
	static function behaviorMode2(a:AuraDef):String {
		if (a.effects != null)
			for (e in a.effects) if (e != null && e.enabled.get() && (e.kind == AuraEffect.KIND_WINDOW || e.kind == AuraEffect.KIND_ICON)) {
				if (e.when == AuraEffect.WHEN_WHILE_FALSE) return "whileFalse";
				if (e.when == AuraEffect.WHEN_ON_RISE || e.when == AuraEffect.WHEN_ON_RISE_HOLD) return "onRiseHold";
			}
		return "whileTrue";
	}

	// ----------------------------------------------------------------
	// APPEARANCE TAB
	// ----------------------------------------------------------------

	function drawAppearanceTab(a:AuraDef):Void {
		var avail = ImGui.getContentRegionAvail();
		HudChrome.safeChild("##ab_appear_scroll", ImGui.vec2(0, avail.y), 0, function() {
			builderSectionHeader("Window");
			drawWindowLayout(a);
			ImGui.separator();
			builderSectionHeader("Display Style");
			drawAppearance(a);
			ImGui.separator();
			drawGlowAndFuse(a);
			if (a.region == "canvas") { ImGui.separator(); drawCanvasElements(a); }
		});
	}

	// ----------------------------------------------------------------
	// PREVIEW TAB
	// ----------------------------------------------------------------

	function drawPreviewTab(a:AuraDef):Void {
		drawPreviewToolbar(a);
		ImGui.separator();
		var avail = ImGui.getContentRegionAvail();
		var footerReserve:Single = 88;
		var prevW = avail.x;
		var prevH:Single = avail.y - footerReserve;
		if (prevH < 160) prevH = 160;
		advancedPreview.draw(a, prevW, prevH, false);
		previewProgress.set(advancedPreview.progress.get());
		previewCount.set(advancedPreview.stacks.get());
		ImGui.spacing();
		advancedPreview.drawSimButtons(a);
		ImGui.sameLine();
		ImGui.setNextItemWidth(90);
		if (solarflare.ui.BuilderSlider.draw("##ab_sim_prog", advancedPreview.progress, 0, 1, "%.2f"))
			previewProgress.set(advancedPreview.progress.get());
		ImGui.sameLine();
		ImGui.setNextItemWidth(60);
		if (ImGui.sliderInt("##ab_sim_stacks", advancedPreview.stacks, 0, 20, "%d"))
			previewCount.set(advancedPreview.stacks.get());
		ImGui.separator();
		ImGui.alignTextToFramePadding();
		ImGui.text("X");
		ImGui.sameLine();
		ImGui.setNextItemWidth(90);
		if (solarflare.ui.BuilderSlider.draw("##ab_pos_x", a.chrome.x, 0, 2400, "%.0f")) { a.chrome.posDirty = true; SettingsStore.markDirty(); }
		ImGui.sameLine();
		ImGui.text("Y");
		ImGui.sameLine();
		ImGui.setNextItemWidth(90);
		if (solarflare.ui.BuilderSlider.draw("##ab_pos_y", a.chrome.y, 0, 1400, "%.0f")) { a.chrome.posDirty = true; SettingsStore.markDirty(); }
		ImGui.sameLine();
		ImGui.text("Scale");
		ImGui.sameLine();
		ImGui.setNextItemWidth(90);
		if (solarflare.ui.BuilderSlider.draw("##ab_stage_scale", a.scale, 0.5, 2.5, "%.2fx")) { a.sizeDirty = true; SettingsStore.markDirty(); }
	}

	function drawPreviewToolbar(a:AuraDef):Void {
		var isCanvas = a.region == "canvas";
		if (isCanvas) { ImGui.textDisabled("Canvas: 1:1 local bounds (unscaled pixels)"); ImGui.sameLine(); }
		else {
			if (ImGui.smallButton(advancedPreview.zoomMode == 0 ? "[Fit]##ab_zoom_fit" : "Fit##ab_zoom_fit")) advancedPreview.zoomMode = 0;
			ImGui.sameLine();
			if (ImGui.smallButton(advancedPreview.zoomMode == 1 ? "[100%]##ab_zoom_100" : "100%##ab_zoom_100")) advancedPreview.zoomMode = 1;
			ImGui.sameLine();
		}
		if (ImGui.smallButton(advancedPreview.showGrid ? "[Grid]##ab_grid" : "Grid##ab_grid")) advancedPreview.showGrid = !advancedPreview.showGrid;
		ImGui.sameLine();
		if (ImGui.smallButton(advancedPreview.showBounds ? "[Bounds]##ab_bounds" : "Bounds##ab_bounds")) advancedPreview.showBounds = !advancedPreview.showBounds;
		ImGui.sameLine();
		if (ImGui.smallButton(advancedPreview.ghostPreview ? "[Ghost]##ab_ghost" : "Ghost##ab_ghost")) advancedPreview.ghostPreview = !advancedPreview.ghostPreview;
	}

	// ----------------------------------------------------------------
	// LEFT PANE - Library
	// ----------------------------------------------------------------

	function drawLeftPane():Void {
		solarflare.ui.UiChrome.sectionHeader("Aura Library");
		ImGui.textDisabled(Std.string(cfg.auras.length) + " / " + AuraEngine.MAX);

		var atCap = cfg.auras.length >= AuraEngine.MAX;
		drawNewAuraCallout(atCap);

		ImGui.spacing();
		var theme = solarflare.ui.ThemePalette.current();
		var font = ImGui.getFont();
		if (font != null) ImGui.pushFont(font, ImGui.getFontSize() * 1.08);
		ImGui.textColored(theme.text, "Or use a starter template");
		if (font != null) ImGui.popFont();
		if (atCap) ImGui.beginDisabled();
		ImGui.setNextItemWidth(-1);
		if (ImGui.beginCombo("##ab_templates", "Starter template...")) {
			if (ImGui.selectable("Ignore Pain (canvas)", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createIgnorePainAlert()); ToastManager.success("Template: Ignore Pain"); }
			if (ImGui.selectable("Status on me", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createStatusOnMeAlert()); ToastManager.success("Template: Status on me"); }
			if (ImGui.selectable("Pyroclasm Proc", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createPyroclasmProcAlert()); ToastManager.success("Template: Pyroclasm Proc"); }
			if (ImGui.selectable("Enemy Spell Cast", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createEnemySpellCastAlert()); ToastManager.success("Template: Enemy Spell Cast"); }
			if (ImGui.selectable("Enemy Channel Active", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createEnemyChannelActiveAlert()); ToastManager.success("Template: Enemy Channel Active"); }
			if (ImGui.selectable("Emergency Low Health", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createEmergencyLowHpAlert()); ToastManager.success("Template: Low Health"); }
			if (ImGui.selectable("Skill Cooldown Ready", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createSkillReadyAlert()); ToastManager.success("Template: Skill Ready"); }
			if (ImGui.selectable("Buff / Debuff Stacks", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createBuffStackTracker()); ToastManager.success("Template: Stack Tracker"); }
			if (ImGui.selectable("Boss / Run Counter", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createBossKillCounter()); ToastManager.success("Template: Boss Counter"); }
			if (ImGui.selectable("Heavy Damage Warning", false)) { snapshot("Add Template"); addTemplate(AuraTemplates.createDamageTakenSpike()); ToastManager.success("Template: Damage Warning"); }
			ImGui.endCombo();
		}
		if (atCap) ImGui.endDisabled();

		search = auraSearch.draw("##ab_search");
		formLabel("Filter");
		ImGui.setNextItemWidth(-1);
		if (ImGui.beginCombo("##ab_scope", scopeFilter)) {
			for (filter in ["All", "Shared", "Encounter-specific", "Needs setup"])
				if (ImGui.selectable(filter + "##ab_scope_" + filter, scopeFilter == filter)) scopeFilter = filter;
			ImGui.endCombo();
		}

		drawBatchToolbar();
		ImGui.separator();
		var footerH:Single = 40;
		var listH = ImGui.getContentRegionAvail().y - footerH;
		if (listH < 80) listH = 80;
		HudChrome.safeChild("##ab_list_child", ImGui.vec2(0, listH), 0, drawAuraList);
		ImGui.separator();
		if (UiChrome.ghostButton("Import / Export##ab_io_open", ImGui.vec2(-1, 28))) ioModalRequest = true;
	}

	function drawNewAuraCallout(atCap:Bool):Void {
		var theme = solarflare.ui.ThemePalette.current();
		var panelMix:Single = 0.14;
		var panelBg = ImGui.vec4(
			theme.cellBg.x * (1 - panelMix) + theme.accent.x * panelMix,
			theme.cellBg.y * (1 - panelMix) + theme.accent.y * panelMix,
			theme.cellBg.z * (1 - panelMix) + theme.accent.z * panelMix,
			0.98);

		ImGui.pushStyleColor(ImGuiCol.ChildBg, panelBg);
		ImGui.pushStyleColor(ImGuiCol.Border, theme.accent);
		ImGui.pushStyleVar(ImGuiStyleVar.ChildBorderSize, 2.0);
		ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(10, 9));
		var shown = ImGui.beginChild("##ab_create_panel", ImGui.vec2(0, 0),
			ImGuiChildFlags.Borders | ImGuiChildFlags.AutoResizeY | ImGuiChildFlags.AlwaysUseWindowPadding, 0);
		if (shown) {
			UiChrome.heading("Create New Aura", 1.20);
			var cue = atCap ? "Aura limit reached" : "Start here";
			var cueSize = ImGui.calcTextSize(cue);
			var cueX = ImGui.getCursorPosX();
			var cueW = ImGui.getContentRegionAvail().x;
			ImGui.setCursorPosX(cueX + Math.max(0, (cueW - cueSize.x) * 0.5));
			ImGui.textColored(atCap ? theme.textDisabled : theme.accent, cue);
			ImGui.setCursorPosX(cueX);
			ImGui.spacing();

			if (atCap) ImGui.beginDisabled();
			ImGui.pushStyleColor(ImGuiCol.FrameBg, theme.windowBg);
			ImGui.pushStyleColor(ImGuiCol.FrameBgHovered, ImGui.vec4(
				theme.cellBg.x * 0.70 + theme.accent.x * 0.30,
				theme.cellBg.y * 0.70 + theme.accent.y * 0.30,
				theme.cellBg.z * 0.70 + theme.accent.z * 0.30, 1));
			ImGui.pushStyleColor(ImGuiCol.FrameBgActive, ImGui.vec4(
				theme.cellBg.x * 0.60 + theme.accent.x * 0.40,
				theme.cellBg.y * 0.60 + theme.accent.y * 0.40,
				theme.cellBg.z * 0.60 + theme.accent.z * 0.40, 1));
			ImGui.pushStyleVar(ImGuiStyleVar.FramePadding, ImGui.vec2(9, 7));
			ImGui.pushStyleVar(ImGuiStyleVar.FrameBorderSize, 1.5);
			ImGui.setNextItemWidth(-1);
			if (ImGui.beginCombo("##ab_new_mode", "+ New Aura")) {
				ImGui.separatorText("Guided");
				if (ImGui.selectable("Boss##ab_mode_boss", false)) openWizard("boss");
				if (ImGui.isItemHovered()) ImGui.setTooltip("Pick encounter -> mechanic -> event -> create Aura");
				if (ImGui.selectable("Skill##ab_mode_skill", false)) openWizard("skill");
				if (ImGui.isItemHovered()) ImGui.setTooltip("Pick skill -> state (ready / cooldown / cast / charges)");
				if (ImGui.selectable("Utility##ab_mode_utility", false)) openWizard("utility");
				if (ImGui.isItemHovered()) ImGui.setTooltip("Common patterns: timer, counter, resource, buff/debuff, combat state");
				ImGui.separator();
				ImGui.separatorText("Advanced");
				if (ImGui.selectable("Free (blank)##ab_mode_free", false)) {
					snapshot("Create Aura"); addBlankAura(); ToastManager.success("New blank aura created.");
				}
				if (ImGui.isItemHovered()) ImGui.setTooltip("Full condition/effect composer - no wizard");
				ImGui.endCombo();
			}
			ImGui.popStyleVar(2);
			ImGui.popStyleColor(3);
			if (atCap) ImGui.endDisabled();
		}
		ImGui.endChild();
		ImGui.popStyleVar(2);
		ImGui.popStyleColor(2);
	}

	// ----------------------------------------------------------------
	// Creation Wizard
	// ----------------------------------------------------------------

	function openWizard(mode:String):Void {
		wizardMode = mode; wizardStep = 0; wizardSignal = ""; wizardSubject = "";
		wizardFight = ""; wizardBehavior = "whileTrue"; wizardBossId = ""; wizardCatalogSearch = "";
		solarflare.ui.ByteUtil.clearBytes(wizardSubjectBuf, 128);
		solarflare.ui.ByteUtil.clearBytes(wizardCatalogSearchBuf, 96);
		solarflare.ui.ByteUtil.clearBytes(wizardFightBuf, 32);
		wizardOpenRequest = true;
	}

	function drawWizardModal():Void {
		if (wizardOpenRequest) { ImGui.openPopup("New Aura###ab_wizard_modal"); wizardOpenRequest = false; }
		if (!ImGui.beginPopupModal("New Aura###ab_wizard_modal", null, imgui.Enums.ImGuiWindowFlags.AlwaysAutoResize)) return;
		try {
			switch (wizardMode) {
				case "boss": drawWizardBoss();
				case "skill": drawWizardSkill();
				case "utility": drawWizardUtility();
				default: ImGui.textWrapped("Unknown mode.");
			}
			ImGui.separator();
			if (ImGui.button("Cancel##ab_wiz_cancel", ImGui.vec2(100, 28))) ImGui.closeCurrentPopup();
		} catch (e:Dynamic) { ImGui.endPopup(); throw e; }
		ImGui.endPopup();
	}

	function drawWizardBoss():Void {
		ImGui.separatorText("Boss / Encounter Aura");
		ImGui.textWrapped("Tracks a boss mechanic, cast, or phase event.");
		ImGui.spacing();
		if (wizardStep == 0) {
			formLabel("Encounter (optional - leave blank for all)");
			var currentFight = wizardFight.length == 0 ? "All encounters (shared)" : wizardFight;
			ImGui.setNextItemWidth(300);
			if (ImGui.beginCombo("##wiz_fight_sel", currentFight)) {
				if (ImGui.selectable("All encounters (shared)##wiz_scope_shared", wizardFight.length == 0)) {
					wizardFight = "";
					ByteUtil.clearBytes(wizardFightBuf, 32);
				}
				for (fight in AuraPack.FIGHTS) {
					if (fight == "shared") continue;
					if (ImGui.selectable(fight + "##wiz_f_" + fight, wizardFight == fight)) {
						wizardFight = fight;
						ByteUtil.fillBuf(wizardFightBuf, 32, fight);
					}
				}
				ImGui.endCombo();
			}
			ImGui.textDisabled("Or enter custom encounter tag:");
			ImGui.setNextItemWidth(300);
			if (ImGui.inputText("##wiz_fight", wizardFightBuf, 32)) wizardFight = readBytes(wizardFightBuf, 32);
			ImGui.spacing();
			formLabel("Boss / mechanic source (optional)");
			var selectedBoss = AuraQuickStartCatalog.boss(wizardBossId);
			var bossPreview = selectedBoss != null ? selectedBoss.name : "Choose a boss for ability suggestions...";
			ImGui.setNextItemWidth(360);
			if (ImGui.beginCombo("##wiz_boss_catalog", bossPreview)) {
				if (ImGui.selectable("No boss filter##wiz_boss_none", wizardBossId.length == 0)) {
					wizardBossId = "";
					selectWizardSubject("");
				}
				for (boss in AuraQuickStartCatalog.bosses) {
					var selected = wizardBossId == boss.id;
					if (ImGui.selectable(boss.name + "##wiz_boss_" + boss.id, selected)) {
						wizardBossId = boss.id;
						selectWizardSubject("");
					}
					if (ImGui.isItemHovered()) ImGui.setTooltip(boss.id);
				}
				ImGui.endCombo();
			}
			ImGui.textDisabled("Used only to offer data.cdb ability choices; encounter scope stays independent.");
			ImGui.spacing();
			ImGui.textWrapped("Pick what to watch for:");
			if (ImGui.selectable("Enemy cast / channel  (by spell name)", false)) { wizardSignal = "event.cast.active"; wizardStep = 1; }
			if (ImGui.selectable("Enemy cast age (seconds since last cast)", false)) { wizardSignal = "event.cast.recent"; wizardStep = 1; }
			if (ImGui.selectable("Target is boss", false)) { wizardSignal = "target.isBoss"; wizardStep = 2; }
			if (ImGui.selectable("Target HP percent", false)) { wizardSignal = "target.hpRatio"; wizardStep = 2; }
			if (ImGui.selectable("Buff/debuff on me (boss-applied status)", false)) { wizardSignal = "status.present"; wizardStep = 1; }
			if (ImGui.selectable("Damage taken spike", false)) { wizardSignal = "combat.damageTakenRecent"; wizardStep = 2; }
		}
		if (wizardStep == 1) {
			var needsSubject = wizardSignal == "event.cast.active" || wizardSignal == "event.cast.recent" || wizardSignal == "status.present";
			if (needsSubject) {
				var prompt = StringTools.startsWith(wizardSignal, "event.cast") ? "Spell / ability name (ID)" : "Status / buff name (ID)";
				formLabel(prompt);
				if (StringTools.startsWith(wizardSignal, "event.cast") && wizardBossId.length > 0)
					drawWizardBossAbilityPicker();
				drawWizardCatalogPicker("##wiz_boss_subject_catalog", wizardSignal == "status.present" ? "status" : "skill",
					wizardSignal == "status.present" ? "Browse status catalog..." : "Browse all skills...");
				ImGui.setNextItemWidth(300);
				if (ImGui.inputText("##wiz_subject", wizardSubjectBuf, 128)) wizardSubject = readBytes(wizardSubjectBuf, 128);
				ImGui.textDisabled("The selected display name is saved with the authoritative skill/status ID.");
			}
			ImGui.spacing();
			if (ImGui.button("<- Back##wiz_boss_b1", ImGui.vec2(80, 28))) wizardStep = 0;
			ImGui.sameLine();
			if (ImGui.button("Next ->##wiz_boss_next", ImGui.vec2(100, 28))) wizardStep = 2;
		}
		if (wizardStep == 2) {
			formLabel("Show alert");
			ImGui.setNextItemWidth(280);
			if (ImGui.beginCombo("##wiz_behavior", behaviorLabel(wizardBehavior))) {
				for (key in ["whileTrue", "onRiseHold", "whileFalse"])
					if (ImGui.selectable(behaviorLabel(key) + "##wiz_beh_" + key, wizardBehavior == key)) wizardBehavior = key;
				ImGui.endCombo();
			}
			ImGui.spacing();
			if (ImGui.button("<- Back##wiz_boss_back", ImGui.vec2(80, 28))) {
				wizardStep = (wizardSignal == "target.isBoss" || wizardSignal == "target.hpRatio" || wizardSignal == "combat.damageTakenRecent") ? 0 : 1;
			}
			ImGui.sameLine();
			if (UiChrome.accentButton("Create Aura##wiz_boss_create", ImGui.vec2(120, 28))) { finishWizard(); ImGui.closeCurrentPopup(); }
		}
	}

	function drawWizardSkill():Void {
		ImGui.separatorText("Skill Aura");
		ImGui.textWrapped("Track a skill cooldown, cast, or proc.");
		ImGui.spacing();
		if (wizardStep == 0) {
			if (GeauxCache.slots != null && GeauxCache.slots.length > 0) {
				var hasAny = false;
				for (s in GeauxCache.slots) if (s != null && s.present && s.id.length > 0) { hasAny = true; break; }
				if (hasAny) {
					ImGui.textDisabled("Equipped Hero Skills (click to select):");
					for (s in GeauxCache.slots) {
						if (s == null || !s.present || s.id.length == 0) continue;
						var sLabel = s.label.length > 0 ? s.label : s.id;
						if (ImGui.smallButton(sLabel + "##wiz_sk_" + s.index)) {
							selectWizardSubject(s.id);
						}
						ImGui.sameLine();
					}
					ImGui.newLine();
				}
			}
			formLabel("Skill");
			drawWizardCatalogPicker("##wiz_skill_catalog", "skill", "Browse data.cdb skills...");
			formLabel("Exact skill ID (optional)");
			ImGui.setNextItemWidth(300);
			if (ImGui.inputText("##wiz_skill", wizardSubjectBuf, 128)) wizardSubject = readBytes(wizardSubjectBuf, 128);
			ImGui.textDisabled("Pick from data.cdb, choose an equipped skill, or enter an exact ID.");
			ImGui.spacing();
			ImGui.textWrapped("What to track:");
			if (ImGui.selectable("Cooldown ready (not on CD)", false)) { wizardSignal = "skill.ready"; wizardStep = 1; }
			if (ImGui.selectable("In cooldown", false)) { wizardSignal = "skill.inCooldown"; wizardStep = 1; }
			if (ImGui.selectable("Cooldown time left", false)) { wizardSignal = "skill.cooldownLeft"; wizardStep = 1; }
			if (ImGui.selectable("Instant cast ready (script)", false)) { wizardSignal = "skill.instantReady"; wizardStep = 1; }
			if (ImGui.selectable("Skill affordable", false)) { wizardSignal = "skill.affordable"; wizardStep = 1; }
			if (ImGui.selectable("Charges remaining", false)) { wizardSignal = "skill.charges"; wizardStep = 1; }
		}
		if (wizardStep == 1) {
			var d = AuraSignalCatalog.find(wizardSignal);
			ImGui.textWrapped("Signal: " + (d != null ? d.label : wizardSignal));
			ImGui.textWrapped('Skill: "${wizardSubject.length > 0 ? wizardSubjectLabel(wizardSubject) : "(none)"}"');
			if (wizardSubject.length == 0)
				ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "! Tip: You can type a skill ID or pick one in the Build tab.");
			ImGui.spacing();
			formLabel("Show alert");
			ImGui.setNextItemWidth(280);
			if (ImGui.beginCombo("##wiz_skill_beh", behaviorLabel(wizardBehavior))) {
				for (key in ["whileTrue", "onRiseHold", "whileFalse"])
					if (ImGui.selectable(behaviorLabel(key) + "##wiz_skbeh_" + key, wizardBehavior == key)) wizardBehavior = key;
				ImGui.endCombo();
			}
			ImGui.spacing();
			if (ImGui.button("<- Back##wiz_skill_back", ImGui.vec2(80, 28))) wizardStep = 0;
			ImGui.sameLine();
			if (UiChrome.accentButton("Create Aura##wiz_skill_create", ImGui.vec2(120, 28))) { finishWizard(); ImGui.closeCurrentPopup(); }
		}
	}

	function drawWizardUtility():Void {
		ImGui.separatorText("Utility Aura");
		ImGui.textWrapped("Common non-boss patterns.");
		ImGui.spacing();
		if (wizardStep == 0) {
			if (ImGui.selectable("Resource threshold (HP/Rage/Mana %)", false)) { wizardSignal = "resource.health.ratio"; wizardStep = 1; }
			if (ImGui.selectable("Buff / debuff on me", false)) { wizardSignal = "status.present"; wizardStep = 1; }
			if (ImGui.selectable("Buff stacks on me", false)) { wizardSignal = "status.stacks"; wizardStep = 1; }
			if (ImGui.selectable("Combo points", false)) { wizardSignal = "resource.combo.count"; wizardStep = 1; }
			if (ImGui.selectable("Combo at max", false)) { wizardSignal = "resource.combo.atMax"; wizardStep = 1; }
			if (ImGui.selectable("Target HP percent", false)) { wizardSignal = "target.hpRatio"; wizardStep = 1; }
			if (ImGui.selectable("In rift / encounter", false)) { wizardSignal = "encounter.inRift"; wizardStep = 1; }
			if (ImGui.selectable("Has current target", false)) { wizardSignal = "target.valid"; wizardStep = 1; }
			if (ImGui.selectable("Damage taken spike", false)) { wizardSignal = "combat.damageTakenRecent"; wizardStep = 1; }
			if (ImGui.selectable("Counter (increment each trigger)", false)) { wizardSignal = "status.count"; wizardStep = 1; }
		}
		if (wizardStep == 1) {
			var d = AuraSignalCatalog.find(wizardSignal);
			ImGui.textWrapped("Tracking: " + (d != null ? d.label : wizardSignal));
			if (d != null && d.subjectKind.length > 0) {
				formLabel("Subject (" + d.subjectKind + ")");
				drawWizardCatalogPicker("##wiz_util_subject_catalog", d.subjectKind.indexOf("status") >= 0 ? "status" : "skill",
					d.subjectKind.indexOf("status") >= 0 ? "Browse status catalog..." : "Browse subject catalog...");
				ImGui.setNextItemWidth(280);
				if (ImGui.inputText("##wiz_util_subj", wizardSubjectBuf, 128)) wizardSubject = readBytes(wizardSubjectBuf, 128);
			}
			ImGui.spacing();
			formLabel("Show alert");
			ImGui.setNextItemWidth(280);
			if (ImGui.beginCombo("##wiz_util_beh", behaviorLabel(wizardBehavior))) {
				for (key in ["whileTrue", "onRiseHold", "whileFalse"])
					if (ImGui.selectable(behaviorLabel(key) + "##wiz_utbeh_" + key, wizardBehavior == key)) wizardBehavior = key;
				ImGui.endCombo();
			}
			ImGui.spacing();
			if (ImGui.button("<- Back##wiz_util_back", ImGui.vec2(80, 28))) wizardStep = 0;
			ImGui.sameLine();
			if (UiChrome.accentButton("Create Aura##wiz_util_create", ImGui.vec2(120, 28))) { finishWizard(); ImGui.closeCurrentPopup(); }
		}
	}

	function drawWizardBossAbilityPicker():Void {
		var boss = AuraQuickStartCatalog.boss(wizardBossId);
		if (boss == null || boss.skills.length == 0) return;
		var preview = wizardSubject.length > 0 ? wizardSubjectLabel(wizardSubject) : "Choose a boss ability...";
		ImGui.setNextItemWidth(360);
		if (ImGui.beginCombo("##wiz_boss_ability", preview)) {
			for (skill in boss.skills) {
				var label = skill.name != null && skill.name.length > 0 ? skill.name : wizardSubjectLabel(skill.id);
				if (ImGui.selectable(label + "##wiz_boss_skill_" + skill.id, wizardSubject == skill.id))
					selectWizardSubject(skill.id);
				if (ImGui.isItemHovered()) ImGui.setTooltip(skill.id);
			}
			ImGui.endCombo();
		}
	}

	function drawWizardCatalogPicker(id:String, kind:String, prompt:String):Void {
		var preview = wizardSubject.length > 0 ? wizardSubjectLabel(wizardSubject) : prompt;
		ImGui.setNextItemWidth(360);
		if (!ImGui.beginCombo(id, preview)) return;
		if (ImGui.inputText(id + "_search", wizardCatalogSearchBuf, 96))
			wizardCatalogSearch = readBytes(wizardCatalogSearchBuf, 96);
		ImGui.separator();
		if (StringTools.trim(wizardCatalogSearch).length < 2) {
			ImGui.textDisabled("Type at least 2 characters to search names or IDs.");
			ImGui.endCombo();
			return;
		}

		var shown = 0;
		var childOpen = ImGui.beginChild(id + "_results", ImGui.vec2(440, 260), ImGuiChildFlags.Borders);
		if (childOpen) {
			for (entry in AuraCatalog.entries) {
				var matchesKind = kind == "status"
					? AuraCatalog.matchesSubject(entry.kind, "status")
					: entry.kind == kind;
				if (!matchesKind || !AuraCatalog.entryMatchesSearch(entry, wizardCatalogSearch)) continue;
				if (shown >= 200) break;
				if (ImGui.selectable(entry.name + "##wiz_catalog_" + entry.id, wizardSubject == entry.id)) {
					selectWizardSubject(entry.id);
					ImGui.closeCurrentPopup();
				}
				if (ImGui.isItemHovered()) ImGui.setTooltip(entry.id);
				shown++;
			}
			if (shown == 0) ImGui.textDisabled("No matching data.cdb entries.");
			else if (shown >= 200) ImGui.textDisabled("Showing the first 200 matches; refine the search.");
		}
		ImGui.endChild();
		ImGui.endCombo();
	}

	function selectWizardSubject(id:String):Void {
		wizardSubject = id;
		ByteUtil.fillBuf(wizardSubjectBuf, 128, id);
		wizardCatalogSearch = "";
		ByteUtil.clearBytes(wizardCatalogSearchBuf, 96);
	}

	function wizardSubjectLabel(id:String):String {
		if (id == null || id.length == 0) return "";
		var label = wizardSubjectName(id);
		return label != null && label.length > 0 && label != id ? label + " [" + id + "]" : id;
	}

	function wizardSubjectName(id:String):String {
		if (id == null || id.length == 0) return "";
		var label = AuraCatalog.label(id);
		if (label == null || label.length == 0) label = AuraQuickStartCatalog.skillName(id);
		if (label == null || label.length == 0) label = CdbAuraTable.name(id);
		return label != null && label.length > 0 ? label : id;
	}

	function finishWizard():Void {
		if (cfg.auras.length >= AuraEngine.MAX) return;
		snapshot("Create Aura (Wizard)");
		var index = cfg.auras.length + 1;
		var auraName = "New Aura " + index;
		if (wizardSubject.length > 0) {
			auraName = wizardSubjectName(wizardSubject);
		} else if (wizardSignal.length > 0) {
			var d = AuraSignalCatalog.find(wizardSignal);
			if (d != null) auraName = d.label;
		}
		var a = new AuraDef(uniqueAuraId("aura_" + index), auraName);
		a.rule = new solarflare.aura.signal.AuraRuleDef();
		a.enabled.set(false);
		if (wizardFight.length > 0) { a.fight = wizardFight; a.syncFightBuf(); }
		if (wizardSignal.length > 0) {
			var c = new solarflare.aura.signal.AuraConditionDef();
			c.signal = wizardSignal;
			if (wizardSubject.length > 0) {
				c.subject = wizardSubject;
				c.subjectLabel = wizardSubjectName(wizardSubject);
			}
			var desc = AuraSignalCatalog.find(wizardSignal);
			if (desc != null) {
				c.op = AuraConditionValidator.defaultOperator(desc);
				c.numberValue = desc.kind == AuraValueKind.Percent ? 0.35 : 1;
				c.boolValue = true;
			}
			a.rule.conditions.push(c);
		}
		if (wizardMode == "utility" && wizardSignal == "status.count") {
			a.isCounter.set(true);
		}
		applyBehavior(a, wizardBehavior);
		cfg.auras.push(a);
		selected = cfg.auras.length - 1;
		deleteArmed = -1;
		workspaceTab = 0;
		tabSelectRequest = 0;
		SettingsStore.markDirty();
		ToastManager.success("Aura created - configure conditions in the Build tab.");
	}

	// ----------------------------------------------------------------
	// Aura list + context menu (preserved)
	// ----------------------------------------------------------------

	function drawAuraList():Void {
		var visibleIds:Array<String> = [];
		var visibleIndices:Array<Int> = [];
		for (i in 0...cfg.auras.length) {
			var a = cfg.auras[i];
			if (a == null || !matchesFilter(a)) continue;
			visibleIds.push(a.id);
			visibleIndices.push(i);
		}
		for (vi in 0...visibleIndices.length) {
			var i = visibleIndices[vi];
			var a = cfg.auras[i];
			if (a == null) continue;
			ImGui.pushID_Str(a.id);
			try {
			var eyeLabel = a.enabled.get() ? "O##ab_eye" : "-##ab_eye";
			if (ImGui.smallButton(eyeLabel)) { a.enabled.set(!a.enabled.get()); SettingsStore.markDirty(); }
			ImGui.sameLine();
			var state = setupIssue(a).length > 0 ? " SETUP" : "";
			var displayName = a.name.length > 0 ? a.name : a.id;
			var rowSelected = isAuraSelected(a.id) || selected == i;
			if (ImGui.selectable(displayName + state + "##ab_item", rowSelected)) {
				applyManagedSelect(a.id, visibleIds);
				if (selected != i) { canvasSel = -1; lastGlowAuraId = ""; }
				selected = i;
				deleteArmed = -1;
			}
			if (ImGui.isItemClicked(1)) {
				selected = i; selectedIds = new Map(); selectedIds.set(a.id, true); rangeAnchorId = a.id; deleteArmed = -1;
				ImGui.openPopup("ab_ctx_pop_" + a.id);
			}
			drawAuraItemContextMenu(i, a);
			if (DragDropHelper.beginAuraDrag(i, displayName)) DragDropHelper.endAuraDrag();
			var droppedIdx = DragDropHelper.acceptAuraDrop(i);
			if (droppedIdx >= 0 && droppedIdx < cfg.auras.length && droppedIdx != i) {
				snapshot("Reorder Aura");
				var moved = cfg.auras.splice(droppedIdx, 1)[0];
				cfg.auras.insert(i, moved);
				selected = i;
				if (moved != null) { selectedIds = new Map(); selectedIds.set(moved.id, true); rangeAnchorId = moved.id; }
				SettingsStore.markDirty();
			}
			} catch (e:Dynamic) { ImGui.popID(); throw e; }
			ImGui.popID();
		}
		if (visibleIndices.length == 0) ImGui.textDisabled("No auras match.");
	}

	function drawAuraItemContextMenu(index:Int, a:AuraDef):Void {
		if (ImGui.beginPopup("ab_ctx_pop_" + a.id) || ImGui.beginPopupContextItem("##ab_ctx_" + a.id, 1)) {
			try {
			ImGui.separatorText('${a.name}');
			if (ImGui.menuItem(a.enabled.get() ? "Disable Aura" : "Enable Aura")) {
				a.enabled.set(!a.enabled.get()); SettingsStore.markDirty();
				ToastManager.info(a.enabled.get() ? '${a.name} enabled' : '${a.name} disabled');
			}
			if (ImGui.menuItem("Duplicate Aura")) {
				snapshot("Duplicate Aura");
				var copy = AuraConfig.cloneAura(a, uniqueAuraId(a.id + "_copy"), a.name + " Copy");
				if (copy != null && cfg.auras.length < AuraEngine.MAX) { cfg.auras.push(copy); selected = cfg.auras.length - 1; SettingsStore.markDirty(); ToastManager.success('Duplicated: ${a.name}'); }
			}
			if (ImGui.menuItem("Copy Aura Share Key")) {
				var share = ShareCodec.wrapJson(Json.stringify(AuraEngine.toObj(a)));
				UiActionQueue.copyText(share, 'Copied share key for ${a.name}');
			}
			if (a.isCounter.get() && ImGui.menuItem("Reset Counter")) { a.counterValue = 0; a.stacks = 1; SettingsStore.markDirty(); ToastManager.info('Counter reset for ${a.name}'); }
			ImGui.separator();
			if (ImGui.menuItem("Delete Aura")) {
				snapshot('Delete ${a.name}');
				cfg.auras.splice(index, 1);
				selected = cfg.auras.length > 0 ? Std.int(Math.min(index, cfg.auras.length - 1)) : -1;
				SettingsStore.markDirty(); ToastManager.info('Deleted ${a.name}');
			}
			} catch (e:Dynamic) { ImGui.endPopup(); throw e; }
			ImGui.endPopup();
		}
	}

	// ----------------------------------------------------------------
	// Batch / multi-select (preserved)
	// ----------------------------------------------------------------

	function drawBatchToolbar():Void {
		var n = countSelected();
		if (n <= 0) return;
		ImGui.text('Selected: $n'); ImGui.sameLine();
		if (ImGui.smallButton("Enable##ab_batch_en")) { snapshot("Batch Enable"); forEachSelected(a -> a.enabled.set(true)); SettingsStore.markDirty(); ToastManager.info("Enabled " + n + " aura(s)"); }
		ImGui.sameLine();
		if (ImGui.smallButton("Disable##ab_batch_dis")) { snapshot("Batch Disable"); forEachSelected(a -> a.enabled.set(false)); SettingsStore.markDirty(); ToastManager.info("Disabled " + n + " aura(s)"); }
		ImGui.sameLine();
		if (ImGui.smallButton("Export##ab_batch_exp")) {
			var pack:Array<AuraDef> = []; forEachSelected(a -> pack.push(a));
			var share = try AuraPack.encode("shared", "selection", "export", pack) catch (_) "";
			if (share.length > 0) UiActionQueue.enqueue(UiActionKind.ExportAuraSelection(share, n + " aura(s) exported as share key"));
		}
		ImGui.sameLine();
		if (ImGui.smallButton("Clear Selection##ab_batch_clr")) { selectedIds = new Map(); rangeAnchorId = ""; }
		if (ImGui.isKeyPressed(ImGuiKey.Escape, false)) { selectedIds = new Map(); rangeAnchorId = ""; }
	}

	function countSelected():Int { var n = 0; for (_ in selectedIds.keys()) n++; return n; }
	function forEachSelected(fn:AuraDef->Void):Void { if (cfg == null) return; for (a in cfg.auras) if (a != null && selectedIds.exists(a.id)) fn(a); }
	function isAuraSelected(id:String):Bool { return selectedIds.exists(id); }

	function applyManagedSelect(clickedId:String, visibleIds:Array<String>):Void {
		var isShift = ImGui.isKeyDown(ImGuiKey.LeftShift) || ImGui.isKeyDown(ImGuiKey.RightShift);
		var isCtrl = ImGui.isKeyDown(ImGuiKey.LeftCtrl) || ImGui.isKeyDown(ImGuiKey.RightCtrl);
		if (isShift && rangeAnchorId.length > 0) {
			var start = visibleIds.indexOf(rangeAnchorId); var end = visibleIds.indexOf(clickedId);
			if (start < 0) start = end; if (end < 0) end = start;
			if (start > end) { var t = start; start = end; end = t; }
			if (!isCtrl) selectedIds = new Map();
			for (k in start...end + 1) if (k >= 0 && k < visibleIds.length) selectedIds.set(visibleIds[k], true);
		} else if (isCtrl) {
			if (selectedIds.exists(clickedId)) selectedIds.remove(clickedId); else selectedIds.set(clickedId, true);
			rangeAnchorId = clickedId;
		} else { selectedIds = new Map(); selectedIds.set(clickedId, true); rangeAnchorId = clickedId; }
	}

	// ----------------------------------------------------------------
	// Inspector sub-draws (all preserved)
	// ----------------------------------------------------------------

	function drawGlowAndFuse(a:AuraDef):Void {
		builderSectionHeader("Glow & Fuse");
		iconGlowRef.set(a.iconGlow);
		if (ImGui.checkbox("Icon Glow##ab_icon_glow", iconGlowRef)) { a.iconGlow = iconGlowRef.get(); SettingsStore.markDirty(); }
		syncGlowColor(a);
		ImGui.sameLine();
		ImGui.setNextItemWidth(120);
		if (ImGui.colorEdit4("##ab_glow_col", glowColBuf, imgui.Enums.ImGuiColorEditFlags.NoInputs | imgui.Enums.ImGuiColorEditFlags.AlphaBar)) { a.glowColor = packGlowColor(); SettingsStore.markDirty(); }
		if (ImGui.checkbox("Countdown##ab_fx_countdown2", a.showCountdown)) SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.checkbox("Fuse##ab_fx_fuse2", a.showFuse)) SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.checkbox("Bottom fuse##ab_fx_fuse_bot2", a.fuseBottom)) SettingsStore.markDirty();
		ImGui.textDisabled("Forced on when checked. Untoggled still auto for known remaining <=" + Std.string(Std.int(AuraVisualRenderer.AUTO_COUNTDOWN_MAX)) + "s.");
	}

	function syncGlowColor(a:AuraDef):Void {
		if (a == null || a.id == lastGlowAuraId) return;
		lastGlowAuraId = a.id;
		var c = a.glowColor;
		glowColBuf.setF32(0, ((c >> 16) & 0xFF) / 255.0);
		glowColBuf.setF32(4, ((c >> 8) & 0xFF) / 255.0);
		glowColBuf.setF32(8, (c & 0xFF) / 255.0);
		glowColBuf.setF32(12, ((c >>> 24) & 0xFF) / 255.0);
	}

	function packGlowColor():Int {
		var r = Std.int(Math.max(0, Math.min(1, glowColBuf.getF32(0))) * 255);
		var g = Std.int(Math.max(0, Math.min(1, glowColBuf.getF32(4))) * 255);
		var b = Std.int(Math.max(0, Math.min(1, glowColBuf.getF32(8))) * 255);
		var al = Std.int(Math.max(0, Math.min(1, glowColBuf.getF32(12))) * 255);
		return (al << 24) | (r << 16) | (g << 8) | b;
	}

	function drawCanvasElements(a:AuraDef):Void {
		builderSectionHeader("Canvas Elements");
		ImGui.textDisabled("Tokens: {time} {stacks} {name}");
		ImGui.textDisabled("Direct stage drag deferred - canvas locals are unscaled vs outer Scale.");
		if (a.canvasElements == null) a.canvasElements = [];
		if (ImGui.smallButton("+ Text##ab_cv_add_txt")) { snapshot("Canvas Add Text"); a.canvasElements.push(AuraCanvasElement.text("{name}", 8, 8, 16)); canvasSel = a.canvasElements.length - 1; SettingsStore.markDirty(); }
		ImGui.sameLine();
		if (ImGui.smallButton("+ Icon##ab_cv_add_ico")) {
			snapshot("Canvas Add Icon"); var id = a.preferredIconId(); if (id.length == 0) id = "icon";
			a.canvasElements.push(AuraCanvasElement.icon(id, 8, 8, 48, 48)); canvasSel = a.canvasElements.length - 1; SettingsStore.markDirty();
		}
		var i = 0;
		while (i < a.canvasElements.length) {
			var el = a.canvasElements[i];
			if (el == null) { i++; continue; }
			var label = (el.kind == AuraCanvasElement.KIND_ICON ? "Icon" : "Text") + " * " + (el.content.length > 0 ? el.content : "(empty)");
			if (ImGui.selectable(label + "##ab_cv_" + i, canvasSel == i)) canvasSel = i;
			ImGui.sameLine();
			if (ImGui.smallButton("X##ab_cv_del_" + i)) { snapshot("Canvas Delete"); a.canvasElements.splice(i, 1); if (canvasSel >= a.canvasElements.length) canvasSel = a.canvasElements.length - 1; SettingsStore.markDirty(); continue; }
			i++;
		}
		if (canvasSel < 0 || canvasSel >= a.canvasElements.length) return;
		var el = a.canvasElements[canvasSel];
		canvasEditX.set(el.x); canvasEditY.set(el.y);
		canvasEditW.set(el.w > 1 ? el.w : 48); canvasEditH.set(el.h > 1 ? el.h : 48);
		canvasEditFs.set(el.fontSize);
		syncCanvasElementColor(a, el);
		if (ImGui.smallButton("Duplicate##ab_cv_dup")) { snapshot("Canvas Duplicate"); var copy = AuraCanvasElement.fromDyn(el.toObj()); a.canvasElements.insert(canvasSel + 1, copy); canvasSel = canvasSel + 1; SettingsStore.markDirty(); }
		ImGui.sameLine();
		if (ImGui.smallButton("Forward##ab_cv_fwd") && canvasSel < a.canvasElements.length - 1) { snapshot("Canvas Bring Forward"); var tmp = a.canvasElements[canvasSel]; a.canvasElements[canvasSel] = a.canvasElements[canvasSel + 1]; a.canvasElements[canvasSel + 1] = tmp; canvasSel++; SettingsStore.markDirty(); }
		ImGui.sameLine();
		if (ImGui.smallButton("Backward##ab_cv_back") && canvasSel > 0) { snapshot("Canvas Send Backward"); var tmp2 = a.canvasElements[canvasSel]; a.canvasElements[canvasSel] = a.canvasElements[canvasSel - 1]; a.canvasElements[canvasSel - 1] = tmp2; canvasSel--; SettingsStore.markDirty(); }
		formLabel(el.kind == AuraCanvasElement.KIND_ICON ? "Icon ID" : "Text");
		ByteUtil.fillBuf(canvasContentBuf, CANVAS_CONTENT_BUF, el.content != null ? el.content : "");
		ImGui.setNextItemWidth(-1);
		if (ImGui.inputText("##ab_cv_content", canvasContentBuf, CANVAS_CONTENT_BUF)) { el.content = StringTools.trim(readBytes(canvasContentBuf, CANVAS_CONTENT_BUF)); SettingsStore.markDirty(); }
		if (el.kind == AuraCanvasElement.KIND_TEXT) {
			if (ImGui.smallButton("{time}##ab_tok_t")) { el.content += "{time}"; ByteUtil.fillBuf(canvasContentBuf, CANVAS_CONTENT_BUF, el.content); SettingsStore.markDirty(); }
			ImGui.sameLine();
			if (ImGui.smallButton("{stacks}##ab_tok_s")) { el.content += "{stacks}"; ByteUtil.fillBuf(canvasContentBuf, CANVAS_CONTENT_BUF, el.content); SettingsStore.markDirty(); }
			ImGui.sameLine();
			if (ImGui.smallButton("{name}##ab_tok_n")) { el.content += "{name}"; ByteUtil.fillBuf(canvasContentBuf, CANVAS_CONTENT_BUF, el.content); SettingsStore.markDirty(); }
		}
		formLabel("Offset X");
		if (solarflare.ui.BuilderSlider.draw("##ab_cv_x", canvasEditX, -200, 720, "%.0f")) { el.x = canvasEditX.get(); SettingsStore.markDirty(); }
		formLabel("Offset Y");
		if (solarflare.ui.BuilderSlider.draw("##ab_cv_y", canvasEditY, -200, 480, "%.0f")) { el.y = canvasEditY.get(); SettingsStore.markDirty(); }
		if (el.kind == AuraCanvasElement.KIND_ICON) {
			formLabel("Width");
			if (solarflare.ui.BuilderSlider.draw("##ab_cv_w", canvasEditW, 8, 512, "%.0f")) { el.w = canvasEditW.get(); SettingsStore.markDirty(); }
			formLabel("Height");
			if (solarflare.ui.BuilderSlider.draw("##ab_cv_h", canvasEditH, 8, 512, "%.0f")) { el.h = canvasEditH.get(); SettingsStore.markDirty(); }
		} else {
			formLabel("Font size");
			if (solarflare.ui.BuilderSlider.draw("##ab_cv_fs", canvasEditFs, 8, 72, "%.0f")) { el.fontSize = canvasEditFs.get(); SettingsStore.markDirty(); }
		}
		formLabel("Color");
		ImGui.setNextItemWidth(120);
		if (ImGui.colorEdit4("##ab_cv_col", canvasColBuf, imgui.Enums.ImGuiColorEditFlags.NoInputs | imgui.Enums.ImGuiColorEditFlags.AlphaBar)) { el.color = packCanvasColor(); SettingsStore.markDirty(); }
		ImGui.separator();
		builderSectionHeader("Align");
		var auraW = a.w.get() > 1 ? a.w.get() : 96;
		var auraH = a.h.get() > 1 ? a.h.get() : 96;
		if (ImGui.smallButton("Left##ab_cv_al")) { snapshot("Canvas Align"); el.x = 0; SettingsStore.markDirty(); }
		ImGui.sameLine();
		if (ImGui.smallButton("Center H##ab_cv_ach")) { snapshot("Canvas Align"); var ew = measureCanvasElementW(el); el.x = (auraW - ew) * 0.5; SettingsStore.markDirty(); }
		ImGui.sameLine();
		if (ImGui.smallButton("Right##ab_cv_ar")) { snapshot("Canvas Align"); var ewR = measureCanvasElementW(el); el.x = auraW - ewR; SettingsStore.markDirty(); }
		if (ImGui.smallButton("Top##ab_cv_at")) { snapshot("Canvas Align"); el.y = 0; SettingsStore.markDirty(); }
		ImGui.sameLine();
		if (ImGui.smallButton("Center V##ab_cv_acv")) { snapshot("Canvas Align"); var eh = measureCanvasElementH(el); el.y = (auraH - eh) * 0.5; SettingsStore.markDirty(); }
		ImGui.sameLine();
		if (ImGui.smallButton("Bottom##ab_cv_ab")) { snapshot("Canvas Align"); var ehB = measureCanvasElementH(el); el.y = auraH - ehB; SettingsStore.markDirty(); }
	}

	function measureCanvasElementW(el:AuraCanvasElement):Float {
		if (el == null) return 0;
		if (el.kind == AuraCanvasElement.KIND_ICON) return el.w > 1 ? el.w : 48;
		var raw = el.content != null ? el.content : "";
		var fs:Single = el.fontSize > 4 ? el.fontSize : 16;
		ImGui.pushFont(ImGui.getFont(), fs); var ts = ImGui.calcTextSize(raw); ImGui.popFont();
		return ts != null ? ts.x : 0;
	}

	function measureCanvasElementH(el:AuraCanvasElement):Float {
		if (el == null) return 0;
		if (el.kind == AuraCanvasElement.KIND_ICON) return el.h > 1 ? el.h : 48;
		var raw = el.content != null ? el.content : "";
		var fs:Single = el.fontSize > 4 ? el.fontSize : 16;
		ImGui.pushFont(ImGui.getFont(), fs); var ts = ImGui.calcTextSize(raw); ImGui.popFont();
		return ts != null ? ts.y : fs;
	}

	function syncCanvasElementColor(a:AuraDef, el:AuraCanvasElement):Void {
		if (a == null || el == null || (a.id == lastCanvasColorAuraId && canvasSel == lastCanvasColorSel)) return;
		lastCanvasColorAuraId = a.id; lastCanvasColorSel = canvasSel;
		var c = el.color;
		canvasColBuf.setF32(0, ((c >> 16) & 0xFF) / 255.0);
		canvasColBuf.setF32(4, ((c >> 8) & 0xFF) / 255.0);
		canvasColBuf.setF32(8, (c & 0xFF) / 255.0);
		canvasColBuf.setF32(12, ((c >>> 24) & 0xFF) / 255.0);
	}

	function packCanvasColor():Int {
		var r = Std.int(Math.max(0, Math.min(1, canvasColBuf.getF32(0))) * 255);
		var g = Std.int(Math.max(0, Math.min(1, canvasColBuf.getF32(4))) * 255);
		var b = Std.int(Math.max(0, Math.min(1, canvasColBuf.getF32(8))) * 255);
		var al = Std.int(Math.max(0, Math.min(1, canvasColBuf.getF32(12))) * 255);
		return (al << 24) | (r << 16) | (g << 8) | b;
	}

	inline function formLabel(label:String):Void { ImGui.alignTextToFramePadding(); ImGui.text(label); }

	function drawAuraDetails():Void {
		var a = selectedAura(); if (a == null) return;
		formLabel("Aura Name"); ImGui.setNextItemWidth(-1);
		if (ImGui.inputText("##ab_ed_name", a.nameBuf, AuraDef.NAME_BUF)) { a.name = readBytes(a.nameBuf, AuraDef.NAME_BUF); SettingsStore.markDirty(); }
		formLabel("Scope / Encounter"); ImGui.setNextItemWidth(-1);
		var scope = isShared(a) ? "Shared / any encounter" : a.fight;
		if (ImGui.beginCombo("##ab_ed_scope", scope)) {
			if (ImGui.selectable("Shared / any encounter##ab_scope_shared", isShared(a))) { a.fight = ""; a.syncFightBuf(); SettingsStore.markDirty(); }
			for (fight in AuraPack.FIGHTS) {
				if (fight == "shared") continue;
				if (ImGui.selectable(fight + "##ab_fight_" + fight, a.fight == fight)) { a.fight = fight; a.syncFightBuf(); SettingsStore.markDirty(); }
			}
			ImGui.endCombo();
		}
		if (ImGui.collapsingHeader("Custom encounter tag##ab_custom_scope")) {
			formLabel("Tag"); ImGui.setNextItemWidth(-1);
			if (ImGui.inputText("##ab_ed_fight", a.fightBuf, AuraDef.FIGHT_BUF)) { a.fight = readBytes(a.fightBuf, AuraDef.FIGHT_BUF); SettingsStore.markDirty(); }
		}
	}

	function drawIoModal():Void {
		if (ioModalRequest) { ImGui.openPopup("Aura Import / Export##ab_io_modal"); ioModalRequest = false; }
		if (ImGui.beginPopupModal("Aura Import / Export##ab_io_modal", null, imgui.Enums.ImGuiWindowFlags.AlwaysAutoResize)) {
			var a = selectedAura();
			if (a != null) drawShare(a);
			else {
				ImGui.textWrapped("Select an aura to copy its share key, or import a pack into the library.");
				if (ImGui.button("Paste & Import from Clipboard##ab_clip_import_empty", ImGui.vec2(260, 26))) { UiActionQueue.enqueue(UiActionKind.ImportAuraClipboard); setIoStatus("Aura import queued from clipboard.", false); }
				ImGui.sameLine();
				if (ImGui.button("Copy Entire Library##ab_copy_all_empty", ImGui.vec2(180, 26))) { UiActionQueue.enqueue(UiActionKind.ExportAuraPack); setIoStatus("Aura pack export queued.", false); }
				ImGui.inputTextMultiline("##ab_import_area_empty", importBuf, JSON_BUF, ImGui.vec2(520, 120));
				if (ImGui.button("Import from Text Box##ab_do_import_empty", ImGui.vec2(180, 26))) importJson();
				if (ioStatus.length > 0) ImGui.textColored(ioStatusError ? ImGui.vec4(1, 0.35, 0.35, 1) : ImGui.vec4(0.35, 0.9, 0.5, 1), ioStatus);
			}
			ImGui.separator();
			if (ImGui.button("Close##ab_io_close", ImGui.vec2(120, 28))) ImGui.closeCurrentPopup();
			ImGui.endPopup();
		}
	}

	function drawAppearance(a:AuraDef):Void {
		formLabel("Display Style"); ImGui.setNextItemWidth(-1);
		if (ImGui.beginCombo("##ab_region", regionLabel(a.region))) {
			for (rKey in ["bar", "ring", "text", "icon", "canvas"])
				if (ImGui.selectable(regionLabel(rKey) + "##ab_reg_" + rKey, a.region == rKey)) { a.region = rKey; SettingsStore.markDirty(); }
			ImGui.endCombo();
		}
		formLabel("Alert Text"); ImGui.setNextItemWidth(-1);
		if (ImGui.inputText("##ab_announce", a.announceBuf, AuraDef.ANN_BUF)) { a.announce = readBytes(a.announceBuf, AuraDef.ANN_BUF); SettingsStore.markDirty(); }
		if (a.region == "icon" || a.region == "canvas") drawIconPicker(a);
		if (a.region == "bar" || a.region == "ring" || a.region == "icon")
			if (ImGui.checkbox("Show Label##ab_fx_lbl", a.showLabel)) SettingsStore.markDirty();
		if (a.region == "icon" || a.region == "canvas") {
			if (ImGui.checkbox("Progress Ring##ab_fx_ring", a.progressRing)) SettingsStore.markDirty();
			ImGui.sameLine();
			if (ImGui.checkbox("Stack / Count Badge##ab_fx_stacks", a.stackCounter)) SettingsStore.markDirty();
			if (a.region == "canvas") ImGui.textDisabled("Canvas: freeform icon/text placements. Tokens: {time} {stacks} {name}.");
		}
		formLabel("Visual Opacity");
		opacityPercent.set(a.opacity.get() * 100);
		if (solarflare.ui.BuilderSlider.draw("##ab_opacity", opacityPercent, 10, 100, "%.0f%%")) { a.opacity.set(opacityPercent.get() * 0.01); SettingsStore.markDirty(); }
	}

	function drawWindowToggles(a:AuraDef, area:String):Void {
		ImGui.pushID_Str("ab_window_controls_" + area);
		if (ImGui.checkbox("Show Aura##ab_visible", a.enabled)) { if (a.enabled.get()) a.visual.set(true); SettingsStore.markDirty(); }
		ImGui.sameLine();
		if (ImGui.checkbox("Lock##ab_lock", a.chrome.locked)) { cfg.unlockAll.set(false); SettingsStore.markDirty(); }
		ImGui.sameLine();
		if (ImGui.checkbox("Always On##ab_always", a.alwaysOn)) SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.checkbox("Transparent##ab_transparent", a.chrome.transparent)) SettingsStore.markDirty();
		ImGui.popID();
	}

	function drawWindowLayout(a:AuraDef):Void {
		drawWindowToggles(a, "layout");
		ImGui.textWrapped("Always On keeps display visible; conditions still drive counters and alerts.");
		formLabel("Width");
		if (solarflare.ui.BuilderSlider.draw("##ab_w", a.w, 32, 720, "%.0f px")) { a.sizeDirty = true; SettingsStore.markDirty(); }
		formLabel("Height");
		if (solarflare.ui.BuilderSlider.draw("##ab_h", a.h, 24, 480, "%.0f px")) { a.sizeDirty = true; SettingsStore.markDirty(); }
		if (ImGui.checkbox("Show Key Reminder##ab_show_key", a.showKey)) SettingsStore.markDirty();
		if (a.showKey.get()) {
			formLabel("Key Text"); ImGui.setNextItemWidth(-1);
			if (ImGui.inputText("##ab_key", a.keyBuf, AuraDef.KEY_BUF)) { a.keyText = AuraDef.sanitizeKey(readBytes(a.keyBuf, AuraDef.KEY_BUF)); SettingsStore.markDirty(); }
		}
	}

	function drawPreviewCanvas():Void {
		var a = selectedAura(); if (a == null) return;
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
		AuraVisualRenderer.draw(ImGui.getWindowDrawList(), a, x, y, w, h, previewProgress.get(), previewCount.get(), previewCount.get(), false, 1);
		ImGui.dummy(ImGui.vec2(canvasW, 96));
	}

	function drawIconPicker(a:AuraDef):Void {
		var key = a.preferredIconId();
		if (!GameIcons.imageKey(key, 44, 44)) {
			drawIconPlaceholder(key, 44, 44); ImGui.sameLine();
			ImGui.textDisabled(key.length > 0 ? "Icon art is loading or unavailable." : "No automatic icon is available.");
		} else { ImGui.sameLine(); ImGui.textWrapped((a.iconId.length > 0 ? "Custom: " : "Automatic: ") + key); }
		if (a.iconId.length > 0 && ImGui.button("Use Automatic Icon##ab_icon_auto")) { a.iconId = ""; a.plate = ""; a.syncIconBuf(); SettingsStore.markDirty(); }
		formLabel("Custom Icon ID"); ImGui.setNextItemWidth(-1);
		if (ImGui.inputText("##ab_icon_custom", a.iconBuf, AuraDef.ICON_BUF)) { a.iconId = StringTools.trim(readBytes(a.iconBuf, AuraDef.ICON_BUF)); a.plate = ""; SettingsStore.markDirty(); }
		formLabel("Search Icons"); ImGui.setNextItemWidth(-1);
		if (ImGui.inputText("##ab_icon_search", iconSearchBuf, 80)) iconSearch = readBytes(iconSearchBuf, 80).toLowerCase();
		ImGui.setNextItemWidth(110);
		if (ImGui.beginCombo("##ab_icon_kind", iconKindFilter)) {
			for (k in ["All", "Units", "Skills", "Status skills", "Categories", "Icons"])
				if (ImGui.selectable(k + "##ab_icon_kind_" + k, iconKindFilter == k)) iconKindFilter = k;
			ImGui.endCombo();
		}
		ImGui.beginChild("##ab_icon_results", ImGui.vec2(0, 220), ImGuiChildFlags.Borders);
		drawIconCandidates(a);
		ImGui.endChild();
	}

	function drawIconCandidates(a:AuraDef):Void {
		var shown = 0;
		for (entry in solarflare.cdb.AuraCatalog.entries) {
			if (!matchesIconKind(entry.id, entry.kind)) continue;
			if (!matchesIcon(entry.id, entry.name)) continue;
			drawIconChoice(a, entry.id, entry.name, entry.kind);
			shown++;
		}
		ImGui.textDisabled(shown + " matching icons");
	}

	function drawIconChoice(a:AuraDef, id:String, label:String, source:String, fallbackId:String = ""):Void {
		if (!ImGui.isRectVisible(ImGui.vec2(ImGui.getContentRegionAvail().x, 28))) { ImGui.dummy(ImGui.vec2(1, 28)); return; }
		var thumbnailId = id;
		var hasArt = GameIcons.imageKey(thumbnailId, 28, 28);
		if (!hasArt && fallbackId.length > 0 && fallbackId != thumbnailId && GameIcons.imageKey(fallbackId, 28, 28)) { thumbnailId = fallbackId; hasArt = true; }
		if (!hasArt) drawIconPlaceholder(thumbnailId, 28, 28);
		ImGui.sameLine();
		if (ImGui.selectable(label + " [" + source + "]##ab_icon_" + source + "_" + id, a.iconId == thumbnailId)) { a.iconId = thumbnailId; a.plate = ""; a.syncIconBuf(); SettingsStore.markDirty(); }
	}

	function drawIconPlaceholder(id:String, w:Single, h:Single):Void {
		var p = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(w, h));
		var dl = ImGui.getWindowDrawList();
		ImGui.ImDrawList_AddRectFilled(dl, p, ImGui.vec2(p.x + w, p.y + h), ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.13, 0.16, 0.21, 1)), 4);
		ImGui.ImDrawList_AddRect(dl, p, ImGui.vec2(p.x + w, p.y + h), ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.36, 0.45, 0.58, 1)), 4, 1);
		var mark = id != null && id.length > 0 ? id.substr(0, 1).toUpperCase() : "?";
		var ts = ImGui.calcTextSize(mark);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(p.x + (w - ts.x) * 0.5, p.y + (h - ts.y) * 0.5), ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.72, 0.8, 0.92, 1)), mark);
	}

	function drawBehavior(a:AuraDef):Void {
		formLabel("Show Alert"); ImGui.setNextItemWidth(-1);
		var mode = behaviorMode(a);
		if (ImGui.beginCombo("##ab_behavior", behaviorLabel(mode))) {
			for (key in ["whileTrue", "onRiseHold", "whileFalse"])
				if (ImGui.selectable(behaviorLabel(key) + "##ab_behavior_" + key, mode == key)) { applyBehavior(a, key); SettingsStore.markDirty(); }
			ImGui.endCombo();
		}
		var wantDuration = mode == "onRiseHold" || (a.showBanner != null && a.showBanner.get());
		if (wantDuration) {
			formLabel("Display Duration");
			if (solarflare.ui.BuilderSlider.draw("##ab_hold", a.durRef, 0.5, 10, "%.1f s")) {
				a.duration = a.durRef.get();
				for (e in a.effects) if (e != null) { e.hold = a.duration; e.holdRef.set(a.duration); }
				SettingsStore.markDirty();
			}
			ImGui.textDisabled("Fixed hold for cast timers. Follow buff uses live status time when known.");
		}
		if (ImGui.checkbox("Follow buff duration when known##ab_follow_buff", a.followBuffDuration)) SettingsStore.markDirty();
		if (ImGui.checkbox("Count each time the conditions become true##ab_counter", a.isCounter)) SettingsStore.markDirty();
		if (a.isCounter.get()) {
			ImGui.textDisabled("Saved count: " + a.counterValue); ImGui.sameLine();
			if (ImGui.smallButton("Reset Count##ab_reset_count")) { a.counterValue = 0; a.stacks = 1; SettingsStore.markDirty(); }
		}
	}

	function drawBossAlert(a:AuraDef):Void {
		ImGui.separatorText("Large Typed Alert");
		if (ImGui.checkbox("Large typed alert##ab_boss_alert", a.showBanner)) {
			if (a.showBanner.get()) {
				if (!hasAlertEffect(a)) a.effects.push(new AuraEffect("boss_alert", AuraEffect.KIND_ALERT, AuraEffect.WHEN_ON_RISE_HOLD));
				var hold = a.duration > 0.05 ? a.duration : 1.5;
				for (e in a.effects) { if (e == null || e.kind != AuraEffect.KIND_ALERT) continue; e.hold = hold; e.holdRef.set(hold); e.enabled.set(true); }
				a.durRef.set(hold); a.duration = hold;
			} else AuraEffects.disableLargeTypedAlert(a);
			SettingsStore.markDirty();
		}
		if (a.showBanner.get()) {
			formLabel("Alert message");
			if (ImGui.inputTextMultiline("##ab_boss_alert_text", a.bannerBuf, AuraDef.BANNER_BUF, ImGui.vec2(-1, 64))) { a.bannerText = readBytes(a.bannerBuf, AuraDef.BANNER_BUF); SettingsStore.markDirty(); }
			formLabel("Alert size");
			if (solarflare.ui.BuilderSlider.draw("##ab_boss_alert_scale", a.bannerScale, 1, 3, "%.1fx")) SettingsStore.markDirty();
		}
	}

	static function hasAlertEffect(a:AuraDef):Bool {
		if (a == null || a.effects == null) return false;
		for (e in a.effects) if (e != null && e.enabled.get() && e.kind == AuraEffect.KIND_ALERT) return true;
		return false;
	}

	function drawDrmSound(a:AuraDef, collapsed:Bool = true):Void {
		if (collapsed && !ImGui.collapsingHeader("DRM Export Sound##ab_drm_sound")) return;
		ImGui.textDisabled("SolarFlare does not play audio. These settings are included only in DRM exports.");
		if (ImGui.checkbox("Include sound cue in DRM export##ab_audio", a.audio)) SettingsStore.markDirty();
		if (a.audio.get()) {
			var cue = a.cue.length > 0 ? a.cue : "Choose a cue...";
			if (ImGui.beginCombo("Cue##ab_cue", cue)) {
				for (id in AuraPack.CUE_IDS) if (ImGui.selectable(id + "##ab_cue_" + id, a.cue == id)) { a.cue = id; a.syncCueBuf(); SettingsStore.markDirty(); }
				ImGui.endCombo();
			}
			volumePercent.set(a.volume.get() * 100);
			if (solarflare.ui.BuilderSlider.draw("DRM Sound Volume##ab_volume", volumePercent, 0, 100, "%.0f%%")) { a.volume.set(volumePercent.get() * 0.01); SettingsStore.markDirty(); }
		}
	}

	function drawShare(a:AuraDef):Void {
		if (ImGui.collapsingHeader("Share or Back Up##ab_export_sec", imgui.Enums.ImGuiTreeNodeFlags.DefaultOpen)) {
			if (ImGui.button("Copy Selected to Clipboard##ab_copy_sel", ImGui.vec2(190, 26))) {
				exportString = ShareCodec.wrapJson(Json.stringify(AuraEngine.toObj(a)));
				fillBuf(exportBuf, JSON_BUF, exportString);
				UiActionQueue.copyText(exportString, 'Aura "${a.name}" share key copied!');
				setIoStatus('Aura "${a.name}" queued for clipboard copy.', false);
			}
			ImGui.sameLine();
			if (ImGui.button("Copy Entire Library##ab_copy_all", ImGui.vec2(160, 26))) { UiActionQueue.enqueue(UiActionKind.ExportAuraPack); setIoStatus("Aura pack export queued.", false); }
			if (exportString.length > 0) {
				ImGui.textDisabled("Share key preview (canonical string unchanged - use Copy):");
				ImGui.beginChild("##ab_export_preview", ImGui.vec2(-1, 80), ImGuiChildFlags.Borders);
				ImGui.textWrapped(exportString);
				ImGui.endChild();
			}
		}
		if (ImGui.collapsingHeader("Import Aura Share Key / JSON##ab_import_sec", imgui.Enums.ImGuiTreeNodeFlags.DefaultOpen)) {
			if (ImGui.button("Paste & Import from Clipboard##ab_clip_import", ImGui.vec2(220, 26))) { UiActionQueue.enqueue(UiActionKind.ImportAuraClipboard); setIoStatus("Aura import queued from clipboard.", false); }
			ImGui.sameLine();
			if (ImGui.button("Import from Text Box##ab_do_import", ImGui.vec2(160, 26))) importJson();
			ImGui.inputTextMultiline("##ab_import_area", importBuf, JSON_BUF, ImGui.vec2(-1, 70));
		}
		if (ioStatus.length > 0) ImGui.textColored(ioStatusError ? ImGui.vec4(1, 0.35, 0.35, 1) : ImGui.vec4(0.35, 0.9, 0.5, 1), ioStatus);
	}

	function importJson():Void {
		var raw = StringTools.trim(readBytes(importBuf, JSON_BUF));
		if (raw.length < 2) { setIoStatus("Paste Aura share key or JSON before importing.", true); ToastManager.error("Paste Aura share key or JSON before importing."); return; }
		try {
			var json = ShareCodec.unwrapToJson(raw);
			if (json == null) { setIoStatus("Import failed: invalid share key or JSON.", true); ToastManager.error("Import failed: invalid share key or JSON."); return; }
			var imported = importAurasFromJson(json);
			var added = 0; snapshot("Import JSON");
			for (item in imported) { if (item == null || cfg.auras.length >= AuraEngine.MAX) break; item.id = uniqueAuraId(item.id); cfg.auras.push(item); added++; }
			if (added == 0) { setIoStatus(cfg.auras.length >= AuraEngine.MAX ? "The Aura library is full." : "No valid Aura objects were found.", true); ToastManager.error("No valid Aura objects found."); }
			else { selected = cfg.auras.length - 1; deleteArmed = -1; SettingsStore.markDirty(); var msg = added + " Aura(s) imported successfully!"; setIoStatus(msg, false); ToastManager.success(msg); }
		} catch (_:Dynamic) { setIoStatus("Import failed: invalid Aura share key or JSON.", true); ToastManager.error("Import failed: invalid Aura share key or JSON."); }
	}

	function importAurasFromJson(json:String):Array<AuraDef> {
		var d:Dynamic = Json.parse(json);
		if (d == null) return [];
		var isPack = Std.isOfType(d, Array) || (d.auras != null) || (d.kind != null && Std.string(d.kind) == AuraPack.KIND);
		if (!isPack && d.id != null) { JsonSchema.parseAuraImport(json); var a = AuraConfig.fromDyn(d); return a != null ? [a] : []; }
		return AuraPack.unpackAuras(d);
	}

	function addBlankAura():Void {
		if (cfg.auras.length >= AuraEngine.MAX) return;
		var index = cfg.auras.length + 1;
		var a = new AuraDef(uniqueAuraId("aura_" + index), "New Aura " + index);
		a.rule = new solarflare.aura.signal.AuraRuleDef();
		a.enabled.set(false);
		cfg.auras.push(a);
		selected = cfg.auras.length - 1; deleteArmed = -1;
		workspaceTab = 0; tabSelectRequest = 0;
		SettingsStore.markDirty();
	}

	function addTemplate(a:AuraDef):Void {
		if (a == null || cfg.auras.length >= AuraEngine.MAX) return;
		a.id = uniqueAuraId(a.id);
		if (setupIssue(a).length > 0) a.enabled.set(false);
		cfg.auras.push(a);
		selected = cfg.auras.length - 1; deleteArmed = -1;
		workspaceTab = 0; tabSelectRequest = 0;
		SettingsStore.markDirty();
	}

	function duplicateSelected():Void {
		var source = selectedAura(); if (source == null || cfg.auras.length >= AuraEngine.MAX) return;
		var copy = AuraConfig.cloneAura(source, uniqueAuraId(source.id + "_copy"), source.name + " Copy");
		if (copy == null) return;
		cfg.auras.push(copy); selected = cfg.auras.length - 1; deleteArmed = -1; SettingsStore.markDirty();
	}

	function applyBehavior(a:AuraDef, key:String):Void {
		if (key == "onRiseHold") AuraEffects.applyPresetDormant(a);
		else if (key == "whileFalse") AuraEffects.applyPresetOnCd(a);
		else AuraEffects.applyPresetContinuous(a);
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
			if (d != null && d.subjectKind.length > 0 && StringTools.trim(c.subject).length == 0) return "Choose a specific target for the highlighted condition.";
		}
		if (a.region == "text" && StringTools.trim(a.announce).length == 0) return "Enter the text this Aura should show.";
		if ((a.region == "icon" || a.region == "canvas") && a.preferredIconId().length == 0) return "Choose an icon or a condition with an automatic icon.";
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

	function matchesIcon(id:String, label:String):Bool { return solarflare.cdb.AuraCatalog.matchesSearch(id, label, iconSearch); }
	function matchesIconKind(id:String, kind:String):Bool {
		if (iconKindFilter == "All" || iconKindFilter == null || iconKindFilter.length == 0) return true;
		if (iconKindFilter == "Units") return kind == "unit";
		if (iconKindFilter == "Skills") return kind == "skill";
		if (iconKindFilter == "Status skills") return kind == "skill" && solarflare.cdb.AuraCatalog.statusPickRank(id, kind) == 0;
		if (iconKindFilter == "Categories") return kind == "statustype";
		if (iconKindFilter == "Icons") return kind == "icon";
		return true;
	}
	static function contains(value:String, query:String):Bool { return value != null && value.toLowerCase().indexOf(query) >= 0; }
	static function isShared(a:AuraDef):Bool { return a == null || a.fight == null || a.fight.length == 0 || a.fight == "shared"; }
	function selectedAura():AuraDef { return selected >= 0 && selected < cfg.auras.length ? cfg.auras[selected] : null; }
	function uniqueAuraId(requested:String):String { return cfg.allocateAuraId(requested); }
	function setIoStatus(message:String, error:Bool):Void { ioStatus = message; ioStatusError = error; }

	static function regionLabel(region:String):String {
		return switch (region) {
			case "bar": "HUD Status Bar";
			case "ring": "Hero Ring";
			case "text": "Screen Text Banner";
			case "icon": "Icon Alert";
			case "canvas": "Freeform Canvas";
			default: "HUD Status Bar";
		};
	}

	static function fillBuf(buf:hl.Bytes, cap:Int, value:String):Void { ByteUtil.fillBuf(buf, cap, value); }
	static function readBytes(buf:hl.Bytes, cap:Int):String { return ByteUtil.readBytes(buf, cap); }
}
