package solarflare.resourcetracker;

import imgui.ImGui;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import solarflare.ui.NumberField;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiLayout;

/**
 * Presentation options for the three prayer icons. Colors drive the fallback shape (used when the
 * game icon is missing) and the ready ring. Created in constructors only (native-backed buffers).
 */
class PrayerLook {
	public static final SHAPE_NAMES = ["Rounded square", "Circle", "Diamond", "Hex"];

	public var size = new FloatRef(30);
	public var gap = new FloatRef(3);
	public var shape = new IntRef(0);
	public var smite:hl.Bytes;
	public var life:hl.Bytes;
	public var shield:hl.Bytes;
	public var dimAlpha = new FloatRef(0.38);
	public var readyRing = new BoolRef(false);
	public var border = new BoolRef(false);

	public function new() {
		smite = ImGui.v4(0.95, 0.22, 0.18, 0.95);
		life = ImGui.v4(0.95, 0.78, 0.22, 0.95);
		shield = ImGui.v4(0.28, 0.55, 0.98, 0.95);
	}

	public function colorFor(index:Int):hl.Bytes return index == 0 ? smite : (index == 1 ? life : shield);

	public function dump():Dynamic {
		return {
			size: size.get(), gap: gap.get(), shape: shape.get(), smite: v4(smite), life: v4(life), shield: v4(shield),
			dim: dimAlpha.get(), ring: readyRing.get(), border: border.get()
		};
	}

	public function apply(d:Dynamic):Void {
		if (d == null)
			return;
		size.set(num(d, "size", size.get(), 16, 64));
		gap.set(num(d, "gap", gap.get(), 0, 16));
		shape.set(Std.int(num(d, "shape", shape.get(), 0, SHAPE_NAMES.length - 1)));
		loadV4(smite, Reflect.field(d, "smite"));
		loadV4(life, Reflect.field(d, "life"));
		loadV4(shield, Reflect.field(d, "shield"));
		dimAlpha.set(num(d, "dim", dimAlpha.get(), 0.1, 1));
		var ring:Dynamic = Reflect.field(d, "ring");
		if (Std.isOfType(ring, Bool))
			readyRing.set(ring);
		var edge:Dynamic = Reflect.field(d, "border");
		if (Std.isOfType(edge, Bool))
			border.set(edge);
	}

	static function num(d:Dynamic, k:String, fallback:Float, lo:Float, hi:Float):Float {
		var v:Dynamic = Reflect.field(d, k);
		return solarflare.ui.HudLayoutModel.finite(v) ? Math.max(lo, Math.min(hi, v)) : fallback;
	}

	static function v4(b:hl.Bytes):Array<Float> return [b.getF32(0), b.getF32(4), b.getF32(8), b.getF32(12)];

	static function loadV4(b:hl.Bytes, data:Dynamic):Void {
		if (data == null)
			return;
		try {
			var arr:Array<Dynamic> = data;
			if (arr == null || arr.length < 4)
				return;
			for (i in 0...4)
				if (!solarflare.ui.HudLayoutModel.finite(arr[i]))
					return;
			for (i in 0...4)
				b.setF32(i * 4, Math.max(0, Math.min(1, arr[i])));
		} catch (_:Dynamic) {}
	}

	public function drawEditor(id:String):Void {
		var colorFlags = imgui.Enums.ImGuiColorEditFlags.AlphaBar | imgui.Enums.ImGuiColorEditFlags.NoInputs;
		UiLayout.propertyGrid("##rt_" + id + "_prayer_look", function() {
			UiLayout.propertyRow("Icon size", function() {
				if (NumberField.draw("##rt_" + id + "_psize", size, 16, 64, "%.0f px"))
					SettingsStore.markDirty();
			});
			UiLayout.propertyRow("Spacing", function() {
				if (NumberField.draw("##rt_" + id + "_pgap", gap, 0, 16, "%.0f px"))
					SettingsStore.markDirty();
			});
			UiLayout.propertyRow("Shape", function() {
				if (ImGui.beginCombo("##rt_" + id + "_pshape", SHAPE_NAMES[shape.get()])) {
					for (i in 0...SHAPE_NAMES.length)
						if (ImGui.selectable(SHAPE_NAMES[i] + "##rt_" + id + "_pshape_" + i, shape.get() == i)) {
							shape.set(i);
							SettingsStore.markDirty();
						}
					ImGui.endCombo();
				}
			}, "Used when a prayer has no custom image and the game icon is unavailable; also shapes the ring.");
			UiLayout.propertyRow("Colors", function() {
				UiLayout.inlineSplit("##rt_" + id + "_pcols", 3, function(i:Int, _:Single) {
					if (ImGui.colorEdit4("##rt_" + id + "_pcol_" + i, colorFor(i), colorFlags))
						SettingsStore.markDirty();
				});
			}, "Smite, Life, Shield.");
			UiLayout.propertyRow("Not ready", function() {
				if (NumberField.draw("##rt_" + id + "_pdim", dimAlpha, 0.1, 1, "%.2f"))
					SettingsStore.markDirty();
			}, "How visible a prayer is while it is recharging.");
			UiLayout.propertyRow("Accents", function() {
				UiLayout.inlinePair("##rt_" + id + "_paccents",
					function(_:Single) {
						if (ImGui.checkbox("Ready ring##rt_" + id + "_pring", readyRing))
							SettingsStore.markDirty();
					},
					function(_:Single) {
						if (ImGui.checkbox("Border##rt_" + id + "_pborder", border))
							SettingsStore.markDirty();
					});
			});
		});
	}
}
