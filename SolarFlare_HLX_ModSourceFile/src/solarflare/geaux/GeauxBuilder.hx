package solarflare.geaux;

import haxe.Json;
import solarflare.ui.ToolWindow;
import solarflare.ui.UiChrome;
import solarflare.ui.GameIcons;
import solarflare.ui.SettingsStore;
import solarflare.ui.ByteUtil;
import solarflare.ui.ConfigPanel;
import solarflare.ui.FeatureProfiles;
import solarflare.ui.SearchBar;
import solarflare.ui.UndoManager;
import solarflare.ui.ToastManager;
import solarflare.ui.DragDropHelper;
import solarflare.ui.ContextMenuSystem;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.UiActionQueue;
import solarflare.ui.UiActionQueue.UiActionKind;
import solarflare.geaux.GeauxConfig.GeauxStyle;
import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiChildFlags;
import imgui.ref.BoolRef;

/**
 * Floating Geaux action-bar designer — single full-height workspace (no tabs).
 */
class GeauxBuilder {
	public var open = new BoolRef(false);
	var cfg:GeauxConfig;
	var host:ConfigPanel;
	var preview:GeauxBar;
	var selected:Int = -1;
	var swapMode:Bool = false;

	var searchBar = new SearchBar("Search skills & prayers...", 128);
	var search:String = "";
	var categoryFilter:String = "All";
	var undoMgr = new UndoManager<Dynamic>(30);

	static inline var DIAG_CAP:Int = 8192;
	var diagBuf = new hl.Bytes(DIAG_CAP);
	var diagRevision:Int = -1;
	var layoutRevision:Int = 0;
	var showDiag:Bool = false;
	var assignPopupCell:Int = -1;
	var assignSearch = new SearchBar("Filter skills to assign...", 96);

	public function new(cfg:GeauxConfig, host:ConfigPanel) {
		this.cfg = cfg;
		this.host = host;
		preview = new GeauxBar();
		ByteUtil.clearBytes(diagBuf, DIAG_CAP);
	}

	public function clearTransientState():Void {
		selected = -1;
		swapMode = false;
	}

	public function applyExternalLayout(snap:Dynamic, actionName:String):Void {
		if (cfg == null || snap == null)
			return;
		snapshot(actionName);
		cfg.applyLayout(snap);
		selected = -1;
		swapMode = false;
		bumpRevision();
		SettingsStore.markDirty();
	}

	function bumpRevision():Void layoutRevision++;

	function snapshot(actionName:String):Void {
		if (cfg != null)
			undoMgr.push(actionName, cfg.dumpLayout());
	}

	function applySnapshot(snap:Dynamic):Void {
		if (cfg != null && snap != null) {
			cfg.applyLayout(snap);
			selected = -1;
			swapMode = false;
			bumpRevision();
			SettingsStore.markDirty();
		}
	}

	public function draw():Void {
		if (!open.get() || cfg == null) {
			clearTransientState();
			return;
		}
		if (!CursorCaptureFix.cursorFree)
			return;

		cfg.ensureSlots();
		if (selected >= cfg.visibleCount()) {
			selected = -1;
			swapMode = false;
		}

		var vis = ToolWindow.begin("Geaux Builder###SolarFlare.GeauxBuilder", open, 1400, 900, 0, false);
		if (vis) {
			drawTopToolbar();
			ImGui.separator();

			var avail = ImGui.getContentRegionAvail();
			var leftW:Single = 320;
			var rightW:Single = 340;
			var midW:Single = avail.x - leftW - rightW - 16;
			if (midW < 280) midW = 280;
			var paneH:Single = avail.y - 4;
			if (paneH < 400) paneH = 400;

			UiChrome.celChild("##gb_left", ImGui.vec2(leftW, paneH), drawLeftControls);
			ImGui.sameLine();
			UiChrome.celChild("##gb_mid", ImGui.vec2(midW, paneH), drawCenterPreview);
			ImGui.sameLine();
			UiChrome.celChild("##gb_right", ImGui.vec2(0, paneH), drawRightCatalog);
		}
		ToolWindow.end();
	}

	function drawTopToolbar():Void {
		if (ImGui.checkbox("Show Geaux grid##gb_enabled", cfg.enabled)) {
			SettingsStore.markDirty();
			ToastManager.info(cfg.enabled.get() ? "Geaux bar enabled" : "Geaux bar hidden");
		}

		ImGui.sameLine();
		if (ImGui.checkbox("Lock Bar##gb_top_lock", cfg.chrome.locked)) SettingsStore.markDirty();
		ImGui.sameLine();
		FeatureProfiles.drawToolbar(host, "geaux", "geaux_builder");

		ImGui.sameLine(0, 14);
		if (!undoMgr.canUndo()) ImGui.beginDisabled();
		if (UiChrome.ghostButton("Undo##gb_undo")) {
			var snap = undoMgr.undo(cfg.dumpLayout());
			if (snap != null) applySnapshot(snap);
		}
		if (!undoMgr.canUndo()) ImGui.endDisabled();

		ImGui.sameLine();
		if (!undoMgr.canRedo()) ImGui.beginDisabled();
		if (UiChrome.ghostButton("Redo##gb_redo")) {
			var snap = undoMgr.redo(cfg.dumpLayout());
			if (snap != null) applySnapshot(snap);
		}
		if (!undoMgr.canRedo()) ImGui.endDisabled();

		ImGui.sameLine(0, 14);
		if (UiChrome.accentButton("Save##gb_save_now")) {
			cfg.ensureSlots();
			cfg.syncHotkeyBuffers();
			UiActionQueue.save();
		}
		ImGui.sameLine();
		if (UiChrome.ghostButton("Copy JSON##gb_export"))
			UiActionQueue.enqueue(UiActionKind.ExportGeauxClipboard);
		ImGui.sameLine();
		if (UiChrome.ghostButton("Import JSON##gb_import"))
			UiActionQueue.enqueue(UiActionKind.ImportGeauxClipboard);
		ImGui.sameLine();
		if (ImGui.smallButton(showDiag ? "Hide JSON##gb_diag_tog" : "Diagnostics##gb_diag_tog"))
			showDiag = !showDiag;
	}

	function drawLeftControls():Void {
		UiChrome.sectionHeader("Grid & Slots");

		if (ImGui.sliderInt("Rows##gb_rows", cfg.rows, GeauxConfig.MIN_DIM, GeauxConfig.MAX_DIM)) {
			if (ImGui.isItemDeactivatedAfterEdit())
				snapshot("Resize Rows");
			cfg.sizeDirty = true;
			cfg.ensureSlots();
			GeauxCache.markLayoutDirty();
			bumpRevision();
			SettingsStore.markDirty();
		}
		if (ImGui.sliderInt("Columns##gb_cols", cfg.cols, GeauxConfig.MIN_DIM, GeauxConfig.MAX_DIM)) {
			if (ImGui.isItemDeactivatedAfterEdit())
				snapshot("Resize Columns");
			cfg.sizeDirty = true;
			cfg.ensureSlots();
			GeauxCache.markLayoutDirty();
			bumpRevision();
			SettingsStore.markDirty();
		}

		UiChrome.subHeader("Quick Presets");
		var presets = [
			{label: "1x4", r: 1, c: 4},
			{label: "1x6", r: 1, c: 6},
			{label: "2x3", r: 2, c: 3},
			{label: "2x4", r: 2, c: 4},
			{label: "2x5", r: 2, c: 5},
			{label: "3x4", r: 3, c: 4}
		];
		for (p in 0...presets.length) {
			if (p > 0 && p % 3 != 0) ImGui.sameLine();
			var item = presets[p];
			if (UiChrome.accentButton(item.label + "##gb_preset_" + p, ImGui.vec2(80, 28))) {
				snapshot('Preset ${item.label}');
				cfg.rows.set(item.r);
				cfg.cols.set(item.c);
				cfg.sizeDirty = true;
				cfg.ensureSlots();
				GeauxCache.markLayoutDirty();
				bumpRevision();
				SettingsStore.markDirty();
				ToastManager.info('Applied layout ${item.label}');
			}
		}

		UiChrome.sectionHeader("Selected Slot");
		if (selected >= 0 && selected < cfg.visibleCount()) {
			var currentSkill = cfg.slotIds[selected];
			ImGui.text('Slot #${selected + 1}: ${currentSkill.length > 0 ? currentSkill : "Empty"}');
			if (UiChrome.ghostButton("Clear Slot##gb_clear_slot")) {
				snapshot("Clear Slot");
				cfg.clearCell(selected);
				bumpRevision();
				ToastManager.info('Slot #${selected + 1} cleared.');
			}
			ImGui.sameLine();
			if (UiChrome.accentButton(swapMode ? "Cancel Swap##gb_swap" : "Swap Mode##gb_swap")) {
				swapMode = !swapMode;
				ToastManager.info(swapMode ? "Click another cell to swap" : "Swap cancelled");
			}
			ImGui.separator();
			cfg.drawHotkeyAssignment(selected);
		} else {
			ImGui.textDisabled("Click a cell in the preview to configure it.");
		}

		UiChrome.sectionHeader("Looks");
		var style = cfg.style != null ? cfg.style : (cfg.style = new GeauxStyle());

		UiChrome.subHeader("Layout (match in-game bar)");
		if (solarflare.ui.BuilderSlider.draw("Outer Padding##gb_st_pad", style.padding, 0, 32, "%.0f px")) {
			cfg.sizeDirty = true;
			SettingsStore.markDirty();
		}
		if (solarflare.ui.BuilderSlider.draw("Cell Gap##gb_st_gap", style.gap, 0, 24, "%.0f px"))
			SettingsStore.markDirty();
		if (solarflare.ui.BuilderSlider.draw("Cell Border##gb_st_border", style.border, 0, 6, "%.1f px"))
			SettingsStore.markDirty();
		if (solarflare.ui.BuilderSlider.draw("Cell Rounding##gb_st_round", style.rounding, 0, 16, "%.0f px"))
			SettingsStore.markDirty();
		if (solarflare.ui.BuilderSlider.draw("Icon Scale##gb_st_glyph", style.glyphScale, 0.5, 1.4, "%.2f"))
			SettingsStore.markDirty();
		if (solarflare.ui.BuilderSlider.draw("Window Alpha##gb_st_alpha", style.bgAlpha, 0, 1, "%.2f"))
			SettingsStore.markDirty();

		UiChrome.subHeader("Bar Size");
		if (solarflare.ui.BuilderSlider.draw("Width##gb_st_w", cfg.width, GeauxConfig.MIN_W, GeauxConfig.MAX_W, "%.0f px")) {
			cfg.sizeDirty = true;
			SettingsStore.markDirty();
		}
		if (solarflare.ui.BuilderSlider.draw("Height##gb_st_h", cfg.height, GeauxConfig.MIN_H, GeauxConfig.MAX_H, "%.0f px")) {
			cfg.sizeDirty = true;
			SettingsStore.markDirty();
		}
		ImGui.textDisabled('Grid ${cfg.rows.get()}x${cfg.cols.get()} · cells grow to fill the bar.');

		UiChrome.subHeader("Overlays");
		if (ImGui.checkbox("Cooldown Pinwheel##gb_st_pin", style.showPinwheel))
			SettingsStore.markDirty();
		if (ImGui.checkbox("Cooldown Seconds##gb_st_cd", style.showCdText))
			SettingsStore.markDirty();
		if (ImGui.checkbox("Keybind Chips##gb_st_hk", style.showHotkeys))
			SettingsStore.markDirty();
		if (ImGui.checkbox("Group Tags##gb_st_tags", style.showGroupTags))
			SettingsStore.markDirty();

		UiChrome.subHeader("On Cooldown");
		var cdMode = style.effectiveCdDisplay();
		var cdLabel = switch (cdMode) {
			case GeauxStyle.CD_HIDE: "Hide while on cooldown";
			case GeauxStyle.CD_SHOW_FULL: "Always show (no dim)";
			default: "Show + dim on cooldown";
		};
		if (ImGui.beginCombo("##gb_cd_display", cdLabel)) {
			if (ImGui.selectable("Show + dim on cooldown##gb_cd_dim", cdMode == GeauxStyle.CD_SHOW_DIM)) {
				style.cdDisplay.set(GeauxStyle.CD_SHOW_DIM);
				style.dimOnCd.set(true);
				SettingsStore.markDirty();
			}
			if (ImGui.selectable("Hide while on cooldown##gb_cd_hide", cdMode == GeauxStyle.CD_HIDE)) {
				style.cdDisplay.set(GeauxStyle.CD_HIDE);
				style.dimOnCd.set(false);
				SettingsStore.markDirty();
			}
			if (ImGui.selectable("Always show (no dim)##gb_cd_full", cdMode == GeauxStyle.CD_SHOW_FULL)) {
				style.cdDisplay.set(GeauxStyle.CD_SHOW_FULL);
				style.dimOnCd.set(false);
				SettingsStore.markDirty();
			}
			ImGui.endCombo();
		}
		if (ImGui.checkbox("Dim when lacking resources##gb_st_dimnores", style.dimOnNoResource))
			SettingsStore.markDirty();

		if (ImGui.checkbox("Lock Bar##gb_st_lock", cfg.chrome.locked))
			SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.checkbox("Transparent##gb_st_trans", cfg.chrome.transparent))
			SettingsStore.markDirty();

		if (showDiag) {
			UiChrome.sectionHeader("Diagnostics");
			if (diagRevision != layoutRevision) {
				diagRevision = layoutRevision;
				var json = try Json.stringify(cfg.dumpLayout(), null, "  ") catch (e:Dynamic) 'Error: $e';
				ByteUtil.clearBytes(diagBuf, DIAG_CAP);
				ByteUtil.fillBuf(diagBuf, DIAG_CAP, json);
			}
			ImGui.inputTextMultiline("##gb_diag_json", diagBuf, DIAG_CAP, ImGui.vec2(-1, 120));
			if (ImGui.button("Copy Diagnostics##gb_diag_copy"))
				UiActionQueue.copyText(ByteUtil.readBytes(diagBuf, DIAG_CAP), "Diagnostics JSON copied");
		}
	}

	function drawCenterPreview():Void {
		UiChrome.sectionHeader("Interactive Grid");
		ImGui.textDisabled("Click = select. Drag = swap cells. Drop catalog skills. Right-click = assign.");
		ImGui.spacing();
		preview.drawPreview(cfg, function(clickedIdx:Int) {
			if (swapMode && selected >= 0 && selected != clickedIdx) {
				snapshot("Swap Cells");
				cfg.swapCells(selected, clickedIdx);
				swapMode = false;
				selected = clickedIdx;
				bumpRevision();
				preview.flashCell(clickedIdx);
				ToastManager.success("Cells swapped!");
			} else {
				selected = clickedIdx;
				swapMode = false;
			}
		}, selected, true, function(idx:Int, skillId:String) {
			snapshot("DnD Assign Skill");
			cfg.assignCell(idx, skillId);
			selected = idx;
			bumpRevision();
			preview.flashCell(idx);
			ToastManager.success('Assigned $skillId to slot #${idx + 1}');
		}, function(fromIdx:Int, toIdx:Int) {
			snapshot("DnD Swap Cells");
			cfg.swapCells(fromIdx, toIdx);
			selected = toIdx;
			bumpRevision();
			preview.flashCell(fromIdx);
			preview.flashCell(toIdx);
			ToastManager.success("Cells swapped!");
		}, function(idx:Int) {
			selected = idx;
			assignPopupCell = idx;
			ImGui.openPopup("##gb_assign_cell");
		});

		drawAssignPopup();
	}

	function drawAssignPopup():Void {
		ImGui.setNextWindowSize(ImGui.vec2(320, 400), imgui.Enums.ImGuiCond.Appearing);
		if (!ImGui.beginPopup("##gb_assign_cell"))
			return;

		var cell = assignPopupCell;
		UiChrome.subHeader(cell >= 0 ? 'Assign to slot #${cell + 1}' : "Assign skill");
		var q = assignSearch.draw("##gb_assign_search");
		ImGui.separator();

		if (cell >= 0 && cell < cfg.visibleCount()) {
			if (UiChrome.ghostButton("Clear Slot##gb_pop_clear", ImGui.vec2(-1, 28))) {
				snapshot("Clear Slot");
				cfg.clearCell(cell);
				bumpRevision();
				ImGui.closeCurrentPopup();
			}
			ImGui.separator();
		}

		ImGui.beginChild("##gb_assign_list", ImGui.vec2(0, 0), 0);
		var skills = getFilteredSkills();
		if (q.length > 0) {
			var ql = q.toLowerCase();
			skills = skills.filter(s ->
				s.id.toLowerCase().indexOf(ql) >= 0
				|| (s.label != null && s.label.toLowerCase().indexOf(ql) >= 0));
		}
		for (skill in skills) {
			ImGui.pushID_Str("ap_" + skill.id);
			var label = skill.label != null && skill.label.length > 0 ? skill.label : skill.id;
			if (ImGui.selectable(label + "##asg")) {
				if (cell >= 0 && cell < cfg.visibleCount()) {
					snapshot('Assign $label');
					cfg.assignCell(cell, skill.id);
					selected = cell;
					bumpRevision();
					preview.flashCell(cell);
					ToastManager.success('Assigned $label to slot #${cell + 1}');
				}
				ImGui.closeCurrentPopup();
			}
			ImGui.popID();
		}
		ImGui.endChild();
		ImGui.endPopup();
	}

	function drawRightCatalog():Void {
		UiChrome.sectionHeader("Skill Catalog");
		search = searchBar.draw("##gb_cat_search");

		var categories = ["All", "Weapons", "Prayers", "Signatures"];
		for (c in 0...categories.length) {
			if (c > 0) ImGui.sameLine();
			var cat = categories[c];
			if (ImGui.selectable(cat + "##gb_cat_" + c, categoryFilter == cat, 0, ImGui.vec2(72, 22)))
				categoryFilter = cat;
		}

		var skills = getFilteredSkills();
		var total = countCatalogSkills();
		ImGui.textDisabled('Showing ${skills.length} of $total skills');
		ImGui.separator();

		if (skills.length == 0) {
			ImGui.textDisabled("No matching skills.");
			return;
		}

		ImGui.beginChild("##gb_cat_scroll", ImGui.vec2(0, 0), 0);
		for (i in 0...skills.length) {
			var skill = skills[i];
			var isAssigned = cfg.slotIds.indexOf(skill.id) >= 0;
			ImGui.pushID_Str(skill.id);

			var label = skill.label != null && skill.label.length > 0 ? skill.label : skill.id;
			var rowH:Single = 34;
			var rowPos = ImGui.getCursorScreenPos();
			var rowW = ImGui.getContentRegionAvail().x;
			var selectedHere = selected >= 0 && selected < cfg.slotIds.length && cfg.slotIds[selected] == skill.id;

			if (ImGui.selectable("##gb_sk_row", selectedHere, 0, ImGui.vec2(rowW - 88, rowH))) {
				if (selected >= 0)
					assignSkill(skill.id);
				else
					assignSkillEmpty(skill.id);
			}
			if (DragDropHelper.beginSkillDrag(skill.id, label))
				DragDropHelper.endSkillDrag();

			ContextMenuSystem.openForItem("##gb_sk_ctx");
			if (ContextMenuSystem.begin("##gb_sk_ctx")) {
				if (ContextMenuSystem.menuItem("Assign to selected slot"))
					assignSkill(skill.id);
				if (ContextMenuSystem.menuItem("Assign to first empty slot"))
					assignSkillEmpty(skill.id);
				if (ContextMenuSystem.menuItem("Copy ID"))
					UiActionQueue.copyText(skill.id, "Skill ID copied");
				ContextMenuSystem.end();
			}

			var dl = ImGui.getWindowDrawList();
			var iconSize:Single = 28;
			GameIcons.draw(dl, GameIcons.get(skill.id), rowPos.x + 4, rowPos.y + (rowH - iconSize) * 0.5, iconSize);
			var textCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.92, 0.90, 0.84, 1.0));
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(rowPos.x + iconSize + 12, rowPos.y + (rowH - ImGui.getFontSize()) * 0.5), textCol, label);
			if (isAssigned) {
				var tag = "In Bar";
				var ts = ImGui.calcTextSize(tag);
				ImGui.ImDrawList_AddText_Vec2(dl,
					ImGui.vec2(rowPos.x + rowW - 88 - ts.x - 8, rowPos.y + (rowH - ts.y) * 0.5),
					ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.4, 0.85, 0.4, 1.0)), tag);
			}

			ImGui.sameLine(0, 6);
			ImGui.setCursorPosY(ImGui.getCursorPosY() + (rowH - 28) * 0.5);
			if (UiChrome.accentButton("Assign##asn", ImGui.vec2(78, 28)))
				assignSkill(skill.id);

			ImGui.popID();
		}
		ImGui.endChild();
	}

	function assignSkill(skillId:String):Void {
		if (selected >= 0 && selected < cfg.visibleCount()) {
			snapshot('Assign to #${selected + 1}');
			cfg.assignCell(selected, skillId);
			bumpRevision();
			preview.flashCell(selected);
			ToastManager.success('Assigned $skillId to slot #${selected + 1}');
		} else {
			assignSkillEmpty(skillId);
		}
	}

	function assignSkillEmpty(skillId:String):Void {
		var emptyIdx = cfg.slotIds.indexOf("");
		if (emptyIdx >= 0 && emptyIdx < cfg.visibleCount()) {
			snapshot('Auto-Assign $skillId');
			cfg.assignCell(emptyIdx, skillId);
			selected = emptyIdx;
			bumpRevision();
			preview.flashCell(emptyIdx);
			ToastManager.success('Assigned $skillId to slot #${emptyIdx + 1}');
		} else {
			ToastManager.warn("Select a slot first, or free an empty cell.");
		}
	}

	function countCatalogSkills():Int {
		var n = 0;
		var seen = new Map<String, Bool>();
		for (s in GeauxCache.weapons) {
			if (s != null && s.id != null && s.id.length > 0 && !seen.exists(s.id)) {
				seen.set(s.id, true);
				n++;
			}
		}
		for (bid in GeauxCache.bookIds) {
			if (bid != null && bid.length > 0 && !seen.exists(bid)) {
				seen.set(bid, true);
				n++;
			}
		}
		return n;
	}

	function getFilteredSkills():Array<{id:String, label:String, group:String}> {
		var list:Array<{id:String, label:String, group:String}> = [];
		var seen = new Map<String, Bool>();

		for (s in GeauxCache.weapons) {
			if (s != null && s.id != null && s.id.length > 0 && !seen.exists(s.id)) {
				seen.set(s.id, true);
				list.push({
					id: s.id,
					label: s.label != null && s.label.length > 0 ? s.label : s.id,
					group: s.group != null ? s.group : "WEAPON"
				});
			}
		}
		for (i in 0...GeauxCache.bookIds.length) {
			var bid = GeauxCache.bookIds[i];
			if (bid != null && bid.length > 0 && !seen.exists(bid)) {
				seen.set(bid, true);
				list.push({
					id: bid,
					label: i < GeauxCache.bookLabels.length ? GeauxCache.bookLabels[i] : bid,
					group: i < GeauxCache.bookGroups.length ? GeauxCache.bookGroups[i] : "SKILL"
				});
			}
		}
		if (categoryFilter != "All") {
			list = list.filter(item -> {
				if (categoryFilter == "Weapons") return item.group == "WEAPON" || item.group == "BAR";
				if (categoryFilter == "Prayers") return item.group == "PRAYER" || item.group == "PR";
				if (categoryFilter == "Signatures") return item.group == "SIG" || item.group == "SIGNATURE";
				return true;
			});
		}
		if (search.length > 0) {
			var q = search.toLowerCase();
			list = list.filter(item ->
				item.id.toLowerCase().indexOf(q) >= 0
				|| (item.label != null && item.label.toLowerCase().indexOf(q) >= 0));
		}
		return list;
	}
}
