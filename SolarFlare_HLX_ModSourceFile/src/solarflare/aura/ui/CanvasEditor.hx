package solarflare.aura.ui;

import solarflare.aura.*;
import solarflare.ui.EditorWindow;
import solarflare.ui.UiChrome;
import solarflare.ui.UiLayout;
import solarflare.ui.UiScope;
import solarflare.ui.NumberField;
import solarflare.ui.CustomImages;
import solarflare.ui.CustomSounds;
import solarflare.ui.SettingsStore;
import solarflare.ui.ByteUtil;
import solarflare.ui.GameIcons;
import solarflare.ui.UiActionQueue;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.DragDropHelper.PayloadExt;
import solarflare.aura.AuraVectorPath.SvgImport;
import solarflare.aura.AuraVectorPath.PathNode;
import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiKey;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;

/**
 * Freeform Canvas Editor window: large stage, layers, typed properties and the image library.
 * Edits the Aura Builder's selected aura through CanvasHost, so undo, save and preview stay shared.
 */
class CanvasEditor {
	public var open = new BoolRef(false);
	var host:CanvasHost;
	public var canvasSel:Int = -1;
	var canvasEditX = new FloatRef(0);
	var canvasEditY = new FloatRef(0);
	var canvasEditW = new FloatRef(48);
	var canvasEditH = new FloatRef(48);
	var canvasEditFs = new FloatRef(16);
	var canvasColBuf:hl.Bytes = ImGui.v4(1, 1, 1, 1);
	var edgeColBuf:hl.Bytes = ImGui.v4(1, 1, 1, 1);
	var edgeColEl:AuraCanvasElement = null;
	var edgeColValue:Int = 0;
	var edgeColEditing:Bool = false;
	var canvasEditEdge = new FloatRef(2);
	var lastCanvasColorAuraId:String = "";
	var lastCanvasColorSel:Int = -1;
	var canvasContentBuf = new hl.Bytes(CANVAS_CONTENT_BUF);
	static inline var CANVAS_CONTENT_BUF:Int = 160;
	var canvasEditStroke = new FloatRef(0);
	var canvasEditSides = new FloatRef(5);
	var canvasEditBox = new FloatRef(0);
	var canvasEditOutline = new FloatRef(0);
	var canvasNameBuf = new hl.Bytes(AuraCanvasElement.MAX_NAME * 4);
	var canvasCol2Buf:hl.Bytes = ImGui.v4(1, 1, 1, 0);
	var canvasColor2Editing:Bool = false;
	var canvasStrokeBuf:hl.Bytes = ImGui.v4(1, 1, 1, 1);
	var canvasStrokeEditing:Bool = false;
	var canvasEditOpacity = new FloatRef(100);
	var canvasEditRot = new FloatRef(0);
	var canvasFlagRef = new BoolRef(false);
	var canvasSnap = new BoolRef(true);
	var canvasRuleContexts = new haxe.ds.ObjectMap<AuraCanvasElement, solarflare.aura.signal.AuraRuleEditorContext>();
	var nextCanvasRuleId:Int = 1;
	var lastCanvasColorEl:AuraCanvasElement = null;
	var lastCanvasColorValue:Int = 0;
	var canvasColorEditing:Bool = false;
	var canvasDragMode:Int = 0;
	var canvasDragX:Float = 0;
	var canvasDragY:Float = 0;
	var canvasDragW:Float = 0;
	var canvasDragH:Float = 0;
	var canvasDragMoved:Bool = false;
	var canvasDragUndo:String = null;
	var canvasFieldUndoState:String = null;
	var canvasNudgeStamp:Float = 0;
	/** Scratch box written by canvasBox(); avoids a per-hit-test allocation. */
	var cvBoxX:Float = 0;
	var cvBoxY:Float = 0;
	var cvBoxW:Float = 0;
	var cvBoxH:Float = 0;
	var canvasImgComboOpen:Bool = false;
	static inline var CANVAS_IMPORT_BUF:Int = 520;
	var canvasImportBuf = new hl.Bytes(CANVAS_IMPORT_BUF);
	var canvasImportMsg:String = "";
	var canvasImportErr:Bool = false;
	static inline var CANVAS_FOLDER_BUF:Int = 1024;
	var canvasFolderBuf = new hl.Bytes(CANVAS_FOLDER_BUF);
	var canvasFolderGeneration:Int = -1;
	var canvasFolderMsg:String = "";
	var canvasFolderError:Bool = false;
	var canvasRowIds = new haxe.ds.ObjectMap<AuraCanvasElement, Int>();
	var canvasRowOwner:AuraDef;
	var nextCanvasRowId:Int = 1;
	var imageLibrary:ImageLibraryPanel;
	var iconPicker = new GameIconPicker();
	var preciseFn:Void->Void;
	var stageMaxH:Single = 280;

	public function new(host:CanvasHost) {
		this.host = host;
		preciseFn = function() host.canvasPrecise();
		ByteUtil.clearBytes(canvasContentBuf, CANVAS_CONTENT_BUF);
		ByteUtil.clearBytes(canvasImportBuf, CANVAS_IMPORT_BUF);
		ByteUtil.clearBytes(canvasFolderBuf, CANVAS_FOLDER_BUF);
		imageLibrary = new ImageLibraryPanel(function() return host.canvasAuras(), function(name) host.canvasSnapshotAll(name));
	}

	/** Called after undo/redo rewrote this aura's elements and states behind the editor's back. */
	public function afterExternalRestore():Void {
		resetPathTools();
		canvasSel = -1;
		canvasMulti = [];
		canvasDragMode = CANVAS_DRAG_NONE;
		canvasDragUndo = null;
		canvasFieldUndoState = null;
		resetRuleContexts();
		stateRuleContexts = new haxe.ds.ObjectMap();
		canvasRowOwner = null;
		canvasRowIds = new haxe.ds.ObjectMap<AuraCanvasElement, Int>();
		invalidateColor();
		stateDeleteArmed = "";
		stateNameFor = null;
	}

	public function invalidateColor():Void { lastCanvasColorAuraId = ""; lastCanvasColorSel = -1; }
	public function resetRuleContexts():Void canvasRuleContexts = new haxe.ds.ObjectMap();

	public function clearTransientState():Void {
		releasePreview();
		for (a in host.canvasAuras()) if (a != null) a.previewState = null;
		imageLibrary.clearTransientState();
		resetRuleContexts();
		canvasSel = -1;
		invalidateColor();
		resetCanvasTransient();
	}

	inline function builderSectionHeader(label:String):Void UiChrome.subHeader(label);

	// ---- Window -----------------------------------------------------------------------------

	public function draw():Void {
		if (!open.get()) { if (haxe.Timer.stamp() - lastPreviewSync > 0.3) releasePreview(); return; }
		if (!CursorCaptureFix.cursorFree) return;
		EditorWindow.drawMenuWindow("Canvas Editor###SolarFlare.CanvasEditor", open, 1180, 780, drawBody);
	}


	// ================================================================================================
	// Editor layout
	//   Menu bar ........ every command, with shortcuts
	//   Toolbar ......... tools, insert, edit, align, arrange, view
	//   Look bar ........ which look (state) the stage is showing / editing
	//   Left ............ Layers | Looks        Centre ... stage        Right ... Inspector | Library | Canvas
	//   Status bar ...... cursor, zoom, selection
	// ================================================================================================

	static inline var CLIP_PREFIX:String = "solarflare.canvas:";
	static inline var MAX_LAYERS:Int = 512;

	var tool:Int = 0;
	var showGrid = new BoolRef(true);
	var showGuides = new BoolRef(true);
	var showBounds = new BoolRef(false);
	var snapStep:Float = 4;
	var gridDraw:Float = 16;
	var stageBg:Int = 0;
	var guideX:Float = Math.NaN;
	var guideY:Float = Math.NaN;
	var cursorX:Float = Math.NaN;
	var cursorY:Float = Math.NaN;
	var clip:Array<Dynamic> = [];
	var pasteCount:Int = 0;
	var dragGroup:{x:Float, y:Float, w:Float, h:Float} = null;
	var tbUsed:Float = 0;
	var tbAvail:Float = 0;
	var tbFirst:Bool = true;
	var tbIndex:Int = 0;
	static var STAGE_BACKGROUNDS:Array<String> = ["Dark", "Mid grey", "Light", "Checker"];
	static var SNAP_STEPS:Array<Float> = [1, 2, 4, 8, 16];
	static var SIZE_PRESETS:Array<Int> = [48, 64, 96, 128, 160, 192, 256];

	function drawBody():Void {
		var a = host.canvasSelectedAura();
		if (a == null) {
			ImGui.textDisabled("Select an aura in the Aura Builder to edit its canvas.");
			return;
		}
		if (a.region != "canvas") {
			ImGui.textWrapped(a.name + " is not a freeform canvas aura. Choose Freeform Canvas under its preview in the Aura Builder.");
			return;
		}
		if (a.canvasElements == null) a.canvasElements = [];
		if (canvasSel >= a.canvasElements.length) canvasSel = -1;
		canvasMulti = canvasMulti.filter(function(i) return i < a.canvasElements.length && i != canvasSel);
		syncPreview(a);
		drawMenuBar(a);
		if (handleGlobalKeys(a)) return;
		drawToolbar(a);
		drawLookBar(a);
		ImGui.separator();

		var avail = ImGui.getContentRegionAvail();
		var statusH:Single = 24;
		var paneH:Single = Math.max(280, avail.y - statusH);
		var leftW:Single = Math.max(200, Math.min(280, avail.x * 0.2));
		var rightW:Single = Math.max(280, Math.min(380, avail.x * 0.28));
		var centreW:Single = Math.max(260, avail.x - leftW - rightW - 16);
		var borders = imgui.Enums.ImGuiChildFlags.Borders;

		if (ImGui.beginChild("##cv_left", ImGui.vec2(leftW, paneH), borders)) {
			try drawLeftPanel(a) catch (e:Dynamic) { ImGui.endChild(); throw e; }
		}
		ImGui.endChild();
		ImGui.sameLine(0, 6);
		if (ImGui.beginChild("##cv_centre", ImGui.vec2(centreW, paneH), borders)) {
			try {
				stageMaxH = Math.max(200, paneH - 16);
				drawCanvasStage(a);
			} catch (e:Dynamic) { ImGui.endChild(); throw e; }
		}
		ImGui.endChild();
		ImGui.sameLine(0, 6);
		if (ImGui.beginChild("##cv_right", ImGui.vec2(0, paneH), borders)) {
			try drawRightPanel(a) catch (e:Dynamic) { ImGui.endChild(); throw e; }
		}
		ImGui.endChild();
		drawStatusBar(a);
		drawSvgModal(a);
	}

	// ---- Panels ------------------------------------------------------------------------------

	function drawLeftPanel(a:AuraDef):Void {
		if (ImGui.beginTabBar("##cv_left_tabs", imgui.Enums.ImGuiTabBarFlags.DrawSelectedOverline)) {
			try {
				if (UiChrome.beginTabItem("Layers##cv_tab_layers")) {
					try {
						ImGui.textDisabled("Layers are the pieces of the design.");
						if (a.canvasElements.length == 0) {
							UiChrome.gap(4);
							wrappedHint("No layers yet. Use Insert in the toolbar or menu to add text, a game icon, one of your images, a shape, or a ready-made preset.");
						} else drawCanvasLayers(a);
					} catch (e:Dynamic) { ImGui.endTabItem(); throw e; }
					ImGui.endTabItem();
				}
				if (UiChrome.beginTabItem("Looks##cv_tab_looks")) {
					try {
						UiChrome.gap(4);
						drawStateHints(a);
						var st = AuraStateDef.find(a.states, editState);
						if (st != null) {
							ImGui.separator();
							UiChrome.subHeader("Settings for " + st.name);
							drawStateSettings(a, st);
						} else if (a.states.length == 0 && ImGui.button("Add a look##cv_add_first_look", ImGui.vec2(-1, 0))) addState(a);
					} catch (e:Dynamic) { ImGui.endTabItem(); throw e; }
					ImGui.endTabItem();
				}
			} catch (e:Dynamic) { ImGui.endTabBar(); throw e; }
			ImGui.endTabBar();
		}
	}

	function drawRightPanel(a:AuraDef):Void {
		if (ImGui.beginTabBar("##cv_right_tabs", imgui.Enums.ImGuiTabBarFlags.DrawSelectedOverline)) {
			try {
				if (UiChrome.beginTabItem("Inspector##cv_tab_inspector")) {
					try {
						var el = canvasSel >= 0 ? a.canvasElements[canvasSel] : null;
						if (el == null) drawInspectorEmpty(a);
						else {
							if (canvasMulti.length > 0) drawMultiSelectBar(a);
							drawCanvasProperties(a, el);
							drawPathTools(a, el);
							drawAnimationSection(a, el);
						}
					} catch (e:Dynamic) { ImGui.endTabItem(); throw e; }
					ImGui.endTabItem();
				}
				if (UiChrome.beginTabItem("Library##cv_tab_library")) {
					try {
						UiChrome.gap(4);
						imageLibrary.draw("cv_lib", function(stem) {
							addCanvasElement(a, AuraCanvasElement.icon(CustomImages.key(stem), 8, 8, 48, 48), "Canvas Add Image", false);
						}, "Add to canvas");
						ImGui.separator();
						drawCanvasAssetFolder();
					} catch (e:Dynamic) { ImGui.endTabItem(); throw e; }
					ImGui.endTabItem();
				}
				if (UiChrome.beginTabItem("Canvas##cv_tab_canvas")) {
					try drawCanvasSettings(a) catch (e:Dynamic) { ImGui.endTabItem(); throw e; }
					ImGui.endTabItem();
				}
			} catch (e:Dynamic) { ImGui.endTabBar(); throw e; }
			ImGui.endTabBar();
		}
	}

	function drawInspectorEmpty(a:AuraDef):Void {
		UiChrome.gap(4);
		UiChrome.subHeader("Nothing selected");
		wrappedHint(a.canvasElements.length == 0
			? "Start with Insert: Text, Icon, Image, Shape or a Preset. Everything you add can be moved, resized, aligned and recoloured here."
			: "Click a layer on the stage or in Layers to edit its position, size, colour, visibility and per-look overrides.");
		UiChrome.subHeader("Quick start");
		for (row in ["Drag to move; drag empty space to box-select", "Ctrl+click adds to the selection", "Corner and edge handles resize; Shift keeps the ratio",
				"The round handle rotates shapes", "Arrows nudge (Shift = 10 px)", "Space+drag or middle-drag pans; + / - zoom; 0 resets"])
			wrappedHint("- " + row);
	}

	function drawCanvasSettings(a:AuraDef):Void {
		UiChrome.gap(4);
		UiLayout.propertyGrid("##cv_canvas_props", function() {
			UiLayout.propertyRow("Size", function() {
				UiLayout.inlinePair("##cv_size",
					function(_:Single) { if (NumberField.draw("##cv_aw", a.w, 24, 720, "W  %.0f", preciseFn)) { a.sizeDirty = true; SettingsStore.markDirty(); } },
					function(_:Single) { if (NumberField.draw("##cv_ah", a.h, 24, 480, "H  %.0f", preciseFn)) { a.sizeDirty = true; SettingsStore.markDirty(); } });
			}, "The aura's width and height in pixels, before Scale. Layers are positioned inside this box.");
			UiLayout.propertyRow("Presets", function() {
				if (ImGui.beginCombo("##cv_size_preset", "Square sizes")) {
					for (n in SIZE_PRESETS) if (ImGui.selectable(n + " x " + n + "##cv_sz_" + n)) setCanvasSize(a, n, n);
					ImGui.endCombo();
				}
			});
			UiLayout.propertyRow("Background", function() {
				if (ImGui.beginCombo("##cv_bg", STAGE_BACKGROUNDS[stageBg])) {
					for (i in 0...STAGE_BACKGROUNDS.length) if (ImGui.selectable(STAGE_BACKGROUNDS[i] + "##cv_bg_" + i, stageBg == i)) stageBg = i;
					ImGui.endCombo();
				}
			}, "Only changes this editor. Use Light or Checker to judge dark artwork, Dark for light text.");
			UiLayout.propertyRow("Grid", function() {
				ImGui.checkbox("Show##cv_show_grid", showGrid);
				ImGui.sameLine(0, 12);
				canvasFlagRef.set(canvasSnap.get());
				if (ImGui.checkbox("Snap##cv_snap_cfg", canvasSnap)) {}
			});
			UiLayout.propertyRow("Snap step", function() {
				if (ImGui.beginCombo("##cv_snap_step", Std.string(Std.int(snapStep)) + " px")) {
					for (v in SNAP_STEPS) if (ImGui.selectable(Std.int(v) + " px##cv_ss_" + Std.int(v), snapStep == v)) snapStep = v;
					ImGui.endCombo();
				}
			}, "Drags and resizes land on multiples of this. Hold Alt to place freely.");
			UiLayout.propertyRow("Guides", function() {
				ImGui.checkbox("Smart guides##cv_guides", showGuides);
				ImGui.sameLine(0, 12);
				ImGui.checkbox("Layer outlines##cv_bounds", showBounds);
			}, "Smart guides snap a moving layer to the aura's edges and centre and to other layers.");
			UiLayout.propertyRow("Preview", function() {
				var live = host.canvasPreview().liveCanvasConditions;
				if (ImGui.beginCombo("##cv_preview_mode", live ? "Live conditions" : "Edit all layers")) {
					if (ImGui.selectable("Edit all layers##cv_pm0", !live)) host.canvasPreview().liveCanvasConditions = false;
					if (ImGui.selectable("Live conditions##cv_pm1", live)) host.canvasPreview().liveCanvasConditions = true;
					ImGui.endCombo();
				}
			}, "Live conditions use observed game state. The Stacks simulation changes display text only.");
		});
	}

	function setCanvasSize(a:AuraDef, w:Int, h:Int):Void {
		host.canvasSnapshot("Canvas Size");
		a.w.set(w); a.h.set(h);
		a.sizeDirty = true;
		SettingsStore.markDirty();
	}

	// ---- Look bar and status bar -------------------------------------------------------------

	function drawLookBar(a:AuraDef):Void {
		ImGui.alignTextToFramePadding();
		ImGui.textDisabled("Looks");
		if (ImGui.isItemHovered()) ImGui.setTooltip("A look is an alternate design of this canvas. Layers are the shapes, text and images; looks decide which layers show and where. Conditions pick the look in game.");
		ImGui.sameLine(0, 8);
		drawStateTabs(a);
		if (editState != "") {
			var theme = solarflare.ui.ThemePalette.current();
			ImGui.alignTextToFramePadding();
			ImGui.textColored(theme.accent, "Editing look: " + stateLabel(a, editState));
			ImGui.sameLine(0, 8);
			ImGui.textDisabled("Position, size, colour and Hidden changes apply to this look only.");
			ImGui.sameLine(0, 8);
			if (ImGui.smallButton("Back to Default##cv_back_default")) { editState = ""; stateDeleteArmed = ""; }
		}
	}

	function addState(a:AuraDef):Void {
		if (a.states.length >= AuraStateDef.MAX_STATES) return;
		host.canvasSnapshot("Add State");
		var st = new AuraStateDef(AuraStateDef.uniqueId(a.states), "State " + (a.states.length + 1));
		a.states.push(st);
		editState = st.id;
		SettingsStore.markDirty();
	}

	/** Copies the look being edited (its trigger, which layers show in it and their per-look values) and switches to the copy. */
	function duplicateState(a:AuraDef):Void {
		var src = AuraStateDef.find(a.states, editState);
		if (src == null || a.states.length >= AuraStateDef.MAX_STATES) return;
		host.canvasSnapshot("Duplicate State");
		var copy = AuraStateDef.duplicate(a.states, a.canvasElements, src.id);
		if (copy == null) return;
		editState = copy.id;
		SettingsStore.markDirty();
		solarflare.ui.ToastManager.info("Copied \"" + src.name + "\". Change its trigger (for example the stack number) below.");
	}

	function drawStatusBar(a:AuraDef):Void {
		var parts:Array<String> = [];
		parts.push(Math.isNaN(cursorX) ? "x -, y -" : "x " + Math.round(cursorX) + ", y " + Math.round(cursorY));
		parts.push("Zoom " + Math.round(zoom * 100) + "%");
		var picks = selectedIndices();
		if (picks.length == 1 && picks[0] < a.canvasElements.length) {
			var b = elementBounds(a, a.canvasElements[picks[0]]);
			parts.push("1 layer: " + Math.round(b.x) + ", " + Math.round(b.y) + "  " + Math.round(b.w) + " x " + Math.round(b.h));
		} else parts.push(picks.length == 0 ? a.canvasElements.length + " layers" : picks.length + " selected");
		parts.push("Canvas " + Math.round(a.w.get()) + " x " + Math.round(a.h.get()));
		parts.push("Look: " + stateLabel(a, editState));
		parts.push(canvasSnap.get() ? "Snap " + Std.int(snapStep) + " px" : "Snap off");
		ImGui.alignTextToFramePadding();
		ImGui.textDisabled(parts.join("   |   "));
		if (hintText.length > 0) {
			ImGui.sameLine(0, 16);
			ImGui.textColored(solarflare.ui.ThemePalette.current().accent, hintText);
		}
	}

	// ---- Keyboard ----------------------------------------------------------------------------

	/** Window-level shortcuts. Returns true when the frame should end (undo/redo replaced the document). */
	function handleGlobalKeys(a:AuraDef):Bool {
		if (!ImGui.isWindowFocused(imgui.Enums.ImGuiFocusedFlags.RootAndChildWindows) || ImGui.isAnyItemActive()) return false;
		var ctrl = ImGui.isKeyDown(ImGuiKey.LeftCtrl) || ImGui.isKeyDown(ImGuiKey.RightCtrl);
		var shift = ImGui.isKeyDown(ImGuiKey.LeftShift) || ImGui.isKeyDown(ImGuiKey.RightShift);
		if (ctrl) {
			if (ImGui.isKeyPressed(ImGuiKey.Z, false)) { if (shift) host.canvasRedo(); else host.canvasUndo(); return true; }
			if (ImGui.isKeyPressed(ImGuiKey.Y, false)) { host.canvasRedo(); return true; }
			if (ImGui.isKeyPressed(ImGuiKey.C, false)) copySelection(a, false);
			if (ImGui.isKeyPressed(ImGuiKey.X, false)) copySelection(a, true);
			if (ImGui.isKeyPressed(ImGuiKey.V, false)) pasteLayers(a);
			if (ImGui.isKeyPressed(ImGuiKey.G, false)) { if (shift) ungroupSelected(a); else groupSelected(a); }
			if (ImGui.isKeyPressed(ImGuiKey.RightBracket, false)) reorderKey(a, true, true);
			if (ImGui.isKeyPressed(ImGuiKey.LeftBracket, false)) reorderKey(a, false, true);
		} else {
			if (ImGui.isKeyPressed(ImGuiKey.RightBracket, false)) reorderKey(a, true, false);
			if (ImGui.isKeyPressed(ImGuiKey.LeftBracket, false)) reorderKey(a, false, false);
			if (ImGui.isKeyPressed(ImGuiKey.Escape, false)) selectOnly(-1);
			if (ImGui.isKeyPressed(ImGuiKey.V, false)) tool = TOOL_SELECT;
			if (ImGui.isKeyPressed(ImGuiKey.P, false)) tool = TOOL_PEN;
			if (ImGui.isKeyPressed(ImGuiKey.N, false)) tool = TOOL_NODES;
			if (ImGui.isKeyPressed(ImGuiKey.H, false)) tool = 1;
		}
		return false;
	}

	function reorderKey(a:AuraDef, forward:Bool, extreme:Bool):Void {
		if (canvasSel < 0 || canvasMulti.length > 0) return;
		var n = a.canvasElements.length;
		var to = forward ? (extreme ? n - 1 : canvasSel + 1) : (extreme ? 0 : canvasSel - 1);
		moveCanvasElement(a, canvasSel, to, forward ? (extreme ? "Canvas To Front" : "Canvas Bring Forward") : (extreme ? "Canvas To Back" : "Canvas Send Backward"));
	}

	// ---- Menu bar ----------------------------------------------------------------------------

	function drawMenuBar(a:AuraDef):Void {
		if (!ImGui.beginMenuBar()) return;
		try {
			if (ImGui.beginMenu("File")) {
				try drawFileMenu(a) catch (e:Dynamic) { ImGui.endMenu(); throw e; }
				ImGui.endMenu();
			}
			if (ImGui.beginMenu("Edit")) {
				try drawEditMenu(a) catch (e:Dynamic) { ImGui.endMenu(); throw e; }
				ImGui.endMenu();
			}
			if (ImGui.beginMenu("Insert")) {
				try drawInsertMenu(a) catch (e:Dynamic) { ImGui.endMenu(); throw e; }
				ImGui.endMenu();
			}
			if (ImGui.beginMenu("Arrange")) {
				try drawArrangeMenu(a) catch (e:Dynamic) { ImGui.endMenu(); throw e; }
				ImGui.endMenu();
			}
			if (ImGui.beginMenu("View")) {
				try drawViewMenu(a) catch (e:Dynamic) { ImGui.endMenu(); throw e; }
				ImGui.endMenu();
			}
			if (ImGui.beginMenu("Look")) {
				try drawLookMenu(a) catch (e:Dynamic) { ImGui.endMenu(); throw e; }
				ImGui.endMenu();
			}
			if (ImGui.beginMenu("Help")) {
				for (row in [["Move / box-select", "Drag"], ["Add to selection", "Ctrl+click"], ["Resize (keep ratio)", "Handles (Shift)"], ["Nudge", "Arrows (Shift x10)"],
						["Select all / none", "Ctrl+A / Esc"], ["Copy / Cut / Paste", "Ctrl+C / X / V"], ["Duplicate / Delete", "Ctrl+D / Del"], ["Group / Ungroup", "Ctrl+G / Ctrl+Shift+G"], ["Select one layer of a group", "Alt+click"], ["Undo / Redo", "Ctrl+Z / Ctrl+Y"],
						["Layer forward / backward", "] / [  (Ctrl = ends)"], ["Select / Pan / Pen / Nodes tool", "V / H / P / N"], ["Add a path point on a line", "Ctrl+click (Nodes)"], ["Zoom / Reset view", "+ - / 0"], ["Pan", "Space+drag, middle-drag"], ["Place freely", "Hold Alt"]])
					ImGui.menuItem(row[0], row[1], false, false);
				ImGui.endMenu();
			}
		} catch (e:Dynamic) { ImGui.endMenuBar(); throw e; }
		ImGui.endMenuBar();
	}

	function drawFileMenu(a:AuraDef):Void {
		if (ImGui.menuItem("Copy all layers to clipboard##cv_m_copyall")) copyAll(a);
		if (ImGui.menuItem("Paste layers from clipboard", "Ctrl+V")) pasteLayers(a);
		ImGui.separator();
		if (ImGui.menuItem("Clear all layers##cv_m_clear", null, false, a.canvasElements.length > 0)) clearAll(a);
		ImGui.separator();
		if (ImGui.menuItem("Close editor##cv_m_close")) open.set(false);
	}

	function drawEditMenu(a:AuraDef):Void {
		var any = canvasSel >= 0;
		if (ImGui.menuItem("Undo", "Ctrl+Z", false, host.canvasCanUndo())) host.canvasUndo();
		if (ImGui.menuItem("Redo", "Ctrl+Y", false, host.canvasCanRedo())) host.canvasRedo();
		ImGui.separator();
		if (ImGui.menuItem("Cut", "Ctrl+X", false, any)) copySelection(a, true);
		if (ImGui.menuItem("Copy", "Ctrl+C", false, any)) copySelection(a, false);
		if (ImGui.menuItem("Paste", "Ctrl+V")) pasteLayers(a);
		if (ImGui.menuItem("Duplicate", "Ctrl+D", false, any)) duplicateSelected(a);
		if (ImGui.menuItem("Delete", "Del", false, any)) removeSelected(a);
		ImGui.separator();
		if (ImGui.menuItem("Select all", "Ctrl+A", false, a.canvasElements.length > 0)) selectIndices([for (i in 0...a.canvasElements.length) i]);
		if (ImGui.menuItem("Select none", "Esc", false, any)) selectOnly(-1);
		if (ImGui.menuItem("Invert selection", null, false, a.canvasElements.length > 0)) {
			var inverse = [for (i in 0...a.canvasElements.length) if (!isSelected(i)) i];
			selectIndices(inverse);
		}
	}

	function drawInsertMenu(a:AuraDef):Void {
		if (ImGui.menuItem("Text##cv_m_text")) insertText(a);
		if (ImGui.menuItem("Game icon##cv_m_icon")) insertIcon(a);
		if (ImGui.menuItem("Image from library##cv_m_image")) insertImage(a);
		if (ImGui.beginMenu("Shape")) {
			try {
				for (sh in AuraCanvasElement.SHAPES) if (ImGui.menuItem(canvasShapeLabel(sh) + "##cv_m_sh_" + sh)) insertShape(a, sh);
			} catch (e:Dynamic) { ImGui.endMenu(); throw e; }
			ImGui.endMenu();
		}
		if (ImGui.menuItem("Pen tool: draw a path", "P")) tool = TOOL_PEN;
		if (ImGui.menuItem("Edit path points", "N")) tool = TOOL_NODES;
		if (ImGui.beginMenu("Vector")) {
			try drawVectorMenu(a) catch (e:Dynamic) { ImGui.endMenu(); throw e; }
			ImGui.endMenu();
		}
		if (ImGui.beginMenu("Preset")) {
			try {
				for (p in PRESETS) if (ImGui.menuItem(p.label + "##cv_m_pr_" + p.key)) addPreset(a, p.key);
			} catch (e:Dynamic) { ImGui.endMenu(); throw e; }
			ImGui.endMenu();
		}
	}

	function drawVectorMenu(a:AuraDef):Void {
		for (item in AuraVectorLibrary.ITEMS) if (ImGui.menuItem(item.label + "##cv_vec_" + item.key)) insertSvgText(a, item.d, item.label);
		ImGui.separator();
		if (ImGui.menuItem("Paste SVG path...##cv_vec_svg")) svgRequest = true;
	}

	// ---- Pen and node tools ------------------------------------------------------------------
	// Pen: click for a corner, drag for a curve, click the first point to close, Enter / double-click / Esc to finish.
	// Nodes: click a point to select, drag to move, drag a handle to bend, double-click a point to flip
	// corner/smooth, Ctrl+click or double-click a line to add a point, Delete to remove.

	static inline var TOOL_SELECT:Int = 0;
	static inline var TOOL_PAN:Int = 1;
	static inline var TOOL_PEN:Int = 2;
	static inline var TOOL_NODES:Int = 3;
	static inline var NODE_HIT_PX:Float = 7;

	var penEl:AuraCanvasElement = null;
	var penDragging:Bool = false;
	var penDragIdx:Int = -1;
	var nodeSel:Array<Int> = [];
	var nodeOwner:AuraCanvasElement = null;
	/** 0 none, 1 anchor(s), 2 incoming handle, 3 outgoing handle. */
	var nodeDrag:Int = 0;
	var nodeDragIdx:Int = -1;
	var nodeStart:Array<PathNode> = [];
	var nodeStartX:Float = 0;
	var nodeStartY:Float = 0;
	var nodeUndo:String = null;
	var nodeMoved:Bool = false;

	function resetPathTools():Void {
		penEl = null; penDragging = false; penDragIdx = -1;
		nodeSel = []; nodeOwner = null; nodeDrag = 0; nodeDragIdx = -1; nodeUndo = null; nodeMoved = false;
	}

	/** The selected, unlocked path layer, or null. */
	function pathLayer(a:AuraDef):AuraCanvasElement {
		if (canvasSel < 0 || canvasSel >= a.canvasElements.length) return null;
		var el = a.canvasElements[canvasSel];
		return el != null && el.kind == AuraCanvasElement.KIND_PATH && el.path != null && !el.locked ? el : null;
	}

	/** Aura-local point to the layer's unit space, undoing its rotation. */
	function unitPoint(a:AuraDef, el:AuraCanvasElement, mx:Float, my:Float):{u:Float, v:Float} {
		canvasBox(a, el);
		var c = rotatedPoint(mx, my, cvBoxX + cvBoxW * 0.5, cvBoxY + cvBoxH * 0.5, -el.rotationAt(editState));
		return {u: (c.x - cvBoxX) / cvBoxW, v: (c.y - cvBoxY) / cvBoxH};
	}

	/** Unit-space point back to aura-local coordinates. */
	function screenPoint(a:AuraDef, el:AuraCanvasElement, u:Float, v:Float):{x:Float, y:Float} {
		canvasBox(a, el);
		return rotatedPoint(cvBoxX + u * cvBoxW, cvBoxY + v * cvBoxH, cvBoxX + cvBoxW * 0.5, cvBoxY + cvBoxH * 0.5, el.rotationAt(editState));
	}

	static inline function dist(ax:Float, ay:Float, bx:Float, by:Float):Float return Math.sqrt((ax - bx) * (ax - bx) + (ay - by) * (ay - by));

	/** Shrink the layer's box to its outline so resizing and rotating work on the visible shape. */
	function fitElementToPath(el:AuraCanvasElement):Void {
		var box = el.path.fitUnit();
		var nx = el.x + box.x0 * el.w, ny = el.y + box.y0 * el.h;
		el.x = Math.round(nx); el.y = Math.round(ny);
		el.w = Math.max(4, Math.round(box.w * el.w)); el.h = Math.max(4, Math.round(box.h * el.h));
	}

	function finishPen(a:AuraDef):Void {
		if (penEl == null) return;
		var el = penEl;
		penEl = null; penDragging = false; penDragIdx = -1;
		var at = a.canvasElements.indexOf(el);
		if (at < 0) return;
		if (el.path.nodes.length < 2) { a.canvasElements.splice(at, 1); selectOnly(-1); return; }
		fitElementToPath(el);
		selectOnly(at);
		a.sizeDirty = true;
		SettingsStore.markDirty();
	}

	function penStep(a:AuraDef, mx:Float, my:Float, s:Float, active:Bool, activated:Bool, alt:Bool, hovered:Bool):Void {
		var snap = canvasSnap.get() && !alt;
		if (activated) {
			var px = canvasSnapValue(mx, snap), py = canvasSnapValue(my, snap);
			if (penEl == null) {
				if (a.canvasElements.length >= MAX_LAYERS) return;
				host.canvasSnapshot("Canvas Pen Path");
				var el = AuraCanvasElement.vector(new AuraVectorPath(), 0, 0, auraBoxW(a), auraBoxH(a), 0xFFFFFFFF);
				el.stroke = 2; el.name = "Pen path";
				a.canvasElements.push(el);
				selectOnly(a.canvasElements.length - 1);
				penEl = el;
			}
			var path = penEl.path, count = path.nodes.length;
			if (count >= 3) {
				var f = screenPoint(a, penEl, path.nodes[0].x, path.nodes[0].y);
				if (dist(f.x, f.y, mx, my) * s <= 8) { path.setClosed(true); finishPen(a); return; }
			}
			if (count >= 1) {
				var l = screenPoint(a, penEl, path.nodes[count - 1].x, path.nodes[count - 1].y);
				if (dist(l.x, l.y, px, py) * s < 3) { finishPen(a); return; }
			}
			var uv = unitPoint(a, penEl, px, py);
			var idx = path.addNode(uv.u, uv.v);
			if (idx < 0) { solarflare.ui.ToastManager.warn("A path can have " + AuraVectorPath.MAX_NODES + " points."); finishPen(a); return; }
			penDragging = true; penDragIdx = idx;
		}
		if (penEl != null && penDragging && active && penDragIdx >= 0 && penDragIdx < penEl.path.nodes.length && ImGui.isMouseDragging(0, 4)) {
			// Dragging out of a fresh point pulls a smooth curve: the far handle follows the cursor, the near one mirrors it.
			var n = penEl.path.nodes[penDragIdx], uv = unitPoint(a, penEl, mx, my);
			n.ox = uv.u; n.oy = uv.v; n.ix = 2 * n.x - uv.u; n.iy = 2 * n.y - uv.v;
			penEl.path.invalidate();
		}
		if (!active) penDragging = false;
		if (penEl != null && (ImGui.isKeyPressed(ImGuiKey.Enter, false) || ImGui.isKeyPressed(ImGuiKey.KeypadEnter, false) || ImGui.isKeyPressed(ImGuiKey.Escape, false))) finishPen(a);
		else if (penEl != null && ImGui.isKeyPressed(ImGuiKey.Backspace, false) && penEl.path.nodes.length > 1) {
			penEl.path.nodes.pop();
			penEl.path.invalidate();
		}
		if (hovered) ImGui.setMouseCursor(imgui.Enums.ImGuiMouseCursor.Hand);
	}

	/** Returns true when the tool used the pointer, so the normal layer selection stays out of the way. */
	function nodesStep(a:AuraDef, mx:Float, my:Float, s:Float, active:Bool, activated:Bool, shift:Bool, ctrl:Bool, alt:Bool):Bool {
		var el = pathLayer(a);
		if (el == null) { nodeDrag = 0; return false; }
		if (nodeOwner != el) { nodeOwner = el; nodeSel = []; }
		var path = el.path, snap = canvasSnap.get() && !alt;
		if (activated && nodeDrag == 0) {
			var reach = NODE_HIT_PX / s;
			// Handles of the selected nodes first, then anchors from the top down.
			for (i in nodeSel) {
				if (i >= path.nodes.length) continue;
				var n = path.nodes[i];
				var pin = screenPoint(a, el, n.ix, n.iy), pout = screenPoint(a, el, n.ox, n.oy);
				if (!(n.ix == n.x && n.iy == n.y) && dist(pin.x, pin.y, mx, my) <= reach) { beginNodeDrag(path, 2, i, mx, my); return true; }
				if (!(n.ox == n.x && n.oy == n.y) && dist(pout.x, pout.y, mx, my) <= reach) { beginNodeDrag(path, 3, i, mx, my); return true; }
			}
			var i = path.nodes.length - 1;
			while (i >= 0) {
				var p = screenPoint(a, el, path.nodes[i].x, path.nodes[i].y);
				if (dist(p.x, p.y, mx, my) <= reach) {
					if (ImGui.isMouseDoubleClicked(0)) {
						host.canvasSnapshot("Canvas Node Type");
						if (path.isCornerAt(i)) path.setSmooth(i); else path.setCorner(i);
						nodeSel = [i];
						SettingsStore.markDirty();
						return true;
					}
					if (shift || ctrl) { if (nodeSel.indexOf(i) >= 0) nodeSel.remove(i); else nodeSel.push(i); }
					else if (nodeSel.indexOf(i) < 0) nodeSel = [i];
					if (nodeSel.indexOf(i) >= 0) beginNodeDrag(path, 1, i, mx, my);
					return true;
				}
				i--;
			}
			if (ctrl || ImGui.isMouseDoubleClicked(0)) {
				canvasBox(a, el);
				var uv = unitPoint(a, el, mx, my);
				var hit = path.nearestSegment(uv.u, uv.v, cvBoxW * s, cvBoxH * s, 8);
				if (hit != null) {
					host.canvasSnapshot("Canvas Add Node");
					var at = path.splitSegment(hit.seg, hit.t);
					if (at >= 0) { nodeSel = [at]; SettingsStore.markDirty(); }
					return true;
				}
			}
			// Another layer under the pointer is selected as usual; empty space just clears the node selection.
			var over = canvasHitTest(a, mx, my);
			if (over >= 0 && over != canvasSel) return false;
			nodeSel = [];
			return true;
		}
		if (nodeDrag != 0 && active && ImGui.isMouseDragging(0, 0)) {
			if (nodeDrag == 1) {
				var d = ImGui.getMouseDragDelta(0, 0);
				var dx = canvasSnapValue(d.x / s, snap), dy = canvasSnapValue(d.y / s, snap);
				canvasBox(a, el);
				var r = rotatedPoint(dx, dy, 0, 0, -el.rotationAt(editState));
				for (k in 0...nodeSel.length) {
					var at = nodeSel[k];
					if (at >= path.nodes.length || k >= nodeStart.length) continue;
					var o = nodeStart[k];
					path.nodes[at] = {x: o.x, y: o.y, ix: o.ix, iy: o.iy, ox: o.ox, oy: o.oy};
					path.moveNode(at, r.x / cvBoxW, r.y / cvBoxH);
				}
			} else if (nodeDragIdx >= 0 && nodeDragIdx < path.nodes.length) {
				var uv = unitPoint(a, el, canvasSnapValue(mx, snap), canvasSnapValue(my, snap));
				path.moveHandle(nodeDragIdx, nodeDrag == 3, uv.u, uv.v, !alt);
			}
			nodeMoved = true;
		}
		if (nodeDrag != 0 && !active) {
			if (nodeMoved && nodeUndo != null) { host.canvasUndoPush("Canvas Edit Path", nodeUndo); SettingsStore.markDirty(); }
			nodeDrag = 0; nodeUndo = null; nodeMoved = false;
		}
		return nodeDrag != 0;
	}

	function beginNodeDrag(path:AuraVectorPath, mode:Int, idx:Int, mx:Float, my:Float):Void {
		nodeDrag = mode; nodeDragIdx = idx; nodeStartX = mx; nodeStartY = my; nodeMoved = false;
		nodeUndo = canvasUndoBase();
		nodeStart = [for (i in nodeSel) if (i < path.nodes.length) {var n = path.nodes[i]; {x: n.x, y: n.y, ix: n.ix, iy: n.iy, ox: n.ox, oy: n.oy};}];
	}

	/** Delete and arrow keys act on the selected nodes. Returns true when a key was used. */
	function nodesKeys(a:AuraDef, shift:Bool):Bool {
		var el = pathLayer(a);
		if (el == null || nodeSel.length == 0) return false;
		var path = el.path;
		if (ImGui.isKeyPressed(ImGuiKey.Delete, false)) {
			host.canvasSnapshot("Canvas Delete Node");
			var order = nodeSel.copy();
			order.sort(function(p, q) return q - p);
			for (i in order) path.removeNode(i);
			nodeSel = [];
			SettingsStore.markDirty();
			return true;
		}
		var step:Float = shift ? 10 : 1, nx = 0.0, ny = 0.0;
		if (ImGui.isKeyPressed(ImGuiKey.LeftArrow)) nx -= step;
		if (ImGui.isKeyPressed(ImGuiKey.RightArrow)) nx += step;
		if (ImGui.isKeyPressed(ImGuiKey.UpArrow)) ny -= step;
		if (ImGui.isKeyPressed(ImGuiKey.DownArrow)) ny += step;
		if (nx == 0 && ny == 0) return false;
		var now = haxe.Timer.stamp();
		if (now - canvasNudgeStamp > 0.75) host.canvasSnapshot("Canvas Nudge Nodes");
		canvasNudgeStamp = now;
		canvasBox(a, el);
		for (i in nodeSel) if (i < path.nodes.length) path.moveNode(i, nx / cvBoxW, ny / cvBoxH);
		SettingsStore.markDirty();
		return true;
	}

	/** Inspector buttons: change every selected node. */
	function nodeAction(a:AuraDef, el:AuraCanvasElement, action:String):Void {
		var path = el.path;
		if (path == null) return;
		host.canvasSnapshot("Canvas Path " + action);
		switch (action) {
			case "Corner": for (i in nodeSel) if (i < path.nodes.length) path.setCorner(i);
			case "Smooth": for (i in nodeSel) if (i < path.nodes.length) path.setSmooth(i);
			case "Delete":
				var order = nodeSel.copy();
				order.sort(function(p, q) return q - p);
				for (i in order) path.removeNode(i);
				nodeSel = [];
			case "Reverse": path.reverse(); nodeSel = [];
			case "Close": path.setClosed(!path.closed);
			case "Fit": fitElementToPath(el);
			default:
		}
		SettingsStore.markDirty();
	}

	function drawNodeRows(a:AuraDef, el:AuraCanvasElement):Void {
		var path = el.path;
		if (path == null) return;
		UiChrome.subHeader("Points");
		if (tool != TOOL_NODES && ImGui.button("Edit points (N)##cv_path_edit", ImGui.vec2(-1, 0))) tool = TOOL_NODES;
		var some = nodeOwner == el && nodeSel.length > 0;
		ImGui.textDisabled(some ? nodeSel.length + " selected" : (tool == TOOL_NODES ? "Click a point to select it" : "Choose the Nodes tool to select points"));
		ImGui.beginDisabled(!some);
		UiLayout.inlineSplit("##cv_path_nodebtns", 3, function(index:Int, cellW:Single) {
			var size = ImGui.vec2(cellW, 0);
			if (index == 0 && ImGui.button("Corner##cv_pn_corner", size)) nodeAction(a, el, "Corner");
			else if (index == 1 && ImGui.button("Smooth##cv_pn_smooth", size)) nodeAction(a, el, "Smooth");
			else if (index == 2 && ImGui.button("Delete##cv_pn_delete", size)) nodeAction(a, el, "Delete");
		});
		ImGui.endDisabled();
		UiLayout.inlineSplit("##cv_path_shapebtns", 3, function(index:Int, cellW:Single) {
			var size = ImGui.vec2(cellW, 0);
			if (index == 0 && ImGui.button((path.closed ? "Open" : "Close") + "##cv_pn_close", size)) nodeAction(a, el, "Close");
			else if (index == 1 && ImGui.button("Reverse##cv_pn_reverse", size)) nodeAction(a, el, "Reverse");
			else if (index == 2 && ImGui.button("Fit box##cv_pn_fit", size)) nodeAction(a, el, "Fit");
		});
		wrappedHint("Double-click a point to switch corner/smooth. Ctrl+click or double-click a line adds a point. Alt while dragging a handle bends one side only.");
	}

	/** Points, handles and the pen's rubber band, drawn over the stage. */
	function drawPathOverlay(dl:Dynamic, a:AuraDef, el:AuraCanvasElement, ox:Float, oy:Float, s:Float, accent:Int, pen:Bool, hovered:Bool, mx:Float, my:Float):Void {
		var path = el.path;
		if (path == null) return;
		var n = path.nodes.length, white = 0xFFFFFFFF, dark = 0xFF14141C;
		for (i in 0...n) {
			var node = path.nodes[i];
			var p = screenPoint(a, el, node.x, node.y);
			var px:Single = ox + p.x * s, py:Single = oy + p.y * s;
			var selected = pen ? i == n - 1 : nodeSel.indexOf(i) >= 0;
			if (selected) {
				for (side in 0...2) {
					var hx = side == 0 ? node.ix : node.ox, hy = side == 0 ? node.iy : node.oy;
					if (hx == node.x && hy == node.y) continue;
					var h = screenPoint(a, el, hx, hy);
					var qx:Single = ox + h.x * s, qy:Single = oy + h.y * s;
					ImGui.ImDrawList_AddLine(dl, ImGui.vec2(px, py), ImGui.vec2(qx, qy), accent, 1);
					ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(qx, qy), 4, white, 12);
					ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(qx, qy), 4, accent, 12, 1.5);
				}
			}
			var half:Single = 4.5;
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(px - half, py - half), ImGui.vec2(px + half, py + half), selected ? accent : white, 1);
			ImGui.ImDrawList_AddRect(dl, ImGui.vec2(px - half, py - half), ImGui.vec2(px + half, py + half), dark, 1, 1);
			if (pen && i == 0 && n >= 3 && hovered && dist(p.x, p.y, mx, my) * s <= 8)
				ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(px, py), 9, accent, 16, 2);
		}
		if (pen && hovered && n >= 1) {
			var last = path.nodes[n - 1], lp = screenPoint(a, el, last.x, last.y);
			var from = ImGui.vec2(ox + lp.x * s, oy + lp.y * s), to = ImGui.vec2(ox + mx * s, oy + my * s);
			var faint = (accent & 0x00FFFFFF) | 0x99000000;
			if (last.ox != last.x || last.oy != last.y) {
				var c = screenPoint(a, el, last.ox, last.oy);
				ImGui.ImDrawList_AddBezierCubic(dl, from, ImGui.vec2(ox + c.x * s, oy + c.y * s), to, to, faint, 1.5);
			} else ImGui.ImDrawList_AddLine(dl, from, to, faint, 1.5);
		}
	}

	// ---- Vector paths ------------------------------------------------------------------------

	var svgRequest:Bool = false;
	var svgBuf = new hl.Bytes(SVG_BUF);
	static inline var SVG_BUF:Int = AuraVectorPath.MAX_SVG_CHARS + 1024;
	var svgText:String = "";
	var svgParsed:SvgImport = null;
	var svgStroke = new FloatRef(0);

	function parseSvgBuffer():Void {
		svgText = ByteUtil.readBytes(svgBuf, SVG_BUF);
		svgParsed = StringTools.trim(svgText).length == 0 ? null : AuraVectorPath.fromSvg(AuraVectorLibrary.extractPathData(svgText));
	}

	/** Insert parsed outlines as layers sharing one box, centred and sized to the aura. */
	function insertSvgText(a:AuraDef, data:String, label:String):Void {
		var imp = AuraVectorPath.fromSvg(data);
		if (imp.error.length > 0) { solarflare.ui.ToastManager.error(imp.error); return; }
		if (imp.note != null && imp.note.length > 0) solarflare.ui.ToastManager.warn(imp.note);
		insertImported(a, imp, label, 0);
	}

	function insertImported(a:AuraDef, imp:SvgImport, label:String, outline:Float):Void {
		if (imp.paths.length == 0) return;
		host.canvasSnapshot("Canvas Add Path");
		var size = Math.max(24, Math.min(auraBoxW(a), auraBoxH(a)) * 0.7);
		var w = imp.aspect >= 1 ? size : size * imp.aspect, h = imp.aspect >= 1 ? size / imp.aspect : size;
		var first = a.canvasElements.length;
		for (path in imp.paths) {
			if (a.canvasElements.length >= MAX_LAYERS) break;
			var el = AuraCanvasElement.vector(path, Math.round((auraBoxW(a) - w) * 0.5), Math.round((auraBoxH(a) - h) * 0.5), Math.round(w), Math.round(h));
			el.name = label;
			if (path.closed) el.stroke = outline;
			else { el.fill = false; el.stroke = Math.max(2, outline); }
			a.canvasElements.push(el);
		}
		selectIndices([for (i in first...a.canvasElements.length) i]);
		SettingsStore.markDirty();
	}

	function drawSvgModal(a:AuraDef):Void {
		if (svgRequest) {
			ImGui.openPopup("Insert SVG path##cv_svg");
			svgRequest = false;
			ByteUtil.clearBytes(svgBuf, SVG_BUF);
			parseSvgBuffer();
		}
		ImGui.setNextWindowSize(ImGui.vec2(560, 380), imgui.Enums.ImGuiCond.FirstUseEver);
		if (!ImGui.beginPopupModal("Insert SVG path##cv_svg", null, 0)) return;
		try {
			wrappedHint("Paste the d=\"...\" value of an SVG path, or the whole <path> markup. Export icons from Inkscape, Figma or an icon site as SVG, open the file in a text editor and copy its path. Supports M L H V C S Q T A Z; up to 512 points per shape (busier drawings are simplified automatically).");
			if (ImGui.inputTextMultiline("##cv_svg_text", svgBuf, SVG_BUF, ImGui.vec2(-1, 170))) parseSvgBuffer();
			if (UiChrome.ghostButton("Paste from clipboard##cv_svg_clip", ImGui.vec2(180, 26))) {
				UiActionQueue.custom(function() {
					var bytes = ImGui.getClipboardText();
					if (bytes != null) ByteUtil.fillBuf(svgBuf, SVG_BUF, ByteUtil.readString(bytes, SVG_BUF - 1, true));
					parseSvgBuffer();
				});
			}
			ImGui.sameLine(0, 8);
			ImGui.setNextItemWidth(160);
			NumberField.draw("##cv_svg_outline", svgStroke, 0, 16, "Outline %.0f px", null);
			if (svgParsed == null) wrappedHint("Nothing pasted yet.");
			else if (svgParsed.error.length > 0) ImGui.textColored(solarflare.ui.ThemePalette.status(solarflare.ui.ThemePalette.STATUS_DANGER), svgParsed.error);
			else {
				var points = 0;
				for (path in svgParsed.paths) points += path.nodes.length;
				ImGui.textColored(solarflare.ui.ThemePalette.status(solarflare.ui.ThemePalette.STATUS_SUCCESS),
					svgParsed.paths.length + " shape" + (svgParsed.paths.length == 1 ? "" : "s") + ", " + points + " points. Closed shapes are filled; open paths become outlines." + (svgParsed.note != null && svgParsed.note.length > 0 ? " " + svgParsed.note : ""));
			}
			ImGui.separator();
			var ok = svgParsed != null && svgParsed.error.length == 0 && svgParsed.paths.length > 0;
			ImGui.beginDisabled(!ok);
			if (UiChrome.ghostButton("Insert##cv_svg_ok", ImGui.vec2(120, 28)) && ok) { insertImported(a, svgParsed, "SVG path", svgStroke.get()); ImGui.closeCurrentPopup(); }
			ImGui.endDisabled();
			ImGui.sameLine(0, 8);
			if (UiChrome.ghostButton("Cancel##cv_svg_cancel", ImGui.vec2(120, 28))) ImGui.closeCurrentPopup();
		} catch (e:Dynamic) { ImGui.endPopup(); throw e; }
		ImGui.endPopup();
	}

	function drawArrangeMenu(a:AuraDef):Void {
		var any = canvasSel >= 0, n = a.canvasElements.length;
		if (ImGui.beginMenu("Order", any)) {
			try {
				if (ImGui.menuItem("Bring to front", null, false, canvasSel < n - 1)) moveCanvasElement(a, canvasSel, n - 1, "Canvas To Front");
				if (ImGui.menuItem("Bring forward", null, false, canvasSel < n - 1)) moveCanvasElement(a, canvasSel, canvasSel + 1, "Canvas Bring Forward");
				if (ImGui.menuItem("Send backward", null, false, canvasSel > 0)) moveCanvasElement(a, canvasSel, canvasSel - 1, "Canvas Send Backward");
				if (ImGui.menuItem("Send to back", null, false, canvasSel > 0)) moveCanvasElement(a, canvasSel, 0, "Canvas To Back");
			} catch (e:Dynamic) { ImGui.endMenu(); throw e; }
			ImGui.endMenu();
		}
		if (ImGui.beginMenu("Align", any)) {
			try drawAlignMenu(a, a.canvasElements[canvasSel]) catch (e:Dynamic) { ImGui.endMenu(); throw e; }
			ImGui.endMenu();
		}
		if (ImGui.menuItem("Group selection", "Ctrl+G", false, canvasMulti.length > 0)) groupSelected(a);
		if (ImGui.menuItem("Ungroup", "Ctrl+Shift+G", false, selectionHasGroup(a))) ungroupSelected(a);
		if (ImGui.menuItem("Center on aura", null, false, any)) centerOnAura(a);
		ImGui.separator();
		if (ImGui.menuItem("Lock selection", null, false, any)) setSelectionFlag(a, "lock", true);
		if (ImGui.menuItem("Unlock selection", null, false, any)) setSelectionFlag(a, "lock", false);
		if (ImGui.menuItem("Hide selection", null, false, any)) setSelectionFlag(a, "hide", true);
		if (ImGui.menuItem("Show selection", null, false, any)) setSelectionFlag(a, "hide", false);
		ImGui.separator();
		if (ImGui.menuItem("Unlock all layers", null, false, n > 0)) setAllFlag(a, "lock", false);
		if (ImGui.menuItem("Show all layers", null, false, n > 0)) setAllFlag(a, "hide", false);
	}

	function drawViewMenu(a:AuraDef):Void {
		if (ImGui.menuItem("Zoom in", "+")) zoom = Math.min(16, zoom * 1.25);
		if (ImGui.menuItem("Zoom out", "-")) zoom = Math.max(0.25, zoom * 0.8);
		if (ImGui.menuItem("Fit to window", "0")) resetView();
		if (ImGui.menuItem("Actual size (100%)")) { zoom = 1; panX = 0; panY = 0; }
		ImGui.separator();
		if (ImGui.menuItem("Show grid", null, showGrid.get())) showGrid.set(!showGrid.get());
		if (ImGui.menuItem("Snap to grid", null, canvasSnap.get())) canvasSnap.set(!canvasSnap.get());
		if (ImGui.menuItem("Smart guides", null, showGuides.get())) showGuides.set(!showGuides.get());
		if (ImGui.menuItem("Layer outlines", null, showBounds.get())) showBounds.set(!showBounds.get());
		if (ImGui.menuItem("Animate pulses here", null, AuraVisualRenderer.animateInEditor)) AuraVisualRenderer.animateInEditor = !AuraVisualRenderer.animateInEditor;
		if (ImGui.beginMenu("Snap step")) {
			try { for (v in SNAP_STEPS) if (ImGui.menuItem(Std.int(v) + " px##cv_vm_ss_" + Std.int(v), null, snapStep == v)) snapStep = v; }
			catch (e:Dynamic) { ImGui.endMenu(); throw e; }
			ImGui.endMenu();
		}
		if (ImGui.beginMenu("Background")) {
			try { for (i in 0...STAGE_BACKGROUNDS.length) if (ImGui.menuItem(STAGE_BACKGROUNDS[i] + "##cv_vm_bg_" + i, null, stageBg == i)) stageBg = i; }
			catch (e:Dynamic) { ImGui.endMenu(); throw e; }
			ImGui.endMenu();
		}
		var live = host.canvasPreview().liveCanvasConditions;
		if (ImGui.menuItem("Live conditions preview", null, live)) host.canvasPreview().liveCanvasConditions = !live;
	}

	function drawLookMenu(a:AuraDef):Void {
		if (ImGui.menuItem("Default##cv_lm_default", null, editState == "")) editState = "";
		for (st in a.states) if (ImGui.menuItem(st.name + "##cv_lm_" + st.id, null, editState == st.id)) editState = st.id;
		ImGui.separator();
		if (ImGui.menuItem("New look", null, false, a.states.length < AuraStateDef.MAX_STATES)) addState(a);
		if (ImGui.menuItem("Duplicate this look", null, false, editState != "" && a.states.length < AuraStateDef.MAX_STATES)) duplicateState(a);
	}

	// ---- Toolbar -----------------------------------------------------------------------------

	/** Description of the toolbar command under the pointer, shown in the status bar. */
	var hintText:String = "";

	function tbBegin():Void {
		hintText = "";
		tbAvail = ImGui.getContentRegionAvail().x;
		tbUsed = 0;
		tbFirst = true;
		tbIndex = 0;
	}

	function tbPlace(width:Float):Void {
		if (!tbFirst) {
			if (tbUsed + 4 + width > tbAvail) tbUsed = 0; else { ImGui.sameLine(0, 4); tbUsed += 4; }
		}
		tbFirst = false;
		tbUsed += width;
	}

	/** A real vertical divider between groups of commands (replaces the old "|" text). */
	function tbSeparator():Void {
		tbPlace(TB_DIVIDER_W);
		var p = ImGui.getCursorScreenPos(), h = TB_BUTTON_H;
		var line = ImGui.colorConvertFloat4ToU32(solarflare.ui.ThemePalette.current().border);
		ImGui.ImDrawList_AddLine(ImGui.getWindowDrawList(), ImGui.vec2(p.x + TB_DIVIDER_W * 0.5, p.y + 3), ImGui.vec2(p.x + TB_DIVIDER_W * 0.5, p.y + h - 3), line, 1.5);
		ImGui.dummy(ImGui.vec2(TB_DIVIDER_W, h));
	}

	/** Small caption that names the group of commands that follows. */
	function tbLabel(text:String):Void {
		tbPlace(ImGui.calcTextSize(text).x);
		ImGui.alignTextToFramePadding();
		ImGui.textDisabled(text);
	}

	static inline var TB_BUTTON_H:Float = 26;
	static inline var TB_DIVIDER_W:Float = 13;
	static inline var TB_MIN_W:Float = 40;

	function tbButton(label:String, tip:String, active:Bool = false, enabled:Bool = true):Bool {
		var bw = Math.max(TB_MIN_W, ImGui.calcTextSize(label).x + 18);
		tbPlace(bw);
		if (active) ImGui.pushStyleColor(ImGuiCol.Button, solarflare.ui.ThemePalette.current().accent);
		if (!enabled) ImGui.beginDisabled(true);
		var clicked = ImGui.button(label + "##cvtb" + (tbIndex++), ImGui.vec2(bw, TB_BUTTON_H));
		if (!enabled) ImGui.endDisabled();
		if (active) ImGui.popStyleColor();
		if (tip != null && ImGui.isItemHovered()) {
			hintText = label + ": " + tip;
			if (ImGui.isItemHovered(imgui.Enums.ImGuiHoveredFlags.DelayNormal)) ImGui.setTooltip(tip);
		}
		return clicked;
	}

	function drawToolbar(a:AuraDef):Void {
		tbBegin();
		var any = canvasSel >= 0, several = canvasMulti.length > 0, n = a.canvasElements.length;
		tbLabel("Tools");
		if (tbButton("Select", "Select and move layers (V)", tool == 0)) tool = 0;
		if (tbButton("Pan", "Drag to pan the view (H). Space+drag works in any tool.", tool == TOOL_PAN)) tool = TOOL_PAN;
		if (tbButton("Pen", "Draw a vector path: click for corners, drag for curves, click the first point to close, Enter to finish (P)", tool == TOOL_PEN)) tool = TOOL_PEN;
		if (tbButton("Nodes", "Edit the points and curves of the selected path (N)", tool == TOOL_NODES)) tool = TOOL_NODES;
		tbSeparator();
		tbLabel("Add");
		if (tbButton("+ Text", "Add a text layer")) insertText(a);
		if (tbButton("+ Icon", "Add a game icon layer")) insertIcon(a);
		if (tbButton("+ Image", "Add the first image from your library; drag others from the Library tab")) insertImage(a);
		if (tbButton("+ Shape", "Add a shape")) ImGui.openPopup("##cv_tb_shapes");
		if (ImGui.beginPopup("##cv_tb_shapes")) {
			try { for (sh in AuraCanvasElement.SHAPES) if (ImGui.selectable(canvasShapeLabel(sh) + "##cv_tbs_" + sh)) insertShape(a, sh); }
			catch (e:Dynamic) { ImGui.endPopup(); throw e; }
			ImGui.endPopup();
		}
		if (tbButton("+ Vector", "Hand-editable outlines: hearts, bolts, arrows, or paste SVG path data")) ImGui.openPopup("##cv_tb_vectors");
		if (ImGui.beginPopup("##cv_tb_vectors")) {
			try drawVectorMenu(a) catch (e:Dynamic) { ImGui.endPopup(); throw e; }
			ImGui.endPopup();
		}
		if (tbButton("+ Preset", "Ready-made starting points: label plate, icon frame, count badge, timer text...")) ImGui.openPopup("##cv_tb_presets");
		if (ImGui.beginPopup("##cv_tb_presets")) {
			try { for (p in PRESETS) if (ImGui.selectable(p.label + "##cv_tbp_" + p.key)) addPreset(a, p.key); }
			catch (e:Dynamic) { ImGui.endPopup(); throw e; }
			ImGui.endPopup();
		}
		tbSeparator();
		tbLabel("Edit");
		if (tbButton("Undo", "Ctrl+Z", false, host.canvasCanUndo())) host.canvasUndo();
		if (tbButton("Redo", "Ctrl+Y", false, host.canvasCanRedo())) host.canvasRedo();
		if (tbButton("Copy", "Ctrl+C", false, any)) copySelection(a, false);
		if (tbButton("Paste", "Ctrl+V")) pasteLayers(a);
		if (tbButton("Duplicate", "Ctrl+D", false, any)) duplicateSelected(a);
		if (tbButton("Delete", "Del", false, any)) removeSelected(a);
		tbSeparator();
		tbLabel("Layers");
		if (tbButton("Group", "Group the selected layers so they select, move and hide together (Ctrl+G)", false, canvasMulti.length > 0)) groupSelected(a);
		if (tbButton("Ungroup", "Release the selected layers' groups (Ctrl+Shift+G)", false, selectionHasGroup(a))) ungroupSelected(a);
		tbSeparator();
		tbLabel("Align");
		for (row in ALIGN_ROWS) {
			var short = row.label;
			if (tbButton(short, "Align " + row.label.toLowerCase() + (several ? " (to the selection)" : " (to the aura)"), false, any)) alignAny(a, row.mode);
		}
		if (tbButton("Space H", "Spread three or more layers evenly across", false, canvasMulti.length >= 2)) alignSelection(a, "distH");
		if (tbButton("Space V", "Spread three or more layers evenly down", false, canvasMulti.length >= 2)) alignSelection(a, "distV");
		tbSeparator();
		tbLabel("Stacking");
		if (tbButton("Front", "Bring to front", false, any && canvasSel < n - 1 && !several)) moveCanvasElement(a, canvasSel, n - 1, "Canvas To Front");
		if (tbButton("Up", "Bring forward", false, any && canvasSel < n - 1 && !several)) moveCanvasElement(a, canvasSel, canvasSel + 1, "Canvas Bring Forward");
		if (tbButton("Down", "Send backward", false, any && canvasSel > 0 && !several)) moveCanvasElement(a, canvasSel, canvasSel - 1, "Canvas Send Backward");
		if (tbButton("Back", "Send to back", false, any && canvasSel > 0 && !several)) moveCanvasElement(a, canvasSel, 0, "Canvas To Back");
		tbSeparator();
		tbLabel("View");
		if (tbButton("Snap", "Snap drags to the grid (hold Alt to place freely)", canvasSnap.get())) canvasSnap.set(!canvasSnap.get());
		if (tbButton("Grid", "Show the grid", showGrid.get())) showGrid.set(!showGrid.get());
		if (tbButton("Guides", "Smart guides: snap to the aura's edges and centre and to other layers", showGuides.get())) showGuides.set(!showGuides.get());
		if (tbButton("Outlines", "Outline every layer", showBounds.get())) showBounds.set(!showBounds.get());
		tbSeparator();
		if (tbButton("-", "Zoom out")) zoom = Math.max(0.25, zoom * 0.8);
		if (tbButton(Std.string(Math.round(zoom * 100)) + "%", "Click to fit the aura in the window")) resetView();
		if (tbButton("+", "Zoom in")) zoom = Math.min(16, zoom * 1.25);
	}

	// ---- Insert helpers ----------------------------------------------------------------------

	function auraBoxW(a:AuraDef):Float return a.w.get() > 1 ? a.w.get() : 96;
	function auraBoxH(a:AuraDef):Float return a.h.get() > 1 ? a.h.get() : 96;

	function insertText(a:AuraDef):Void addCanvasElement(a, AuraCanvasElement.text("{name}", 8, 8, 16), "Canvas Add Text", false);

	function insertIcon(a:AuraDef):Void {
		var id = a.preferredIconId();
		addCanvasElement(a, AuraCanvasElement.icon(id.length > 0 ? id : "icon", 8, 8, 48, 48), "Canvas Add Icon", false);
	}

	function insertImage(a:AuraDef):Void {
		var names = CustomImages.names();
		addCanvasElement(a, AuraCanvasElement.icon(CustomImages.key(names.length > 0 ? names[0] : ""), 8, 8, 48, 48), "Canvas Add Image", false);
	}

	/** Shapes start as a backplate behind everything else. */
	function insertShape(a:AuraDef, shape:String):Void {
		var el = AuraCanvasElement.shape(shape, 0, 0, auraBoxW(a), shape == "line" ? 3 : auraBoxH(a));
		if (shape == "line") el.y = Math.round(auraBoxH(a) * 0.5);
		addCanvasElement(a, el, "Canvas Add Shape", shape != "line");
	}

	static var PRESETS:Array<{key:String, label:String}> = [
		{key: "plate", label: "Label plate"}, {key: "frame", label: "Icon frame"}, {key: "badge", label: "Count badge"},
		{key: "timer", label: "Timer text"}, {key: "divider", label: "Divider line"}, {key: "glow", label: "Soft glow"}
	];

	/** Several layers in one undo step; the last one added ends up selected. */
	function addPreset(a:AuraDef, key:String):Void {
		var w = auraBoxW(a), h = auraBoxH(a);
		var made:Array<AuraCanvasElement> = [];
		var behind:Array<AuraCanvasElement> = [];
		switch (key) {
			case "plate":
				var plate = AuraCanvasElement.shape("rounded", 0, h - 28, w, 28, 0xC0101418);
				var label = AuraCanvasElement.text("{name}", 0, h - 23, 14, 0xFFFFFFFF); label.w = w; label.textAlign = 1;
				made = [plate, label];
			case "frame":
				var id = a.preferredIconId();
				var ring = AuraCanvasElement.shape("ring", 0, 0, w, h, 0xFFFFB020); ring.stroke = 4;
				made = [AuraCanvasElement.icon(id, 4, 4, w - 8, h - 8), ring];
			case "badge":
				var disc = AuraCanvasElement.shape("circle", w - 30, h - 30, 28, 28, 0xE0101418);
				var count = AuraCanvasElement.text("{stacks}", w - 30, h - 24, 14, 0xFFFFFFFF); count.w = 28; count.textAlign = 1;
				made = [disc, count];
			case "timer":
				var t = AuraCanvasElement.text("{time}", 0, h - 26, 20, 0xFFFFFFFF); t.w = w; t.textAlign = 1; t.outline = 1.5;
				made = [t];
			case "divider":
				made = [AuraCanvasElement.shape("line", 8, h * 0.5, w - 16, 2, 0xA0FFFFFF)];
			case "glow":
				var g = AuraCanvasElement.shape("circle", 0, 0, w, h, 0xB0FFB020); g.color2 = 0x00FFB020;
				behind = [g];
			default:
		}
		if (made.length == 0 && behind.length == 0) return;
		host.canvasSnapshot("Canvas Preset");
		for (el in behind) a.canvasElements.insert(0, el);
		for (el in made) a.canvasElements.push(el);
		if (a.canvasElements.length > MAX_LAYERS) a.canvasElements.splice(MAX_LAYERS, a.canvasElements.length - MAX_LAYERS);
		var last = behind.length > 0 ? 0 : a.canvasElements.length - 1;
		selectOnly(last);
		SettingsStore.markDirty();
	}

	// ---- Clipboard and bulk edits ------------------------------------------------------------

	function copyAll(a:AuraDef):Void {
		clip = [for (el in a.canvasElements) if (el != null) el.toObj()];
		pasteCount = 0;
		UiActionQueue.copyText(CLIP_PREFIX + haxe.Json.stringify(clip), "Copied " + clip.length + " layer(s)");
	}

	function copySelection(a:AuraDef, cut:Bool):Void {
		var picks = selectedIndices();
		if (picks.length == 0) return;
		clip = [for (i in picks) if (a.canvasElements[i] != null) a.canvasElements[i].toObj()];
		pasteCount = 0;
		UiActionQueue.copyText(CLIP_PREFIX + haxe.Json.stringify(clip), (cut ? "Cut " : "Copied ") + clip.length + " layer(s)");
		if (cut) removeSelected(a);
	}

	/** Layers from the system clipboard when it holds some (works between auras), else the last copy. */
	function pasteLayers(a:AuraDef):Void {
		UiActionQueue.custom(function() {
			if (host.canvasAuras().indexOf(a) < 0 || a.canvasElements == null) return;
			var source:Array<Dynamic> = clip;
			try {
				var bytes = ImGui.getClipboardText();
				var text = bytes != null ? ByteUtil.readString(bytes, 1 << 20, true) : "";
				if (text != null && StringTools.startsWith(text, CLIP_PREFIX)) {
					var parsed:Dynamic = haxe.Json.parse(text.substr(CLIP_PREFIX.length));
					if (Std.isOfType(parsed, Array)) { source = cast parsed; pasteCount = 0; }
				}
			} catch (_:Dynamic) {}
			if (source == null || source.length == 0) { solarflare.ui.ToastManager.info("Nothing to paste. Copy layers first."); return; }
			host.canvasSnapshot("Canvas Paste");
			pasteCount++;
			var first = a.canvasElements.length;
			for (raw in source) {
				if (raw == null || a.canvasElements.length >= MAX_LAYERS) continue;
				var el = AuraCanvasElement.fromDyn(raw);
				el.x += 8 * pasteCount; el.y += 8 * pasteCount; el.locked = false;
				a.canvasElements.push(el);
			}
			AuraCanvasGroups.separateCopies(a.canvasElements, first);
			selectIndices([for (i in first...a.canvasElements.length) i]);
			a.sizeDirty = true;
			SettingsStore.markDirty();
		});
	}

	function clearAll(a:AuraDef):Void {
		host.canvasSnapshot("Clear Canvas");
		a.canvasElements.splice(0, a.canvasElements.length);
		canvasRuleContexts = new haxe.ds.ObjectMap();
		canvasRowIds = new haxe.ds.ObjectMap<AuraCanvasElement, Int>();
		selectOnly(-1);
		a.sizeDirty = true;
		SettingsStore.markDirty();
	}

	function setSelectionFlag(a:AuraDef, flag:String, value:Bool):Void {
		var picks = selectedIndices();
		if (picks.length == 0) return;
		host.canvasSnapshot(flag == "lock" ? "Canvas Lock" : "Canvas Visibility");
		for (i in picks) if (a.canvasElements[i] != null) { if (flag == "lock") a.canvasElements[i].locked = value; else setHidden(a.canvasElements[i], value); }
		SettingsStore.markDirty();
	}

	function setAllFlag(a:AuraDef, flag:String, value:Bool):Void {
		host.canvasSnapshot(flag == "lock" ? "Canvas Lock" : "Canvas Visibility");
		for (el in a.canvasElements) if (el != null) { if (flag == "lock") el.locked = value; else setHidden(el, value); }
		SettingsStore.markDirty();
	}

	function alignAny(a:AuraDef, mode:String):Void {
		if (canvasSel < 0 || canvasSel >= a.canvasElements.length) return;
		alignContext(a, a.canvasElements[canvasSel], mode);
	}

	/** Centre the whole selection (as one block) on the aura. */
	function centerOnAura(a:AuraDef):Void {
		var picks = selectedIndices().filter(function(i) return a.canvasElements[i] != null && !a.canvasElements[i].locked);
		if (picks.length == 0) return;
		var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
		for (i in picks) { var b = elementBounds(a, a.canvasElements[i]); minX = Math.min(minX, b.x); minY = Math.min(minY, b.y); maxX = Math.max(maxX, b.x + b.w); maxY = Math.max(maxY, b.y + b.h); }
		var dx = auraBoxW(a) * 0.5 - (minX + maxX) * 0.5, dy = auraBoxH(a) * 0.5 - (minY + maxY) * 0.5;
		host.canvasSnapshot("Canvas Align");
		for (i in picks) { var el = a.canvasElements[i]; setX(el, Math.round(el.xAt(editState) + dx)); setY(el, Math.round(el.yAt(editState) + dy)); }
		SettingsStore.markDirty();
	}

	// ---- Smart guides ------------------------------------------------------------------------

	/** Nearest alignment target for a moving box edge/centre along one axis, or null. */
	function guideSnap(horizontal:Bool, start:Float, size:Float, a:AuraDef, s:Float):{adj:Float, pos:Float} {
		var targets:Array<Float> = horizontal ? [0, auraBoxW(a) * 0.5, auraBoxW(a)] : [0, auraBoxH(a) * 0.5, auraBoxH(a)];
		var editAll = !host.canvasPreview().liveCanvasConditions;
		for (i in 0...a.canvasElements.length) {
			var el = a.canvasElements[i];
			if (el == null || dragIndices.indexOf(i) >= 0 || !el.visible(editAll, editState)) continue;
			var b = elementBounds(a, el);
			if (horizontal) { targets.push(b.x); targets.push(b.x + b.w * 0.5); targets.push(b.x + b.w); }
			else { targets.push(b.y); targets.push(b.y + b.h * 0.5); targets.push(b.y + b.h); }
		}
		var edges = [start, start + size * 0.5, start + size];
		var best:{adj:Float, pos:Float} = null;
		var reach = 6 / s;
		for (e in edges) for (t in targets) {
			var d = t - e;
			if (Math.abs(d) <= reach && (best == null || Math.abs(d) < Math.abs(best.adj))) best = {adj: d, pos: t};
		}
		return best;
	}

	// ---- States ------------------------------------------------------------------------------

	var previewOwner:AuraDef = null;
	/** Stamp of the last frame any panel (editor window or builder card) showed this aura's looks. */
	var lastPreviewSync:Float = 0;
	var stateRuleContexts = new haxe.ds.ObjectMap<AuraStateDef, solarflare.aura.signal.AuraRuleEditorContext>();
	var stateNameBuf = new hl.Bytes(AuraStateDef.MAX_NAME * 4);
	var stateNameFor:String = null;
	var stateDeleteArmed:String = "";
	var nextStateRuleId:Int = 1;

	function releasePreview():Void {
		if (previewOwner != null) previewOwner.previewState = null;
		previewOwner = null;
		editState = "";
		stateDeleteArmed = "";
		stateNameFor = null;
	}

	/** Draw the state being edited on the real aura; auras without states follow nothing. */
	public function syncPreview(a:AuraDef):Void {
		lastPreviewSync = haxe.Timer.stamp();
		if (previewOwner != a) {
			if (previewOwner != null) previewOwner.previewState = null;
			previewOwner = a;
			editState = "";
			stateDeleteArmed = "";
			stateNameFor = null;
		}
		if (editState != "" && AuraStateDef.find(a.states, editState) == null) editState = "";
		a.previewState = a.states.length > 0 ? editState : null;
	}

	function stateLabel(a:AuraDef, id:String):String {
		if (id == "") return "Default";
		var st = AuraStateDef.find(a.states, id);
		return st != null ? st.name : id;
	}

	/** Look buttons (Default + each state) that wrap to the available width, then the add button. */
	function drawStateTabs(a:AuraDef):Void {
		var tabs:Array<String> = [""];
		for (st in a.states) tabs.push(st.id);
		var availW = ImGui.getContentRegionAvail().x;
		var used = 0.0;
		var first = true;
		function place(width:Float):Void {
			if (!first) {
				if (used + 6 + width > availW) used = 0; else { ImGui.sameLine(0, 6); used += 6; }
			}
			first = false;
			used += width;
		}
		for (id in tabs) {
			var active = id == editState;
			var live = a.activeState == id && a.states.length > 0;
			var label = stateLabel(a, id) + (live ? " *" : "");
			place(ImGui.calcTextSize(label).x + 20);
			if (active) ImGui.pushStyleColor(ImGuiCol.Button, solarflare.ui.ThemePalette.current().accent);
			if (ImGui.button(label + "##cv_state_" + id)) { editState = id; stateDeleteArmed = ""; }
			if (active) ImGui.popStyleColor();
			if (live && ImGui.isItemHovered()) ImGui.setTooltip("This is the look showing in the game right now.");
		}
		if (a.states.length < AuraStateDef.MAX_STATES) {
			place(ImGui.calcTextSize("+ State").x + 20);
			if (ImGui.button("+ State##cv_state_add")) {
				host.canvasSnapshot("Add State");
				var st = new AuraStateDef(AuraStateDef.uniqueId(a.states), "State " + (a.states.length + 1));
				a.states.push(st);
				editState = st.id;
				SettingsStore.markDirty();
			}
			if (ImGui.isItemHovered()) ImGui.setTooltip("Add another look for this canvas. Elements can show, hide, move, resize and recolour per look; conditions decide when it is used.");
			if (editState != "") {
				place(ImGui.calcTextSize("Duplicate").x + 20);
				if (ImGui.button("Duplicate##cv_state_dup")) duplicateState(a);
				if (ImGui.isItemHovered()) ImGui.setTooltip("Copy the selected look with its trigger, layer visibility and per-look values. Handy for looks that differ only by one condition.");
			}
		}
	}

	function wrappedHint(text:String):Void {
		ImGui.pushStyleColor(ImGuiCol.Text, solarflare.ui.ThemePalette.current().textDisabled);
		ImGui.textWrapped(text);
		ImGui.popStyleColor();
	}

	function drawStateHints(a:AuraDef):Void {
		if (a.states.length == 0) {
			wrappedHint("One look today. Add a state to design variations that switch on conditions, or on another aura in the same group.");
			return;
		}
		if (editState == "") {
			wrappedHint("Previewing the Default look: used when no state's conditions match. Other looks start from it and only change what they override.");
			return;
		}
		var live = a.activeState == "" ? "Default" : stateLabel(a, a.activeState);
		wrappedHint("Previewing " + stateLabel(a, editState) + ". In the game right now: " + live + ".");
	}

	/** Builder card: tabs, hints and the selected look's settings, all in one column. */
	public function drawStatesPanel(a:AuraDef):Void {
		syncPreview(a);
		drawStateTabs(a);
		ImGui.spacing();
		drawStateHints(a);
		var st = AuraStateDef.find(a.states, editState);
		if (st != null) {
			ImGui.separator();
			UiChrome.subHeader("Settings for " + st.name);
			drawStateSettings(a, st);
		}
	}


	function drawStateSettings(a:AuraDef, st:AuraStateDef):Void {
		if (stateNameFor != st.id) { ByteUtil.fillBuf(stateNameBuf, AuraStateDef.MAX_NAME * 4, st.name); stateNameFor = st.id; }
		UiLayout.propertyGrid("##cv_state_props", function() {
			UiLayout.propertyRow("Name", function() {
				ImGui.setNextItemWidth(-1);
				if (ImGui.inputText("##cv_state_name", stateNameBuf, AuraStateDef.MAX_NAME * 4)) {
					var n = StringTools.trim(ByteUtil.readBytes(stateNameBuf, AuraStateDef.MAX_NAME * 4));
					if (n.length > 0) { st.name = n.length > AuraStateDef.MAX_NAME ? n.substr(0, AuraStateDef.MAX_NAME) : n; SettingsStore.markDirty(); }
				}
				canvasFieldUndo("Rename State");
			});
			UiLayout.propertyRow("Order", function() {
				var at = a.states.indexOf(st);
				ImGui.beginDisabled(at <= 0);
				if (ImGui.button("Earlier##cv_state_up")) { host.canvasSnapshot("Reorder State"); a.states.splice(at, 1); a.states.insert(at - 1, st); SettingsStore.markDirty(); }
				ImGui.endDisabled();
				ImGui.sameLine(0, 4);
				ImGui.beginDisabled(at >= a.states.length - 1);
				if (ImGui.button("Later##cv_state_down")) { host.canvasSnapshot("Reorder State"); a.states.splice(at, 1); a.states.insert(at + 1, st); SettingsStore.markDirty(); }
				ImGui.endDisabled();
				ImGui.sameLine(0, 12);
				var armed = stateDeleteArmed == st.id;
				ImGui.beginDisabled(a.states.length >= AuraStateDef.MAX_STATES);
				if (ImGui.button("Duplicate##cv_state_dup2")) duplicateState(a);
				ImGui.endDisabled();
				ImGui.sameLine(0, 12);
				if (ImGui.button((armed ? "Confirm delete##cv_state_del" : "Delete state##cv_state_del"))) {
					if (!armed) stateDeleteArmed = st.id; else deleteState(a, st);
				}
			}, "The first state in this order whose conditions match is the one shown. If none match, the Default look shows.");
		});
		drawStateTrigger(a, st);
	}

	function deleteState(a:AuraDef, st:AuraStateDef):Void {
		host.canvasSnapshot("Delete State");
		a.states.remove(st);
		stateRuleContexts.remove(st);
		for (el in a.canvasElements) if (el != null) el.forgetState(st.id);
		editState = "";
		stateDeleteArmed = "";
		SettingsStore.markDirty();
	}

	function drawStateTrigger(a:AuraDef, st:AuraStateDef):Void {
		UiChrome.subHeader("When this look is used");
		var mates:Array<AuraDef> = [];
		if (a.group != null && a.group.length > 0) for (o in host.canvasAuras()) if (o != null && o != a && o.group == a.group) mates.push(o);
		if (mates.length > 0) {
			ImGui.textDisabled("Use this look when a group member is showing:");
			for (m in mates) {
				ImGui.sameLine(0, 6);
				if (ImGui.smallButton(m.displayLabel() + "##cv_state_mate_" + m.id)) {
					host.canvasSnapshot("State Trigger");
					var c = new solarflare.aura.signal.AuraConditionDef();
					c.signal = "aura.active"; c.subject = m.id; c.subjectLabel = m.displayLabel(); c.op = "is"; c.boolValue = true;
					if (st.rule.conditions.length < solarflare.aura.signal.AuraRuleDef.MAX_CONDITIONS) st.rule.conditions.push(c);
					SettingsStore.markDirty();
				}
			}
		} else if (a.group == null || a.group.length == 0) ImGui.textDisabled("Put this aura in a display group to tie a state to its members, or use any condition below.");
		var context = stateRuleContexts.get(st);
		if (context == null) {
			context = new solarflare.aura.signal.AuraRuleEditorContext(a.id + "_state_" + nextStateRuleId++, st.rule, st.result, [], false);
			stateRuleContexts.set(st, context);
		}
		context.rule = st.rule;
		context.snapshot = preciseFn;
		ImGui.textDisabled(st.result.known ? (st.result.hit ? "This state is active now." : "Conditions do not match right now.") : "No conditions yet, or the game state is unknown. An empty state never activates.");
		solarflare.aura.signal.AuraConditionEditor.drawContext(context);
	}

	/** Which states show the selected element, and a way back to the Default values for the edited state. */
	function drawElementStateRows(a:AuraDef, el:AuraCanvasElement):Void {
		if (a.states.length == 0) return;
		UiLayout.propertyRow("Shown in", function() {
			var all = el.inStates == null;
			canvasFlagRef.set(all);
			if (ImGui.checkbox("All looks##cv_in_all", canvasFlagRef)) {
				host.canvasSnapshot("Canvas States");
				el.inStates = canvasFlagRef.get() ? null : ([""] .concat([for (st in a.states) st.id]));
				SettingsStore.markDirty();
			}
			if (el.inStates != null) {
				for (id in [""].concat([for (st in a.states) st.id])) {
					canvasFlagRef.set(el.inStates.indexOf(id) >= 0);
					if (ImGui.checkbox(stateLabel(a, id) + "##cv_in_" + id, canvasFlagRef)) {
						host.canvasSnapshot("Canvas States");
						if (canvasFlagRef.get()) { if (el.inStates.indexOf(id) < 0) el.inStates.push(id); } else el.inStates.remove(id);
						SettingsStore.markDirty();
					}
				}
			}
		}, "Limit this element to chosen looks. Elements that are not part of the look being edited are hidden on the stage.");
		if (editState != "") {
			UiLayout.propertyRow("This look", function() {
				var has = el.ov(editState) != null;
				ImGui.beginDisabled(!has);
				if (ImGui.button("Reset to Default values##cv_ov_reset", ImGui.vec2(-1, 0))) { host.canvasSnapshot("Reset Look"); el.clearOverride(editState); SettingsStore.markDirty(); }
				ImGui.endDisabled();
			}, has_tooltip());
		}
	}

	static inline function has_tooltip():String return "Position, size, colour, opacity, rotation and Hidden edited while this look is selected apply to this look only.";

	function drawMultiSelectBar(a:AuraDef):Void {
		builderSectionHeader((canvasMulti.length + 1) + " layers selected");
		UiLayout.inlineSplit("##cv_group_btns", 3, function(index:Int, cellW:Single) {
			var size = ImGui.vec2(cellW, 0);
			if (index == 0 && ImGui.button("Group##cv_msg", size)) groupSelected(a);
			else if (index == 1) { ImGui.beginDisabled(!selectionHasGroup(a)); if (ImGui.button("Ungroup##cv_msug", size)) ungroupSelected(a); ImGui.endDisabled(); }
			else if (index == 2 && ImGui.button("Duplicate##cv_msdp", size)) duplicateSelected(a);
		});
		UiLayout.propertyGrid("##cv_scale_sel", function() {
			UiLayout.propertyRow("Scale all", function() {
				UiLayout.inlinePair("##cv_scale_pair",
					function(_:Single) { NumberField.draw("##cv_scale_pct", groupScale, 10, 400, "%.0f%%", null); },
					function(_:Single) {
						ImGui.beginDisabled(editState != "");
						if (ImGui.button("Apply##cv_scale_apply", ImGui.vec2(-1, 0))) scaleSelectedBy(a, groupScale.get() / 100);
						ImGui.endDisabled();
					});
			}, "Resizes the selected layers together about their shared centre: positions, sizes, text and outlines. Available in the Default look.");
		});
		ImGui.textDisabled("Properties below edit the last-clicked layer. Move, nudge, duplicate and delete act on all.");
		UiLayout.inlineSplit("##ab_cv_align_a", 3, function(index:Int, cellW:Single) {
			var size = ImGui.vec2(cellW, 0);
			if (index == 0 && ImGui.button("Align left##ab_cv_msl", size)) alignSelection(a, "left");
			else if (index == 1 && ImGui.button("Center H##ab_cv_msch", size)) alignSelection(a, "centerH");
			else if (index == 2 && ImGui.button("Align right##ab_cv_msr", size)) alignSelection(a, "right");
		});
		UiLayout.inlineSplit("##ab_cv_align_b", 3, function(index:Int, cellW:Single) {
			var size = ImGui.vec2(cellW, 0);
			if (index == 0 && ImGui.button("Align top##ab_cv_mst", size)) alignSelection(a, "top");
			else if (index == 1 && ImGui.button("Middle V##ab_cv_mscv", size)) alignSelection(a, "middleV");
			else if (index == 2 && ImGui.button("Align bottom##ab_cv_msb", size)) alignSelection(a, "bottom");
		});
		UiLayout.inlineSplit("##ab_cv_align_c", 3, function(index:Int, cellW:Single) {
			var size = ImGui.vec2(cellW, 0);
			if (index == 0 && ImGui.button("Space across##ab_cv_msdh", size)) alignSelection(a, "distH");
			else if (index == 1 && ImGui.button("Space down##ab_cv_msdv", size)) alignSelection(a, "distV");
			else if (index == 2 && ImGui.button("Duplicate all##ab_cv_msdup", size)) duplicateSelected(a);
		});
	}

	/** Typed-field undo: capture on activation, commit when the edit lands. */
	function canvasUndoBase():String {
		try return host.canvasSnapshotJson() catch (_:Dynamic) return null;
	}

	function canvasFieldUndo(action:String):Void {
		if (ImGui.isItemActivated()) canvasFieldUndoState = canvasUndoBase();
		if (ImGui.isItemDeactivatedAfterEdit() && canvasFieldUndoState != null) {
			host.canvasUndoPush(action, canvasFieldUndoState);
			canvasFieldUndoState = null;
		}
	}

	// ---- Freeform canvas editor -------------------------------------------------------------
	// Stage (drag / resize / nudge / context menu) + Layers list + typed properties.
	// Coordinates are aura-local and unscaled; the stage fits them, the live HUD multiplies by Scale.

	static inline var CANVAS_STAGE_PAD:Single = 18;
	static inline var CANVAS_HANDLE_PX:Single = 7;
	static inline var CANVAS_GRID:Float = 4;
	static inline var CANVAS_DRAG_NONE:Int = 0;
	static inline var CANVAS_DRAG_MOVE:Int = 1;
	static inline var CANVAS_DRAG_SIZE:Int = 2;


	/** Global machine-local preference, independent of the selected aura and its Undo snapshots. */
	function drawCanvasAssetFolder():Void {
		if (canvasFolderGeneration != CustomImages.generation) {
			ByteUtil.fillBuf(canvasFolderBuf, CANVAS_FOLDER_BUF, CustomImages.folder);
			canvasFolderGeneration = CustomImages.generation;
		}
		UiLayout.propertyGrid("##ab_canvas_asset_folder", function() {
			UiLayout.propertyRow("Images folder", function() {
				ImGui.setNextItemWidth(Math.max(60, ImGui.getContentRegionAvail().x - 90));
				var enter = ImGui.inputTextWithHint("##ab_cv_folder_path", CustomImages.displayDir, canvasFolderBuf, CANVAS_FOLDER_BUF,
					imgui.Enums.ImGuiInputTextFlags.EnterReturnsTrue);
				ImGui.sameLine(0, 4);
				if (UiChrome.ghostButton("Use folder##ab_cv_folder_apply", ImGui.vec2(86, 28)) || enter)
					queueCanvasAssetFolder(ByteUtil.readBytes(canvasFolderBuf, CANVAS_FOLDER_BUF));
			}, "Paste a full folder path, then Use folder. This choice is saved for this PC, across all auras. Leave blank for custom_images.");
			UiLayout.propertyRow("Folder actions", function() {
				UiLayout.inlineSplit("##ab_cv_folder_actions", 3, function(index:Int, width:Single) {
					if (index == 0 && UiChrome.ghostButton("Default##ab_cv_folder_default", ImGui.vec2(width, 28))) queueCanvasAssetFolder("");
					if (index == 1 && UiChrome.ghostButton("Copy path##ab_cv_folder_copy", ImGui.vec2(width, 28))) UiActionQueue.copyText(CustomImages.displayDir, "Images folder path copied.");
					if (index == 2 && UiChrome.ghostButton("Refresh##ab_cv_img_refresh", ImGui.vec2(width, 28))) CustomImages.requestRefresh();
				});
			});
		});
		ImGui.textWrapped(CustomImages.displayDir);
		if (CustomImages.folderError)
			ImGui.textColored(solarflare.ui.ThemePalette.status(solarflare.ui.ThemePalette.STATUS_WARN), CustomImages.status);
		else ImGui.textWrapped(CustomImages.status);
		if (canvasFolderMsg.length > 0) {
			if (canvasFolderError) ImGui.textColored(solarflare.ui.ThemePalette.status(solarflare.ui.ThemePalette.STATUS_DANGER), canvasFolderMsg);
			else ImGui.textWrapped(canvasFolderMsg);
		}
	}

	function queueCanvasAssetFolder(path:String):Void {
		UiActionQueue.custom(function() {
			try {
				if (CustomImages.useFolder(path)) SettingsStore.markDirty();
				canvasFolderGeneration = -1;
				canvasFolderMsg = "Folder selected. Choose Image to add one to the canvas.";
				canvasFolderError = false;
			} catch (error:Dynamic) {
				canvasFolderMsg = Std.string(error); canvasFolderError = true;
			}
		});
	}

	function addCanvasElement(a:AuraDef, el:AuraCanvasElement, action:String, atBottom:Bool):Void {
		host.canvasSnapshot(action);
		if (atBottom) {
			a.canvasElements.insert(0, el);
			canvasSel = 0; canvasMulti = [];
		} else {
			a.canvasElements.push(el);
			canvasSel = a.canvasElements.length - 1; canvasMulti = [];
		}
		SettingsStore.markDirty();
	}

	function removeCanvasElement(a:AuraDef, index:Int):Void {
		if (index < 0 || index >= a.canvasElements.length) return;
		host.canvasSnapshot("Canvas Delete");
		canvasSel = CanvasSelection.afterRemoval(canvasSel,index,a.canvasElements.length);
		canvasMulti = [];
		canvasRuleContexts.remove(a.canvasElements[index]);
		canvasRowIds.remove(a.canvasElements[index]);
		a.canvasElements.splice(index, 1); a.sizeDirty=true;
		SettingsStore.markDirty();
	}

	function duplicateCanvasElement(a:AuraDef, index:Int):Void {
		if (index < 0 || index >= a.canvasElements.length || a.canvasElements[index] == null) return;
		host.canvasSnapshot("Canvas Duplicate");
		var copy = AuraCanvasElement.fromDyn(a.canvasElements[index].toObj());
		setX(copy, copy.xAt(editState) + 8);
		setY(copy, copy.yAt(editState) + 8);
		copy.locked = false;
		a.canvasElements.insert(index + 1, copy);
		canvasSel = index + 1; canvasMulti = [];
		SettingsStore.markDirty();
	}

	/** Move one layer; draw order is array order, so a higher index draws on top. */
	function moveCanvasElement(a:AuraDef, from:Int, to:Int, action:String):Void {
		var n = a.canvasElements.length;
		if (from < 0 || from >= n) return;
		if (to < 0) to = 0;
		if (to >= n) to = n - 1;
		if (to == from) return;
		host.canvasSnapshot(action);
		var el = a.canvasElements.splice(from, 1)[0];
		a.canvasElements.insert(to, el);
		canvasSel = to; canvasMulti = [];
		SettingsStore.markDirty();
	}

	/** Aura-local box of an element into cvBox*; text is measured with the preview's token values. */
	function canvasBox(a:AuraDef, el:AuraCanvasElement):Void {
		cvBoxX = el.xAt(editState);
		cvBoxY = el.yAt(editState);
		if (el.kind == AuraCanvasElement.KIND_TEXT) {
			cvBoxW = measureCanvasElementW(a, el);
			cvBoxH = measureCanvasElementH(a, el);
		} else {
			cvBoxW = el.wAt(editState) > 1 ? el.wAt(editState) : (a.w.get() > 1 ? a.w.get() : 96);
			cvBoxH = el.hAt(editState) > 1 ? el.hAt(editState) : (a.h.get() > 1 ? a.h.get() : 96);
		}
		if (cvBoxW < 4) cvBoxW = 4;
		if (cvBoxH < 4) cvBoxH = 4;
	}

	/** Topmost visible, unlocked element under an aura-local point, or -1. */
	function canvasHitTest(a:AuraDef, mx:Float, my:Float):Int {
		var i = a.canvasElements.length - 1;
		while (i >= 0) {
			var el = a.canvasElements[i];
			if (el != null && el.visible(!host.canvasPreview().liveCanvasConditions, editState) && !el.locked) {
				var b = elementBounds(a, el);
				if (mx >= b.x && mx <= b.x + b.w && my >= b.y && my <= b.y + b.h) return i;
			}
			i--;
		}
		return -1;
	}

	inline function canvasSnapValue(v:Float, snap:Bool):Float {
		return snap ? Math.round(v / snapStep) * snapStep : Math.round(v);
	}


	// ---- State-aware element access ---------------------------------------------------------
	/** "" edits the Default look (base values); any other id writes that state's overrides. */
	var editState:String = "";

	function setX(el:AuraCanvasElement, v:Float):Void { if (editState == "") el.x = v; else el.overrideFor(editState).x = v; }
	function setY(el:AuraCanvasElement, v:Float):Void { if (editState == "") el.y = v; else el.overrideFor(editState).y = v; }
	function setW(el:AuraCanvasElement, v:Float):Void { if (editState == "") el.w = v; else el.overrideFor(editState).w = v; }
	function setH(el:AuraCanvasElement, v:Float):Void { if (editState == "") el.h = v; else el.overrideFor(editState).h = v; }
	function setRotation(el:AuraCanvasElement, v:Float):Void { if (editState == "") el.rotation = v; else el.overrideFor(editState).rotation = v; }
	function setOpacity(el:AuraCanvasElement, v:Float):Void { if (editState == "") el.opacity = v; else el.overrideFor(editState).opacity = v; }
	function setColor(el:AuraCanvasElement, v:Int):Void { if (editState == "") el.color = v; else el.overrideFor(editState).color = v; }
	function setHidden(el:AuraCanvasElement, v:Bool):Void { if (editState == "") el.hidden = v; else el.overrideFor(editState).hidden = v; }

	// ---- Selection ---------------------------------------------------------------------------

	/** Extra selected layers besides `canvasSel` (the primary, shown in Properties). Indices into canvasElements. */
	var canvasMulti:Array<Int> = [];
	var zoom:Float = 1;
	var panX:Float = 0;
	var panY:Float = 0;
	static inline var DRAG_ROTATE:Int = 3;
	static inline var DRAG_MARQUEE:Int = 4;
	static inline var DRAG_PAN:Int = 5;
	var dragHandle:Int = -1;
	var dragStartRot:Float = 0;
	var dragStarts:Array<Float> = [];
	var dragIndices:Array<Int> = [];
	var dragBoxX:Float = 0;
	var dragBoxY:Float = 0;
	var marqueeX0:Float = 0;
	var marqueeY0:Float = 0;
	var marqueeX1:Float = 0;
	var marqueeY1:Float = 0;
	var marqueeAdditive:Bool = false;

	public inline function isSelected(i:Int):Bool return i == canvasSel || canvasMulti.indexOf(i) >= 0;

	function selectedIndices():Array<Int> {
		var out:Array<Int> = [];
		if (canvasSel >= 0) out.push(canvasSel);
		for (i in canvasMulti) if (i != canvasSel) out.push(i);
		out.sort(function(x, y) return x - y);
		return out;
	}

	function selectOnly(i:Int):Void { canvasSel = i; canvasMulti = []; }

	/** Ctrl toggles a layer in the selection; the last one added becomes the primary. */
	function toggleSelect(i:Int):Void {
		if (isSelected(i)) {
			if (i == canvasSel) {
				canvasSel = canvasMulti.length > 0 ? canvasMulti.pop() : -1;
			} else canvasMulti.remove(i);
		} else {
			if (canvasSel >= 0) canvasMulti.push(canvasSel);
			canvasSel = i;
		}
	}

	function selectIndices(list:Array<Int>):Void {
		if (list.length == 0) { selectOnly(-1); return; }
		canvasSel = list[list.length - 1];
		canvasMulti = [for (i in list) if (i != canvasSel) i];
	}

	function resetView():Void { zoom = 1; panX = 0; panY = 0; }

	// ---- Handles -----------------------------------------------------------------------------

	static inline var H_ROTATE:Int = 8;
	static inline var ROTATE_STEM_PX:Float = 22;

	/** Handle index under the cursor: 0..7 around the box (TL,T,TR,R,BR,B,BL,L), 8 = rotate, or -1. */
	function canvasHandleAt(a:AuraDef, el:AuraCanvasElement, mx:Float, my:Float, s:Float):Int {
		if (el == null || el.locked || !el.visible(!host.canvasPreview().liveCanvasConditions, editState) || canvasMulti.length > 0) return -1;
		canvasBox(a, el);
		var r = (CANVAS_HANDLE_PX + 3) / s;
		if (rotatable(el)) {
			var c = rotatedPoint(cvBoxX + cvBoxW * 0.5, cvBoxY - ROTATE_STEM_PX / s, cvBoxX + cvBoxW * 0.5, cvBoxY + cvBoxH * 0.5, el.rotationAt(editState));
			if (Math.abs(mx - c.x) <= r && Math.abs(my - c.y) <= r) return H_ROTATE;
		}
		if (el.kind == AuraCanvasElement.KIND_TEXT || el.rotationAt(editState) != 0) return -1;
		for (h in 0...8) {
			var p = handlePos(h);
			if (Math.abs(mx - p.x) <= r && Math.abs(my - p.y) <= r) return h;
		}
		return -1;
	}

	/** Handle position on the box last written by canvasBox(). */
	function handlePos(h:Int):{x:Float, y:Float} {
		var x = switch (h) { case 0 | 6 | 7: cvBoxX; case 1 | 5: cvBoxX + cvBoxW * 0.5; default: cvBoxX + cvBoxW; };
		var y = switch (h) { case 0 | 1 | 2: cvBoxY; case 3 | 7: cvBoxY + cvBoxH * 0.5; default: cvBoxY + cvBoxH; };
		return {x: x, y: y};
	}

	static function rotatedPoint(px:Float, py:Float, cx:Float, cy:Float, deg:Float):{x:Float, y:Float} {
		if (deg == 0) return {x: px, y: py};
		var r = deg * Math.PI / 180, c = Math.cos(r), sn = Math.sin(r), dx = px - cx, dy = py - cy;
		return {x: cx + dx * c - dy * sn, y: cy + dx * sn + dy * c};
	}

	static function handleCursor(h:Int):Int {
		return switch (h) {
			case 0 | 4: imgui.Enums.ImGuiMouseCursor.ResizeNWSE;
			case 2 | 6: imgui.Enums.ImGuiMouseCursor.ResizeNESW;
			case 1 | 5: imgui.Enums.ImGuiMouseCursor.ResizeNS;
			default: imgui.Enums.ImGuiMouseCursor.ResizeEW;
		};
	}

	/** Resize the primary element from handle `h` using the box captured at press time. */
	function applyResize(el:AuraCanvasElement, h:Int, dx:Float, dy:Float, snap:Bool, keepRatio:Bool):Void {
		var sx = dragBoxX, sy = dragBoxY, sw = canvasDragW, sh = canvasDragH;
		var left = h == 0 || h == 6 || h == 7, right = h == 2 || h == 3 || h == 4;
		var top = h == 0 || h == 1 || h == 2, bottom = h == 4 || h == 5 || h == 6;
		var nx = sx, ny = sy, nw = sw, nh = sh;
		if (left) { nx = canvasSnapValue(sx + dx, snap); nw = sx + sw - nx; }
		if (right) nw = canvasSnapValue(sx + sw + dx, snap) - sx;
		if (top) { ny = canvasSnapValue(sy + dy, snap); nh = sy + sh - ny; }
		if (bottom) nh = canvasSnapValue(sy + sh + dy, snap) - sy;
		if (keepRatio && sw > 0 && sh > 0 && (left || right) && (top || bottom)) {
			var k = Math.max(Math.max(4, nw) / sw, Math.max(4, nh) / sh);
			nw = Math.round(sw * k); nh = Math.round(sh * k);
			if (left) nx = sx + sw - nw;
			if (top) ny = sy + sh - nh;
		}
		if (nw < 4) { if (left) nx -= 4 - nw; nw = 4; }
		if (nh < 4) { if (top) ny -= 4 - nh; nh = 4; }
		setX(el, nx); setY(el, ny); setW(el, nw); setH(el, nh);
	}

	// ---- Stage -------------------------------------------------------------------------------

	function drawCanvasStage(a:AuraDef):Void {
		var els = a.canvasElements;
		var theme = solarflare.ui.ThemePalette.current();
		var preview = host.canvasPreview();
		var editAll = !preview.liveCanvasConditions;
		var auraW:Float = a.w.get() > 1 ? a.w.get() : 96;
		var auraH:Float = a.h.get() > 1 ? a.h.get() : 96;
		var availW:Single = Math.max(140, ImGui.getContentRegionAvail().x);
		var pad = CANVAS_STAGE_PAD;
		var fit:Single = Math.min((availW - pad * 2) / auraW, (stageMaxH - pad * 2) / auraH);
		fit = Math.max(0.2, Math.min(6, fit));
		var s:Single = Math.max(0.1, Math.min(24, fit * zoom));
		var stageH:Single = Math.max(160, stageMaxH);
		var origin = ImGui.getCursorScreenPos();
		var ox:Single = origin.x + (availW - auraW * s) * 0.5 + panX;
		var oy:Single = origin.y + (stageH - auraH * s) * 0.5 + panY;
		ImGui.invisibleButton("##ab_cv_stage", ImGui.vec2(availW, stageH));
		var hovered = ImGui.isItemHovered();
		var active = ImGui.isItemActive();
		var activated = ImGui.isItemActivated();
		var focused = ImGui.isItemFocused();
		var mouse = ImGui.getMousePos();
		var mx:Float = (mouse.x - ox) / s;
		var my:Float = (mouse.y - oy) / s;
		if (hovered) { cursorX = mx; cursorY = my; } else { cursorX = Math.NaN; cursorY = Math.NaN; }
		var shift = ImGui.isKeyDown(ImGuiKey.LeftShift) || ImGui.isKeyDown(ImGuiKey.RightShift);
		var ctrl = ImGui.isKeyDown(ImGuiKey.LeftCtrl) || ImGui.isKeyDown(ImGuiKey.RightCtrl);
		var alt = ImGui.isKeyDown(ImGuiKey.LeftAlt) || ImGui.isKeyDown(ImGuiKey.RightAlt);
		var snap = canvasSnap.get() && !alt;

		// Drop target: a thumbnail dragged from the Image library lands where it is released.
		if (ImGui.beginDragDropTarget()) {
			var dropped = ImGui.acceptDragDropPayload(ImageLibraryPanel.PAYLOAD_IMAGE);
			if (dropped != null && ImGui.ImGuiPayload_IsDataType(dropped, ImageLibraryPanel.PAYLOAD_IMAGE)) {
				var stem = PayloadExt.getString(dropped);
				if (stem != null && stem.length > 0) dropImage(a, stem, mx, my, snap);
			}
			ImGui.endDragDropTarget();
		}

		// Pan: middle button, or Space + left drag. Deltas are consumed each frame so panning stays incremental.
		var spaceHeld = ImGui.isKeyDown(ImGuiKey.Space) || tool == 1;
		if (hovered && canvasDragMode == CANVAS_DRAG_NONE && ImGui.isMouseClicked(2)) { canvasDragMode = DRAG_PAN; }
		if (activated && spaceHeld && canvasDragMode == CANVAS_DRAG_NONE) canvasDragMode = DRAG_PAN;
		if (canvasDragMode == DRAG_PAN) {
			if (ImGui.isMouseDown(2) || (active && spaceHeld)) {
				var button = ImGui.isMouseDown(2) ? 2 : 0;
				var d = ImGui.getMouseDragDelta(button, 0);
				panX += d.x; panY += d.y;
				ImGui.resetMouseDragDelta(button);
				ImGui.setMouseCursor(imgui.Enums.ImGuiMouseCursor.ResizeAll);
			} else canvasDragMode = CANVAS_DRAG_NONE;
		}

		// Pen and node tools take the pointer before layer selection does.
		var toolUsed = false;
		if (penEl != null && a.canvasElements.indexOf(penEl) < 0) { penEl = null; penDragging = false; }
		if (canvasDragMode != DRAG_PAN) {
			if (tool != TOOL_PEN && penEl != null) finishPen(a);
			if (tool == TOOL_PEN) { penStep(a, mx, my, s, active, activated, alt, hovered); toolUsed = true; }
			else if (tool == TOOL_NODES) toolUsed = nodesStep(a, mx, my, s, active, activated, shift, ctrl, alt);
		}

		// Press: handle of the lone selection first, then the topmost layer, else start a marquee.
		if (activated && !toolUsed && canvasDragMode == CANVAS_DRAG_NONE) {
			var primary = canvasSel >= 0 && canvasSel < els.length ? els[canvasSel] : null;
			var handle = canvasHandleAt(a, primary, mx, my, s);
			dragHandle = handle;
			if (handle >= 0) {
				canvasBox(a, primary);
				dragBoxX = cvBoxX; dragBoxY = cvBoxY; canvasDragW = cvBoxW; canvasDragH = cvBoxH;
				dragStartRot = primary.rotation;
				canvasDragMode = handle == H_ROTATE ? DRAG_ROTATE : CANVAS_DRAG_SIZE;
			} else {
				var hit = canvasHitTest(a, mx, my);
				if (hit >= 0) {
					if (ctrl) toggleSelect(hit);
					else if (!isSelected(hit)) selectGroupOf(a, hit, alt);
					else if (hit != canvasSel && !shift) { /* keep the group; dragging moves all */ }
					if (isSelected(hit)) canvasDragMode = CANVAS_DRAG_MOVE;
				} else {
					marqueeAdditive = ctrl || shift;
					if (!marqueeAdditive) selectOnly(-1);
					marqueeX0 = marqueeX1 = mx; marqueeY0 = marqueeY1 = my;
					canvasDragMode = DRAG_MARQUEE;
				}
			}
			if (canvasDragMode == CANVAS_DRAG_MOVE) {
				dragIndices = selectedIndices().filter(function(i) return !els[i].locked);
				dragStarts = [];
				for (i in dragIndices) { dragStarts.push(els[i].xAt(editState)); dragStarts.push(els[i].yAt(editState)); }
				dragGroup = null;
				for (i in dragIndices) {
					var gb = elementBounds(a, els[i]);
					if (dragGroup == null) dragGroup = {x: gb.x, y: gb.y, w: gb.w, h: gb.h};
					else {
						var gx0 = Math.min(dragGroup.x, gb.x), gy0 = Math.min(dragGroup.y, gb.y);
						var gx1 = Math.max(dragGroup.x + dragGroup.w, gb.x + gb.w), gy1 = Math.max(dragGroup.y + dragGroup.h, gb.y + gb.h);
						dragGroup = {x: gx0, y: gy0, w: gx1 - gx0, h: gy1 - gy0};
					}
				}
			}
			if (canvasDragMode == CANVAS_DRAG_MOVE || canvasDragMode == CANVAS_DRAG_SIZE || canvasDragMode == DRAG_ROTATE) {
				canvasDragMoved = false;
				canvasDragUndo = canvasUndoBase();
			}
		}
		if (active && canvasDragMode != CANVAS_DRAG_NONE && canvasDragMode != DRAG_PAN && ImGui.isMouseDragging(0, 0)) {
			var d = ImGui.getMouseDragDelta(0, 0);
			var dx:Float = d.x / s;
			var dy:Float = d.y / s;
			switch (canvasDragMode) {
				case CANVAS_DRAG_MOVE:
					var mdx = dx, mdy = dy;
					guideX = Math.NaN; guideY = Math.NaN;
					if (showGuides.get() && !alt && dragGroup != null) {
						var gx = guideSnap(true, dragGroup.x + dx, dragGroup.w, a, s);
						var gy = guideSnap(false, dragGroup.y + dy, dragGroup.h, a, s);
						if (gx != null) { mdx = dx + gx.adj; guideX = gx.pos; }
						if (gy != null) { mdy = dy + gy.adj; guideY = gy.pos; }
					}
					for (k in 0...dragIndices.length) {
						var el = els[dragIndices[k]];
						setX(el, Math.isNaN(guideX) ? canvasSnapValue(dragStarts[k * 2] + mdx, snap) : Math.round(dragStarts[k * 2] + mdx));
						setY(el, Math.isNaN(guideY) ? canvasSnapValue(dragStarts[k * 2 + 1] + mdy, snap) : Math.round(dragStarts[k * 2 + 1] + mdy));
					}
					canvasDragMoved = true;
				case CANVAS_DRAG_SIZE:
					if (canvasSel >= 0 && canvasSel < els.length) { applyResize(els[canvasSel], dragHandle, dx, dy, snap, shift); canvasDragMoved = true; }
				case DRAG_ROTATE:
					if (canvasSel >= 0 && canvasSel < els.length) {
						var el = els[canvasSel];
						canvasBox(a, el);
						var ang = Math.atan2(my - (cvBoxY + cvBoxH * 0.5), mx - (cvBoxX + cvBoxW * 0.5)) * 180 / Math.PI + 90;
						setRotation(el, AuraCanvasElement.clampRotation(snap ? Math.round(ang / 15) * 15 : Math.round(ang)));
						canvasDragMoved = true;
					}
				case DRAG_MARQUEE:
					marqueeX1 = mx; marqueeY1 = my;
				default:
			}
		}
		if (!active && canvasDragMode != CANVAS_DRAG_NONE && canvasDragMode != DRAG_PAN) {
			if (canvasDragMode == DRAG_MARQUEE) applyMarquee(a, editAll);
			else if (canvasDragMoved && canvasDragUndo != null) {
				host.canvasUndoPush(canvasDragMode == CANVAS_DRAG_MOVE ? "Canvas Move" : (canvasDragMode == DRAG_ROTATE ? "Canvas Rotate" : "Canvas Resize"), canvasDragUndo);
				SettingsStore.markDirty();
			}
			canvasDragMode = CANVAS_DRAG_NONE;
			canvasDragUndo = null;
			canvasDragMoved = false;
			guideX = Math.NaN; guideY = Math.NaN; dragGroup = null;
		}

		// Keyboard while the stage has focus or the pointer.
		var nodeKeysUsed = tool == TOOL_NODES && (focused || hovered) && !active && nodesKeys(a, shift);
		if (!nodeKeysUsed && tool != TOOL_PEN && (focused || hovered) && !active && canvasSel >= 0 && canvasSel < els.length && (focused || !ImGui.isAnyItemActive())) {
			var picks = selectedIndices();
			var step:Float = shift ? 10 : 1;
			var nx:Float = 0;
			var ny:Float = 0;
			if (ImGui.isKeyPressed(ImGuiKey.LeftArrow)) nx -= step;
			if (ImGui.isKeyPressed(ImGuiKey.RightArrow)) nx += step;
			if (ImGui.isKeyPressed(ImGuiKey.UpArrow)) ny -= step;
			if (ImGui.isKeyPressed(ImGuiKey.DownArrow)) ny += step;
			if (nx != 0 || ny != 0) {
				// One undo step per burst of nudges.
				var now = haxe.Timer.stamp();
				if (now - canvasNudgeStamp > 0.75) host.canvasSnapshot("Canvas Nudge");
				canvasNudgeStamp = now;
				for (i in picks) if (!els[i].locked) { setX(els[i], els[i].xAt(editState) + nx); setY(els[i], els[i].yAt(editState) + ny); }
				SettingsStore.markDirty();
			}
			if (ImGui.isKeyPressed(ImGuiKey.Delete, false)) removeSelected(a);
			else if (ctrl && ImGui.isKeyPressed(ImGuiKey.D, false)) duplicateSelected(a);
		}
		if ((focused || hovered) && !active && ctrl && ImGui.isKeyPressed(ImGuiKey.A, false) && els.length > 0)
			selectIndices([for (i in 0...els.length) i]);
		if (hovered && !active && !ImGui.isAnyItemActive()) {
			if (ImGui.isKeyPressed(ImGuiKey.Equal, false) || ImGui.isKeyPressed(ImGuiKey.KeypadAdd, false)) zoomAbout(1.25, mx, my, ox, oy, s, fit);
			if (ImGui.isKeyPressed(ImGuiKey.Minus, false) || ImGui.isKeyPressed(ImGuiKey.KeypadSubtract, false)) zoomAbout(0.8, mx, my, ox, oy, s, fit);
			if (ImGui.isKeyPressed(ImGuiKey._0, false)) resetView();
		}

		var hoverIndex = -1;
		var hoverHandle = -1;
		if (hovered && !active && canvasDragMode == CANVAS_DRAG_NONE) {
			var sel = canvasSel >= 0 && canvasSel < els.length ? els[canvasSel] : null;
			hoverHandle = tool == TOOL_SELECT ? canvasHandleAt(a, sel, mx, my, s) : -1;
			hoverIndex = hoverHandle >= 0 ? canvasSel : canvasHitTest(a, mx, my);
		}
		if (canvasDragMode == DRAG_PAN) {}
		else if (hoverHandle == H_ROTATE || (active && canvasDragMode == DRAG_ROTATE)) ImGui.setMouseCursor(imgui.Enums.ImGuiMouseCursor.Hand);
		else if (hoverHandle >= 0) ImGui.setMouseCursor(handleCursor(hoverHandle));
		else if (active && canvasDragMode == CANVAS_DRAG_SIZE) ImGui.setMouseCursor(handleCursor(dragHandle));
		else if (hoverIndex >= 0 || (active && canvasDragMode == CANVAS_DRAG_MOVE)) ImGui.setMouseCursor(imgui.Enums.ImGuiMouseCursor.ResizeAll);
		if (hovered && ImGui.isMouseClicked(1)) {
			var hit = canvasHitTest(a, mx, my);
			if (hit >= 0 && !isSelected(hit)) selectOnly(hit);
			if (hit >= 0) ImGui.openPopup("##ab_cv_ctx");
		}

		var dl = ImGui.getWindowDrawList();
		var stageMax = ImGui.vec2(origin.x + availW, origin.y + stageH);
		ImGui.ImDrawList_PushClipRect(dl, origin, stageMax, true);
		try {
			drawStageBackground(dl, origin, stageMax, theme.windowBg);
			// Light 16 px grid inside the aura bounds when it is readable at this zoom.
			var gridStep:Float = Math.max(8, snapStep * 4);
			if (showGrid.get() && gridStep * s >= 6) {
				var gridCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(theme.border.x, theme.border.y, theme.border.z, 0.35));
				var gx = gridStep;
				while (gx < auraW) {
					ImGui.ImDrawList_AddLineV(dl, ox + gx * s, oy, oy + auraH * s, gridCol);
					gx += gridStep;
				}
				var gy = gridStep;
				while (gy < auraH) {
					ImGui.ImDrawList_AddLineH(dl, ox, ox + auraW * s, oy + gy * s, gridCol);
					gy += gridStep;
				}
			}
			ImGui.ImDrawList_AddRect(dl, ImGui.vec2(ox, oy), ImGui.vec2(ox + auraW * s, oy + auraH * s),
				ImGui.colorConvertFloat4ToU32(theme.border), 0, 1);
			AuraVisualRenderer.draw(dl, a, ox, oy, auraW * s, auraH * s, preview.gaugeProgress(a),
				preview.stacks.get(), preview.counter.get(), false, 1, s, null, null, editAll);
			var accent = ImGui.colorConvertFloat4ToU32(theme.accent);
			var faint = ImGui.colorConvertFloat4ToU32(ImGui.vec4(theme.accent.x, theme.accent.y, theme.accent.z, 0.45));
			if (showBounds.get()) for (el in els) if (el != null && el.visible(editAll, editState)) outlineElement(dl, a, el, ox, oy, s, faint, 1);
			if (hoverIndex >= 0 && !isSelected(hoverIndex) && els[hoverIndex] != null) outlineElement(dl, a, els[hoverIndex], ox, oy, s, faint, 1);
			if (!Math.isNaN(guideX)) ImGui.ImDrawList_AddLineV(dl, ox + guideX * s, origin.y, origin.y + stageH, 0xFFFF40C0);
			if (!Math.isNaN(guideY)) ImGui.ImDrawList_AddLineH(dl, origin.x, origin.x + availW, oy + guideY * s, 0xFFFF40C0);
			var picks = selectedIndices();
			for (i in picks) if (i < els.length && els[i] != null) outlineElement(dl, a, els[i], ox, oy, s, accent, i == canvasSel ? 1.5 : 1);
			var sel = canvasSel >= 0 && canvasSel < els.length ? els[canvasSel] : null;
			if (sel != null && canvasMulti.length == 0 && !sel.locked && sel.visible(editAll, editState) && tool != TOOL_NODES && tool != TOOL_PEN) drawHandles(dl, a, sel, ox, oy, s, accent);
			if (tool == TOOL_NODES) { var pl = pathLayer(a); if (pl != null) drawPathOverlay(dl, a, pl, ox, oy, s, accent, false, hovered, mx, my); }
			if (tool == TOOL_PEN && penEl != null) drawPathOverlay(dl, a, penEl, ox, oy, s, accent, true, hovered, mx, my);
			var carrying = ImGui.getDragDropPayload();
			if (carrying != null && ImGui.ImGuiPayload_IsDataType(carrying, ImageLibraryPanel.PAYLOAD_IMAGE)) {
				ImGui.ImDrawList_AddRect(dl, ImGui.vec2(origin.x + 2, origin.y + 2), ImGui.vec2(stageMax.x - 2, stageMax.y - 2), accent, 4, 2);
				ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(origin.x + 12, origin.y + 10), accent, "Drop to add this image");
			}
			if (canvasDragMode == DRAG_MARQUEE) {
				var mnx = Math.min(marqueeX0, marqueeX1), mny = Math.min(marqueeY0, marqueeY1);
				var mxx = Math.max(marqueeX0, marqueeX1), mxy = Math.max(marqueeY0, marqueeY1);
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(ox + mnx * s, oy + mny * s), ImGui.vec2(ox + mxx * s, oy + mxy * s),
					ImGui.colorConvertFloat4ToU32(ImGui.vec4(theme.accent.x, theme.accent.y, theme.accent.z, 0.12)), 0);
				ImGui.ImDrawList_AddRect(dl, ImGui.vec2(ox + mnx * s, oy + mny * s), ImGui.vec2(ox + mxx * s, oy + mxy * s), accent, 0, 1);
			}
		} catch (e:Dynamic) { ImGui.ImDrawList_PopClipRect(dl); throw e; }
		ImGui.ImDrawList_PopClipRect(dl);

		if (ImGui.beginPopup("##ab_cv_ctx")) {
			try drawCanvasContextMenu(a) catch (e:Dynamic) { ImGui.endPopup(); throw e; }
			ImGui.endPopup();
		}
	}

	function drawStageBackground(dl:Dynamic, min:Dynamic, max:Dynamic, dark:Dynamic):Void {
		switch (stageBg) {
			case 1: ImGui.ImDrawList_AddRectFilled(dl, min, max, ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.38, 0.38, 0.4, 1)), 4);
			case 2: ImGui.ImDrawList_AddRectFilled(dl, min, max, ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.86, 0.87, 0.9, 1)), 4);
			case 3:
				ImGui.ImDrawList_AddRectFilled(dl, min, max, ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.32, 0.32, 0.34, 1)), 4);
				var light = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.46, 0.46, 0.48, 1));
				var size = 16.0;
				var rows = Std.int(Math.ceil((max.y - min.y) / size)), cols = Std.int(Math.ceil((max.x - min.x) / size));
				for (r in 0...rows) for (c in 0...cols) if ((r + c) % 2 == 0)
					ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(min.x + c * size, min.y + r * size),
						ImGui.vec2(Math.min(max.x, min.x + (c + 1) * size), Math.min(max.y, min.y + (r + 1) * size)), light, 0);
			default: ImGui.ImDrawList_AddRectFilled(dl, min, max, ImGui.colorConvertFloat4ToU32(dark), 4);
		}
	}

	/** New image layer centred on the drop point. */
	function dropImage(a:AuraDef, stem:String, mx:Float, my:Float, snap:Bool):Void {
		var size = 48.0;
		var el = AuraCanvasElement.icon(CustomImages.key(stem), canvasSnapValue(mx - size * 0.5, snap), canvasSnapValue(my - size * 0.5, snap), size, size);
		// Dropping onto a look other than Default still creates a layer shared by every look.
		addCanvasElement(a, el, "Canvas Add Image", false);
		GameIcons.get(el.content);
	}

	function zoomAbout(factor:Float, mx:Float, my:Float, ox:Float, oy:Float, s:Float, fit:Float):Void {
		var nz = Math.max(0.25, Math.min(16, zoom * factor));
		var ns = Math.max(0.1, Math.min(24, fit * nz));
		// Keep the point under the cursor fixed: origin shifts by the change in its scaled offset.
		panX += mx * s - mx * ns; panY += my * s - my * ns;
		panX = Math.max(-4000, Math.min(4000, panX)); panY = Math.max(-4000, Math.min(4000, panY));
		zoom = nz;
	}

	/** Aura-local AABB of an element, rotation included (editor hit tests and outlines). */
	function elementBounds(a:AuraDef, el:AuraCanvasElement):{x:Float, y:Float, w:Float, h:Float} {
		canvasBox(a, el);
		if (rotatable(el) && el.rotationAt(editState) != 0) {
			var e = AuraCanvasElement.rotatedHalfExtent(cvBoxW, cvBoxH, el.rotationAt(editState));
			return {x: cvBoxX + cvBoxW * 0.5 - e.hx, y: cvBoxY + cvBoxH * 0.5 - e.hy, w: e.hx * 2, h: e.hy * 2};
		}
		return {x: cvBoxX, y: cvBoxY, w: cvBoxW, h: cvBoxH};
	}

	function outlineElement(dl:Dynamic, a:AuraDef, el:AuraCanvasElement, ox:Float, oy:Float, s:Float, col:Int, thick:Float):Void {
		canvasBox(a, el);
		var x0 = ox + cvBoxX * s, y0 = oy + cvBoxY * s, x1 = ox + (cvBoxX + cvBoxW) * s, y1 = oy + (cvBoxY + cvBoxH) * s;
		if (rotatable(el) && el.rotationAt(editState) != 0) {
			var cx = (x0 + x1) * 0.5, cy = (y0 + y1) * 0.5;
			var p0 = rotatedPoint(x0, y0, cx, cy, el.rotationAt(editState)), p1 = rotatedPoint(x1, y0, cx, cy, el.rotationAt(editState));
			var p2 = rotatedPoint(x1, y1, cx, cy, el.rotationAt(editState)), p3 = rotatedPoint(x0, y1, cx, cy, el.rotationAt(editState));
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(p0.x, p0.y), ImGui.vec2(p1.x, p1.y), col, thick);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(p1.x, p1.y), ImGui.vec2(p2.x, p2.y), col, thick);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(p2.x, p2.y), ImGui.vec2(p3.x, p3.y), col, thick);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(p3.x, p3.y), ImGui.vec2(p0.x, p0.y), col, thick);
		} else ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x0 - 1, y0 - 1), ImGui.vec2(x1 + 1, y1 + 1), col, 2, thick);
	}

	function drawHandles(dl:Dynamic, a:AuraDef, el:AuraCanvasElement, ox:Float, oy:Float, s:Float, col:Int):Void {
		canvasBox(a, el);
		var hs:Single = CANVAS_HANDLE_PX * 0.5;
		if (el.kind != AuraCanvasElement.KIND_TEXT && el.rotationAt(editState) == 0) {
			for (h in 0...8) {
				var p = handlePos(h);
				var px:Single = ox + p.x * s, py:Single = oy + p.y * s;
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(px - hs, py - hs), ImGui.vec2(px + hs, py + hs), col, 1);
			}
		}
		if (rotatable(el)) {
			var cx = cvBoxX + cvBoxW * 0.5, cy = cvBoxY + cvBoxH * 0.5;
			var top = rotatedPoint(cx, cvBoxY, cx, cy, el.rotationAt(editState));
			var knob = rotatedPoint(cx, cvBoxY - ROTATE_STEM_PX / s, cx, cy, el.rotationAt(editState));
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(ox + top.x * s, oy + top.y * s), ImGui.vec2(ox + knob.x * s, oy + knob.y * s), col, 1);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(ox + knob.x * s, oy + knob.y * s), CANVAS_HANDLE_PX * 0.6, col, 16);
		}
	}

	function applyMarquee(a:AuraDef, editAll:Bool):Void {
		var x0 = Math.min(marqueeX0, marqueeX1), y0 = Math.min(marqueeY0, marqueeY1);
		var x1 = Math.max(marqueeX0, marqueeX1), y1 = Math.max(marqueeY0, marqueeY1);
		if (x1 - x0 < 2 && y1 - y0 < 2) return;
		var list = marqueeAdditive ? selectedIndices() : [];
		for (i in 0...a.canvasElements.length) {
			var el = a.canvasElements[i];
			if (el == null || el.locked || !el.visible(editAll, editState) || list.indexOf(i) >= 0) continue;
			var b = elementBounds(a, el);
			if (b.x <= x1 && b.x + b.w >= x0 && b.y <= y1 && b.y + b.h >= y0) list.push(i);
		}
		selectIndices(list);
	}

	function removeSelected(a:AuraDef):Void {
		var picks = selectedIndices();
		if (picks.length == 0) return;
		host.canvasSnapshot("Canvas Delete");
		var i = picks.length - 1;
		while (i >= 0) {
			var idx = picks[i];
			if (idx >= 0 && idx < a.canvasElements.length) {
				canvasRuleContexts.remove(a.canvasElements[idx]);
				canvasRowIds.remove(a.canvasElements[idx]);
				a.canvasElements.splice(idx, 1);
			}
			i--;
		}
		a.sizeDirty = true;
		selectOnly(-1);
		SettingsStore.markDirty();
	}

	function duplicateSelected(a:AuraDef):Void {
		var picks = selectedIndices();
		if (picks.length == 0) return;
		host.canvasSnapshot("Canvas Duplicate");
		var created:Array<Int> = [];
		var shift = 0;
		for (idx in picks) {
			if (a.canvasElements[idx] == null) continue;
			var copy = AuraCanvasElement.fromDyn(a.canvasElements[idx].toObj());
			setX(copy, copy.xAt(editState) + 8); setY(copy, copy.yAt(editState) + 8); copy.locked = false;
			var at = idx + 1 + shift;
			a.canvasElements.insert(at, copy);
			// Earlier inserts push later indices down by one; keep the earlier copies in step.
			for (k in 0...created.length) if (created[k] >= at) created[k]++;
			created.push(at);
			shift++;
		}
		AuraCanvasGroups.separate(a.canvasElements, created);
		selectIndices(created);
		SettingsStore.markDirty();
	}

	/** Align the selection to its own bounds; "distH"/"distV" spread three or more evenly. */
	function alignSelection(a:AuraDef, mode:String):Void {
		var picks = selectedIndices().filter(function(i) return a.canvasElements[i] != null && !a.canvasElements[i].locked);
		if (picks.length < 2) return;
		host.canvasSnapshot("Canvas Align");
		var minX = 1e9, minY = 1e9, maxX = -1e9, maxY = -1e9;
		var boxes = [for (i in picks) elementBounds(a, a.canvasElements[i])];
		for (b in boxes) { minX = Math.min(minX, b.x); minY = Math.min(minY, b.y); maxX = Math.max(maxX, b.x + b.w); maxY = Math.max(maxY, b.y + b.h); }
		if (mode == "distH" || mode == "distV") {
			if (picks.length < 3) return;
			var order = [for (k in 0...picks.length) k];
			var horizontal = mode == "distH";
			order.sort(function(p, q) return horizontal ? Std.int(boxes[p].x - boxes[q].x) : Std.int(boxes[p].y - boxes[q].y));
			var total = 0.0;
			for (b in boxes) total += horizontal ? b.w : b.h;
			var gap = ((horizontal ? maxX - minX : maxY - minY) - total) / (picks.length - 1);
			var cursor = horizontal ? minX : minY;
			for (k in order) {
				var el = a.canvasElements[picks[k]], b = boxes[k];
				if (horizontal) setX(el, Math.round(el.xAt(editState) + (cursor - b.x))); else setY(el, Math.round(el.yAt(editState) + (cursor - b.y)));
				cursor += (horizontal ? b.w : b.h) + gap;
			}
		} else {
			for (k in 0...picks.length) {
				var el = a.canvasElements[picks[k]], b = boxes[k];
				switch (mode) {
					case "left": setX(el, Math.round(el.xAt(editState) + (minX - b.x)));
					case "centerH": setX(el, Math.round(el.xAt(editState) + ((minX + maxX) * 0.5 - (b.x + b.w * 0.5))));
					case "right": setX(el, Math.round(el.xAt(editState) + (maxX - (b.x + b.w))));
					case "top": setY(el, Math.round(el.yAt(editState) + (minY - b.y)));
					case "middleV": setY(el, Math.round(el.yAt(editState) + ((minY + maxY) * 0.5 - (b.y + b.h * 0.5))));
					case "bottom": setY(el, Math.round(el.yAt(editState) + (maxY - (b.y + b.h))));
					default:
				}
			}
		}
		SettingsStore.markDirty();
	}


	function drawCanvasContextMenu(a:AuraDef):Void {
		var n = a.canvasElements.length;
		if (canvasSel < 0 || canvasSel >= n || a.canvasElements[canvasSel] == null) {
			ImGui.closeCurrentPopup();
			return;
		}
		var el = a.canvasElements[canvasSel];
		if (ImGui.menuItem("Duplicate", "Ctrl+D")) duplicateSelectedOrOne(a);
		ImGui.separator();
		if (ImGui.beginMenu("Align")) {
			try drawAlignMenu(a, el) catch (e:Dynamic) { ImGui.endMenu(); throw e; }
			ImGui.endMenu();
		}
		if (canvasMulti.length > 0 && ImGui.menuItem("Group##cv_ctx_group", "Ctrl+G")) groupSelected(a);
		if (selectionHasGroup(a) && ImGui.menuItem("Ungroup##cv_ctx_ungroup", "Ctrl+Shift+G")) ungroupSelected(a);
		ImGui.separator();
		if (ImGui.menuItem("Bring to front", null, false, canvasSel < n - 1)) moveCanvasElement(a, canvasSel, n - 1, "Canvas To Front");
		if (ImGui.menuItem("Bring forward", null, false, canvasSel < n - 1)) moveCanvasElement(a, canvasSel, canvasSel + 1, "Canvas Bring Forward");
		if (ImGui.menuItem("Send backward", null, false, canvasSel > 0)) moveCanvasElement(a, canvasSel, canvasSel - 1, "Canvas Send Backward");
		if (ImGui.menuItem("Send to back", null, false, canvasSel > 0)) moveCanvasElement(a, canvasSel, 0, "Canvas To Back");
		ImGui.separator();
		if (ImGui.menuItem(el.hiddenAt(editState) ? "Show" : "Hide")) { host.canvasSnapshot("Canvas Visibility"); setHidden(el, !el.hiddenAt(editState)); SettingsStore.markDirty(); }
		if (ImGui.menuItem(el.locked ? "Unlock" : "Lock")) { host.canvasSnapshot("Canvas Lock"); el.locked = !el.locked; SettingsStore.markDirty(); }
		ImGui.separator();
		if (ImGui.menuItem("Delete", "Del")) removeSelected(a);
	}

	function duplicateSelectedOrOne(a:AuraDef):Void {
		if (canvasMulti.length > 0) duplicateSelected(a); else duplicateCanvasElement(a, canvasSel);
	}

	static var ALIGN_ROWS:Array<{label:String, mode:String}> = [
		{label: "Left", mode: "left"}, {label: "Center", mode: "centerH"}, {label: "Right", mode: "right"},
		{label: "Top", mode: "top"}, {label: "Middle", mode: "middleV"}, {label: "Bottom", mode: "bottom"}
	];

	/** One layer aligns to the aura; several align to each other's bounds. */
	function drawAlignMenu(a:AuraDef, el:AuraCanvasElement):Void {
		var several = canvasMulti.length > 0;
		ImGui.textDisabled(several ? "To the selection" : "To the aura");
		for (i in 0...ALIGN_ROWS.length) {
			if (i == 3) ImGui.separator();
			var row = ALIGN_ROWS[i];
			if (ImGui.menuItem(row.label + "##cv_ctx_al_" + row.mode)) alignContext(a, el, row.mode);
		}
		if (several) {
			ImGui.separator();
			if (ImGui.menuItem("Space across##cv_ctx_dh", null, false, canvasMulti.length >= 2)) alignSelection(a, "distH");
			if (ImGui.menuItem("Space down##cv_ctx_dv", null, false, canvasMulti.length >= 2)) alignSelection(a, "distV");
		} else if (el.kind != AuraCanvasElement.KIND_TEXT) {
			ImGui.separator();
			if (ImGui.menuItem("Fill aura##cv_ctx_fill")) {
				var auraW = a.w.get() > 1 ? a.w.get() : 96, auraH = a.h.get() > 1 ? a.h.get() : 96;
				host.canvasSnapshot("Canvas Fill");
				setX(el, 0); setY(el, 0); setW(el, auraW); setH(el, auraH);
				SettingsStore.markDirty();
			}
		}
	}

	function alignContext(a:AuraDef, el:AuraCanvasElement, mode:String):Void {
		if (canvasMulti.length > 0) { alignSelection(a, mode); return; }
		var auraW = a.w.get() > 1 ? a.w.get() : 96, auraH = a.h.get() > 1 ? a.h.get() : 96;
		var b = elementBounds(a, el);
		var dx = 0.0, dy = 0.0;
		switch (mode) {
			case "left": dx = -b.x;
			case "centerH": dx = (auraW - b.w) * 0.5 - b.x;
			case "right": dx = auraW - b.w - b.x;
			case "top": dy = -b.y;
			case "middleV": dy = (auraH - b.h) * 0.5 - b.y;
			case "bottom": dy = auraH - b.h - b.y;
			default:
		}
		host.canvasSnapshot("Canvas Align");
		setX(el, Math.round(el.xAt(editState) + dx));
		setY(el, Math.round(el.yAt(editState) + dy));
		SettingsStore.markDirty();
	}

	static inline var PAYLOAD_LAYER:String = "CV_LAYER";
	var lastLayerRow:Int = -1;

	/** Hover card for a layer: artwork preview plus its placement in the look being edited. */
	function drawLayerTooltip(a:AuraDef, el:AuraCanvasElement):Void {
		if (el.kind == AuraCanvasElement.KIND_ICON) {
			var id = el.content != null && el.content.length > 0 ? el.content : a.preferredIconId();
			if (!GameIcons.imageKey(id, 48, 48)) ImGui.dummy(ImGui.vec2(48, 48));
			ImGui.sameLine(0, 8);
		}
		ImGui.beginGroup();
		ImGui.text(canvasLayerLabel(el));
		var b = elementBounds(a, el);
		ImGui.textDisabled("x " + Math.round(b.x) + ", y " + Math.round(b.y) + "   " + Math.round(b.w) + " x " + Math.round(b.h));
		ImGui.textDisabled("Opacity " + Math.round(el.opacityAt(editState) * 100) + "%" + (el.rotationAt(editState) != 0 ? "   Rotation " + Math.round(el.rotationAt(editState)) + " deg" : ""));
		if (el.inStates != null) ImGui.textDisabled("Shown in: " + [for (id in el.inStates) stateLabel(a, id)].join(", "));
		if (el.ov(editState) != null) ImGui.textDisabled("Overridden in this look");
		ImGui.endGroup();
	}

	/** Layers that turn about their centre: plates and vector paths. */
	static inline function rotatable(el:AuraCanvasElement):Bool return el.kind == AuraCanvasElement.KIND_SHAPE || el.kind == AuraCanvasElement.KIND_PATH;

	function canvasLayerLabel(el:AuraCanvasElement):String {
		var kind = el.kind == AuraCanvasElement.KIND_SHAPE ? "Shape"
			: el.kind == AuraCanvasElement.KIND_PATH ? "Path"
			: (el.kind == AuraCanvasElement.KIND_ICON ? (el.isCustomImage() ? "Image" : "Icon") : "Text");
		var body = el.name != null && el.name.length > 0 ? el.name : (el.isCustomImage() ? CustomImages.stemOf(el.content) : el.content);
		if (body == null || body.length == 0) body = "(empty)";
		if (body.length > 28) body = body.substr(0, 27) + "...";
		return kind + "  " + body + (el.visibilityRule != null ? (el.visibilityResult.known ? (el.visibilityResult.hit ? "  (condition true)" : "  (condition false)") : "  (condition unknown)") : "") + (el.hiddenAt(editState) ? "  (hidden)" : "") + (!el.inState(editState) ? "  (not in this look)" : "") + (el.locked ? "  (locked)" : "");
	}

	/** Topmost layer first. The remove button gets its own fixed cell so the row never covers it. */
	function drawCanvasLayers(a:AuraDef):Void {
		if(canvasRowOwner!=a) { canvasRowOwner=a; canvasRowIds=new haxe.ds.ObjectMap<AuraCanvasElement,Int>(); canvasRuleContexts = new haxe.ds.ObjectMap(); }
		var els = a.canvasElements;
		if (els.length == 0) return;
		UiChrome.gap(4);
		builderSectionHeader("Layers");
		var rowH:Single = ImGui.getTextLineHeight() + 4;
		var delW:Single = 24;
		var removeAt = -1;
		var dropFrom = -1;
		var dropTo = -1;
		var i = els.length - 1;
		while (i >= 0) {
			var el = els[i];
			// A run of layers sharing a group name starts with a header; folded groups hide their rows.
			if (el != null && el.group.length > 0 && (i == els.length - 1 || els[i + 1] == null || els[i + 1].group != el.group)) {
				var lo = i;
				while (lo - 1 >= 0 && els[lo - 1] != null && els[lo - 1].group == el.group) lo--;
				drawGroupHeader(a, el.group, lo, i, rowH, delW);
				if (groupFolded.get(el.group) == true) { i = lo - 1; continue; }
			}
			// Long lists only lay out the rows that are on screen.
			if (!ImGui.isRectVisible(ImGui.vec2(ImGui.getContentRegionAvail().x, rowH))) { ImGui.dummy(ImGui.vec2(1, rowH)); i--; continue; }
			var nested = el != null && el.group.length > 0;
			if (nested) ImGui.indent(14);
			if (el != null) {
				if(!canvasRowIds.exists(el)) canvasRowIds.set(el,nextCanvasRowId++);
				ImGui.pushID_Int(canvasRowIds.get(el));
				var w:Single = Math.max(1, ImGui.getContentRegionAvail().x - delW * 3 - 12);
				if (el.hiddenAt(editState)) ImGui.pushStyleColor(ImGuiCol.Text, solarflare.ui.ThemePalette.current().textDisabled);
				var picked = ImGui.selectable(canvasLayerLabel(el) + "###ab_cv_row", isSelected(i), 0, ImGui.vec2(w, rowH));
				if (el.hiddenAt(editState)) ImGui.popStyleColor();
				if (picked) {
					var ctrlDown = ImGui.isKeyDown(ImGuiKey.LeftCtrl) || ImGui.isKeyDown(ImGuiKey.RightCtrl);
					var shiftDown = ImGui.isKeyDown(ImGuiKey.LeftShift) || ImGui.isKeyDown(ImGuiKey.RightShift);
					if (shiftDown && lastLayerRow >= 0 && lastLayerRow < els.length) {
						var lo = Std.int(Math.min(lastLayerRow, i)), hi = Std.int(Math.max(lastLayerRow, i));
						selectIndices([for (k in lo...hi + 1) if (els[k] != null) k]);
					} else if (ctrlDown) toggleSelect(i); else selectOnly(i);
					lastLayerRow = i;
				}
				if (ImGui.isItemClicked(imgui.Enums.ImGuiMouseButton.Right)) {
					if (!isSelected(i)) selectOnly(i);
					ImGui.openPopup("##cv_layer_ctx");
				}
				if (ImGui.isItemHovered(imgui.Enums.ImGuiHoveredFlags.DelayNormal) && ImGui.beginTooltip()) {
					try drawLayerTooltip(a, el) catch (e:Dynamic) { ImGui.endTooltip(); throw e; }
					ImGui.endTooltip();
				}
				if (ImGui.beginDragDropSource(0)) {
					var payload = haxe.io.Bytes.ofString(Std.string(i));
					ImGui.setDragDropPayload(PAYLOAD_LAYER, payload.getData(), payload.length + 1);
					ImGui.text("Move layer: " + canvasLayerLabel(el));
					ImGui.endDragDropSource();
				}
				if (ImGui.beginDragDropTarget()) {
					var dropped = ImGui.acceptDragDropPayload(PAYLOAD_LAYER);
					if (dropped != null && ImGui.ImGuiPayload_IsDataType(dropped, PAYLOAD_LAYER)) { dropFrom = PayloadExt.getInt(dropped); dropTo = i; }
					ImGui.endDragDropTarget();
				}
				ImGui.sameLine(0, 4);
				var hid = el.hiddenAt(editState);
				if (UiChrome.ghostButton((hid ? "-" : "o") + "##ab_cv_eye", ImGui.vec2(delW, rowH))) { host.canvasSnapshot("Canvas Visibility"); setHidden(el, !hid); SettingsStore.markDirty(); }
				if (ImGui.isItemHovered()) ImGui.setTooltip(hid ? "Hidden. Click to show this layer." : "Visible. Click to hide this layer.");
				ImGui.sameLine(0, 4);
				if (UiChrome.ghostButton((el.locked ? "L" : ".") + "##ab_cv_lockbtn", ImGui.vec2(delW, rowH))) { host.canvasSnapshot("Canvas Lock"); el.locked = !el.locked; SettingsStore.markDirty(); }
				if (ImGui.isItemHovered()) ImGui.setTooltip(el.locked ? "Locked: ignores stage clicks. Click to unlock." : "Click to lock so it cannot be moved by accident.");
				ImGui.sameLine(0, 4);
				if (UiChrome.ghostButton("x##ab_cv_delete", ImGui.vec2(delW, rowH))) removeAt = i;
				if (ImGui.isItemHovered()) ImGui.setTooltip("Remove this element");
				ImGui.popID();
			}
			if (nested) ImGui.unindent(14);
			i--;
		}
		if (ImGui.beginPopup("##cv_group_ctx")) {
			try drawGroupMenu(a) catch (e:Dynamic) { ImGui.endPopup(); throw e; }
			ImGui.endPopup();
		}
		if (ImGui.beginPopup("##cv_layer_ctx")) {
			try drawCanvasContextMenu(a) catch (e:Dynamic) { ImGui.endPopup(); throw e; }
			ImGui.endPopup();
		}
		if (removeAt >= 0) removeCanvasElement(a, removeAt);
		else if (dropFrom >= 0 && dropTo >= 0 && dropFrom != dropTo) moveCanvasElement(a, dropFrom, dropTo, "Canvas Reorder");
	}

	// ---- Groups ------------------------------------------------------------------------------

	var groupFolded = new Map<String, Bool>();
	var groupMenuFor:String = "";
	var renamingGroup:String = "";
	var groupNameBuf = new hl.Bytes(AuraCanvasGroups.MAX_NAME * 4);
	var groupScale = new FloatRef(100);

	function selectGroupOf(a:AuraDef, hit:Int, single:Bool):Void {
		var el = a.canvasElements[hit];
		if (single || el == null || el.group.length == 0) { selectOnly(hit); return; }
		canvasSel = hit;
		canvasMulti = [for (k in AuraCanvasGroups.members(a.canvasElements, el.group)) if (k != hit) k];
	}

	function groupSelected(a:AuraDef):Void {
		var picks = selectedIndices();
		if (picks.length < 2) { solarflare.ui.ToastManager.info("Select two or more layers to group them."); return; }
		host.canvasSnapshot("Group Layers");
		var block = AuraCanvasGroups.group(a.canvasElements, picks, AuraCanvasGroups.uniqueName(a.canvasElements));
		if (block.length > 0) selectIndices(block);
		SettingsStore.markDirty();
	}

	function selectionHasGroup(a:AuraDef):Bool {
		for (i in selectedIndices()) if (i < a.canvasElements.length && a.canvasElements[i] != null && a.canvasElements[i].group.length > 0) return true;
		return false;
	}

	function ungroupSelected(a:AuraDef):Void {
		if (!selectionHasGroup(a)) return;
		host.canvasSnapshot("Ungroup Layers");
		AuraCanvasGroups.ungroup(a.canvasElements, selectedIndices());
		SettingsStore.markDirty();
	}

	function scaleSelectedBy(a:AuraDef, factor:Float):Void {
		if (editState != "") { solarflare.ui.ToastManager.info("Scale the Default look: switch Look to Default first."); return; }
		host.canvasSnapshot("Scale Layers");
		AuraCanvasGroups.scale(a.canvasElements, selectedIndices(), factor, auraBoxW(a), auraBoxH(a));
		a.sizeDirty = true;
		SettingsStore.markDirty();
	}

	/** One row for a group: fold arrow, name, and visibility / lock / delete for every layer in it. */
	function drawGroupHeader(a:AuraDef, name:String, lo:Int, hi:Int, rowH:Single, delW:Single):Void {
		var els = a.canvasElements;
		var folded = groupFolded.get(name) == true;
		var members = [for (k in lo...hi + 1) k];
		var allSelected = true, anyHidden = false, anyLocked = false;
		for (k in members) { if (!isSelected(k)) allSelected = false; if (els[k].hiddenAt(editState)) anyHidden = true; if (els[k].locked) anyLocked = true; }
		ImGui.pushID_Str("cv_grp_" + name);
		if (UiChrome.ghostButton((folded ? "+" : "-") + "##cv_grp_fold", ImGui.vec2(delW, rowH))) groupFolded.set(name, !folded);
		if (ImGui.isItemHovered()) ImGui.setTooltip(folded ? "Show this group's layers" : "Fold this group's layers");
		ImGui.sameLine(0, 4);
		var w:Single = Math.max(1, ImGui.getContentRegionAvail().x - delW * 3 - 12);
		if (renamingGroup == name) {
			ImGui.setNextItemWidth(w);
			if (ImGui.isWindowAppearing() || !ImGui.isAnyItemActive()) ImGui.setKeyboardFocusHere();
			var enter = ImGui.inputText("##cv_grp_rename", groupNameBuf, AuraCanvasGroups.MAX_NAME * 4, imgui.Enums.ImGuiInputTextFlags.EnterReturnsTrue);
			if (enter) {
				var next = ByteUtil.readBytes(groupNameBuf, AuraCanvasGroups.MAX_NAME * 4);
				host.canvasSnapshot("Rename Group");
				if (AuraCanvasGroups.rename(els, name, next)) { var key = AuraCanvasGroups.clean(next); if (folded) { groupFolded.remove(name); groupFolded.set(key, true); } SettingsStore.markDirty(); }
				else solarflare.ui.ToastManager.warn("Pick a name that is not already used.");
				renamingGroup = "";
			} else if (ImGui.isKeyPressed(ImGuiKey.Escape, false)) renamingGroup = "";
		} else {
			if (allSelected) ImGui.pushStyleColor(ImGuiCol.Text, solarflare.ui.ThemePalette.current().accent);
			var clicked = ImGui.selectable("[group] " + name + "  (" + members.length + ")###cv_grp_row", allSelected, 0, ImGui.vec2(w, rowH));
			if (allSelected) ImGui.popStyleColor();
			if (clicked) { selectIndices(members); lastLayerRow = hi; }
			if (ImGui.isItemHovered() && ImGui.isMouseDoubleClicked(0)) { renamingGroup = name; ByteUtil.fillBuf(groupNameBuf, AuraCanvasGroups.MAX_NAME * 4, name); }
			if (ImGui.isItemClicked(imgui.Enums.ImGuiMouseButton.Right)) { selectIndices(members); groupMenuFor = name; ImGui.openPopup("##cv_group_ctx"); }
			if (ImGui.isItemHovered()) ImGui.setTooltip("Click selects the whole group. Double-click renames. Right-click for more.");
		}
		ImGui.sameLine(0, 4);
		if (UiChrome.ghostButton((anyHidden ? "-" : "o") + "##cv_grp_eye", ImGui.vec2(delW, rowH))) {
			host.canvasSnapshot("Canvas Visibility");
			for (k in members) setHidden(els[k], !anyHidden);
			SettingsStore.markDirty();
		}
		if (ImGui.isItemHovered()) ImGui.setTooltip(anyHidden ? "Show every layer in the group" : "Hide every layer in the group");
		ImGui.sameLine(0, 4);
		if (UiChrome.ghostButton((anyLocked ? "L" : ".") + "##cv_grp_lock", ImGui.vec2(delW, rowH))) {
			host.canvasSnapshot("Canvas Lock");
			for (k in members) els[k].locked = !anyLocked;
			SettingsStore.markDirty();
		}
		if (ImGui.isItemHovered()) ImGui.setTooltip(anyLocked ? "Unlock the whole group" : "Lock the whole group");
		ImGui.sameLine(0, 4);
		if (UiChrome.ghostButton("x##cv_grp_del", ImGui.vec2(delW, rowH))) { selectIndices(members); removeSelected(a); }
		if (ImGui.isItemHovered()) ImGui.setTooltip("Delete the group and its layers");
		ImGui.popID();
	}

	function drawGroupMenu(a:AuraDef):Void {
		var name = groupMenuFor;
		if (name.length == 0) { ImGui.closeCurrentPopup(); return; }
		if (ImGui.menuItem("Rename##cv_gm_rename")) { renamingGroup = name; ByteUtil.fillBuf(groupNameBuf, AuraCanvasGroups.MAX_NAME * 4, name); }
		if (ImGui.menuItem("Select layers##cv_gm_select")) selectIndices(AuraCanvasGroups.members(a.canvasElements, name));
		if (ImGui.menuItem("Duplicate group##cv_gm_dup")) { selectIndices(AuraCanvasGroups.members(a.canvasElements, name)); duplicateSelected(a); }
		ImGui.separator();
		if (ImGui.menuItem("Ungroup##cv_gm_ungroup")) { selectIndices(AuraCanvasGroups.members(a.canvasElements, name)); ungroupSelected(a); }
	}

	function drawCanvasProperties(a:AuraDef, el:AuraCanvasElement):Void {
		UiChrome.gap(4);
		builderSectionHeader(el.kind == AuraCanvasElement.KIND_SHAPE ? "Shape"
			: el.kind == AuraCanvasElement.KIND_PATH ? "Vector path"
			: (el.kind == AuraCanvasElement.KIND_ICON ? (el.isCustomImage() ? "Custom image" : "Game icon") : "Text"));
		canvasEditX.set(el.xAt(editState));
		canvasEditY.set(el.yAt(editState));
		canvasEditW.set(el.wAt(editState) > 1 ? el.wAt(editState) : 48);
		canvasEditH.set(el.hAt(editState) > 1 ? el.hAt(editState) : 48);
		canvasEditFs.set(el.fontSize);
		canvasEditStroke.set(el.stroke);
		canvasEditOpacity.set(Math.round(el.opacityAt(editState) * 100));
		canvasEditRot.set(el.rotationAt(editState));
		syncCanvasElementColor(a, el);
		canvasEditSides.set(el.sides);
		canvasEditOutline.set(el.outline);
		canvasEditBox.set(el.wAt(editState) > 1 ? el.wAt(editState) : 0);
		UiLayout.propertyGrid("##ab_cv_props", function() {
			UiLayout.propertyRow("Layer name", function() {
				ByteUtil.fillBuf(canvasNameBuf, AuraCanvasElement.MAX_NAME * 4, el.name != null ? el.name : "");
				ImGui.setNextItemWidth(-1);
				if (ImGui.inputTextWithHint("##ab_cv_name", "Optional", canvasNameBuf, AuraCanvasElement.MAX_NAME * 4)) {
					var n = StringTools.trim(ByteUtil.readBytes(canvasNameBuf, AuraCanvasElement.MAX_NAME * 4));
					el.name = n.length > AuraCanvasElement.MAX_NAME ? n.substr(0, AuraCanvasElement.MAX_NAME) : n;
					SettingsStore.markDirty();
				}
				canvasFieldUndo("Canvas Layer Name");
			}, "Shown in the Layers list. Drag a layer row to reorder it.");
			if (el.kind == AuraCanvasElement.KIND_TEXT) drawCanvasTextRows(el);
			else if (el.kind == AuraCanvasElement.KIND_SHAPE) {
				UiLayout.propertyRow("Shape", function() {
					var picked = UiLayout.stringCombo("ab_cv_shape", el.content, AuraCanvasElement.SHAPES, canvasShapeLabel);
					if (picked != null) {
						host.canvasSnapshot("Canvas Shape");
						el.content = picked;
						SettingsStore.markDirty();
					}
				});
			} else if (el.kind == AuraCanvasElement.KIND_PATH) drawPathRows(a, el);
			else drawCanvasIconRows(a, el);
			UiLayout.propertyRow("Opacity", function() {
				if (NumberField.draw("##ab_cv_opacity", canvasEditOpacity, 0, 100, "%.0f%%", preciseFn)) { setOpacity(el, AuraCanvasElement.clampOpacity(canvasEditOpacity.get() / 100)); SettingsStore.markDirty(); }
			}, "Multiplies the colour alpha. Applies to text, images and shapes.");
			if (rotatable(el)) {
				UiLayout.propertyRow("Rotation", function() {
					if (NumberField.draw("##ab_cv_rot", canvasEditRot, -180, 180, "%.0f deg", preciseFn)) { setRotation(el, AuraCanvasElement.clampRotation(canvasEditRot.get())); SettingsStore.markDirty(); }
				}, "Turns a shape about its centre. Text and images do not rotate yet. Resize handles return at 0 degrees.");
			}
			UiLayout.propertyRow("Position", function() {
				UiLayout.inlinePair("##ab_cv_xy",
					function(_:Single) {
						if (NumberField.draw("##ab_cv_x", canvasEditX, -2000, 2000, "X  %.0f", preciseFn)) { setX(el, canvasEditX.get()); SettingsStore.markDirty(); }

					},
					function(_:Single) {
						if (NumberField.draw("##ab_cv_y", canvasEditY, -2000, 2000, "Y  %.0f", preciseFn)) { setY(el, canvasEditY.get()); SettingsStore.markDirty(); }

					});
			}, "Pixels from the aura's top-left corner, before Scale.");
			if (el.kind == AuraCanvasElement.KIND_TEXT) {
				UiLayout.propertyRow("Font size", function() {
					if (NumberField.draw("##ab_cv_fs", canvasEditFs, 6, 120, "%.0f px", preciseFn)) { el.fontSize = canvasEditFs.get(); SettingsStore.markDirty(); }

				});
				UiLayout.propertyRow("Shadow", function() {
					canvasFlagRef.set(el.shadow);
					if (ImGui.checkbox("Drop shadow##ab_cv_shadow", canvasFlagRef)) { host.canvasSnapshot("Canvas Shadow"); el.shadow = canvasFlagRef.get(); SettingsStore.markDirty(); }
				});
			} else {
				UiLayout.propertyRow("Size", function() {
					UiLayout.inlinePair("##ab_cv_wh",
						function(_:Single) {
							if (NumberField.draw("##ab_cv_w", canvasEditW, 4, 1024, "W  %.0f", preciseFn)) { setW(el, canvasEditW.get()); SettingsStore.markDirty(); }

						},
						function(_:Single) {
							if (NumberField.draw("##ab_cv_h", canvasEditH, 4, 1024, "H  %.0f", preciseFn)) { setH(el, canvasEditH.get()); SettingsStore.markDirty(); }

						});
				});
			}
			if (el.kind == AuraCanvasElement.KIND_SHAPE && (el.content == "polygon" || el.content == "star")) {
				UiLayout.propertyRow(el.content == "star" ? "Points" : "Sides", function() {
					if (NumberField.draw("##ab_cv_sides", canvasEditSides, 3, 12, "%.0f", preciseFn)) { el.sides = AuraCanvasElement.clampSides(Std.int(canvasEditSides.get())); SettingsStore.markDirty(); }
				});
			}
			if (el.kind == AuraCanvasElement.KIND_SHAPE) {
				var ring = el.content == "ring";
				UiLayout.propertyRow(ring ? "Thickness" : "Outline", function() {
					if (NumberField.draw("##ab_cv_stroke", canvasEditStroke, 0, 16, ring ? "%.0f px (0 = auto)" : "%.0f px", preciseFn)) { el.stroke = canvasEditStroke.get(); SettingsStore.markDirty(); }
				}, ring ? "Width of the ring band. 0 picks a width from the size." : "0 fills the shape; any other value draws only its outline at that thickness.");
				if (el.content != "line") drawGradientRows(el, ring);
			}
			UiLayout.propertyRow("Swatches", function() { drawSwatches(el); }, "Click a swatch to use it. The row below keeps your most recent colours.");
			UiLayout.propertyRow(el.kind == AuraCanvasElement.KIND_ICON ? "Tint" : "Color", function() {
				if (ImGui.colorEdit4("##ab_cv_col", canvasColBuf, PICKER_FLAGS)) {
					if (!canvasColorEditing) host.canvasSnapshot("Canvas Color");
					canvasColorEditing = true;
					setColor(el, packCanvasColor());
					SettingsStore.markDirty();
				} else if (!ImGui.isAnyItemActive()) canvasColorEditing = false;
				if (ImGui.isItemDeactivatedAfterEdit()) rememberColor(el.colorAt(editState));
			});
			if (el.kind != AuraCanvasElement.KIND_TEXT) drawEdgeRows(el);
			UiLayout.propertyRow("Visibility", function() {
				var conditional = el.visibilityRule != null;
				if (ImGui.beginCombo("##ab_cv_visibility", conditional ? "When conditions match" : "Always")) {
					if (ImGui.selectable("Always", !conditional) && conditional) {
						host.canvasSnapshot("Canvas visibility rule"); el.visibilityRule = null; el.clearVisibility(); SettingsStore.markDirty();
					}
					if (ImGui.selectable("When conditions match", conditional) && !conditional) {
						host.canvasSnapshot("Canvas visibility rule"); el.visibilityRule = new solarflare.aura.signal.AuraRuleDef(); el.clearVisibility(); SettingsStore.markDirty();
					}
					ImGui.endCombo();
				}
			});
			drawElementStateRows(a, el);
			UiLayout.propertyRow("State", function() {
				canvasFlagRef.set(el.hiddenAt(editState));
				if (ImGui.checkbox("Hidden##ab_cv_hidden", canvasFlagRef)) { host.canvasSnapshot("Canvas Visibility"); setHidden(el, canvasFlagRef.get()); SettingsStore.markDirty(); }
				ImGui.sameLine(0, 16);
				canvasFlagRef.set(el.locked);
				if (ImGui.checkbox("Locked##ab_cv_locked", canvasFlagRef)) { host.canvasSnapshot("Canvas Lock"); el.locked = canvasFlagRef.get(); SettingsStore.markDirty(); }
			}, "Locked elements ignore stage clicks and drags, so plates behind text stay put.");
			UiLayout.propertyRow("Align", function() drawCanvasAlignRow(a, el));
		});
		if (el.visibilityRule != null) {
			var context = canvasRuleContexts.get(el);
			if (context == null) {
				var ui:Array<solarflare.aura.signal.AuraConditionUiState> = [];
				context = new solarflare.aura.signal.AuraRuleEditorContext(a.id + "_canvas_" + nextCanvasRuleId++, el.visibilityRule, el.visibilityResult, ui, false);
				canvasRuleContexts.set(el, context);
			}
			context.rule = el.visibilityRule;
			context.snapshot = preciseFn;
			ImGui.textDisabled(el.visibilityResult.known ? (el.visibilityResult.hit ? "Conditions match" : "Conditions do not match") : "Conditions unavailable or incomplete");
			solarflare.aura.signal.AuraConditionEditor.drawContext(context);
		}
	}

	/** Outline effect rows: side, width, colour and an optional timer-driven wipe. */
	function drawEdgeRows(el:AuraCanvasElement):Void {
		UiLayout.propertyRow("Edge outline", function() {
			canvasFlagRef.set(el.edgeOn);
			if (ImGui.checkbox("Outline the edge##ab_cv_edge_on", canvasFlagRef)) { host.canvasSnapshot("Canvas Edge"); el.edgeOn = canvasFlagRef.get(); SettingsStore.markDirty(); }
		}, el.kind == AuraCanvasElement.KIND_ICON ? "Traces the visible shape of a custom image (its see-through parts are ignored). Game icons use their box." : "Draws a coloured line along the edge of the layer.");
		if (!el.edgeOn) return;
		UiLayout.propertyRow("Side", function() {
			UiLayout.inlineSplit("##ab_cv_edge_side", 3, function(index:Int, cellW:Single) {
				var value = index == 0 ? AuraCanvasElement.EDGE_OUTER : (index == 1 ? AuraCanvasElement.EDGE_INNER : AuraCanvasElement.EDGE_CENTER);
				var on = el.edgeSide == value;
				if (on) ImGui.pushStyleColor(ImGuiCol.Button, solarflare.ui.ThemePalette.current().accent);
				if (ImGui.button((index == 0 ? "Outside" : (index == 1 ? "Inside" : "Centred")) + "##ab_cv_es" + index, ImGui.vec2(cellW, 0)) && !on) { host.canvasSnapshot("Canvas Edge"); el.edgeSide = value; SettingsStore.markDirty(); }
				if (on) ImGui.popStyleColor();
			});
		}, "Outside draws beyond the edge, Inside draws within the layer, Centred straddles the edge.");
		canvasEditEdge.set(el.edgeWidth);
		UiLayout.propertyRow("Edge width", function() {
			if (NumberField.draw("##ab_cv_edge_w", canvasEditEdge, 0.5, AuraCanvasElement.MAX_EDGE, "%.1f px", preciseFn)) { el.edgeWidth = Math.max(0.5, Math.min(AuraCanvasElement.MAX_EDGE, canvasEditEdge.get())); SettingsStore.markDirty(); }
		});
		if (edgeColEl != el || (!edgeColEditing && edgeColValue != el.edgeColor)) {
			edgeColEl = el; edgeColValue = el.edgeColor;
			edgeColBuf.setF32(0, ((edgeColValue >> 16) & 0xFF) / 255.0);
			edgeColBuf.setF32(4, ((edgeColValue >> 8) & 0xFF) / 255.0);
			edgeColBuf.setF32(8, (edgeColValue & 0xFF) / 255.0);
			edgeColBuf.setF32(12, ((edgeColValue >>> 24) & 0xFF) / 255.0);
		}
		UiLayout.propertyRow("Edge color", function() {
			if (ImGui.colorEdit4("##ab_cv_edge_col", edgeColBuf, PICKER_FLAGS)) {
				if (!edgeColEditing) host.canvasSnapshot("Canvas Edge Color");
				edgeColEditing = true;
				var r = Std.int(Math.max(0, Math.min(1, edgeColBuf.getF32(0))) * 255), g = Std.int(Math.max(0, Math.min(1, edgeColBuf.getF32(4))) * 255);
				var b = Std.int(Math.max(0, Math.min(1, edgeColBuf.getF32(8))) * 255), al = Std.int(Math.max(0, Math.min(1, edgeColBuf.getF32(12))) * 255);
				edgeColValue = (al << 24) | (r << 16) | (g << 8) | b;
				el.edgeColor = edgeColValue;
				SettingsStore.markDirty();
			} else if (!ImGui.isAnyItemActive()) edgeColEditing = false;
		});
		UiLayout.propertyRow("Shown", function() {
			UiLayout.inlineSplit("##ab_cv_edge_mode", 2, function(index:Int, cellW:Single) {
				var on = (index == 1) == el.edgeCooldown;
				if (on) ImGui.pushStyleColor(ImGuiCol.Button, solarflare.ui.ThemePalette.current().accent);
				if (ImGui.button((index == 0 ? "Always" : "With timer") + "##ab_cv_em" + index, ImGui.vec2(cellW, 0)) && !on) { host.canvasSnapshot("Canvas Edge"); el.edgeCooldown = index == 1; SettingsStore.markDirty(); }
				if (on) ImGui.popStyleColor();
			});
		}, "With timer wipes the outline in as the aura's timer or cooldown runs, so it is complete when the timer ends. Use Live conditions preview to see it.");
		if (!el.edgeCooldown) return;
		UiLayout.propertyRow("Wipe direction", function() {
			UiLayout.inlineSplit("##ab_cv_edge_dir", 4, function(index:Int, cellW:Single) {
				var on = el.edgeDir == index;
				if (on) ImGui.pushStyleColor(ImGuiCol.Button, solarflare.ui.ThemePalette.current().accent);
				if (ImGui.button(["Up", "Down", "Left", "Right"][index] + "##ab_cv_ed" + index, ImGui.vec2(cellW, 0)) && !on) { host.canvasSnapshot("Canvas Edge"); el.edgeDir = index; SettingsStore.markDirty(); }
				if (on) ImGui.popStyleColor();
			});
		}, "The way the edge of the reveal moves: Up fills from the bottom to the top, Left from the right to the left.");
		UiLayout.propertyRow("Timer effect", function() {
			UiLayout.inlineSplit("##ab_cv_edge_drain", 2, function(index:Int, cellW:Single) {
				var on = (index == 1) == el.edgeDrain;
				if (on) ImGui.pushStyleColor(ImGuiCol.Button, solarflare.ui.ThemePalette.current().accent);
				if (ImGui.button((index == 0 ? "Fills in" : "Drains away") + "##ab_cv_ex" + index, ImGui.vec2(cellW, 0)) && !on) { host.canvasSnapshot("Canvas Edge"); el.edgeDrain = index == 1; SettingsStore.markDirty(); }
				if (on) ImGui.popStyleColor();
			});
		}, "Fills in: the outline appears as time passes. Drains away: it starts complete and disappears.");
	}

	function drawCanvasTextRows(el:AuraCanvasElement):Void {
		UiLayout.propertyRow("Text", function() {
			ByteUtil.fillBuf(canvasContentBuf, CANVAS_CONTENT_BUF, el.content != null ? el.content : "");
			if (ImGui.inputText("##ab_cv_content", canvasContentBuf, CANVAS_CONTENT_BUF)) {
				el.content = StringTools.trim(ByteUtil.readBytes(canvasContentBuf, CANVAS_CONTENT_BUF));
				SettingsStore.markDirty();
			}
			canvasFieldUndo("Canvas Text");
		});
		UiLayout.propertyRow("Box width", function() {
			if (NumberField.draw("##ab_cv_boxw", canvasEditBox, 0, 1024, "%.0f px (0 = fit text)", preciseFn)) { setW(el, canvasEditBox.get() >= 2 ? canvasEditBox.get() : 0); SettingsStore.markDirty(); }
		}, "Give the text a fixed width to align it left, centre or right inside that box.");
		UiLayout.propertyRow("Alignment", function() {
			UiLayout.inlineSplit("##ab_cv_talign", 3, function(index:Int, cellW:Single) {
				var size = ImGui.vec2(cellW, 0);
				var label = index == 0 ? "Left" : (index == 1 ? "Centre" : "Right");
				if (index == el.textAlign) ImGui.pushStyleColor(ImGuiCol.Button, solarflare.ui.ThemePalette.current().accent);
				if (ImGui.button(label + "##ab_cv_ta" + index, size) && el.textAlign != index) { host.canvasSnapshot("Canvas Text Align"); el.textAlign = index; SettingsStore.markDirty(); }
				if (index == el.textAlign) ImGui.popStyleColor();
			});
		}, "Needs a Box width above 0.");
		UiLayout.propertyRow("Outline", function() {
			if (NumberField.draw("##ab_cv_toutline", canvasEditOutline, 0, 4, "%.1f px", preciseFn)) { el.outline = Math.max(0, Math.min(4, canvasEditOutline.get())); SettingsStore.markDirty(); }
		}, "A dark edge that keeps text readable over busy icons.");
		UiLayout.propertyRow("Time format", function() {
				UiLayout.inlineSplit("##ab_cv_tfmt", 2, function(index:Int, cellW:Single) {
					var on = (index == 1) == el.wholeTime;
					if (on) ImGui.pushStyleColor(ImGuiCol.Button, solarflare.ui.ThemePalette.current().accent);
					if (ImGui.button((index == 0 ? "Decimals (4.3)" : "Whole seconds (5)") + "##ab_cv_tf" + index, ImGui.vec2(cellW, 0)) && !on) { host.canvasSnapshot("Canvas Time Format"); el.wholeTime = index == 1; SettingsStore.markDirty(); }
					if (on) ImGui.popStyleColor();
				});
			}, "How {time} is written. Whole seconds always round up, so a 4.3 s timer reads 5.");
			UiLayout.propertyRow("Insert", function() {
			for (tok in CANVAS_TOKENS) {
				if (ImGui.smallButton(tok + "##ab_tok_" + tok)) {
					host.canvasSnapshot("Canvas Token");
					el.content += tok;
					SettingsStore.markDirty();
				}
				if (tok != "{name}") ImGui.sameLine(0, 4);
			}
		});
	}

	static inline var PICKER_FLAGS:Int = imgui.Enums.ImGuiColorEditFlags.AlphaBar | imgui.Enums.ImGuiColorEditFlags.AlphaPreviewHalf
		| imgui.Enums.ImGuiColorEditFlags.PickerHueWheel | imgui.Enums.ImGuiColorEditFlags.DisplayRGB | imgui.Enums.ImGuiColorEditFlags.DisplayHSV
		| imgui.Enums.ImGuiColorEditFlags.DisplayHex;
	static var PALETTE:Array<Int> = [0xFFFFFFFF, 0xFF000000, 0xFFE53935, 0xFFFF9800, 0xFFFFD54F, 0xFF66BB6A, 0xFF26C6DA, 0xFF42A5F5, 0xFF7E57C2, 0xFFEC407A, 0xFF9E9E9E, 0xC0101418];
	var recentColors:Array<Int> = [];

	static function packedToVec4(c:Int):imgui.Structs.ImVec4 {
		return ImGui.vec4(((c >> 16) & 0xFF) / 255.0, ((c >> 8) & 0xFF) / 255.0, (c & 0xFF) / 255.0, ((c >>> 24) & 0xFF) / 255.0);
	}

	function rememberColor(c:Int):Void {
		recentColors.remove(c);
		recentColors.unshift(c);
		if (recentColors.length > 10) recentColors.pop();
	}

	function applySwatch(el:AuraCanvasElement, c:Int):Void {
		host.canvasSnapshot("Canvas Color");
		setColor(el, c);
		rememberColor(c);
		invalidateColor();
		SettingsStore.markDirty();
	}

	function drawSwatches(el:AuraCanvasElement):Void {
		var all = PALETTE.concat(recentColors);
		for (i in 0...all.length) {
			if (i > 0 && i != PALETTE.length) ImGui.sameLine(0, 3);
			else if (i == PALETTE.length) { ImGui.spacing(); }
			if (ImGui.colorButton("##cv_sw_" + i, packedToVec4(all[i]), 0, ImGui.vec2(20, 20))) applySwatch(el, all[i]);
			if (ImGui.isItemHovered()) ImGui.setTooltip(i < PALETTE.length ? "Palette colour" : "Recent colour");
		}
	}

	function drawPathRows(a:AuraDef, el:AuraCanvasElement):Void {
		UiLayout.propertyRow("Outline", function() {
			var n = el.path != null ? el.path.nodes.length : 0;
			ImGui.textDisabled(el.path == null ? "No path data" : n + " point" + (n == 1 ? "" : "s") + ", " + (el.path.closed ? "closed" : "open"));
		}, "Paste more SVG path data from Insert > Vector to add shapes. Resize and rotate the layer to scale the whole path.");
		UiLayout.propertyRow("Fill", function() {
			canvasFlagRef.set(el.fill);
			if (ImGui.checkbox("Fill the shape##cv_path_fill", canvasFlagRef)) { host.canvasSnapshot("Canvas Path Fill"); el.fill = canvasFlagRef.get(); SettingsStore.markDirty(); }
		}, "Open paths have no inside to fill.");
		UiLayout.propertyRow("Stroke", function() {
			if (NumberField.draw("##ab_cv_stroke", canvasEditStroke, 0, 16, "%.0f px (0 = none)", preciseFn)) { el.stroke = canvasEditStroke.get(); SettingsStore.markDirty(); }
		});
		UiLayout.propertyRow("Stroke color", function() {
			canvasFlagRef.set(el.strokeColor == null);
			if (ImGui.checkbox("Same as fill##cv_path_same", canvasFlagRef)) {
				host.canvasSnapshot("Canvas Stroke Color");
				el.strokeColor = canvasFlagRef.get() ? null : 0xFFFFFFFF;
				SettingsStore.markDirty();
			}
			if (el.strokeColor != null) {
				ImGui.sameLine(0, 8);
				if (!canvasStrokeEditing) fillColorBuf(canvasStrokeBuf, el.strokeColor);
				if (ImGui.colorEdit4("##cv_path_scol", canvasStrokeBuf, PICKER_FLAGS)) {
					if (!canvasStrokeEditing) host.canvasSnapshot("Canvas Stroke Color");
					canvasStrokeEditing = true;
					el.strokeColor = packColorBuf(canvasStrokeBuf);
					SettingsStore.markDirty();
				} else if (!ImGui.isAnyItemActive()) canvasStrokeEditing = false;
			}
		});
		drawGradientRows(el, true);
	}

	// ---- Animation -----------------------------------------------------------------------------

	var canvasAnimIn = new FloatRef(0);
	var canvasAnimOut = new FloatRef(0);
	var canvasAnimPeriod = new FloatRef(2);
	var canvasAnimDepth = new FloatRef(60);
	var canvasAnimVol = new FloatRef(70);
	var canvasPulseBuf:hl.Bytes = ImGui.v4(1, 1, 1, 1);
	var canvasPulseEditing:Bool = false;
	var soundImportBuf = new hl.Bytes(520);
	var soundMsg:String = "";
	var soundMsgError:Bool = false;
	var soundScanQueued:Bool = false;
	static var PULSE_LABELS:Array<String> = ["None", "Breathe (opacity)", "Colour shift"];

	function soundPicker(id:String, current:String, onPick:String->Void, volume:Float):Void {
		ImGui.setNextItemWidth(Math.max(60, ImGui.getContentRegionAvail().x - 58));
		if (ImGui.beginCombo("##cv_snd_" + id, current.length > 0 ? current : "None")) {
			try {
				if (ImGui.selectable("None##cv_snd_none_" + id, current.length == 0)) onPick("");
				for (n in CustomSounds.names()) if (ImGui.selectable(n + "##cv_snd_" + id + "_" + n, n == current)) onPick(n);
				if (CustomSounds.names().length == 0) ImGui.textDisabled("No sounds yet. Import one below.");
			} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
			ImGui.endCombo();
		}
		ImGui.sameLine(0, 4);
		ImGui.beginDisabled(current.length == 0);
		if (ImGui.button("Play##cv_snd_play_" + id, ImGui.vec2(54, 0))) UiActionQueue.custom(function() AuraSoundPlayer.play(current, volume));
		ImGui.endDisabled();
	}

	/** Fades, a simple pulse and show/hide sound cues for one layer. */
	function drawAnimationSection(a:AuraDef, el:AuraCanvasElement):Void {
		if (!ImGui.collapsingHeader("Animation##cv_anim", el.hasAnimation() ? imgui.Enums.ImGuiTreeNodeFlags.DefaultOpen : 0)) return;
		if (!CustomSounds.hasScanned() && !soundScanQueued) { soundScanQueued = true; UiActionQueue.custom(function() CustomSounds.refresh()); }
		canvasAnimIn.set(el.fadeIn); canvasAnimOut.set(el.fadeOut);
		canvasAnimPeriod.set(el.pulsePeriod); canvasAnimDepth.set(Math.round(el.pulseDepth * 100));
		canvasAnimVol.set(Math.round(el.soundVolume * 100));
		UiLayout.propertyGrid("##cv_anim_props", function() {
			UiLayout.propertyRow("Fade in", function() {
				if (NumberField.draw("##cv_fin", canvasAnimIn, 0, AuraCanvasElement.MAX_FADE, "%.1f s (0 = instant)", preciseFn)) { el.fadeIn = canvasAnimIn.get(); SettingsStore.markDirty(); }
			}, "How long the layer takes to appear when it is first shown, or when its look or conditions bring it back.");
			UiLayout.propertyRow("Fade out", function() {
				if (NumberField.draw("##cv_fout", canvasAnimOut, 0, AuraCanvasElement.MAX_FADE, "%.1f s (0 = instant)", preciseFn)) { el.fadeOut = canvasAnimOut.get(); SettingsStore.markDirty(); }
			}, "How long it takes to dissolve when its conditions stop matching or another look hides it.");
			UiLayout.propertyRow("Pulse", function() {
				ImGui.setNextItemWidth(-1);
				if (ImGui.beginCombo("##cv_pulse_kind", PULSE_LABELS[el.pulseKind])) {
					for (i in 0...PULSE_LABELS.length) if (ImGui.selectable(PULSE_LABELS[i] + "##cv_pk_" + i, el.pulseKind == i) && el.pulseKind != i) {
						host.canvasSnapshot("Canvas Pulse"); el.pulseKind = i; SettingsStore.markDirty();
					}
					ImGui.endCombo();
				}
			}, "A steady loop: breathe the opacity, or shift the colour towards another and back.");
			if (el.pulseKind != AuraCanvasElement.PULSE_NONE) {
				UiLayout.propertyRow("Speed", function() {
					if (NumberField.draw("##cv_pperiod", canvasAnimPeriod, 0.2, 30, "%.1f s per pulse", preciseFn)) { el.pulsePeriod = canvasAnimPeriod.get(); SettingsStore.markDirty(); }
				});
				UiLayout.propertyRow("Strength", function() {
					if (NumberField.draw("##cv_pdepth", canvasAnimDepth, 0, 100, "%.0f%%", preciseFn)) { el.pulseDepth = canvasAnimDepth.get() / 100; SettingsStore.markDirty(); }
				});
				if (el.pulseKind == AuraCanvasElement.PULSE_COLOR) {
					UiLayout.propertyRow("Pulse colour", function() {
						if (!canvasPulseEditing) fillColorBuf(canvasPulseBuf, el.pulseColor);
						if (ImGui.colorEdit4("##cv_pcolor", canvasPulseBuf, PICKER_FLAGS)) {
							if (!canvasPulseEditing) host.canvasSnapshot("Canvas Pulse Color");
							canvasPulseEditing = true;
							el.pulseColor = packColorBuf(canvasPulseBuf);
							SettingsStore.markDirty();
						} else if (!ImGui.isAnyItemActive()) canvasPulseEditing = false;
					});
				}
			}
			UiLayout.propertyRow("Show cue", function() {
				soundPicker("show", el.soundShow, function(n) { host.canvasSnapshot("Canvas Sound"); el.soundShow = n; SettingsStore.markDirty(); }, el.soundVolume);
			}, "Plays when the layer appears in game.");
			UiLayout.propertyRow("Hide cue", function() {
				soundPicker("hide", el.soundHide, function(n) { host.canvasSnapshot("Canvas Sound"); el.soundHide = n; SettingsStore.markDirty(); }, el.soundVolume);
			}, "Plays when the layer goes away in game.");
			if (el.soundShow.length > 0 || el.soundHide.length > 0) {
				UiLayout.propertyRow("Volume", function() {
					if (NumberField.draw("##cv_svol", canvasAnimVol, 0, 100, "%.0f%%", preciseFn)) { el.soundVolume = canvasAnimVol.get() / 100; SettingsStore.markDirty(); }
				});
			}
		});
		wrappedHint("Fades and sound cues run in game, and in the preview with Live conditions. Pulses can be previewed with View > Animate pulses here. Sound names are not carried by share keys; friends need the same file in their custom_sounds folder.");
		ImGui.setNextItemWidth(Math.max(60, ImGui.getContentRegionAvail().x - 150));
		var enter = ImGui.inputTextWithHint("##cv_snd_import", "Path to a .wav, .ogg or .mp3 (2 MB max)", soundImportBuf, 520, imgui.Enums.ImGuiInputTextFlags.EnterReturnsTrue);
		ImGui.sameLine(0, 4);
		if (UiChrome.ghostButton("Import##cv_snd_go", ImGui.vec2(68, 26)) || enter) {
			var raw = ByteUtil.readBytes(soundImportBuf, 520);
			UiActionQueue.custom(function() {
				try {
					var stem = CustomSounds.importFile(raw);
					ByteUtil.clearBytes(soundImportBuf, 520);
					soundMsg = "Imported " + stem; soundMsgError = false;
				} catch (e:Dynamic) { soundMsg = Std.string(e); soundMsgError = true; }
			});
		}
		ImGui.sameLine(0, 4);
		if (UiChrome.ghostButton("Refresh##cv_snd_refresh", ImGui.vec2(72, 26))) UiActionQueue.custom(function() { CustomSounds.refresh(); AuraSoundPlayer.clearCache(); });
		if (soundMsg.length > 0) {
			if (soundMsgError) ImGui.textColored(solarflare.ui.ThemePalette.status(solarflare.ui.ThemePalette.STATUS_DANGER), soundMsg); else ImGui.textDisabled(soundMsg);
		}
		if (AuraSoundPlayer.status.length > 0) ImGui.textColored(solarflare.ui.ThemePalette.status(solarflare.ui.ThemePalette.STATUS_WARN), AuraSoundPlayer.status);
		ImGui.textDisabled(CustomSounds.status);
	}

	/** Point editing lives below the property grid so its buttons get the full panel width. */
	function drawPathTools(a:AuraDef, el:AuraCanvasElement):Void {
		if (el.kind == AuraCanvasElement.KIND_PATH) drawNodeRows(a, el);
	}

	function drawGradientRows(el:AuraCanvasElement, ring:Bool):Void {
		var usable = el.stroke <= 0 || ring;
		UiLayout.propertyRow("Gradient", function() {
			ImGui.beginDisabled(!usable);
			canvasFlagRef.set(el.color2 != null);
			if (ImGui.checkbox("Fade to##ab_cv_grad", canvasFlagRef)) {
				host.canvasSnapshot("Canvas Gradient");
				// Start from the same hue fully transparent, the most common soft-edge look.
				el.color2 = canvasFlagRef.get() ? (el.color & 0x00FFFFFF) : null;
				SettingsStore.markDirty();
			}
			if (el.color2 != null) {
				ImGui.sameLine(0, 8);
				if (!canvasColor2Editing) fillColorBuf(canvasCol2Buf, el.color2);
				if (ImGui.colorEdit4("##ab_cv_col2", canvasCol2Buf, PICKER_FLAGS)) {
					if (!canvasColor2Editing) host.canvasSnapshot("Canvas Gradient");
					canvasColor2Editing = true;
					el.color2 = packColorBuf(canvasCol2Buf);
					SettingsStore.markDirty();
				} else if (!ImGui.isAnyItemActive()) canvasColor2Editing = false;
			}
			ImGui.endDisabled();
		}, usable ? "Blends the fill from Color to this colour. The blend follows the screen, so it stays put when the shape rotates." : "Outlines do not take a gradient. Set Outline to 0 for a filled shape.");
		if (el.color2 != null && usable) {
			UiLayout.propertyRow("Direction", function() {
				if (ImGui.radioButton("Top to bottom##ab_cv_gd0", el.gradDir == 0) && el.gradDir != 0) { host.canvasSnapshot("Canvas Gradient"); el.gradDir = 0; SettingsStore.markDirty(); }
				ImGui.sameLine(0, 12);
				if (ImGui.radioButton("Left to right##ab_cv_gd1", el.gradDir == 1) && el.gradDir != 1) { host.canvasSnapshot("Canvas Gradient"); el.gradDir = 1; SettingsStore.markDirty(); }
			});
		}
	}

	static function fillColorBuf(buf:hl.Bytes, c:Int):Void {
		buf.setF32(0, ((c >> 16) & 0xFF) / 255.0);
		buf.setF32(4, ((c >> 8) & 0xFF) / 255.0);
		buf.setF32(8, (c & 0xFF) / 255.0);
		buf.setF32(12, ((c >>> 24) & 0xFF) / 255.0);
	}

	static function packColorBuf(buf:hl.Bytes):Int {
		var r = Std.int(Math.max(0, Math.min(1, buf.getF32(0))) * 255);
		var g = Std.int(Math.max(0, Math.min(1, buf.getF32(4))) * 255);
		var b = Std.int(Math.max(0, Math.min(1, buf.getF32(8))) * 255);
		var al = Std.int(Math.max(0, Math.min(1, buf.getF32(12))) * 255);
		return (al << 24) | (r << 16) | (g << 8) | b;
	}

	static var CANVAS_TOKENS:Array<String> = ["{time}", "{stacks}", "{counter}", "{name}"];

	function drawCanvasIconRows(a:AuraDef, el:AuraCanvasElement):Void {
		UiLayout.propertyRow("Source", function() {
			var custom = el.isCustomImage();
			if (ImGui.radioButton("Game icon##ab_cv_src_game", !custom) && custom) {
				host.canvasSnapshot("Canvas Source");
				var id = a.preferredIconId();
				el.content = id.length > 0 ? id : "icon";
				SettingsStore.markDirty();
			}
			ImGui.sameLine(0, 12);
			if (ImGui.radioButton("Custom image##ab_cv_src_custom", custom) && !custom) {
				host.canvasSnapshot("Canvas Source");
				var names = CustomImages.names();
				el.content = CustomImages.key(names.length > 0 ? names[0] : "");
				SettingsStore.markDirty();
			}
		});
		if (el.isCustomImage()) {
			drawCanvasImageRows(el);
			return;
		}
		UiLayout.propertyRow("Game icon", function() {
			iconPicker.draw("cv_el", el.content, function(picked) {
				host.canvasSnapshot("Canvas Icon");
				el.content = picked;
				GameIcons.get(picked);
				SettingsStore.markDirty();
			});
		}, "Search the game's units, skills and icons by name. The Icon ID field below takes any id directly.");
		UiLayout.propertyRow("Icon ID", function() {
			ByteUtil.fillBuf(canvasContentBuf, CANVAS_CONTENT_BUF, el.content != null ? el.content : "");
			ImGui.setNextItemWidth(Math.max(60, ImGui.getContentRegionAvail().x - 96));
			if (ImGui.inputText("##ab_cv_content", canvasContentBuf, CANVAS_CONTENT_BUF)) {
				el.content = StringTools.trim(ByteUtil.readBytes(canvasContentBuf, CANVAS_CONTENT_BUF));
				SettingsStore.markDirty();
			}
			canvasFieldUndo("Canvas Icon");
			ImGui.sameLine(0, 4);
			if (ImGui.button("Aura icon##ab_cv_use_aura_icon", ImGui.vec2(92, 0))) {
				host.canvasSnapshot("Canvas Icon");
				el.content = a.preferredIconId();
				SettingsStore.markDirty();
			}
			if (ImGui.isItemHovered()) ImGui.setTooltip("Use this aura's own icon.");
		});
	}

	function drawCanvasAlignRow(a:AuraDef, el:AuraCanvasElement):Void {
		var auraW = a.w.get() > 1 ? a.w.get() : 96;
		var auraH = a.h.get() > 1 ? a.h.get() : 96;
		UiLayout.inlineSplit("##ab_cv_align_h", 3, function(index:Int, cellW:Single) {
			var size = ImGui.vec2(cellW, 0);
			if (index == 0 && ImGui.button("Left##ab_cv_al", size)) { host.canvasSnapshot("Canvas Align"); setX(el, 0); SettingsStore.markDirty(); }
			else if (index == 1 && ImGui.button("Center##ab_cv_ach", size)) { host.canvasSnapshot("Canvas Align"); setX(el, Math.round((auraW - measureCanvasElementW(a, el)) * 0.5)); SettingsStore.markDirty(); }
			else if (index == 2 && ImGui.button("Right##ab_cv_ar", size)) { host.canvasSnapshot("Canvas Align"); setX(el, Math.round(auraW - measureCanvasElementW(a, el))); SettingsStore.markDirty(); }
		});
		UiLayout.inlineSplit("##ab_cv_align_v", 3, function(index:Int, cellW:Single) {
			var size = ImGui.vec2(cellW, 0);
			if (index == 0 && ImGui.button("Top##ab_cv_at", size)) { host.canvasSnapshot("Canvas Align"); setY(el, 0); SettingsStore.markDirty(); }
			else if (index == 1 && ImGui.button("Middle##ab_cv_acv", size)) { host.canvasSnapshot("Canvas Align"); setY(el, Math.round((auraH - measureCanvasElementH(a, el)) * 0.5)); SettingsStore.markDirty(); }
			else if (index == 2 && ImGui.button("Bottom##ab_cv_ab", size)) { host.canvasSnapshot("Canvas Align"); setY(el, Math.round(auraH - measureCanvasElementH(a, el))); SettingsStore.markDirty(); }
		});
		if (el.kind != AuraCanvasElement.KIND_TEXT && ImGui.button("Fill aura##ab_cv_fill", ImGui.vec2(-1, 0))) {
			host.canvasSnapshot("Canvas Fill");
			setX(el, 0);
			setY(el, 0);
			setW(el, auraW);
			setH(el, auraH);
			SettingsStore.markDirty();
		}
	}

	static function canvasShapeLabel(id:String):String {
		return switch (id) {
			case "rect": "Rectangle";
			case "rounded": "Rounded rectangle";
			case "circle": "Circle / ellipse";
			case "diamond": "Diamond";
			case "hex": "Hexagon";
			case "triangle": "Triangle";
			case "line": "Line";
			case "polygon": "Polygon";
			case "star": "Star";
			case "ring": "Ring";
			case "chevron": "Chevron";
			default: id;
		}
	}

	/** Cache-only picker. Scans/imports are requested here and executed during observation. */
	function drawCanvasImageRows(el:AuraCanvasElement):Void {
		UiLayout.propertyRow("Image", function() {
			var stem = CustomImages.stemOf(el.content);
			var opened = ImGui.beginCombo("##ab_cv_img", stem.length > 0 ? stem : "Choose an image...");
			if (opened) {
				try {
					if (!canvasImgComboOpen) CustomImages.requestRefresh();
					canvasImgComboOpen = true;
					var names = CustomImages.names();
					if (names.length == 0) ImGui.textDisabled("No images yet. Import one below or drop PNGs in the folder.");
					for (n in names) {
						if (!GameIcons.imageKey(CustomImages.key(n), 20, 20)) ImGui.dummy(ImGui.vec2(20, 20));
						ImGui.sameLine(0, 6);
						if (ImGui.selectable(n + "##ab_cv_img_" + n, n == stem)) {
							host.canvasSnapshot("Canvas Image");
							el.content = CustomImages.key(n);
							GameIcons.get(el.content);
							SettingsStore.markDirty();
						}
					}
				} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
				ImGui.endCombo();
			} else canvasImgComboOpen = false;
		});
		UiLayout.propertyRow("Import", function() {
			ImGui.setNextItemWidth(Math.max(60, ImGui.getContentRegionAvail().x - 72));
			var enter = ImGui.inputTextWithHint("##ab_cv_imp", "Paste an image path (PNG, GIF, BMP, TGA)", canvasImportBuf, CANVAS_IMPORT_BUF,
				imgui.Enums.ImGuiInputTextFlags.EnterReturnsTrue);
			ImGui.sameLine(0, 4);
			if (ImGui.button("Import##ab_cv_imp_go", ImGui.vec2(68, 0)) || enter) {
				var path = ByteUtil.readBytes(canvasImportBuf, CANVAS_IMPORT_BUF);
				var owner = host.canvasSelectedAura();
				UiActionQueue.custom(function() {
					if (!host.canvasHostOpen() || owner == null || host.canvasAuras().indexOf(owner) < 0 || owner.canvasElements == null || owner.canvasElements.indexOf(el) < 0) return;
					try {
						var stem = CustomImages.importFile(path);
						host.canvasSnapshot("Canvas Image"); el.content = CustomImages.key(stem);
						GameIcons.get(el.content); SettingsStore.markDirty();
						ByteUtil.clearBytes(canvasImportBuf, CANVAS_IMPORT_BUF);
						canvasImportMsg = "Imported " + stem + ".png"; canvasImportErr = false;
					} catch (e:Dynamic) { canvasImportMsg = Std.string(e); canvasImportErr = true; }
				});
			}
			if (canvasImportMsg.length > 0) {
				if (canvasImportErr) ImGui.textColored(ImGui.vec4(0.95, 0.45, 0.4, 1), canvasImportMsg);
				else ImGui.textDisabled(canvasImportMsg);
			}
		}, "PNG, JPG, GIF, BMP or TGA, converted to PNG; larger than 1024px is scaled down; 4 MB max. Import copies into the selected images folder. The picker lists PNGs in that folder itself. Clipboard keys carry only filenames. Use Export with images to share a ZIP containing the PNGs.");
	}

	public function resetCanvasTransient():Void {
		resetPathTools();
		canvasRowOwner=null; canvasRowIds=new haxe.ds.ObjectMap<AuraCanvasElement,Int>();
		canvasMulti = [];
		canvasDragMode = CANVAS_DRAG_NONE;
		canvasDragUndo = null;
		canvasFieldUndoState = null;
		canvasColorEditing = false;
		canvasImgComboOpen = false;
		lastCanvasColorEl = null;
		canvasImportMsg = "";
		canvasFolderGeneration = -1;
		canvasFolderMsg = "";
	}

	function measureCanvasElementW(a:AuraDef, el:AuraCanvasElement):Float {
		if (el == null) return 0;
		if (el.kind != AuraCanvasElement.KIND_TEXT) return el.wAt(editState) > 1 ? el.wAt(editState) : 48;
		if (el.wAt(editState) > 1) return el.wAt(editState);
		var raw = AuraVisualRenderer.formatTokens(el.content != null ? el.content : "", a, host.canvasPreview().stacks.get(), host.canvasPreview().counter.get(), el.wholeTime);
		var fs:Single = el.fontSize > 4 ? el.fontSize : 16;
		ImGui.pushFont(ImGui.getFont(), fs); var ts = ImGui.calcTextSize(raw); ImGui.popFont();
		return ts != null ? ts.x : 0;
	}

	function measureCanvasElementH(a:AuraDef, el:AuraCanvasElement):Float {
		if (el == null) return 0;
		if (el.kind != AuraCanvasElement.KIND_TEXT) return el.hAt(editState) > 1 ? el.hAt(editState) : 48;
		var raw = AuraVisualRenderer.formatTokens(el.content != null ? el.content : "", a, host.canvasPreview().stacks.get(), host.canvasPreview().counter.get(), el.wholeTime);
		var fs:Single = el.fontSize > 4 ? el.fontSize : 16;
		ImGui.pushFont(ImGui.getFont(), fs); var ts = ImGui.calcTextSize(raw); ImGui.popFont();
		return ts != null ? ts.y : fs;
	}

	function syncCanvasElementColor(a:AuraDef, el:AuraCanvasElement):Void {
		if (a == null || el == null || (a.id == lastCanvasColorAuraId && el == lastCanvasColorEl && el.colorAt(editState) == lastCanvasColorValue)) return;
		lastCanvasColorAuraId = a.id;
		lastCanvasColorSel = canvasSel;
		lastCanvasColorEl = el;
		var c = el.colorAt(editState);
		lastCanvasColorValue = c;
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
		lastCanvasColorValue = (al << 24) | (r << 16) | (g << 8) | b;
		return lastCanvasColorValue;
	}

}
