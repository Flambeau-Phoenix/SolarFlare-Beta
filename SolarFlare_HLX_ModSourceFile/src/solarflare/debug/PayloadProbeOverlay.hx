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
 */
class PayloadProbeOverlay {
	public function new() {}

	public function draw(cursorFree:Bool = true):Void {
		if (!PayloadProbe.armed())
			return;
		ImGui.setNextWindowSize(ImGui.vec2(560, 360), ImGuiCond.FirstUseEver);
		var extraFlags = cursorFree ? 0 : ImGuiWindowFlags.NoInputs;
		if (HudChrome.beginPanel("Payload probe##hm_pp", PayloadProbe.enabled, "Payload probe", extraFlags)) {
			ImGui.text("Do not use stats.current or skill.cd (Monumental Research).");
			ImGui.text(PayloadProbe.lastLabel);
			if (PayloadProbe.lastPath.length > 0)
				ImGui.text(PayloadProbe.lastPath);
			if (ImGui.smallButton("Copy last JSON##hm_pp_copy"))
				ImGui.setClipboardText(PayloadProbe.lastJson);
			var snap = PayloadProbe.lastSnap();
			if (snap == null || snap.rows.length == 0)
				ImGui.text("Armed. Take a hit, cast, chat line, or wait for a GameApp spine sample.");
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
