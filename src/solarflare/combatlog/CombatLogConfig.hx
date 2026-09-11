package solarflare.combatlog;

import solarflare.getrifty.GetRifty;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
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
		if (ImGui.checkbox("You##clog", showYou))
			SettingsStore.markDirty();
		if (ImGui.checkbox("Enemies##clog", showEnemy))
			SettingsStore.markDirty();
		if (ImGui.checkbox("Other players in rift##clog_rift", showPlayersInRift))
			SettingsStore.markDirty();
		if (showPlayersInRift.get() && !GetRiftyCache.inInstance)
			ImGui.textDisabled("Rift gate: off outside instance (preference stays on).");
		else if (showPlayersInRift.get() && GetRiftyCache.inInstance)
			ImGui.textDisabled("In rift — other players shown.");
		if (ImGui.collapsingHeader("More filters")) {
			if (ImGui.checkbox("Other players always##clog", showPlayer))
				SettingsStore.markDirty();
			if (ImGui.checkbox("Heroes only##clog", showHeroes))
				SettingsStore.markDirty();
			if (ImGui.checkbox("Current target only##clog", currentTargetOnly))
				SettingsStore.markDirty();
		}
		if (ImGui.collapsingHeader("Record")) {
			if (ImGui.checkbox("Record JSONL##clog_rec", CombatLogRecorder.enabled)) {
				SettingsStore.markDirty();
				if (CombatLogRecorder.enabled.get())
					CombatLogRecorder.newSession();
				else
					CombatLogRecorder.endSession();
			}
			if (ImGui.checkbox("Record world activity##clog_world", recordWorld)) {
				if (!recordWorld.get())
					recordInProximity.set(false);
				SettingsStore.markDirty();
			}
			ImGui.beginDisabled(!recordWorld.get());
			if (ImGui.checkbox("In Proximity##clog_prox", recordInProximity))
				SettingsStore.markDirty();
			ImGui.endDisabled();
			if (!recordWorld.get())
				ImGui.textDisabled("In Proximity needs Record world activity.");
			ImGui.text(CombatLogRecorder.lastStatus);
			ImGui.text("hlx/mods/solarflare/logs/combatlog/clog-*.jsonl");
		}
	}
}
