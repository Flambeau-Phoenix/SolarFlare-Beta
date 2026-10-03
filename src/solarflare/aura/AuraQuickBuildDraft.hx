package solarflare.aura;

import imgui.ref.BoolRef;
import solarflare.aura.signal.AuraConditionDef;
import solarflare.aura.signal.AuraRuleDef;

/** Session-only creation draft. Never writes SettingsStore or the library. */
class AuraQuickBuildDraft {
	public var aura(default, null):AuraDef;
	public var condition(default, null):AuraConditionDef;
	public var behavior(default, null):String = AuraEffect.WHEN_WHILE_TRUE;
	public var face(default, null):String = "Bar";
	var configuredHold:Float;
	var briefHold:Float;

	public function new() {
		aura = new AuraDef("quick_build_draft", "New Aura");
		configuredHold = aura.duration;
		briefHold = aura.effects[0].hold;
		aura.rule = new AuraRuleDef();
		condition = new AuraConditionDef();
		aura.rule.conditions.push(condition);
	}

	public function setFace(value:String):Void {
		if (["Icon", "Glow", "Bar", "Banner"].indexOf(value) < 0) return;
		face = value;
		aura.showBanner.set(value == "Banner");
		aura.visual.set(value != "Banner");
		if (value != "Banner") aura.region = value == "Bar" ? "bar" : "icon";
		for (e in aura.effects) {
			if (e.kind == AuraEffect.KIND_ICON) e.glow.set(false);
			if (e.kind == AuraEffect.KIND_ALERT) e.enabled.set(false);
		}
		if (value == "Glow") {
			var e = effect(AuraEffect.KIND_ICON);
			e.enabled.set(true);
			e.glow.set(true);
		}
		if (value == "Banner") effect(AuraEffect.KIND_ALERT).enabled.set(true);
	}

	function effect(kind:String):AuraEffect {
		for (e in aura.effects) if (e.kind == kind) return e;
		var e = new AuraEffect("quick_" + kind, kind, behavior);
		e.hold = aura.duration;
		e.holdRef.set(e.hold);
		aura.effects.push(e);
		return e;
	}

	public function setBehavior(value:String):Void {
		if ([AuraEffect.WHEN_WHILE_TRUE, AuraEffect.WHEN_ON_RISE_HOLD, AuraEffect.WHEN_ON_RISE].indexOf(value) < 0) return;
		behavior = value;
		aura.duration = value == AuraEffect.WHEN_ON_RISE ? briefHold : configuredHold;
		aura.durRef.set(aura.duration);
		for (e in aura.effects) {
			e.when = value;
			e.hold = aura.duration;
			e.holdRef.set(e.hold);
		}
		aura.dormant.set(value == AuraEffect.WHEN_ON_RISE_HOLD);
	}

	public function setHold(seconds:Float):Void {
		if (!Math.isFinite(seconds)) seconds = 3;
		aura.duration = Math.max(0.5, Math.min(10, seconds));
		configuredHold = aura.duration;
		aura.durRef.set(aura.duration);
		for (e in aura.effects) { e.hold = aura.duration; e.holdRef.set(e.hold); }
	}

	public function overlay(key:String):BoolRef {
		return switch (key) {
			case "Stacks": aura.stackCounter;
			case "Counter": aura.isCounter;
			case "Countdown": aura.showCountdown;
			case "Fuse": aura.showFuse;
			default: aura.showLabel;
		};
	}

	public function toggleOverlay(key:String):Void {
		var ref = overlay(key);
		if (AuraQuickBuildRules.overlayAllowed(key, !ref.get(), aura.stackCounter.get(), aura.isCounter.get()))
			ref.set(!ref.get());
	}

	public function issue(hasIcon:String->Bool):String {
		if (StringTools.trim(aura.name).length == 0) return "Give this aura a name.";
		var problem = AuraQuickBuildRules.conditionIssue(condition);
		if (problem.length > 0) return problem;
		if ((face == "Icon" || face == "Glow") && !hasIcon(aura.preferredIconId())) return "Choose a usable icon.";
		if (aura.stackCounter.get() && aura.isCounter.get()) return "Turn off either Stacks or Counter.";
		return "";
	}

	public function summary():String {
		var problem = AuraQuickBuildRules.conditionIssue(condition);
		if (problem.length > 0) return problem;
		var when = AuraQuickBuildRules.conditionSummary(condition);
		var label = face == "Icon" ? "Icon Alert" : face;
		var result = switch (behavior) {
			case AuraEffect.WHEN_ON_RISE_HOLD: "Show " + label + " for " + aura.duration + " seconds when " + when + " becomes true";
			case AuraEffect.WHEN_ON_RISE: "Alert with " + label + " once each time " + when + " becomes true";
			default: "Show " + label + " when " + when;
		};
		var overlays = [];
		if (face != "Banner")
			for (key in ["Stacks", "Counter", "Countdown", "Fuse", "Label"]) if (overlay(key).get()) overlays.push(key.toLowerCase());
		return result + (overlays.length > 0 ? ", with " + overlays.join(", ") : "") + "."
			+ (face != "Banner" && !aura.chrome.locked.get() ? " The unlocked HUD face also stays visible for placement." : "");
	}
}
