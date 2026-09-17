package solarflare.notebook;

import solarflare.ui.CursorCaptureFix;
import solarflare.ui.HudChrome;
import solarflare.ui.ToolWindow;
import solarflare.ui.ModPaths;
import solarflare.ui.ByteUtil;
import solarflare.ui.ToastManager;
import solarflare.ui.VectorGlow;
import solarflare.ui.SearchBar;
import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;
import sys.FileSystem;
import sys.io.File;

/**
 * Enhanced in-game notebook with search, color-coded tabs, word count, and automatic disk persistence.
 */
class NotebookPage {
	public var id:String;
	public var title:String;
	public var body:String;
	public var created:Float;
	public var modified:Float;

	public function new(id:String, title:String = "Untitled", body:String = "") {
		this.id = id;
		this.title = title != null ? title : "Untitled";
		this.body = body != null ? body : "";
		this.created = Date.now().getTime();
		this.modified = this.created;
	}
}

class Notebook {
	static inline var BODY_BUF:Int = 32768;
	static inline var TITLE_BUF:Int = 128;
	static inline var SAVE_DELAY_MS:Float = 600;
	static inline var MAX_PAGES:Int = 50;

	public var open = new BoolRef(false);

	var pages:Array<NotebookPage> = [];
	var selected = new IntRef(0);
	var bodyBuf:hl.Bytes;
	var titleBuf:hl.Bytes;
	var dirty = false;
	var lastEditMs:Float = 0;
	var nextId:Int = 1;
	var loadedSel:Int = -1;
	var searchBar = new SearchBar("Filter pages...", 64);
	var searchText:String = "";
	var searchActive:Bool = false;
	var pageColors:Array<Int> = [
		0xFF3344AA, 0xFF44AA33, 0xFFAA4433,
		0xFF8844AA, 0xFF33AAAA, 0xFFAA8833
	];

	public function new() {
		bodyBuf = new hl.Bytes(BODY_BUF);
		titleBuf = new hl.Bytes(TITLE_BUF);
		load();
		if (pages.length == 0)
			addPage(false);
		selectIndex(0);
	}

	public function draw():Void {
		if (!open.get()) {
			flushIfDirty(true);
			return;
		}
		if (!CursorCaptureFix.cursorFree)
			return;

		ImGui.setNextWindowSizeConstraints(ImGui.vec2(600, 400), ImGui.vec2(1200, 800));
		ToolWindow.drawMenuWindow("Notebook###SolarFlare.Notebook", open, 820, 560, function() {
			if (ImGui.beginMenuBar()) {
				if (ImGui.beginMenu("File")) {
					if (ImGui.menuItem("Flush Save Now"))
						flushIfDirty(true);
					ImGui.endMenu();
				}
				ImGui.endMenuBar();
			}
			drawToolbar();
			ImGui.separator();

			var avail = ImGui.getContentRegionAvail();
			var leftW:Single = 230;
			if (leftW > avail.x * 0.35)
				leftW = avail.x * 0.35;
			if (leftW < 140)
				leftW = 140;

			drawPageList(leftW, avail.y - 4);
			ImGui.sameLine();
			drawEditor(avail.x - leftW - 8, avail.y - 4);
		}, false, true);

		flushIfDirty(false);
	}

	function drawToolbar():Void {
		ImGui.text('${pages.length} pages');
		ImGui.sameLine(ImGui.getWindowWidth() - 150);

		if (dirty) {
			ImGui.textColored(ImGui.vec4(1.0, 0.8, 0.2, 1.0), "Saving...");
		} else {
			ImGui.textColored(ImGui.vec4(0.4, 0.85, 0.4, 1.0), "Saved to disk");
		}
	}

	function drawPageList(width:Float, height:Float):Void {
		if (ImGui.beginChild("##nb_list", ImGui.vec2(width, height), 0)) {
			// Search bar
			searchText = searchBar.draw("##nb_search");
			searchActive = searchText.length > 0;

			ImGui.separator();

			// Action buttons with icons
			if (ImGui.button("New##nb_add", ImGui.vec2(54, 22))) {
				addPage(true);
				ToastManager.success("New page created!");
			}
			ImGui.sameLine();

			if (ImGui.button("Delete##nb_del", ImGui.vec2(64, 22))) {
				if (pages.length > 1) {
					deleteSelected();
					ToastManager.info("Page deleted.");
				} else {
					ToastManager.warn("Cannot delete the last page.");
				}
			}
			ImGui.sameLine();

			if (ImGui.button("Copy##nb_dup", ImGui.vec2(58, 22))) {
				duplicateSelected();
				ToastManager.success("Page duplicated!");
			}

			ImGui.separator();

			// Page list
			ImGui.beginChild("##nb_scroll", ImGui.vec2(width - 4, height - 90));

			var filteredPages = getFilteredPages();
			if (filteredPages.length == 0 && searchActive) {
				ImGui.textColored(ImGui.vec4(0.6, 0.6, 0.6, 1.0), "No matches found.");
			}

			for (i in 0...filteredPages.length) {
				var p = filteredPages[i];
				var realIdx = pages.indexOf(p);
				if (realIdx < 0)
					continue;

				var isSelected = selected.get() == realIdx;

				var label = (p.title != null && p.title.length > 0) ? p.title : ("Page " + Std.string(realIdx + 1));
				var truncated = label.length > 20 ? label.substr(0, 18) + "…" : label;

				if (ImGui.selectable(truncated + "##nb" + p.id, isSelected)) {
					if (!isSelected) {
						selectIndex(realIdx);
					}
				}

			}

			ImGui.endChild();
		}
		ImGui.endChild();
	}

	function drawEditor(width:Float, height:Float):Void {
		if (ImGui.beginChild("##nb_edit", ImGui.vec2(width, height), 0)) {
			ensureSelection();
			var page = current();
			if (page != null) {
				// Title input
				ImGui.setNextItemWidth(width - 120);
				if (ImGui.inputText("##nb_title", titleBuf, TITLE_BUF)) {
					page.title = bytesToString(titleBuf, TITLE_BUF);
					if (page.title.length == 0)
						page.title = "Untitled";
					page.modified = Date.now().getTime();
					markDirty();
				}

				ImGui.sameLine();
				var wordCount = page.body.length > 0 ? page.body.split(" ").length : 0;
				ImGui.textDisabled(Std.string(wordCount) + " words");

				ImGui.separator();

				// Body editor
				var editAvail = ImGui.getContentRegionAvail();
				if (editAvail.y > 40) {
					if (ImGui.inputTextMultiline("##nb_body", bodyBuf, BODY_BUF, ImGui.vec2(editAvail.x, editAvail.y - 4))) {
						page.body = bytesToString(bodyBuf, BODY_BUF);
						page.modified = Date.now().getTime();
						markDirty();
					}
				}
			} else {
				ImGui.textColored(ImGui.vec4(0.6, 0.6, 0.6, 1.0), "No pages available.");
				ImGui.text("Click 'New' to create your first page.");
			}
		}
		ImGui.endChild();
	}

	function getFilteredPages():Array<NotebookPage> {
		if (!searchActive || searchText.length == 0)
			return pages;
		var q = searchText.toLowerCase();
		return pages.filter(p -> p.title.toLowerCase().indexOf(q) >= 0 || p.body.toLowerCase().indexOf(q) >= 0);
	}

	function current():NotebookPage {
		var i = selected.get();
		if (i < 0 || i >= pages.length)
			return null;
		return pages[i];
	}

	function ensureSelection():Void {
		if (pages.length == 0) {
			addPage(false);
			selectIndex(0);
			return;
		}
		if (selected.get() < 0 || selected.get() >= pages.length)
			selectIndex(0);
		if (loadedSel != selected.get())
			selectIndex(selected.get());
	}

	function selectIndex(i:Int):Void {
		if (pages.length == 0)
			return;
		if (i < 0)
			i = 0;
		if (i >= pages.length)
			i = pages.length - 1;
		flushIfDirty(true);
		selected.set(i);
		loadedSel = i;
		var p = pages[i];
		writeString(titleBuf, TITLE_BUF, p.title);
		writeString(bodyBuf, BODY_BUF, p.body);
	}

	function addPage(select:Bool):Void {
		if (pages.length >= MAX_PAGES) {
			ToastManager.warn("Maximum pages reached (" + MAX_PAGES + ")");
			return;
		}
		flushIfDirty(true);
		var id = Std.string(nextId++);
		var p = new NotebookPage(id, "Page " + id, "");
		pages.push(p);
		dirty = true;
		lastEditMs = nowMs();
		if (select)
			selectIndex(pages.length - 1);
		flushIfDirty(true);
	}

	function deleteSelected():Void {
		if (pages.length <= 1) {
			ToastManager.warn("Cannot delete the last page.");
			return;
		}
		var i = selected.get();
		if (i < 0 || i >= pages.length)
			return;
		pages.splice(i, 1);
		dirty = true;
		lastEditMs = nowMs();
		selectIndex(i >= pages.length ? pages.length - 1 : i);
		flushIfDirty(true);
	}

	function duplicateSelected():Void {
		var page = current();
		if (page == null)
			return;
		if (pages.length >= MAX_PAGES) {
			ToastManager.warn("Maximum pages reached.");
			return;
		}
		flushIfDirty(true);
		var copy = new NotebookPage(Std.string(nextId++), page.title + " (Copy)", page.body);
		pages.push(copy);
		dirty = true;
		lastEditMs = nowMs();
		selectIndex(pages.length - 1);
		flushIfDirty(true);
	}

	function markDirty():Void {
		dirty = true;
		lastEditMs = nowMs();
	}

	function flushIfDirty(force:Bool):Void {
		if (!dirty)
			return;
		if (!force && nowMs() - lastEditMs < SAVE_DELAY_MS)
			return;
		save();
		dirty = false;
	}

	function load():Void {
		pages = [];
		try {
			var path = jsonPath();
			if (path == null || !FileSystem.exists(path))
				return;
			var raw = File.getContent(path);
			if (raw == null || raw.length == 0)
				return;
			var data:Dynamic = haxe.Json.parse(raw);
			if (data == null)
				return;
			if (data.nextId != null)
				nextId = Std.int(data.nextId);
			var arr:Array<Dynamic> = data.pages;
			if (arr == null)
				return;
			for (item in arr) {
				if (item == null)
					continue;
				var id = item.id != null ? Std.string(item.id) : Std.string(nextId++);
				var title = item.title != null ? Std.string(item.title) : "Untitled";
				var body = item.body != null ? Std.string(item.body) : "";
				var p = new NotebookPage(id, title, body);
				if (item.created != null)
					p.created = item.created;
				if (item.modified != null)
					p.modified = item.modified;
				pages.push(p);
				var n = Std.parseInt(id);
				if (n != null && n >= nextId)
					nextId = n + 1;
			}
			if (data.selected != null) {
				var s = Std.int(data.selected);
				if (s >= 0 && s < pages.length)
					selected.set(s);
			}
		} catch (_:Dynamic) {}
	}

	function save():Void {
		try {
			var path = jsonPath();
			if (path == null)
				return;
			ensureDir(haxe.io.Path.directory(path));
			var outPages:Array<Dynamic> = [];
			for (p in pages) {
				outPages.push({
					id: p.id,
					title: p.title,
					body: p.body,
					created: p.created,
					modified: p.modified
				});
			}
			var data = {
				v: 2,
				nextId: nextId,
				selected: selected.get(),
				pages: outPages
			};
			File.saveContent(path, haxe.Json.stringify(data, null, "  "));
		} catch (_:Dynamic) {}
	}

	static function jsonPath():String {
		try {
			return haxe.io.Path.join([ModPaths.modDir(), "notebook.json"]);
		} catch (_:Dynamic) {
			return null;
		}
	}

	static function ensureDir(dir:String):Void {
		if (dir == null || dir.length == 0)
			return;
		if (FileSystem.exists(dir))
			return;
		ensureDir(haxe.io.Path.directory(dir));
		try
			FileSystem.createDirectory(dir)
		catch (_:Dynamic) {}
	}

	static function nowMs():Float {
		return Date.now().getTime();
	}

	static function writeString(buf:hl.Bytes, cap:Int, s:String):Void {
		if (buf == null || cap < 1)
			return;
		var i = 0;
		if (s != null) {
			var n = s.length;
			while (i < n && i < cap - 1) {
				var c = s.charCodeAt(i);
				if (c == null || c > 255)
					c = "?".code;
				buf.setUI8(i, c);
				i++;
			}
		}
		while (i < cap) {
			buf.setUI8(i, 0);
			i++;
		}
	}

	static function bytesToString(buf:hl.Bytes, cap:Int):String {
		return ByteUtil.readString(buf, cap);
	}
}
