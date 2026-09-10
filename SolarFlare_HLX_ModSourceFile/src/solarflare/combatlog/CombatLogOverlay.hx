package solarflare.combatlog;

import solarflare.ui.HudChrome;
import solarflare.ui.ImGuiLists;
import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiTableColumnFlags;
import imgui.Enums.ImGuiTableFlags;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Theme;

/**
 * Scrolling combat log. Draws snapshots from CombatLogCache only.
 */
class CombatLogOverlay {
	static inline var FLAGS:Int = ImGuiWindowFlags.NoCollapse;

	var theme:Theme;

	public function new() {
		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(8, 6))
			.varV(ImGuiStyleVar.ItemSpacing, ImGui.vec2(4, 2))
			.varF(ImGuiStyleVar.WindowRounding, 6)
			.varF(ImGuiStyleVar.WindowBorderSize, 1.5)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0.07, 0.08, 0.10, 0.88))
			.color(ImGuiCol.Border, ImGui.vec4(0.42, 0.62, 0.92, 0.55))
			.color(ImGuiCol.ChildBg, ImGui.vec4(0.05, 0.06, 0.08, 0.55))
			.color(ImGuiCol.TableHeaderBg, ImGui.vec4(0.12, 0.14, 0.18, 0.9))
			.color(ImGuiCol.TableRowBg, ImGui.vec4(0.06, 0.07, 0.09, 0.35))
			.color(ImGuiCol.TableRowBgAlt, ImGui.vec4(0.09, 0.10, 0.13, 0.45));
	}

	public function draw(cfg:CombatLogConfig):Void {
		if (cfg == null || cfg.hidden.get())
			return;
		theme.wrap(() -> drawWindow(cfg));
	}

	function drawWindow(cfg:CombatLogConfig):Void {
		var trans = cfg.chrome != null && cfg.chrome.isTransparent();
		ImGui.setNextWindowBgAlpha(trans ? 0 : 0.88);
		ImGui.setNextWindowSize(ImGui.vec2(720, 240), ImGuiCond.FirstUseEver);
		if (cfg.chrome != null)
			cfg.chrome.applyPos();
		var flags = cfg.chrome != null ? cfg.chrome.windowFlags(FLAGS) : FLAGS;
		var began = ImGui.begin("SolarFlare Combat Log", null, flags);
		if (began) {
			if (cfg.chrome != null && !cfg.chrome.isLocked())
				cfg.chrome.capturePos();
			if (cfg.chrome == null || cfg.chrome.beginBody(function() {
				cfg.hidden.set(true);
				solarflare.ui.SettingsStore.markDirty();
			}, null, "Combat Log")) {
			var rows = CombatLogCache.linesForDraw(cfg);
			var avail = ImGui.getContentRegionAvail();
			drawRows(rows, avail.x, avail.y);
			}
		}
		HudChrome.endOverlayWindow(began, cfg.chrome);
	}

	var sortCol:Int = -1;
	var sortAsc:Bool = true;

	function drawRows(rows:Array<CombatLogLine>, width:Single, height:Single):Void {
		var tbl = ImGuiTableFlags.RowBg | ImGuiTableFlags.SizingStretchProp
			| ImGuiTableFlags.NoPadOuterX | ImGuiTableFlags.Hideable | ImGuiTableFlags.Resizable
			| ImGuiTableFlags.BordersInnerV | ImGuiTableFlags.ScrollY | ImGuiTableFlags.Sortable;
		if (!ImGui.beginTable("clog_rows", 12, tbl, ImGui.vec2(width, height)))
			return;
		ImGui.tableSetupColumn("Time", ImGuiTableColumnFlags.WidthFixed | ImGuiTableColumnFlags.DefaultSort, 62);
		ImGui.tableSetupColumn("Type", ImGuiTableColumnFlags.WidthFixed, 44);
		ImGui.tableSetupColumn("Source", ImGuiTableColumnFlags.WidthStretch, 0.18);
		ImGui.tableSetupColumn("Minion", ImGuiTableColumnFlags.WidthStretch, 0.15);
		ImGui.tableSetupColumn("Skill", ImGuiTableColumnFlags.WidthStretch, 0.22);
		ImGui.tableSetupColumn("Target", ImGuiTableColumnFlags.WidthStretch, 0.18);
		ImGui.tableSetupColumn("Damage", ImGuiTableColumnFlags.WidthFixed, 56);
		ImGui.tableSetupColumn("Crit", ImGuiTableColumnFlags.WidthFixed, 40);
		ImGui.tableSetupColumn("Block", ImGuiTableColumnFlags.WidthFixed, 52);
		ImGui.tableSetupColumn("Kill", ImGuiTableColumnFlags.WidthFixed, 40);
		ImGui.tableSetupColumn("Dmg", ImGuiTableColumnFlags.WidthFixed, 52);
		ImGui.tableSetupColumn("HP", ImGuiTableColumnFlags.WidthFixed, 64);
		ImGui.tableSetupScrollFreeze(0, 1);
		ImGui.tableHeadersRow();

		var specs = ImGui.tableGetSortSpecs();
		if (specs != null && ImGui.tableSortSpecsGetSpecsDirty(specs)) {
			var count = ImGui.tableSortSpecsGetSpecsCount(specs);
			if (count > 0) {
				sortCol = ImGui.tableSortSpecsGetColumnIndex(specs, 0);
				sortAsc = ImGui.tableSortSpecsGetSortDirection(specs, 0) == imgui.Enums.ImGuiSortDirection.Ascending;
			} else {
				sortCol = -1;
			}
			ImGui.tableSortSpecsSetSpecsDirty(specs, false);
		}

		var displayRows = rows;
		if (sortCol >= 0 && rows.length > 1) {
			displayRows = rows.copy();
			displayRows.sort(function(a, b) {
				var cmp = 0;
				switch (sortCol) {
					case 0:
						cmp = a.t < b.t ? -1 : (a.t > b.t ? 1 : 0);
					case 1:
						cmp = a.kind < b.kind ? -1 : (a.kind > b.kind ? 1 : 0);
					case 2:
						cmp = a.sourceName < b.sourceName ? -1 : (a.sourceName > b.sourceName ? 1 : 0);
					case 3:
						cmp = a.minionName < b.minionName ? -1 : (a.minionName > b.minionName ? 1 : 0);
					case 4:
						cmp = a.skillName < b.skillName ? -1 : (a.skillName > b.skillName ? 1 : 0);
					case 5:
						cmp = a.targetName < b.targetName ? -1 : (a.targetName > b.targetName ? 1 : 0);
					case 6:
						cmp = a.amount < b.amount ? -1 : (a.amount > b.amount ? 1 : 0);
					case 7:
						cmp = (a.crit ? 1 : 0) - (b.crit ? 1 : 0);
					case 8:
						cmp = a.blockAmt < b.blockAmt ? -1 : (a.blockAmt > b.blockAmt ? 1 : 0);
					case 9:
						cmp = (a.kill ? 1 : 0) - (b.kill ? 1 : 0);
					case 10:
						cmp = a.amount < b.amount ? -1 : (a.amount > b.amount ? 1 : 0);
					case 11:
						cmp = a.targetHp < b.targetHp ? -1 : (a.targetHp > b.targetHp ? 1 : 0);
				}
				return sortAsc ? cmp : -cmp;
			});
		}

		ImGuiLists.forVisible(displayRows.length, function(i:Int) drawLine(displayRows[i]));
		if (sortCol <= 0 && ImGui.getScrollY() >= ImGui.getScrollMaxY() - 8)
			ImGui.setScrollHereY(1);
		ImGui.endTable();
	}

	function drawLine(line:CombatLogLine):Void {
		ImGui.tableNextRow();
		var srcCol = roleColor(line.sourceRole);
		var tgtCol = roleColor(line.targetRole);
		if (line.kill)
			srcCol = ImGui.vec4(1.0, 0.55, 0.2, 1);
		else if (line.crit)
			srcCol = ImGui.vec4(1.0, 0.78, 0.28, 1);

		ImGui.tableNextColumn();
		ImGui.text(line.timeText());

		ImGui.tableNextColumn();
		textCol(kindColor(line), kindLabel(line.kind));

		ImGui.tableNextColumn();
		textCol(srcCol, actorWithPlayer(line.sourceRole, line.sourceName, line.sourcePlayer));

		ImGui.tableNextColumn();
		ImGui.text(line.minionName);

		ImGui.tableNextColumn();
		var skill = line.skillName.length > 0 ? line.skillName : (line.skillLabel.length > 0 ? line.skillLabel : line.skillId);
		textCol(ImGui.vec4(0.72, 0.76, 0.82, 1), skill);

		ImGui.tableNextColumn();
		if (line.targetName.length > 0)
			textCol(tgtCol, actorWithPlayer(line.targetRole, line.targetName, line.targetPlayer));
		else
			ImGui.text("");

		ImGui.tableNextColumn();
		if (line.kind == CombatLogCache.KIND_HIT && line.amount > 0)
			textCol(ImGui.vec4(0.95, 0.95, 0.97, 1), Std.string(Std.int(line.amount)));
		else
			ImGui.text("");

		ImGui.tableNextColumn();
		if (line.crit) textCol(ImGui.vec4(1.0, 0.78, 0.28, 1), "crit"); else ImGui.text("");

		ImGui.tableNextColumn();
		if (line.blockAmt > 0) ImGui.text(Std.string(Std.int(line.blockAmt)));
		else if (line.blocked) ImGui.text("block"); else ImGui.text("");

		ImGui.tableNextColumn();
		if (line.kill) textCol(ImGui.vec4(1.0, 0.55, 0.2, 1), "kill"); else ImGui.text("");

		ImGui.tableNextColumn();
		ImGui.text(damageType(line));

		ImGui.tableNextColumn();
		ImGui.text(hpText(line));
	}

	static function damageType(line:CombatLogLine):String {
		if (line.physical) return "phys";
		if (line.magic) return "mag";
		if (line.auto) return "base";
		return "";
	}

	static function actorWithPlayer(role:Int, name:String, player:String):String {
		var base = actorLabel(role, name);
		if (player != null && player.length > 0 && player != name && player != base)
			return base + " · " + player;
		return base;
	}

	static function kindLabel(kind:Int):String {
		if (kind == CombatLogCache.KIND_CAST)
			return "cast";
		if (kind == CombatLogCache.KIND_HIT)
			return "hit";
		return "?";
	}

	static function kindColor(line:CombatLogLine):imgui.Structs.ImVec4 {
		if (line.kind == CombatLogCache.KIND_CAST)
			return ImGui.vec4(0.95, 0.78, 0.38, 1);
		if (line.kill)
			return ImGui.vec4(1.0, 0.55, 0.2, 1);
		if (line.crit)
			return ImGui.vec4(1.0, 0.78, 0.28, 1);
		return ImGui.vec4(0.78, 0.80, 0.84, 1);
	}

	static function drawFlags(line:CombatLogLine):Void {
		var first = true;
		if (line.crit) {
			textCol(ImGui.vec4(1.0, 0.78, 0.28, 1), "crit");
			first = false;
		}
		if (line.blocked) {
			if (!first)
				ImGui.sameLine();
			textCol(ImGui.vec4(0.62, 0.66, 0.72, 1), "block");
			first = false;
		}
		if (line.kill) {
			if (!first)
				ImGui.sameLine();
			textCol(ImGui.vec4(1.0, 0.55, 0.2, 1), "kill");
			first = false;
		}
		if (first)
			ImGui.text("");
	}

	static function hpText(line:CombatLogLine):String {
		if (line.targetMaxHp > 0)
			return Std.string(Std.int((line.targetHp / line.targetMaxHp) * 100)) + "%";
		if (line.targetHp > 0)
			return Std.string(Std.int(line.targetHp));
		return "";
	}

	static function actorLabel(role:Int, name:String):String {
		var n = name != null && name.length > 0 ? name : "?";
		if (role == CombatLogCache.ROLE_YOU)
			return "YOU";
		return n;
	}

	static function roleColor(role:Int):imgui.Structs.ImVec4 {
		if (role == CombatLogCache.ROLE_YOU)
			return ImGui.vec4(0.95, 0.82, 0.32, 1);
		if (role == CombatLogCache.ROLE_ENEMY)
			return ImGui.vec4(0.92, 0.38, 0.32, 1);
		if (role == CombatLogCache.ROLE_PLAYER)
			return ImGui.vec4(0.62, 0.68, 0.78, 1);
		return ImGui.vec4(0.72, 0.74, 0.78, 1);
	}

	static function textCol(col:imgui.Structs.ImVec4, s:String):Void {
		ImGui.textColored(col, s != null ? s : "");
	}
}
