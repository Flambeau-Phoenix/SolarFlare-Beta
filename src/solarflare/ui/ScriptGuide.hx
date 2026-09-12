package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.BoolRef;

/**
 * In-game custom-script / file-location guide. F6 hub button. Matches docs/hudmod/CUSTOM_SCRIPTS.md.
 */
class ScriptGuide {
	public var open = new BoolRef(false);

	var idSuffix:String;

	public function new(idSuffix:String = "hm") {
		this.idSuffix = idSuffix;
	}

	public function draw(cursorFree:Bool = true):Void {
		if (!open.get())
			return;
		ImGui.setNextWindowSize(ImGui.vec2(560, 480), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel("Custom script guide##" + idSuffix, open, "Custom script guide")) {
			if (!CursorCaptureFix.cursorFree)
				ImGui.text("Unlock cursor (UI mode) to copy paths.");
			ImGui.text("These tools do not run Lua or Haxe. Customize them with the files below.");
			ImGui.text("Paths are under your Farever install.");
			ImGui.separator();
			section("aura", "Auras", [
				"F6 -> Auras. New aura, set trigger and region. Layout saves with F6 close.",
				"Unlock ghosts hidden auras so you can place them. Lock for combat.",
				"Status: op + pct = stack compare (pct 1 or leftover 35 = any stacks).",
				"duration 0 uses CastleDB length from hlx/mods/solarflare/cdb/aura-catalog.json.",
				"skillId is the engine id (Fairie spelling for clones). Clipboard share key is Base64 JSON; settings file stays plain JSON.",
				"Out-of-game builder is in the SolarFlare repo: tools/custom_script_builder.html (not under Farever).",
			], [aurasDir()]);
			section("drm", "Deadly Rift Mods", [
				"Drop a pack INI plus a plate PNG. Restart after new packs.",
				"Toggles live in F7 and drm.ini.",
				"Plates: hlx/mods/deadlyriftmods/assets/alerts/<plate>.png"
			], [drmCustomDir(), drmIniPath()]);
			section("note", "Notebook", [
				"F6 -> Notebook. Pages auto-save. Not a script engine."
			], [notebookPath()]);
			section("saber", "Lightsaber", [
				"Lightsaber DPS Meter is always local You. GetRifty clock works on both windows.",
				"In that rift is a second meter of hero players in the instance. Open world stays You only.",
				"JSONL is written when the local fight seals (idle or Reset local encounter)."
			], [saberGlob()]);
			section("clog", "Combat Log", [
				"F6 Combat Log overlay. Record JSONL writes SolarFlare hunt files.",
				"New file after 30s idle or when recording starts. Schema: docs/hudmod/COMBAT_LOG.md"
			], [hudClogGlob(), clogGlob()]);
		}
		HudChrome.endPanel();
	}

	function section(slug:String, title:String, lines:Array<String>, paths:Array<String>):Void {
		if (!ImGui.collapsingHeader(title + "##sg_" + slug + idSuffix))
			return;
		for (line in lines)
			ImGui.textWrapped(line);
		var i = 0;
		while (i < paths.length) {
			pathLine("sgp_" + slug + Std.string(i) + idSuffix, paths[i]);
			i++;
		}
	}

	function pathLine(id:String, path:String):Void {
		ImGui.text(path);
		if (ImGui.smallButton("Copy path##" + id))
			ImGui.setClipboardText(path);
	}

	static function aurasDir():String {
		return join(["hlx", "mods", "solarflare", "auras"]);
	}

	static function notebookPath():String {
		return join(["hlx", "mods", "solarflare", "notebook.json"]);
	}

	static function saberGlob():String {
		return join(["hlx", "mods", "solarflare", "logs", "saber", "saber-*.jsonl"]);
	}

	static function drmCustomDir():String {
		return join(["hlx", "mods", "deadlyriftmods", "assets", "alerts", "packs", "custom"]);
	}

	static function drmIniPath():String {
		return join(["hlx", "mods", "deadlyriftmods", "drm.ini"]);
	}

	static function hudClogGlob():String {
		return join(["hlx", "mods", "solarflare", "logs", "combatlog", "clog-*.jsonl"]);
	}

	static function clogGlob():String {
		return join(["hlx", "mods", "deadlyriftmods", "combatlog", "clog-*.jsonl"]);
	}

	static function join(parts:Array<String>):String {
		var acc = fareverRoot();
		if (acc == null || acc.length == 0)
			acc = "{Farever}";
		for (p in parts)
			acc = haxe.io.Path.join([acc, p]);
		return acc;
	}

	static function fareverRoot():String {
		try
			return haxe.io.Path.directory(Sys.programPath())
		catch (_:Dynamic)
			return "";
	}
}
