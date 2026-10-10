package solarflare.ui;

import imgui.ImGui;
import imgui.ref.BoolRef;

/** Global presentation preferences; never part of a character/gear profile. */
class NativeHideConfig {
	public var hideBottomBar = new BoolRef(true);
	public var hideAll = new BoolRef(false);
	/** Live acceptance is deliberately session-only. Loading JSON cannot grant it. */
	public var bottomBarAccepted = new BoolRef(false);
	public var status:String = "Waiting for native HUD";

	public function new() {}

	public function dump():Dynamic {
		return {hideBottomBar: hideBottomBar.get(), hideAll: hideAll.get()};
	}

	public function apply(data:Dynamic):Void {
		if (data == null) return;
		var bottom:Dynamic = Reflect.field(data, "hideBottomBar");
		var all:Dynamic = Reflect.field(data, "hideAll");
		if (Std.isOfType(bottom, Bool)) hideBottomBar.set(bottom);
		if (Std.isOfType(all, Bool)) hideAll.set(all);
	}

	/** F6 Hub controls change preferences only; observation owns engine calls. */
	public function drawControls(id:String):Void {
		UiChrome.subHeader("Native UI");
		UiLayout.propertyGrid(id, function() {
			UiLayout.propertyRow("Bottom bar", function() {
				if (ImGui.checkbox("Hide native bottom bar", hideBottomBar)) SettingsStore.markDirty();
			});
			UiLayout.propertyRow("Live acceptance", function() {
				if (ImGui.checkbox("Bottom bar tested this session", bottomBarAccepted) && !bottomBarAccepted.get()) {
					hideAll.set(false);
					SettingsStore.markDirty();
				}
			}, "Confirm toggle/reload, casting, data, and camera recovery before trying full-root hiding.");
			UiLayout.propertyRow("Full native root", function() {
				if (bottomBarAccepted.get()) {
					if (ImGui.checkbox("Experimental: KeepWorld hide (custom UI mode)", hideAll)) SettingsStore.markDirty();
				} else ImGui.textDisabled("Requires bottom-bar acceptance");
			}, "Uses HideMode.KeepWorld when available (UI root off, world stays). All is fallback only. F6 remains via SolarFlare.");
			UiLayout.propertyRow("Recovery", function() {
				if (ImGui.button("Restore native UI")) {
					hideAll.set(false);
					hideBottomBar.set(false);
					SettingsStore.markDirty();
				}
			});
		});
		ImGui.textWrapped(status);
	}
}
