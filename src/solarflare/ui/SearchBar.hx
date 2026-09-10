package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiCol;
import hl.Bytes;

/**
 * Reusable search and filter input with a quick clear button.
 */
class SearchBar {
	var buffer:Bytes;
	var capacity:Int;
	var text:String = "";
	var active:Bool = false;
	var placeholder:String;

	public function new(placeholder:String = "Search...", capacity:Int = 128) {
		this.placeholder = placeholder;
		this.capacity = capacity;
		this.buffer = new Bytes(capacity);
		ByteUtil.clearBytes(this.buffer, capacity);
	}

	public function draw(id:String = "##search"):String {
		ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 6.0);
		ImGui.pushStyleColor(ImGuiCol.FrameBg, ImGui.vec4(0.12, 0.14, 0.18, 0.85));

		if (ImGui.inputTextWithHint(id, placeholder, buffer, capacity)) {
			text = ByteUtil.readString(buffer, capacity, true);
			active = text.length > 0;
		}

		ImGui.popStyleColor();
		ImGui.popStyleVar();

		if (active && text.length > 0) {
			ImGui.sameLine();
			if (ImGui.smallButton("X##clear_" + id)) {
				text = "";
				ByteUtil.clearBytes(buffer, capacity);
				active = false;
			}
		}

		return text.toLowerCase();
	}

	public function getText():String {
		return text;
	}

	public function clear():Void {
		text = "";
		ByteUtil.clearBytes(buffer, capacity);
		active = false;
	}
}
