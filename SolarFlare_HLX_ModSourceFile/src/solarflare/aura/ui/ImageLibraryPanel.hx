package solarflare.aura.ui;

import imgui.ImGui;
import solarflare.aura.AuraDef;
import solarflare.aura.AuraImageUsage;
import solarflare.ui.ByteUtil;
import solarflare.ui.CustomImages;
import solarflare.ui.GameIcons;
import solarflare.ui.ImageConvert;
import solarflare.ui.ImageDrop;
import solarflare.ui.SettingsStore;
import solarflare.ui.ThemePalette;
import solarflare.ui.ToastManager;
import solarflare.ui.UiActionQueue;
import solarflare.ui.UiChrome;

/**
 * Searchable thumbnail grid for the user's images: pick, import (path, clipboard, drag and drop),
 * rename and delete. Disk work is queued to the observe phase; drawing only reads caches.
 */
class ImageLibraryPanel {
	/** Drag payload carrying a custom-image stem; the Canvas Editor stage accepts it. */
	public static inline var PAYLOAD_IMAGE:String = "CV_IMAGE";
	static inline var ROW_H:Int = 32;
	static inline var PREVIEW_H:Int = 150;
	static inline var NAME_BUF:Int = 96;
	static inline var PATH_BUF:Int = 1024;

	var auras:Void->Array<AuraDef>;
	var snapshot:String->Void;
	var searchBuf = new hl.Bytes(NAME_BUF);
	var pathBuf = new hl.Bytes(PATH_BUF);
	var renameBuf = new hl.Bytes(NAME_BUF);
	var search = "";
	/** Library selection (separate from the element being edited). */
	public var selected(default, null):String = "";
	var armDelete = "";
	var message = "";
	var messageError = false;
	var opened = false;
	/** File size of the selected image, fetched in the observe phase when the selection changes. */
	var infoText:String = "";
	var infoFor:String = "";
	/** Usage is counted on selection events, never per frame. */
	var usedCount = 0;

	public function new(auras:Void->Array<AuraDef>, snapshot:String->Void) {
		this.auras = auras;
		this.snapshot = snapshot;
		ByteUtil.clearBytes(searchBuf, NAME_BUF); ByteUtil.clearBytes(pathBuf, PATH_BUF); ByteUtil.clearBytes(renameBuf, NAME_BUF);
	}

	public function clearTransientState():Void {
		armDelete = ""; opened = false;
		ImageDrop.onImported = null;
	}

	function say(text:String, error:Bool):Void { message = text; messageError = error; }

	/** `onPick(stem)` fires when the user chooses an image (double click, or the Use button). */
	public function draw(id:String, onPick:String->Void, pickLabel:String = "Use image"):Void {
		ImageDrop.arm();
		ImageDrop.onImported = function(stems) { if (stems.length > 0) { selected = stems[stems.length - 1]; syncRename(); } };
		if (!opened) { opened = true; CustomImages.requestRefresh(); }
		drawImportRow(id);
		ImGui.setNextItemWidth(-1);
		if (ImGui.inputTextWithHint("##" + id + "_search", "Search images", searchBuf, NAME_BUF, imgui.Enums.ImGuiInputTextFlags.EscapeClearsAll)) search = ByteUtil.readBytes(searchBuf, NAME_BUF).toLowerCase();
		drawGrid(id, onPick);
		drawSelectionRow(id, onPick, pickLabel);
		if (message.length > 0) {
			if (messageError) ImGui.textColored(ThemePalette.status(ThemePalette.STATUS_DANGER), message);
			else ImGui.textWrapped(message);
		}
		if (CustomImages.folderError) ImGui.textColored(ThemePalette.status(ThemePalette.STATUS_WARN), CustomImages.status);
		else ImGui.textDisabled(CustomImages.status);
		if (ImageDrop.lastDrop.length > 0) ImGui.textDisabled(ImageDrop.lastDrop);
		ImGui.textDisabled(ImageDrop.available() ? "Drop " + ImageConvert.EXTENSIONS.join(", ").toUpperCase() + " files onto the game window to import." : ImageDrop.support);
	}

	function drawImportRow(id:String):Void {
		ImGui.setNextItemWidth(Math.max(60, ImGui.getContentRegionAvail().x - 150));
		var enter = ImGui.inputTextWithHint("##" + id + "_path", "Paste one or more image paths", pathBuf, PATH_BUF,
			imgui.Enums.ImGuiInputTextFlags.EnterReturnsTrue);
		ImGui.sameLine(0, 4);
		if (UiChrome.ghostButton("Import##" + id + "_go", ImGui.vec2(68, 26)) || enter) {
			var raw = ByteUtil.readBytes(pathBuf, PATH_BUF);
			UiActionQueue.custom(function() { runImport(raw, true); });
		}
		ImGui.sameLine(0, 4);
		if (UiChrome.ghostButton("Paste##" + id + "_clip", ImGui.vec2(72, 26))) {
			// Clipboard text may hold a copied file path (Explorer "Copy as path") or several, one per line.
			UiActionQueue.custom(function() {
				var bytes = ImGui.getClipboardText();
				var text = bytes != null ? ByteUtil.readString(bytes, PATH_BUF * 8, true) : "";
				runImport(text, false);
			});
		}
		if (ImGui.isItemHovered()) ImGui.setTooltip("Import the file path(s) on your clipboard.");
	}

	function runImport(raw:String, clearField:Bool):Void {
		if (raw == null || StringTools.trim(raw).length == 0) { say("Paste the full path to an image file (PNG, JPG, GIF, BMP or TGA).", true); return; }
		var report = CustomImages.importMany(raw);
		if (report.imported.length > 0) {
			selected = report.imported[report.imported.length - 1]; syncRename();
			if (clearField) ByteUtil.clearBytes(pathBuf, PATH_BUF);
			GameIcons.get(CustomImages.key(selected));
		}
		var parts:Array<String> = [];
		if (report.imported.length > 0) parts.push("Imported " + report.imported.join(", "));
		if (report.errors.length > 0) parts.push(report.errors.join("  "));
		say(parts.join("  "), report.imported.length == 0);
	}

	/** Preview of the selected image above a scrolling list of every usable file. */
	function drawGrid(id:String, onPick:String->Void):Void {
		drawPreview(id);
		var names = CustomImages.names();
		var shown:Array<String> = [];
		for (n in names) if (search.length == 0 || n.toLowerCase().indexOf(search) >= 0) shown.push(n);
		ImGui.textDisabled(shown.length + " of " + names.length + " image" + (names.length == 1 ? "" : "s"));
		if (ImGui.beginChild("##" + id + "_list", ImGui.vec2(0, ROW_H * 7 + 10), imgui.Enums.ImGuiChildFlags.Borders)) {
			try {
				if (shown.length == 0) ImGui.textDisabled(names.length == 0 ? "No images yet. Drop files here, or paste a path above." : "No images match the search.");
				for (stem in shown) {
					// Only rows on screen are laid out, so long folders stay cheap.
					if (!ImGui.isRectVisible(ImGui.vec2(ImGui.getContentRegionAvail().x, ROW_H))) { ImGui.dummy(ImGui.vec2(1, ROW_H)); continue; }
					var key = CustomImages.key(stem);
					if (!GameIcons.imageKey(key, 28, 28)) ImGui.dummy(ImGui.vec2(28, 28));
					ImGui.sameLine(0, 8);
					if (ImGui.selectable(stem + "##" + id + "_row_" + stem, stem == selected, 0, ImGui.vec2(0, 28))) { selected = stem; armDelete = ""; syncRename(); }
					if (ImGui.isItemHovered() && ImGui.isMouseDoubleClicked(0)) { onPick(stem); syncRename(); }
					if (ImGui.beginDragDropSource(0)) {
						var payload = haxe.io.Bytes.ofString(stem);
						ImGui.setDragDropPayload(PAYLOAD_IMAGE, payload.getData(), payload.length + 1);
						GameIcons.imageKey(key, 40, 40);
						ImGui.text(stem + " - drop on the canvas");
						ImGui.endDragDropSource();
					}
				}
			} catch (e:Dynamic) { ImGui.endChild(); throw e; }
		}
		ImGui.endChild();
		drawFixOffer(id);
	}

	/** Aspect-fit view of the selected image on a dark panel, with its size and usage. */
	function drawPreview(id:String):Void {
		var w:Single = Math.max(100, ImGui.getContentRegionAvail().x), h:Single = PREVIEW_H;
		var p = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		ImGui.dummy(ImGui.vec2(w, h));
		ImGui.ImDrawList_AddRectFilled(dl, p, ImGui.vec2(p.x + w, p.y + h), ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.05, 0.06, 0.09, 1)), 4);
		ImGui.ImDrawList_AddRect(dl, p, ImGui.vec2(p.x + w, p.y + h), ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.3, 0.38, 0.5, 1)), 4, 1);
		var present = selected.length > 0 && CustomImages.has(selected);
		if (!present) {
			var msg = "Select an image to preview it";
			var ts = ImGui.calcTextSize(msg);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(p.x + (w - ts.x) * 0.5, p.y + (h - ts.y) * 0.5), ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.55, 0.6, 0.7, 1)), msg);
			return;
		}
		var key = CustomImages.key(selected);
		var iw = GameIcons.texW(key), ih = GameIcons.texH(key);
		if (iw <= 0 || ih <= 0) {
			var state = CustomImages.stateOf(selected);
			var note = state == "conforming" ? "Optimizing this image..." : (state == "ready" || state == "" ? "Loading..." : "Could not use this image: " + state);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(p.x + 10, p.y + 10), ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.55, 0.6, 0.7, 1)), note);
			return;
		}
		var fit = Math.min((w - 12) / iw, (h - 12) / ih);
		fit = Math.min(fit, 4);
		var dw = iw * fit, dh = ih * fit;
		GameIcons.drawKey(dl, key, p.x + (w - dw) * 0.5, p.y + (h - dh) * 0.5, dw, dh);
		var caption = iw + " x " + ih + " px" + (infoFor == selected ? infoText : "");
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(p.x + 8, p.y + h - 18), ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.8, 0.86, 0.95, 1)), caption);
	}

	/** Offer to convert or shrink files the picker cannot list as they are. */
	function drawFixOffer(id:String):Void {
		if (CustomImages.fixable <= 0) return;
		wrappedNote(CustomImages.fixable + " file" + (CustomImages.fixable == 1 ? "" : "s") + " in your images folder can't be used as they are (JPG, GIF, BMP or TGA). Large PNGs are optimized automatically.");
		if (UiChrome.ghostButton("Convert and resize them##" + id + "_fix", ImGui.vec2(-1, 28))) {
			UiActionQueue.custom(function() {
				var report = CustomImages.convertFolder();
				var parts:Array<String> = [];
				if (report.imported.length > 0) parts.push("Created " + report.imported.join(", ") + " (originals kept).");
				if (report.errors.length > 0) parts.push(report.errors.join("  "));
				say(parts.length > 0 ? parts.join("  ") : "Nothing needed converting.", report.imported.length == 0 && report.errors.length > 0);
			});
		}
		if (ImGui.isItemHovered()) ImGui.setTooltip("Makes a PNG copy (1024 px, under 4 MB) of each. Your original files are left untouched.");
	}

	function wrappedNote(text:String):Void {
		ImGui.pushStyleColor(imgui.Enums.ImGuiCol.Text, ThemePalette.status(ThemePalette.STATUS_WARN));
		ImGui.textWrapped(text);
		ImGui.popStyleColor();
	}

	function syncRename():Void {
		ByteUtil.fillBuf(renameBuf, NAME_BUF, selected);
		usedCount = selected.length > 0 ? AuraImageUsage.count(auras(), selected) : 0;
		var stem = selected;
		if (stem.length > 0) UiActionQueue.custom(function() {
			var path = CustomImages.pathFor(stem);
			if (path == null) return;
			try {
				var size = sys.FileSystem.stat(path).size;
				infoText = "  -  " + (size >= 1048576 ? Std.string(Math.round(size / 104857.6) / 10) + " MB" : Std.string(Math.max(1, Math.round(size / 1024))) + " KB");
				infoFor = stem;
			} catch (_:Dynamic) { infoText = ""; infoFor = stem; }
		});
	}

	function drawSelectionRow(id:String, onPick:String->Void, pickLabel:String):Void {
		if (selected.length == 0 || !CustomImages.has(selected)) {
			ImGui.textDisabled("Select an image to rename, delete or use it.");
			return;
		}
		var managed = solarflare.ui.CustomImageKey.isManagedStem(selected);
		var used = usedCount;
		ImGui.textDisabled("Selected: " + selected + "  -  used " + used + " time" + (used == 1 ? "" : "s"));
		if (UiChrome.ghostButton(pickLabel + "##" + id + "_use", ImGui.vec2(ImGui.getContentRegionAvail().x * 0.34, 26))) { onPick(selected); syncRename(); }
		if (managed) return;
		ImGui.setNextItemWidth(Math.max(60, ImGui.getContentRegionAvail().x - 160));
		var enter = ImGui.inputText("##" + id + "_rename", renameBuf, NAME_BUF, imgui.Enums.ImGuiInputTextFlags.EnterReturnsTrue);
		ImGui.sameLine(0, 4);
		if (UiChrome.ghostButton("Rename##" + id + "_ren", ImGui.vec2(70, 26)) || enter) {
			var from = selected, to = ByteUtil.readBytes(renameBuf, NAME_BUF);
			UiActionQueue.custom(function() renameSelected(from, to));
		}
		ImGui.sameLine(0, 4);
		var confirming = armDelete == selected;
		if (UiChrome.ghostButton((confirming ? "Confirm##" : "Delete##") + id + "_del", ImGui.vec2(76, 26))) {
			if (!confirming) { armDelete = selected; usedCount = AuraImageUsage.count(auras(), selected); }
			else { var stem = selected; armDelete = ""; UiActionQueue.custom(function() deleteSelected(stem)); }
		}
		if (confirming) ImGui.textColored(ThemePalette.status(ThemePalette.STATUS_WARN),
			used > 0 ? "Deleting removes the file; " + used + " layer(s) will show nothing. Click Confirm." : "Click Confirm to delete the file.");
	}

	function renameSelected(from:String, to:String):Void {
		try {
			var next = CustomImages.renameImage(from, to);
			if (next != from) {
				snapshot("Rename Image");
				var changed = AuraImageUsage.rewrite(auras(), from, next);
				if (changed > 0) SettingsStore.markDirty();
				GameIcons.get(CustomImages.key(next));
				say("Renamed to " + next + (changed > 0 ? "; updated " + changed + " layer(s)." : "."), false);
			}
			selected = next; syncRename();
		} catch (e:Dynamic) { say(Std.string(e), true); }
	}

	function deleteSelected(stem:String):Void {
		try {
			CustomImages.deleteImage(stem);
			if (selected == stem) selected = "";
			say("Deleted " + stem + ".png", false);
			ToastManager.info("Deleted " + stem + ".png");
		} catch (e:Dynamic) { say(Std.string(e), true); }
	}
}
