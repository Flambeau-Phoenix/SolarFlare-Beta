package solarflare.ui;

import imgui.ImGui;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;

/**
 * One-binary Custom | Native pack. Own menu (not inline on F6 Resources).
 * Flips NativeHide + BarTer + target/cast defaults. Docs: native-ui/HIDE_MATRIX.md
 */
class UiPackConfig {
	public static inline var PACK_CUSTOM:Int = 0;
	public static inline var PACK_NATIVE:Int = 1;

	public var pack = new IntRef(PACK_CUSTOM);
	public var open = new BoolRef(false);

	public function new() {}

	public function isCustom():Bool return pack.get() != PACK_NATIVE;
	public function isNative():Bool return pack.get() == PACK_NATIVE;

	public function dump():Dynamic {
		return {id: isNative() ? "native" : "custom"};
	}

	public function apply(data:Dynamic):Void {
		if (data == null) return;
		var id:Dynamic = Reflect.field(data, "id");
		if (Std.isOfType(id, String)) {
			var s:String = id;
			pack.set(s == "native" ? PACK_NATIVE : PACK_CUSTOM);
		} else {
			var n:Dynamic = Reflect.field(data, "pack");
			if (Std.isOfType(n, Int))
				pack.set(n == PACK_NATIVE ? PACK_NATIVE : PACK_CUSTOM);
		}
	}

	/** Apply pack defaults onto live config modules. */
	public function applyPack(cfg:ConfigPanel):Void {
		if (cfg == null) return;
		if (isNative()) {
			if (cfg.nativeHide != null) {
				cfg.nativeHide.hideBottomBar.set(false);
				cfg.nativeHide.hideAll.set(false);
			}
			if (cfg.barter != null && cfg.barter.config != null) {
				cfg.barter.config.enabled.set(false);
				cfg.barter.config.hidden.set(true);
			}
		} else {
			if (cfg.nativeHide != null) {
				cfg.nativeHide.hideBottomBar.set(true);
			}
			if (cfg.barter != null && cfg.barter.config != null) {
				cfg.barter.config.enabled.set(true);
				cfg.barter.config.hidden.set(false);
			}
			if (cfg.target != null) {
				cfg.target.showCastBar.set(true);
				if (cfg.target.height.get() < 96)
					cfg.target.height.set(96);
				if (cfg.target.width.get() < 300)
					cfg.target.width.set(320);
				cfg.target.sizeDirty = true;
			}
			if (cfg.castBar != null)
				cfg.castBar.hidden.set(true);
		}
		SettingsStore.markDirty();
	}

	/** One-line pack state on Resources — menu opens from the logo launcher row. */
	public function drawHubPackBlurb():Void {
		ImGui.textWrapped("UI pack and Domkit hide live in Native UI (button under the logo).");
		ImGui.text(isNative() ? "Pack: Native UI" : "Pack: Custom UI");
	}

	public function drawMenu(cfg:ConfigPanel):Void {
		if (!open.get())
			return;
		EditorWindow.drawMenuWindow("Native UI###SolarFlare.NativeUI", open, 640, 720, function() {
			drawBody(cfg);
		});
	}

	function drawBody(cfg:ConfigPanel):Void {
		UiChrome.heading("Native UI", 1.35);
		ImGui.textWrapped("One solarflare.hl. Switch pack preset, then tune Domkit hide and HideMove without crowding the F6 hub.");
		ImGui.separator();
		drawPackControls(cfg, "##native_ui_pack");
		ImGui.separator();
		if (cfg != null && cfg.nativeHide != null)
			cfg.nativeHide.drawControls("##native_ui_hide");
		ImGui.separator();
		if (cfg != null && cfg.hideMove != null)
			cfg.hideMove.drawControls("##native_ui_hidemove");
	}

	function drawPackControls(cfg:ConfigPanel, id:String):Void {
		UiChrome.subHeader("UI pack");
		UiLayout.propertyGrid(id + "_grid", function() {
			UiLayout.propertyRow("Preset", function() {
				var cur = isNative() ? "Native UI" : "Custom UI";
				if (ImGui.beginCombo(id + "_combo", cur)) {
					if (ImGui.selectable("Custom UI", !isNative())) {
						pack.set(PACK_CUSTOM);
						applyPack(cfg);
					}
					if (ImGui.selectable("Native UI", isNative())) {
						pack.set(PACK_NATIVE);
						applyPack(cfg);
					}
					ImGui.endCombo();
				}
			}, "Custom hides Domkit bottom bar and enables BarTer. Native leaves Domkit skills visible.");
		});
		ImGui.textWrapped(isNative()
			? "Native pack: Domkit skill strip stays. BarTer off by default."
			: "Custom pack: NativeHide bottom bar on, BarTer on, larger target HP; player cast bar hidden (target cast bar stays).");
	}
}
