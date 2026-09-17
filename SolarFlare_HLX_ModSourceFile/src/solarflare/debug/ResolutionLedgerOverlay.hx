package solarflare.debug;

import solarflare.debug.ResolutionLedger;
import solarflare.debug.ResolutionLedger.LedgerAgg;
import solarflare.ui.HudChrome;
import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiTableColumnFlags;
import imgui.Enums.ImGuiTableFlags;
import imgui.Enums.ImGuiWindowFlags;

/**
 * Layer 2: draw frozen ResolutionLedger aggs. No live engine walks.
 * Panel open (enabled) is separate from recording (armed).
 */
class ResolutionLedgerOverlay {
	public function new() {}

	public function draw(cursorFree:Bool = true):Void {
		if (ResolutionLedger.enabled == null || !ResolutionLedger.enabled.get())
			return;
		ImGui.setNextWindowSize(ImGui.vec2(720, 380), ImGuiCond.FirstUseEver);
		var extraFlags = cursorFree ? 0 : ImGuiWindowFlags.NoMouseInputs;
		if (HudChrome.beginPanel("Resolution ledger##hm_rl", ResolutionLedger.enabled, "Resolution ledger", extraFlags)) {
			ImGui.textWrapped("Production winners (engine / typed / FieldWalk). Recording is session-only and does not auto-start.");
			if (ResolutionLedger.armed()) {
				if (ImGui.button("Stop recording##hm_rl_stop"))
					ResolutionLedger.stopRecording();
			} else {
				if (ImGui.button("Start recording##hm_rl_start"))
					ResolutionLedger.startRecording();
			}
			ImGui.sameLine();
			if (ImGui.button("Clear session##hm_rl_clear"))
				ResolutionLedger.clearSession();
			ImGui.text(ResolutionLedger.armed() ? "Recording ON — JSONL flushes while armed." : "Idle — panel open only; no log growth.");
			ImGui.separator();
			ImGui.text(ResolutionLedger.lastLabel);
			if (ResolutionLedger.lastPath.length > 0)
				ImGui.text(ResolutionLedger.lastPath);
			if (ImGui.smallButton("Copy last JSON##hm_rl_copy"))
				ImGui.setClipboardText(ResolutionLedger.lastJson);
			var rows = ResolutionLedger.rowsForDraw();
			if (rows.length == 0)
				ImGui.text(ResolutionLedger.armed()
					? "Recording. Play: vitals, Geaux CD, a hit/cast, chat, rift if available."
					: "Start recording to capture winners.");
			else
				drawRows(rows);
		}
		HudChrome.endPanel();
	}

	function drawRows(rows:Array<LedgerAgg>):Void {
		var tbl = ImGuiTableFlags.RowBg | ImGuiTableFlags.SizingStretchProp | ImGuiTableFlags.ScrollY;
		if (!ImGui.beginTable("hm_rl_rows", 6, tbl))
			return;
		ImGui.tableSetupColumn("Key", ImGuiTableColumnFlags.WidthStretch, 0.26);
		ImGui.tableSetupColumn("Method", ImGuiTableColumnFlags.WidthStretch, 0.12);
		ImGui.tableSetupColumn("Step", ImGuiTableColumnFlags.WidthStretch, 0.10);
		ImGui.tableSetupColumn("Hits", ImGuiTableColumnFlags.WidthStretch, 0.08);
		ImGui.tableSetupColumn("Name", ImGuiTableColumnFlags.WidthStretch, 0.20);
		ImGui.tableSetupColumn("Preview", ImGuiTableColumnFlags.WidthStretch, 0.24);
		ImGui.tableHeadersRow();
		var i = 0;
		while (i < rows.length) {
			var r = rows[i];
			ImGui.tableNextRow();
			ImGui.tableSetColumnIndex(0);
			ImGui.text(r.key);
			ImGui.tableSetColumnIndex(1);
			ImGui.text(r.method);
			ImGui.tableSetColumnIndex(2);
			ImGui.text(r.step.length > 0 ? r.step : "-");
			ImGui.tableSetColumnIndex(3);
			ImGui.text(Std.string(r.hits));
			ImGui.tableSetColumnIndex(4);
			ImGui.text(ResolutionLedger.cleanId(r.nameWon));
			ImGui.tableSetColumnIndex(5);
			ImGui.text(ResolutionLedger.cleanId(r.preview));
			i++;
		}
		ImGui.endTable();
	}
}
