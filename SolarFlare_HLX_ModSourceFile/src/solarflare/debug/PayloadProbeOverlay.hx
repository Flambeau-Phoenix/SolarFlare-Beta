package solarflare.debug;

import solarflare.debug.PayloadProbe;
import solarflare.ui.HudChrome;
import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiTableColumnFlags;
import imgui.Enums.ImGuiTableFlags;
import imgui.Enums.ImGuiWindowFlags;

/**
 * Layer 2: draw frozen PayloadProbe snaps. No live engine walks.
 * Panel open (enabled) is separate from recording (armed).
 */
class PayloadProbeOverlay {
	public function new() {}

	public function draw(cursorFree:Bool = true):Void {
		if (PayloadProbe.enabled == null || !PayloadProbe.enabled.get())
			return;
		ImGui.setNextWindowSize(ImGui.vec2(560, 360), ImGuiCond.FirstUseEver);
		var extraFlags = cursorFree ? 0 : ImGuiWindowFlags.NoMouseInputs;
		if (HudChrome.beginPanel("Payload probe##hm_pp", PayloadProbe.enabled, "Payload probe", extraFlags)) {
			ImGui.textWrapped("Session only. Recording does not auto-start and is not saved.");
			if (PayloadProbe.armed()) {
				if (ImGui.button("Stop recording##hm_pp_stop"))
					PayloadProbe.stopRecording();
			} else {
				if (ImGui.button("Start recording##hm_pp_start"))
					PayloadProbe.startRecording();
			}
			ImGui.sameLine();
			if (ImGui.button("Clear session##hm_pp_clear"))
				PayloadProbe.clearSession();
			ImGui.text(PayloadProbe.armed() ? "Recording ON — hit/cast/chat + spine samples write JSONL." : "Idle — open panel only; no log growth.");
			ImGui.separatorText("Instant cast (skill script)");
			ImGui.textWrapped("demand=" + Std.string(solarflare.ObserveDemand.aurasNeedInstant)
				+ " last=" + PayloadProbe.lastInstantSkillId
				+ " known=" + Std.string(PayloadProbe.lastInstantKnown)
				+ " ready=" + Std.string(PayloadProbe.lastInstantReady));
			ImGui.textDisabled("Subject = skill ID (e.g. Staff_Craft_S1). Uses typed SkillScript.shouldPlayInstantly().");
			ImGui.separator();
			ImGui.text(PayloadProbe.lastLabel);
			if (PayloadProbe.lastPath.length > 0)
				ImGui.text(PayloadProbe.lastPath);
			if (ImGui.smallButton("Copy last JSON##hm_pp_copy"))
				ImGui.setClipboardText(PayloadProbe.lastJson);
			var snap = PayloadProbe.lastSnap();
			if (snap == null || snap.rows.length == 0)
				ImGui.text(PayloadProbe.armed()
					? "Recording. Use a skill, take a hit, chat, or wait for a spine sample."
					: "Start recording to capture payloads.");
			else
				drawRows(snap.rows);
		}
		HudChrome.endPanel();
	}

	function drawRows(rows:Array<ProbeRow>):Void {
		var tbl = ImGuiTableFlags.RowBg | ImGuiTableFlags.SizingStretchProp | ImGuiTableFlags.ScrollY;
		if (!ImGui.beginTable("hm_pp_rows", 4, tbl))
			return;
		ImGui.tableSetupColumn("Name", ImGuiTableColumnFlags.WidthStretch, 0.36);
		ImGui.tableSetupColumn("Step", ImGuiTableColumnFlags.WidthStretch, 0.16);
		ImGui.tableSetupColumn("Kind", ImGuiTableColumnFlags.WidthStretch, 0.16);
		ImGui.tableSetupColumn("Preview", ImGuiTableColumnFlags.WidthStretch, 0.32);
		ImGui.tableHeadersRow();
		var i = 0;
		while (i < rows.length) {
			var r = rows[i];
			ImGui.tableNextRow();
			ImGui.tableSetColumnIndex(0);
			ImGui.text(r.name);
			ImGui.tableSetColumnIndex(1);
			ImGui.text(r.step);
			ImGui.tableSetColumnIndex(2);
			ImGui.text(r.kind);
			ImGui.tableSetColumnIndex(3);
			ImGui.text(r.preview);
			i++;
		}
		ImGui.endTable();
	}
}
