package solarflare.aura.ui;

import imgui.ImGui;
import solarflare.cdb.AuraCatalog;
import solarflare.ui.ByteUtil;
import solarflare.ui.GameIcons;

/**
 * Searchable game-icon dropdown: type to filter the aura catalog, narrow by kind, click an icon.
 * Mirrors the Aura Builder's icon search but opens as a combo so it fits inside a property row.
 */
class GameIconPicker {
	static inline var ROW_H:Int = 30;
	static var KINDS:Array<String> = ["All", "Units", "Skills", "Status skills", "Categories", "Icons"];

	var searchBuf = new hl.Bytes(80);
	var search = "";
	var kind = "All";
	var wasOpen = false;

	public function new() {
		ByteUtil.clearBytes(searchBuf, 80);
	}

	function matchesKind(id:String, entryKind:String):Bool {
		return switch (kind) {
			case "Units": entryKind == "unit";
			case "Skills": entryKind == "skill";
			case "Status skills": entryKind == "skill" && AuraCatalog.statusPickRank(id, entryKind) == 0;
			case "Categories": entryKind == "statustype";
			case "Icons": entryKind == "icon";
			default: true;
		};
	}

	/** `current` is the icon id now in use; `onPick(id)` fires on click. Returns true when something was picked. */
	public function draw(id:String, current:String, onPick:String->Void):Bool {
		var picked = false;
		var label = current != null && current.length > 0 ? AuraCatalog.label(current) : "Search game icons...";
		if (label == null || label.length == 0) label = current;
		ImGui.setNextItemWidth(-1);
		ImGui.setNextWindowSize(ImGui.vec2(440, 420), imgui.Enums.ImGuiCond.Always);
		if (!ImGui.beginCombo("##" + id + "_icon_combo", label)) { wasOpen = false; return false; }
		try {
			if (!wasOpen) { wasOpen = true; ImGui.setKeyboardFocusHere(); }
			ImGui.setNextItemWidth(Math.max(120, ImGui.getContentRegionAvail().x - 130));
			if (ImGui.inputTextWithHint("##" + id + "_icon_search", "Search by name or id", searchBuf, 80, imgui.Enums.ImGuiInputTextFlags.EscapeClearsAll))
				search = ByteUtil.readBytes(searchBuf, 80).toLowerCase();
			ImGui.sameLine(0, 6);
			ImGui.setNextItemWidth(-1);
			if (ImGui.beginCombo("##" + id + "_icon_kind", kind)) {
				for (k in KINDS) if (ImGui.selectable(k + "##" + id + "_kind_" + k, kind == k)) kind = k;
				ImGui.endCombo();
			}
			var shown = 0;
			if (ImGui.beginChild("##" + id + "_icon_list", ImGui.vec2(0, 0), imgui.Enums.ImGuiChildFlags.Borders)) {
				try {
					for (entry in AuraCatalog.entries) {
						if (!matchesKind(entry.id, entry.kind) || !AuraCatalog.matchesSearch(entry.id, entry.name, search)) continue;
						shown++;
						if (!ImGui.isRectVisible(ImGui.vec2(ImGui.getContentRegionAvail().x, ROW_H))) { ImGui.dummy(ImGui.vec2(1, ROW_H)); continue; }
						var art = GameIcons.imageKey(entry.id, 26, 26);
						if (!art) ImGui.dummy(ImGui.vec2(26, 26));
						ImGui.sameLine(0, 8);
						if (ImGui.selectable(entry.name + " [" + entry.kind + "]##" + id + "_ic_" + entry.id, entry.id == current, 0, ImGui.vec2(0, 26))) {
							onPick(entry.id);
							picked = true;
							ImGui.closeCurrentPopup();
						}
					}
					if (shown == 0) ImGui.textDisabled("No icons match.");
				} catch (e:Dynamic) { ImGui.endChild(); throw e; }
			}
			ImGui.endChild();
		} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
		ImGui.endCombo();
		return picked;
	}
}
