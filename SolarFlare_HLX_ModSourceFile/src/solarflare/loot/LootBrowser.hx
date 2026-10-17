package solarflare.loot;

import imgui.ImGui;
import imgui.Enums.ImGuiChildFlags;
import imgui.ref.BoolRef;
import solarflare.cdb.LootCatalog;
import solarflare.cdb.LootCatalog.LootBoss;
import solarflare.cdb.LootCatalog.LootItem;
import solarflare.cdb.LootCatalog.LootRow;
import solarflare.cdb.LootCatalog.LootTable;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.EditorWindow;
import solarflare.ui.GameIcons;
import solarflare.ui.ImGuiLists;
import solarflare.ui.SearchBar;
import solarflare.ui.ThemePalette;
import solarflare.ui.UiActionQueue;
import solarflare.ui.UiChrome;
import solarflare.ui.UiLayout;
import solarflare.ui.UiScope;

/**
 * Searchable browser for the CDB loot tables: every item with its portrait, every table with its drops, and an
 * AtlasLoot-style boss page (normal/heroic drops per boss).
 * Data comes from LootCatalog (baked in the build); thumbnails come from the lazily loaded atlas_loot sheet.
 * Filtering runs in observe() on an edge (query/filter/view change); draw() reads the frozen result lists.
 */
class LootBrowser {
	static inline var SHEET:String = "atlas_loot";
	static inline var VIEW_ITEMS:Int = 0;
	static inline var VIEW_TABLES:Int = 1;
	static inline var VIEW_BOSSES:Int = 2;
	static inline var ROW_H:Single = 44;
	static inline var CARD_H:Single = 46;
	static inline var BIG_THUMB:Single = 96;

	// Rarity is a game-defined colour language (ABGR for ImGui), so it is not themed.
	static inline var C_COMMON:Int = 0xFFB8B8B8;
	static inline var C_UNCOMMON:Int = 0xFF5AC84C;
	static inline var C_RARE:Int = 0xFFFF9A4C;
	static inline var C_EPIC:Int = 0xFFE65CB0;
	static inline var C_LEGENDARY:Int = 0xFF2E9AFF;

	public var open = new BoolRef(false);

	var search = new SearchBar("Search items, tables, units...", 96);
	var query:String = "";
	var view:Int = VIEW_ITEMS;
	var rarity:String = "";
	var itemType:String = "";
	var rollMode:String = "";
	var family:String = "";
	/** Boss page difficulty; falls back to Normal for a boss with no heroic table. */
	var heroic = true;
	var itemHits:Array<LootItem> = [];
	var tableHits:Array<LootTable> = [];
	var bossHits:Array<LootBoss> = [];
	var selItem:LootItem = null;
	var selTable:LootTable = null;
	var selBoss:LootBoss = null;
	var dirty = true;
	var sheetRequested = false;
	/** Set by a jump; resolved to a list row once the next rebuild has placed the selection. */
	var pendingScroll = false;
	var scrollRow:Int = -1;
	var statusText:String = "";

	var rarityOptions:Array<String>;
	var typeOptions:Array<String>;
	var familyOptions:Array<String>;
	var modeOptions:Array<String> = ["", "weighted", "independent"];
	var bodyFn:Void->Void;
	var listFn:Void->Void;
	var detailFn:Void->Void;
	var barFn:Int->Single->Void;
	var itemRowFn:Int->Void;
	var tableRowFn:Int->Void;
	var bossRowFn:Int->Void;
	var rarityLabelFn:String->String;
	var typeLabelFn:String->String;
	var modeLabelFn:String->String;
	var familyLabelFn:String->String;

	public function new() {
		LootCatalog.keep();
		rarityOptions = [""].concat(LootCatalog.rarities);
		typeOptions = [""].concat(LootCatalog.types);
		familyOptions = [""].concat(LootCatalog.families);
		bodyFn = drawBody;
		listFn = drawList;
		detailFn = drawDetail;
		barFn = drawBarCell;
		itemRowFn = drawItemRow;
		tableRowFn = drawTableRow;
		bossRowFn = drawBossRow;
		rarityLabelFn = function(s:String) return s == "" ? "Any rarity" : s;
		typeLabelFn = function(s:String) return s == "" ? "Any type" : s;
		modeLabelFn = function(s:String) return s == "" ? "Any roll mode" : (s == "weighted" ? "Weighted pick" : "Independent rolls");
		familyLabelFn = function(s:String) return s == "" ? "Any creature" : s;
	}

	// ---------------------------------------------------------------------------------------------
	// Observe: texture load and filtering (never from draw)
	// ---------------------------------------------------------------------------------------------

	public function observe():Void {
		if (!open.get())
			return;
		if (!sheetRequested) {
			sheetRequested = true;
			GameIcons.ensureSheet(SHEET);
			dirty = true;
		}
		if (!dirty)
			return;
		dirty = false;
		rebuild();
	}

	function rebuild():Void {
		var tokens = query.split(" ").filter(function(t) return t.length > 0);
		itemHits = [];
		for (item in LootCatalog.items) {
			if ((rarity != "" && item.rarity != rarity) || (itemType != "" && item.type != itemType))
				continue;
			if (matches(item.haystack, tokens))
				itemHits.push(item);
		}
		tableHits = [];
		for (table in LootCatalog.tables) {
			if ((rollMode == "weighted" && !table.weighted) || (rollMode == "independent" && table.weighted))
				continue;
			if (matches(table.haystack, tokens))
				tableHits.push(table);
		}
		bossHits = [];
		for (boss in LootCatalog.bosses) {
			if (family != "" && boss.family != family)
				continue;
			if (matches(boss.haystack, tokens))
				bossHits.push(boss);
		}
		if (selItem == null && itemHits.length > 0)
			selItem = itemHits[0];
		if (selBoss == null && bossHits.length > 0)
			selBoss = bossHits[0];
		if (selTable == null && tableHits.length > 0)
			selTable = tableHits[0];
		if (pendingScroll) {
			pendingScroll = false;
			scrollRow = view == VIEW_ITEMS ? itemHits.indexOf(selItem) : (view == VIEW_TABLES ? tableHits.indexOf(selTable) : bossHits.indexOf(selBoss));
		}
		var thumbs = firstArt() == "" || GameIcons.hasKey(firstArt()) ? "thumbnails ready" : "thumbnails unavailable (atlas_loot.png not found)";
		statusText = switch (view) {
			case VIEW_ITEMS: itemHits.length + " of " + LootCatalog.items.length + " items | " + LootCatalog.tables.length + " loot tables | " + thumbs;
			case VIEW_TABLES: tableHits.length + " of " + LootCatalog.tables.length + " loot tables | " + LootCatalog.items.length + " items | " + thumbs;
			default: bossHits.length + " of " + LootCatalog.bosses.length + " bosses | " + thumbs;
		}
	}

	static function firstArt():String {
		for (item in LootCatalog.items)
			if (item.art != "")
				return item.art;
		return "";
	}

	static function matches(haystack:String, tokens:Array<String>):Bool {
		for (t in tokens)
			if (haystack.indexOf(t) < 0)
				return false;
		return true;
	}

	function setView(v:Int):Void {
		if (v == view)
			return;
		view = v;
		dirty = true;
	}

	function clearFilters():Void {
		query = "";
		search.clear();
		rarity = "";
		itemType = "";
		rollMode = "";
		family = "";
	}

	function jumpItem(id:String):Void {
		var item = LootCatalog.item(id);
		if (item == null)
			return;
		clearFilters();
		view = VIEW_ITEMS;
		selItem = item;
		pendingScroll = true;
		dirty = true;
	}

	function jumpTable(id:String):Void {
		var table = LootCatalog.table(id);
		if (table == null)
			return;
		clearFilters();
		view = VIEW_TABLES;
		selTable = table;
		pendingScroll = true;
		dirty = true;
	}

	/** Called from ConfigPanel.closeInteractiveWindowsImpl on camera entry. */
	public function clearTransientState():Void {
		clearFilters();
		pendingScroll = false;
		scrollRow = -1;
		dirty = true;
	}

	// ---------------------------------------------------------------------------------------------
	// Draw
	// ---------------------------------------------------------------------------------------------

	public function draw():Void {
		if (!open.get() || !CursorCaptureFix.cursorFree)
			return;
		EditorWindow.drawMenuWindow("Loot Browser###SolarFlare.LootBrowser", open, 980, 640, bodyFn, false, true);
	}

	function drawBody():Void {
		ImGui.textDisabled(statusText);
		ImGui.setNextItemWidth(Math.max(120, ImGui.getContentRegionAvail().x - 36));
		var q = search.draw("##loot_search");
		if (q != query) {
			query = q;
			dirty = true;
		}
		UiLayout.inlineSplit("##loot_bar", 5, barFn, 6);
		UiChrome.gap(UiChrome.SP_S);
		var avail = ImGui.getContentRegionAvail();
		var leftW:Single = Math.max(280, Math.min(420, avail.x * 0.42));
		UiScope.child("##loot_list", ImGui.vec2(leftW, avail.y), listFn, ImGuiChildFlags.Borders);
		ImGui.sameLine();
		UiScope.child("##loot_detail", ImGui.vec2(0, avail.y), detailFn, ImGuiChildFlags.Borders);
	}

	function drawBarCell(i:Int, w:Single):Void {
		switch (i) {
			case 0:
				if (UiChrome.navButton("Items##loot_view_items", view == VIEW_ITEMS, ImGui.vec2(w, 28)))
					setView(VIEW_ITEMS);
			case 1:
				if (UiChrome.navButton("Loot tables##loot_view_tables", view == VIEW_TABLES, ImGui.vec2(w, 28)))
					setView(VIEW_TABLES);
			case 2:
				if (UiChrome.navButton("Bosses##loot_view_bosses", view == VIEW_BOSSES, ImGui.vec2(w, 28)))
					setView(VIEW_BOSSES);
			case 3:
				ImGui.setNextItemWidth(w);
				if (view == VIEW_ITEMS)
					pick("loot_rarity", rarity, rarityOptions, rarityLabelFn, function(s) rarity = s);
				else if (view == VIEW_TABLES)
					pick("loot_mode", rollMode, modeOptions, modeLabelFn, function(s) rollMode = s);
				else
					pick("loot_family", family, familyOptions, familyLabelFn, function(s) family = s);
			default:
				if (view == VIEW_ITEMS) {
					ImGui.setNextItemWidth(w);
					pick("loot_type", itemType, typeOptions, typeLabelFn, function(s) itemType = s);
				}
		}
	}

	function pick(id:String, current:String, options:Array<String>, label:String->String, set:String->Void):Void {
		var picked = UiLayout.stringCombo(id, current, options, label);
		if (picked != null && picked != current) {
			set(picked);
			dirty = true;
		}
	}

	function drawList():Void {
		var count = view == VIEW_ITEMS ? itemHits.length : (view == VIEW_TABLES ? tableHits.length : bossHits.length);
		if (count == 0) {
			ImGui.textDisabled("Nothing matches. Clear the search or filters.");
			return;
		}
		if (scrollRow >= 0) {
			var step = ROW_H + ImGui.getTextLineHeightWithSpacing() - ImGui.getTextLineHeight();
			ImGui.setScrollY(Math.max(0, scrollRow * step - ROW_H * 2));
			scrollRow = -1;
		}
		ImGuiLists.forVisible(count, view == VIEW_ITEMS ? itemRowFn : (view == VIEW_TABLES ? tableRowFn : bossRowFn));
	}

	function drawItemRow(i:Int):Void {
		var item = itemHits[i];
		var box = rowBox(item.rowId, ROW_H, selItem == item, rarityColor(item.rarity));
		if (box.clicked)
			selItem = item;
		thumb(item.art, item.name, box.x + 8, box.y + 4, 36);
		textIn(box.x + 52, box.y + 6, box.w - 60, item.name, false);
		textIn(box.x + 52, box.y + 24, box.w - 60, item.subtitle, true);
		if (box.hovered)
			ImGui.setTooltip(item.id);
	}

	function drawTableRow(i:Int):Void {
		var table = tableHits[i];
		var box = rowBox(table.rowId, ROW_H, selTable == table, 0);
		if (box.clicked)
			selTable = table;
		var previews = table.previewArt.length;
		var textW = box.w - 16 - previews * 34;
		textIn(box.x + 10, box.y + 6, textW, table.id, false);
		textIn(box.x + 10, box.y + 24, textW, table.subtitle, true);
		for (k in 0...previews)
			thumb(table.previewArt[k], "", box.x + box.w - 8 - (k + 1) * 34 + 4, box.y + 7, 30);
		if (box.hovered)
			ImGui.setTooltip(table.id);
	}

	function drawBossRow(i:Int):Void {
		var boss = bossHits[i];
		var box = rowBox(boss.rowId, ROW_H, selBoss == boss, 0);
		if (box.clicked)
			selBoss = boss;
		var previews = boss.previewArt.length;
		var textW = box.w - 16 - previews * 34;
		textIn(box.x + 10, box.y + 6, textW, boss.name, false);
		textIn(box.x + 10, box.y + 24, textW, boss.subtitle, true);
		for (k in 0...previews)
			thumb(boss.previewArt[k], "", box.x + box.w - 8 - (k + 1) * 34 + 4, box.y + 7, 30);
		if (box.hovered)
			ImGui.setTooltip(boss.id);
	}

	function drawDetail():Void {
		switch (view) {
			case VIEW_ITEMS: drawItemDetail(selItem);
			case VIEW_TABLES: drawTableDetail(selTable);
			default: drawBossDetail(selBoss);
		}
	}

	function drawBossDetail(boss:LootBoss):Void {
		if (boss == null) {
			ImGui.textDisabled("Select a boss on the left.");
			return;
		}
		var showHeroic = heroic && boss.hasHeroic();
		UiChrome.sectionHeader(boss.name + "##loot_boss_head");
		ImGui.textDisabled(boss.subtitle);
		UiChrome.gap(UiChrome.SP_S);
		UiLayout.inlinePair("##loot_boss_diff", function(w:Single) {
			if (UiChrome.navButton("Normal##loot_boss_normal", !showHeroic, ImGui.vec2(w, 28)))
				heroic = false;
		}, function(w:Single) {
			if (boss.hasHeroic()) {
				if (UiChrome.navButton("Heroic##loot_boss_heroic", showHeroic, ImGui.vec2(w, 28)))
					heroic = true;
			} else
				ImGui.textDisabled("No heroic table");
		}, 6);
		UiChrome.gap(UiChrome.SP_S);
		UiLayout.inlinePair("##loot_boss_actions", function(w:Single) {
			if (UiChrome.ghostButton("Open table##loot_boss_open", ImGui.vec2(w, 26)))
				jumpTable(showHeroic ? boss.heroicTable : boss.bossTable);
		}, function(w:Single) {
			if (UiChrome.ghostButton("Copy ID##loot_boss_copy", ImGui.vec2(w, 26)))
				UiActionQueue.copyText(boss.id, "Copied " + boss.id);
		}, 6);
		var drops = showHeroic ? boss.heroicDrops : boss.normalDrops;
		UiChrome.subHeader((showHeroic ? "Heroic drops (" : "Boss drops (") + drops.length + ")##loot_boss_drops");
		ImGui.pushTextWrapPos(0);
		ImGui.textDisabled("Chance per kill. Nested tables are multiplied in; level and foe gates are listed, not applied.");
		ImGui.popTextWrapPos();
		drawFlatRows(drops, "##loot_bd_");
		if (boss.regularDrops.length > 0) {
			UiChrome.subHeader("Regular loot (" + boss.regularDrops.length + ")##loot_boss_regular");
			drawFlatRows(boss.regularDrops, "##loot_br_");
		}
	}

	function drawFlatRows(rows:Array<LootRow>, prefix:String):Void {
		var w = ImGui.getContentRegionAvail().x;
		for (i in 0...rows.length) {
			var row = rows[i];
			var item = LootCatalog.item(row.item);
			var name = item != null ? item.name : row.item;
			if (dropCard(prefix + i, item != null ? item.art : "", name, name, item != null ? rarityColor(item.rarity) : 0, row, w))
				jumpItem(row.item);
		}
	}

	function drawItemDetail(item:LootItem):Void {
		if (item == null) {
			ImGui.textDisabled("Select an item on the left.");
			return;
		}
		var p = ImGui.getCursorScreenPos();
		thumb(item.art, item.name, p.x, p.y, BIG_THUMB);
		var x = p.x + BIG_THUMB + 12;
		var font = ImGui.getFont();
		ImGui.setCursorScreenPos(ImGui.vec2(x, p.y + 2));
		if (font != null)
			ImGui.pushFont(font, ImGui.getFontSize() * 1.35);
		ImGui.textColored(colorVec(rarityColor(item.rarity)), item.name);
		if (font != null)
			ImGui.popFont();
		ImGui.setCursorScreenPos(ImGui.vec2(x, p.y + 34));
		ImGui.textDisabled(item.id);
		ImGui.setCursorScreenPos(ImGui.vec2(x, p.y + 52));
		ImGui.text(item.rarity + " | " + item.type);
		ImGui.setCursorScreenPos(ImGui.vec2(x, p.y + 68));
		if (UiChrome.ghostButton("Copy ID##loot_copy_item", ImGui.vec2(96, 26)))
			UiActionQueue.copyText(item.id, "Copied " + item.id);
		ImGui.setCursorScreenPos(p);
		ImGui.dummy(ImGui.vec2(1, BIG_THUMB + 4));
		if (item.desc != "")
			ImGui.textWrapped(item.desc);
		if (item.details.length > 0) {
			UiChrome.subHeader("Details##loot_item_details");
			UiLayout.propertyGrid("##loot_item_props", function() {
				for (d in item.details)
					UiLayout.propertyRow(d.label, function() ImGui.textWrapped(d.value));
			});
		}
		UiChrome.subHeader("Dropped by " + item.drops.length + (item.drops.length == 1 ? " table##loot_item_drops" : " tables##loot_item_drops"));
		if (item.drops.length == 0)
			ImGui.textDisabled("No loot table drops this item directly.");
		var w = ImGui.getContentRegionAvail().x;
		for (i in 0...item.drops.length) {
			var drop = item.drops[i];
			var owner = LootCatalog.table(drop.table);
			var art = owner != null && owner.previewArt.length > 0 ? owner.previewArt[0] : "";
			if (dropCard("##loot_drop_" + i, art, "", drop.table, 0, drop.row, w))
				jumpTable(drop.table);
		}
	}

	function drawTableDetail(table:LootTable):Void {
		if (table == null) {
			ImGui.textDisabled("Select a loot table on the left.");
			return;
		}
		UiChrome.sectionHeader(table.id + "##loot_table_head");
		ImGui.pushTextWrapPos(0);
		ImGui.textDisabled(table.modeText);
		ImGui.popTextWrapPos();
		UiChrome.gap(UiChrome.SP_S);
		if (UiChrome.ghostButton("Copy ID##loot_copy_table", ImGui.vec2(96, 26)))
			UiActionQueue.copyText(table.id, "Copied " + table.id);
		if (table.sourceCount > 0) {
			UiChrome.subHeader("Used by##loot_table_sources");
			ImGui.textWrapped(table.sourcesText);
		}
		if (table.parents.length > 0) {
			UiChrome.subHeader("Nested in##loot_table_parents");
			drawParents(table);
		}
		UiChrome.subHeader("Drops (" + table.rows.length + ")##loot_table_drops");
		if (table.rows.length == 0)
			ImGui.textDisabled("This table has no drops.");
		var w = ImGui.getContentRegionAvail().x;
		for (i in 0...table.rows.length) {
			var row = table.rows[i];
			if (row.item != "") {
				var item = LootCatalog.item(row.item);
				var name = item != null ? item.name : row.item;
				if (dropCard("##loot_row_" + i, item != null ? item.art : "", name, name, item != null ? rarityColor(item.rarity) : 0, row, w))
					jumpItem(row.item);
			} else {
				var child = LootCatalog.table(row.table);
				var art = child != null && child.previewArt.length > 0 ? child.previewArt[0] : "";
				if (dropCard("##loot_row_" + i, art, "T", row.table, 0, row, w))
					jumpTable(row.table);
			}
		}
	}

	function drawParents(table:LootTable):Void {
		var shown = table.parents.length < 8 ? table.parents.length : 8;
		var cols = UiLayout.columnCount(ImGui.getContentRegionAvail().x, 150, 4, UiChrome.SP_M);
		var rows = Std.int((shown + cols - 1) / cols);
		for (r in 0...rows)
			UiLayout.inlineSplit("##loot_parents_" + r, cols, function(c:Int, w:Single) {
				var i = r * cols + c;
				if (i < shown && UiChrome.ghostButton(table.parents[i] + "##loot_parent_" + i, ImGui.vec2(w, 26)))
					jumpTable(table.parents[i]);
			}, UiChrome.SP_M);
		if (table.parents.length > shown)
			ImGui.textDisabled("+" + (table.parents.length - shown) + " more");
	}

	// ---------------------------------------------------------------------------------------------
	// Shared drawing
	// ---------------------------------------------------------------------------------------------

	/** One drop line: portrait, name, chance, and the quantity/level/condition caption. Returns true on click. */
	function dropCard(id:String, art:String, glyph:String, title:String, titleColor:Int, row:LootRow, w:Single):Bool {
		var box = rowBox(id, CARD_H, false, 0);
		thumb(art, glyph != "" ? glyph : title, box.x + 6, box.y + 6, 34);
		var theme = ThemePalette.current();
		var chance = row.chanceText;
		var cw = ImGui.calcTextSize(chance).x;
		textIn(box.x + 48, box.y + 7, box.w - 48 - cw - 18, title, false, titleColor);
		var dl = ImGui.getWindowDrawList();
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(box.x + box.w - cw - 10, box.y + 7), ImGui.colorConvertFloat4ToU32(theme.accent), chance);
		textIn(box.x + 48, box.y + 26, box.w - 58, row.detailText == "" ? "No conditions" : row.detailText, true);
		return box.clicked;
	}

	/** Full-width clickable plate with hover/selected fill. `stripe` (ABGR, 0 = none) marks rarity on the left edge. */
	function rowBox(id:String, h:Single, selected:Bool, stripe:Int):{clicked:Bool, hovered:Bool, x:Single, y:Single, w:Single} {
		var theme = ThemePalette.current();
		var p = ImGui.getCursorScreenPos();
		var w = ImGui.getContentRegionAvail().x;
		var clicked = ImGui.invisibleButton(id, ImGui.vec2(w, h));
		var hovered = ImGui.isItemHovered();
		var dl = ImGui.getWindowDrawList();
		var mix:Single = selected ? 0.34 : hovered ? 0.12 : 0;
		var max = ImGui.vec2(p.x + w, p.y + h);
		ImGui.ImDrawList_AddRectFilled(dl, p, max, ImGui.colorConvertFloat4ToU32(ImGui.vec4(
			theme.cellBg.x * (1 - mix) + theme.accent.x * mix,
			theme.cellBg.y * (1 - mix) + theme.accent.y * mix,
			theme.cellBg.z * (1 - mix) + theme.accent.z * mix, 0.96)), 8);
		ImGui.ImDrawList_AddRect(dl, p, max, ImGui.colorConvertFloat4ToU32(selected ? theme.accent : theme.border), 8, selected ? 2 : 1, 0);
		if (stripe != 0)
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(p.x + 2, p.y + 8), ImGui.vec2(p.x + 5, p.y + h - 8), stripe, 2);
		return {clicked: clicked, hovered: hovered, x: p.x, y: p.y, w: w};
	}

	/**
	 * Item portrait on a dark plate, or the name's first letter when there is no art. The image is placed with
	 * setCursorScreenPos and the cursor put back, so a row consumes exactly its button (clipper-safe).
	 */
	function thumb(art:String, label:String, x:Single, y:Single, size:Single):Void {
		var theme = ThemePalette.current();
		var dl = ImGui.getWindowDrawList();
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + size, y + size), ImGui.colorConvertFloat4ToU32(
			ImGui.vec4(theme.windowBg.x * 0.8, theme.windowBg.y * 0.8, theme.windowBg.z * 0.8, 0.95)), 6);
		if (art != "" && GameIcons.hasKey(art)) {
			var saved = ImGui.getCursorScreenPos();
			ImGui.setCursorScreenPos(ImGui.vec2(x + 2, y + 2));
			ImGui.setNextItemAllowOverlap();
			GameIcons.imageKey(art, size - 4, size - 4);
			// Put the cursor back through an item. A bare SetCursorScreenPos as the last call of a child
			// makes ImGui flag "extends window/parent boundaries"; this zero-size Dummy lands exactly on `saved`.
			ImGui.setCursorScreenPos(ImGui.vec2(saved.x, saved.y - (ImGui.getTextLineHeightWithSpacing() - ImGui.getTextLineHeight())));
			ImGui.dummy(ImGui.vec2(0, 0));
			return;
		}
		var letter = label != "" ? label.substr(0, 1).toUpperCase() : "?";
		var ts = ImGui.calcTextSize(letter);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + (size - ts.x) * 0.5, y + (size - ts.y) * 0.5),
			ImGui.colorConvertFloat4ToU32(theme.textDisabled), letter);
	}

	/** Single-line text clipped to `width`; `color` (ABGR) overrides the theme text colour when non-zero. */
	function textIn(x:Single, y:Single, width:Single, text:String, muted:Bool, color:Int = 0):Void {
		var theme = ThemePalette.current();
		var dl = ImGui.getWindowDrawList();
		var ts = ImGui.calcTextSize(text);
		ImGui.ImDrawList_PushClipRect(dl, ImGui.vec2(x, y - 2), ImGui.vec2(x + Math.max(1, width), y + ts.y + 4), true);
		var col = color != 0 ? color : ImGui.colorConvertFloat4ToU32(muted ? theme.textDisabled : theme.text);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x, y), col, text);
		ImGui.ImDrawList_PopClipRect(dl);
	}

	static function rarityColor(r:String):Int {
		return switch (r) {
			case "Uncommon": C_UNCOMMON;
			case "Rare": C_RARE;
			case "Epic": C_EPIC;
			case "Legendary": C_LEGENDARY;
			default: C_COMMON;
		}
	}

	/** ImGui packs colours as 0xAABBGGRR; textColored wants a float vector. */
	static function colorVec(abgr:Int):imgui.Structs.ImVec4 {
		return ImGui.vec4((abgr & 0xFF) / 255, ((abgr >> 8) & 0xFF) / 255, ((abgr >> 16) & 0xFF) / 255, 1);
	}
}
