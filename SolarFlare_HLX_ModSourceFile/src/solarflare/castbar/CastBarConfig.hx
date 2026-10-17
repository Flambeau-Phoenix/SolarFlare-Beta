package solarflare.castbar;

import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.ThemePalette;
import solarflare.ui.UiChrome;
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
		drawSkinPicker(id);
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
			UiLayout.propertyRow("Show", function() {
				if (ImGui.checkbox("Icon##" + id, showIcon)) SettingsStore.markDirty();
				ImGui.sameLine();
				if (ImGui.checkbox("Spell name##" + id, showName)) SettingsStore.markDirty();
				ImGui.sameLine();
				if (ImGui.checkbox("Time##" + id, showTime)) SettingsStore.markDirty();
			});
		});
	}

	/**
	 * The skin choice is the most visible decision here, so it is a grid of large cards, each showing the real
	 * skin, instead of a small dropdown. It comes first, directly under the preview.
	 */
	public function drawSkinPicker(id:String):Void {
		UiChrome.subHeader("Skin");
		var names = CastBarRenderer.SKIN_NAMES;
		var current = skin.get();
		if (current < 0 || current >= names.length) current = 0;
		var theme = ThemePalette.current();
		var gap:Single = 8;
		var avail:Single = ImGui.getContentRegionAvail().x;
		var columns = Std.int(Math.max(1, Math.floor((avail + gap) / (190 + gap))));
		var cardW:Single = (avail - gap * (columns - 1)) / columns;
		var cardH:Single = 66;
		for (i in 0...names.length) {
			if (i % columns != 0) ImGui.sameLine(0, gap);
			var p = ImGui.getCursorScreenPos();
			var clicked = ImGui.invisibleButton("##" + id + "_skin_" + i, ImGui.vec2(cardW, cardH));
			var hovered = ImGui.isItemHovered();
			var dl = ImGui.getWindowDrawList();
			var max = ImGui.vec2(p.x + cardW, p.y + cardH);
			var selected = i == current;
			var mix:Single = selected ? 0.34 : hovered ? 0.12 : 0;
			ImGui.ImDrawList_AddRectFilled(dl, p, max, ImGui.colorConvertFloat4ToU32(ImGui.vec4(
				theme.cellBg.x * (1 - mix) + theme.accent.x * mix,
				theme.cellBg.y * (1 - mix) + theme.accent.y * mix,
				theme.cellBg.z * (1 - mix) + theme.accent.z * mix, 0.96)), 10);
			ImGui.ImDrawList_AddRect(dl, p, max, ImGui.colorConvertFloat4ToU32(selected ? theme.accent : theme.border), 10, selected ? 2 : 1, 0);
			CastBarRenderer.drawPlayer(preview, i, false, false, false, p.x + 10, p.y + 8, cardW - 20, 28);
			var label = names[i];
			var ts = ImGui.calcTextSize(label);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(p.x + (cardW - ts.x) * 0.5, p.y + cardH - ts.y - 7),
				ImGui.colorConvertFloat4ToU32(selected ? theme.text : theme.textDisabled), label);
			if (clicked && i != current) {
				skin.set(i);
				SettingsStore.markDirty();
			}
		}
		ImGui.spacing();
	}
}
