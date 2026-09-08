package solarflare.aura.test;

import imgui.ImGui;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import solarflare.aura.AuraDef;
import solarflare.aura.signal.AuraSignalCatalog;
import solarflare.aura.signal.AuraRuleEvaluator;

/**
 * Interactive test station for validating and stress-testing aura trigger conditions.
 */
class AuraTestHarness {
	public var active:Bool = true;
	public var simHpPercent = new FloatRef(100);
	public var simRagePercent = new FloatRef(100);
	public var simManaPercent = new FloatRef(100);
	public var simShieldPercent = new FloatRef(0);
	public var simComboCount = new IntRef(0);
	public var simSkillReady:Bool = true;
	public var simCooldownRemain = new FloatRef(0);

	public function new() {}

	public function draw(a:AuraDef):Void {
		if (a == null) return;

		ImGui.separatorText("Interactive Condition Test Harness");
		ImGui.textDisabled("Simulate game state variables to verify aura trigger rules immediately.");

		// Preset Quick Buttons
		if (ImGui.smallButton("Full Resources##th_full")) {
			simHpPercent.set(100);
			simRagePercent.set(100);
			simManaPercent.set(100);
			simShieldPercent.set(50);
			simComboCount.set(5);
			simSkillReady = true;
			simCooldownRemain.set(0);
		}
		ImGui.sameLine();
		if (ImGui.smallButton("50% Resources##th_half")) {
			simHpPercent.set(50);
			simRagePercent.set(50);
			simManaPercent.set(50);
			simShieldPercent.set(0);
			simComboCount.set(2);
			simSkillReady = true;
			simCooldownRemain.set(2.5);
		}
		ImGui.sameLine();
		if (ImGui.smallButton("Low HP (<20%)##th_low")) {
			simHpPercent.set(15);
			simRagePercent.set(10);
			simManaPercent.set(10);
			simShieldPercent.set(0);
			simComboCount.set(0);
			simSkillReady = false;
			simCooldownRemain.set(8.0);
		}
		ImGui.sameLine();
		if (ImGui.smallButton("Empty Resources##th_empty")) {
			simHpPercent.set(0);
			simRagePercent.set(0);
			simManaPercent.set(0);
			simShieldPercent.set(0);
			simComboCount.set(0);
			simSkillReady = false;
			simCooldownRemain.set(12.0);
		}

		ImGui.spacing();

		// Knobs
		if (solarflare.ui.BuilderSlider.draw("Health %##th_hp", simHpPercent, 0, 100, "%.0f%%")) {}
		if (solarflare.ui.BuilderSlider.draw("Rage %##th_rage", simRagePercent, 0, 100, "%.0f%%")) {}
		if (solarflare.ui.BuilderSlider.draw("Mana %##th_mana", simManaPercent, 0, 100, "%.0f%%")) {}
		if (solarflare.ui.BuilderSlider.draw("Shield %##th_shield", simShieldPercent, 0, 100, "%.0f%%")) {}
		if (ImGui.sliderInt("Combo Points##th_combo", simComboCount, 0, 5)) {}
		if (solarflare.ui.BuilderSlider.draw("Cooldown Left (s)##th_cd", simCooldownRemain, 0, 30, "%.1fs")) {}

		ImGui.separator();

		// Evaluate Aura condition against simulated state
		var triggered = evaluateSimulated(a);

		if (triggered) {
			ImGui.textColored(ImGui.vec4(0.3, 1.0, 0.4, 1.0), "Condition Status: ACTIVE (Aura will trigger)");
			ImGui.progressBar(1.0, ImGui.vec2(-1, 20), "TRIGGERED");
		} else {
			ImGui.textColored(ImGui.vec4(0.7, 0.7, 0.7, 1.0), "Condition Status: INACTIVE (Aura hidden)");
			ImGui.progressBar(0.0, ImGui.vec2(-1, 20), "DORMANT");
		}
	}

	function evaluateSimulated(a:AuraDef):Bool {
		if (a == null || a.rule == null || a.rule.conditions == null || a.rule.conditions.length == 0)
			return true;

		var allPass = true;
		var anyPass = false;

		for (c in a.rule.conditions) {
			if (c == null) continue;
			var pass = false;
			var sig = c.signal.toLowerCase();

			if (sig.indexOf("health") >= 0 && sig.indexOf("ratio") >= 0) {
				pass = testOp(simHpPercent.get() / 100.0, c.op, c.numberValue);
			} else if (sig.indexOf("rage") >= 0) {
				pass = testOp(simRagePercent.get() / 100.0, c.op, c.numberValue);
			} else if (sig.indexOf("mana") >= 0) {
				pass = testOp(simManaPercent.get() / 100.0, c.op, c.numberValue);
			} else if (sig.indexOf("shield") >= 0) {
				pass = testOp(simShieldPercent.get() / 100.0, c.op, c.numberValue);
			} else if (sig.indexOf("combo") >= 0) {
				pass = testOp(simComboCount.get(), c.op, c.numberValue);
			} else if (sig.indexOf("cooldown") >= 0) {
				pass = testOp(simCooldownRemain.get(), c.op, c.numberValue);
			} else {
				pass = true;
			}

			if (pass) anyPass = true;
			else allPass = false;
		}

		return a.rule.mode == "any" ? anyPass : allPass;
	}

	static function testOp(val:Float, op:String, target:Float):Bool {
		return switch (op) {
			case "lt": val < target;
			case "lte": val <= target;
			case "gt": val > target;
			case "gte": val >= target;
			case "eq": Math.abs(val - target) < 0.001;
			case "neq": Math.abs(val - target) >= 0.001;
			default: true;
		};
	}
}
