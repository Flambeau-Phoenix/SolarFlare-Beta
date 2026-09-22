package solarflare.castbar;

import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiLayout;
import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;

class CastBarConfig {
	public static inline var MIN_W:Single = 240;
	public static inline var MAX_W:Single = 760;
	public static inline var MIN_H:Single = 34;
	public static inline var MAX_H:Single = 120;

	public var open = new BoolRef(false);
	public var hidden = new BoolRef(false);
	public var showIcon = new BoolRef(true);
	public var showName = new BoolRef(true);
	public var showTime = new BoolRef(true);
	public var skin = new IntRef(0);
	public var width = new FloatRef(460);
	public var height = new FloatRef(58);
	public var sizeDirty = true;
	public var chrome = new HudChrome(480, 760);
	var preview = new CastSnap();

	public function new() {
		preview.active = true;
		preview.skillId = "Mage_RayOfSpark";
		preview.label = "Ray Of Spark";
		preview.duration = 3.5;
		preview.elapsed = 2.15;
		preview.remaining = 1.35;
		preview.progress = preview.elapsed / preview.duration;
	}

	public function draw():Void {
		if (!open.get()) return;
		ImGui.setNextWindowSize(ImGui.vec2(520, 0), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel("Player Cast Bar##solarflare_castcfg", open, "Player Cast Bar")) {
			ImGui.textWrapped("Shows your current cast from the frozen telemetry snapshot. Drag or resize the HUD bar directly.");
			drawSettings("cast");
			ImGui.separatorText("Preview");
			var avail:Single = ImGui.getContentRegionAvail().x;
			var ph:Single = Math.max(MIN_H, Math.min(80, height.get()));
			var p = ImGui.getCursorScreenPos();
			ImGui.dummy(ImGui.vec2(avail, ph));
			CastBarRenderer.drawPlayer(preview, skin.get(), showIcon.get(), showName.get(), showTime.get(), p.x, p.y, avail, ph);
		}
		HudChrome.endPanel();
	}

	public function drawSettings(id:String):Void {
		ImGui.separatorText("Window");
		chrome.drawWindowSettings(hidden, id);
		UiLayout.propertyGrid("##" + id + "_window", function() {
			UiLayout.propertyRow("Size", function() {
				UiLayout.inlinePair("##" + id + "_size", function(_:Single) {
					if (ImGui.sliderFloat("Width##" + id, width, MIN_W, MAX_W, "%.0f px")) { sizeDirty = true; SettingsStore.markDirty(); }
				}, function(_:Single) {
					if (ImGui.sliderFloat("Height##" + id, height, MIN_H, MAX_H, "%.0f px")) { sizeDirty = true; SettingsStore.markDirty(); }
				});
			});
		});
		ImGui.separatorText("Appearance");
		UiLayout.propertyGrid("##" + id + "_appearance", function() {
			UiLayout.propertyRow("Skin", function() { drawSkinCombo("##" + id + "_skin"); });
			UiLayout.propertyRow("Show", function() {
				if (ImGui.checkbox("Icon##" + id, showIcon)) SettingsStore.markDirty();
				ImGui.sameLine();
				if (ImGui.checkbox("Spell name##" + id, showName)) SettingsStore.markDirty();
				ImGui.sameLine();
				if (ImGui.checkbox("Time##" + id, showTime)) SettingsStore.markDirty();
			});
		});
	}

	function drawSkinCombo(id:String):Void {
		var current = skin.get();
		if (current < 0 || current >= CastBarRenderer.SKIN_NAMES.length) current = 0;
		if (!ImGui.beginCombo(id, CastBarRenderer.SKIN_NAMES[current])) return;
		for (i in 0...CastBarRenderer.SKIN_NAMES.length) {
			if (ImGui.selectable(CastBarRenderer.SKIN_NAMES[i] + "##skin" + i, current == i)) {
				skin.set(i);
				SettingsStore.markDirty();
			}
		}
		ImGui.endCombo();
	}
}
