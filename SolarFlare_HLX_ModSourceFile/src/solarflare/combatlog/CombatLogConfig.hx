package solarflare.combatlog;

import solarflare.ui.CursorCaptureFix;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.BoolRef;

/**
 * F6 combat-log filters. Defaults: You + Enemy on, other players off.
 */
class CombatLogConfig {
	public var open = new BoolRef(false);
	public var hidden = new BoolRef(false);
	public var showYou = new BoolRef(true);
	public var showPlayer = new BoolRef(false);
	public var showEnemy = new BoolRef(true);
	public var showHeroes = new BoolRef(true);
	public var currentTargetOnly = new BoolRef(false);
	public var chrome:HudChrome;

	public function new() {
		chrome = new HudChrome(40, 360);
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

	function roleOn(role:Int):Bool {
		if (role == CombatLogCache.ROLE_YOU)
			return showYou.get();
		if (role == CombatLogCache.ROLE_PLAYER)
			return showPlayer.get();
		if (role == CombatLogCache.ROLE_ENEMY)
			return showEnemy.get();
		return showEnemy.get() || showPlayer.get();
	}

	public function draw():Void {
		if (!open.get())
			return;
		ImGui.setNextWindowSize(ImGui.vec2(360, 0), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel("Combat Log##solarflare_cfg", open, "Combat Log")) {
			ImGui.text("Skill casts and resolved hits. YOU is the local hero.");
			if (ImGui.checkbox("Hide overlay##clog", hidden))
				SettingsStore.markDirty();
			chrome.drawToggles("clog");
			ImGui.separatorText("Show");
			if (ImGui.checkbox("You##clog", showYou))
				SettingsStore.markDirty();
			if (ImGui.checkbox("Enemies##clog", showEnemy))
				SettingsStore.markDirty();
			if (ImGui.collapsingHeader("More filters")) {
				if (ImGui.checkbox("Other players##clog", showPlayer))
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
				ImGui.text(CombatLogRecorder.lastStatus);
				ImGui.text("hlx/mods/solarflare/logs/combatlog/clog-*.jsonl");
			}
		}
		HudChrome.endPanel();
	}
}
