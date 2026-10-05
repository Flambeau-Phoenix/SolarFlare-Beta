package solarflare.aura.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiTableFlags;
import imgui.Enums.ImGuiTableColumnFlags;
import solarflare.aura.CombatLogAuraChoices;
import solarflare.aura.CombatLogAuraChoices.CombatLogAuraChoice;
import solarflare.aura.CombatLogAuraChoices.CombatLogStatusInfo;
import solarflare.combatlog.CombatLogDocument;
import solarflare.combatlog.CombatLogDocument.CombatLogEvent;
import solarflare.combatlog.CombatLogDocument.CombatLogParseJob;
import solarflare.combatlog.CombatLogAnalysis;
import solarflare.combatlog.CombatLogAnalysis.CombatLogSkillStats;
import solarflare.combatlog.CombatLogBrowserState;
import solarflare.cdb.CdbAuraTable;
import solarflare.ui.ByteUtil;
import solarflare.ui.GameIcons;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiActionQueue;
import solarflare.ui.UiChrome;
import solarflare.ui.UiLayout;
import solarflare.ui.UiScope;

private typedef RecordingFile = { var path:String; var name:String; var date:String; var modified:Float; var bytes:Int; }

/** Saved-log reader and linked builder workspace. It never edits the recorder or live auras. */
class CombatLogBrowser {
	var state = new CombatLogBrowserState();
	var files:Array<RecordingFile> = [];
	var folder = "";
	var status = "";
	var failed = false;
	var refreshing = false;
	var job:CombatLogParseJob = null;
	var loadingPath = "";
	var loadToken = 0;
	var pathBuf = new hl.Bytes(1024);
	var searchBuf = new hl.Bytes(160);
	var seenRevision = -1;
	var viewKey = "";
	var events:Array<CombatLogEvent> = [];
	var skills:Array<CombatLogSkillStats> = [];
	var choices:Array<CombatLogAuraChoice> = [];
	var restoreScroll = false;
	var atCap = false;
	var choose:CombatLogAuraChoice->String->Void;
	public function new() { ByteUtil.clearBytes(pathBuf, 1024); ByteUtil.clearBytes(searchBuf, 160); }
	public function enter():Void { if (folder.length == 0 && !refreshing) refresh(); }

	function refresh():Void {
		if (refreshing) return;
		refreshing = true;
		UiActionQueue.custom(function() {
			try {
				folder = SettingsStore.logSubdir("combatlog");
				if (folder == null) throw "Combat-log folder is unavailable.";
				var next:Array<RecordingFile> = [];
				for (name in sys.FileSystem.readDirectory(folder)) {
					if (!StringTools.endsWith(name.toLowerCase(), ".jsonl")) continue;
					var path = haxe.io.Path.join([folder, name]);
					if (sys.FileSystem.isDirectory(path)) continue;
					try {
						var info = sys.FileSystem.stat(path);
						next.push({path:path, name:name, date:info.mtime.toString(), modified:info.mtime.getTime(), bytes:info.size});
					} catch (_:Dynamic) {}
				}
				next.sort(function(a, b) return a.modified > b.modified ? -1 : a.modified < b.modified ? 1 : Reflect.compare(a.name, b.name));
				files = next; status = files.length + " recordings found."; failed = false;
			} catch (e:Dynamic) { folder = folder == null ? "" : folder; status = "Could not list recordings: " + Std.string(e); failed = true; }
			refreshing = false;
		});
	}
	function load(path:String):Void {
		path = StringTools.trim(path);
		if (path.length == 0) { status = "Enter the full path of a combat-log JSONL file."; failed = true; return; }
		var token = ++loadToken;
		if (job != null) { job.cancel(); job = null; }
		loadingPath = path; status = "Opening " + haxe.io.Path.withoutDirectory(path) + "..."; failed = false;
		UiActionQueue.custom(function() {
			if (token != loadToken) return;
			try {
				if (!sys.FileSystem.exists(path) || sys.FileSystem.isDirectory(path)) throw "File not found.";
				if (sys.FileSystem.stat(path).size > CombatLogDocument.MAX_BYTES) throw "Log exceeds the 16 MiB limit.";
				job = new CombatLogParseJob(sys.io.File.read(path));
				pump(token, path);
			} catch (e:Dynamic) { status = "Could not open log: " + Std.string(e); failed = true; loadingPath = ""; }
		});
	}
	function pump(token:Int, path:String):Void {
		if (token != loadToken || job == null) return;
		job.step(200);
		if (!job.done) {
			status = "Reading " + job.lines + " lines...";
			UiActionQueue.custom(function() pump(token, path));
			return;
		}
		if (job.error.length > 0) { status = "Could not import log: " + job.error; failed = true; }
		else {
			state.accept(job.result, path);
			viewKey = ""; seenRevision = -1;
			status = job.result.events.length + " events loaded."; failed = false;
		}
		job = null; loadingPath = "";
	}
	function cancelLoad():Void {
		loadToken++; if (job != null) job.cancel(); job = null; loadingPath = ""; status = "Import cancelled."; failed = false;
	}

	public function draw(atCap:Bool, choose:CombatLogAuraChoice->String->Void):Void {
		this.atCap = atCap; this.choose = choose;
		UiChrome.heading("Combat Logs", 1.3);
		ImGui.textWrapped("Explore a recorded fight, choose what to watch, then design an aura in Quick Build.");
		if (status.length > 0) {
			ImGui.pushTextWrapPos(0);
			ImGui.textColored(failed ? ImGui.vec4(1, 0.55, 0.35, 1) : ImGui.vec4(0.65, 0.72, 0.8, 1), status);
			ImGui.popTextWrapPos();
		}
		if (loadingPath.length > 0 && ImGui.smallButton("Cancel import##ab_cl_cancel")) cancelLoad();
		if (state.page == "files") { drawFiles(); return; }
		drawNavigation();
		if (state.analysis.document.legacy) ImGui.textWrapped("Legacy recording without a session header. The recorder may have trimmed earlier events.");
		if (state.page == "recording") drawTabs();
		if (state.page == "enemy") ImGui.textWrapped("Enemies are grouped by recorded name. Creatures with the same name may be combined.");
		refreshView();
		var currentKey = state.key();
		UiScope.child("##ab_cl_content_" + haxe.crypto.Md5.encode(state.path + currentKey), ImGui.vec2(0, 0), function() {
			if (restoreScroll) {
				var saved:Float = state.scroll.exists(currentKey) ? state.scroll.get(currentKey) : 0;
				ImGui.setScrollY(saved); restoreScroll = false;
			}
			if (state.page == "skill" || state.page == "damage") drawDetails();
			else {
				drawSearch();
				if (skills.length > 0) drawSkills();
				if (state.page == "enemy" || state.tab != "Me") drawEvents();
				else if (skills.length == 0) ImGui.textDisabled("No matching casts by the recording player.");
			}
			state.scroll.set(currentKey, ImGui.getScrollY());
		});
	}
	function drawFiles():Void {
		UiLayout.inlinePair("##ab_cl_files_actions", function(w:Single) {
			if (UiChrome.ghostButton(refreshing ? "Refreshing...##ab_cl_refresh" : "Refresh##ab_cl_refresh", ImGui.vec2(w, 28))) refresh();
		}, function(w:Single) {
			if (state.analysis != null && UiChrome.ghostButton("Continue selected fight##ab_cl_continue", ImGui.vec2(w, 28))) state.recording();
		});
		ImGui.textWrapped(folder.length > 0 ? folder : "Checking the default combat-log folder...");
		UiLayout.propertyGrid("##ab_cl_import", function() {
			UiLayout.propertyRow("Import another file", function() {
				ImGui.inputTextWithHint("##ab_cl_path", "Full path to an existing .jsonl recording", pathBuf, 1024);
			});
		});
		if (UiChrome.ghostButton("Open file from path##ab_cl_open_path", ImGui.vec2(-1, 28))) load(ByteUtil.readBytes(pathBuf, 1024));
		ImGui.textDisabled("Limits: 16 MiB / 20,000 events. Opening a recording never creates an aura.");
		UiScope.child("##ab_cl_files_list", ImGui.vec2(0, 0), function() {
			if (files.length == 0) ImGui.textWrapped("No recordings found. Import a file from another folder, or use the existing combat-log recorder to save a fight.");
			UiScope.table("##ab_cl_files", 3, function() {
				columns(["Recording", "Date", "Size"], [0.5, 0.35, 0.15]);
				clipped(files.length, function(i) {
					var file = files[i]; ImGui.tableNextRow(0, rowHeight());
					ImGui.tableSetColumnIndex(0);
					if (ImGui.selectable(text(file.name) + "##ab_cl_file_" + i, state.path == file.path)) load(file.path);
					ImGui.tableSetColumnIndex(1); ImGui.text(file.date);
					ImGui.tableSetColumnIndex(2); ImGui.text(Std.int(Math.ceil(file.bytes / 1024)) + " KiB");
				});
			}, tableFlags());
		});
	}
	function drawNavigation():Void {
		UiLayout.inlineSplit("##ab_cl_breadcrumb", state.page == "recording" ? 2 : state.page == "enemy" || state.enemy == null ? 3 : 4, function(i, w) {
			if (i == 0) { if (UiChrome.navButton("Recordings##ab_cl_files_nav", state.page=="files", ImGui.vec2(w, 28))) state.files(); }
			else if (i == 1) { if (UiChrome.navButton("Fight##ab_cl_fight_nav", state.page=="recording", ImGui.vec2(w, 28))) state.recording(); }
			else if (i == 2 && state.enemy != null) { if (UiChrome.navButton("Enemy##ab_cl_enemy_nav", state.page=="enemy", ImGui.vec2(w, 28))) state.selectEnemy(state.enemy); }
			else if (UiChrome.ghostButton("Back##ab_cl_back", ImGui.vec2(w, 28))) state.back();
		});
		ImGui.textWrapped(haxe.io.Path.withoutDirectory(state.path)
			+ (state.enemy != null && state.page != "recording" ? " > " + displaySource(state.enemy) : "")
			+ (state.skill != null && (state.page == "skill" || state.page == "damage") ? " > " + skillLabel(state.skill) : ""));
	}
	function drawTabs():Void {
		UiLayout.inlineSplit("##ab_cl_tabs", 3, function(i, w) {
			var tab = ["Enemies", "Me", "Damage taken"][i];
			if (UiChrome.navButton(tab + "##ab_cl_tab_" + i, state.tab == tab, ImGui.vec2(w, 32))) state.setTab(tab);
		});
	}
	function drawSearch():Void {
		if (ImGui.inputTextWithHint("##ab_cl_search", "Filter enemies or skills...", searchBuf, 160)) {
			state.setFilter(ByteUtil.readBytes(searchBuf, 160)); refreshView();
		}
	}
	function refreshView():Void {
		if (seenRevision == state.revision) return;
		var nextKey = state.key();
		if (viewKey != nextKey) { viewKey = nextKey; restoreScroll = true; ByteUtil.fillBuf(searchBuf, 160, state.filter()); }
		var query = state.filter().toLowerCase();
		events = [for (e in state.eventRows()) if (matches(e.skill, e.label, e.source, query)) e];
		skills = [for (s in state.skillRows()) if (matches(s.skill, s.label, s.source, query)) s];
		choices = state.page == "damage" ? CombatLogAuraChoices.damage(state.hit)
			: state.page == "skill" ? CombatLogAuraChoices.skill(state.skill, skillLabel(state.skill), statusInfo(state.skill)) : [];
		seenRevision = state.revision;
	}
	function drawSkills():Void {
		UiChrome.subHeader("Skills in this recording");
		UiScope.table("##ab_cl_skills", 4, function() {
			columns(["Skill", "Casts", "Damage / largest hit", "Examples"], [0.4, 0.1, 0.25, 0.25]);
			clipped(skills.length, function(i) {
				var s = skills[i]; ImGui.tableNextRow(0, rowHeight());
				ImGui.tableSetColumnIndex(0);
				skillLink(s.skill, skillLabel(s), "summary_" + i, function() {
					state.selectRow(s.events[0].row); state.selectSkill(s);
				}, state.rowSelected(s.events[0].row));
				ImGui.tableSetColumnIndex(1); ImGui.text(Std.string(s.casts));
				ImGui.tableSetColumnIndex(2); ImGui.text(number(s.damage) + " / " + number(s.largest));
				ImGui.tableSetColumnIndex(3); ImGui.text([for (e in s.examples) state.analysis.document.time(e)].join(", "));
			});
		}, tableFlags());
	}
	function drawEvents():Void {
		UiChrome.subHeader(state.page == "enemy" ? "Cast history" : state.page == "skill" ? "Recorded history" : state.tab == "Damage taken" ? "Hits on the recording player" : "Enemy cast history");
		if (events.length == 0) { ImGui.textDisabled("No matching recorded events."); return; }
		var damage = state.page == "recording" && state.tab == "Damage taken";
		UiScope.table("##ab_cl_events", damage ? 5 : 4, function() {
			if (damage) columns(["Time", "Source", "Skill", "Damage", "Action"], [0.13, 0.19, 0.3, 0.12, 0.26]);
			else columns(["Time", "Enemy / source", "Skill", "Event"], [0.15, 0.25, 0.4, 0.2]);
			clipped(events.length, function(i) {
				var e = events[i]; ImGui.tableNextRow(0, rowHeight());
				ImGui.tableSetColumnIndex(0); ImGui.text(state.analysis.document.time(e));
				ImGui.tableSetColumnIndex(1);
				if (state.page == "recording" && e.sourceRole == CombatLogDocument.ENEMY) {
					if (ImGui.selectable(text(displaySource(e.source)) + "##ab_cl_enemy_" + e.row, state.rowSelected(e.row))) {
						state.selectRow(e.row); state.selectEnemy(e.source);
					}
				} else ImGui.text(displaySource(e.source));
				ImGui.tableSetColumnIndex(2);
				if (state.page == "skill") ImGui.text(eventLabel(e));
				else skillLink(e.skill, eventLabel(e), "event_" + e.row, function() {
					state.selectRow(e.row); state.selectSkill(state.analysis.forEvent(e));
				}, state.rowSelected(e.row));
				ImGui.tableSetColumnIndex(3); ImGui.text(damage ? number(e.amount) : e.kind == "hit" ? "hit " + number(e.amount) : e.kind);
				if (damage) {
					ImGui.tableSetColumnIndex(4);
					if (e.amount > 0 && ImGui.smallButton("Build damage warning##ab_cl_damage_" + e.row)) {
						state.selectRow(e.row); state.selectHit(e);
					}
				}
			});
		}, tableFlags());
	}
	function drawDetails():Void {
		if (state.skill == null) return;
		var label = skillLabel(state.skill);
		UiChrome.subHeader(state.page == "damage" ? "Damage warning" : label);
		UiLayout.propertyGrid("##ab_cl_metrics", function() {
			UiLayout.propertyRow("Skill ID", function() ImGui.textWrapped(state.skill.skill.length > 0 ? state.skill.skill : "No skill ID recorded"));
			UiLayout.propertyRow("Recorded metrics", function() ImGui.textWrapped(state.skill.casts + " casts / " + state.skill.hits + " hits / "
				+ number(state.skill.damage) + " damage / " + number(state.skill.largest) + " largest hit"));
			if (state.page == "damage") UiLayout.propertyRow("Selected hit", function() ImGui.textWrapped(number(state.hit.amount)
				+ " damage from " + displaySource(state.hit.source) + " at " + state.analysis.document.time(state.hit)));
		});
		ImGui.textWrapped("Totals cover recorded hits for this source and skill, not individual cast instances. Missing log events are not reconstructed.");
		if (state.page == "damage" && state.skill.skill.length > 0) {
			if (UiChrome.ghostButton("Explore causing skill##ab_cl_explore_damage_skill", ImGui.vec2(-1, 28))) state.selectSkill(state.skill);
		}
		var width = ImGui.getContentRegionAvail().x;
		if (state.page == "skill" && width >= 780) {
			UiScope.table("##ab_cl_detail_columns", 2, function() {
				ImGui.tableSetupColumn("History", ImGuiTableColumnFlags.WidthStretch, 0.5);
				ImGui.tableSetupColumn("Aura choices", ImGuiTableColumnFlags.WidthStretch, 0.5);
				ImGui.tableNextRow();
				ImGui.tableSetColumnIndex(0); drawEvents();
				ImGui.tableSetColumnIndex(1); drawChoices(label);
			}, ImGuiTableFlags.SizingStretchProp | ImGuiTableFlags.NoSavedSettings);
		} else {
			drawChoices(label);
			if (state.page == "skill") drawEvents();
		}
	}
	function drawChoices(label:String):Void {
		UiChrome.subHeader("Aura choices");
		if (choices.length == 0) ImGui.textWrapped("No supported aura mapping for this recorded event. You can still browse its history.");
		if (atCap) ImGui.textWrapped("Aura limit reached. Delete an aura to create another; browsing remains available.");
		var count = state.showMore ? choices.length : Std.int(Math.min(5, choices.length));
		for (i in 0...count) {
			var option = choices[i];
			ImGui.beginDisabled(atCap);
			var clicked = false;
			try { clicked = ImGui.selectable(text(option.title) + "##ab_cl_choice_" + option.id, false); }
			catch (e:Dynamic) { ImGui.endDisabled(); throw e; }
			ImGui.endDisabled();
			if (ImGui.isItemHovered()) ImGui.setTooltip(option.reason);
			if (clicked && choose != null) choose(option, label);
		}
		if (choices.length > 5 && ImGui.selectable(state.showMore ? "Show fewer##ab_cl_more" : "Show more##ab_cl_more", false)) state.showMore = !state.showMore;
	}
	function skillLink(id:String, label:String, key:String, action:Void->Void, selected:Bool = false):Void {
		if (id.length == 0) { ImGui.text(label); return; }
		var icon = CdbAuraTable.iconStem(id); if (icon.length == 0) icon = id;
		if (GameIcons.imageKey(icon, 18, 18)) ImGui.sameLine(0, 6);
		if (ImGui.selectable(text(label) + "##ab_cl_skill_" + key, selected)) action();
		if (ImGui.isItemHovered()) ImGui.setTooltip(label + "\n" + id);
	}
	function statusInfo(stats:CombatLogSkillStats):CombatLogStatusInfo {
		if (stats == null) return null;
		var id = CdbAuraTable.isStatus(stats.skill) ? stats.skill : CdbAuraTable.grantedStatusId(stats.skill);
		if (id.length == 0 || !CdbAuraTable.isStatus(id)) return null;
		return {id:id, label:CombatLogAnalysis.label(id, "", CdbAuraTable.name), duration:CdbAuraTable.duration(id), stacks:CdbAuraTable.maxStacks(id)};
	}
	function skillLabel(stats:CombatLogSkillStats):String return stats != null ? CombatLogAnalysis.label(stats.skill, stats.label, CdbAuraTable.name) : "Unknown skill";
	function eventLabel(event:CombatLogEvent):String return CombatLogAnalysis.label(event.skill, event.label, CdbAuraTable.name);
	function matches(id:String, label:String, source:String, query:String):Bool
		return query.length == 0 || (id + " " + label + " " + source + " " + CdbAuraTable.name(id)).toLowerCase().indexOf(query) >= 0;
	static function displaySource(name:String):String return name.length > 0 ? text(name) : "Unknown source";
	static function text(value:String):String return StringTools.replace(StringTools.replace(StringTools.replace(value, "##", "# #"), "\n", " "), "\r", " ");
	static function number(value:Float):String return Math.isFinite(value)
		? Std.string(value < 1e12 ? Math.ffloor(value * 10 + 0.5) / 10 : value) : "unavailable";
	static function tableFlags():Int return ImGuiTableFlags.RowBg | ImGuiTableFlags.BordersInnerH | ImGuiTableFlags.SizingStretchProp | ImGuiTableFlags.NoSavedSettings;
	static function rowHeight():Single return Math.max(24, ImGui.getFrameHeight() + 4);
	static function columns(names:Array<String>, weights:Array<Float>):Void {
		for (i in 0...names.length) ImGui.tableSetupColumn(names[i], ImGuiTableColumnFlags.WidthStretch, weights[i]);
		ImGui.tableHeadersRow();
	}
	static function clipped(count:Int, row:Int->Void):Void {
		var clipper = ImGui.ImGuiListClipper_ImGuiListClipper();
		try {
			ImGui.ImGuiListClipper_Begin(clipper, count, rowHeight());
			while (ImGui.ImGuiListClipper_Step(clipper))
				for (i in ImGui.ImGuiListClipper_get_DisplayStart(clipper)...ImGui.ImGuiListClipper_get_DisplayEnd(clipper)) row(i);
		} catch (e:Dynamic) { ImGui.ImGuiListClipper_destroy(clipper); throw e; }
		ImGui.ImGuiListClipper_destroy(clipper);
	}
}
