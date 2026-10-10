package solarflare.ui;

import imgui.ImGui;
import imgui.ref.BoolRef;

class HideMoveConfig {
	public var enabled = new BoolRef(false);
	public var status:String = "HideMove idle";
	public var elements:Array<HideMoveElement>;

	public function new() {
		elements = [
			new HideMoveElement("chat", "Chat box", "domkit.CompChatBox"),
			new HideMoveElement("bottomBar", "Bottom bar (hero)", "domkit.CompHeroBar"),
			new HideMoveElement("heroBarPad", "Hero bar pad", "domkit.CompHeroBarPad"),
			new HideMoveElement("castingBar", "Casting bar", "domkit.CompCastingBar")
		];
	}

	public function dump():Dynamic {
		var rows:Array<Dynamic> = [];
		for (e in elements)
			rows.push(e.dump());
		return {enabled: enabled.get(), elements: rows};
	}

	public function apply(data:Dynamic):Void {
		if (data == null)
			return;
		if (Std.isOfType(Reflect.field(data, "enabled"), Bool))
			enabled.set(Reflect.field(data, "enabled"));
		var rows:Dynamic = Reflect.field(data, "elements");
		if (rows == null)
			return;
		try {
			var arr:Array<Dynamic> = cast rows;
			if (arr == null)
				return;
			for (row in arr) {
				var id = Std.string(Reflect.field(row, "id"));
				for (e in elements) {
					if (e.id == id) {
						e.apply(row);
						break;
					}
				}
			}
		} catch (_:Dynamic) {}
	}

	public function drawControls(id:String):Void {
		UiChrome.subHeader("HideMove");
		UiLayout.propertyGrid(id, function() {
			UiLayout.propertyRow("Enable", function() {
				if (ImGui.checkbox("Apply HideMove transforms##hm_en", enabled))
					SettingsStore.markDirty();
			}, "Per-element hide/move/scale/alpha. Locked rows skip geometry writes. Chat first, then bars.");
		});
		ImGui.textWrapped(status);
		for (e in elements) {
			ImGui.separator();
			ImGui.text(e.label + " (" + e.typePath + ")");
			var eid = "##hm_" + e.id;
			UiLayout.propertyGrid(eid, function() {
				UiLayout.propertyRow("Visible", function() {
					if (ImGui.checkbox("##vis" + eid, e.visible))
						SettingsStore.markDirty();
				});
				UiLayout.propertyRow("Locked", function() {
					if (ImGui.checkbox("##lock" + eid, e.locked))
						SettingsStore.markDirty();
				}, "Locked = no position/scale persist edits this session.");
				UiLayout.propertyRow("Move", function() {
					if (ImGui.checkbox("Apply XY##pos" + eid, e.applyPos))
						SettingsStore.markDirty();
					if (!e.locked.get()) {
						if (ImGui.sliderFloat("X##x" + eid, e.x, -2000, 2000))
							SettingsStore.markDirty();
						if (ImGui.sliderFloat("Y##y" + eid, e.y, -2000, 2000))
							SettingsStore.markDirty();
					}
				});
				UiLayout.propertyRow("Scale", function() {
					if (ImGui.checkbox("Apply scale##sc" + eid, e.applyScale))
						SettingsStore.markDirty();
					if (!e.locked.get() && ImGui.sliderFloat("##scale" + eid, e.scale, 0.25, 3.0))
						SettingsStore.markDirty();
				}, "h2d.Object.setScale — not engine resize().");
				UiLayout.propertyRow("Alpha", function() {
					if (ImGui.checkbox("Apply alpha##al" + eid, e.applyAlpha))
						SettingsStore.markDirty();
					if (!e.locked.get() && ImGui.sliderFloat("##alpha" + eid, e.alpha, 0, 1))
						SettingsStore.markDirty();
				});
			});
		}
	}
}
