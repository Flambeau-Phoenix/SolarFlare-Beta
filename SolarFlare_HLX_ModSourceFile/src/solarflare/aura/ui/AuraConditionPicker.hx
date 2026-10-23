package solarflare.aura.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiKey;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Enums.ImGuiSelectableFlags;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiChildFlags;
import imgui.Structs.ImVec2;
import imgui.Structs.ImVec4;
import imgui.ref.BoolRef;
import solarflare.aura.signal.AuraConditionDef;
import solarflare.aura.signal.AuraConditionUiState;
import solarflare.aura.signal.AuraRuleEditorContext;
import solarflare.aura.signal.AuraConditionPickerModel;
import solarflare.aura.signal.AuraConditionPickerLayout;
import solarflare.aura.signal.AuraConditionPickerLayout.PickerLayoutCell;
import solarflare.aura.signal.AuraConditionPickerLayout.PickerLayoutRow;
import solarflare.ui.ByteUtil;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiChrome;
import solarflare.ui.UiScope;
import solarflare.ui.UiLayout;
import solarflare.ui.ThemePalette;
import solarflare.ui.HudChrome;

/** Owner-root modal: condition cards request it; their scrolling children never own its popup scope. */
class AuraConditionPicker {
	static inline var SEARCH_CAP:Int = 256;
	public var model(default, null):AuraConditionPickerModel = new AuraConditionPickerModel();
	var title:String;
	var visible = new BoolRef(false);
	var requested:Bool = false;
	var closeRequested:Bool = false;
	var focusSearch:Bool = false;
	var scrollHighlight:Bool = false;
	var search = new hl.Bytes(SEARCH_CAP);
	var groupLabels:Array<String> = [];
	var resultLabel:String = "";
	var cachedRevision:Int = -1;
	var groupComboOpen:Bool = false;
	var ownerValid:Void->Bool;
	var drawGroupsFn:Void->Void;
	var drawResultsFn:Void->Void;
	var lastX:Float = Math.NaN;
	var lastY:Float = Math.NaN;
	var lastW:Float = 1000;
	var lastH:Float = 700;
	var layout = new AuraConditionPickerLayout();
	var measureTextFn:String->Float;
	var searchActive:Bool = false;
	var honorNativeFocus:Bool = false;
	var focusGrid:Bool = false;
	var lastFont:imgui.ImGui.ImFont;
	var zero = new ImVec2();
	var childPadding = new ImVec2(8, 8);
	var cellSize = new ImVec2();
	var itemMin = new ImVec2();
	var itemMax = new ImVec2();
	var clipMin = new ImVec2();
	var clipMax = new ImVec2();
	var textPos = new ImVec2();
	var rowOrigin = new ImVec2();
	var measuredText = new ImVec2();
	var availableSpace = new ImVec2();
	var childSize = new ImVec2();
	var blend = new ImVec4();
	var cellBg:Int;
	var selectedBg:Int;
	var border:Int;
	var accent:Int;
	var text:Int;
	var muted:Int;
	public function new(ownerId:String, ownerValid:Void->Bool = null) {
		title = "Choose a condition###AuraConditionPicker." + ownerId; this.ownerValid = ownerValid; ByteUtil.clearBytes(search, SEARCH_CAP);
		drawGroupsFn = drawGroupSidebar; drawResultsFn = drawResults;
		measureTextFn = measureText;
	}
	public function isOpen():Bool return model.active || visible.get();
	public function request(context:AuraRuleEditorContext, condition:AuraConditionDef, ui:AuraConditionUiState):Void {
		var rule = context.rule; var contextValid = context.pickerOwnerValid; var snapshot = context.snapshot;
		if (!model.open(rule, condition, function() return context.rule == rule && (ownerValid == null || ownerValid())
			&& (contextValid == null || contextValid()), snapshot, function() {
			ui.sync(condition); ui.flashContext(); SettingsStore.markDirty();
		})) return;
		ByteUtil.clearBytes(search, SEARCH_CAP); visible.set(true); requested = true; closeRequested = false; focusSearch = true; scrollHighlight = true;
		groupComboOpen = false; focusGrid = false; lastX = lastY = Math.NaN;
	}
	public function cancel():Void {
		closeRequested = closeRequested || visible.get(); model.cancel(); visible.set(false); requested = false;
		groupComboOpen = false; focusGrid = false;
		ByteUtil.clearBytes(search, SEARCH_CAP);
	}
	public function draw():Void {
		if (!model.active && !closeRequested) return;
		if (model.active && (!CursorCaptureFix.cursorFree || !model.isValid())) cancel();
		if (requested) { ImGui.openPopup(title); requested = false; }
		var screenW:Single = HudChrome.viewportWidth; var screenH:Single = HudChrome.viewportHeight;
		var cx:Single = screenW * 0.5; var cy:Single = screenH * 0.5;
		var viewport = ImGui.getMainViewport();
		if (viewport != null) {
			var center = ImGui.ImGuiViewport_GetCenter(viewport);
			if (center != null) { cx = center.x; cy = center.y; }
		}
		var maxW:Single = Math.max(1, screenW - 64); var maxH:Single = Math.max(1, screenH - 64);
		var width:Single = Math.min(1000, maxW); var height:Single = Math.min(700, maxH);
		ImGui.setNextWindowSize(ImGui.vec2(width, height), ImGuiCond.Appearing);
		ImGui.setNextWindowPos(ImGui.vec2(cx - width * 0.5, cy - height * 0.5), ImGuiCond.Appearing);
		ImGui.setNextWindowSizeConstraints(ImGui.vec2(Math.min(520, maxW), Math.min(400, maxH)), ImGui.vec2(maxW, maxH));
		if (Math.isFinite(lastX) && Math.isFinite(lastY)) {
			var x:Single = Math.max(cx - screenW * 0.5 + 32, Math.min(lastX, cx + screenW * 0.5 - 32 - Math.min(lastW, maxW)));
			var y:Single = Math.max(cy - screenH * 0.5 + 32, Math.min(lastY, cy + screenH * 0.5 - 32 - Math.min(lastH, maxH)));
			if (x != lastX || y != lastY) ImGui.setNextWindowPos(ImGui.vec2(x, y), ImGuiCond.Always);
		}
		// Do not pass a false ref while closing: BeginPopupModal must run to close its active popup explicitly.
		if (closeRequested) visible.set(true);
		if (!ImGui.beginPopupModal(title, visible, ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse)) {
			if (!visible.get() || closeRequested) { model.cancel(); visible.set(false); closeRequested = false; }
			return;
		}
		try {
			var position = ImGui.getWindowPos(); var size = ImGui.getWindowSize();
			lastX = position.x; lastY = position.y; lastW = size.x; lastH = size.y;
			if (closeRequested || !visible.get() || !model.isValid() || ImGui.isKeyPressed(ImGuiKey.Escape, false)) finish();
			else drawContents();
		} catch (e:Dynamic) { ImGui.endPopup(); throw e; }
		ImGui.endPopup();
	}
	function finish():Void { ImGui.closeCurrentPopup(); model.cancel(); visible.set(false); closeRequested = false; requested = false; groupComboOpen = false; }
	function refreshLabels():Void {
		if (cachedRevision == model.revision) return;
		cachedRevision = model.revision; groupLabels.resize(0);
		for (i in 0...model.groups.length) groupLabels.push(model.groups[i] + " (" + model.groupCounts[i] + ")###condition_group_" + model.groups[i]);
		resultLabel = model.matches.length + " conditions" + (model.group == "" ? " across all groups" : " in " + model.group);
	}
	function drawContents():Void {
		if (focusSearch) { ImGui.setKeyboardFocusHere(); focusSearch = false; }
		ImGui.setNextItemWidth(-1);
		if (ImGui.inputTextWithHint("##condition_browser_search", "Search condition names, IDs, or groups...", search, SEARCH_CAP)) {
			model.setQuery(ByteUtil.readBytes(search, SEARCH_CAP)); scrollHighlight = true;
		}
		searchActive = ImGui.isItemActive();
		refreshLabels();
		var available = ImGui.getContentRegionAvail(availableSpace);
		var sidebar:Single = 200 * Math.max(1, ImGui.getTextLineHeight() / 13);
		// Preserve at least two readable result columns before spending width on navigation.
		var wide = available.x - sidebar - 12 - 32 >= AuraConditionPickerLayout.minimumWidth(ImGui.getTextLineHeight()) * 2 + 12;
		groupComboOpen = false;
		if (!wide) {
			ImGui.setNextItemWidth(-1);
			if (ImGui.beginCombo("##condition_browser_group", model.group == "" ? "All groups" : model.group)) {
				groupComboOpen = true;
				try { drawGroupChoices(true); } catch (e:Dynamic) { ImGui.endCombo(); throw e; }
				ImGui.endCombo();
			}
		}
		refreshLabels();
		var bodyHeight:Single = Math.max(32, ImGui.getContentRegionAvail().y - ImGui.getFrameHeightWithSpacing() - 12);
		if (wide) {
			childSize.x = sidebar; childSize.y = bodyHeight;
			UiScope.child("##condition_browser_groups", childSize, drawGroupsFn);
			ImGui.sameLine(0, 12);
		}
		childSize.x = 0; childSize.y = bodyHeight;
		ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, childPadding);
		ImGui.pushStyleVar(ImGuiStyleVar.ScrollbarSize, 16);
		ImGui.pushStyleColor(ImGuiCol.ChildBg, ThemePalette.current().windowBg);
		try {
			// A reserved scrollbar prevents column count from oscillating as content height changes.
			UiScope.child("##condition_browser_results", childSize, drawResultsFn, ImGuiChildFlags.AlwaysUseWindowPadding, ImGuiWindowFlags.AlwaysVerticalScrollbar);
		} catch (e:Dynamic) { ImGui.popStyleColor(); ImGui.popStyleVar(2); throw e; }
		ImGui.popStyleColor(); ImGui.popStyleVar(2);
		if (!model.active) return;
		ImGui.textDisabled(resultLabel);
		ImGui.sameLine();
		if (ImGui.smallButton("Close##condition_browser_close")) finish();
	}
	function drawGroupSidebar():Void drawGroupChoices(false);
	function drawGroupChoices(combo:Bool):Void {
		if (ImGui.selectable("All groups###condition_group_all", model.group == "", ImGuiSelectableFlags.NoAutoClosePopups)) {
			model.setGroup(""); scrollHighlight = true; if (combo) ImGui.closeCurrentPopup();
		}
		for (i in 0...model.groups.length) if (ImGui.selectable(groupLabels[i], model.group == model.groups[i], ImGuiSelectableFlags.NoAutoClosePopups)) {
			model.setGroup(model.groups[i]); scrollHighlight = true; if (combo) ImGui.closeCurrentPopup();
		}
	}
	function drawResults():Void {
		// Zero ItemSpacing makes selectable hit rectangles exact. Real Dummy items own all gutters.
		ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing, zero);
		try { drawGrid(); } catch (e:Dynamic) { ImGui.popStyleVar(); throw e; }
		ImGui.popStyleVar();
	}
	function measureText(value:String):Float return ImGui.calcTextSize(value, false, -1, measuredText).x;
	function drawGrid():Void {
		var font = ImGui.getFont();
		if (font != lastFont) { layout.invalidate(); lastFont = font; }
		var available = ImGui.getContentRegionAvail(availableSpace);
		var lineHeight:Single = Math.ceil(ImGui.getTextLineHeight());
		var count = UiLayout.columnCount(available.x, AuraConditionPickerLayout.minimumWidth(lineHeight), 3, 12);
		if (layout.rebuild(model, available.x, lineHeight, count, measureTextFn)) scrollHighlight = true;
		var moved = false;
		if (!groupComboOpen) {
			var dx = 0; var dy = 0;
			if (ImGui.isKeyPressed(ImGuiKey.DownArrow)) dy = 1;
			else if (ImGui.isKeyPressed(ImGuiKey.UpArrow)) dy = -1;
			else if (!searchActive && ImGui.isKeyPressed(ImGuiKey.RightArrow)) dx = 1;
			else if (!searchActive && ImGui.isKeyPressed(ImGuiKey.LeftArrow)) dx = -1;
			if (dx != 0 || dy != 0) {
				var index = layout.move(model.highlight, dx, dy);
				if (index >= 0) model.setHighlightById(layout.cells[index].id);
				moved = true; scrollHighlight = true; focusGrid = !searchActive;
			}
			if (searchActive && (ImGui.isKeyPressed(ImGuiKey.Enter, false) || ImGui.isKeyPressed(ImGuiKey.KeypadEnter, false))) {
				var d = model.highlighted(); if (d != null) { model.choose(d.id); finish(); return; }
			}
		}
		honorNativeFocus = !searchActive && !scrollHighlight && !moved && !focusGrid;
		if (scrollHighlight) {
			ImGui.setScrollY(layout.scrollTo(model.highlight, ImGui.getScrollY(), Math.max(1, ImGui.getWindowHeight() - 16)));
			scrollHighlight = false;
		}
		if (model.matches.length == 0) { ImGui.textWrapped("No conditions match. Try another search or choose All groups."); return; }
		var theme = ThemePalette.current();
		cellBg = ImGui.colorConvertFloat4ToU32(theme.cellBg);
		blend.x = theme.cellBg.x * 0.8 + theme.accent.x * 0.2;
		blend.y = theme.cellBg.y * 0.8 + theme.accent.y * 0.2;
		blend.z = theme.cellBg.z * 0.8 + theme.accent.z * 0.2; blend.w = 1;
		selectedBg = ImGui.colorConvertFloat4ToU32(blend);
		var delta = Math.abs(theme.border.x - theme.cellBg.x) + Math.abs(theme.border.y - theme.cellBg.y) + Math.abs(theme.border.z - theme.cellBg.z);
		border = ImGui.colorConvertFloat4ToU32(delta < 0.25 ? theme.textDisabled : theme.border);
		accent = ImGui.colorConvertFloat4ToU32(theme.accent);
		text = ImGui.colorConvertFloat4ToU32(theme.text); muted = ImGui.colorConvertFloat4ToU32(theme.textDisabled);
		for (i in 0...layout.rows.length) {
			var row = layout.rows[i];
			if (i > 0) { cellSize.x = 0; cellSize.y = 12; ImGui.dummy(cellSize); }
			cellSize.x = layout.width; cellSize.y = row.height;
			if (!ImGui.isRectVisible(cellSize)) { ImGui.dummy(cellSize); continue; }
			if (row.kind != "cells") { drawHeading(row); continue; }
			var picked = -1;
			ImGui.beginGroup();
			try {
				for (cell in row.cells) {
					if (cell.column > 0) ImGui.sameLine(0, 12);
					if (drawResultCell(cell)) picked = cell.matchIndex;
				}
			} catch (e:Dynamic) { ImGui.endGroup(); throw e; }
			ImGui.endGroup();
			if (picked >= 0) { model.choose(layout.cells[picked].id); finish(); return; }
		}
	}
	function drawHeading(row:PickerLayoutRow):Void {
		ImGui.getCursorScreenPos(rowOrigin);
		cellSize.x = layout.width; cellSize.y = row.height; ImGui.dummy(cellSize);
		var dl = ImGui.getWindowDrawList();
		textPos.x = rowOrigin.x + 8; textPos.y = rowOrigin.y + 4;
		for (line in row.lines) {
			ImGui.ImDrawList_AddText_Vec2(dl, textPos, row.kind == "heading" ? text : muted, line);
			textPos.y += layout.fontHeight;
		}
		if (row.kind == "heading") {
			clipMin.x = rowOrigin.x; clipMin.y = rowOrigin.y + row.height;
			clipMax.x = rowOrigin.x + layout.width; clipMax.y = clipMin.y;
			ImGui.ImDrawList_AddLine(dl, clipMin, clipMax, border, 1);
		}
	}
	function drawResultCell(cell:PickerLayoutCell):Bool {
		var entry = model.entries[model.matches[cell.matchIndex]];
		if (focusGrid && cell.matchIndex == model.highlight) { ImGui.setKeyboardFocusHere(); focusGrid = false; }
		cellSize.x = cell.width; cellSize.y = cell.height;
		var clicked = ImGui.selectable(entry.hitLabel, cell.matchIndex == model.highlight, ImGuiSelectableFlags.NoAutoClosePopups, cellSize);
		var hovered = ImGui.isItemHovered(); var focused = ImGui.isItemFocused();
		ImGui.getItemRectMin(itemMin); ImGui.getItemRectMax(itemMax);
		if (focused && honorNativeFocus) model.setHighlightById(cell.id);
		var selected = cell.matchIndex == model.highlight;
		var dl = ImGui.getWindowDrawList();
		ImGui.ImDrawList_AddRectFilled(dl, itemMin, itemMax, selected || hovered ? selectedBg : cellBg, 4);
		ImGui.ImDrawList_AddRect(dl, itemMin, itemMax, selected || hovered || focused ? accent : border, 4, 1);
		clipMin.x = itemMin.x + 8; clipMin.y = itemMin.y + 8;
		clipMax.x = itemMax.x - 8; clipMax.y = itemMax.y - 8;
		ImGui.ImDrawList_PushClipRect(dl, clipMin, clipMax, true);
		try {
			textPos.x = clipMin.x; textPos.y = clipMin.y;
			for (line in cell.lines) { ImGui.ImDrawList_AddText_Vec2(dl, textPos, text, line); textPos.y += layout.fontHeight; }
			textPos.y += 4;
			ImGui.ImDrawList_AddText_Vec2(dl, textPos, muted, model.target != null && model.target.signal == cell.id ? entry.currentCaption : entry.typeCaption);
		} catch (e:Dynamic) { ImGui.ImDrawList_PopClipRect(dl); throw e; }
		ImGui.ImDrawList_PopClipRect(dl);
		if (hovered || focused) ImGui.setTooltip(entry.tooltip);
		return clicked;
	}
}
