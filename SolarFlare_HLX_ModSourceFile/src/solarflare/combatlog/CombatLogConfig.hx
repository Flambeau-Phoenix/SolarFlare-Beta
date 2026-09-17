package solarflare.combatlog;

import solarflare.getrifty.GetRifty;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiLayout;
import imgui.ImGui;
import imgui.ref.BoolRef;

/**
 * F6 combat-log filters. Defaults: You + Enemy on; other players only while in rift.
 */
class CombatLogConfig {
	/** Single live instance for recorder/capture filters (set in constructor). */
	public static var live:CombatLogConfig = null;

	/** World-activity proximity radius (pos2D units). */
	public static inline var PROXIMITY:Float = 40;

	public var hidden = new BoolRef(false);
	public var showYou = new BoolRef(true);
	/** Force other players in open world too. Default off. */
	public var showPlayer = new BoolRef(false);
	/** Other players while GetRiftyCache.inInstance. Default on; auto-silent outside rift. */
	public var showPlayersInRift = new BoolRef(true);
	public var showEnemy = new BoolRef(true);
	public var showHeroes = new BoolRef(true);
	public var currentTargetOnly = new BoolRef(false);
	/** JSONL: also keep non-you world/player lines. */
	public var recordWorld = new BoolRef(false);
	/** JSONL world subset: only lines marked inProximity. Requires recordWorld. */
	public var recordInProximity = new BoolRef(false);
	public var width = new imgui.ref.FloatRef(720);
	public var height = new imgui.ref.FloatRef(240);
	public var sizeDirty = true;
	public var chrome:HudChrome;

	public function new() {
		chrome = new HudChrome(40, 360);
		live = this;
	}

	/** ROLE_PLAYER display: always OR (in-rift preference && currently in rift). */
	public function effectiveShowPlayer():Bool {
		if (showPlayer.get())
			return true;
		return showPlayersInRift.get() && GetRiftyCache.inInstance;
	}

	public function passes(line:CombatLogLine):Bool {
		if (line == null)
			return false;
		if (currentTargetOnly.get() && !line.involvesCurrentTarget)
			return false;
		if (showHeroes.get() && !line.heroInvolved)
			return false;
		return roleOn(line.sourceRole) || roleOn(line.targetRole);
	}

	/**
	 * Recorder gate. You-side lines always. World/player lines need recordWorld;
	 * proximity further requires line.inProximity.
	 */
	public function shouldRecord(line:CombatLogLine):Bool {
		if (line == null)
			return false;
		if (line.sourceRole == CombatLogCache.ROLE_YOU || line.targetRole == CombatLogCache.ROLE_YOU)
			return true;
		if (!recordWorld.get())
			return false;
		if (recordInProximity.get() && !line.inProximity)
			return false;
		return true;
	}

	function roleOn(role:Int):Bool {
		if (role == CombatLogCache.ROLE_YOU)
			return showYou.get();
		if (role == CombatLogCache.ROLE_PLAYER)
			return effectiveShowPlayer();
		if (role == CombatLogCache.ROLE_ENEMY)
			return showEnemy.get();
		return showEnemy.get() || effectiveShowPlayer();
	}

	public function drawEditorContents():Void {
		ImGui.separatorText("Window");
		chrome.drawWindowSettings(hidden, "clog");
		ImGui.separatorText("Show");
		UiLayout.propertyGrid("##clog_show_props", function() {
			UiLayout.propertyRow("Roles", function() {
				var avail:Single = ImGui.getContentRegionAvail().x;
				var colW:Single = avail / 3;
				if (ImGui.checkbox("You##clog", showYou))
					SettingsStore.markDirty();
				ImGui.sameLine(colW);
				if (ImGui.checkbox("Enemies##clog", showEnemy))
					SettingsStore.markDirty();
				ImGui.sameLine(colW * 2);
				if (ImGui.checkbox("Other players in rift##clog_rift", showPlayersInRift))
					SettingsStore.markDirty();
			}, showPlayersInRift.get()
				? (GetRiftyCache.inInstance
					? "In rift — other players shown."
					: "Rift gate: off outside instance (preference stays on).")
				: null);
		});
		if (ImGui.collapsingHeader("More filters##clog_more")) {
			UiLayout.propertyGrid("##clog_more_props", function() {
				UiLayout.propertyRow("Filters", function() {
					UiLayout.inlinePair(
						"##clog_more_pair",
						function(_:Single) {
							if (ImGui.checkbox("Other players always##clog", showPlayer))
								SettingsStore.markDirty();
						},
						function(_:Single) {
							if (ImGui.checkbox("Heroes only##clog", showHeroes))
								SettingsStore.markDirty();
						}
					);
				});
				UiLayout.propertyRow("Target", function() {
					if (ImGui.checkbox("Current target only##clog", currentTargetOnly))
						SettingsStore.markDirty();
				});
			});
		}
		if (ImGui.collapsingHeader("Record##clog_record")) {
			UiLayout.propertyGrid("##clog_record_props", function() {
				UiLayout.propertyRow("JSONL", function() {
					if (ImGui.checkbox("Record JSONL##clog_rec", CombatLogRecorder.enabled)) {
						SettingsStore.markDirty();
						if (CombatLogRecorder.enabled.get())
							CombatLogRecorder.newSession();
						else
							CombatLogRecorder.endSession();
					}
				});
				UiLayout.propertyRow("World", function() {
					UiLayout.inlinePair(
						"##clog_world_pair",
						function(_:Single) {
							if (ImGui.checkbox("World activity##clog_world", recordWorld)) {
								if (!recordWorld.get())
									recordInProximity.set(false);
								SettingsStore.markDirty();
							}
						},
						function(_:Single) {
							ImGui.beginDisabled(!recordWorld.get());
							if (ImGui.checkbox("In Proximity##clog_prox", recordInProximity))
								SettingsStore.markDirty();
							ImGui.endDisabled();
						}
					);
				}, !recordWorld.get() ? "In Proximity needs Record world activity." : null);
			});
			ImGui.text(CombatLogRecorder.lastStatus);
			ImGui.textDisabled("hlx/mods/solarflare/logs/combatlog/clog-*.jsonl");
		}
	}
}
