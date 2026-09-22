package solarflare.target;

import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiLayout;
import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;

/**
 * Current-target HUD settings. Snapshot authority stays in CombatLogCache.
 */
class TargetConfig {
	public static inline var MIN_W:Single = 160;
	public static inline var MAX_W:Single = 520;
	public static inline var MIN_H:Single = 52;
	public static inline var MAX_H:Single = 180;

	public var open = new BoolRef(false);
	public var hidden = new BoolRef(true);
	/**
	 * When true, keep the window mounted with a No-target frame.
	 * When false, hide the overlay entirely while there is no valid target.
	 */
	public var alwaysShow = new BoolRef(true);
	public var showName = new BoolRef(true);
	public var showBadge = new BoolRef(true);
	public var showPortrait = new BoolRef(true);
	public var showPercent = new BoolRef(true);
	public var showHpText = new BoolRef(true);
	public var showEmptyBar = new BoolRef(true);
	public var showCastBar = new BoolRef(true);
	public var castBarHeight = new FloatRef(16);
	public var castBarSkin = new IntRef(0);
	public var lowHpPulse = new BoolRef(true);
	/** Provisional — isBoss() not yet ledger-verified in a live boss fight. */
	public var bossesOnly = new BoolRef(false);
	/** Low-HP pulse threshold as percent of max (5–50). */
	public var lowHpPercent = new FloatRef(25);
	public var barRounding = new FloatRef(3);
	public var width = new FloatRef(280);
	public var height = new FloatRef(72);
	public var sizeDirty = true;
	public var chrome:HudChrome;

	public function new() {
		chrome = new HudChrome(420, 80);
	}

	public function draw():Void {
		if (!open.get())
			return;
		ImGui.setNextWindowSize(ImGui.vec2(380, 0), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel("Current Target##solarflare_tgtcfg", open, "Current Target")) {
			ImGui.textWrapped("Local hero current target HP from the combat observe path. Draw uses a frozen snap only.");
			drawSettings("tgt");
		}
		HudChrome.endPanel();
	}

	/** Shared settings for standalone panel and Resource Tracker builder. */
	public function drawSettings(id:String):Void {
		if (id == null || id.length == 0)
			id = "tgt";
		ImGui.separatorText("Window");
		if (chrome != null)
			chrome.drawWindowSettings(hidden, id);
		UiLayout.propertyGrid("##" + id + "_window_props", function() {
			UiLayout.propertyRow("Size", function() {
				UiLayout.inlinePair(
					"##" + id + "_size",
					function(_:Single) {
						if (ImGui.sliderFloat("Width##" + id + "_w", width, MIN_W, MAX_W, "%.0f px")) {
							sizeDirty = true;
							SettingsStore.markDirty();
						}
					},
					function(_:Single) {
						if (ImGui.sliderFloat("Height##" + id + "_h", height, MIN_H, MAX_H, "%.0f px")) {
							sizeDirty = true;
							SettingsStore.markDirty();
						}
					}
				);
			});
		});

		ImGui.separatorText("Visibility");
		UiLayout.propertyGrid("##" + id + "_visibility_props", function() {
			UiLayout.propertyRow("Always show", function() {
				if (ImGui.checkbox("##" + id + "_always", alwaysShow))
					SettingsStore.markDirty();
			}, alwaysShow.get()
				? "Frame stays up with an empty placeholder when nothing is targeted."
				: "Overlay hides completely until you have a target.");
			UiLayout.propertyRow("Bosses / elites", function() {
				if (ImGui.checkbox("##" + id + "_boss", bossesOnly))
					SettingsStore.markDirty();
			}, "Boss filter uses Unit.isBoss/isElite — verify live before relying on it.");
		});

		ImGui.separatorText("Display");
		UiLayout.propertyGrid("##" + id + "_display_props", function() {
			UiLayout.propertyRow("Show", function() {
				var avail:Single = ImGui.getContentRegionAvail().x;
				var colW:Single = avail / 3;
				if (ImGui.checkbox("Show name##" + id + "_name", showName))
					SettingsStore.markDirty();
				ImGui.sameLine(colW);
				if (ImGui.checkbox("Show badge##" + id + "_badge", showBadge))
					SettingsStore.markDirty();
				ImGui.sameLine(colW * 2);
				if (ImGui.checkbox("Show portrait##" + id + "_port", showPortrait))
					SettingsStore.markDirty();
				if (ImGui.checkbox("Show HP numbers##" + id + "_hp", showHpText))
					SettingsStore.markDirty();
				ImGui.sameLine(colW);
				if (ImGui.checkbox("Show percent##" + id + "_pct", showPercent))
					SettingsStore.markDirty();
			}, "Portrait key = unit kind basename via GameIcons.");
			UiLayout.propertyRow("Placeholder", function() {
				UiLayout.inlinePair(
					"##" + id + "_placeholder",
					function(_:Single) {
						if (ImGui.checkbox("Empty bar##" + id + "_emptybar", showEmptyBar))
							SettingsStore.markDirty();
					},
					function(_:Single) {
						if (ImGui.checkbox("Low HP pulse##" + id + "_pulse", lowHpPulse))
							SettingsStore.markDirty();
					}
				);
			});
			UiLayout.propertyRow("Bar", function() {
				UiLayout.inlinePair(
					"##" + id + "_bar_metrics",
					function(_:Single) {
						if (ImGui.sliderFloat("##" + id + "_low", lowHpPercent, 5, 50, "Low %.0f%%"))
							SettingsStore.markDirty();
					},
					function(_:Single) {
						if (ImGui.sliderFloat("##" + id + "_round", barRounding, 0, 10, "Round %.0f"))
							SettingsStore.markDirty();
					}
				);
			});
		});

		ImGui.separatorText("Target cast bar");
		UiLayout.propertyGrid("##" + id + "_cast_props", function() {
			UiLayout.propertyRow("Enabled", function() {
				if (ImGui.checkbox("##" + id + "_cast", showCastBar))
					SettingsStore.markDirty();
			}, "Displays the target's active cast directly beneath its health bar.");
			UiLayout.propertyRow("Height", function() {
				if (!showCastBar.get()) ImGui.beginDisabled();
				if (ImGui.sliderFloat("##" + id + "_cast_h", castBarHeight, 12, 28, "%.0f px"))
					SettingsStore.markDirty();
				if (!showCastBar.get()) ImGui.endDisabled();
			});
		});
	}
}
