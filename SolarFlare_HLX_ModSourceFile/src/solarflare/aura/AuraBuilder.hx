package solarflare.aura;

import solarflare.aura.signal.AuraConditionEditor;
import solarflare.aura.signal.AuraSignalCatalog;
import solarflare.aura.signal.AuraConditionValidator;
import solarflare.aura.signal.AuraValueKind;
import solarflare.cdb.CdbAuraTable;
import solarflare.cdb.AuraCatalog;
import solarflare.cdb.AuraQuickStartCatalog;
import solarflare.geaux.GeauxCache;
import solarflare.ui.EditorWindow;
import solarflare.ui.UiChrome;
import solarflare.ui.UiLayout;
import solarflare.ui.UiScope;
import solarflare.ui.BuilderSlider;
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
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import haxe.Json;

/**
 * Aura Builder - 2-column layout: Library (left ~22%) + unified Workspace (right ~78%).
 *
 * Workspace: identity bar + WHEN / THEN, including appearance and live preview.
 *
 * All existing condition/effect/canvas/icon/undo/import-export capability is preserved.
 * Creation mode wizard (Boss / Skill / Utility / Free) adds guided entry without new engine.
 */
class AuraBuilder {
	public var open = new BoolRef(false);
	// Timer checkboxes mirror the exclusive timerMode int and the timerSource pair.
	// Persistent so the draw loop never allocates refs.
	var timerDown = new BoolRef(false);
	var timerUp = new BoolRef(false);
	var useGameTime = new BoolRef(true);
	var cfg:AuraConfig;
	var host:ConfigPanel;
	var selected:Int = -1;
	var deleteArmed:Int = -1;
	var selectedIds:Map<String, Bool> = new Map();
	var rangeAnchorId:String = "";

	var undoManager = new UndoManager<String>(40);
	var auraSearch = new SearchBar("Filter auras by name, signal, or target...", 128);

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

	var boundEditorAura:AuraDef = null;
	var creationHomeOpen:Bool = true;
	var creationScrollToGallery:Bool = false;

	var canvasSel:Int = -1;
	var canvasEditX = new FloatRef(0);
	var canvasEditY = new FloatRef(0);
	var canvasEditW = new FloatRef(48);
	var canvasEditH = new FloatRef(48);
	var canvasEditFs = new FloatRef(16);
	var canvasColBuf:hl.Bytes;
	var lastCanvasColorAuraId:String = "";
	var lastCanvasColorSel:Int = -1;
	var glowColBuf:hl.Bytes;
	var lastGlowAuraId:String = "";
	var canvasContentBuf = new hl.Bytes(160);
	/** Separate buffer so the Display card's inline field never aliases the Canvas Elements field. */
	var canvasQuickBuf = new hl.Bytes(160);
	static inline var CANVAS_CONTENT_BUF:Int = 160;
	var libraryCollapsed:Bool = false;
	var buildFocusBossId:String = "";

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
	var wizardPreset:String = "";
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
		solarflare.ui.ByteUtil.clearBytes(canvasQuickBuf, CANVAS_CONTENT_BUF);
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
			boundEditorAura = null;
			canvasSel = -1;
			lastGlowAuraId = "";
			lastCanvasColorAuraId = "";
			lastCanvasColorSel = -1;
			selected = cfg.auras.length > 0 ? 0 : -1;
			creationHomeOpen = selected < 0;
			deleteArmed = -1;
			SettingsStore.markDirty();
		} catch (_:Dynamic) {}
	}

	public function clearTransientState():Void {
		boundEditorAura = null;
		canvasSel = -1;
		lastGlowAuraId = "";
		lastCanvasColorAuraId = "";
		lastCanvasColorSel = -1;
		selected = -1;
		creationHomeOpen = true;
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

		EditorWindow.drawMenuWindow("Aura Builder###SolarFlare.AuraBuilder", open, 1480, 920, function() {
			drawMenuBar();
			drawTopToolbar();
			ImGui.separator();

			var avail = ImGui.getContentRegionAvail();
			var paneH:Single = avail.y < 280 ? 280 : avail.y;
			// Collapsible library rail: 36px collapsed vs ~22% expanded.
			var leftW:Single = libraryCollapsed ? 36 : avail.x * 0.22;
			if (!libraryCollapsed && leftW < 200) leftW = 200;
			var rightW:Single = avail.x - leftW - 10;
			if (rightW < 280) rightW = 280;

			// Outer panes: NoScrollbar — only tab/list inner UiScope.child scrolls.
			solarflare.ui.UiChrome.celChild("##ab_list", ImGui.vec2(leftW, paneH), drawLeftPane,
				ImGuiWindowFlags.NoScrollbar);
			ImGui.sameLine();
			solarflare.ui.UiChrome.celChild("##ab_workspace", ImGui.vec2(rightW > 0 ? rightW : 0, paneH), drawWorkspace,
				ImGuiWindowFlags.NoScrollbar);

			drawIoModal();
			drawWizardModal();
		}, false, true);
	}

	/** F6-style native menu bar — workspace navigation + IO without cluttering the strip. */
	function drawMenuBar():Void {
		if (!ImGui.beginMenuBar())
			return;
		if (ImGui.beginMenu("Open")) {
			if (ImGui.menuItem("SolarFlare Hub", "F6") && host != null)
				host.open.set(true);
			if (ImGui.menuItem("Geaux Builder") && host != null && host.geauxBuilder != null)
				host.geauxBuilder.open.set(true);
			if (ImGui.menuItem("Resource Tracker") && host != null && host.resourceTracker != null)
				host.resourceTracker.open.set(true);
			if (ImGui.menuItem("Notebook") && host != null && host.notebook != null)
				host.notebook.open.set(true);
			ImGui.endMenu();
		}
		if (ImGui.beginMenu("File")) {
			if (ImGui.menuItem("Save", "Ctrl+S"))
				UiActionQueue.save();
			if (ImGui.menuItem("Import from Clipboard"))
				importFromClipboardQueued();
			if (ImGui.menuItem("Export Pack to Clipboard"))
				exportPackQueued();
			if (ImGui.menuItem("Import / Export…"))
				ioModalRequest = true;
			ImGui.separator();
			if (ImGui.menuItem("Reset Dock Layout"))
				UiActionQueue.enqueue(UiActionKind.ResetDockLayout);
			ImGui.endMenu();
		}
		if (ImGui.beginMenu("Aura")) {
			if (ImGui.menuItem("Creation Home"))
				creationHomeOpen = true;
			if (ImGui.menuItem("Create Blank Aura"))
				createBlankFromHome();
			if (ImGui.menuItem("Duplicate Selected", null, false, selectedAura() != null))
				duplicateSelected();
			ImGui.separator();
			if (ImGui.menuItem("Enable Aura System", null, cfg.enabled.get())) {
				cfg.enabled.set(!cfg.enabled.get());
				SettingsStore.markDirty();
				ToastManager.info(cfg.enabled.get() ? "Aura system enabled" : "Aura system suspended");
			}
			ImGui.endMenu();
		}
		if (ImGui.beginMenu("Edit")) {
			var canUndo = undoManager.canUndo();
			var canRedo = undoManager.canRedo();
			if (ImGui.menuItem("Undo", "Ctrl+Z", false, canUndo)) {
				var currentJson = try Json.stringify(AuraPack.toObj("shared", "current", "undo", cfg.auras)) catch (_) "";
				var snap = undoManager.undo(currentJson);
				if (snap != null)
					restoreSnapshot(snap);
			}
			if (ImGui.menuItem("Redo", "Ctrl+Y", false, canRedo)) {
				var currentJson = try Json.stringify(AuraPack.toObj("shared", "current", "undo", cfg.auras)) catch (_) "";
				var snap = undoManager.redo(currentJson);
				if (snap != null)
					restoreSnapshot(snap);
			}
			ImGui.endMenu();
		}
		if (ImGui.beginMenu("View")) {
			// 3rd arg is `selected`, not `enabled` — the old guard painted a checkmark
			// while editing instead of disabling on an empty library.
			if (ImGui.menuItem("Edit My Auras", null, false, cfg.auras.length > 0))
				openWorkspace();
			if (ImGui.menuItem("Replay tutorial"))
				openWizard("tutorial");
			ImGui.endMenu();
		}
		ImGui.endMenuBar();
	}

	function drawTopToolbar():Void {
		// Single compact header line:
		// [x] Enable | Profile combo [Save][New][Copy][Delete] | Status | [Undo][Redo] | * Unsaved
		if (ImGui.checkbox("Enable##ab_system_enable", cfg.enabled)) {
			SettingsStore.markDirty();
			ToastManager.info(cfg.enabled.get() ? "Aura system enabled" : "Aura system suspended");
		}
		ImGui.sameLine(0, 10);
		// Inline bar: combo + Save/New/Copy/Delete on same line, no subHeader row.
		FeatureProfiles.drawInlineBar(host, "ab");
		ImGui.sameLine(0, 12);
		drawStatusPill();
		ImGui.sameLine(0, 12);
		var currentJson = try Json.stringify(AuraPack.toObj("shared", "current", "undo", cfg.auras)) catch (_) "";
		undoManager.drawButtons(currentJson, restoreSnapshot);
		if (SettingsStore.isDirty()) { ImGui.sameLine(0, 12); ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "* Unsaved"); }

		// Resolve after profile and Undo/Redo actions, which may replace cfg.auras.
		var a = selectedAura();
		if (a != null) {
			var toggleW:Single = 302;
			var remaining = ImGui.getContentRegionAvail().x;
			if (remaining >= toggleW + 8) {
				ImGui.sameLine(0, 8);
				ImGui.setCursorPosX(ImGui.getCursorPosX() + Math.max(0, ImGui.getContentRegionAvail().x - toggleW));
			} else {
				ImGui.newLine();
				var rowX = ImGui.getCursorPosX();
				ImGui.setCursorPosX(rowX + Math.max(0, ImGui.getContentRegionAvail().x - toggleW));
			}
			drawWindowToggles(a);
		}
	}

	function drawStatusPill():Void {
		if (creationHomeOpen) { ImGui.textColored(solarflare.ui.ThemePalette.current().accent, "CREATION HOME"); return; }
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
	// Workspace (right panel, unified)
	// ----------------------------------------------------------------

	function drawWorkspace():Void {
		var a = selectedAura();
		if (creationHomeOpen || a == null) {
			drawCreationHome();
			return;
		}
		if (boundEditorAura != a) {
			boundEditorAura = a;
			canvasSel = -1;
			lastGlowAuraId = "";
			lastCanvasColorAuraId = "";
			lastCanvasColorSel = -1;
		}
		drawAuraIdentityBar(a);
		if (creationHomeOpen) return;
		drawMainPane(a);
	}

	function openWorkspace():Void {
		if (cfg == null || cfg.auras.length == 0) return;
		if (selectedAura() == null) {
			selected = 0;
			selectedIds = new Map();
			var first = cfg.auras[0];
			if (first != null) { selectedIds.set(first.id, true); rangeAnchorId = first.id; }
		}
		creationHomeOpen = false;
	}

	function drawCreationHome():Void {
		var avail = ImGui.getContentRegionAvail();
		UiScope.child("##ab_creation_home_scroll", ImGui.vec2(0, avail.y), function() {
			var theme = solarflare.ui.ThemePalette.current();
			var heroBg = ImGui.vec4(
				theme.windowBg.x * 0.62 + theme.accent.x * 0.38,
				theme.windowBg.y * 0.72 + theme.accent.y * 0.28,
				theme.windowBg.z * 0.72 + theme.accent.z * 0.28, 0.98);
			ImGui.pushStyleColor(ImGuiCol.ChildBg, heroBg);
			ImGui.pushStyleColor(ImGuiCol.Border, theme.accent);
			ImGui.pushStyleVar(ImGuiStyleVar.ChildBorderSize, 2.0);
			ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(16, 6));
			UiScope.child("##ab_creation_hero", ImGui.vec2(0, 0), function() {
				var heroW = ImGui.getContentRegionAvail().x;
				UiChrome.heading("Create an Aura", 1.72);
				centeredText("Start with an intent. SolarFlare will prepare the conditions and presentation for review.", false);
				ImGui.spacing();
				if (heroW >= 720) {
					UiLayout.inlineSplit("##ab_creation_steps", 3, function(index:Int, cellW:Single) {
						var label = switch (index) {
							case 0: "1  Choose a starting point";
							case 1: "2  Review WHEN and THEN";
							default: "3  Create and fine-tune";
						};
						centeredText(label, true);
					}, 10);
				} else {
					centeredText("1  Choose a starting point", true);
					centeredText("2  Review WHEN and THEN", true);
					centeredText("3  Create and fine-tune", true);
				}
				// Force ImGui layout bounding box to encompass full card width and height before EndChild
				ImGui.dummy(ImGui.vec2(heroW, 2));
			}, ImGuiChildFlags.Borders | ImGuiChildFlags.AutoResizeY | ImGuiChildFlags.AlwaysUseWindowPadding);
			ImGui.popStyleVar(2);
			ImGui.popStyleColor(2);
			var previous = selectedAura();
			if (previous != null) {
				if (UiChrome.ghostButton("Back to " + previous.name + "##ab_creation_back", ImGui.vec2(-1, 30)))
					creationHomeOpen = false;
			} else if (cfg.auras.length > 0) {
				// "+ Create Aura" clears the selection, so the Back button above erases
				// itself on the one path that reaches this screen. openWorkspace reselects.
				if (UiChrome.ghostButton("Edit My Auras (" + cfg.auras.length + ")##ab_creation_edit", ImGui.vec2(-1, 30)))
					openWorkspace();
			}

			ImGui.dummy(ImGui.vec2(0, 4));
			UiChrome.subHeader("Encounter starters");
			// setScrollHereY must fire at the target widget's Y position, not at the
			// hero block above it. Placing it here (after the subHeader) scrolls the
			// outer child so the gallery is flush at the top of the visible area.
			if (creationScrollToGallery) {
				ImGui.setScrollHereY(0.0);
				creationScrollToGallery = false;
			}
			solarflare.aura.ui.AuraBossPortraitStrip.draw(
				buildFocusBossId,
				selectedAura(),
				function(id:String) buildFocusBossId = id,
				function() snapshot("Boss portrait action"),
				function(created:AuraDef) acceptBossStarterAura(created),
				true
			);

			ImGui.dummy(ImGui.vec2(0, 4));
			UiLayout.inlinePair("##ab_creation_start_hdr", function(w:Single) {
				UiChrome.sectionHeader("How would you like to start?");
			}, function(w:Single) {
				if (previous == null && cfg.auras.length > 0) {
					if (UiChrome.ghostButton("Edit Auras (" + cfg.auras.length + ")##ab_creation_edit_hdr", ImGui.vec2(w, 26)))
						openWorkspace();
				} else if (UiChrome.ghostButton("Replay tutorial##ab_creation_tut", ImGui.vec2(w, 26)))
					openWizard("tutorial");
			}, 12);
			ImGui.textDisabled("Pick a row. Lists use the full width — they are not packed into cards.");
			ImGui.spacing();

			var atCap = cfg.auras.length >= AuraEngine.MAX;
			if (atCap) {
				ImGui.textColored(theme.textDisabled, "Aura limit reached. Delete an Aura before creating another.");
				ImGui.beginDisabled();
			}
			drawCreationLists(atCap);
			if (atCap) ImGui.endDisabled();

			ImGui.spacing();
			UiChrome.subHeader("Popular starting points");
			centeredText("Fast starts using the same editable Aura system.", true);
			drawCreationTemplates(atCap);
		});
	}

	function drawCreationLists(atCap:Bool):Void {
		drawUtilityList(0);
		ImGui.dummy(ImGui.vec2(0, 18));
		drawSkillList(0);
		ImGui.dummy(ImGui.vec2(0, 18));
		drawBlankList(0);
	}

	function drawHomeRow(label:String, id:String, onPick:Void->Void):Void {
		if (ImGui.selectable(label + "##" + id, false))
			onPick();
	}

	function drawUtilityList(_:Single):Void {
		UiChrome.sectionHeader("Utilities");
		ImGui.textDisabled("Everyday signals");
		ImGui.dummy(ImGui.vec2(0, 4));
		drawHomeRow("Resource threshold (HP/Rage/Mana %)", "home_util_res", function() createFromHome("utility", "resource.health.ratio", ""));
		drawHomeRow("Buff / debuff on me", "home_util_buff", function() createFromHome("utility", "status.present", ""));
		drawHomeRow("Track status stacks on me", "home_util_stacks", function() createFromHome("utility", "status.stacks", ""));
		drawHomeRow("Combo points", "home_util_combo", function() createFromHome("utility", "resource.combo.count", ""));
		drawHomeRow("Combo at max", "home_util_combo_max", function() createFromHome("utility", "resource.combo.atMax", ""));
		drawHomeRow("Target HP percent", "home_util_thp", function() createFromHome("utility", "target.hpRatio", ""));
		drawHomeRow("In rift / encounter", "home_util_rift", function() createFromHome("utility", "encounter.inRift", ""));
		drawHomeRow("In rift boss fight", "home_util_boss", function() createFromHome("utility", "encounter.inBossFight", ""));
		drawHomeRow("Rift timer remaining", "home_util_rtm", function() createFromHome("utility", "encounter.riftRemain", ""));
		drawHomeRow("Has current target", "home_util_tgt", function() createFromHome("utility", "target.valid", ""));
		drawHomeRow("Damage taken spike", "home_util_dmg", function() createFromHome("utility", "combat.damageTakenRecent", ""));
		drawHomeRow("Counter (increment each trigger)", "home_util_cnt", function() createFromHome("utility", "status.count", ""));
	}

	function drawSkillList(_:Single):Void {
		UiChrome.sectionHeader("Skills");
		ImGui.textDisabled("Equipped bar, then a cooldown/cast signal");
		ImGui.dummy(ImGui.vec2(0, 4));
		var any = false;
		if (GeauxCache.slots != null) {
			for (s in GeauxCache.slots) {
				if (s == null || !s.present || s.id.length == 0) continue;
				any = true;
				var sLabel = s.label.length > 0 ? s.label : s.id;
				var sid = s.id;
				drawHomeRow(sLabel + "  — ready", "home_sk_" + s.index, function() createFromHome("skill", "skill.ready", sid));
			}
		}
		if (!any)
			ImGui.textDisabled("No equipped skills yet. Use a signal row below, then pick the skill in WHEN.");
		ImGui.dummy(ImGui.vec2(0, 6));
		drawHomeRow("Cooldown ready (not on CD)", "home_sk_ready", function() createFromHome("skill", "skill.ready", ""));
		drawHomeRow("In cooldown", "home_sk_incd", function() createFromHome("skill", "skill.inCooldown", ""));
		drawHomeRow("Cooldown time left", "home_sk_left", function() createFromHome("skill", "skill.cooldownLeft", ""));
		drawHomeRow("Instant cast ready", "home_sk_inst", function() createFromHome("skill", "skill.instantReady", ""));
		drawHomeRow("Skill affordable", "home_sk_aff", function() createFromHome("skill", "skill.affordable", ""));
		drawHomeRow("Charges remaining", "home_sk_chg", function() createFromHome("skill", "skill.charges", ""));
	}

	function drawBlankList(_:Single):Void {
		UiChrome.sectionHeader("Blank Aura");
		ImGui.textDisabled("Empty rule — you already know the WHEN");
		ImGui.dummy(ImGui.vec2(0, 4));
		drawHomeRow("Start blank", "home_blank", function() createBlankFromHome());
		ImGui.dummy(ImGui.vec2(0, 8));
		if (UiChrome.ghostButton("Jump to encounter gallery##home_boss_jump", ImGui.vec2(-1, 26)))
			creationScrollToGallery = true;
	}

	function createFromHome(mode:String, signal:String, subject:String):Void {
		wizardMode = mode;
		wizardSignal = signal;
		wizardSubject = subject != null ? subject : "";
		wizardFight = "";
		wizardBehavior = "whileTrue";
		wizardBossId = "";
		wizardPreset = "";
		if (wizardSubject.length > 0)
			selectWizardSubject(wizardSubject);
		finishWizard();
	}

	function acceptBossStarterAura(created:AuraDef):Void {
		if (created == null || cfg.auras.length >= AuraEngine.MAX) return;
		snapshot("Boss portrait create");
		created.id = uniqueAuraId(created.id);
		cfg.auras.push(created);
		selected = cfg.auras.length - 1;
		selectedIds = new Map();
		selectedIds.set(created.id, true);
		rangeAnchorId = created.id;
		creationHomeOpen = false;
		SettingsStore.markDirty();
		ToastManager.success("Created: " + created.name);
	}

	function drawCreationCard(id:String, kicker:String, title:String, description:String, action:String,
			primary:Bool, onClick:Void->Void, width:Single):Void {
		var theme = solarflare.ui.ThemePalette.current();
		var mix:Single = primary ? 0.20 : 0.07;
		var bg = ImGui.vec4(
			theme.cellBg.x * (1 - mix) + theme.accent.x * mix,
			theme.cellBg.y * (1 - mix) + theme.accent.y * mix,
			theme.cellBg.z * (1 - mix) + theme.accent.z * mix, 0.98);
		ImGui.pushStyleColor(ImGuiCol.ChildBg, bg);
		ImGui.pushStyleColor(ImGuiCol.Border, primary ? theme.accent : theme.border);
		ImGui.pushStyleVar(ImGuiStyleVar.ChildBorderSize, primary ? 2.25 : 1.5);
		ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(16, 13));
		// AutoResizeY lets the card grow to fit content so the action button's
		// full 34px hit rect is never clipped by a fixed client boundary.
		// Width is still fixed; height expands. A minimum dummy of 30px is
		// inserted before the button to guarantee at least the visual push-down.
		UiScope.child("##ab_create_card_" + id, ImGui.vec2(width, 0), function() {
			ImGui.textColored(primary ? theme.accent : theme.textDisabled, kicker);
			var font = ImGui.getFont();
			if (font != null) ImGui.pushFont(font, ImGui.getFontSize() * 1.28);
			ImGui.text(title);
			if (font != null) ImGui.popFont();
			ImGui.textWrapped(description);
			// Guarantee at least 6px breathing room between the description and
			// the action button; AutoResizeY absorbs whatever height is needed.
			ImGui.spacing();
			ImGui.spacing();
			var clicked = primary
				? UiChrome.accentButton(action + "##ab_create_" + id, ImGui.vec2(-1, 34))
				: UiChrome.ghostButton(action + "##ab_create_" + id, ImGui.vec2(-1, 34));
			if (clicked && onClick != null) onClick();
		}, ImGuiChildFlags.Borders | ImGuiChildFlags.AutoResizeY | ImGuiChildFlags.AlwaysUseWindowPadding);
		ImGui.popStyleVar(2);
		ImGui.popStyleColor(2);
	}

	function drawCreationTemplates(disabled:Bool):Void {
		if (disabled) ImGui.beginDisabled();
		drawHomeRow("Emergency Low Health", "ab_home_low_hp", function() addHomeTemplate(AuraTemplates.createEmergencyLowHpAlert(), "Low Health"));
		drawHomeRow("Track Status Stacks on Me", "ab_home_stacks", function() addHomeTemplate(AuraTemplates.createBuffStackTracker(), "Stack Tracker"));
		drawHomeRow("Demonic Charge Stacks", "ab_home_demonic", function() addHomeTemplate(AuraTemplates.createDemonicChargeStacks(), "Demonic Charge"));
		drawHomeRow("Pyroclasm Proc", "ab_home_pyro", function() addHomeTemplate(AuraTemplates.createPyroclasmProcAlert(), "Pyroclasm"));
		drawHomeRow("Conduit Stacks", "ab_home_conduit", function() addHomeTemplate(AuraTemplates.createConduitStacksAlert(), "Conduit"));
		drawHomeRow("Chaincast Ready", "ab_home_chain", function() addHomeTemplate(AuraTemplates.createChaincastReadyAlert(), "Chaincast"));
		drawHomeRow("Life Prayer Ready", "ab_home_prayer", function() addHomeTemplate(AuraTemplates.createPrayerLifeReadyAlert(), "Life Prayer"));
		drawHomeRow("Rift Boss Fight", "ab_home_riftboss", function() addHomeTemplate(AuraTemplates.createRiftBossFightAlert(), "Rift Boss"));
		drawHomeRow("Enemy Spell Cast", "ab_home_cast", function() addHomeTemplate(AuraTemplates.createEnemySpellCastAlert(), "Enemy Spell Cast"));
		drawHomeRow("Heavy Damage Warning", "ab_home_damage", function() addHomeTemplate(AuraTemplates.createDamageTakenSpike(), "Damage Warning"));
		if (disabled) ImGui.endDisabled();
	}

	function addHomeTemplate(a:AuraDef, label:String):Void {
		if (cfg.auras.length >= AuraEngine.MAX) {
			ToastManager.error("Aura library full (max " + AuraEngine.MAX + "). Delete an aura first.");
			return;
		}
		snapshot("Add Template");
		addTemplate(a);
		var issue = setupIssue(a);
		if (issue.length > 0)
			ToastManager.info("Template: " + label + " — " + issue);
		else
			ToastManager.success("Template: " + label);
	}

	function createBlankFromHome():Void {
		if (cfg.auras.length >= AuraEngine.MAX) {
			ToastManager.error("Aura library full (max " + AuraEngine.MAX + "). Delete an aura first.");
			return;
		}
		snapshot("Create Aura");
		addBlankAura();
		// addBlankAura already sets selected, selectedIds, creationHomeOpen=false,
		// and marks dirty.
		ToastManager.success("New blank aura created.");
	}

	function centeredText(value:String, disabled:Bool):Void {
		var start = ImGui.getCursorPosX();
		var available = ImGui.getContentRegionAvail().x;
		var size = ImGui.calcTextSize(value);
		if (size.x > available) {
			if (disabled) {
				ImGui.pushStyleColor(ImGuiCol.Text, solarflare.ui.ThemePalette.current().textDisabled);
				ImGui.textWrapped(value);
				ImGui.popStyleColor();
			} else ImGui.textWrapped(value);
			return;
		}
		ImGui.setCursorPosX(start + Math.max(0, (available - size.x) * 0.5));
		// Text submits ItemSize and returns X to the current column origin. A
		// trailing SetCursorPosX would be unconsumed when this ends a table cell.
		if (disabled) ImGui.textDisabled(value); else ImGui.text(value);
	}

	// ----------------------------------------------------------------
	// BUILD TAB
	// ----------------------------------------------------------------

	function drawMainPane(a:AuraDef):Void {
		var avail = ImGui.getContentRegionAvail();
		if (avail.x < 780) {
			UiScope.child("##ab_unified_scroll", ImGui.vec2(0, 0), function() {
				drawWhenColumn(a);
				drawThenColumn(a);
			});
			return;
		}
		var gap:Single = 8;
		var whenW:Single = (avail.x - gap) * 0.45;
		var thenW:Single = avail.x - gap - whenW;
		var paneH:Single = Math.max(1, avail.y - 4);
		UiChrome.celChild("##ab_build_when", ImGui.vec2(whenW, paneH),
			function() drawWhenColumn(a));
		ImGui.sameLine(0, gap);
		UiChrome.celChild("##ab_build_then", ImGui.vec2(thenW, paneH),
			function() drawThenColumn(a));
	}

	function drawWhenColumn(a:AuraDef):Void {
		drawSectionCard("WHEN", "Conditions that trigger this Aura", true, function() {
			AuraConditionEditor.draw(a, true, function() snapshot("Condition batch"), buildFocusBossId);
			ImGui.spacing();
			var issue = setupIssue(a);
			if (issue.length > 0)
				ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "! " + issue);
		});
	}

	function drawThenColumn(a:AuraDef):Void {
		UiChrome.sectionHeader("THEN");
		drawThenPreview(a);
		drawSectionCard("Display", "Style, timer, counter, alert", false, function() drawAppearance(a));
		drawSectionCard("Window", "", false, function() drawWindowLayout(a));
		if (a.region == "canvas")
			drawSectionCard("Canvas Elements", "", false, function() drawCanvasElements(a));
		drawSectionCard("Alerts and Actions", "", false, function() {
			drawBehavior(a);
			cfg.drawEffects(a, false);
			drawDrmSound(a, true);
		});
	}
	/** Compact Home | Name | Scope identity row; the table owns cursor advancement. */
	function drawAuraIdentityBar(a:AuraDef):Void {
		UiScope.table("##ab_identity", 3, function() {
			ImGui.tableSetupColumn("##home", imgui.Enums.ImGuiTableColumnFlags.WidthFixed, 64);
			ImGui.tableSetupColumn("##name", imgui.Enums.ImGuiTableColumnFlags.WidthStretch, 0.45);
			ImGui.tableSetupColumn("##scope", imgui.Enums.ImGuiTableColumnFlags.WidthStretch, 0.55);
			ImGui.tableNextRow();
			ImGui.tableSetColumnIndex(0);
			if (UiChrome.ghostButton("Home##ab_home", ImGui.vec2(64, 28))) {
				clearTransientState();
				return;
			}
			ImGui.tableSetColumnIndex(1);
			ImGui.alignTextToFramePadding();
			ImGui.text("Name");
			ImGui.sameLine(0, 6);
			ImGui.setNextItemWidth(-1);
			if (ImGui.inputText("##ab_ed_name", a.nameBuf, AuraDef.NAME_BUF)) {
				a.name = readBytes(a.nameBuf, AuraDef.NAME_BUF);
				SettingsStore.markDirty();
			}
			ImGui.tableSetColumnIndex(2);
			ImGui.alignTextToFramePadding();
			ImGui.text("Scope");
			ImGui.sameLine(0, 6);
			drawAuraScope(a);
		}, imgui.Enums.ImGuiTableFlags.SizingStretchProp | imgui.Enums.ImGuiTableFlags.NoSavedSettings);
	}

	function drawAuraScope(a:AuraDef):Void {
		ImGui.setNextItemWidth(-1);
		if (!ImGui.beginCombo("##ab_custom_enc", isShared(a) ? "Shared" : a.fight)) return;
		try {
			if (ImGui.selectable("Shared##ab_scope_shared", isShared(a))) {
				a.fight = "";
				a.syncFightBuf();
				SettingsStore.markDirty();
			}
			for (fight in AuraPack.FIGHTS) {
				if (fight == null || fight == "shared") continue;
				if (ImGui.selectable(fight + "##ab_fight_" + fight, a.fight == fight)) {
					a.fight = fight;
					a.syncFightBuf();
					SettingsStore.markDirty();
				}
			}
			ImGui.separator();
			ImGui.textDisabled("Custom encounter tag");
			ImGui.setNextItemWidth(-1);
			if (ImGui.inputTextWithHint("##ab_ed_fight", "tag id", a.fightBuf, AuraDef.FIGHT_BUF)) {
				a.fight = readBytes(a.fightBuf, AuraDef.FIGHT_BUF);
				SettingsStore.markDirty();
			}
		} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
		ImGui.endCombo();
	}

	/**
	 * Auto-height option card. The workspace owns scrolling; each card owns
	 * its padding, border, header, and balanced child/style scopes.
	 */
	function drawSectionCard(title:String, subtitle:String, primary:Bool, body:Void->Void):Void {
		var theme = solarflare.ui.ThemePalette.current();
		var vars = 0;
		var colors = 0;
		var failed = false;
		var failure:Dynamic = null;
		try {
			ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(8, 8)); vars++;
			ImGui.pushStyleVar(ImGuiStyleVar.ChildBorderSize, 1); vars++;
			ImGui.pushStyleVar(ImGuiStyleVar.ChildRounding, 4); vars++;
			ImGui.pushStyleColor(ImGuiCol.Border, primary ? theme.accent : theme.border); colors++;
			ImGui.pushStyleColor(ImGuiCol.ChildBg, theme.cellBg); colors++;
			UiScope.child("##ab_card_" + title, ImGui.vec2(0, 0), function() {
				var p = ImGui.getCursorScreenPos();
				var w = ImGui.getContentRegionAvail().x;
				var dl = ImGui.getWindowDrawList();
				var bandH:Single = 24;
				var mix:Single = primary ? 0.24 : 0.12;
				var bg = ImGui.vec4(
					theme.cellBg.x * (1 - mix) + theme.accent.x * mix,
					theme.cellBg.y * (1 - mix) + theme.accent.y * mix,
					theme.cellBg.z * (1 - mix) + theme.accent.z * mix, 1);
				ImGui.dummy(ImGui.vec2(w, bandH));
				ImGui.ImDrawList_AddRectFilled(dl, p, ImGui.vec2(p.x + w, p.y + bandH),
					ImGui.colorConvertFloat4ToU32(bg), 3);
				var titleSize = ImGui.calcTextSize(title);
				ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(p.x + 8, p.y + (bandH - titleSize.y) * 0.5),
					ImGui.colorConvertFloat4ToU32(theme.text), title);
				if (subtitle.length > 0 && titleSize.x + ImGui.calcTextSize(subtitle).x + 28 <= w) {
					ImGui.ImDrawList_AddText_Vec2(dl,
						ImGui.vec2(p.x + titleSize.x + 16, p.y + (bandH - titleSize.y) * 0.5),
						ImGui.colorConvertFloat4ToU32(theme.textDisabled), subtitle);
				}
				body();
			}, ImGuiChildFlags.Borders | ImGuiChildFlags.AutoResizeY | ImGuiChildFlags.AlwaysUseWindowPadding,
				ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse);
		} catch (e:Dynamic) { failed = true; failure = e; }
		if (colors > 0) ImGui.popStyleColor(colors);
		if (vars > 0) ImGui.popStyleVar(vars);
		if (failed) throw failure;
		ImGui.spacing();
	}
	inline function builderSectionHeader(label:String):Void {
		UiChrome.subHeader(label);
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
	// DISPLAY / TIMER SHORTCUTS
	// ----------------------------------------------------------------

	static inline var FX_OFF:Int = 0;
	static inline var FX_ON:Int = 1;
	static inline var FX_MIXED:Int = 2;

	function forEachFxTarget(fn:AuraDef->Void):Void {
		if (fn == null) return;
		if (countSelected() > 1) {
			forEachSelected(fn);
			return;
		}
		var a = selectedAura();
		if (a != null) fn(a);
	}

	function fxState(get:AuraDef->Bool):Int {
		var anyOn = false;
		var anyOff = false;
		forEachFxTarget(function(a:AuraDef) {
			if (get(a)) anyOn = true; else anyOff = true;
		});
		if (anyOn && anyOff) return FX_MIXED;
		return anyOn ? FX_ON : FX_OFF;
	}

	function applyFxToTargets(mut:AuraDef->Void):Void {
		if (mut == null) return;
		snapshot("Appearance FX");
		forEachFxTarget(mut);
		SettingsStore.markDirty();
	}

	function drawFxTile(label:String, id:String, state:Int, w:Single, h:Single, onWrite:Bool->Void):Void {
		var isChecked = state == FX_ON;
		var isMixed = state == FX_MIXED;
		if (solarflare.ui.UiChrome.toggleTile("##" + id, label, isChecked, w, h, isMixed)) {
			onWrite(state != FX_ON);
		}
		if (ImGui.isItemHovered() && isMixed)
			ImGui.setTooltip("Mixed across selection — click to enable all");
	}
	function drawAppearanceFxStrip(a:AuraDef):Void {
		if (a == null) return;
		var selectionCount = countSelected();
		if (selectionCount > 1) ImGui.textDisabled("Selection shortcuts — " + selectionCount + " auras");
		var columns = UiLayout.columnCount(ImGui.getContentRegionAvail().x, 108, 2, 6);
		ImGui.pushStyleVar(ImGuiStyleVar.CellPadding, ImGui.vec2(3, 3));
		try {
			UiScope.table("##ab_fx_tiles", columns, function() {
				for (col in 0...columns)
					ImGui.tableSetupColumn("##tile_" + col, imgui.Enums.ImGuiTableColumnFlags.WidthStretch, 1);
				for (i in 0...6) {
					if (i % columns == 0) ImGui.tableNextRow();
					ImGui.tableSetColumnIndex(i % columns);
					var w:Single = ImGui.getContentRegionAvail().x;
					switch (i) {
						case 0: drawFxTile("Glow", "ab_fx_glow", fxState(function(x) return AuraEffects.hasIconGlow(x)), w, 32,
							function(v) applyFxToTargets(function(x) AuraEffects.setIconGlow(x, v)));
						case 1: drawFxTile("Fuse", "ab_fx_fuse", fxState(function(x) return x.showFuse.get()), w, 32,
							function(v) applyFxToTargets(function(x) x.showFuse.set(v)));
						case 2: drawFxTile("CD Bar", "ab_fx_fbot", fxState(function(x) return x.fuseBottom.get()), w, 32,
							function(v) applyFxToTargets(function(x) x.fuseBottom.set(v)));
						case 3: drawFxTile("Label", "ab_fx_lbl", fxState(function(x) return x.showLabel.get()), w, 32,
							function(v) applyFxToTargets(function(x) x.showLabel.set(v)));
						case 4: drawFxTile("Ring", "ab_fx_ring", fxState(function(x) return x.progressRing.get()), w, 32,
							function(v) applyFxToTargets(function(x) x.progressRing.set(v)));
						case 5: drawFxTile("Stacks", "ab_fx_stk", fxState(function(x) return x.stackCounter.get()), w, 32,
							function(v) applyFxToTargets(function(x) {
								x.stackCounter.set(v);
								if (v) x.isCounter.set(false);
							}));
					}
				}
			}, imgui.Enums.ImGuiTableFlags.SizingStretchProp | imgui.Enums.ImGuiTableFlags.NoSavedSettings);
		} catch (e:Dynamic) { ImGui.popStyleVar(); throw e; }
		ImGui.popStyleVar();
		if (a.stackCounter.get() || a.isCounter.get()) {
			UiLayout.propertyGrid("##ab_stack_display", function() {
				UiLayout.propertyRow("Stack position", function() {
					ImGui.setNextItemWidth(-1);
					if (ImGui.beginCombo("##ab_stack_place", stackPlaceLabel(a.stackPlace))) {
						for (p in 0...3)
							if (ImGui.selectable(stackPlaceLabel(p) + "##ab_stackp_" + p, a.stackPlace == p)) {
								a.stackPlace = p;
								SettingsStore.markDirty();
							}
						ImGui.endCombo();
					}
				}, "Places the tracked stack count above, over, or below the aura face.");
				UiLayout.propertyRow("Stack size", function() {
					if (BuilderSlider.draw("##ab_stack_scale", a.stackScale, 0.5, 3, "%.2fx"))
						SettingsStore.markDirty();
				});
			});
		}
		syncGlowColor(a);
		UiLayout.propertyGrid("##ab_fx_glow_col", function() {
			UiLayout.propertyRow("Glow color", function() {
				if (ImGui.colorEdit4("##ab_glow_col", glowColBuf,
						imgui.Enums.ImGuiColorEditFlags.NoInputs | imgui.Enums.ImGuiColorEditFlags.AlphaBar)) {
					a.glowColor = packGlowColor();
					SettingsStore.markDirty();
				}
				if (!AuraEffects.hasIconGlow(a)) {
					ImGui.sameLine(0, 8);
					ImGui.textDisabled("Glow is off");
				}
			}, "Tints the Glow tile above plus the Pulse / Expire / Ready overlays.");
		});
	}

	/**
	 * One timer cluster. Direction, where the span comes from, and how it is shown used
	 * to be three controls in two places: a Timer / source combo pair, a face row that
	 * reused the label "Seconds", and Follow buff duration over in Alerts and Actions.
	 *
	 * Direction is exclusive. An aura carries a single timerValue, so counting both ways
	 * at once would need a second accumulator in AuraTimer.
	 */
	function drawTimerRows(a:AuraDef):Void {
		timerDown.set(a.timerMode == AuraTimer.MODE_DOWN);
		timerUp.set(a.timerMode == AuraTimer.MODE_UP);
		UiLayout.propertyRow("Timer", function() {
			if (ImGui.checkbox("Count down##ab_timer_down", timerDown))
				setTimerMode(a, timerDown.get() ? AuraTimer.MODE_DOWN : AuraTimer.MODE_OFF);
			ImGui.sameLine(0, 14);
			if (ImGui.checkbox("Count up##ab_timer_up", timerUp))
				setTimerMode(a, timerUp.get() ? AuraTimer.MODE_UP : AuraTimer.MODE_OFF);
		}, "Counts on the rising edge of this aura's condition.");

		if (a.timerMode != AuraTimer.MODE_OFF) {
			useGameTime.set(a.timerSource == AuraTimer.SRC_FOLLOW);
			UiLayout.propertyRow("Seconds", function() {
				UiLayout.inlinePair("##ab_timer_secs_pair", function(_:Single) {
					if (ImGui.checkbox("Use the game's time##ab_timer_follow", useGameTime)) {
						a.timerSource = useGameTime.get() ? AuraTimer.SRC_FOLLOW : AuraTimer.SRC_FIXED;
						// Same question Alerts and Actions used to ask separately.
						if (a.followBuffDuration != null) a.followBuffDuration.set(useGameTime.get());
						AuraTimer.reset(a);
						if (!useGameTime.get()) primeTimerSeconds(a);
						SettingsStore.markDirty();
					}
					if (!useGameTime.get() && BuilderSlider.draw("##ab_timer_secs", a.timerSeconds, 1, 600, "%.0f s"))
						SettingsStore.markDirty();
				}, function(_:Single) {
					var listed = listedTimerSpan(a);
					if (listed <= 0.05)
						return;
					var subject = a.timingSubjectId();
					var field = solarflare.cdb.CdbAuraTable.listedSpanSource(subject);
					var shown = Math.round(listed * 10) / 10;
					var following = useGameTime.get();
					if (ImGui.smallButton("Listed: " + shown + "s##ab_timer_listed")) {
						// Applying a baked span means a fixed timer by definition, so following
						// the game's own span is turned off here rather than making the user
						// find the checkbox first. Same state the checkbox itself writes.
						if (following) {
							useGameTime.set(false);
							a.timerSource = AuraTimer.SRC_FIXED;
							if (a.followBuffDuration != null) a.followBuffDuration.set(false);
							AuraTimer.reset(a);
						}
						a.timerSeconds.set(listed);
						SettingsStore.markDirty();
					}
					if (ImGui.isItemHovered())
						ImGui.setTooltip("CastleDB lists " + shown + "s " + field + " for " + subject + "."
							+ (following ? " Click to use it as a fixed span (turns off \"Use the game's time\")." : " Click to use it."));
				});
			}, "Where the span comes from: the live buff / cooldown the game reports, or your own number.");
		}

		UiLayout.propertyRow("On the aura", function() {
			UiLayout.inlinePair("##ab_cd_face", function(_:Single) {
				if (ImGui.checkbox("Show seconds##ab_cd_force", a.showCountdown)) SettingsStore.markDirty();
			}, function(w:Single) {
				if (!a.showCountdown.get())
					return;
				ImGui.setNextItemWidth(w);
				if (ImGui.beginCombo("##ab_cd_place", countdownPlaceLabel(a.countdownPlace))) {
					for (p in 0...3)
						if (ImGui.selectable(countdownPlaceLabel(p) + "##ab_cdp_" + p, a.countdownPlace == p)) {
							a.countdownPlace = p;
							SettingsStore.markDirty();
						}
					ImGui.endCombo();
				}
			});
			ImGui.textDisabled(timingReadout(a));
		}, "Prints the tracked seconds on the aura face: the live status time when the game reports one, else the CastleDB span, else the timer above.");

		if (a.showCountdown.get())
			UiLayout.propertyRow("Seconds size", function() {
				if (BuilderSlider.draw("##ab_cd_scale", a.countdownScale, 0.5, 3, "%.2fx")) SettingsStore.markDirty();
			});

		if (a.timerMode != AuraTimer.MODE_OFF)
			UiLayout.propertyRow("Timers window", function() {
				UiLayout.inlinePair("##ab_timer_board_pair", function(_:Single) {
					if (ImGui.checkbox("Show in Timers##ab_timer_board", a.timerBoard)) SettingsStore.markDirty();
				}, function(_:Single) {
					if (BuilderSlider.draw("Keep at 0##ab_timer_linger", a.timerKeepExpired, 0, 30, "%.0f s")) SettingsStore.markDirty();
				});
			}, "Stacks this timer in the movable Timers window. Keep at 0 is how long the finished row lingers.");
	}

	/** Exclusive: ticking both directions would need a second accumulator in AuraTimer. */
	function setTimerMode(a:AuraDef, mode:Int):Void {
		a.timerMode = mode;
		AuraTimer.reset(a);
		if (mode != AuraTimer.MODE_OFF) {
			a.showCountdown.set(true);
			primeTimerSeconds(a);
		}
		SettingsStore.markDirty();
	}

	/** Seeds a fixed timer with the subject's listed CDB span while the value is untouched. */
	function primeTimerSeconds(a:AuraDef):Void {
		var listed = listedTimerSpan(a);
		if (listed > 0.05 && Math.abs(a.timerSeconds.get() - 60) < 0.01)
			a.timerSeconds.set(listed);
	}

	inline function listedTimerSpan(a:AuraDef):Float {
		return solarflare.cdb.CdbAuraTable.listedSpan(a.timingSubjectId());
	}

	function timingReadout(a:AuraDef):String {
		var subj = a.timingSubjectId();
		var cdb = listedTimerSpan(a);
		var grant = CdbAuraTable.grantedStatusId(subj);
		var live = a.timerInfinite ? "inf" : (Math.isFinite(a.timeLeft) ? (Math.round(a.timeLeft * 10) / 10) + "s" : "unknown");
		var baked = cdb > 0.05 ? (Math.round(cdb * 10) / 10) + "s" : "none";
		var extra = grant.length > 0 && grant != subj ? " via " + grant : "";
		var mod = CdbAuraTable.listedSpanMod(subj);
		if (mod.length > 0)
			baked += " (" + mod + ")";
		return "Live " + live + " · CastleDB " + baked + extra;
	}

	/** Kill / activation counter, kept beside the timer since users reach for both. */
	function drawCounterRow(a:AuraDef):Void {
		UiLayout.propertyRow("Counter", function() {
			if (ImGui.checkbox("Count activations##ab_counter", a.isCounter)) {
				if (a.isCounter.get())
					a.stackCounter.set(false);
				SettingsStore.markDirty();
			}
			if (!a.isCounter.get())
				return;
			ImGui.sameLine(0, 8);
			ImGui.textDisabled("= " + a.counterValue);
			ImGui.sameLine(0, 6);
			if (ImGui.smallButton("Reset##ab_reset_count")) {
				a.counterValue = 0;
				a.stacks = 1;
				SettingsStore.markDirty();
			}
		}, "Increments every time the condition becomes true. Survives reloads. Mutually exclusive with the Stacks badge.");
	}

	function drawThenPreview(a:AuraDef):Void {
		var width = ImGui.getContentRegionAvail().x;
		var previewW:Single = Math.max(160, Math.min(220, width * 0.38));
		UiScope.table("##ab_preview_controls", 2, function() {
			ImGui.tableSetupColumn("##preview", imgui.Enums.ImGuiTableColumnFlags.WidthFixed, previewW);
			ImGui.tableSetupColumn("##controls", imgui.Enums.ImGuiTableColumnFlags.WidthStretch, 1);
			ImGui.tableNextRow();
			ImGui.tableSetColumnIndex(0);
			advancedPreview.draw(a, previewW, previewW, false, true);
			if (ImGui.isItemHovered()) ImGui.setTooltip("Live preview of the current settings.");
			drawSummaryBlock(a, previewW);
			ImGui.tableSetColumnIndex(1);
			UiChrome.subHeader("Display shortcuts");
			drawAppearanceFxStrip(a);
		}, imgui.Enums.ImGuiTableFlags.SizingStretchProp | imgui.Enums.ImGuiTableFlags.NoSavedSettings);
		ImGui.separator();
	}

	/** Plain-language rule beside the preview, so WHEN and THEN stay paired while scrolling. */
	function drawSummaryBlock(a:AuraDef, w:Single):Void {
		ImGui.beginGroup();
		try {
			UiChrome.subHeader("This aura");
			var summary = buildSummary(a);
			ImGui.pushTextWrapPos(ImGui.getCursorPosX() + w);
			if (summary.length > 0) ImGui.textWrapped(summary);
			else ImGui.textDisabled("Pick a condition on the left and this fills in.");
			ImGui.popTextWrapPos();
		} catch (e:Dynamic) { ImGui.endGroup(); throw e; }
		ImGui.endGroup();
	}

	// ----------------------------------------------------------------
	// LEFT PANE - Library
	// ----------------------------------------------------------------

	function drawLeftPane():Void {
		if (libraryCollapsed) {
			ImGui.dummy(ImGui.vec2(1, 6));
			if (UiChrome.ghostButton(">>##ab_lib_expand", ImGui.vec2(-1, 28)))
				libraryCollapsed = false;
			if (ImGui.isItemHovered())
				ImGui.setTooltip("Expand Aura Library");
			return;
		}

		UiLayout.inlinePair("##ab_lib_hdr", function(w:Single) {
			solarflare.ui.UiChrome.sectionHeader("Aura Library");
		}, function(w:Single) {
			if (UiChrome.ghostButton("<<##ab_lib_collapse", ImGui.vec2(Math.max(28, w), 28)))
				libraryCollapsed = true;
			if (ImGui.isItemHovered())
				ImGui.setTooltip("Collapse library to rail");
		}, 6);
		ImGui.textDisabled(Std.string(cfg.auras.length) + " / " + AuraEngine.MAX);

		var atCap = cfg.auras.length >= AuraEngine.MAX;
		if (atCap) ImGui.beginDisabled();
		if (creationHomeOpen) {
			// Already on Creation Home — primary button becomes a direct blank-aura
			// shortcut so it is never a silent no-op.
			if (UiChrome.accentButton("+ Quick Blank Aura##ab_quick_blank", ImGui.vec2(-1, 42)))
				createBlankFromHome();
		} else {
			if (UiChrome.accentButton("+ Create Aura##ab_open_creation_home", ImGui.vec2(-1, 42))) {
				creationHomeOpen = true;
				selected = -1;
				selectedIds = new Map();
				rangeAnchorId = "";
				deleteArmed = -1;
				canvasSel = -1;
			}
		}
		if (atCap) ImGui.endDisabled();
		if (creationHomeOpen) {
			// Outside the atCap guard on purpose: a full library is exactly when you
			// need to edit rather than create.
			if (cfg.auras.length > 0 && UiChrome.ghostButton("Edit My Auras##ab_lib_edit", ImGui.vec2(-1, 26)))
				openWorkspace();
			centeredText(atCap ? "Library full" : "Creation Home open", true);
		}
		ImGui.spacing();
		ImGui.separator();
		ImGui.spacing();

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
		UiScope.child("##ab_list_child", ImGui.vec2(0, listH), drawAuraList);
		ImGui.separator();
		if (UiChrome.ghostButton("Import / Export##ab_io_open", ImGui.vec2(-1, 28))) ioModalRequest = true;
	}

	// ----------------------------------------------------------------
	// Creation Wizard
	// ----------------------------------------------------------------

	function openWizard(mode:String):Void {
		wizardMode = mode; wizardStep = 0; wizardSignal = ""; wizardSubject = "";
		wizardFight = ""; wizardBehavior = "whileTrue"; wizardBossId = ""; wizardCatalogSearch = ""; wizardPreset = "";
		solarflare.ui.ByteUtil.clearBytes(wizardSubjectBuf, 128);
		solarflare.ui.ByteUtil.clearBytes(wizardCatalogSearchBuf, 96);
		solarflare.ui.ByteUtil.clearBytes(wizardFightBuf, 32);
		wizardOpenRequest = true;
	}

	function openSkillReadyTemplate():Void {
		openWizard("skill");
		wizardSignal = "skill.ready";
		wizardPreset = "skillReady";
		ToastManager.info("Choose the skill for this template.");
	}

	function drawWizardModal():Void {
		if (wizardOpenRequest) { ImGui.openPopup("New Aura###ab_wizard_modal"); wizardOpenRequest = false; }
		if (!ImGui.beginPopupModal("New Aura###ab_wizard_modal", null, imgui.Enums.ImGuiWindowFlags.AlwaysAutoResize)) return;
		try {
			switch (wizardMode) {
				case "tutorial": drawTutorial();
				case "boss": drawWizardBoss();
				case "skill": drawWizardSkill();
				case "utility": drawWizardUtility();
				default: ImGui.textWrapped("Unknown mode.");
			}
			ImGui.separator();
			if (ImGui.button("Close##ab_wiz_cancel", ImGui.vec2(100, 28))) ImGui.closeCurrentPopup();
		} catch (e:Dynamic) { ImGui.endPopup(); throw e; }
		ImGui.endPopup();
	}

	function drawTutorial():Void {
		UiChrome.heading("Aura tutorial", 1.28);
		ImGui.spacing();
		ImGui.textWrapped("1. Creation Home lists Utilities, Skills, and Blank Aura as rows. Click one to make an Aura — there is no extra modal for that.");
		ImGui.spacing();
		ImGui.textWrapped("2. WHEN is the condition (buff present, skill ready, HP below a percent). Pick a specific status or skill id when the row asks for a subject.");
		ImGui.spacing();
		ImGui.textWrapped("3. THEN is what you see: icon, glow, seconds on the face, fuse. Glow is stored as an icon effect so it survives reloads. Seconds follow the live buff when the game reports remaining time.");
		ImGui.spacing();
		ImGui.textWrapped("4. Status auras should watch the granted status (often *_Proc or *_Status), not the cast skill. CastleDB listed time prefers that duration.");
		ImGui.spacing();
		if (UiChrome.accentButton("Got it##ab_tut_done", ImGui.vec2(120, 28)))
			ImGui.closeCurrentPopup();
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
			if (wizardPreset == "skillReady") {
				ImGui.textWrapped("Template behavior: show when the selected skill is ready.");
				if (wizardSubject.length == 0) ImGui.beginDisabled();
				if (UiChrome.accentButton("Continue##wiz_skill_template_next", ImGui.vec2(120, 28))) wizardStep = 1;
				if (wizardSubject.length == 0) ImGui.endDisabled();
			} else {
				ImGui.textWrapped("What to track:");
				if (ImGui.selectable("Cooldown ready (not on CD)", false)) { wizardSignal = "skill.ready"; wizardStep = 1; }
				if (ImGui.selectable("In cooldown", false)) { wizardSignal = "skill.inCooldown"; wizardStep = 1; }
				if (ImGui.selectable("Cooldown time left", false)) { wizardSignal = "skill.cooldownLeft"; wizardStep = 1; }
				if (ImGui.selectable("Instant cast ready (script)", false)) { wizardSignal = "skill.instantReady"; wizardStep = 1; }
				if (ImGui.selectable("Skill affordable", false)) { wizardSignal = "skill.affordable"; wizardStep = 1; }
				if (ImGui.selectable("Charges remaining", false)) { wizardSignal = "skill.charges"; wizardStep = 1; }
			}
		}
		if (wizardStep == 1) {
			var d = AuraSignalCatalog.find(wizardSignal);
			ImGui.textWrapped("Signal: " + (d != null ? d.label : wizardSignal));
			ImGui.textWrapped('Skill: "${wizardSubject.length > 0 ? wizardSubjectLabel(wizardSubject) : "(none)"}"');
			if (wizardSubject.length == 0)
				ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "! Select a skill before creating this Aura.");
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
			if (wizardSubject.length == 0) ImGui.beginDisabled();
			if (UiChrome.accentButton("Create Aura##wiz_skill_create", ImGui.vec2(120, 28))) { finishWizard(); ImGui.closeCurrentPopup(); }
			if (wizardSubject.length == 0) ImGui.endDisabled();
		}
	}

	function drawWizardUtility():Void {
		ImGui.separatorText("Utility Aura");
		ImGui.textWrapped("Common non-boss patterns.");
		ImGui.spacing();
		if (wizardStep == 0) {
			if (ImGui.selectable("Resource threshold (HP/Rage/Mana %)", false)) { wizardSignal = "resource.health.ratio"; wizardStep = 1; }
			if (ImGui.selectable("Buff / debuff on me", false)) { wizardSignal = "status.present"; wizardStep = 1; }
			if (ImGui.selectable("Track status stacks on me", false)) { wizardSignal = "status.stacks"; wizardStep = 1; }
			if (ImGui.selectable("Combo points", false)) { wizardSignal = "resource.combo.count"; wizardStep = 1; }
			if (ImGui.selectable("Combo at max", false)) { wizardSignal = "resource.combo.atMax"; wizardStep = 1; }
			if (ImGui.selectable("Target HP percent", false)) { wizardSignal = "target.hpRatio"; wizardStep = 1; }
			if (ImGui.selectable("In rift / encounter", false)) { wizardSignal = "encounter.inRift"; wizardStep = 1; }
			if (ImGui.selectable("In rift boss fight", false)) { wizardSignal = "encounter.inBossFight"; wizardStep = 1; }
			if (ImGui.selectable("Rift timer remaining", false)) { wizardSignal = "encounter.riftRemain"; wizardStep = 1; }
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
		var childOpen = ImGui.beginChild(id + "_results", ImGui.vec2(440, 340), ImGuiChildFlags.Borders);
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
				if (StringTools.startsWith(wizardSignal, "status.")) {
					var grant = CdbAuraTable.grantedStatusId(wizardSubject);
					if (grant.length > 0 && grant != wizardSubject) {
						c.subject = grant;
					}
				}
			}
			var desc = AuraSignalCatalog.find(wizardSignal);
			if (desc != null) {
				c.op = AuraConditionValidator.defaultOperator(desc);
				c.numberValue = desc.kind == AuraValueKind.Percent ? 0.35 : 1;
				c.boolValue = true;
			}
			a.rule.conditions.push(c);
		}
		// Keep the declarative condition authoritative while also synchronizing the
		// legacy/presentation fields used by icon lookup and older Aura consumers.
		if (wizardSubject.length > 0) {
			a.iconId = wizardSubject;
			a.syncIconBuf();
			if (wizardMode == "skill" || StringTools.startsWith(wizardSignal, "skill.") || StringTools.startsWith(wizardSignal, "event.cast")) {
				a.skillId = wizardSubject;
				a.syncSkillBuf();
			}
		}
		if (wizardMode == "utility" && wizardSignal == "status.count") {
			a.isCounter.set(true);
		}
		if (StringTools.startsWith(wizardSignal, "status.")) {
			a.region = "icon";
			a.showCountdown.set(true);
			a.followBuffDuration.set(true);
			a.showIcon.set(true);
			// status.stacks is useless without the corner badge — enable it by default.
			if (wizardSignal == "status.stacks") {
				a.stackCounter.set(true);
				a.isCounter.set(false);
			}
		}
		applyBehavior(a, wizardBehavior);
		if (setupIssue(a).length == 0)
			a.enabled.set(true);
		cfg.auras.push(a);
		selected = cfg.auras.length - 1;
		selectedIds = new Map();
		selectedIds.set(a.id, true);
		rangeAnchorId = a.id;
		creationHomeOpen = false;
		deleteArmed = -1;
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
				creationHomeOpen = false;
				deleteArmed = -1;
			}
			if (ImGui.isItemClicked(1)) {
				selected = i; creationHomeOpen = false; 
				selectedIds = new Map(); selectedIds.set(a.id, true); rangeAnchorId = a.id; deleteArmed = -1;
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
				creationHomeOpen = false;
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
				if (copy != null && cfg.auras.length < AuraEngine.MAX) { cfg.auras.push(copy); selected = cfg.auras.length - 1; creationHomeOpen = false; SettingsStore.markDirty(); ToastManager.success('Duplicated: ${a.name}'); }
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
				creationHomeOpen = selected < 0;
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
		UiLayout.propertyGrid("##ab_cv_props", function() {
			UiLayout.propertyRow("Offset", function() {
				UiLayout.inlinePair(
					"##ab_cv_xy",
					function(_:Single) {
						if (BuilderSlider.draw("X##ab_cv_x", canvasEditX, -200, 720, "%.0f")) { el.x = canvasEditX.get(); SettingsStore.markDirty(); }
					},
					function(_:Single) {
						if (BuilderSlider.draw("Y##ab_cv_y", canvasEditY, -200, 480, "%.0f")) { el.y = canvasEditY.get(); SettingsStore.markDirty(); }
					}
				);
			});
			if (el.kind == AuraCanvasElement.KIND_ICON) {
				UiLayout.propertyRow("Size", function() {
					UiLayout.inlinePair(
						"##ab_cv_wh",
						function(_:Single) {
							if (BuilderSlider.draw("W##ab_cv_w", canvasEditW, 8, 512, "%.0f")) { el.w = canvasEditW.get(); SettingsStore.markDirty(); }
						},
						function(_:Single) {
							if (BuilderSlider.draw("H##ab_cv_h", canvasEditH, 8, 512, "%.0f")) { el.h = canvasEditH.get(); SettingsStore.markDirty(); }
						}
					);
				});
			} else {
				UiLayout.propertyRow("Font size", function() {
					if (BuilderSlider.draw("##ab_cv_fs", canvasEditFs, 8, 72, "%.0f")) { el.fontSize = canvasEditFs.get(); SettingsStore.markDirty(); }
				});
			}
			UiLayout.propertyRow("Color", function() {
				ImGui.setNextItemWidth(120);
				if (ImGui.colorEdit4("##ab_cv_col", canvasColBuf, imgui.Enums.ImGuiColorEditFlags.NoInputs | imgui.Enums.ImGuiColorEditFlags.AlphaBar)) {
					el.color = packCanvasColor();
					SettingsStore.markDirty();
				}
			});
		});
		ImGui.separator();
		builderSectionHeader("Align");
		var auraW = a.w.get() > 1 ? a.w.get() : 96;
		var auraH = a.h.get() > 1 ? a.h.get() : 96;
		UiLayout.inlineSplit("##ab_cv_align_h", 3, function(index:Int, cellW:Single) {
			if (index == 0 && ImGui.smallButton("Left##ab_cv_al")) { snapshot("Canvas Align"); el.x = 0; SettingsStore.markDirty(); }
			else if (index == 1 && ImGui.smallButton("Center H##ab_cv_ach")) { snapshot("Canvas Align"); var ew = measureCanvasElementW(el); el.x = (auraW - ew) * 0.5; SettingsStore.markDirty(); }
			else if (index == 2 && ImGui.smallButton("Right##ab_cv_ar")) { snapshot("Canvas Align"); var ewR = measureCanvasElementW(el); el.x = auraW - ewR; SettingsStore.markDirty(); }
		});
		UiLayout.inlineSplit("##ab_cv_align_v", 3, function(index:Int, cellW:Single) {
			if (index == 0 && ImGui.smallButton("Top##ab_cv_at")) { snapshot("Canvas Align"); el.y = 0; SettingsStore.markDirty(); }
			else if (index == 1 && ImGui.smallButton("Center V##ab_cv_acv")) { snapshot("Canvas Align"); var eh = measureCanvasElementH(el); el.y = (auraH - eh) * 0.5; SettingsStore.markDirty(); }
			else if (index == 2 && ImGui.smallButton("Bottom##ab_cv_ab")) { snapshot("Canvas Align"); var ehB = measureCanvasElementH(el); el.y = auraH - ehB; SettingsStore.markDirty(); }
		});
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
		UiLayout.propertyGrid("##ab_ed_details", function() {
			UiLayout.propertyRow("Name", function() {
				if (ImGui.inputText("##ab_ed_name", a.nameBuf, AuraDef.NAME_BUF)) {
					a.name = readBytes(a.nameBuf, AuraDef.NAME_BUF);
					SettingsStore.markDirty();
				}
			});
			UiLayout.propertyRow("Scope", function() {
				var scope = isShared(a) ? "Shared / any encounter" : a.fight;
				if (ImGui.beginCombo("##ab_ed_scope", scope)) {
					if (ImGui.selectable("Shared / any encounter##ab_scope_shared", isShared(a))) {
						a.fight = "";
						a.syncFightBuf();
						SettingsStore.markDirty();
					}
					for (fight in AuraPack.FIGHTS) {
						if (fight == "shared") continue;
						if (ImGui.selectable(fight + "##ab_fight_" + fight, a.fight == fight)) {
							a.fight = fight;
							a.syncFightBuf();
							SettingsStore.markDirty();
						}
					}
					ImGui.endCombo();
				}
			});
		});
		if (ImGui.collapsingHeader("Custom encounter tag##ab_custom_scope")) {
			UiLayout.propertyGrid("##ab_ed_custom_scope", function() {
				UiLayout.propertyRow("Tag", function() {
					if (ImGui.inputText("##ab_ed_fight", a.fightBuf, AuraDef.FIGHT_BUF)) {
						a.fight = readBytes(a.fightBuf, AuraDef.FIGHT_BUF);
						SettingsStore.markDirty();
					}
				});
			});
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
		UiLayout.propertyGrid("##ab_appear_props", function() {
			UiLayout.propertyRow("Style", function() {
				if (ImGui.beginCombo("##ab_region", regionLabel(a.region))) {
					for (rKey in ["bar", "ring", "text", "icon", "canvas"])
						if (ImGui.selectable(regionLabel(rKey) + "##ab_reg_" + rKey, a.region == rKey)) {
							a.region = rKey;
							SettingsStore.markDirty();
						}
					ImGui.separator();
					ImGui.textDisabled("Add-on");
					if (ImGui.selectable("Large Typed Alert##ab_reg_banner", a.showBanner.get()))
						toggleBanner(a);
					ImGui.endCombo();
				}
			}, "The face this aura wears. The add-on prints a large line across the screen on top of it.");
			drawTimerRows(a);
			drawCounterRow(a);
			drawBannerRows(a);
			drawCanvasTextRow(a);
			UiLayout.propertyRow("Alert text", function() {
				if (ImGui.inputText("##ab_announce", a.announceBuf, AuraDef.ANN_BUF)) {
					a.announce = readBytes(a.announceBuf, AuraDef.ANN_BUF);
					SettingsStore.markDirty();
				}
			});
			UiLayout.propertyRow("Opacity", function() {
				opacityPercent.set(a.opacity.get() * 100);
				if (BuilderSlider.draw("##ab_opacity", opacityPercent, 10, 100, "%.0f%%")) {
					a.opacity.set(opacityPercent.get() * 0.01);
					SettingsStore.markDirty();
				}
			});
		});
		if (a.region == "icon" || a.region == "canvas") drawIconPicker(a);
	}

	function drawWindowToggles(a:AuraDef):Void {
		if (a == null) return;
		ImGui.pushID_Str("ab_window_controls_toolbar");
		try {
			if (UiChrome.toggleChip("Show##ab_visible", a.enabled, ImGui.vec2(52, 26))) {
				if (a.enabled.get()) a.visual.set(true);
				SettingsStore.markDirty();
			}
			ImGui.sameLine(0, 6);
			if (UiChrome.toggleChip("Lock##ab_lock", a.chrome.locked, ImGui.vec2(52, 26))) {
				cfg.unlockAll.set(false);
				SettingsStore.markDirty();
			}
			ImGui.sameLine(0, 6);
			if (UiChrome.toggleChip("Always On##ab_always", a.alwaysOn, ImGui.vec2(88, 26)))
				SettingsStore.markDirty();
			if (ImGui.isItemHovered())
				ImGui.setTooltip("Always On keeps display visible; conditions still drive counters and alerts.");
			ImGui.sameLine(0, 6);
			if (UiChrome.toggleChip("Transparent##ab_transparent", a.chrome.transparent, ImGui.vec2(92, 26)))
				SettingsStore.markDirty();
		} catch (e:Dynamic) { ImGui.popID(); throw e; }
		ImGui.popID();
	}

	function drawWindowLayout(a:AuraDef):Void {
		UiLayout.propertyGrid("##ab_window_layout", function() {
			UiLayout.propertyRow("Size", function() {
				UiLayout.inlinePair(
					"##ab_wh",
					function(_:Single) {
						if (BuilderSlider.draw("W##ab_w", a.w, 32, 720, "%.0f px")) {
							a.sizeDirty = true;
							SettingsStore.markDirty();
						}
					},
					function(_:Single) {
						if (BuilderSlider.draw("H##ab_h", a.h, 24, 480, "%.0f px")) {
							a.sizeDirty = true;
							SettingsStore.markDirty();
						}
					}
				);
			});
			UiLayout.propertyRow("Scale", function() {
				if (BuilderSlider.draw("##ab_scale", a.scale, 0.5, 2.5, "%.2f")) {
					a.sizeDirty = true;
					SettingsStore.markDirty();
				}
			});
			UiLayout.propertyRow("Key", function() {
				if (ImGui.checkbox("Show Key Reminder##ab_show_key", a.showKey)) SettingsStore.markDirty();
				if (a.showKey.get()) {
					ImGui.setNextItemWidth(-1);
					if (ImGui.inputText("##ab_key", a.keyBuf, AuraDef.KEY_BUF)) {
						a.keyText = AuraDef.sanitizeKey(readBytes(a.keyBuf, AuraDef.KEY_BUF));
						SettingsStore.markDirty();
					}
				}
			});
		});
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
		var mode = behaviorMode(a);
		UiLayout.propertyGrid("##ab_behavior_props", function() {
			UiLayout.propertyRow("Show alert", function() {
				if (ImGui.beginCombo("##ab_behavior", behaviorLabel(mode))) {
					for (key in ["whileTrue", "onRiseHold", "whileFalse"])
						if (ImGui.selectable(behaviorLabel(key) + "##ab_behavior_" + key, mode == key)) {
							applyBehavior(a, key);
							SettingsStore.markDirty();
						}
					ImGui.endCombo();
				}
			});
			var wantDuration = mode == "onRiseHold" || (a.showBanner != null && a.showBanner.get());
			if (wantDuration) {
				UiLayout.propertyRow("Duration", function() {
					if (BuilderSlider.draw("##ab_hold", a.durRef, 0.5, 10, "%.1f s")) {
						a.duration = a.durRef.get();
						for (e in a.effects) if (e != null) { e.hold = a.duration; e.holdRef.set(a.duration); }
						SettingsStore.markDirty();
					}
				}, "Fixed hold for cast timers. Live status time wins when the game reports one.");
			}
			// "Follow buff duration" moved into the Timer cluster's "Use the game's time"
			// so the same question is not asked in two places.
		});
	}
	/** Flips the screen-wide typed alert and keeps its ALERT effect in sync. */
	function toggleBanner(a:AuraDef):Void {
		a.showBanner.set(!a.showBanner.get());
		if (a.showBanner.get()) {
			if (!hasAlertEffect(a)) a.effects.push(new AuraEffect("boss_alert", AuraEffect.KIND_ALERT, AuraEffect.WHEN_ON_RISE_HOLD));
			var hold = a.duration > 0.05 ? a.duration : 1.5;
			for (e in a.effects) {
				if (e == null || e.kind != AuraEffect.KIND_ALERT) continue;
				e.hold = hold;
				e.holdRef.set(hold);
				e.enabled.set(true);
			}
			a.durRef.set(hold);
			a.duration = hold;
		} else AuraEffects.disableLargeTypedAlert(a);
		SettingsStore.markDirty();
	}

	/** Message / size rows for the typed alert; the toggle itself lives in the Style combo. */
	function drawBannerRows(a:AuraDef):Void {
		if (!a.showBanner.get())
			return;
		UiLayout.propertyRow("Alert line", function() {
			if (ImGui.inputTextMultiline("##ab_boss_alert_text", a.bannerBuf, AuraDef.BANNER_BUF, ImGui.vec2(-1, 48))) {
				a.bannerText = readBytes(a.bannerBuf, AuraDef.BANNER_BUF);
				SettingsStore.markDirty();
			}
		}, "Printed large across the screen when this aura fires.");
		UiLayout.propertyRow("Alert size", function() {
			if (BuilderSlider.draw("##ab_boss_alert_scale", a.bannerScale, 1, 3, "%.1fx")) SettingsStore.markDirty();
		});
	}

	/** Inline shortcut to the canvas's first text element; creates one on demand. */
	function drawCanvasTextRow(a:AuraDef):Void {
		if (a.region != "canvas")
			return;
		UiLayout.propertyRow("Canvas text", function() {
			if (a.canvasElements == null) a.canvasElements = [];
			var el:AuraCanvasElement = null;
			for (c in a.canvasElements)
				if (c != null && c.kind == AuraCanvasElement.KIND_TEXT) { el = c; break; }
			if (el == null) {
				if (ImGui.smallButton("+ Add text##ab_cv_quick_add")) {
					snapshot("Canvas Add Text");
					a.canvasElements.push(AuraCanvasElement.text("{name}", 8, 8, 16));
					canvasSel = a.canvasElements.length - 1;
					SettingsStore.markDirty();
				}
				return;
			}
			ByteUtil.fillBuf(canvasQuickBuf, CANVAS_CONTENT_BUF, el.content != null ? el.content : "");
			ImGui.setNextItemWidth(-1);
			if (ImGui.inputText("##ab_cv_quick", canvasQuickBuf, CANVAS_CONTENT_BUF)) {
				el.content = StringTools.trim(readBytes(canvasQuickBuf, CANVAS_CONTENT_BUF));
				SettingsStore.markDirty();
			}
		}, "Tokens: {time} {stacks} {name}. Full placement lives in Canvas Elements below.");
	}

	static function hasAlertEffect(a:AuraDef):Bool {
		if (a == null || a.effects == null) return false;
		for (e in a.effects) if (e != null && e.enabled.get() && e.kind == AuraEffect.KIND_ALERT) return true;
		return false;
	}

	function drawDrmSound(a:AuraDef, collapsed:Bool = true):Void {
		if (collapsed && !ImGui.collapsingHeader("DRM Export Sound##ab_drm_sound")) return;
		ImGui.textDisabled("SolarFlare does not play audio. These settings are included only in DRM exports.");
		UiLayout.propertyGrid("##ab_drm_props", function() {
			UiLayout.propertyRow("Include", function() {
				if (ImGui.checkbox("Sound cue##ab_audio", a.audio)) SettingsStore.markDirty();
			});
			if (a.audio.get()) {
				UiLayout.propertyRow("Cue", function() {
					var cue = a.cue.length > 0 ? a.cue : "Choose a cue...";
					if (ImGui.beginCombo("##ab_cue", cue)) {
						for (id in AuraPack.CUE_IDS)
							if (ImGui.selectable(id + "##ab_cue_" + id, a.cue == id)) {
								a.cue = id;
								a.syncCueBuf();
								SettingsStore.markDirty();
							}
						ImGui.endCombo();
					}
				});
				UiLayout.propertyRow("Volume", function() {
					volumePercent.set(a.volume.get() * 100);
					if (BuilderSlider.draw("##ab_volume", volumePercent, 0, 100, "%.0f%%")) {
						a.volume.set(volumePercent.get() * 0.01);
						SettingsStore.markDirty();
					}
				});
			}
		});
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
			else { selected = cfg.auras.length - 1; creationHomeOpen = false; deleteArmed = -1; SettingsStore.markDirty(); var msg = added + " Aura(s) imported successfully!"; setIoStatus(msg, false); ToastManager.success(msg); }
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
		selectedIds = new Map();
		selectedIds.set(a.id, true);
		rangeAnchorId = a.id;
		creationHomeOpen = false;
		
		SettingsStore.markDirty();
	}

	function addTemplate(a:AuraDef):Void {
		if (a == null || cfg.auras.length >= AuraEngine.MAX) return;
		a.id = uniqueAuraId(a.id);
		if (setupIssue(a).length > 0) a.enabled.set(false);
		cfg.auras.push(a);
		selected = cfg.auras.length - 1; deleteArmed = -1;
		selectedIds = new Map();
		selectedIds.set(a.id, true);
		rangeAnchorId = a.id;
		creationHomeOpen = false;
		
		SettingsStore.markDirty();
	}

	function duplicateSelected():Void {
		var source = selectedAura(); if (source == null || cfg.auras.length >= AuraEngine.MAX) return;
		var copy = AuraConfig.cloneAura(source, uniqueAuraId(source.id + "_copy"), source.name + " Copy");
		if (copy == null) return;
		cfg.auras.push(copy); selected = cfg.auras.length - 1; creationHomeOpen = false; deleteArmed = -1; SettingsStore.markDirty();
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

	static inline function countdownPlaceLabel(p:Int):String {
		return switch (p) {
			case 1: "Above";
			case 2: "Below";
			default: "Center";
		};
	}

	static inline function stackPlaceLabel(p:Int):String {
		return switch (p) {
			case 1: "Top";
			case 2: "Bottom";
			default: "Center";
		};
	}

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
