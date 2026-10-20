package solarflare.resourcetracker;

import imgui.ImGui;
import imgui.Structs.ImVec4;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import solarflare.ui.NumberField;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiLayout;

/**
 * Light presentation options shared by pip-style trackers (Rogue combo points, Conduits):
 * filled color, border thickness, glow when full. Created in constructors only (native buffer).
 */
class PipLook {
	public var useColor = new BoolRef(false);
	public var color:hl.Bytes;
	public var border = new FloatRef(2);
	public var glowFull = new BoolRef(false);

	public function new() {
		color = ImGui.v4(0.32, 0.78, 0.42, 1);
	}

	/** The user's lit color as a vec4, or null while the tracker's own palette applies. */
	public function lit():Null<ImVec4> {
		return useColor.get() ? ImGui.vec4(color.getF32(0), color.getF32(4), color.getF32(8), color.getF32(12)) : null;
	}

	public function dump():Dynamic {
		return {
			useColor: useColor.get(), color: [color.getF32(0), color.getF32(4), color.getF32(8), color.getF32(12)],
			border: border.get(), glow: glowFull.get()
		};
	}

	public function apply(d:Dynamic):Void {
		if (d == null)
			return;
		var on:Dynamic = Reflect.field(d, "useColor");
		if (Std.isOfType(on, Bool))
			useColor.set(on);
		var glow:Dynamic = Reflect.field(d, "glow");
		if (Std.isOfType(glow, Bool))
			glowFull.set(glow);
		var b:Dynamic = Reflect.field(d, "border");
		if (solarflare.ui.HudLayoutModel.finite(b))
			border.set(Math.max(0, Math.min(4, b)));
		try {
			var arr:Array<Dynamic> = Reflect.field(d, "color");
			if (arr != null && arr.length >= 4) {
				for (i in 0...4)
					if (!solarflare.ui.HudLayoutModel.finite(arr[i]))
						return;
				for (i in 0...4)
					color.setF32(i * 4, Math.max(0, Math.min(1, arr[i])));
			}
		} catch (_:Dynamic) {}
	}

	public function drawEditor(id:String):Void {
		var colorFlags = imgui.Enums.ImGuiColorEditFlags.AlphaBar | imgui.Enums.ImGuiColorEditFlags.NoInputs;
		UiLayout.propertyGrid("##rt_" + id + "_pip_look", function() {
			UiLayout.propertyRow("Filled color", function() {
				UiLayout.inlinePair("##rt_" + id + "_pipcol",
					function(_:Single) {
						if (ImGui.checkbox("Custom##rt_" + id + "_pipuse", useColor))
							SettingsStore.markDirty();
					},
					function(_:Single) {
						ImGui.beginDisabled(!useColor.get());
						if (ImGui.colorEdit4("##rt_" + id + "_pipcolor", color, colorFlags))
							SettingsStore.markDirty();
						ImGui.endDisabled();
					});
			});
			UiLayout.propertyRow("Border", function() {
				if (NumberField.draw("##rt_" + id + "_pipborder", border, 0, 4, "%.1f px"))
					SettingsStore.markDirty();
			});
			UiLayout.propertyRow("Glow", function() {
				if (ImGui.checkbox("Glow while full##rt_" + id + "_pipglow", glowFull))
					SettingsStore.markDirty();
			});
		});
	}
}
