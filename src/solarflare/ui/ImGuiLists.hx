package solarflare.ui;

import imgui.ImGui;

/** Virtualize equal-height rows with ImGuiListClipper (hl-imgui 0.0.5). */
class ImGuiLists {
	public static function forVisible(count:Int, drawIndex:Int->Void):Void {
		if (count <= 0)
			return;
		var c = ImGui.ImGuiListClipper_ImGuiListClipper();
		if (c == null) {
			var i = 0;
			while (i < count) {
				drawIndex(i);
				i++;
			}
			return;
		}
		try {
			ImGui.ImGuiListClipper_Begin(c, count);
			while (ImGui.ImGuiListClipper_Step(c)) {
				var i = ImGui.ImGuiListClipper_get_DisplayStart(c);
				var end = ImGui.ImGuiListClipper_get_DisplayEnd(c);
				while (i < end) {
					drawIndex(i);
					i++;
				}
			}
		} catch (_:Dynamic) {}
		ImGui.ImGuiListClipper_destroy(c);
	}
}
