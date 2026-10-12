package solarflare.notebook;

import solarflare.ui.CursorCaptureFix;
import solarflare.ui.HudChrome;
import solarflare.ui.ToolWindow;
import solarflare.ui.ModPaths;
import solarflare.ui.ByteUtil;
import solarflare.ui.ToastManager;
import solarflare.ui.VectorGlow;
import solarflare.ui.SearchBar;
import solarflare.ui.ThemePalette;
import solarflare.ui.UiLayout;
import solarflare.ui.UiScope;
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
	var wordCount:Int = 0;
	var deleteArmedPage:String = "";
	var deleteArmedUntil:Float = 0;
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

	public function pageCount():Int return pages.length;

	public function hasUnsavedChanges():Bool return dirty;

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
			var leftW:Single = 240;
			if (leftW > avail.x * 0.35)
				leftW = avail.x * 0.35;
			if (leftW < 150)
				leftW = 150;

			drawPageList(leftW, avail.y - 4);
			ImGui.sameLine();
			drawEditor(avail.x - leftW - 8, avail.y - 4);
		}, false, true);

		flushIfDirty(false);
	}

	function drawToolbar():Void {
		ImGui.text(Std.string(pages.length) + " / " + Std.string(MAX_PAGES) + " pages");
		var label = dirty ? "Saving..." : "Saved to disk";
		var width = ImGui.calcTextSize(label).x;
		ImGui.sameLine(0, 0);
		ImGui.setCursorPosX(Math.max(ImGui.getCursorPosX() + 12, ImGui.getWindowWidth() - width - 20));
		ImGui.textColored(ThemePalette.status(dirty ? ThemePalette.STATUS_WARN : ThemePalette.STATUS_SUCCESS), label);
	}

	function drawPageList(width:Float, height:Float):Void {
		UiScope.child("##nb_list", ImGui.vec2(width, height), function() {
			// Search bar
			searchText = searchBar.draw("##nb_search");
			searchActive = searchText.length > 0;

			// Page actions: equal thirds, delete needs a second click.
			var armed = deleteArmedPage != "" && nowMs() < deleteArmedUntil;
			UiLayout.inlineSplit("##nb_actions", 3, function(i:Int, w:Single) {
				switch (i) {
					case 0:
						if (ImGui.button("New##nb_add", ImGui.vec2(w, 24))) {
							addPage(true);
							ToastManager.success("New page created!");
						}
					case 1:
						if (ImGui.button("Duplicate##nb_dup", ImGui.vec2(w, 24))) {
							duplicateSelected();
							ToastManager.success("Page duplicated!");
						}
					default:
						var cur = current();
						var armedHere = armed && cur != null && cur.id == deleteArmedPage;
						if (armedHere)
							ImGui.pushStyleColor(ImGuiCol.Button, ThemePalette.status(ThemePalette.STATUS_DANGER));
						var clicked = ImGui.button((armedHere ? "Confirm?" : "Delete") + "##nb_del", ImGui.vec2(w, 24));
						if (armedHere)
							ImGui.popStyleColor();
						if (clicked)
							requestDelete(cur, armedHere);
				}
			}, 4);
			ImGui.separator();

			// Page list
			UiScope.child("##nb_scroll", ImGui.vec2(0, 0), function() {
				var filteredPages = getFilteredPages();
				if (filteredPages.length == 0 && searchActive)
					ImGui.textDisabled("No matches found.");

				var textW = ImGui.getContentRegionAvail().x - 8;
				var now = nowMs();
				for (i in 0...filteredPages.length) {
					var p = filteredPages[i];
					var realIdx = pages.indexOf(p);
					if (realIdx < 0)
						continue;

					var isSelected = selected.get() == realIdx;
					var label = (p.title != null && p.title.length > 0) ? p.title : ("Page " + Std.string(realIdx + 1));
					if (ImGui.selectable(fitText(label, textW) + "##nb" + p.id, isSelected)) {
						if (!isSelected)
							selectIndex(realIdx);
					}
					ImGui.textDisabled("  " + fitText(ago(now, p.modified) + "  " + preview(p.body), textW - 8));
				}
			});
		});
	}

	function drawEditor(width:Float, height:Float):Void {
		UiScope.child("##nb_edit", ImGui.vec2(width, height), function() {
			ensureSelection();
			var page = current();
			if (page == null) {
				ImGui.textDisabled("No pages available.");
				ImGui.text("Click 'New' to create your first page.");
				return;
			}

			// Title input leaves room for the word count on the same row.
			var counter = Std.string(wordCount) + " words";
			var reserve = ImGui.calcTextSize(counter).x + 24;
			ImGui.setNextItemWidth(Math.max(80, width - reserve));
			if (ImGui.inputText("##nb_title", titleBuf, TITLE_BUF)) {
				page.title = bytesToString(titleBuf, TITLE_BUF);
				if (page.title.length == 0)
					page.title = "Untitled";
				page.modified = nowMs();
				markDirty();
			}
			ImGui.sameLine();
			ImGui.textDisabled(counter);
			ImGui.separator();

			var editAvail = ImGui.getContentRegionAvail();
			if (editAvail.y > 40) {
				if (ImGui.inputTextMultiline("##nb_body", bodyBuf, BODY_BUF, ImGui.vec2(editAvail.x, editAvail.y - 4))) {
					page.body = bytesToString(bodyBuf, BODY_BUF);
					page.modified = nowMs();
					wordCount = countWords(page.body);
					markDirty();
				}
			}
		});
	}

	/** First click arms the page; a second click on the same page within 4s removes it. */
	function requestDelete(page:NotebookPage, confirmed:Bool):Void {
		if (page == null)
			return;
		if (pages.length <= 1) {
			ToastManager.warn("Cannot delete the last page.");
			return;
		}
		if (confirmed) {
			deleteArmedPage = "";
			deleteSelected();
			ToastManager.info("Page deleted.");
			return;
		}
		deleteArmedPage = page.id;
		deleteArmedUntil = nowMs() + 4000;
		ToastManager.info("Click Confirm? to delete \"" + fitText(page.title, 240) + "\".");
	}

	/** Trims with an ellipsis so the rendered text fits the given pixel width. */
	static function fitText(s:String, maxW:Float):String {
		if (s == null || s.length == 0 || maxW <= 0)
			return "";
		if (ImGui.calcTextSize(s).x <= maxW)
			return s;
		var n = s.length;
		var guess = Std.int(n * (maxW / ImGui.calcTextSize(s).x));
		if (guess >= n)
			guess = n - 1;
		while (guess > 1 && ImGui.calcTextSize(s.substr(0, guess) + "...").x > maxW)
			guess--;
		return s.substr(0, guess) + "...";
	}

	/** First non-empty line of a body, collapsed to a single short run. */
	static function preview(body:String):String {
		if (body == null || body.length == 0)
			return "(empty)";
		var lines = body.split("\n");
		for (l in lines) {
			var t = StringTools.trim(l);
			if (t.length > 0)
				return t.length > 80 ? t.substr(0, 80) : t;
		}
		return "(empty)";
	}

	static function ago(now:Float, then:Float):String {
		var s = (now - then) / 1000;
		if (s < 60)
			return "just now";
		if (s < 3600)
			return Std.string(Std.int(s / 60)) + "m ago";
		if (s < 86400)
			return Std.string(Std.int(s / 3600)) + "h ago";
		return Std.string(Std.int(s / 86400)) + "d ago";
	}

	/** Allocation-free word count (whitespace-delimited, counts across newlines). */
	static function countWords(s:String):Int {
		if (s == null)
			return 0;
		var count = 0;
		var inWord = false;
		for (i in 0...s.length) {
			var c = s.charCodeAt(i);
			var space = c == 32 || c == 10 || c == 13 || c == 9;
			if (!space && !inWord)
				count++;
			inWord = !space;
		}
		return count;
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
		wordCount = countWords(p.body);
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
		ByteUtil.fillBuf(buf, cap, s != null ? s : "");
	}

	static function bytesToString(buf:hl.Bytes, cap:Int):String {
		return ByteUtil.readString(buf, cap);
	}
}
