package solarflare.target;

import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;

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
		if (ImGui.sliderFloat("Width##" + id + "_w", width, MIN_W, MAX_W, "%.0f px")) {
			sizeDirty = true;
			SettingsStore.markDirty();
		}
		if (ImGui.sliderFloat("Height##" + id + "_h", height, MIN_H, MAX_H, "%.0f px")) {
			sizeDirty = true;
			SettingsStore.markDirty();
		}

		ImGui.separatorText("Visibility");
		if (ImGui.checkbox("Always show (No target frame)##" + id + "_always", alwaysShow))
			SettingsStore.markDirty();
		ImGui.textDisabled(alwaysShow.get()
			? "Frame stays up with an empty placeholder when nothing is targeted."
			: "Overlay hides completely until you have a target.");
		if (ImGui.checkbox("Bosses / elites only##" + id + "_boss", bossesOnly))
			SettingsStore.markDirty();
		ImGui.textDisabled("Boss filter uses Unit.isBoss/isElite — verify live before relying on it.");

		ImGui.separatorText("Display");
		if (ImGui.checkbox("Show name##" + id + "_name", showName))
			SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.checkbox("Show badge##" + id + "_badge", showBadge))
			SettingsStore.markDirty();
		if (ImGui.checkbox("Show portrait##" + id + "_port", showPortrait))
			SettingsStore.markDirty();
		ImGui.textDisabled("Portrait key = unit kind basename via GameIcons (atlas frame or icons/portraits/{kind}.png).");
		if (ImGui.checkbox("Show HP numbers##" + id + "_hp", showHpText))
			SettingsStore.markDirty();
		ImGui.sameLine();
		if (ImGui.checkbox("Show percent##" + id + "_pct", showPercent))
			SettingsStore.markDirty();
		if (ImGui.checkbox("Empty bar in placeholder##" + id + "_emptybar", showEmptyBar))
			SettingsStore.markDirty();
		if (ImGui.checkbox("Pulse under low HP##" + id + "_pulse", lowHpPulse))
			SettingsStore.markDirty();
		if (ImGui.sliderFloat("Low HP threshold##" + id + "_low", lowHpPercent, 5, 50, "%.0f%%"))
			SettingsStore.markDirty();
		if (ImGui.sliderFloat("Bar rounding##" + id + "_round", barRounding, 0, 10, "%.0f"))
			SettingsStore.markDirty();
	}
}
