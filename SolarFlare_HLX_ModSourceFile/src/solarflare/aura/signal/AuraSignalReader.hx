package solarflare.aura.signal;

class AuraSignalReader {
	public static function read(frame:AuraSignalFrame, signal:String, subject:String, out:AuraResolvedValue):Void {
		out.reset();
		var d = AuraSignalCatalog.find(signal);
		if (d == null) { out.code = UNKNOWN_SIGNAL; return; }
		out.kind = d.kind;
		if (d.subjectKind.length > 0 && (subject == null || subject.length == 0)) { out.code = MISSING_SUBJECT; return; }
		switch (signal) {
			case "resource.health.current": number(out, frame.healthKnown, frame.healthCurrent);
			case "resource.health.ratio": percent(out, frame.healthKnown, frame.healthRatio);
			case "resource.shield.ratio": percent(out, frame.healthKnown, frame.shieldRatio);
			case "resource.rage.ratio": percent(out, frame.rageKnown, frame.rageRatio);
			case "resource.mana.ratio": percent(out, frame.manaKnown, frame.manaRatio);
			case "resource.spark.ratio": percent(out, frame.sparkKnown, frame.sparkRatio);
			case "resource.generic.ratio": percent(out, frame.genericKnown, frame.genericRatio);
			case "resource.combo.count": count(out, frame.comboKnown, frame.comboCount, frame.comboMax > 0 ? frame.comboCount / frame.comboMax : 0);
			case "resource.combo.atMax": bool(out, frame.comboKnown, frame.comboMax > 0 && frame.comboCount >= frame.comboMax);
			case "skill.ready", "skill.affordable", "skill.inCooldown", "skill.cooldownLeft", "skill.cooldownProgress", "skill.instantReady", "skill.specialReady", "skill.charges", "skill.chargesMax": readSkill(frame, signal, subject, out);
			case "status.count", "status.overflow", "status.present", "status.stacks", "status.durationLeft", "status.durationProgress": AuraStatusSignalReader.read(frame, signal, subject, out);
			case "prayer.charged": count(out, frame.prayerKnown, frame.prayerCharged);
			case "prayer.lifeReady": bool(out, frame.prayerKnown, frame.prayerLifeReady);
			case "prayer.shieldReady": bool(out, frame.prayerKnown, frame.prayerShieldReady);
			case "prayer.smiteReady": bool(out, frame.prayerKnown, frame.prayerSmiteReady);
			case "chaincast.stacks": count(out, frame.chaincastKnown, frame.chaincastStacks);
			case "chaincast.ready": bool(out, frame.chaincastKnown, frame.chaincastReady);
			case "chaincast.remaining": duration(out, frame.chaincastKnown, frame.chaincastRemaining, frame.chaincastProgress);
			case "conduit.filledCount": count(out, frame.conduitKnown, frame.conduitFilled);
			case "conduit.powerStacks": count(out, frame.conduitKnown, frame.conduitPowerStacks);
			case "conduit.effectiveStacks": count(out, frame.conduitKnown, frame.conduitPowerStacks > 0 ? frame.conduitPowerStacks : frame.conduitFilled);
			case "conduit.powerLeft": duration(out, frame.conduitKnown, frame.conduitPowerLeft);
			case "attackCombo.step": count(out, frame.attackComboKnown, frame.attackComboStep);
			case "attackCombo.withinChain": bool(out, frame.attackComboKnown, frame.attackComboWithin);
			case "attackCombo.finalFlash": bool(out, frame.attackComboKnown, frame.attackComboFinal);
			case "encounter.inRift": bool(out, frame.encounterKnown, frame.inRift);
			case "target.valid": bool(out, frame.targetKnown, frame.targetValid);
			case "target.kindMatches": bool(out, frame.targetKnown, frame.targetValid && kindEq(frame.targetKind, subject));
			case "target.isBoss": bool(out, frame.targetKnown && frame.targetValid, frame.targetIsBoss || frame.targetIsMiniboss);
			case "target.isElite": bool(out, frame.targetKnown && frame.targetValid, frame.targetIsElite);
			case "target.hpRatio": percent(out, frame.targetKnown && frame.targetValid, frame.targetRatio);
			case "combat.killKindMatches": bool(out, frame.killKnown, kindEq(frame.killKind, subject));
			case "combat.damageTakenRecent": number(out, frame.damageTakenKnown, frame.damageTakenRecent);
			case "event.cast.recent", "event.cast.active": readCast(frame, signal, subject, out);
			case "custom.script": bool(out, true, solarflare.scripting.ScriptEngine.evalBool(subject, frame));
			default: out.code = UNKNOWN_SIGNAL;
		}
	}
	static function kindEq(a:String, b:String):Bool {
		if (a == null || b == null || a.length == 0 || b.length == 0)
			return false;
		var sa = solarflare.geaux.GeauxCache.sanitizeSkillId(a);
		var sb = solarflare.geaux.GeauxCache.sanitizeSkillId(b);
		if (sa.length == 0 || sb.length == 0)
			return false;
		return sa.toLowerCase() == sb.toLowerCase();
	}
	static function readSkill(frame:AuraSignalFrame, signal:String, subject:String, out:AuraResolvedValue):Void {
		var s = frame.findSkill(subject); if (s == null || !s.known) { out.code = MISSING_SUBJECT; return; }
		switch (signal) {
			case "skill.ready": bool(out, true, s.ready);
			case "skill.affordable": bool(out, true, s.affordable);
			case "skill.inCooldown": bool(out, true, s.inCooldown);
			case "skill.cooldownLeft": duration(out, true, s.cooldownLeft, s.cooldownProgress);
			case "skill.cooldownProgress": percent(out, true, s.cooldownProgress, s.cooldownLeft);
			case "skill.instantReady": bool(out, s.instantReadyKnown, s.instantReady);
			case "skill.specialReady": bool(out, s.specialReadyKnown, s.specialReady);
			case "skill.charges": count(out, s.chargesMax > 0, s.charges);
			case "skill.chargesMax": count(out, s.chargesMax > 0, s.chargesMax);
			default:
		}
	}
	static function readCast(frame:AuraSignalFrame, signal:String, subject:String, out:AuraResolvedValue):Void {
		var c = frame.findCast(subject);
		if (c == null || !c.known) {
			if (signal == "event.cast.active") {
				bool(out, true, false);
				return;
			}
			// No cast yet: known miss for within (age larger than any window).
			duration(out, true, 1e9);
			return;
		}
		switch (signal) {
			case "event.cast.recent": duration(out, true, c.age);
			case "event.cast.active": bool(out, true, c.active);
			default:
		}
	}
	static function number(o:AuraResolvedValue, known:Bool, v:Float):Void { o.kind = Number; setNumber(o, known, v); }
	static function percent(o:AuraResolvedValue, known:Bool, v:Float, left:Float = -1):Void { o.kind = Percent; setNumber(o, known, v); o.progress = v; o.timeLeft = left >= 0 ? left : Math.NaN; }
	static function duration(o:AuraResolvedValue, known:Bool, v:Float, prog:Float = -1):Void { o.kind = Duration; setNumber(o, known, v); o.timeLeft = v; o.progress = prog >= 0 ? prog : Math.NaN; }
	static function count(o:AuraResolvedValue, known:Bool, v:Int, prog:Float = -1):Void { o.kind = Count; o.known = known; o.intValue = v; o.numberValue = v; o.progress = prog >= 0 ? prog : Math.NaN; o.code = known ? OK : UNKNOWN_DOMAIN; }
	static function bool(o:AuraResolvedValue, known:Bool, v:Bool):Void { o.kind = Boolean; o.known = known; o.boolValue = v; o.present = v; o.code = known ? OK : UNKNOWN_DOMAIN; }
	static function setNumber(o:AuraResolvedValue, known:Bool, v:Float):Void { o.known = known && Math.isFinite(v); o.numberValue = v; o.code = o.known ? OK : (known ? NON_FINITE : UNKNOWN_DOMAIN); }
}
