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
import solarflare.ui.NumberField;
import solarflare.ui.CustomImages;
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
import imgui.Enums.ImGuiCond;
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
class AuraBuilder implements solarflare.aura.ui.BossModsHost implements solarflare.aura.ui.CanvasHost {
	public var open = new BoolRef(false);
	var cfg:AuraConfig;
	var host:ConfigPanel;
	var shareService=new AuraShareService();
	var sharePanel:solarflare.aura.ui.AuraSharePanel;
	var shareEpoch:Int=0;
	var selected:Int = -1;
	var deleteArmed:Int = -1;
	var selectedIds:Map<String, Bool> = new Map();
	var rangeAnchorId:String = "";

	var undoManager = new UndoManager<String>(40);
	var undoCoordinator:AuraUndoCoordinator;
	public var canvasEditor:solarflare.aura.ui.CanvasEditor;
	var auraSearch = new SearchBar("Filter auras by name, signal, or target...", 128);
	var consumableSearch = new SearchBar("Search potions, elixirs, and boons...", 128);
	var consumableTrack:String = "consumable.active";

	var opacityPercent = new FloatRef(100);
	var volumePercent = new FloatRef(100);
	var search:String = "";
	var scopeFilter:String = "All";
	/** Aura Sets: folded groups, the set whose editor popup should open next, buffers for the editor. */
	var setFolded:Map<String, Bool> = new Map();
	var openSetEditorFor:String = "";
	var setNameFor:String = "";
	var setNameBuf = new hl.Bytes(64);
	var mapAddBuf = new hl.Bytes(96);
	var setDeleteArmed:String = "";
	var iconSearchBuf = new hl.Bytes(80);
	var iconSearch:String = "";
	var iconKindFilter:String = "All";

	var advancedPreview = new solarflare.aura.preview.AdvancedAuraPreview();
	var quickBuild = new solarflare.aura.ui.AuraQuickBuildPopup();
	var combatLogBrowser = new solarflare.aura.ui.CombatLogBrowser();
	var combatLogsOpen:Bool = false;

	var boundEditorAura:AuraDef = null;
	var creationHomeOpen:Bool = true;
	/** Creation Home category card currently expanded: consumable | utility | skill | blank. */
	var homeCategory:String = "utility";
	var creationScrollToGallery:Bool = false;

	var glowColBuf:hl.Bytes;
	var lastGlowAuraId:String = "";
	/** Separate buffer so the Display card's inline field never aliases the Canvas Elements field. */
	var canvasQuickBuf = new hl.Bytes(160);
	static inline var CANVAS_CONTENT_BUF:Int = 160;
	/** Stage drag: mode, element start box, and the pre-drag undo state (pushed on release if moved). */
	var canvasFieldUndoState:String = null;
	/** Scratch box written by canvasBox(); avoids a per-hit-test allocation. */
	/** Group editor owns the workspace while `selected` still equals `groupOpenedAt`. */
	var selectedGroupId:String = "";
	var groupOpenedAt:Int = -2;
	var groupFolded:Map<String, Bool> = new Map();
	var groupNameBuf = new hl.Bytes(64);
	var groupNameFor:String = "";
	var groupWrapRef = new FloatRef(0);
	var groupSpacingRef = new FloatRef(4);
	var groupScaleRef = new FloatRef(1);
	var groupOpacityRef = new FloatRef(1);
	var groupPreviewLayout = new AuraGroupLayout();
	var groupPreviewW:Array<Float> = [];
	var groupPreviewH:Array<Float> = [];
	var groupSnapshotFn:Void->Void;
	/** Groups from the pack being imported; added after its auras land. */
	var pendingImportGroups:Array<AuraGroupDef> = null;
	var libraryCollapsed:Bool = false;
	var buildFocusBossId:String = "";

	static inline var JSON_BUF:Int = 32768;
	var exportBuf = new hl.Bytes(JSON_BUF);
	var importBuf = new hl.Bytes(JSON_BUF);
	var exportString:String = "";
	var ioStatus:String = "";
	var ioStatusError:Bool = false;
	var ioModalRequest:Bool = false;
 var ioOwnerGeneration:Int=-1;

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
 var wizardOwnerGeneration:Int=-1;

	var preciseSnapshotFn:Void->Void;
	function preciseSnapshot():Void snapshot("Adjust Aura value");

	public function new(cfg:AuraConfig, host:ConfigPanel) {
		preciseSnapshotFn=preciseSnapshot;
		groupSnapshotFn = groupSnapshot;
		solarflare.ui.ByteUtil.clearBytes(groupNameBuf, 64);
		this.cfg = cfg;
		this.host = host;
		canvasEditor = new solarflare.aura.ui.CanvasEditor(this);
		undoCoordinator = new AuraUndoCoordinator(undoManager, snapshotJson, captureCanvasById, restoreSnapshot, restoreCanvas);
		solarflare.aura.signal.AuraConditionEditor.auraChoices = auraChoicesForConditions;
		solarflare.aura.signal.AuraConditionEditor.auraConditionChoices = auraConditionSummaries;
		sharePanel=new solarflare.aura.ui.AuraSharePanel(shareService,queueShareScope,queueShareInspect,queueShareImport);
		glowColBuf = ImGui.v4(1, 0.53, 0, 1);
		solarflare.ui.ByteUtil.clearBytes(iconSearchBuf, 80);
		solarflare.ui.ByteUtil.clearBytes(exportBuf, JSON_BUF);
		solarflare.ui.ByteUtil.clearBytes(importBuf, JSON_BUF);
		solarflare.ui.ByteUtil.clearBytes(canvasQuickBuf, CANVAS_CONTENT_BUF);
		solarflare.ui.ByteUtil.clearBytes(wizardSubjectBuf, 128);
		solarflare.ui.ByteUtil.clearBytes(wizardCatalogSearchBuf, 96);
		solarflare.ui.ByteUtil.clearBytes(wizardFightBuf, 32);
	}

	function snapshotJson():String {
		var data = AuraPack.toObj("shared", "snapshot", "undo", cfg.auras, cfg.dumpGroups());
		Reflect.setField(data, "sets", cfg.dumpSets());
		Reflect.setField(data, "counterState", AuraCounterState.dump(cfg.auras));
		Reflect.setField(data, "uiLayouts", host.uiLayouts.dumpCurrent(host));
		return Json.stringify(data);
	}

	function snapshot(actionName:String):Void {
		if (cfg == null) return;
		try {
			var state = snapshotJson();
			undoManager.push(actionName, state);
		} catch (_:Dynamic) {}
	}

	function restoreSnapshot(jsonStr:String):Void {
		try {
			var data = AuraPack.decode(jsonStr);
			var imported = AuraPack.unpackAuras(data);
			AuraCounterState.apply(imported, data.counterState);
			cfg.auras = imported;
			if(data.sets!=null) cfg.applySets(data.sets); else cfg.ensureSets();
			cfg.applyGroups(data.groups);
			if(data.uiLayouts!=null) host.uiLayouts.load(host,data.uiLayouts,solarflare.ui.HudLayoutModel.legacy({auras:{config:{list:data.auras}}}));
			host.uiLayouts.requestReconcile();
			boundEditorAura = null;
			canvasEditor.canvasSel = -1;
			lastGlowAuraId = "";
			canvasEditor.invalidateColor();
			selected = cfg.auras.length > 0 ? 0 : -1;
			creationHomeOpen = selected < 0 && selectedGroupId.length == 0;
			groupOpenedAt = selected;
			deleteArmed = -1;
			SettingsStore.markDirty();
		} catch (_:Dynamic) {}
	}

	public function clearTransientState():Void {
		if (canvasEditor != null) canvasEditor.clearTransientState();
		StatusTypeDemand.beginEditorFrame();
		shareEpoch++; shareService.cancel();
		combatLogsOpen = false;
		combatLogBrowser.suspend();
		selectedGroupId = "";
		openSetEditorFor = "";
		setDeleteArmed = "";
		quickBuild.cancel();
		advancedPreview.reset();
		canvasEditor.resetRuleContexts();
		boundEditorAura = null;
		canvasEditor.canvasSel = -1;
		lastGlowAuraId = "";
		canvasEditor.invalidateColor();
		canvasEditor.resetCanvasTransient();
		selected = -1;
		creationHomeOpen = true;
		deleteArmed = -1;
		selectedIds = new Map();
		rangeAnchorId = "";
	}
 public function resetProfileState():Void {
  clearTransientState(); undoManager.clear(); pendingImportGroups=null; canvasFieldUndoState=null;
  ioModalRequest=false; wizardOpenRequest=false; wizardMode="";
 }

	public function observeShares():Void { shareService.observe(); }
	function queueShareMembers(ids:Array<String>,label:String,wholeLibrary:Bool=false):Void {
		ioModalRequest=true;
		var epoch=shareEpoch; var owner=cfg.auras;
		UiActionQueue.custom(function() {
			if(!open.get() || epoch!=shareEpoch || cfg.auras!=owner) return;
			var members:Array<AuraDef>=[];
			for(id in ids) { var found:AuraDef=null; for(a in cfg.auras) if(a!=null && a.id==id) { found=a; break; } if(found==null) throw "The export selection changed."; members.push(found); }
			var data=AuraShareImport.capture(cfg,members,label,wholeLibrary);
			shareService.requestExport(data,function() return open.get() && epoch==shareEpoch && cfg.auras==owner);
		});
	}
	function queueShareScope(scope:String):Void {
		var current=selectedAura(); var members:Array<AuraDef>=[]; var label="Aura library";
		switch(scope) {
		 case "Aura": if(current!=null) { members=[current]; label=current.name; }
		 case "Selection": forEachSelected(function(a) members.push(a)); label="Selected Auras";
		 case "Group": if(current!=null && cfg.groupOf(current)!=null) { var group=cfg.groupOf(current); members=cfg.groupMembers(group.id); label=group.name; }
		 case "Set": if(current!=null) { var id=AuraConfig.tagOf(current); for(a in cfg.auras) if(AuraConfig.tagOf(a)==id) members.push(a); var set=cfg.findSet(id); label=set!=null ? set.name : id; }
		 default: members=cfg.auras.copy();
		}
		queueShareMembers([for(a in members) a.id],label,scope=="Library");
	}
	function queueShareInspect(path:String):Void { queueShareFile(path,false); }
	function queueShareImport(path:String):Void { queueShareFile(path,true); }
	function queueShareFile(path:String,importing:Bool):Void {
		var epoch=shareEpoch; var owner=cfg.auras;
		UiActionQueue.custom(function() {
			if(!open.get() || epoch!=shareEpoch || cfg.auras!=owner) return;
			var alive=function() return open.get() && epoch==shareEpoch && cfg.auras==owner;
			var check=function(data:Dynamic) AuraShareImport.preflight(data,cfg);
			if(!importing) { shareService.requestInspect(path,check,alive); return; }
			shareService.requestImport(path,check,function(data:Dynamic) {
				var before=snapshotJson(); var transaction=new AuraShareImport(data,cfg);
				var bank=host.uiLayouts.bank; var layout=bank.active; var oldRows=bank.layouts.get(layout);
				var rows=solarflare.ui.HudLayoutModel.merge(oldRows,transaction.layoutRows());
				try {
				 transaction.commit();
				 bank.layouts.set(layout,rows);
				 host.uiLayouts.requestReconcile(); SettingsStore.markDirty(); solarflare.ObserveDemand.markStatusDemandDirty();
				 undoManager.push("Import share file",before);
				 selected=cfg.auras.length-1; selectedGroupId=""; creationHomeOpen=false; boundEditorAura=null; canvasEditor.canvasSel=-1;
				} catch(e:Dynamic) { bank.layouts.set(layout,oldRows); transaction.rollback(); throw e; }
			},alive);
		});
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
			var share = AuraPack.encode("shared", "export", "pack", cfg.auras, cfg.dumpGroups());
			ImGui.setClipboardText(share);
			ToastManager.success(cfg.auras.length + " Auras copied as share key!");
		} catch (e:Dynamic) { ToastManager.error("Export failed: " + e); }
	}

	// ----------------------------------------------------------------
	// Main Draw - 2-column layout
	// ----------------------------------------------------------------

	public function draw():Void {
		StatusTypeDemand.beginEditorFrame();
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
			quickBuild.draw(cfg, commitQuickBuild);
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
				openCreationHome();
			if (ImGui.menuItem("Combat Logs")) openCombatLogs();
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
			if (ImGui.menuItem("Undo", "Ctrl+Z", false, canUndo)) performUndo();
			if (ImGui.menuItem("Redo", "Ctrl+Y", false, canRedo)) performRedo();
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
		ImGui.beginDisabled(!undoManager.canUndo());
		if (ImGui.button("Undo##ab_undo")) performUndo();
		ImGui.endDisabled();
		ImGui.sameLine();
		ImGui.beginDisabled(!undoManager.canRedo());
		if (ImGui.button("Redo##ab_redo")) performRedo();
		ImGui.endDisabled();
		if (SettingsStore.isDirty()) { ImGui.sameLine(0, 12); ImGui.textColored(ImGui.vec4(0.95, 0.72, 0.25, 1), "* Unsaved"); }

		// Resolve after profile and Undo/Redo actions, which may replace cfg.auras.
		var a = selectedAura();
		if (a != null && activeGroup() == null) {
			var toggleW:Single = 418;
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
		if (combatLogsOpen) { ImGui.textColored(solarflare.ui.ThemePalette.current().accent, "COMBAT LOGS"); return; }
		if (creationHomeOpen) { ImGui.textColored(solarflare.ui.ThemePalette.current().accent, "CREATION HOME"); return; }
		var pillGroup = activeGroup();
		if (pillGroup != null) { ImGui.textColored(solarflare.ui.ThemePalette.current().accent, "GROUP * " + pillGroup.name); return; }
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
		if (combatLogsOpen) {
			combatLogBrowser.draw(this);
			return;
		}
		var openGroup = activeGroup();
		if (openGroup != null) {
			drawGroupEditor(openGroup);
			return;
		}
		selectedGroupId = "";
		var a = selectedAura();
		if (creationHomeOpen || a == null) {
			drawCreationHome();
			return;
		}
		if (boundEditorAura != a) {
			advancedPreview.reset();
			boundEditorAura = a;
			canvasEditor.canvasSel = -1;
			lastGlowAuraId = "";
			canvasEditor.invalidateColor();
			canvasEditor.resetCanvasTransient();
		}
		drawAuraIdentityBar(a);
		if (creationHomeOpen) return;
		drawMainPane(a);
	}

	function openWorkspace():Void {
		combatLogsOpen = false;
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
			UiLayout.inlinePair("##ab_creation_nav", function(w:Single) {
				if (previous != null) {
					if (UiChrome.ghostButton("Back to " + previous.name + "##ab_creation_back", ImGui.vec2(w, 28)))
						creationHomeOpen = false;
				} else if (cfg.auras.length > 0) {
					// Recover an editor selection when the home screen has no current aura.
					if (UiChrome.ghostButton("Edit My Auras (" + cfg.auras.length + ")##ab_creation_edit", ImGui.vec2(w, 28)))
						openWorkspace();
				} else {
					ImGui.dummy(ImGui.vec2(w, 28));
				}
			}, function(w:Single) {
				if (UiChrome.ghostButton("Replay tutorial##ab_creation_tut", ImGui.vec2(w, 28)))
					openWizard("tutorial");
			}, 8);

			ImGui.dummy(ImGui.vec2(0, 4));
			UiChrome.subHeader("Boss Mods");
			ImGui.textWrapped("Fought a boss with recording on? Open it, tick its abilities and create a whole set of alerts at once.");
			if (UiChrome.ghostButton("Build boss alerts from a recording##ab_home_bossmods", ImGui.vec2(280, 30))) openCombatLogs();
			ImGui.dummy(ImGui.vec2(0, 6));
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

			ImGui.dummy(ImGui.vec2(0, 8));
			UiChrome.subHeader("Or start from a signal");

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

	static var HOME_CATEGORY_IDS:Array<String> = ["utility", "skill", "consumable", "blank"];
	static var HOME_CATEGORY_TITLES:Array<String> = ["Utilities", "Skills", "Consumables", "Blank"];
	static var HOME_CATEGORY_HINTS:Array<String> = ["Everyday signals", "Cooldowns and casts", "Potions and boons", "Empty rule"];

	function drawCreationLists(atCap:Bool):Void {
		UiLayout.inlineSplit("##ab_home_categories", HOME_CATEGORY_IDS.length, function(i:Int, cellW:Single) {
			if (drawHomeCategoryCard(i, cellW))
				homeCategory = HOME_CATEGORY_IDS[i];
		}, 8);
		ImGui.dummy(ImGui.vec2(0, 8));
		switch (homeCategory) {
			case "consumable": drawConsumableList();
			case "skill": drawSkillList(0);
			case "blank": drawBlankList(0);
			default: drawUtilityList(0);
		}
	}

	/** Selectable category card: title and one-line hint, accent only on the selected one. */
	function drawHomeCategoryCard(index:Int, width:Single):Bool {
		var theme = solarflare.ui.ThemePalette.current();
		var selected = homeCategory == HOME_CATEGORY_IDS[index];
		var height:Single = 54;
		var clicked = ImGui.invisibleButton("##ab_home_cat_" + HOME_CATEGORY_IDS[index], ImGui.vec2(width, height));
		var hovered = ImGui.isItemHovered();
		var min = ImGui.getItemRectMin();
		var max = ImGui.getItemRectMax();
		var dl = ImGui.getWindowDrawList();
		var tint:Single = selected ? 0.22 : (hovered ? 0.1 : 0);
		ImGui.ImDrawList_AddRectFilled(dl, min, max, ImGui.colorConvertFloat4ToU32(ImGui.vec4(
			theme.cellBg.x * (1 - tint) + theme.accent.x * tint,
			theme.cellBg.y * (1 - tint) + theme.accent.y * tint,
			theme.cellBg.z * (1 - tint) + theme.accent.z * tint, 1)), 8);
		ImGui.ImDrawList_AddRect(dl, min, max, ImGui.colorConvertFloat4ToU32(selected || hovered ? theme.accent : theme.border), 8, selected ? 2 : 1, 0);
		if (selected)
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(min.x + 10, max.y - 4), ImGui.vec2(max.x - 10, max.y - 4),
				ImGui.colorConvertFloat4ToU32(theme.accent), 2.5);
		ImGui.ImDrawList_PushClipRect(dl, ImGui.vec2(min.x + 4, min.y), ImGui.vec2(max.x - 4, max.y), true);
		var title = HOME_CATEGORY_TITLES[index];
		var ts = ImGui.calcTextSize(title);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(min.x + (width - ts.x) * 0.5, min.y + 9),
			ImGui.colorConvertFloat4ToU32(theme.text), title);
		var hint = HOME_CATEGORY_HINTS[index];
		var hs = ImGui.calcTextSize(hint);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(min.x + Math.max(6, (width - hs.x) * 0.5), min.y + 9 + ts.y + 4),
			ImGui.colorConvertFloat4ToU32(theme.textDisabled), hint);
		ImGui.ImDrawList_PopClipRect(dl);
		return clicked;
	}

	/** One library transaction shared by Create & Save and the Advanced handoff. */
	function commitQuickBuild(draft:AuraQuickBuildDraft, advanced:Bool):String {
		if (draft == null || cfg == null) return "Quick Build draft is unavailable.";
		if (cfg.auras.length >= AuraEngine.MAX) return "Aura limit reached. Delete an aura before creating another.";
		var issue = draft.issue(GameIcons.hasKey);
		if (!advanced && issue.length > 0) return issue;
		var a = draft.aura;
		if (cfg.auras.indexOf(a) >= 0) return "This aura has already been created.";
		snapshot("Create Aura (Quick Build)");
		a.id = uniqueAuraId("aura_" + (cfg.auras.length + 1));
		a.enabled.set(issue.length == 0);
		cfg.auras.push(a);
		cfg.ensureSets();
		selected = cfg.auras.length - 1;
		selectedIds = new Map();
		selectedIds.set(a.id, true);
		rangeAnchorId = a.id;
		deleteArmed = -1;
		creationHomeOpen = !advanced;
		if (advanced) combatLogsOpen = false;
		SettingsStore.markDirty();
		if (!advanced) UiActionQueue.save();
		ToastManager.success(advanced ? "Aura opened in Advanced." : "Aura created; save queued.");
		return "";
	}

	/**
	 * Boss Mods transaction: many drafts, ONE undo step and ONE save, never past the library cap.
	 * `setId` (optional) becomes each aura's encounter/set tag.
	 */
	public function commitBatch(drafts:Array<AuraQuickBuildDraft>, setId:String):{made:Int, skipped:Int, why:String} {
		if (cfg == null || drafts == null || drafts.length == 0) return {made: 0, skipped: 0, why: "Nothing to create."};
		if (cfg.auras.length >= AuraEngine.MAX)
			return {made: 0, skipped: drafts.length, why: "Aura limit reached. Delete an aura before creating another."};
		snapshot("Create boss alerts");
		var made = 0;
		var skipped = 0;
		var why = "";
		selectedIds = new Map();
		for (draft in drafts) {
			if (draft == null || cfg.auras.indexOf(draft.aura) >= 0) { skipped++; continue; }
			if (cfg.auras.length >= AuraEngine.MAX) { skipped++; why = "Aura limit reached."; continue; }
			var a = draft.aura;
			a.id = uniqueAuraId("aura_" + (cfg.auras.length + 1));
			if (setId != null && setId.length > 0) { a.fight = setId; a.syncFightBuf(); }
			a.enabled.set(draft.issue(GameIcons.hasKey).length == 0);
			cfg.auras.push(a);
			selectedIds.set(a.id, true);
			rangeAnchorId = a.id;
			selected = cfg.auras.length - 1;
			made++;
		}
		cfg.ensureSets();
		deleteArmed = -1;
		if (made > 0) {
			SettingsStore.markDirty();
			UiActionQueue.save();
		}
		return {made: made, skipped: skipped, why: why};
	}

	// ---------------------------------------------------------------------------------------------
	// Boss Mods host (see BossModsHost)
	// ---------------------------------------------------------------------------------------------

	public function bossCfg():AuraConfig return cfg;

	public function bossBuild(draft:AuraQuickBuildDraft):Void quickBuild.start(draft);

	public function bossAddSet(name:String):AuraSetDef {
		var created = cfg.addSet(name);
		if (created != null) SettingsStore.markDirty();
		return created;
	}

	public function bossSetsChanged():Void {
		cfg.markSetsDirty();
		SettingsStore.markDirty();
	}

	public function bossOpenAura(id:String):Void {
		for (i in 0...cfg.auras.length) {
			var a = cfg.auras[i];
			if (a == null || a.id != id) continue;
			combatLogsOpen = false;
			creationHomeOpen = false;
			selected = i;
			selectedIds = new Map();
			selectedIds.set(id, true);
			rangeAnchorId = id;
			canvasEditor.canvasSel = -1;
			lastGlowAuraId = "";
			return;
		}
	}

	/**
	 * Creates several drafts as one undo step. `setId` empty means no Aura Set. A non-empty `mapId` arms the set on
	 * that map, but only when the set is empty or already map-bound, so an existing set keeps its behavior.
	 */
	public function bossCreate(drafts:Array<AuraQuickBuildDraft>, setId:String, mapId:String):solarflare.aura.ui.BossModsHost.BossAlertResult {
		if (cfg == null) return {made: 0, skipped: drafts.length, why: "Aura library is unavailable.", set: ""};
		var set = setId != null && setId.length > 0 ? cfg.findSet(setId) : null;
		var map = AuraSetDef.normalizeMap(mapId);
		if (set != null && map.length > 0 && (cfg.countIn(set.id) == 0 || set.mode == AuraSetDef.MODE_MAPS)) {
			set.mode = AuraSetDef.MODE_MAPS;
			set.addMap(map);
		}
		cfg.markSetsDirty();
		var result = commitBatch(drafts, set != null ? set.id : "");
		return {made: result.made, skipped: result.skipped, why: result.why, set: set != null ? set.name : ""};
	}

	function openCreationHome():Void {
		combatLogsOpen = false;
		creationHomeOpen = true;
	}

	function openCombatLogs():Void {
		combatLogsOpen = true;
		combatLogBrowser.enter();
	}

	/** Entry point for other pages (Utilities): show the builder already on the combat-log workspace. */
	public function openCombatLogsWindow():Void {
		open.set(true);
		creationHomeOpen = false;
		openCombatLogs();
	}

	function drawConsumableList():Void {
		UiChrome.sectionHeader("Consumables");
		ImGui.textWrapped("Potions, elixirs, and boons. Choose what to track, then pick an item.");
		drawHomeRow("Spark Cube - Spark Surge timer", "home_spark_surge",
			function() acceptBossStarterAura(AuraTemplates.createConsumableTracker("SparkCube")));
		drawHomeRow("Spark Cube - refill needed", "home_spark_refill",
			function() acceptBossStarterAura(AuraTemplates.createConsumableTracker("SparkCube", "consumable.needsRefill")));
		UiLayout.propertyGrid("##ab_consumable_properties", function() {
			UiLayout.propertyRow("Track", function() {
				var labels = ["Effect active / timer", "Usable now", "Count / charges", "Refill needed", "Owned"];
				var signals = ["consumable.active", "consumable.usable", "consumable.count", "consumable.needsRefill", "consumable.owned"];
				if (ImGui.beginCombo("##ab_consumable_track", labels[signals.indexOf(consumableTrack)])) {
					for (i in 0...signals.length)
						if (ImGui.selectable(labels[i], consumableTrack == signals[i])) consumableTrack = signals[i];
					ImGui.endCombo();
				}
			});
		});
		var query = consumableSearch.draw("##ab_consumable_search");
		UiScope.child("##ab_consumable_items", ImGui.vec2(0, 210), function() {
			var matches = 0;
			for (entry in solarflare.cdb.ConsumableCatalog.entries) {
				if (query.length > 0 && (entry.name + " " + entry.id + " " + entry.type).toLowerCase().indexOf(query) < 0) continue;
				if (consumableTrack == "consumable.needsRefill" && !entry.refillable) continue;
				matches++;
				var id = entry.id;
				drawHomeRow(entry.name + (entry.statuses.length == 0 && consumableTrack == "consumable.active" ? " - usable (instant effect)" : ""),
					"home_consumable_" + id, function() acceptBossStarterAura(AuraTemplates.createConsumableTracker(id, consumableTrack)));
			}
			if (matches == 0) ImGui.textDisabled("No matching consumables.");
		}, ImGuiChildFlags.Borders);
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
		drawHomeRow("My skill cast", "home_sk_cast", function() createFromHome("skill", "event.playerCast.recent", ""));
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
		drawHomeRow("Static text box", "home_text_box", function() createStaticTextBox());
		drawHomeRow("Cast + buff timer", "home_cast_buff_timer", function() createCastBuffTimer());
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
		combatLogsOpen = false;
		// addBlankAura already sets selected, selectedIds, creationHomeOpen=false,
		// and marks dirty.
		ToastManager.success("New blank aura created.");
	}

	function createStaticTextBox():Void {
		var a = new AuraDef(uniqueAuraId("text_box"), "Text box");
		a.region = "text";
		a.announce = "Your message";
		a.syncAnnounceBuf();
		a.alwaysOn.set(true);
		a.chrome.transparent.set(true);
		a.showKey.set(false);
		a.w.set(320);
		a.h.set(120);
		a.rule = new solarflare.aura.signal.AuraRuleDef();
		acceptBossStarterAura(a);
	}
	function createCastBuffTimer():Void {
		var a = new AuraDef(uniqueAuraId("cast_buff_timer"), "Cast + buff timer");
		a.region = "icon";
		a.rule = new solarflare.aura.signal.AuraRuleDef();
		var castCondition = new solarflare.aura.signal.AuraConditionDef();
		castCondition.signal = "event.playerCast.recent";
		castCondition.op = "within";
		castCondition.numberValue = 1;
		var buff = new solarflare.aura.signal.AuraConditionDef();
		buff.signal = "status.present";
		buff.subject = "Staff_SummonDemon_Passive_Buff";
		buff.op = "present";
		a.rule.conditions = [castCondition, buff];
		a.rule.mode = "all";
		a.timerMode = AuraTimer.MODE_DOWN;
		a.timerSource = AuraTimer.SRC_FIXED;
		a.timerSeconds.set(20);
		a.followBuffDuration.set(false);
		a.showCountdown.set(true);
		a.enabled.set(false);
		AuraPresentationDefaults.fresh(a);
		acceptBossStarterAura(a);
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
		if (ImGui.collapsingHeader("Preview controls##ab_preview_controls_fold")) {
			advancedPreview.drawControls();
		}
		drawDrmSound(a, true);
	}

	function drawThenColumn(a:AuraDef):Void {
		UiChrome.sectionHeader("THEN");
		drawThenPreview(a);
		drawSectionCard("Display", "Style, timer, counter, alert", false, function() drawAppearance(a));
		drawSectionCard("Window", "", false, function() drawWindowLayout(a));
		drawSectionCard("Alerts and Actions", "", false, function() {
			cfg.drawEffects(a, true);
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
			for (set in cfg.sets) {
				if (set == null) continue;
				if (ImGui.selectable(set.name + "##ab_fight_" + set.id, AuraConfig.tagOf(a) == set.id)) {
					cfg.moveToSet(a, set.id);
					SettingsStore.markDirty();
				}
			}
			ImGui.separator();
			ImGui.textDisabled("New encounter tag");
			ImGui.setNextItemWidth(-1);
			if (ImGui.inputTextWithHint("##ab_ed_fight", "tag id", a.fightBuf, AuraDef.FIGHT_BUF)) {
				a.fight = readBytes(a.fightBuf, AuraDef.FIGHT_BUF);
				SettingsStore.markDirty();
			}
			// The tag becomes a set once typing ends, not on every keystroke.
			if (ImGui.isItemDeactivatedAfterEdit()) cfg.ensureSets();
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
		if (a.alwaysOn.get() && (a.rule == null || a.rule.conditions == null || a.rule.conditions.length == 0))
			return "Always show " + regionLabel(a.region) + ". Add conditions if you want a trigger.";
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
		if (AuraTimer.keepsAura(a))
			parts.add('; also show during ' + (a.timerSource == AuraTimer.SRC_FIXED ? 'the ${a.timerSeconds.get()}s timer' : "the timer") + ' started when conditions ' + (a.timerStartEdge == 1 ? "stop being true" : "become true"));
		if (a.showFuse.get()) parts.add(" + fuse");
		if (a.showCountdown.get()) parts.add(a.timerMode == AuraTimer.MODE_UP ? " + countup" : " + countdown");
		if (AuraEffects.hasIconGlow(a)) parts.add(" + glow");
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
		if (solarflare.ui.UiChrome.toggleTile("##" + id, label, isChecked, w, h, isMixed, false)) {
			onWrite(state != FX_ON);
		}
		if (ImGui.isItemHovered() && isMixed)
			ImGui.setTooltip("Mixed across selection — click to enable all");
	}
	function drawAppearanceFxStrip(a:AuraDef, tiles:Bool = true):Void {
		if (a == null) return;
		if (tiles) drawFxTiles(a);
		drawFxStripRest(a);
	}

	/** The six shortcut toggles; shown beside the preview, or under it for freeform canvas auras. */
	function drawFxTiles(a:AuraDef):Void {
		if (a == null) return;
		var selectionCount = countSelected();
		if (selectionCount > 1) ImGui.textDisabled("Selection shortcuts — " + selectionCount + " auras");
		var columns = UiLayout.columnCount(ImGui.getContentRegionAvail().x, 108, 2, 6);
		var rows = Std.int(Math.ceil(6 / columns));
		for (row in 0...rows) {
			UiLayout.inlineSplit("##ab_fx_tiles_" + row, columns, function(col:Int, w:Single) {
				var i = row * columns + col;
				if (i >= 6) return;
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
						function(v) applyFxToTargets(function(x) x.stackCounter.set(v)));
				}
			}, 6);
			if (row + 1 < rows) ImGui.dummy(ImGui.vec2(0, 6));
		}
	}

	function drawFxStripRest(a:AuraDef):Void {
		UiChrome.subHeader("Timer");
		drawTimerRows(a);
		if (a.stackCounter.get() || a.isCounter.get()) {
			UiLayout.propertyGrid("##ab_stack_display", function() {
				if (a.stackCounter.get()) drawBadgeRows(a, false);
				if (a.isCounter.get()) drawBadgeRows(a, true);
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
			}, "Tints the configured icon glow.");
			if (AuraEffects.hasIconGlow(a)) {
				UiLayout.propertyRow("Glow style", function() {
					if (ImGui.beginCombo("##ab_glow_style", glowStyleLabel(a.glowStyle))) {
						for (style in ["proc", "soft", "pulse"])
							if (ImGui.selectable(glowStyleLabel(style) + "##ab_gs_" + style, a.glowStyle == style)) {
								a.glowStyle = style;
								SettingsStore.markDirty();
							}
						ImGui.endCombo();
					}
				});
				UiLayout.propertyRow("Strength", function() {
					if (ImGui.inputFloat("##ab_glow_strength", a.glowStrength, 0, 0, "%.2fx")) {
						a.glowStrength.set(AuraGlowStyle.strength(a.glowStrength.get()));
						SettingsStore.markDirty();
					}
				});
				UiLayout.propertyRow("Outside spread", function() {
					if (ImGui.inputFloat("##ab_glow_outer", a.glowOuter, 0, 0, "%.1f px")) {
						a.glowOuter.set(AuraGlowStyle.spread(a.glowOuter.get()));
						SettingsStore.markDirty();
					}
				});
				UiLayout.propertyRow("Inside spread", function() {
					if (ImGui.inputFloat("##ab_glow_inner", a.glowInner, 0, 0, "%.1f px")) {
						a.glowInner.set(AuraGlowStyle.spread(a.glowInner.get()));
						SettingsStore.markDirty();
					}
				}, "Spread inward is limited by the face size; outward spread gets its own drawing space.");
			}
		});
	}
	static function glowStyleLabel(style:String):String {
		return switch (AuraGlowStyle.normalize(style)) {
			case "soft": "Soft bloom";
			case "pulse": "Pulsing bloom";
			default: "Proc sparks";
		};
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
		UiLayout.propertyGrid("##ab_timer_options_grid", function() {
			var cooldown = AuraTimingReferencePolicy.isCooldown(timingSignal(a));
			UiLayout.propertyRow("Time direction", function() {
				var labels = ["Off", "Count down", "Count up"];
				if (ImGui.beginCombo("##ab_timer_mode", labels[a.timerMode >= 0 && a.timerMode <= 2 ? a.timerMode : 0])) {
					for (mode in 0...3)
						if (ImGui.selectable(labels[mode] + "##ab_tm_" + mode, a.timerMode == mode)) setTimerMode(a, mode);
					ImGui.endCombo();
				}
			});
			if (cooldown) UiLayout.propertyRow("Gauge fill", function() {
				var modes = AuraGaugePolicy.MODES;
				var labels = AuraGaugePolicy.LABELS;
				var index = modes.indexOf(a.gaugeFillMode); if (index < 0) index = 0;
				if (ImGui.beginCombo("##ab_gauge_fill", labels[index])) {
					for (i in 0...modes.length) if (ImGui.selectable(labels[i], index == i)) {
						snapshot("Gauge fill"); a.gaugeFillMode = modes[i]; a.gauge.reset(); SettingsStore.markDirty();
					}
					ImGui.endCombo();
				}
			}, "Independent of time text. Fill stays full when no recharge is active. Use Show aura: Always to keep it visible.");
			UiLayout.propertyRow("Duration source", function() {
				var fixed = a.timerSource == AuraTimer.SRC_FIXED;
				if (ImGui.beginCombo("##ab_timer_source", fixed ? (cooldown ? "Game time + estimate" : "Fixed seconds") : "Game time")) {
					for (source in 0...2)
						if (ImGui.selectable(source == 0 ? "Game time" : (cooldown ? "Game time + estimate" : "Fixed seconds"), a.timerSource == source)) {
							a.timerSource = source;
							a.followBuffDuration.set(source == AuraTimer.SRC_FOLLOW);
							AuraTimer.reset(a);
							if (source == AuraTimer.SRC_FIXED) primeTimerSeconds(a);
							SettingsStore.markDirty();
						}
					ImGui.endCombo();
				}
			});
			UiLayout.propertyRow(cooldown ? "Estimate seconds" : "Fixed seconds", function() {
				ImGui.beginDisabled(a.timerSource != AuraTimer.SRC_FIXED);
				var previous = a.timerSeconds.get();
				if (ImGui.inputFloat("##ab_timer_secs", a.timerSeconds, 0, 0, "%.3f")) {
					var value = a.timerSeconds.get();
					a.timerSeconds.set(Math.isFinite(value) ? Math.max(1, Math.min(600, value)) : previous);
					AuraTimer.reset(a);
					SettingsStore.markDirty();
				}
				if (ImGui.isItemHovered()) ImGui.setTooltip("Enter 1–600 seconds. Decimal values are supported.");
				var listed = listedTimerSpan(a);
				if (listed > 0.05 && ImGui.smallButton("Use listed " + (Math.round(listed * 10) / 10) + "s##ab_timer_listed")) {
					a.timerSeconds.set(listed);
					AuraTimer.reset(a);
					SettingsStore.markDirty();
				}
				ImGui.endDisabled();
			});
			UiLayout.propertyRow("Start when", function() {
				if (cooldown) { ImGui.textWrapped("Skill enters cooldown"); return; }
				var labels = ["Conditions become true", "Conditions stop being true"];
				if (ImGui.beginCombo("##ab_timer_edge", labels[a.timerStartEdge])) {
					for (edge in 0...2)
						if (ImGui.selectable(labels[edge] + "##ab_te_" + edge, a.timerStartEdge == edge)) {
							a.timerStartEdge = edge;
							AuraTimer.reset(a);
							SettingsStore.markDirty();
						}
					ImGui.endCombo();
				}
			}, cooldown ? "Live cooldown seconds take precedence over the estimate. Readiness and affordability never start a cooldown timer." : null);
			UiLayout.propertyRow("On aura", function() {
				if (ImGui.checkbox("Show time##ab_cd_force", a.showCountdown)) SettingsStore.markDirty();
				var previousGlobal=a.useGlobalCountdown.get();
				if (ImGui.checkbox("Use global countdown##ab_global_countdown", a.useGlobalCountdown)) {
					var value=a.useGlobalCountdown.get(); a.useGlobalCountdown.set(previousGlobal);
					snapshot("Global countdown"); a.useGlobalCountdown.set(value); SettingsStore.markDirty();
				}
				ImGui.beginDisabled(!a.showCountdown.get());
				if (ImGui.beginCombo("##ab_cd_place", countdownPlaceLabel(a.countdownPlace))) {
					for (place in 0...3)
						if (ImGui.selectable(countdownPlaceLabel(place) + "##ab_cdp_" + place, a.countdownPlace == place)) {
							a.countdownPlace = place;
							SettingsStore.markDirty();
						}
					ImGui.endCombo();
				}
				ImGui.endDisabled();
			});
			UiLayout.propertyRow("Time size", function() {
				ImGui.beginDisabled(!a.showCountdown.get());
				if (NumberField.draw("##ab_cd_scale", a.countdownScale, 0.5, 3, "%.2fx", preciseSnapshotFn)) SettingsStore.markDirty();
				ImGui.endDisabled();
			});
			UiLayout.propertyRow("Timers window", function() {
				if (ImGui.checkbox("Show timer##ab_timer_board", a.timerBoard)) SettingsStore.markDirty();
			});
			UiLayout.propertyRow("Finished row", function() {
				ImGui.beginDisabled(!a.timerBoard.get());
				if (ImGui.inputFloat("##ab_timer_linger", a.timerKeepExpired, 0, 0, "%.1f s")) {
					var value = a.timerKeepExpired.get();
					a.timerKeepExpired.set(Math.isFinite(value) ? Math.max(0, Math.min(30, value)) : 3);
					SettingsStore.markDirty();
				}
				ImGui.endDisabled();
			}, "Time the finished board row stays visible. This does not extend the aura's interval.");
		});
	}

	/** Exclusive: ticking both directions would need a second accumulator in AuraTimer. */
	function setTimerMode(a:AuraDef, mode:Int):Void {
		snapshot("Time direction");
		a.gauge.reset();
		a.timerMode = mode;
		AuraTimer.reset(a);
		if (mode != AuraTimer.MODE_OFF) {
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
		var signal = timingSignal(a);
		if (AuraTimingReferencePolicy.isCast(signal)) return AuraTimingReferences.forSubject(a.timingSubjectId(), signal).castSeconds;
		if (AuraTimingReferencePolicy.isCooldown(signal)) return AuraTimingReferences.forSubject(a.timingSubjectId(), signal).cdbSeconds;
		return solarflare.cdb.CdbAuraTable.listedSpan(a.timingSubjectId());
	}

	function timingSignal(a:AuraDef):String {
		if (a.rule != null && a.rule.hasConditions()) {
			var index = a.rule.presentationSource;
			if (index < 0 || index >= a.rule.conditions.length) index = 0;
			var condition = a.rule.conditions[index];
			if (condition != null) return condition.signal;
		}
		return a.trigger == "combatlog" ? "event.cast.recent" : a.trigger == "cooldown" ? "skill.ready" : "";
	}

	function timingReadout(a:AuraDef):String {
		var subj = a.timingSubjectId();
		var signal = timingSignal(a);
		if (AuraTimingReferencePolicy.isCast(signal)) {
			var ref = AuraTimingReferences.forSubject(subj, signal);
			return ref.castLabel + (ref.castSeconds > 0 ? " · " + Math.round(ref.castSeconds * 1000) / 1000 + "s" : "")
				+ " · Manual seconds apply to this aura only.";
		}
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

	function drawBadgeRows(a:AuraDef, counter:Bool):Void {
		var label = counter ? "Counter" : "Stacks";
		var id = counter ? "counter" : "stack";
		var place = counter ? a.counterPlace : a.stackPlace;
		UiLayout.propertyRow(label + " position", function() {
			if (ImGui.beginCombo("##ab_" + id + "_place", stackPlaceLabel(place))) {
				try {
					for (p in 0...3) {
						if (ImGui.selectable(stackPlaceLabel(p) + "##ab_" + id + "p_" + p, place == p)) {
							snapshot(label + " position");
							if (counter) a.counterPlace = p; else a.stackPlace = p;
							SettingsStore.markDirty();
						}
					}
				} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
				ImGui.endCombo();
			}
		}, "Timer, Stacks and Counter sharing a position use separate lanes.");
		UiLayout.propertyRow(label + " size", function() {
			var ref = counter ? a.counterScale : a.stackScale;
			var before = ref.get();
			if (NumberField.draw("##ab_" + id + "_scale", ref, 0.5, 3, "%.2fx", preciseSnapshotFn)) {
				// Precise input records one pre-edit snapshot for the whole gesture.
				SettingsStore.markDirty();
			}
		});
	}

	/** Activation total is independent of the live Stacks badge. */
	function drawCounterRow(a:AuraDef):Void {
		UiLayout.propertyRow("Counter", function() {
			var before = a.isCounter.get();
			if (ImGui.checkbox("Count activations##ab_counter", a.isCounter)) {
				var after = a.isCounter.get(); a.isCounter.set(before);
				snapshot("Count activations"); a.isCounter.set(after);
				SettingsStore.markDirty();
			}
			if (!a.isCounter.get()) return;
			ImGui.sameLine(0, 8);
			ImGui.textDisabled("= " + a.counterValue);
			ImGui.sameLine(0, 6);
			if (ImGui.smallButton("Reset##ab_reset_count")) {
				snapshot("Reset Counter");
				a.counterValue = 0;
				SettingsStore.markDirty();
			}
		}, "Increments every time the condition becomes true. Survives reloads. Independent of live Stacks.");
	}

	function drawThenPreview(a:AuraDef):Void {
		var width = ImGui.getContentRegionAvail().x;
		var isCanvas = a.region == "canvas";
		// A canvas aura keeps its looks and shortcuts under the preview, so that column gets more room.
		var previewW:Single = isCanvas ? Math.max(240, Math.min(340, width * 0.46)) : Math.max(160, Math.min(220, width * 0.38));
		UiScope.table("##ab_preview_controls", 2, function() {
			ImGui.tableSetupColumn("##preview", imgui.Enums.ImGuiTableColumnFlags.WidthFixed, previewW);
			ImGui.tableSetupColumn("##controls", imgui.Enums.ImGuiTableColumnFlags.WidthStretch, 1);
			ImGui.tableNextRow();
			ImGui.tableSetColumnIndex(0);
			AuraVisualRenderer.countdownAll = cfg.countdownAll.get();
			AuraVisualRenderer.countdownCeiling = cfg.countdownAutoMax.get();
			AuraVisualRenderer.countdownGlobalScale = Math.max(0.5, Math.min(3, cfg.countdownScale.get()));
			advancedPreview.draw(a, previewW, previewW, false, true);
			if (ImGui.isItemHovered()) ImGui.setTooltip("Live preview of the current settings.");
			drawSummaryBlock(a, previewW);
			drawCanvasLauncher(a, previewW);
			if (isCanvas) {
				ImGui.spacing();
				drawSectionCard("Looks", "States", false, function() canvasEditor.drawStatesPanel(a));
				drawSectionCard("Display shortcuts", "", false, function() drawFxTiles(a));
			}
			ImGui.tableSetColumnIndex(1);
			if (!isCanvas) UiChrome.subHeader("Display shortcuts");
			drawAppearanceFxStrip(a, !isCanvas);
		}, imgui.Enums.ImGuiTableFlags.SizingStretchProp | imgui.Enums.ImGuiTableFlags.NoSavedSettings);
		drawBehavior(a);
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
		ImGui.sameLine(0, 10);
		if (ImGui.smallButton("+ Set##ab_new_set")) {
			var created = cfg.addSet("New set");
			if (created != null) { openSetEditorFor = created.id; setNameFor = ""; setFolded.remove(created.id); SettingsStore.markDirty(); }
		}
		if (ImGui.isItemHovered()) ImGui.setTooltip("Create an Aura Set to group alerts for one fight");

		var atCap = cfg.auras.length >= AuraEngine.MAX;
		var atHome = !combatLogsOpen && (creationHomeOpen || selectedAura() == null);
		if (UiChrome.navButton("Creation Home##ab_open_creation_home", atHome, ImGui.vec2(-1, 28))) openCreationHome();
		if (UiChrome.navButton("Boss Mods (Combat Logs)##ab_library_combat_logs", combatLogsOpen, ImGui.vec2(-1, 28))) openCombatLogs();
		ImGui.beginDisabled(atCap);
		try {
			if (UiChrome.ghostButton("Start with blank aura##ab_quick_blank", ImGui.vec2(-1, 28))) createBlankFromHome();
			if (UiChrome.ghostButton("Quick Build##ab_library_quick_build", ImGui.vec2(-1, 28))) quickBuild.start();
		} catch (e:Dynamic) { ImGui.endDisabled(); throw e; }
		ImGui.endDisabled();
		if (atCap) ImGui.textWrapped("Aura limit reached. Delete an aura before creating another.");
		if (atHome) {
			// Outside the atCap guard on purpose: a full library is exactly when you
			// need to edit rather than create.
			if (cfg.auras.length > 0 && UiChrome.ghostButton("Edit My Auras##ab_lib_edit", ImGui.vec2(-1, 26)))
				openWorkspace();
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

	function drawWizardModal():Void {
		if (wizardOpenRequest) { wizardOwnerGeneration=FeatureProfiles.statusOwnerGen; ImGui.openPopup("New Aura###ab_wizard_modal"); wizardOpenRequest = false; }
		if (!ImGui.beginPopupModal("New Aura###ab_wizard_modal", null, imgui.Enums.ImGuiWindowFlags.AlwaysAutoResize)) return;
  if(wizardOwnerGeneration!=FeatureProfiles.statusOwnerGen) { ImGui.closeCurrentPopup(); ImGui.endPopup(); return; }
		try {
			switch (wizardMode) {
				case "tutorial": drawTutorial();
				case "boss": drawWizardBoss();
				case "skill": drawWizardSkill();
				case "utility": drawWizardUtility();
				default: ImGui.textWrapped("Unknown mode.");
			}
			ImGui.separator();
			if (UiChrome.ghostButton("Close##ab_wiz_cancel", ImGui.vec2(100, 28))) ImGui.closeCurrentPopup();
		} catch (e:Dynamic) { ImGui.endPopup(); throw e; }
		ImGui.endPopup();
	}

	function drawTutorial():Void {
		UiChrome.heading("Aura tutorial", 1.28);
		ImGui.spacing();
		ImGui.textWrapped("1. Creation Home groups starting points into Utilities, Skills, Consumables and Blank cards. Pick a card, then click a row to make an Aura — there is no extra modal for that.");
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
			if (UiChrome.ghostButton("<- Back##wiz_boss_b1", ImGui.vec2(80, 28))) wizardStep = 0;
			ImGui.sameLine();
			if (UiChrome.ghostButton("Next ->##wiz_boss_next", ImGui.vec2(100, 28))) wizardStep = 2;
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
			if (UiChrome.ghostButton("<- Back##wiz_boss_back", ImGui.vec2(80, 28))) {
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
				if (UiChrome.ghostButton("Continue##wiz_skill_template_next", ImGui.vec2(120, 28))) wizardStep = 1;
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
			if (UiChrome.ghostButton("<- Back##wiz_skill_back", ImGui.vec2(80, 28))) wizardStep = 0;
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
			if (UiChrome.ghostButton("<- Back##wiz_util_back", ImGui.vec2(80, 28))) wizardStep = 0;
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
					c.subject = CdbAuraTable.statusSubjectId(wizardSubject);
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
		AuraPresentationDefaults.fresh(a);
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
		// Sections in display order: each Aura Set, then Shared. Auras keep their library order inside a section.
		var filtering = search.length > 0 || scopeFilter != "All";
		var groups:Array<{set:AuraSetDef, rows:Array<Int>}> = [];
		for (s in cfg.sets) if (s != null) groups.push({set: s, rows: []});
		var shared:Array<Int> = [];
		// A display group sits as one block in the section of its first listed member, so every aura shows once.
		var groupRows = new Map<String, Array<Int>>();
		var groupHome = new Map<String, String>();
		for (i in 0...cfg.auras.length) {
			var a = cfg.auras[i];
			if (a == null || !matchesFilter(a)) continue;
			var tag = AuraConfig.tagOf(a);
			var placed = false;
			for (g in groups) if (g.set.id == tag) { g.rows.push(i); placed = true; break; }
			if (!placed) shared.push(i);
			if (cfg.findGroup(a.group) != null) {
				var list = groupRows.get(a.group);
				if (list == null) {
					list = [];
					groupRows.set(a.group, list);
					groupHome.set(a.group, placed ? tag : "");
				}
				list.push(i);
			}
		}
		var sections:Array<{key:String, rows:Array<Int>}> = [for (g in groups) {key: g.set.id, rows: g.rows}];
		sections.push({key: "", rows: shared});
		var plans = new Map<String, Array<AuraListEntry>>();
		for (sec in sections) {
			var entries:Array<AuraListEntry> = [];
			for (i in sec.rows) {
				var a = cfg.auras[i];
				var g = cfg.findGroup(a.group);
				if (g == null) { entries.push({kind: 0, index: i, group: null}); continue; }
				if (groupHome.get(g.id) != sec.key) continue;
				groupHome.set(g.id, "#placed");
				var members = groupRows.get(g.id);
				entries.push({kind: 1, index: members.length, group: g});
				if (!groupFolded.exists(g.id))
					for (m in members) entries.push({kind: 2, index: m, group: g});
			}
			// Groups with no members at all still need a home so they can be edited or removed.
			if (sec.key == "" && !filtering)
				for (g in cfg.groups)
					if (g != null && !groupRows.exists(g.id)) entries.push({kind: 1, index: 0, group: g});
			plans.set(sec.key, entries);
		}
		var visibleIds:Array<String> = [];
		for (sec in sections)
			if (!setFolded.exists(sec.key))
				for (e in plans.get(sec.key)) if (e.kind != 1) visibleIds.push(cfg.auras[e.index].id);
		var shown = 0;
		for (g in groups) {
			if (g.rows.length == 0 && filtering) continue;
			drawSetHeader(g.set, g.rows.length);
			if (!setFolded.exists(g.set.id)) {
				drawListEntries(plans.get(g.set.id), visibleIds);
				if (g.rows.length == 0) ImGui.textDisabled("   Empty. Move auras here from their right-click menu.");
			}
			shown += g.rows.length;
		}
		var sharedPlan = plans.get("");
		if (groups.length > 0 && (sharedPlan.length > 0 || !filtering)) drawSharedHeader(shared.length);
		if (!setFolded.exists("")) drawListEntries(sharedPlan, visibleIds);
		shown += shared.length;
		if (shown == 0 && cfg.groups.length == 0) ImGui.textDisabled("No auras match.");
	}

	function drawListEntries(entries:Array<AuraListEntry>, visibleIds:Array<String>):Void {
		for (e in entries) {
			if (e.kind == 1) drawGroupHeaderRow(e.group, e.index);
			else if (e.kind == 2) {
				ImGui.indent(14);
				try drawAuraRow(e.index, visibleIds) catch (err:Dynamic) { ImGui.unindent(14); throw err; }
				ImGui.unindent(14);
			} else drawAuraRow(e.index, visibleIds);
		}
	}

	function drawSharedHeader(count:Int):Void {
		ImGui.pushID_Str("ab_set_shared");
		try {
			var folded = setFolded.exists("");
			if (ImGui.smallButton(folded ? ">##ab_set_fold" : "v##ab_set_fold")) { if (folded) setFolded.remove(""); else setFolded.set("", true); }
			ImGui.sameLine(0, 6);
			ImGui.textDisabled("Shared (" + count + ")");
		} catch (e:Dynamic) { ImGui.popID(); throw e; }
		ImGui.popID();
	}

	function drawAuraRow(i:Int, visibleIds:Array<String>):Void {
		var a = cfg.auras[i];
		if (a == null) return;
		ImGui.pushID_Str(a.id);
		try {
			var eyeLabel = a.enabled.get() ? "O##ab_eye" : "-##ab_eye";
			if (ImGui.smallButton(eyeLabel)) { a.enabled.set(!a.enabled.get()); SettingsStore.markDirty(); }
			ImGui.sameLine();
			var state = setupIssue(a).length > 0 ? " SETUP" : "";
			if (!cfg.setActive(AuraConfig.tagOf(a))) state += " (set off)";
			var displayName = a.name.length > 0 ? a.name : a.id;
			var rowSelected = isAuraSelected(a.id) || selected == i;
			if (ImGui.selectable(displayName + state + "##ab_item", rowSelected)) {
				combatLogsOpen = false;
				applyManagedSelect(a.id, visibleIds);
				selectedGroupId = "";
				if (selected != i) { canvasEditor.canvasSel = -1; lastGlowAuraId = ""; }
				selected = i;
				creationHomeOpen = false;
				deleteArmed = -1;
			}
			if (ImGui.isItemClicked(1)) {
				combatLogsOpen = false;
				selected = i; creationHomeOpen = false; selectedGroupId = "";
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

	// ----------------------------------------------------------------
	// Aura Groups (dynamic display groups; independent of Aura Sets)
	// ----------------------------------------------------------------

	/** The group whose editor owns the workspace, or null. It stays open while `selected` is unchanged. */
	function activeGroup():AuraGroupDef {
		if (selectedGroupId.length == 0 || combatLogsOpen || creationHomeOpen || selected != groupOpenedAt) return null;
		return cfg.findGroup(selectedGroupId);
	}

	function openGroupEditor(g:AuraGroupDef):Void {
		if (g == null) return;
		selectedGroupId = g.id;
		groupOpenedAt = selected;
		groupNameFor = "";
		creationHomeOpen = false;
		combatLogsOpen = false;
		deleteArmed = -1;
	}

	function openAuraFromGroup(a:AuraDef):Void {
		var idx = cfg.auras.indexOf(a);
		if (idx < 0) return;
		selectedGroupId = "";
		selected = idx;
		selectedIds = new Map();
		selectedIds.set(a.id, true);
		rangeAnchorId = a.id;
		creationHomeOpen = false;
		canvasEditor.canvasSel = -1;
	}

	function groupSnapshot():Void snapshot("Group setting");

	function createGroupFrom(list:Array<AuraDef>):Void {
		if (list == null || list.length == 0) return;
		if (cfg.groups.length >= AuraGroupDef.MAX) {
			ToastManager.error("Group limit reached (" + AuraGroupDef.MAX + ").");
			return;
		}
		snapshot("Create group");
		var g = cfg.addGroup("Group " + (cfg.groups.length + 1), list);
		if (g == null) return;
		SettingsStore.markDirty();
		openGroupEditor(g);
		ToastManager.success("Grouped " + list.length + " aura(s). They now share one window.");
	}

	function setGroupEnabled(g:AuraGroupDef, on:Bool):Void {
		snapshot(on ? "Enable group" : "Disable group");
		for (a in cfg.auras)
			if (a != null && a.group == g.id)
				a.enabled.set(on);
		SettingsStore.markDirty();
	}

	function groupAnyEnabled(g:AuraGroupDef):Bool {
		for (a in cfg.auras)
			if (a != null && a.group == g.id && a.enabled.get())
				return true;
		return false;
	}

	function ungroup(g:AuraGroupDef):Void {
		snapshot("Ungroup");
		var id = g.id;
		cfg.removeGroup(id);
		host.uiLayouts.forgetWidget("auraGroup:" + id);
		if (selectedGroupId == id) selectedGroupId = "";
		SettingsStore.markDirty();
		ToastManager.info("Ungrouped " + g.name + ". Its auras have their own windows again.");
	}

	function copyGroupShareKey(g:AuraGroupDef):Void {
		var members = cfg.groupMembers(g.id);
		var share = try AuraPack.encode("shared", g.id, g.name, members, [cfg.dumpGroup(g)]) catch (_:Dynamic) "";
		if (share.length > 0) UiActionQueue.copyText(share, 'Copied share key for group "${g.name}" (${members.length} auras)');
		else ToastManager.error("Group export failed.");
	}

	/** Swap a member with its neighbour in library order (group order is library order). */
	function moveGroupMember(members:Array<AuraDef>, k:Int, dir:Int):Void {
		var j = k + dir;
		if (k < 0 || j < 0 || k >= members.length || j >= members.length) return;
		var ia = cfg.auras.indexOf(members[k]);
		var ib = cfg.auras.indexOf(members[j]);
		if (ia < 0 || ib < 0) return;
		snapshot("Reorder group");
		cfg.auras[ia] = members[j];
		cfg.auras[ib] = members[k];
		if (selected == ia) selected = ib;
		else if (selected == ib) selected = ia;
		groupOpenedAt = selected;
		SettingsStore.markDirty();
	}

	function drawGroupHeaderRow(g:AuraGroupDef, count:Int):Void {
		ImGui.pushID_Str("ab_grp_" + g.id);
		try {
			var folded = groupFolded.exists(g.id);
			if (ImGui.smallButton(folded ? ">##ab_grp_fold" : "v##ab_grp_fold")) {
				if (folded) groupFolded.remove(g.id); else groupFolded.set(g.id, true);
			}
			ImGui.sameLine(0, 6);
			var on = groupAnyEnabled(g);
			if (ImGui.smallButton(on ? "O##ab_grp_eye" : "-##ab_grp_eye")) setGroupEnabled(g, !on);
			if (ImGui.isItemHovered()) ImGui.setTooltip("Turn every aura in this group on or off");
			ImGui.sameLine();
			ImGui.pushStyleColor(ImGuiCol.Text, solarflare.ui.ThemePalette.current().accent);
			var picked = ImGui.selectable("Group: " + g.name + " (" + count + ")##ab_grp_sel", activeGroup() == g);
			ImGui.popStyleColor();
			if (picked) openGroupEditor(g);
			var dropped = DragDropHelper.acceptAuraDrop(-1);
			if (dropped >= 0 && dropped < cfg.auras.length) {
				var a = cfg.auras[dropped];
				if (a != null && a.group != g.id) {
					snapshot("Add to group");
					cfg.moveToGroup(a, g.id);
					SettingsStore.markDirty();
				}
			}
			if (ImGui.isItemClicked(1)) ImGui.openPopup("ab_grp_ctx");
			if (ImGui.beginPopup("ab_grp_ctx")) {
				try {
					if (ImGui.menuItem("Edit group")) openGroupEditor(g);
					if (ImGui.menuItem("Enable all")) setGroupEnabled(g, true);
					if (ImGui.menuItem("Disable all")) setGroupEnabled(g, false);
					if (ImGui.menuItem("Copy group share key")) copyGroupShareKey(g);
					ImGui.separator();
					if (ImGui.menuItem("Ungroup")) ungroup(g);
				} catch (e:Dynamic) { ImGui.endPopup(); throw e; }
				ImGui.endPopup();
			}
		} catch (e:Dynamic) { ImGui.popID(); throw e; }
		ImGui.popID();
	}

	function drawGroupMenu(a:AuraDef):Void {
		if (!ImGui.beginMenu("Group")) return;
		try {
			if (ImGui.menuItem("New group with this aura")) createGroupFrom([a]);
			if (cfg.groups.length > 0) ImGui.separator();
			for (grp in cfg.groups)
				if (grp != null && ImGui.menuItem(grp.name + "##ab_gm_" + grp.id, "", a.group == grp.id) && a.group != grp.id) {
					snapshot("Add to group");
					cfg.moveToGroup(a, grp.id);
					SettingsStore.markDirty();
				}
			if (cfg.groupOf(a) != null) {
				ImGui.separator();
				if (ImGui.menuItem("Remove from group")) {
					snapshot("Remove from group");
					cfg.moveToGroup(a, "");
					SettingsStore.markDirty();
				}
			}
		} catch (e:Dynamic) { ImGui.endMenu(); throw e; }
		ImGui.endMenu();
	}

	function drawGroupEditor(g:AuraGroupDef):Void {
		var members = cfg.groupMembers(g.id);
		drawGroupIdentityBar(g, members.length);
		var avail = ImGui.getContentRegionAvail();
		if (avail.x < 780) {
			UiScope.child("##ab_grp_scroll", ImGui.vec2(0, 0), function() {
				drawGroupLeftColumn(g, members);
				drawGroupRightColumn(g, members);
			});
			return;
		}
		var gap:Single = 8;
		var leftW:Single = (avail.x - gap) * 0.5;
		var rightW:Single = avail.x - gap - leftW;
		var paneH:Single = Math.max(1, avail.y - 4);
		UiChrome.celChild("##ab_grp_left", ImGui.vec2(leftW, paneH), function() drawGroupLeftColumn(g, members));
		ImGui.sameLine(0, gap);
		UiChrome.celChild("##ab_grp_right", ImGui.vec2(rightW, paneH), function() drawGroupRightColumn(g, members));
	}

	function drawGroupIdentityBar(g:AuraGroupDef, count:Int):Void {
		if (groupNameFor != g.id) {
			groupNameFor = g.id;
			ByteUtil.fillBuf(groupNameBuf, 64, g.name);
		}
		UiScope.table("##ab_grp_identity", 3, function() {
			ImGui.tableSetupColumn("##home", imgui.Enums.ImGuiTableColumnFlags.WidthFixed, 64);
			ImGui.tableSetupColumn("##name", imgui.Enums.ImGuiTableColumnFlags.WidthStretch, 0.6);
			ImGui.tableSetupColumn("##info", imgui.Enums.ImGuiTableColumnFlags.WidthStretch, 0.4);
			ImGui.tableNextRow();
			ImGui.tableSetColumnIndex(0);
			if (UiChrome.ghostButton("Home##ab_grp_home", ImGui.vec2(64, 28))) {
				clearTransientState();
				return;
			}
			ImGui.tableSetColumnIndex(1);
			ImGui.alignTextToFramePadding();
			ImGui.text("Group");
			ImGui.sameLine(0, 6);
			ImGui.setNextItemWidth(-1);
			if (ImGui.inputText("##ab_grp_name", groupNameBuf, 64)) {
				var next = StringTools.trim(readBytes(groupNameBuf, 64));
				if (next.length > 0) {
					g.name = next;
					SettingsStore.markDirty();
				}
			}
			canvasFieldUndo("Rename group");
			ImGui.tableSetColumnIndex(2);
			ImGui.alignTextToFramePadding();
			ImGui.textDisabled(count + (count == 1 ? " aura" : " auras") + " share one window");
		}, imgui.Enums.ImGuiTableFlags.SizingStretchProp | imgui.Enums.ImGuiTableFlags.NoSavedSettings);
	}

	function drawGroupLeftColumn(g:AuraGroupDef, members:Array<AuraDef>):Void {
		drawSectionCard("Preview", "How the group packs on screen", true, function() drawGroupPreview(g, members));
		drawSectionCard("Members", "Order here is the on-screen order", false, function() drawGroupMembers(g, members));
	}

	function drawGroupRightColumn(g:AuraGroupDef, members:Array<AuraDef>):Void {
		drawSectionCard("Layout", "", false, function() drawGroupLayoutCard(g));
		drawSectionCard("Look", "", false, function() drawGroupLookCard(g));
		drawSectionCard("Window", "", false, function() drawGroupWindowCard(g));
		drawSectionCard("Share and actions", "", false, function() drawGroupActionsCard(g, members));
	}

	/** Every member drawn as active with the shared preview simulation, fitted into the card. */
	function drawGroupPreview(g:AuraGroupDef, members:Array<AuraDef>):Void {
		var theme = solarflare.ui.ThemePalette.current();
		var n = members.length;
		var width:Single = Math.max(120, ImGui.getContentRegionAvail().x);
		var height:Single = 200;
		var pos = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(width, height));
		var dl = ImGui.getWindowDrawList();
		var max = ImGui.vec2(pos.x + width, pos.y + height);
		ImGui.ImDrawList_PushClipRect(dl, pos, max, true);
		try {
			ImGui.ImDrawList_AddRectFilled(dl, pos, max, ImGui.colorConvertFloat4ToU32(theme.windowBg), 4);
			if (n == 0) {
				var msg = "Add auras to see the group here.";
				var ts = ImGui.calcTextSize(msg);
				ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(pos.x + (width - ts.x) * 0.5, pos.y + (height - ts.y) * 0.5),
					ImGui.colorConvertFloat4ToU32(theme.textDisabled), msg);
			} else {
				for (i in 0...n) {
					var a = members[i];
					var sc = a.displayScale() * g.scale;
					setPreviewAt(groupPreviewW, i, Math.max(24, a.w.get() * sc));
					setPreviewAt(groupPreviewH, i, Math.max(24, a.h.get() * sc));
				}
				groupPreviewLayout.compute(groupPreviewW, groupPreviewH, n, g.grow, g.wrap, g.spacing * g.scale, g.align);
				var tw = Math.max(1, groupPreviewLayout.totalW);
				var th = Math.max(1, groupPreviewLayout.totalH);
				var fit:Single = Math.min(1, Math.min((width - 16) / tw, (height - 16) / th));
				var ox:Single = pos.x + (width - tw * fit) * 0.5;
				var oy:Single = pos.y + (height - th * fit) * 0.5;
				for (i in 0...n) {
					var a = members[i];
					var sc = a.displayScale() * g.scale * fit;
					var x:Single = ox + groupPreviewLayout.xs[i] * fit;
					var y:Single = oy + groupPreviewLayout.ys[i] * fit;
					var w:Single = groupPreviewW[i] * fit;
					var h:Single = groupPreviewH[i] * fit;
					AuraVisualRenderer.draw(dl, a, x, y, w, h, advancedPreview.gaugeProgress(a), advancedPreview.stacks.get(),
						advancedPreview.counter.get(), !a.enabled.get(), g.opacity, sc, null, null, !advancedPreview.liveCanvasConditions);
					AuraVisualRenderer.drawKeyChip(dl, x, y, w, h, a, !a.enabled.get());
				}
			}
		} catch (e:Dynamic) { ImGui.ImDrawList_PopClipRect(dl); throw e; }
		ImGui.ImDrawList_PopClipRect(dl);
		ImGui.pushTextWrapPos(0);
		ImGui.textDisabled("Every member is shown here. In game, only auras that are showing take a slot, so gaps close"
			+ (g.sort == "time" ? ", soonest expiry first." : "."));
		ImGui.popTextWrapPos();
	}

	static inline function setPreviewAt(arr:Array<Float>, i:Int, v:Float):Void {
		if (i < arr.length) arr[i] = v; else arr.push(v);
	}

	function drawGroupMembers(g:AuraGroupDef, members:Array<AuraDef>):Void {
		if (members.length == 0) {
			ImGui.pushTextWrapPos(0);
			ImGui.textDisabled("No auras yet. Add one below, drag an aura onto the group in the library, or select auras and press Group.");
			ImGui.popTextWrapPos();
		}
		var rowH:Single = ImGui.getTextLineHeight() + 4;
		var btnW:Single = 24;
		for (k in 0...members.length) {
			var a = members[k];
			ImGui.pushID_Str("ab_gm_" + a.id);
			try {
				var w:Single = Math.max(40, ImGui.getContentRegionAvail().x - btnW * 3 - 12);
				var off = !a.enabled.get();
				if (off) ImGui.pushStyleColor(ImGuiCol.Text, solarflare.ui.ThemePalette.current().textDisabled);
				var label = (a.name.length > 0 ? a.name : a.id) + (off ? "  (off)" : "");
				var picked = ImGui.selectable(label + "##ab_gm_row", false, 0, ImGui.vec2(w, rowH));
				if (off) ImGui.popStyleColor();
				if (ImGui.isItemHovered()) ImGui.setTooltip("Open this aura");
				if (picked) openAuraFromGroup(a);
				ImGui.sameLine(0, 4);
				ImGui.beginDisabled(k == 0);
				if (UiChrome.ghostButton("^##ab_gm_up", ImGui.vec2(btnW, rowH))) moveGroupMember(members, k, -1);
				ImGui.endDisabled();
				ImGui.sameLine(0, 4);
				ImGui.beginDisabled(k == members.length - 1);
				if (UiChrome.ghostButton("v##ab_gm_down", ImGui.vec2(btnW, rowH))) moveGroupMember(members, k, 1);
				ImGui.endDisabled();
				ImGui.sameLine(0, 4);
				if (UiChrome.ghostButton("x##ab_gm_rm", ImGui.vec2(btnW, rowH))) {
					snapshot("Remove from group");
					cfg.moveToGroup(a, "");
					SettingsStore.markDirty();
				}
				if (ImGui.isItemHovered()) ImGui.setTooltip("Remove from group (the aura is kept)");
			} catch (e:Dynamic) { ImGui.popID(); throw e; }
			ImGui.popID();
		}
		UiChrome.gap(4);
		UiLayout.propertyGrid("##ab_grp_add", function() {
			UiLayout.propertyRow("Add aura", function() {
				if (!ImGui.beginCombo("##ab_grp_add_combo", "Choose an aura...")) return;
				try {
					var any = false;
					for (a in cfg.auras) {
						if (a == null || a.group == g.id) continue;
						any = true;
						var other = cfg.groupOf(a);
						var label = (a.name.length > 0 ? a.name : a.id) + (other != null ? "  (in " + other.name + ")" : "");
						if (ImGui.selectable(label + "##ab_grp_add_" + a.id, false)) {
							snapshot("Add to group");
							cfg.moveToGroup(a, g.id);
							SettingsStore.markDirty();
						}
					}
					if (!any) ImGui.textDisabled("Every aura is already in this group.");
				} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
				ImGui.endCombo();
			});
		});
	}

	static function groupGrowLabel(dir:String):String {
		return switch (dir) {
			case "left": "Left";
			case "down": "Down";
			case "up": "Up";
			default: "Right";
		}
	}

	static function groupSortLabel(id:String):String {
		return id == "time" ? "Time left (soonest first)" : "Library order";
	}

	function drawGroupLayoutCard(g:AuraGroupDef):Void {
		UiLayout.propertyGrid("##ab_grp_layout", function() {
			UiLayout.propertyRow("Grow", function() {
				UiLayout.inlineSplit("##ab_grp_grow", 4, function(index:Int, cellW:Single) {
					var dir = AuraGroupDef.GROWS[index];
					if (UiChrome.navButton(groupGrowLabel(dir) + "##ab_grp_grow_" + dir, g.grow == dir, ImGui.vec2(cellW, 0)) && g.grow != dir) {
						snapshot("Group grow");
						g.grow = dir;
						SettingsStore.markDirty();
					}
				});
			}, "Direction the group fills as auras appear.");
			UiLayout.propertyRow("Per line", function() {
				groupWrapRef.set(g.wrap);
				if (NumberField.draw("##ab_grp_wrap", groupWrapRef, 0, 64, "%.0f", groupSnapshotFn)) {
					g.wrap = Std.int(groupWrapRef.get());
					SettingsStore.markDirty();
				}
			}, "0 keeps every aura on one line. 3 makes a grid three wide.");
			UiLayout.propertyRow("Spacing", function() {
				groupSpacingRef.set(g.spacing);
				if (NumberField.draw("##ab_grp_spacing", groupSpacingRef, 0, 64, "%.0f px", groupSnapshotFn)) {
					g.spacing = groupSpacingRef.get();
					SettingsStore.markDirty();
				}
			});
			UiLayout.propertyRow("Align", function() {
				var picked = UiLayout.stringCombo("ab_grp_align", g.align, AuraGroupDef.ALIGNS, function(id:String) {
					if (g.horizontal()) return id == "start" ? "Top" : (id == "end" ? "Bottom" : "Middle");
					return id == "start" ? "Left" : (id == "end" ? "Right" : "Center");
				});
				if (picked != null) {
					snapshot("Group align");
					g.align = picked;
					SettingsStore.markDirty();
				}
			}, "Lines up auras of different sizes inside a line.");
			UiLayout.propertyRow("Order", function() {
				var picked = UiLayout.stringCombo("ab_grp_sort", g.sort, AuraGroupDef.SORTS, groupSortLabel);
				if (picked != null) {
					snapshot("Group order");
					g.sort = picked;
					SettingsStore.markDirty();
				}
			});
		});
	}

	function drawGroupLookCard(g:AuraGroupDef):Void {
		UiLayout.propertyGrid("##ab_grp_look", function() {
			UiLayout.propertyRow("Scale", function() {
				groupScaleRef.set(g.scale);
				if (NumberField.draw("##ab_grp_scale", groupScaleRef, 0.25, 4, "%.2fx", groupSnapshotFn)) {
					g.scale = groupScaleRef.get();
					SettingsStore.markDirty();
				}
			}, "Multiplies each aura's own Scale.");
			UiLayout.propertyRow("Opacity", function() {
				groupOpacityRef.set(g.opacity);
				if (NumberField.draw("##ab_grp_opacity", groupOpacityRef, 0.05, 1, "%.2f", groupSnapshotFn)) {
					g.opacity = groupOpacityRef.get();
					SettingsStore.markDirty();
				}
			}, "Multiplies each aura's own Opacity.");
		});
	}

	function drawGroupWindowCard(g:AuraGroupDef):Void {
		var chrome = cfg.groupChrome(g);
		UiLayout.propertyGrid("##ab_grp_window", function() {
			UiLayout.propertyRow("Locked", function() {
				if (ImGui.checkbox("Lock window##ab_grp_lock", chrome.locked)) SettingsStore.markDirty();
			}, "Unlocked, every member shows as a ghost so you can drag the group into place.");
			chrome.drawPositionRow("ab_grp_pos_" + g.id);
		});
	}

	function drawGroupActionsCard(g:AuraGroupDef, members:Array<AuraDef>):Void {
		UiLayout.inlinePair("##ab_grp_enable",
			function(w:Single) {
				if (UiChrome.ghostButton("Enable all##ab_grp_en", ImGui.vec2(w, 0))) setGroupEnabled(g, true);
			},
			function(w:Single) {
				if (UiChrome.ghostButton("Disable all##ab_grp_dis", ImGui.vec2(w, 0))) setGroupEnabled(g, false);
			});
		UiChrome.gap(4);
		ImGui.beginDisabled(members.length == 0);
		if (UiChrome.accentButton("Copy group share key##ab_grp_share", ImGui.vec2(-1, 0))) copyGroupShareKey(g);
		ImGui.endDisabled();
		ImGui.pushTextWrapPos(0);
		ImGui.textDisabled("The key carries the group settings; the ZIP also carries custom images.");
		if(UiChrome.ghostButton("Export with images##ab_group_files")) queueShareMembers([for(a in cfg.groupMembers(g.id)) a.id],g.name);
		ImGui.popTextWrapPos();
		UiChrome.gap(4);
		if (UiChrome.ghostButton("Ungroup##ab_grp_ungroup", ImGui.vec2(-1, 0))) ungroup(g);
		if (ImGui.isItemHovered()) ImGui.setTooltip("Removes the group. Its auras are kept and get their own windows back.");
	}

	// ----------------------------------------------------------------
	// Aura Sets
	// ----------------------------------------------------------------

	static function setChip(cfg:AuraConfig, s:AuraSetDef):{text:String, kind:Int} {
		if (s.mode == AuraSetDef.MODE_OFF) return {text: "OFF", kind: solarflare.ui.ThemePalette.STATUS_WARN};
		if (s.mode == AuraSetDef.MODE_MAPS)
			return cfg.setActive(s.id) ? {text: "ARMED", kind: solarflare.ui.ThemePalette.STATUS_SUCCESS}
				: {text: "WAITING FOR MAP", kind: solarflare.ui.ThemePalette.STATUS_INFO};
		return {text: "ALWAYS ON", kind: solarflare.ui.ThemePalette.STATUS_INFO};
	}

	function drawSetHeader(s:AuraSetDef, count:Int):Void {
		ImGui.pushID_Str("ab_set_" + s.id);
		try {
			UiLayout.inlinePair("##ab_set_row", function(w:Single) {
				var folded = setFolded.exists(s.id);
				if (ImGui.smallButton(folded ? ">##ab_set_fold" : "v##ab_set_fold")) { if (folded) setFolded.remove(s.id); else setFolded.set(s.id, true); }
				ImGui.sameLine(0, 6);
				ImGui.text(s.name + " (" + count + ")");
			}, function(w:Single) {
				var chip = setChip(cfg, s);
				ImGui.textColored(solarflare.ui.ThemePalette.status(chip.kind), chip.text);
				ImGui.sameLine(0, 6);
				if (ImGui.smallButton("Edit##ab_set_edit")) { setDeleteArmed = ""; ImGui.openPopup("ab_set_pop"); }
				if (openSetEditorFor == s.id) { openSetEditorFor = ""; setDeleteArmed = ""; ImGui.openPopup("ab_set_pop"); }
				if (ImGui.beginPopup("ab_set_pop")) {
					try drawSetEditor(s) catch (e:Dynamic) { ImGui.endPopup(); throw e; }
					ImGui.endPopup();
				}
			}, 6);
		} catch (e:Dynamic) { ImGui.popID(); throw e; }
		ImGui.popID();
	}

	function drawSetEditor(s:AuraSetDef):Void {
		if (setNameFor != s.id) { setNameFor = s.id; ByteUtil.fillBuf(setNameBuf, 64, s.name); }
		ImGui.setNextItemWidth(260);
		if (ImGui.inputText("##ab_set_name", setNameBuf, 64)) {
			var next = StringTools.trim(readBytes(setNameBuf, 64));
			if (next.length > 0) { s.name = next; SettingsStore.markDirty(); }
		}
		ImGui.textDisabled("When should this set run?");
		UiLayout.inlineSplit("##ab_set_mode", 3, function(i:Int, w:Single) {
			var label = ["Always", "On chosen maps", "Off"][i];
			if (UiChrome.navButton(label + "##ab_set_mode_" + i, s.mode == i, ImGui.vec2(w, 26))) {
				s.mode = i; cfg.markSetsDirty(); SettingsStore.markDirty();
			}
		}, 4);
		if (s.mode == AuraSetDef.MODE_MAPS) {
			ImGui.textWrapped("Bosses never appear in the open world, so a set can arm itself on the map where its fight happens.");
			var here = AuraMapContext.mapId;
			ImGui.textDisabled("Current map: " + AuraMapContext.label(here));
			for (m in s.maps.copy()) {
				ImGui.text("  " + m);
				ImGui.sameLine(0, 8);
				if (ImGui.smallButton("Remove##ab_set_map_rm_" + m)) { s.removeMap(m); cfg.markSetsDirty(); SettingsStore.markDirty(); }
			}
			if (s.maps.length == 0) ImGui.textDisabled("  No maps yet.");
			ImGui.beginDisabled(here.length == 0 || s.hasMap(here));
			if (UiChrome.ghostButton("Add current map##ab_set_add_here", ImGui.vec2(180, 26))) {
				s.addMap(here); cfg.markSetsDirty(); SettingsStore.markDirty();
			}
			ImGui.endDisabled();
			ImGui.setNextItemWidth(180);
			ImGui.inputTextWithHint("##ab_set_map_input", "Map id", mapAddBuf, 96);
			ImGui.sameLine(0, 6);
			if (ImGui.smallButton("Add##ab_set_map_add")) {
				if (s.addMap(readBytes(mapAddBuf, 96))) { ByteUtil.clearBytes(mapAddBuf, 96); cfg.markSetsDirty(); SettingsStore.markDirty(); }
			}
		}
		ImGui.separator();
		if (UiChrome.ghostButton("Export set##ab_set_export", ImGui.vec2(120, 26))) {
			var pack:Array<AuraDef> = [];
			for (a in cfg.auras) if (a != null && AuraConfig.tagOf(a) == s.id) pack.push(a);
			var share = try AuraPack.encode(s.id, s.id, s.name, pack) catch (_) "";
			if (share.length > 0) UiActionQueue.copyText(share, "Set share key copied");
		}
		ImGui.sameLine(0, 6);
		if(UiChrome.ghostButton("Export with images##ab_set_files")) queueShareMembers([for(a in cfg.auras) if(AuraConfig.tagOf(a)==s.id) a.id],s.name);
		var armed = setDeleteArmed == s.id;
		if (UiChrome.ghostButton((armed ? "Really delete? Auras go to Shared" : "Delete set") + "##ab_set_delete", ImGui.vec2(armed ? 230 : 120, 26))) {
			if (armed) {
				snapshot("Delete set");
				cfg.removeSet(s.id);
				setDeleteArmed = "";
				SettingsStore.markDirty();
				ImGui.closeCurrentPopup();
			} else setDeleteArmed = s.id;
		}
	}

	/** Compact arm/disarm list for the hub, so a set can be switched without opening the builder. */
	public function drawSetSwitches(id:String):Void {
		if (cfg == null || cfg.sets.length == 0) {
			ImGui.textDisabled("No Aura Sets yet. Tag auras with an encounter or build alerts from a recording.");
			return;
		}
		UiLayout.propertyGrid("##hub_sets_" + id, function() {
			for (s in cfg.sets) {
				if (s == null) continue;
				UiLayout.propertyRow(s.name, function() {
					ImGui.setNextItemWidth(150);
					if (ImGui.beginCombo("##hub_set_mode_" + s.id, ["Always on", "On chosen maps", "Off"][s.mode])) {
						try {
							for (i in 0...3)
								if (ImGui.selectable(["Always on", "On chosen maps", "Off"][i] + "##hub_set_mode_" + s.id + "_" + i, s.mode == i)) {
									s.mode = i; cfg.markSetsDirty(); SettingsStore.markDirty();
								}
						} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
						ImGui.endCombo();
					}
					ImGui.sameLine(0, 8);
					var chip = setChip(cfg, s);
					ImGui.textColored(solarflare.ui.ThemePalette.status(chip.kind), chip.text);
				});
			}
		});
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
			if (cfg.sets.length > 0 && ImGui.beginMenu("Move to set")) {
				try {
					if (ImGui.menuItem("Shared", "", AuraConfig.tagOf(a).length == 0)) { snapshot("Move to set"); cfg.moveToSet(a, ""); SettingsStore.markDirty(); }
					for (set in cfg.sets)
						if (set != null && ImGui.menuItem(set.name + "##ab_mv_" + set.id, "", AuraConfig.tagOf(a) == set.id)) {
							snapshot("Move to set"); cfg.moveToSet(a, set.id); SettingsStore.markDirty();
						}
				} catch (e:Dynamic) { ImGui.endMenu(); throw e; }
				ImGui.endMenu();
			}
			drawGroupMenu(a);
			if (ImGui.menuItem("Export with images")) queueShareMembers([a.id],a.name);
			if (ImGui.menuItem("Copy Aura Share Key")) {
				var share = ShareCodec.wrapJson(Json.stringify(AuraEngine.toObj(a)));
				UiActionQueue.copyText(share, 'Copied share key for ${a.name}');
			}
			if (a.isCounter.get() && ImGui.menuItem("Reset Counter")) { snapshot("Reset Counter"); a.counterValue = 0; SettingsStore.markDirty(); ToastManager.info('Counter reset for ${a.name}'); }
			ImGui.separator();
			if (ImGui.menuItem("Delete Aura")) {
				snapshot('Delete ${a.name}');
				host.uiLayouts.forgetWidget("aura:"+a.id);
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
		if (ImGui.smallButton("Export with images##ab_batch_files")) queueShareScope("Selection");
		ImGui.sameLine();
		if (ImGui.smallButton("Group##ab_batch_grp")) { var picked:Array<AuraDef> = []; forEachSelected(a -> picked.push(a)); createGroupFrom(picked); }
		if (ImGui.isItemHovered()) ImGui.setTooltip("Put the selected auras in one window that packs them together");
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

	/** One line per condition of the aura with this id, for the "A condition of another aura" picker. */
	function auraConditionSummaries(id:String):Array<String> {
		for (o in cfg.auras) if (o != null && o.id == id) return o.rule == null ? [] : [for (c in o.rule.conditions) AuraConditionEditor.humanConditionSummary(c)];
		return [];
	}

	/** Every other aura, display-group mates first, for the "Another aura is showing" condition. */
	function auraChoicesForConditions():Array<{id:String, name:String}> {
		var current = selectedAura();
		var mates:Array<{id:String, name:String}> = [], others:Array<{id:String, name:String}> = [];
		for (o in cfg.auras) {
			if (o == null || o == current) continue;
			var inGroup = current != null && current.group != null && current.group.length > 0 && o.group == current.group;
			(inGroup ? mates : others).push({id: o.id, name: (inGroup ? "[group] " : "") + o.displayLabel()});
		}
		return mates.concat(others);
	}

	// ---- CanvasHost: the Canvas Editor window edits this builder's selected aura -------------
	public function canvasSelectedAura():AuraDef return selectedAura();
	public function canvasSnapshot(name:String):Void {
		var a = selectedAura();
		if (a == null) { snapshot(name); return; }
		undoManager.push(name, canvasDump(a));
	}
	public function canvasSnapshotAll(name:String):Void snapshot(name);
	public function canvasSnapshotJson():String {
		var a = selectedAura();
		return a == null ? snapshotJson() : canvasDump(a);
	}
	public function canvasUndo():Void performUndo();
	public function canvasRedo():Void performRedo();
	public function canvasCanUndo():Bool return undoManager.canUndo();
	public function canvasCanRedo():Bool return undoManager.canRedo();

	// ---- Scoped (single-aura canvas) undo ---------------------------------------------------
	// Logic lives in AuraCanvasSnapshot / AuraUndoCoordinator so it can be tested without the game.

	function canvasDump(a:AuraDef):String return AuraCanvasSnapshot.dump(a.id, a.canvasElements, a.states, a.w.get(), a.h.get());

	function auraById(id:String):AuraDef {
		for (o in cfg.auras) if (o != null && o.id == id) return o;
		return null;
	}

	function captureCanvasById(id:String):String {
		var a = auraById(id);
		return a != null ? canvasDump(a) : null;
	}

	function performUndo():Void undoCoordinator.undo();

	function performRedo():Void undoCoordinator.redo();

	function restoreCanvas(state:String):Bool {
		var parsed = AuraCanvasSnapshot.parse(state);
		var a = parsed != null ? auraById(parsed.id) : null;
		if (a == null) { ToastManager.warn("That aura no longer exists."); return false; }
		a.canvasElements = parsed.elements;
		a.states = parsed.states;
		if (parsed.w > 0) a.w.set(parsed.w);
		if (parsed.h > 0) a.h.set(parsed.h);
		a.sizeDirty = true;
		selected = cfg.auras.indexOf(a);
		creationHomeOpen = false;
		canvasEditor.afterExternalRestore();
		SettingsStore.markDirty();
		return true;
	}

	public function canvasUndoPush(name:String, state:String):Void undoManager.push(name, state);
	public function canvasPreview():solarflare.aura.preview.AdvancedAuraPreview return advancedPreview;
	public function canvasAuras():Array<AuraDef> return cfg.auras;
	public function canvasPrecise():Void canvasSnapshot("Adjust canvas value");
	public function canvasHostOpen():Bool return open.get();

	function canvasUndoBase():String {
		try return snapshotJson() catch (_:Dynamic) return null;
	}

	/** Push one undo step per typed edit: capture on activation, commit when the edit lands. */
	function canvasFieldUndo(action:String):Void {
		if (ImGui.isItemActivated()) canvasFieldUndoState = canvasUndoBase();
		if (ImGui.isItemDeactivatedAfterEdit() && canvasFieldUndoState != null) {
			undoManager.push(action, canvasFieldUndoState);
			canvasFieldUndoState = null;
		}
	}

	/** Under the preview: turn this aura into a freeform canvas, or open the editor for the one it already is. */
	function drawCanvasLauncher(a:AuraDef, w:Single):Void {
		ImGui.spacing();
		if (a.region != "canvas") {
			if (UiChrome.ghostButton("Freeform Canvas...##ab_canvas_launcher", ImGui.vec2(w, 30))) { enableCanvas(a); canvasEditor.open.set(true); }
			if (ImGui.isItemHovered()) ImGui.setTooltip("Design this aura's look freely with text, icons, your own images and shapes. Pick another Style to go back.");
			return;
		}
		var n = a.canvasElements != null ? a.canvasElements.length : 0;
		drawSectionCard("Freeform Canvas", n + " element" + (n == 1 ? "" : "s"), true, function() {
			ImGui.pushStyleColor(ImGuiCol.Text, solarflare.ui.ThemePalette.current().textDisabled);
			ImGui.textWrapped("Text, icons, your images and shapes, laid out freely. Looks (states) below change what shows.");
			ImGui.popStyleColor();
			if (UiChrome.ghostButton((canvasEditor.open.get() ? "Canvas Editor is open" : "Open Canvas Editor") + "##ab_canvas_launcher", ImGui.vec2(-1, 30))) canvasEditor.open.set(true);
			if (ImGui.isItemHovered()) ImGui.setTooltip("Full-size stage, layers, properties and your image library in a separate window.");
		});
	}

	/** Switch to the canvas face, seeding it with this aura's current icon so the preview never goes blank. */
	function enableCanvas(a:AuraDef):Void {
		snapshot("Use Freeform Canvas");
		a.region = "canvas";
		if (a.canvasElements == null) a.canvasElements = [];
		if (a.canvasElements.length == 0) a.canvasElements.push(AuraCanvasElement.icon(a.preferredIconId(), 0, 0, 0, 0));
		a.sizeDirty = true;
		canvasEditor.canvasSel = -1;
		SettingsStore.markDirty();
	}

	inline function formLabel(label:String):Void { ImGui.alignTextToFramePadding(); ImGui.text(label); }

	function drawIoModal():Void {
		if (ioModalRequest) { ioOwnerGeneration=FeatureProfiles.statusOwnerGen; ImGui.openPopup("Aura Import / Export##ab_io_modal"); ioModalRequest = false; }
		ImGui.setNextWindowSize(ImGui.vec2(620,640),ImGuiCond.FirstUseEver);
		ImGui.setNextWindowSizeConstraints(ImGui.vec2(520,360),ImGui.vec2(Math.max(520,solarflare.ui.HudChrome.viewportWidth-32),Math.max(360,solarflare.ui.HudChrome.viewportHeight-32)));
		if (ImGui.beginPopupModal("Aura Import / Export##ab_io_modal", null, 0)) {
   if(ioOwnerGeneration!=FeatureProfiles.statusOwnerGen) { ImGui.closeCurrentPopup(); ImGui.endPopup(); return; }
		 try {
			var a = selectedAura();
			sharePanel.draw(a!=null,countSelected()>0,a!=null && cfg.groupOf(a)!=null,a!=null && AuraConfig.tagOf(a).length>0);
			ImGui.separator();
			if (a != null) drawShare(a);
			else {
				ImGui.textWrapped("Select an aura to copy its share key, or import a pack into the library.");
				if (UiChrome.ghostButton("Paste & Import from Clipboard##ab_clip_import_empty", ImGui.vec2(260, 26))) { UiActionQueue.enqueue(UiActionKind.ImportAuraClipboard); setIoStatus("Aura import queued from clipboard.", false); }
				ImGui.sameLine();
				if (UiChrome.ghostButton("Copy Entire Library##ab_copy_all_empty", ImGui.vec2(180, 26))) { UiActionQueue.enqueue(UiActionKind.ExportAuraPack); setIoStatus("Aura pack export queued.", false); }
				ImGui.inputTextMultiline("##ab_import_area_empty", importBuf, JSON_BUF, ImGui.vec2(-1, 120));
				if (UiChrome.ghostButton("Import from Text Box##ab_do_import_empty", ImGui.vec2(180, 26))) importJson();
				if (ioStatus.length > 0) ImGui.textColored(ioStatusError ? ImGui.vec4(1, 0.35, 0.35, 1) : ImGui.vec4(0.35, 0.9, 0.5, 1), ioStatus);
			}
			ImGui.separator();
			if (UiChrome.ghostButton("Close##ab_io_close", ImGui.vec2(120, 28))) ImGui.closeCurrentPopup();
		 } catch(e:Dynamic) { ImGui.endPopup(); throw e; }
			ImGui.endPopup();
		}
	}

	function drawAppearance(a:AuraDef):Void {
		UiLayout.propertyGrid("##ab_appear_props", function() {
			UiLayout.propertyRow("Style", function() {
				if (ImGui.beginCombo("##ab_region", regionLabel(a.region))) {
					// Freeform Canvas has its own button under the preview; it still shows here while active.
					for (rKey in ["bar", "ring", "text", "icon"])
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
			drawCounterRow(a);
			drawBannerRows(a);
			drawCanvasTextRow(a);
			UiLayout.propertyRow(a.region == "text" ? "Message" : "Alert text", function() {
				var edited = a.region == "text"
					? ImGui.inputTextMultiline("##ab_announce", a.announceBuf, AuraDef.ANN_BUF, ImGui.vec2(-1, 90))
					: ImGui.inputText("##ab_announce", a.announceBuf, AuraDef.ANN_BUF);
				if (edited) {
					a.announce = ByteUtil.readString(a.announceBuf, AuraDef.ANN_BUF, false);
					SettingsStore.markDirty();
				}
			});
			if (a.region == "text") {
				UiLayout.propertyRow("Font size", function() {
					if (ImGui.inputFloat("##ab_text_size", a.textSize, 0, 0, "%.1f px")) {
						a.textSize.set(AuraTextLayout.fontSize(a.textSize.get()));
						SettingsStore.markDirty();
					}
				}, "Text wraps to the box width. Resize the box with its corner, or enter dimensions below.");
			}
			UiLayout.propertyRow("Opacity", function() {
				opacityPercent.set(a.opacity.get() * 100);
				if (NumberField.draw("##ab_opacity", opacityPercent, 10, 100, "%.0f%%")) {
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
			if (UiChrome.toggleChip("Show##ab_visible", a.enabled, ImGui.vec2(72, 26), false)) {
				if (a.enabled.get()) a.visual.set(true);
				SettingsStore.markDirty();
			}
			ImGui.sameLine(0, 6);
			if (UiChrome.toggleChip("Lock##ab_lock", a.chrome.locked, ImGui.vec2(72, 26), false)) {
				cfg.unlockAll.set(false);
				SettingsStore.markDirty();
			}
			ImGui.sameLine(0, 6);
			if (UiChrome.toggleChip("Always On##ab_always", a.alwaysOn, ImGui.vec2(112, 26), false))
				SettingsStore.markDirty();
			if (ImGui.isItemHovered())
				ImGui.setTooltip("Always On keeps display visible; conditions still drive counters and alerts.");
			ImGui.sameLine(0, 6);
			if (UiChrome.toggleChip("Transparent##ab_transparent", a.chrome.transparent, ImGui.vec2(128, 26), false))
				SettingsStore.markDirty();
		} catch (e:Dynamic) { ImGui.popID(); throw e; }
		ImGui.popID();
	}

	function drawWindowLayout(a:AuraDef):Void {
		UiLayout.propertyGrid("##ab_window_layout", function() {
			var inGroup = cfg.groupOf(a);
			if (inGroup != null) {
				UiLayout.propertyRow("Group", function() {
					ImGui.alignTextToFramePadding();
					ImGui.text(inGroup.name);
					ImGui.sameLine(0, 8);
					if (UiChrome.ghostButton("Open group##ab_open_grp")) openGroupEditor(inGroup);
				}, "The group window places this aura. Size and Scale still apply inside the group.");
			} else
				a.chrome.drawPositionRow("ab_pos");
			UiLayout.propertyRow("Size", function() {
				UiLayout.inlinePair(
					"##ab_wh",
					function(_:Single) {
						var changed = a.region == "text" ? ImGui.inputFloat("##ab_w", a.w, 0, 0, "W  %.0f px")
							: NumberField.draw("##ab_w", a.w, 32, 720, "W  %.0f px", preciseSnapshotFn);
						if (changed) {
							if (a.region == "text") a.w.set(Math.isFinite(a.w.get()) ? Math.max(24, Math.min(10000, a.w.get())) : 320);
							a.sizeDirty = true;
							SettingsStore.markDirty();
						}
					},
					function(_:Single) {
						var changed = a.region == "text" ? ImGui.inputFloat("##ab_h", a.h, 0, 0, "H  %.0f px")
							: NumberField.draw("##ab_h", a.h, 24, 480, "H  %.0f px", preciseSnapshotFn);
						if (changed) {
							if (a.region == "text") a.h.set(Math.isFinite(a.h.get()) ? Math.max(24, Math.min(10000, a.h.get())) : 120);
							a.sizeDirty = true;
							SettingsStore.markDirty();
						}
					}
				);
			});
			UiLayout.propertyRow("Scale", function() {
				if (NumberField.draw("##ab_scale", a.scale, 0.5, a.region == "canvas" ? 6 : 2.5, "%.2f", preciseSnapshotFn)) {
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
		UiLayout.propertyGrid("##ab_icon_visibility", function() {
			UiLayout.propertyRow("Icon visibility", function() {
				var before=a.showIcon.get();
				if (ImGui.checkbox("Show icon##ab_show_icon",a.showIcon)) {
					var value=a.showIcon.get(); a.showIcon.set(before); snapshot("Icon visibility"); a.showIcon.set(value); SettingsStore.markDirty();
				}
			},"Tracking, text and enabled badges remain active when the icon is hidden.");
		});
		var key = a.preferredIconId();
		if (!GameIcons.imageKey(key, 44, 44)) {
			drawIconPlaceholder(key, 44, 44); ImGui.sameLine();
			ImGui.textDisabled(key.length > 0 ? "Icon art is loading or unavailable." : "No automatic icon is available.");
		} else { ImGui.sameLine(); ImGui.textWrapped((a.iconId.length > 0 ? "Custom: " : "Automatic: ") + key); }
		if (a.iconId.length > 0 && UiChrome.ghostButton("Use Automatic Icon##ab_icon_auto")) { a.iconId = ""; a.plate = ""; a.syncIconBuf(); SettingsStore.markDirty(); }
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
			UiLayout.propertyRow("Show aura", function() {
				if (ImGui.beginCombo("##ab_behavior", behaviorLabel(mode))) {
					for (key in ["whileTrue", "onRiseHold", "whileFalse"])
						if (ImGui.selectable(behaviorLabel(key) + "##ab_behavior_" + key, mode == key)) {
							applyBehavior(a, key);
							SettingsStore.markDirty();
						}
					ImGui.endCombo();
				}
			}, "Conditions control the normal display. A running countdown or countup also keeps the aura visible.");
			var wantDuration = mode == "onRiseHold" || (a.showBanner != null && a.showBanner.get());
			if (wantDuration) {
				UiLayout.propertyRow("Duration", function() {
					if (NumberField.draw("##ab_hold", a.durRef, 0.5, 10, "%.1f s")) {
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
			if (NumberField.draw("##ab_boss_alert_scale", a.bannerScale, 1, 3, "%.1fx", preciseSnapshotFn)) SettingsStore.markDirty();
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
					canvasEditor.canvasSel = a.canvasElements.length - 1;
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
		}, "Tokens: {time} {stacks} {counter} {name}. Full placement lives in Canvas Elements below.");
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
					if (NumberField.draw("##ab_volume", volumePercent, 0, 100, "%.0f%%")) {
						a.volume.set(volumePercent.get() * 0.01);
						SettingsStore.markDirty();
					}
				});
			}
		});
	}

	function drawShare(a:AuraDef):Void {
		if (ImGui.collapsingHeader("Share or Back Up##ab_export_sec", imgui.Enums.ImGuiTreeNodeFlags.DefaultOpen)) {
			ImGui.textWrapped("Clipboard keys contain settings only. Export with images below includes the custom PNG files.");
			if (UiChrome.ghostButton("Copy Selected to Clipboard##ab_copy_sel", ImGui.vec2(190, 26))) {
				exportString = ShareCodec.wrapJson(Json.stringify(AuraEngine.toObj(a)));
				fillBuf(exportBuf, JSON_BUF, exportString);
				UiActionQueue.copyText(exportString, 'Aura "${a.name}" share key copied!');
				setIoStatus('Aura "${a.name}" queued for clipboard copy.', false);
			}
			ImGui.sameLine();
			if (UiChrome.ghostButton("Copy Entire Library##ab_copy_all", ImGui.vec2(160, 26))) { UiActionQueue.enqueue(UiActionKind.ExportAuraPack); setIoStatus("Aura pack export queued.", false); }
			if (exportString.length > 0) {
				ImGui.textDisabled("Share key preview (canonical string unchanged - use Copy):");
				ImGui.beginChild("##ab_export_preview", ImGui.vec2(-1, 80), ImGuiChildFlags.Borders);
				ImGui.textWrapped(exportString);
				ImGui.endChild();
			}
		}
		if (ImGui.collapsingHeader("Import Aura Share Key / JSON##ab_import_sec", imgui.Enums.ImGuiTreeNodeFlags.DefaultOpen)) {
			if (UiChrome.ghostButton("Paste & Import from Clipboard##ab_clip_import", ImGui.vec2(220, 26))) { UiActionQueue.enqueue(UiActionKind.ImportAuraClipboard); setIoStatus("Aura import queued from clipboard.", false); }
			ImGui.sameLine();
			if (UiChrome.ghostButton("Import from Text Box##ab_do_import", ImGui.vec2(160, 26))) importJson();
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
			for (item in imported) { if (item == null || cfg.auras.length >= AuraEngine.MAX) break; item.id = uniqueAuraId(item.id); cfg.auras.push(item); added++; } cfg.ensureSets();
			cfg.addImportedGroups(pendingImportGroups); pendingImportGroups = null; cfg.ensureGroups();
			if (added == 0) { setIoStatus(cfg.auras.length >= AuraEngine.MAX ? "The Aura library is full." : "No valid Aura objects were found.", true); ToastManager.error("No valid Aura objects found."); }
			else { selected = cfg.auras.length - 1; creationHomeOpen = false; deleteArmed = -1; SettingsStore.markDirty(); var msg = added + " Aura(s) imported successfully!"; setIoStatus(msg, false); ToastManager.success(msg); }
		} catch (_:Dynamic) { setIoStatus("Import failed: invalid Aura share key or JSON.", true); ToastManager.error("Import failed: invalid Aura share key or JSON."); }
	}

	function importAurasFromJson(json:String):Array<AuraDef> {
		var d:Dynamic = Json.parse(json);
		if (d == null) return [];
		var isPack = Std.isOfType(d, Array) || (d.auras != null) || (d.kind != null && Std.string(d.kind) == AuraPack.KIND);
		// A pack that carries groups re-forms them under fresh ids; otherwise tags survive only if the group exists here.
		pendingImportGroups = null;
		if (isPack && !Std.isOfType(d, Array) && d.groups != null && d.auras != null)
			pendingImportGroups = AuraGroupDef.remapImport(d.groups, cast d.auras, function(id) return cfg.findGroup(id) != null);
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
		if ((a.rule == null || a.rule.conditions == null || a.rule.conditions.length == 0) && !a.alwaysOn.get()) return "Add at least one condition.";
		if (a.rule != null && a.rule.conditions != null) for (c in a.rule.conditions) {
			if (c == null || AuraSignalCatalog.find(c.signal) == null) return "Choose what each condition should check.";
			var d = AuraSignalCatalog.find(c.signal);
			if (d != null && d.subjectKind.length > 0 && StringTools.trim(c.subject).length == 0) return "Choose a specific target for the highlighted condition.";
			if(d!=null && d.subjectKind=="statusType" && solarflare.cdb.StatusTypeCatalog.index(c.subject)<0) return "Choose a general status type for the highlighted condition.";
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
			case "text": "Text box";
			case "icon": "Icon Alert";
			case "canvas": "Freeform Canvas";
			default: "HUD Status Bar";
		};
	}

	static function fillBuf(buf:hl.Bytes, cap:Int, value:String):Void { ByteUtil.fillBuf(buf, cap, value); }
	static function readBytes(buf:hl.Bytes, cap:Int):String { return ByteUtil.readBytes(buf, cap); }
}

/** One library row: 0 = aura, 1 = group header (index = member count), 2 = aura inside a group block. */
private typedef AuraListEntry = {kind:Int, index:Int, group:AuraGroupDef};
