package solarflare.aura.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;
import solarflare.aura.AuraConfig;
import solarflare.aura.AuraDef;
import solarflare.aura.AuraEngine;
import solarflare.aura.AuraQuickBuildDraft;
import solarflare.aura.AuraSetDef;
import solarflare.aura.CombatLogAuraChoices;
import solarflare.aura.CombatLogAuraChoices.CombatLogAuraChoice;
import solarflare.aura.CombatLogAuraChoices.CombatLogStatusInfo;
import solarflare.combatlog.CombatLogDocument;
import solarflare.combatlog.CombatLogDocument.CombatLogEvent;
import solarflare.combatlog.CombatLogDocument.CombatLogParseJob;
import solarflare.combatlog.CombatLogAnalysis;
import solarflare.combatlog.CombatLogAnalysis.CombatLogEnemy;
import solarflare.combatlog.CombatLogAnalysis.CombatLogSkillStats;
import solarflare.combatlog.CombatLogBrowserState;
import solarflare.combatlog.CombatLogRecorder;
import solarflare.cdb.AuraCatalog;
import solarflare.cdb.AuraQuickStartCatalog;
import solarflare.cdb.CdbAuraTable;
import solarflare.ui.ByteUtil;
import solarflare.ui.GameIcons;
import solarflare.ui.SettingsStore;
import solarflare.ui.ThemePalette;
import solarflare.ui.UiActionQueue;
import solarflare.ui.UiChrome;
import solarflare.ui.UiLayout;
import solarflare.ui.UiScope;

private typedef RecordingFile = { var path:String; var name:String; var title:String; var detail:String; var modified:Float; var bytes:Int; var map:String; }
/** One line of the recordings list: a map heading (file == null) or a recording under it. */
private typedef ListRow = { var heading:String; var sub:String; var file:RecordingFile; }
private typedef AbilityRow = { var stats:CombatLogSkillStats; var key:String; var label:String; var icon:String; var metrics:String; var times:String; var choices:Array<CombatLogAuraChoice>; var share:Single; }
private typedef Lane = { var label:String; var ticks:Array<Float>; }
private typedef Unit = { var id:String; var icon:String; }
private typedef CardBox = { var clicked:Bool; var x:Single; var y:Single; var hovered:Bool; }

/**
 * Boss Mods workspace. Recordings on the left; the canvas on the right is split into tabs (Enemies, Your skills,
 * Damage taken, Aura Sets). Building a single aura is the main path; Aura Sets are optional and only exist when
 * the player makes one. It reads saved recordings only and creates nothing except through the host.
 */
class CombatLogBrowser {
	static inline var MAX_ROWS:Int = 80;
	static inline var MAX_FILES:Int = 200;
	static inline var MAX_LANES:Int = 8;
	static inline var MAX_TICKS:Int = 40;
	static inline var FILE_CARD_H:Single = 52;
	static inline var FILE_ROW_H:Single = 58;
	static inline var ENEMY_MIN_W:Single = 118;
	static inline var ENEMY_MAX_COLS:Int = 6;
	static inline var ENEMY_CARD_H:Single = 118;
	static inline var GRID_GAP:Single = 8;
	static inline var GRID_SCROLL:Single = 16;
	static inline var GRID_MAX_ROWS:Int = 2;
	static inline var WIDE_DETAIL:Single = 760;
	static inline var PORTRAIT:Single = 72;
	static var STYLE_LABELS:Array<String> = ["Banner + icon", "Countdown", "Glow"];
	static var MODE_LABELS:Array<String> = ["Always", "On chosen maps", "Off"];
	static var MONTHS:Array<String> = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
	static var unitIndex:Map<String, Array<String>> = null;

	var state = new CombatLogBrowserState();
	var host:BossModsHost;
	var cfg:AuraConfig;
	var files:Array<RecordingFile> = [];
	/** `files` grouped under their map, built once per refresh. */
	var listRows:Array<ListRow> = [];
	/** Enemies of the open recording with bosses first, and which of them are bosses. Built once per recording. */
	var enemyOrder:Array<CombatLogEnemy> = [];
	var bossNames:Map<String, Bool> = new Map();
	var folder = "";
	var status = "";
	var failed = false;
	var refreshing = false;
	var job:CombatLogParseJob = null;
	var loadingPath = "";
	var loadToken = 0;
	var importOpen = false;
	var pathBuf = new hl.Bytes(1024);
	var searchBuf = new hl.Bytes(160);
	var newSetBuf = new hl.Bytes(64);
	var batchNewSetBuf = new hl.Bytes(64);
	var batchSetId = "";
	var batchNewSetOpen = false;
	var armOnMap = new BoolRef(false);
	var pickRef = new BoolRef(false);
	var healthRef = new IntRef(50);
	var seenRevision = -1;
	var viewKey = "";
	var seenRecorderPath = "";
	var rows:Array<AbilityRow> = [];
	var hits:Array<CombatLogEvent> = [];
	var lanes:Array<Lane> = [];
	var enemyInfo:CombatLogEnemy = null;
	var lastResult = "";
	var lastResultFailed = false;
	var atCap = false;
	var slotsFree = 0;
	/** Damage the open enemy dealt to you: all of it, and the part no listed attack accounts for (DoTs, hit-only skills). */
	var enemyTaken = 0.0;
	var enemyTakenHits = 0;
	var otherTaken = 0.0;
	var otherHits = 0;
	/** Hits on you from sources that never cast in this recording (traps, effects). Cached per recording. */
	var strayHits = 0;
	var strayTaken = 0.0;
	var indexed:CombatLogAnalysis = null;

	public function new() {
		ByteUtil.clearBytes(pathBuf, 1024);
		ByteUtil.clearBytes(searchBuf, 160);
		ByteUtil.clearBytes(newSetBuf, 64);
		ByteUtil.clearBytes(batchNewSetBuf, 64);
	}

	/** Opening the workspace refreshes the list when it has never loaded, or a new recording started since. */
	public function enter():Void {
		if ((folder.length == 0 || seenRecorderPath != CombatLogRecorder.lastPath) && !refreshing) refresh(false);
	}

	/** Camera mode or a closed builder: stop any parse in flight; keep the loaded recording. */
	public function suspend():Void {
		if (loadingPath.length > 0) cancelLoad();
		lastResult = "";
		batchNewSetOpen = false;
	}

	// ---------------------------------------------------------------------------------------------
	// Files and loading
	// ---------------------------------------------------------------------------------------------

	function refresh(reloadCurrent:Bool):Void {
		if (refreshing) return;
		refreshing = true;
		seenRecorderPath = CombatLogRecorder.lastPath;
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
						next.push({path: path, name: name, title: "", detail: "", modified: info.mtime.getTime(), bytes: info.size, map: ""});
					} catch (_:Dynamic) {}
				}
				next.sort(function(a, b) return a.modified > b.modified ? -1 : a.modified < b.modified ? 1 : Reflect.compare(a.name, b.name));
				if (next.length > MAX_FILES) next.resize(MAX_FILES);
				for (file in next) describe(file);
				files = next; listRows = groupByMap(next); failed = false;
				status = "";
				// First visit: open the newest one so there is something to look at straight away.
				if (state.analysis == null && files.length > 0 && loadingPath.length == 0) load(files[0].path);
				else if (reloadCurrent && state.path.length > 0 && loadingPath.length == 0) load(state.path);
			} catch (e:Dynamic) { folder = folder == null ? "" : folder; status = "Could not list recordings: " + Std.string(e); failed = true; }
			refreshing = false;
		});
	}

	/** Map headings, newest map first (unknown maps last), each followed by its recordings, newest first. */
	static function groupByMap(source:Array<RecordingFile>):Array<ListRow> {
		var groups:Map<String, Array<RecordingFile>> = new Map();
		var order:Array<String> = [];
		for (file in source) {
			if (!groups.exists(file.map)) { groups.set(file.map, []); order.push(file.map); }
			groups.get(file.map).push(file);
		}
		// `source` is newest first, so the first file of each group is its newest; unknown goes to the end.
		var rank = function(map:String):Int return map.length == 0 ? 1 : 0;
		var position = [for (i in 0...order.length) order[i] => i];
		order.sort(function(a, b) return rank(a) != rank(b) ? rank(a) - rank(b) : position.get(a) - position.get(b));
		var out:Array<ListRow> = [];
		for (map in order) {
			var list = groups.get(map);
			out.push({heading: map.length > 0 ? text(map) : "Map not recorded", sub: list.length + (list.length == 1 ? " recording" : " recordings"), file: null});
			for (file in list) out.push({heading: "", sub: "", file: file});
		}
		return out;
	}

	/** Card text: "Oct 3   19:08" over "412 KiB". The map comes from the recording's first line when it has one and drives the grouping. */
	static function describe(file:RecordingFile):Void {
		var map = "";
		try {
			var input = sys.io.File.read(file.path);
			try {
				var header:Dynamic = haxe.Json.parse(input.readLine());
				if (header != null && Std.isOfType(header.map, String)) map = header.map;
			} catch (_:Dynamic) {}
			input.close();
		} catch (_:Dynamic) {}
		var date = Date.fromTime(file.modified);
		file.title = MONTHS[date.getMonth()] + " " + date.getDate() + "   " + DateTools.format(date, "%H:%M");
		file.map = solarflare.aura.AuraSetDef.normalizeMap(map);
		file.detail = Std.int(Math.ceil(file.bytes / 1024)) + " KiB";
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
			seenRevision = -1; lastResult = ""; batchSetId = ""; batchNewSetOpen = false;
			status = ""; failed = false;
		}
		job = null; loadingPath = "";
	}

	function cancelLoad():Void {
		loadToken++; if (job != null) job.cancel(); job = null; loadingPath = ""; status = "Import cancelled."; failed = false;
	}

	// ---------------------------------------------------------------------------------------------
	// Frame
	// ---------------------------------------------------------------------------------------------

	public function draw(host:BossModsHost):Void {
		this.host = host;
		cfg = host.bossCfg();
		atCap = cfg.auras.length >= AuraEngine.MAX;
		slotsFree = AuraEngine.MAX - cfg.auras.length;
		if (seenRecorderPath != CombatLogRecorder.lastPath && !refreshing && folder.length > 0) refresh(false);
		drawStatusRow();
		refreshView();
		var avail = ImGui.getContentRegionAvail();
		if (avail.x >= 640) {
			UiScope.child("##ab_cl_left", ImGui.vec2(Math.min(270, Math.max(220, avail.x * 0.24)), 0), drawLeft, ImGuiChildFlags.Borders);
			ImGui.sameLine(0, 8);
			UiScope.child("##ab_cl_right", ImGui.vec2(0, 0), drawRight);
		} else {
			UiScope.child("##ab_cl_left", ImGui.vec2(0, 210), drawLeft, ImGuiChildFlags.Borders);
			UiScope.child("##ab_cl_right", ImGui.vec2(0, 0), drawRight);
		}
	}

	function drawStatusRow():Void {
		var recording = CombatLogRecorder.enabled.get();
		UiLayout.inlinePair("##ab_cl_status", function(w:Single) {
			ImGui.textColored(ThemePalette.status(recording ? ThemePalette.STATUS_SUCCESS : ThemePalette.STATUS_INFO),
				recording ? "RECORDING" : "RECORDING OFF");
			ImGui.sameLine(0, 8);
			if (status.length > 0 && (failed || loadingPath.length > 0 || refreshing))
				ImGui.textColored(ThemePalette.status(failed ? ThemePalette.STATUS_DANGER : ThemePalette.STATUS_INFO), status);
			else ImGui.textDisabled(state.analysis != null ? summary() : (recording ? CombatLogRecorder.lastStatus : "Fights are not being saved."));
		}, function(w:Single) {
			if (loadingPath.length > 0) {
				if (UiChrome.ghostButton("Cancel##ab_cl_cancel", ImGui.vec2(Math.max(70, w), 26))) cancelLoad();
			} else if (UiChrome.ghostButton((recording ? "Stop recording" : "Turn on recording") + "##ab_cl_rec", ImGui.vec2(Math.max(120, w), 26))) {
				CombatLogRecorder.setCapture(!recording);
				SettingsStore.markDirty();
			}
		}, 6);
	}

	function summary():String {
		var doc = state.analysis.document;
		var map = doc.mapId.length > 0 ? " | " + doc.mapId : "";
		return haxe.io.Path.withoutDirectory(state.path) + map + " | " + CombatLogDocument.clock(state.analysis.duration)
			+ " | " + state.analysis.enemyList.length + " enemies";
	}

	// ---------------------------------------------------------------------------------------------
	// Cards: one hit area, theme-aware plate, accent when selected
	// ---------------------------------------------------------------------------------------------

	static function cardBox(id:String, w:Single, h:Single, selected:Bool):CardBox {
		var theme = ThemePalette.current();
		var p = ImGui.getCursorScreenPos();
		var clicked = ImGui.invisibleButton(id, ImGui.vec2(w, h));
		var hovered = ImGui.isItemHovered();
		var dl = ImGui.getWindowDrawList();
		var max = ImGui.vec2(p.x + w, p.y + h);
		var mix:Single = selected ? 0.34 : hovered ? 0.12 : 0;
		var fill = ImGui.colorConvertFloat4ToU32(ImGui.vec4(
			theme.cellBg.x * (1 - mix) + theme.accent.x * mix,
			theme.cellBg.y * (1 - mix) + theme.accent.y * mix,
			theme.cellBg.z * (1 - mix) + theme.accent.z * mix, 0.96));
		ImGui.ImDrawList_AddRectFilled(dl, p, max, fill, 10);
		ImGui.ImDrawList_AddRect(dl, p, max, ImGui.colorConvertFloat4ToU32(selected ? theme.accent : theme.border), 10, selected ? 2 : 1, 0);
		return {clicked: clicked, x: p.x, y: p.y, hovered: hovered};
	}

	/** Portrait plate with the unit's art, or its first letter when the atlas has none. */
	static function drawPortrait(x:Single, y:Single, size:Single, unit:Unit, name:String):Void {
		var theme = ThemePalette.current();
		var dl = ImGui.getWindowDrawList();
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + size, y + size),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(theme.windowBg.x * 0.8, theme.windowBg.y * 0.8, theme.windowBg.z * 0.8, 0.95)), 8);
		var drawn = unit.icon.length > 0 && GameIcons.drawKey(dl, unit.icon, x + 3, y + 3, size - 6, size - 6);
		if (!drawn) {
			var letter = name.length > 0 ? name.substr(0, 1).toUpperCase() : "?";
			var ts = ImGui.calcTextSize(letter);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x + (size - ts.x) * 0.5, y + (size - ts.y) * 0.5),
				ImGui.colorConvertFloat4ToU32(theme.textDisabled), letter);
		}
	}

	static function drawTextIn(x:Single, y:Single, width:Single, text:String, muted:Bool, center:Bool):Void {
		var theme = ThemePalette.current();
		var dl = ImGui.getWindowDrawList();
		var ts = ImGui.calcTextSize(text);
		ImGui.ImDrawList_PushClipRect(dl, ImGui.vec2(x, y - 2), ImGui.vec2(x + width, y + ts.y + 4), true);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(center ? x + Math.max(0, (width - ts.x) * 0.5) : x, y),
			ImGui.colorConvertFloat4ToU32(muted ? theme.textDisabled : theme.text), text);
		ImGui.ImDrawList_PopClipRect(dl);
	}

	// ---------------------------------------------------------------------------------------------
	// Left pane: recordings
	// ---------------------------------------------------------------------------------------------

	function drawLeft():Void {
		UiChrome.sectionHeader("Recordings");
		UiLayout.inlinePair("##ab_cl_files_head", function(w:Single) {
			ImGui.textDisabled(files.length == 0 ? "None yet" : files.length + (files.length == 1 ? " recording" : " recordings"));
		}, function(w:Single) {
			if (UiChrome.ghostButton((refreshing ? "..." : "Refresh") + "##ab_cl_refresh", ImGui.vec2(Math.max(70, w), 24)))
				refresh(CombatLogRecorder.enabled.get());
		}, 4);
		var importHeight:Single = importOpen ? 118 : 36;
		var listHeight:Single = Math.max(90, ImGui.getContentRegionAvail().y - importHeight);
		UiScope.child("##ab_cl_files", ImGui.vec2(0, listHeight), function() {
			var width = ImGui.getContentRegionAvail().x;
			clipped(listRows.length, FILE_ROW_H, function(i) {
				var row = listRows[i];
				var file = row.file;
				if (file == null) {
					// Map heading: the map is how a boss fight is told apart from the next.
					var at = ImGui.getCursorScreenPos();
					ImGui.dummy(ImGui.vec2(width, FILE_CARD_H));
					drawTextIn(at.x + 4, at.y + 12, width - 8, row.heading, false, false);
					drawTextIn(at.x + 4, at.y + 32, width - 8, row.sub, true, false);
					ImGui.ImDrawList_AddLine(ImGui.getWindowDrawList(), ImGui.vec2(at.x, at.y + FILE_CARD_H - 2), ImGui.vec2(at.x + width, at.y + FILE_CARD_H - 2),
						ImGui.colorConvertFloat4ToU32(ThemePalette.current().accent), 1);
					return;
				}
				var box = cardBox("##ab_cl_file_" + file.name, width, FILE_CARD_H, state.path == file.path);
				if (box.clicked) load(file.path);
				drawTextIn(box.x + 12, box.y + 9, width - 20, file.title, false, false);
				drawTextIn(box.x + 12, box.y + 29, width - 20, file.detail, true, false);
				if (box.hovered) ImGui.setTooltip(file.name);
			});
		});
		if (UiChrome.ghostButton((importOpen ? "Hide import" : "Import a file...") + "##ab_cl_import_toggle", ImGui.vec2(-1, 28))) importOpen = !importOpen;
		if (importOpen) {
			ImGui.setNextItemWidth(-1);
			ImGui.inputTextWithHint("##ab_cl_path", "Full path to a .jsonl recording", pathBuf, 1024);
			if (UiChrome.ghostButton("Open##ab_cl_open_path", ImGui.vec2(90, 26))) load(ByteUtil.readBytes(pathBuf, 1024));
		}
	}

	// ---------------------------------------------------------------------------------------------
	// Right pane: tabs and content
	// ---------------------------------------------------------------------------------------------

	function drawRight():Void {
		if (state.analysis == null) { drawEmpty(); return; }
		drawTabs();
		UiChrome.gap(UiChrome.SP_S);
		UiScope.child("##ab_cl_content", ImGui.vec2(0, 0), function() {
			var key = state.view + "|" + state.enemy + "|" + state.path;
			if (key != viewKey) { viewKey = key; ImGui.setScrollY(0); ByteUtil.clearBytes(searchBuf, 160); }
			if (state.view == CombatLogBrowserState.VIEW_MINE) drawMine();
			else if (state.view == CombatLogBrowserState.VIEW_DAMAGE) drawDamage();
			else if (state.view == CombatLogBrowserState.VIEW_SETS) drawSets();
			else drawEnemies();
		});
	}

	function drawTabs():Void {
		var analysis = state.analysis;
		// Fights come first; your own skills are a last-place extra, not the point of this window.
		var labels = ["Enemies (" + analysis.enemyList.length + ")", "Damage taken (" + analysis.damageTaken.length + ")",
			"Aura Sets (" + cfg.sets.length + ")", "Your skills (" + analysis.mySkills.length + ")"];
		var views = [CombatLogBrowserState.VIEW_ENEMY, CombatLogBrowserState.VIEW_DAMAGE, CombatLogBrowserState.VIEW_SETS, CombatLogBrowserState.VIEW_MINE];
		UiLayout.inlineSplit("##ab_cl_tabs", 4, function(i:Int, w:Single) {
			if (!UiChrome.navButton(labels[i] + "##ab_cl_tab_" + i, state.view == views[i], ImGui.vec2(w, 38))) return;
			if (i == 0) state.showEnemies();
			else if (i == 1) state.selectDamage();
			else if (i == 2) state.selectSets();
			else state.selectMine();
		}, 6);
	}

	function drawEmpty():Void {
		var recording = CombatLogRecorder.enabled.get();
		UiChrome.sectionHeader(loadingPath.length > 0 ? "Opening recording..." : "No recording open");
		if (loadingPath.length > 0) return;
		if (files.length > 0) { ImGui.textWrapped("Choose a recording on the left."); return; }
		ImGui.textWrapped(recording
			? "Recording is on. Fight something and the recording appears here, with every enemy and ability it used."
			: "Record a fight, then come back here to turn what happened into alerts.");
		ImGui.spacing();
		ImGui.textDisabled("1. Turn on recording");
		ImGui.textDisabled("2. Fight. Nearby enemy casts are saved too");
		ImGui.textDisabled("3. Open the recording and pick an enemy or skill");
		ImGui.spacing();
		if (!recording && UiChrome.accentButton("Turn on recording##ab_cl_empty_rec", ImGui.vec2(190, 32))) {
			CombatLogRecorder.setCapture(true);
			SettingsStore.markDirty();
		}
	}

	// ---------------------------------------------------------------------------------------------
	// Enemies tab
	// ---------------------------------------------------------------------------------------------

	function drawEnemies():Void {
		var analysis = state.analysis;
		if (analysis.enemyList.length == 0) {
			UiChrome.sectionHeader("Enemies");
			ImGui.textWrapped("No enemy casts were saved in this recording. Turn on recording before a fight, and nearby enemy casts are kept.");
			return;
		}
		UiChrome.sectionHeader("Pick an enemy");
		var mapId = state.analysis.document.mapId;
		var bossCount = 0;
		for (_ in bossNames.keys()) bossCount++;
		ImGui.textDisabled((mapId.length > 0 ? "Map: " + text(mapId) : "Map not recorded for this fight")
			+ "  |  " + (bossCount > 0 ? bossCount + (bossCount == 1 ? " boss" : " bosses") + " identified, listed first" : "no known boss among these enemies"));
		drawEnemyGrid(enemyOrder);
		if (strayHits > 0) drawStrayNote();
		if (state.enemy == null) return;
		ImGui.spacing();
		var name = state.enemy;
		if (ImGui.getContentRegionAvail().x >= WIDE_DETAIL) {
			// Wide canvas: who it is on the left, the health alert beside it.
			UiLayout.inlineSplit("##ab_cl_enemy_top", 2, function(i:Int, w:Single) {
				if (i == 0) drawEnemyHeader(name);
				else drawHealthAlert(name);
			}, 14);
		} else {
			drawEnemyHeader(name);
			drawHealthAlert(name);
		}
		drawAbilityAlerts(name);
	}

	/** Responsive card grid: as many columns as fit (up to ENEMY_MAX_COLS), cards stretch to fill the row. Scrolls past two rows. */
	function drawEnemyGrid(list:Array<CombatLogEnemy>):Void {
		var avail = ImGui.getContentRegionAvail().x;
		var columns = UiLayout.columnCount(avail - GRID_SCROLL, ENEMY_MIN_W, ENEMY_MAX_COLS, GRID_GAP);
		var rowCount = Std.int(Math.ceil(list.length / columns));
		var drawRows = function() {
			for (r in 0...rowCount) {
				UiLayout.inlineSplit("##ab_cl_enemy_row_" + r, columns, function(i:Int, w:Single) {
					var index = r * columns + i;
					if (index < list.length) drawEnemyCard(list[index], w);
				}, GRID_GAP);
				ImGui.dummy(ImGui.vec2(0, GRID_GAP));
			}
		};
		if (rowCount <= GRID_MAX_ROWS)
			UiScope.child("##ab_cl_enemy_grid", ImGui.vec2(0, 0), drawRows, ImGuiChildFlags.AutoResizeY, ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse);
		else
			UiScope.child("##ab_cl_enemy_grid", ImGui.vec2(0, GRID_MAX_ROWS * (ENEMY_CARD_H + GRID_GAP + 8) + 4), drawRows);
	}

	function drawEnemyCard(enemy:CombatLogEnemy, width:Single):Void {
		var unit = unitFor(enemy.name);
		var selected = state.view == CombatLogBrowserState.VIEW_ENEMY && state.enemy == enemy.name;
		var box = cardBox("##ab_cl_enemy_" + enemy.name, width, ENEMY_CARD_H, selected);
		if (box.clicked) state.selectEnemy(enemy.name);
		drawPortrait(box.x + (width - 64) * 0.5, box.y + 8, 64, unit, enemy.name);
		drawTextIn(box.x + 6, box.y + 78, width - 12, displaySource(enemy.name), false, true);
		drawTextIn(box.x + 6, box.y + 96, width - 12, enemy.casts + (enemy.casts == 1 ? " cast" : " casts"), true, true);
		if (bossNames.exists(enemy.name))
			ImGui.ImDrawList_AddText_Vec2(ImGui.getWindowDrawList(), ImGui.vec2(box.x + 8, box.y + 5), ImGui.colorConvertFloat4ToU32(ThemePalette.current().accent), "BOSS");
		if (box.hovered) ImGui.setTooltip(displaySource(enemy.name) + "\n" + (unit.id.length > 0 ? unit.id : "Unit not identified"));
	}

	/** Damage that no enemy card can show: sources with no recorded cast. The full Damage taken tab lists every hit. */
	function drawStrayNote():Void {
		UiLayout.inlinePair("##ab_cl_stray", function(w:Single) {
			ImGui.pushTextWrapPos(0);
			ImGui.textDisabled(strayHits + (strayHits == 1 ? " hit" : " hits") + " on you (" + number(strayTaken)
				+ " damage) came from sources with no recorded cast, such as traps or effects, so they are not under an enemy.");
			ImGui.popTextWrapPos();
		}, function(w:Single) {
			if (UiChrome.ghostButton("Open Damage taken##ab_cl_stray_open", ImGui.vec2(Math.max(150, w), 26))) state.selectDamage();
		}, 8);
	}

	function drawEnemyHeader(name:String):Void {
		var unit = unitFor(name);
		var start = ImGui.getCursorScreenPos();
		var avail = ImGui.getContentRegionAvail().x;
		ImGui.dummy(ImGui.vec2(avail, 80));
		var after = ImGui.getCursorScreenPos();
		drawPortrait(start.x, start.y + 2, 72, unit, name);
		var font = ImGui.getFont();
		ImGui.setCursorScreenPos(ImGui.vec2(start.x + 88, start.y + 6));
		if (font != null) ImGui.pushFont(font, ImGui.getFontSize() * 1.35);
		ImGui.text(displaySource(name));
		if (font != null) ImGui.popFont();
		ImGui.setCursorScreenPos(ImGui.vec2(start.x + 88, start.y + 40));
		if (enemyInfo != null)
			ImGui.textDisabled(enemyInfo.abilities + " abilities | " + enemyInfo.casts + " casts"
				+ (Math.isFinite(enemyInfo.firstT) ? " | first seen " + CombatLogDocument.clock(enemyInfo.firstT) : ""));
		ImGui.setCursorScreenPos(ImGui.vec2(start.x + 88, start.y + 58));
		ImGui.textDisabled((bossNames.exists(name) ? "Boss | " : "") + (unit.id.length > 0 ? "Unit: " + unit.id : "Unit not identified"));
		ImGui.setCursorScreenPos(after);
	}

	function drawHealthAlert(name:String):Void {
		var unit = unitFor(name);
		UiChrome.sectionHeader("Health alert");
		ImGui.pushTextWrapPos(0);
		ImGui.textDisabled("Warn when this enemy reaches a health level, for example the moment a boss starts a new phase. You must be targeting it.");
		ImGui.popTextWrapPos();
		UiLayout.propertyGrid("##ab_cl_health", function() {
			UiLayout.propertyRow("Warn at", function() {
				healthRef.set(state.healthPercent);
				ImGui.setNextItemWidth(-1);
				if (solarflare.ui.NumberField.drawInt("##ab_cl_hp", healthRef, 5, 95, "%.0f%%")) state.setHealthPercent(healthRef.get());
			}, "The alert shows once this enemy's health is at or below this percent.");
		});
		if (enemyInfo != null && Math.isFinite(enemyInfo.lowestHp))
			ImGui.textDisabled("In this recording its health went from " + Std.int(Math.round(enemyInfo.highestHp * 100)) + "% down to "
				+ Std.int(Math.round(enemyInfo.lowestHp * 100)) + "%.");
		if (unit.id.length == 0) {
			ImGui.pushTextWrapPos(0);
			ImGui.textDisabled("This unit could not be identified, so the alert will trigger for any boss you target.");
			ImGui.popTextWrapPos();
		}
		disabled(atCap, function() {
			if (UiChrome.ghostButton("Build health alert##ab_cl_build_health", ImGui.vec2(220, 30)))
				host.bossBuild(AuraQuickBuildDraft.forBossHealth(unit.id, displaySource(name), state.healthPercent / 100.0, unit.icon));
		});
		ImGui.spacing();
	}

	function drawAbilityAlerts(name:String):Void {
		UiChrome.sectionHeader("Attacks and damage");
		ImGui.pushTextWrapPos(0);
		ImGui.textDisabled("Every skill this enemy cast, with the damage it did to you. Each alert watches that skill's ID from any enemy, so it fires whenever this boss uses the ability.");
		ImGui.popTextWrapPos();
		ImGui.text(enemyTakenHits == 0 ? "No hits on you from " + displaySource(name) + " were recorded."
			: "It hit you " + enemyTakenHits + (enemyTakenHits == 1 ? " time" : " times") + " for " + number(enemyTaken) + " damage.");
		if (otherHits > 0) {
			ImGui.pushTextWrapPos(0);
			ImGui.textDisabled(otherHits + (otherHits == 1 ? " hit" : " hits") + " (" + number(otherTaken)
				+ " damage) came from effects it did not cast directly, such as damage over time. They are listed under Damage taken.");
			ImGui.popTextWrapPos();
		}
		drawTimeline();
		var picked = state.pickedCount();
		UiLayout.inlineSplit("##ab_cl_ticks", 3, function(i:Int, w:Single) {
			if (i == 0) { if (UiChrome.ghostButton("Tick all##ab_cl_tick_all", ImGui.vec2(w, 26))) state.pickAll([for (row in rows) row.key]); }
			else if (i == 1) { if (picked > 0 && UiChrome.ghostButton("Clear ticks##ab_cl_clear", ImGui.vec2(w, 26))) state.clearPicks(); }
			else ImGui.textDisabled(picked == 0 ? "Tick several to create them together" : picked + " ticked");
		}, 6);
		if (picked > 0) drawBatchCard(name, picked);
		if (lastResult.length > 0) {
			ImGui.pushTextWrapPos(0);
			ImGui.textColored(ThemePalette.status(lastResultFailed ? ThemePalette.STATUS_WARN : ThemePalette.STATUS_SUCCESS), lastResult);
			ImGui.popTextWrapPos();
		}
		drawFilter("Filter abilities...");
		if (rows.length == 0) ImGui.textDisabled("No abilities match.");
		for (row in rows) drawAbility(row, true);
	}

	/** Batch builder. Appears only once something is ticked; Aura Sets stay optional ("None" by default). */
	function drawBatchCard(boss:String, picked:Int):Void {
		var doc = state.analysis.document;
		UiScope.child("##ab_cl_batch", ImGui.vec2(0, 0), function() {
			UiChrome.subHeader("Create " + picked + (picked == 1 ? " alert together" : " alerts together"));
			UiLayout.propertyGrid("##ab_cl_batch_props", function() {
				UiLayout.propertyRow("Look", function() {
					UiLayout.inlineSplit("##ab_cl_look", 3, function(i:Int, w:Single) {
						if (UiChrome.navButton(STYLE_LABELS[i] + "##ab_cl_look_" + i, state.style == CombatLogBrowserState.STYLES[i], ImGui.vec2(w, 26)))
							state.setStyle(CombatLogBrowserState.STYLES[i]);
					}, 4);
				}, "Banner + icon shows the ability name and icon. Countdown counts down the listed cast time. Glow just lights the icon.");
				UiLayout.propertyRow("Aura Set", drawBatchSetPicker, "Optional. Put these alerts in a set so you can arm them together. None keeps them as separate auras.");
				if (batchSetId.length > 0 && doc.mapId.length > 0)
					UiLayout.propertyRow("Arm", function() ImGui.checkbox("Only on " + doc.mapId + "##ab_cl_arm_map", armOnMap),
						"Boss fights do not happen in the open world, so the set can switch itself on when you enter this map.");
			});
			disabled(atCap, function() {
				if (UiChrome.accentButton("Create " + picked + (picked == 1 ? " alert" : " alerts") + "##ab_cl_create", ImGui.vec2(-1, 34))) createAlerts(boss);
			});
			ImGui.textDisabled(atCap ? "Aura limit reached. Delete an aura to create more." : slotsFree + " aura slots free"
				+ (picked > slotsFree ? " (extra ticks will be skipped)" : ""));
		}, ImGuiChildFlags.Borders | ImGuiChildFlags.AutoResizeY | ImGuiChildFlags.AlwaysUseWindowPadding,
			ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse);
		ImGui.spacing();
	}

	function drawBatchSetPicker():Void {
		var current = batchSetId.length > 0 ? cfg.findSet(batchSetId) : null;
		if (batchSetId.length > 0 && current == null) batchSetId = "";
		ImGui.setNextItemWidth(-1);
		if (ImGui.beginCombo("##ab_cl_set_pick", current != null ? current.name : "None")) {
			try {
				if (ImGui.selectable("None##ab_cl_set_none", batchSetId == "")) { batchSetId = ""; batchNewSetOpen = false; }
				for (set in cfg.sets)
					if (set != null && ImGui.selectable(set.name + "##ab_cl_set_" + set.id, batchSetId == set.id)) { batchSetId = set.id; batchNewSetOpen = false; }
				ImGui.separator();
				if (ImGui.selectable("+ New set...##ab_cl_set_new", false)) batchNewSetOpen = true;
			} catch (e:Dynamic) { ImGui.endCombo(); throw e; }
			ImGui.endCombo();
		}
		if (!batchNewSetOpen) return;
		ImGui.setNextItemWidth(-90);
		ImGui.inputTextWithHint("##ab_cl_new_set_name", "Set name", batchNewSetBuf, 64);
		ImGui.sameLine(0, 6);
		if (UiChrome.ghostButton("Create set##ab_cl_new_set_go", ImGui.vec2(84, 24))) {
			var created = host.bossAddSet(StringTools.trim(ByteUtil.readBytes(batchNewSetBuf, 64)));
			if (created != null) {
				batchSetId = created.id; batchNewSetOpen = false; armOnMap.set(true);
				ByteUtil.clearBytes(batchNewSetBuf, 64);
			}
		}
	}

	function createAlerts(boss:String):Void {
		var picked = state.pickedAbilities();
		if (picked.length == 0) return;
		var drafts:Array<AuraQuickBuildDraft> = [];
		for (stats in picked) {
			var label = skillLabel(stats);
			var options = CombatLogAuraChoices.skill(stats, label, null);
			if (options.length == 0) continue;
			var draft = AuraQuickBuildDraft.forBossAlert(options[0], label, state.style);
			draft.aura.name = displaySource(boss) + " - " + label;
			draft.aura.syncNameBuf();
			drafts.push(draft);
		}
		var map = batchSetId.length > 0 && armOnMap.get() ? state.analysis.document.mapId : "";
		var result = host.bossCreate(drafts, batchSetId, map);
		if (result.made > 0) {
			lastResult = "Created " + result.made + (result.made == 1 ? " alert" : " alerts")
				+ (result.set.length > 0 ? " in " + result.set : "")
				+ (result.skipped > 0 ? ". " + result.skipped + " skipped: " + result.why : ".");
			lastResultFailed = result.skipped > 0;
			state.clearPicks();
		} else {
			lastResult = result.why.length > 0 ? result.why : "Nothing was created.";
			lastResultFailed = true;
		}
	}

	// ---------------------------------------------------------------------------------------------
	// Your skills / Damage taken
	// ---------------------------------------------------------------------------------------------

	function drawMine():Void {
		UiChrome.sectionHeader("Your skills");
		ImGui.pushTextWrapPos(0);
		ImGui.textDisabled("Alert when you cast a skill, when it is ready again, or while its cooldown runs.");
		ImGui.popTextWrapPos();
		drawFilter("Filter skills...");
		if (rows.length == 0) ImGui.textDisabled("No skills match.");
		for (row in rows) drawAbility(row, false);
	}

	function drawDamage():Void {
		UiChrome.sectionHeader("Damage taken");
		ImGui.pushTextWrapPos(0);
		ImGui.textDisabled("Biggest hits on you first. The alert warns when a hit this large lands, from any source.");
		ImGui.popTextWrapPos();
		if (hits.length == 0) { ImGui.textDisabled("No hits on you were saved."); return; }
		var doc = state.analysis.document;
		for (event in hits) {
			ImGui.pushID_Str("hit_" + event.row);
			try {
				var nameWidth = Math.max(80, ImGui.getContentRegionAvail().x - 116);
				ImGui.selectable(doc.time(event) + "   " + number(event.amount) + "   " + text(eventLabel(event)) + "   from "
					+ text(displaySource(event.source)) + "##ab_cl_hit", false, 0, ImGui.vec2(nameWidth, 24));
				ImGui.sameLine(0, 6);
				disabled(atCap, function() {
					if (UiChrome.ghostButton("Build alert##ab_cl_warn", ImGui.vec2(108, 24))) {
						var options = CombatLogAuraChoices.damage(event);
						if (options.length > 0) host.bossBuild(AuraQuickBuildDraft.fromCombatLog(options[0], eventLabel(event)));
					}
				});
			} catch (e:Dynamic) { ImGui.popID(); throw e; }
			ImGui.popID();
		}
	}

	function drawFilter(hint:String):Void {
		ImGui.setNextItemWidth(-1);
		if (ImGui.inputTextWithHint("##ab_cl_search", hint, searchBuf, 160)) state.setFilter(ByteUtil.readBytes(searchBuf, 160));
	}

	// ---------------------------------------------------------------------------------------------
	// Aura Sets tab: an optional viewer
	// ---------------------------------------------------------------------------------------------

	function drawSets():Void {
		UiChrome.sectionHeader("Aura Sets");
		ImGui.pushTextWrapPos(0);
		ImGui.textDisabled("Sets are optional. Group alerts for one fight so you can arm or disarm them together, or leave auras on their own.");
		ImGui.popTextWrapPos();
		UiLayout.inlinePair("##ab_cl_newset_row", function(w:Single) {
			ImGui.setNextItemWidth(w);
			ImGui.inputTextWithHint("##ab_cl_newset_name", "Name a new set", newSetBuf, 64);
		}, function(w:Single) {
			if (UiChrome.ghostButton("Create set##ab_cl_newset_go", ImGui.vec2(Math.max(90, w), 26))) {
				var created = host.bossAddSet(StringTools.trim(ByteUtil.readBytes(newSetBuf, 64)));
				if (created != null) ByteUtil.clearBytes(newSetBuf, 64);
			}
		}, 6);
		ImGui.spacing();
		if (cfg.sets.length == 0) ImGui.textDisabled("No sets yet.");
		for (set in cfg.sets) if (set != null) drawSetCard(set);
		var loose = [for (a in cfg.auras) if (a != null && AuraConfig.tagOf(a).length == 0) a];
		UiChrome.subHeader("Not in a set (" + loose.length + ")");
		if (loose.length == 0) ImGui.textDisabled("Every aura is in a set.");
		for (a in loose) drawMemberRow(a);
	}

	function drawSetCard(set:AuraSetDef):Void {
		var members = [for (a in cfg.auras) if (a != null && AuraConfig.tagOf(a) == set.id) a];
		var armed = cfg.setActive(set.id);
		var chipKind = set.mode == AuraSetDef.MODE_OFF ? ThemePalette.STATUS_WARN
			: armed && set.mode == AuraSetDef.MODE_MAPS ? ThemePalette.STATUS_SUCCESS : ThemePalette.STATUS_INFO;
		var chipText = set.mode == AuraSetDef.MODE_OFF ? "OFF" : set.mode == AuraSetDef.MODE_MAPS ? (armed ? "ARMED" : "WAITING FOR MAP") : "ALWAYS ON";
		UiScope.child("##ab_cl_setcard_" + set.id, ImGui.vec2(0, 0), function() {
			UiLayout.inlinePair("##ab_cl_setcard_head_" + set.id, function(w:Single) {
				ImGui.text(set.name + "  (" + members.length + (members.length == 1 ? " aura)" : " auras)"));
			}, function(w:Single) ImGui.textColored(ThemePalette.status(chipKind), chipText), 6);
			UiLayout.inlineSplit("##ab_cl_setcard_mode_" + set.id, 3, function(i:Int, w:Single) {
				if (UiChrome.navButton(MODE_LABELS[i] + "##ab_cl_setmode_" + set.id + "_" + i, set.mode == i, ImGui.vec2(w, 26))) {
					set.mode = i; host.bossSetsChanged();
				}
			}, 4);
			if (set.mode == AuraSetDef.MODE_MAPS) {
				var here = state.analysis != null ? state.analysis.document.mapId : "";
				for (m in set.maps.copy()) {
					ImGui.text("  " + m);
					ImGui.sameLine(0, 8);
					if (ImGui.smallButton("Remove##ab_cl_setmap_rm_" + set.id + "_" + m)) { set.removeMap(m); host.bossSetsChanged(); }
				}
				if (set.maps.length == 0) ImGui.textDisabled("  No maps yet.");
				disabled(here.length == 0 || set.hasMap(here), function() {
					if (UiChrome.ghostButton("Add this recording's map##ab_cl_setmap_add_" + set.id, ImGui.vec2(220, 26))) { set.addMap(here); host.bossSetsChanged(); }
				});
			}
			ImGui.spacing();
			for (a in members) drawMemberRow(a);
			if (members.length == 0) ImGui.textDisabled("Empty. Create alerts with this set chosen, or move auras in from the library.");
		}, ImGuiChildFlags.Borders | ImGuiChildFlags.AutoResizeY | ImGuiChildFlags.AlwaysUseWindowPadding,
			ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse);
		ImGui.spacing();
	}

	function drawMemberRow(a:AuraDef):Void {
		ImGui.pushID_Str("member_" + a.id);
		try {
			if (ImGui.checkbox("##ab_cl_member_on", a.enabled)) SettingsStore.markDirty();
			ImGui.sameLine(0, 6);
			var nameWidth:Single = Math.max(60, ImGui.getContentRegionAvail().x - 70);
			ImGui.selectable(text(a.name.length > 0 ? a.name : a.id) + "##ab_cl_member_name", false, 0, ImGui.vec2(nameWidth, 22));
			ImGui.sameLine(0, 6);
			if (ImGui.smallButton("Open##ab_cl_member_open")) host.bossOpenAura(a.id);
		} catch (e:Dynamic) { ImGui.popID(); throw e; }
		ImGui.popID();
	}

	// ---------------------------------------------------------------------------------------------
	// Ability rows
	// ---------------------------------------------------------------------------------------------

	function drawAbility(row:AbilityRow, pickable:Bool):Void {
		ImGui.pushID_Str(row.key);
		try {
			if (pickable) {
				pickRef.set(state.isPicked(row.key));
				if (ImGui.checkbox("##ab_cl_pick", pickRef)) state.togglePick(row.key);
				ImGui.sameLine(0, 6);
			}
			if (row.icon.length > 0 && GameIcons.imageKey(row.icon, 24, 24)) ImGui.sameLine(0, 6);
			var open = state.expanded == row.key;
			var nameWidth:Single = Math.max(60, ImGui.getContentRegionAvail().x - 116);
			if (ImGui.selectable(text(row.label) + "##ab_cl_open", open, 0, ImGui.vec2(nameWidth, 24))) state.toggleExpanded(row.key);
			ImGui.sameLine(0, 6);
			disabled(atCap, function() {
				if (UiChrome.ghostButton("Build alert##ab_cl_build", ImGui.vec2(108, 24))) buildFirst(row);
			});
			inset(pickable ? 36 : 8);
			ImGui.textDisabled(row.metrics);
			if (row.share >= 0) drawShareBar(row.share, pickable ? 36 : 8);
			if (open) drawDrawer(row);
			ImGui.dummy(ImGui.vec2(0, 2));
		} catch (e:Dynamic) { ImGui.popID(); throw e; }
		ImGui.popID();
	}

	function choicesOf(row:AbilityRow):Array<CombatLogAuraChoice> {
		if (row.choices == null)
			row.choices = CombatLogAuraChoices.skill(row.stats, row.label, state.view == CombatLogBrowserState.VIEW_MINE ? statusInfo(row.stats) : null);
		return row.choices;
	}

	function buildFirst(row:AbilityRow):Void {
		var options = choicesOf(row);
		if (options.length > 0) host.bossBuild(AuraQuickBuildDraft.fromCombatLog(options[0], row.label));
	}

	function drawDrawer(row:AbilityRow):Void {
		if (row.times.length > 0) {
			inset(36);
			ImGui.pushTextWrapPos(0);
			ImGui.textDisabled("Cast at " + row.times);
			ImGui.popTextWrapPos();
		}
		var options = choicesOf(row);
		if (options.length == 0) { inset(36); ImGui.textDisabled("No alert can be built for this skill."); }
		for (option in options) {
			inset(36);
			disabled(atCap, function() {
				if (UiChrome.ghostButton(text(option.title) + "##ab_cl_choice_" + option.id, ImGui.vec2(0, 26)))
					host.bossBuild(AuraQuickBuildDraft.fromCombatLog(option, row.label));
			});
			inset(36);
			ImGui.pushTextWrapPos(0);
			ImGui.textDisabled(option.reason);
			ImGui.popTextWrapPos();
		}
	}

	/** Thin bar under an attack: its damage to you relative to the hardest-hitting attack of this enemy. */
	static function drawShareBar(share:Single, offset:Single):Void {
		var theme = ThemePalette.current();
		var width:Single = Math.max(40, ImGui.getContentRegionAvail().x - offset - 8);
		inset(offset);
		var p = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(width, 5));
		var dl = ImGui.getWindowDrawList();
		ImGui.ImDrawList_AddRectFilled(dl, p, ImGui.vec2(p.x + width, p.y + 4), ImGui.colorConvertFloat4ToU32(theme.cellBg), 2);
		if (share > 0)
			ImGui.ImDrawList_AddRectFilled(dl, p, ImGui.vec2(p.x + Math.max(2, width * share), p.y + 4), ImGui.colorConvertFloat4ToU32(theme.accent), 2);
	}

	/** Indents the next item without ImGui.indent, which the binding does not expose. */
	static function inset(pixels:Single):Void ImGui.setCursorPosX(ImGui.getCursorPosX() + pixels);

	// ---------------------------------------------------------------------------------------------
	// Timeline
	// ---------------------------------------------------------------------------------------------

	function drawTimeline():Void {
		if (lanes.length == 0) return;
		var theme = ThemePalette.current();
		var laneHeight:Single = 14;
		var labelWidth:Single = 130;
		var width:Single = ImGui.getContentRegionAvail().x;
		var pos = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(width, lanes.length * laneHeight + 6));
		var dl = ImGui.getWindowDrawList();
		var x0:Single = pos.x + labelWidth;
		var x1:Single = pos.x + width - 8;
		var labelColor = ImGui.colorConvertFloat4ToU32(theme.textDisabled);
		var tickColor = ImGui.colorConvertFloat4ToU32(theme.accent);
		var railColor = ImGui.colorConvertFloat4ToU32(theme.border);
		for (i in 0...lanes.length) {
			var lane = lanes[i];
			var y:Single = pos.y + 3 + i * laneHeight;
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(pos.x + 2, y), labelColor, lane.label);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x0, y + laneHeight * 0.5), ImGui.vec2(x1, y + laneHeight * 0.5), railColor, 1);
			for (fraction in lane.ticks) {
				var x:Single = x0 + fraction * (x1 - x0);
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x, y + 2), ImGui.vec2(x, y + laneHeight - 2), tickColor, 2);
			}
		}
		ImGui.spacing();
	}

	// ---------------------------------------------------------------------------------------------
	// Cached rows (rebuilt only when the selection, filter or ticks change)
	// ---------------------------------------------------------------------------------------------

	function refreshView():Void {
		if (seenRevision == state.revision) return;
		seenRevision = state.revision;
		rows = []; hits = []; lanes = []; enemyInfo = null;
		enemyTaken = 0; enemyTakenHits = 0; otherTaken = 0; otherHits = 0;
		var analysis = state.analysis;
		if (analysis == null) return;
		if (indexed != analysis) {
			indexed = analysis; strayHits = 0; strayTaken = 0;
			var casters:Map<String, Bool> = new Map();
			for (enemy in analysis.enemyList) casters.set(enemy.name, true);
			for (event in analysis.damageTaken) if (!casters.exists(event.source)) { strayHits++; strayTaken += event.amount; }
			indexBosses(analysis);
		}
		if (state.view == CombatLogBrowserState.VIEW_DAMAGE) {
			var sorted = analysis.damageTaken.copy();
			sorted.sort(function(a, b) return a.amount > b.amount ? -1 : a.amount < b.amount ? 1 : a.row - b.row);
			hits = sorted.length > MAX_ROWS ? sorted.slice(0, MAX_ROWS) : sorted;
			return;
		}
		if (state.view == CombatLogBrowserState.VIEW_SETS) return;
		var query = state.filter.toLowerCase();
		var enemyView = state.view == CombatLogBrowserState.VIEW_ENEMY;
		var listedTaken = 0.0;
		var listedHits = 0;
		var hardest = 0.0;
		for (stats in state.abilities()) {
			// Damage this attack did to you (the skill's hits may also have landed on minions or other enemies).
			var taken = 0.0;
			var landed = 0;
			var biggest = 0.0;
			if (enemyView)
				for (event in stats.events)
					if (event.kind == "hit" && event.targetRole == CombatLogDocument.YOU) {
						taken += event.amount; landed++;
						if (event.amount > biggest) biggest = event.amount;
					}
			listedTaken += taken; listedHits += landed;
			if (taken > hardest) hardest = taken;
			if (rows.length >= MAX_ROWS) continue;
			var label = skillLabel(stats);
			if (query.length > 0 && (stats.skill + " " + label).toLowerCase().indexOf(query) < 0) continue;
			rows.push({stats: stats, key: stats.key, label: label, icon: iconFor(stats.skill), metrics: metrics(stats, taken, landed, biggest),
				times: timesText(stats), choices: null, share: enemyView ? taken : -1});
		}
		if (!enemyView) return;
		// Shares were stored as raw damage while the hardest attack was still unknown; scale them now.
		for (row in rows) if (row.share > 0) row.share = row.share / hardest;
		for (event in analysis.damageTaken)
			if (event.source == state.enemy) { enemyTaken += event.amount; enemyTakenHits++; }
		otherTaken = Math.max(0, enemyTaken - listedTaken);
		otherHits = Std.int(Math.max(0, enemyTakenHits - listedHits));
		for (enemy in analysis.enemyList) if (enemy.name == state.enemy) enemyInfo = enemy;
		var duration = analysis.duration;
		if (duration <= 0) return;
		for (row in rows) {
			if (lanes.length >= MAX_LANES) break;
			var times = row.stats.castTimes;
			if (times.length == 0) continue;
			var stride = Std.int(Math.ceil(times.length / MAX_TICKS));
			var ticks:Array<Float> = [];
			var i = 0;
			while (i < times.length) { ticks.push(Math.min(1, times[i] / duration)); i += stride; }
			lanes.push({label: laneLabel(row.label), ticks: ticks});
		}
	}

	/** Boss flags and ordering for the enemy grid. A boss is a unit the quick-start catalog knows, or one that cast a catalog boss skill. */
	function indexBosses(analysis:CombatLogAnalysis):Void {
		bossNames = new Map();
		AuraQuickStartCatalog.keep();
		for (enemy in analysis.enemyList) {
			var boss = AuraQuickStartCatalog.boss(unitFor(enemy.name).id) != null;
			if (!boss)
				for (stats in analysis.abilitiesOf(enemy.name))
					if (AuraQuickStartCatalog.skillName(stats.skill).length > 0) { boss = true; break; }
			if (boss) bossNames.set(enemy.name, true);
		}
		// Stable partition: bosses first, each group keeps the busiest-first order.
		enemyOrder = [for (enemy in analysis.enemyList) if (bossNames.exists(enemy.name)) enemy]
			.concat([for (enemy in analysis.enemyList) if (!bossNames.exists(enemy.name)) enemy]);
	}

	function metrics(stats:CombatLogSkillStats, taken:Float, landed:Int, biggest:Float):String {
		var parts = ["x" + stats.casts];
		if (state.view == CombatLogBrowserState.VIEW_MINE && stats.damage > 0) parts.push(number(stats.damage) + " damage");
		if (state.view == CombatLogBrowserState.VIEW_ENEMY)
			parts.push(landed > 0 ? number(taken) + " damage to you (" + landed + (landed == 1 ? " hit" : " hits")
				+ ", biggest " + number(biggest) + ")" : "no damage to you");
		if (Math.isFinite(stats.firstT))
			parts.push("first " + CombatLogDocument.clock(stats.firstT)
				+ (state.view == CombatLogBrowserState.VIEW_ENEMY && Math.isFinite(stats.firstHp) ? " (boss at " + Std.int(Math.round(stats.firstHp * 100)) + "% health)" : ""));
		if (Math.isFinite(stats.medianGap)) parts.push("every ~" + seconds(stats.medianGap));
		var castTime = CdbAuraTable.castDuration(stats.skill);
		if (Math.isFinite(castTime) && castTime > 0.001) parts.push(seconds(castTime) + " cast");
		return parts.join("  |  ");
	}

	function timesText(stats:CombatLogSkillStats):String {
		var shown = [for (i in 0...Std.int(Math.min(8, stats.castTimes.length))) CombatLogDocument.clock(stats.castTimes[i])];
		return shown.join(", ") + (stats.castTimes.length > 8 ? " ... (" + stats.castTimes.length + " total)" : "");
	}

	// ---------------------------------------------------------------------------------------------
	// Helpers
	// ---------------------------------------------------------------------------------------------

	/** Unit id and portrait key for a recorded enemy name, from the build-time catalog. Ambiguous names prefer a unit with art. */
	static function unitFor(name:String):Unit {
		if (unitIndex == null) {
			unitIndex = new Map();
			AuraCatalog.keep();
			for (entry in AuraCatalog.entries) {
				if (entry.kind != "unit") continue;
				var key = entry.name.toLowerCase();
				if (!unitIndex.exists(key)) unitIndex.set(key, []);
				unitIndex.get(key).push(entry.id);
			}
		}
		var ids = unitIndex.get(name.toLowerCase());
		if (ids == null || ids.length == 0) return {id: "", icon: ""};
		for (id in ids) if (GameIcons.hasKey(id)) return {id: id, icon: id};
		return {id: ids[0], icon: ""};
	}

	function disabled(blocked:Bool, body:Void->Void):Void {
		ImGui.beginDisabled(blocked);
		try { body(); } catch (e:Dynamic) { ImGui.endDisabled(); throw e; }
		ImGui.endDisabled();
	}

	static function laneLabel(label:String):String return label.length > 18 ? label.substr(0, 17) + "." : label;

	static function iconFor(skill:String):String {
		if (skill == null || skill.length == 0) return "";
		var icon = CdbAuraTable.iconStem(skill);
		return icon.length > 0 ? icon : skill;
	}

	function statusInfo(stats:CombatLogSkillStats):CombatLogStatusInfo {
		if (stats == null) return null;
		var id = CdbAuraTable.isStatus(stats.skill) ? stats.skill : CdbAuraTable.grantedStatusId(stats.skill);
		if (id.length == 0 || !CdbAuraTable.isStatus(id)) return null;
		return {id: id, label: CombatLogAnalysis.label(id, "", CdbAuraTable.name), duration: CdbAuraTable.duration(id), stacks: CdbAuraTable.maxStacks(id)};
	}

	function skillLabel(stats:CombatLogSkillStats):String return stats != null ? CombatLogAnalysis.label(stats.skill, stats.label, CdbAuraTable.name) : "Unknown skill";
	function eventLabel(event:CombatLogEvent):String return CombatLogAnalysis.label(event.skill, event.label, CdbAuraTable.name);
	static function displaySource(name:String):String return name != null && name.length > 0 ? text(name) : "Unknown source";
	static function text(value:String):String return StringTools.replace(StringTools.replace(StringTools.replace(value, "##", "# #"), "\n", " "), "\r", " ");
	static function seconds(value:Float):String return (Math.round(value * 10) / 10) + "s";
	static function number(value:Float):String return Math.isFinite(value)
		? Std.string(value < 1e12 ? Math.ffloor(value * 10 + 0.5) / 10 : value) : "unavailable";
	static function clipped(count:Int, rowHeight:Single, row:Int->Void):Void {
		var clipper = ImGui.ImGuiListClipper_ImGuiListClipper();
		try {
			ImGui.ImGuiListClipper_Begin(clipper, count, rowHeight);
			while (ImGui.ImGuiListClipper_Step(clipper))
				for (i in ImGui.ImGuiListClipper_get_DisplayStart(clipper)...ImGui.ImGuiListClipper_get_DisplayEnd(clipper)) row(i);
		} catch (e:Dynamic) { ImGui.ImGuiListClipper_destroy(clipper); throw e; }
		ImGui.ImGuiListClipper_destroy(clipper);
	}
}
