package solarflare.ui;

import imgui.ImGui;
import imgui.ref.BoolRef;

/**
 * Global "Show explanations" preference for the builders. Sentences that explain an option stay out
 * of the way until the user asks for them. Off by default; remembered with the other UI prefs.
 * Status text, counts, empty-state messages and hover tooltips are not hints and never route here.
 */
class UiHints {
	public static var show = new BoolRef(false);

	public static inline function on():Bool return show.get();

	/** Wrapped caption that only appears while explanations are on. */
	public static function note(text:String):Void {
		if (!show.get() || text == null || text.length == 0)
			return;
		ImGui.textDisabled(text);
	}

	/** Same, but wraps at the window edge. */
	public static function noteWrapped(text:String):Void {
		if (!show.get() || text == null || text.length == 0)
			return;
		ImGui.pushTextWrapPos(0);
		ImGui.textDisabled(text);
		ImGui.popTextWrapPos();
	}

	/** Checkbox bound to the preference. Returns true when it changed. */
	public static function drawToggle(id:String, label:String = "Show explanations"):Bool {
		if (!ImGui.checkbox(label + "##" + id, show))
			return false;
		SettingsStore.markDirty();
		return true;
	}

	public static function dump():Dynamic return {show: show.get()};

	public static function apply(data:Dynamic):Void {
		if (data == null)
			return;
		var on:Dynamic = Reflect.field(data, "show");
		show.set(on == true);
	}
}
