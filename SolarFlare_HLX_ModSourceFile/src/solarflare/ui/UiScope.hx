package solarflare.ui;

import imgui.ImGui;
import imgui.Structs.ImVec2;

/**
 * Callback-owned ImGui scopes. Each helper owns the matching End call and
 * contains callback failures after restoring the ImGui stack.
 */
class UiScope {
	/** BeginChild always requires EndChild, including when it returns false. */
	public static function child(id:String, size:ImVec2, draw:Void->Void,
			childFlags:Int = 0, windowFlags:Int = 0):Void {
		var shown = ImGui.beginChild(id, size, childFlags, windowFlags);
		var failed = false;
		var failure:Dynamic = null;

		if (shown && draw != null) {
			try {
				draw();
			} catch (e:Dynamic) {
				failed = true;
				failure = e;
			}
		}

		ImGui.endChild();
		if (failed)
			report("child", id, failure);
	}

	/** EndTable is valid only when BeginTable returned true. */
	public static function table(id:String, columns:Int, draw:Void->Void,
			flags:Int = 0, outerSize:ImVec2 = null, innerWidth:Single = 0):Bool {
		var shown = ImGui.beginTable(id, columns, flags, outerSize, innerWidth);
		if (!shown)
			return false;

		var failed = false;
		var failure:Dynamic = null;
		try {
			if (draw != null)
				draw();
		} catch (e:Dynamic) {
			failed = true;
			failure = e;
		}

		ImGui.endTable();
		if (failed)
			report("table", id, failure);
		return true;
	}

	public static function report(kind:String, id:String, failure:Dynamic):Void {
		trace('SolarFlare ImGui $kind scope "$id" failed: $failure');
	}
}
