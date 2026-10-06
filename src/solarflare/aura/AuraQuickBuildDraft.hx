package solarflare.aura;

import imgui.ref.BoolRef;
import solarflare.aura.signal.AuraConditionDef;
import solarflare.aura.signal.AuraRuleDef;

/** Session-only creation draft. Never writes SettingsStore or the library. */
class AuraQuickBuildDraft {
	public var aura(default, null):AuraDef;
	public var condition(default, null):AuraConditionDef;
	public var behavior(default, null):String = AuraEffect.WHEN_WHILE_TRUE;
	public var face(default, null):String = "Icon";
	public var cooldownReference(default, null):String = "Game time";
	public var timerReferenceLabel(default, null):String = "Unknown";
	var configuredHold:Float;
	var briefHold:Float;

	public function new() {
		aura = AuraPresentationDefaults.fresh(new AuraDef("quick_build_draft", "New Aura"));
		configuredHold = aura.duration;
		briefHold = aura.effects[0].hold;
		aura.rule = new AuraRuleDef();
		condition = new AuraConditionDef();
		aura.rule.conditions.push(condition);
	}

	/** Builds a new owned template; never adopts or mutates a library aura. */
	public static function fromCombatLog(choice:CombatLogAuraChoices.CombatLogAuraChoice, label:String):AuraQuickBuildDraft {
		var draft = new AuraQuickBuildDraft();
		if (choice.preset == "enemy") draft.aura = AuraTemplates.createEnemySpellCastAlert();
		else if (choice.preset == "damage") draft.aura = AuraTemplates.createDamageTakenSpike();
		var a = draft.aura;
		draft.condition = choice.condition.clone();
		a.rule = new AuraRuleDef();
		a.rule.conditions.push(draft.condition);
		a.name = label + " - " + choice.title;
		a.syncNameBuf();
		a.announce = label; a.syncAnnounceBuf();
		a.bannerText = label; a.syncBannerBuf();
		a.showLabel.set(true);
		if (choice.preset == "enemy") {
			// Adopt the preset without setFace(), which would clear its independent banner.
			draft.face = "Icon";
			draft.behavior = AuraEffect.WHEN_ON_RISE_HOLD;
			draft.setHold(2.5);
		} else {
			draft.setFace(choice.preset == "damage" ? "Banner" : choice.preset == "timer" ? "Bar" : "Icon");
			if (choice.preset == "damage" || choice.preset == "flash") {
				draft.setHold(2.5);
				draft.setBehavior(AuraEffect.WHEN_ON_RISE_HOLD);
			}
			if (choice.preset == "timer") {
				a.timerMode = AuraTimer.MODE_DOWN; a.timerSource = AuraTimer.SRC_FOLLOW;
				a.showCountdown.set(true); a.showFuse.set(true);
			}
			if (choice.preset == "stacks") a.stackCounter.set(true);
		}
		// Combat-log intent supplies tracking and timing, not forced artwork.
		AuraPresentationDefaults.fresh(a);
		draft.face = "Icon";
		draft.configuredHold = a.duration;
		draft.briefHold = 1.5;
		return draft;
	}

	public function setFace(value:String):Void {
		if (["Icon", "Glow", "Bar", "Banner"].indexOf(value) < 0 || face == value) return;
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
		ref.set(!ref.get());
	}

	/** Copy a chosen numerical reference into this draft only. Artwork stays opt-in. */
	public function setTimerReference(choice:String, seconds:Float, label:String):Void {
		cooldownReference = choice == "Game time" ? "Game time" : choice == "Observed" ? "Observed" : "CDB";
		timerReferenceLabel = label;
		aura.timerSource = cooldownReference == "Game time" ? AuraTimer.SRC_FOLLOW : AuraTimer.SRC_FIXED;
		aura.followBuffDuration.set(aura.timerSource == AuraTimer.SRC_FOLLOW);
		aura.timerSeconds.set(Math.isFinite(seconds) && seconds > 0.001 && seconds <= 600 ? seconds : 0);
	}
	public function setTimerMode(mode:Int):Void {
		aura.timerMode = mode < 0 || mode > 2 ? AuraTimer.MODE_OFF : mode;
		aura.timerSource = AuraTimingReferencePolicy.isCooldown(condition.signal) && cooldownReference == "Game time" ? AuraTimer.SRC_FOLLOW : AuraTimer.SRC_FIXED;
		aura.followBuffDuration.set(aura.timerSource == AuraTimer.SRC_FOLLOW);
	}

	public function issue(hasIcon:String->Bool):String {
		if (StringTools.trim(aura.name).length == 0) return "Give this aura a name.";
		var problem = AuraQuickBuildRules.conditionIssue(condition);
		if (problem.length > 0) return problem;
		if (aura.timerMode != AuraTimer.MODE_OFF && aura.timerSource == AuraTimer.SRC_FIXED && !(Math.isFinite(aura.timerSeconds.get()) && aura.timerSeconds.get() > 0.001))
			return "Timer duration is unavailable. Turn the timer off or enter an aura-only duration in Advanced.";
		if (aura.showIcon.get() && (face == "Icon" || face == "Glow") && !hasIcon(aura.preferredIconId())) return "Choose a usable icon.";
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
		var timer = aura.timerMode == AuraTimer.MODE_OFF ? "" : AuraTimingReferencePolicy.isCooldown(condition.signal)
			? " Follows the skill's live cooldown after use." + (aura.timerSource == AuraTimer.SRC_FIXED ? " Uses the selected seconds only when live timing is unavailable." : "") : aura.timerSeconds.get() > 0
			? " Starts a " + aura.timerSeconds.get() + "s " + (aura.timerMode == AuraTimer.MODE_DOWN ? "countdown" : "countup") + " when conditions become true."
			: " Timer duration is unavailable.";
		return result + (overlays.length > 0 ? ", with " + overlays.join(", ") : "") + "." + timer
			+ (face != "Banner" && !aura.chrome.locked.get() ? " The unlocked HUD face also stays visible for placement." : "");
	}
}
