package solarflare.aura.signal;

class AuraSignalReader {
	public static function read(frame:AuraSignalFrame, signal:String, subject:String, out:AuraResolvedValue):Void {
		out.reset();
		var d = AuraSignalCatalog.find(signal);
		if (d == null) { out.code = UNKNOWN_SIGNAL; return; }
		out.kind = d.kind;
		if (d.subjectKind.length > 0 && (subject == null || subject.length == 0)) { out.code = MISSING_SUBJECT; return; }
		if (StringTools.startsWith(signal,"event.skill.") || StringTools.startsWith(signal,"event.status.") || StringTools.startsWith(signal,"event.dash.")) {
			if(StringTools.startsWith(signal,"event.skill.")) { var sk=frame.findSkill(subject); if(sk!=null) subject=sk.rawId; }
			if(StringTools.startsWith(signal,"event.status.")) subject=solarflare.cdb.CdbAuraTable.statusSubjectId(subject);
			var e=frame.events.get(AuraChangeTracker.eventKey(signal,subject));
			duration(out,e!=null && e.known,e==null ? 1e9 : e.age);
			out.timeLeft=Math.NaN; out.eventSerial=e==null ? 0 : e.serial; return;
		}
		if (StringTools.startsWith(signal, "consumable.")) { ConsumableSignalReader.read(frame, signal, subject, out); return; }
		if (solarflare.aura.StatusTypeDemand.isTypeSignal(signal)) {
			var bit=solarflare.cdb.StatusTypeCatalog.bit(subject);
			if(bit==0) { out.code=MISSING_SUBJECT; return; }
			var enemy=signal=="target.statusType.present";
			var known=enemy ? frame.enemyStatusTypeKnown : frame.myStatusTypeKnown;
			var present=enemy ? frame.enemyStatusTypePresent : frame.myStatusTypePresent;
			out.known=(known&bit)!=0; out.boolValue=out.present=(present&bit)!=0;
			out.code=out.known ? OK : UNKNOWN_DOMAIN;
			return;
		}
		if (StringTools.startsWith(signal,"target.status.")) { AuraStatusSignalReader.read(frame,signal,subject,out); return; }
		switch (signal) {
			case "resource.mana.current": number(out,frame.manaKnown,frame.manaCurrent);
			case "resource.rage.current": number(out,frame.rageKnown,frame.rageCurrent);
			case "resource.spark.current": number(out,frame.sparkKnown,frame.sparkCurrent);
			case "resource.shield.current": number(out,frame.healthKnown,frame.shieldCurrent);
			case "player.alive": bool(out,frame.aliveKnown,frame.alive);
			case "dash.charges": count(out,frame.dashKnown,frame.dashCharges); out.progress=frame.dashRechargeProgress; out.timeLeft=frame.dashKnown ? frame.dashRecharge : Math.NaN;
			case "dash.available": bool(out,frame.dashKnown,frame.dashCharges>0); out.progress=frame.dashRechargeProgress; out.timeLeft=frame.dashKnown ? frame.dashRecharge : Math.NaN;
			case "dash.full": bool(out,frame.dashKnown,frame.dashMax>0 && frame.dashCharges>=frame.dashMax); out.progress=frame.dashRechargeProgress; out.timeLeft=frame.dashKnown ? frame.dashRecharge : Math.NaN;
			case "dash.rechargeLeft": duration(out,frame.dashKnown,frame.dashRecharge); out.progress=frame.dashRechargeProgress; out.timeLeft=frame.dashKnown ? frame.dashRecharge : Math.NaN;
			case "target.distance": number(out,frame.targetKnown && frame.targetValid,frame.targetDistance);
			case "combat.damageTakenAge":
				duration(out,frame.heroKnown && frame.damageAgeKnown,frame.damageTakenAge); out.timeLeft=Math.NaN;
			case "event.combat.critical", "event.combat.block":
				var critical=signal=="event.combat.critical";
				duration(out,frame.heroKnown,critical ? frame.critAge : frame.blockAge);
				out.timeLeft=Math.NaN; out.eventSerial=critical ? frame.critSerial : frame.blockSerial;
			case "equipment.weaponEquipped":
				var weapon = frame.findWeapon(subject);
				bool(out, weapon != null && weapon.known, weapon != null && weapon.equipped);
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
			case "encounter.inBossFight": bool(out, frame.encounterKnown, frame.inBossFight);
			case "encounter.riftRemain": duration(out, frame.encounterKnown, frame.riftRemain);
			case "target.valid": bool(out, frame.targetKnown, frame.targetValid);
			case "target.kindMatches": bool(out, frame.targetKnown, frame.targetValid && kindEq(frame.targetKind, subject));
			case "target.isBoss": bool(out, frame.targetKnown && frame.targetValid, frame.targetIsBoss || frame.targetIsMiniboss);
			case "target.isElite": bool(out, frame.targetKnown && frame.targetValid, frame.targetIsElite);
			case "target.hpRatio": percent(out, frame.targetKnown && frame.targetValid, frame.targetRatio);
			case "combat.killKindMatches": bool(out, frame.killKnown, kindEq(frame.killKind, subject));
			case "combat.damageTakenRecent": number(out, frame.damageTakenKnown, frame.damageTakenRecent);
			case "combat.inCombat": bool(out, frame.combatKnown, frame.inCombat);
			case "aura.active": bool(out, frame.auraShowing.exists(subject), frame.auraShowing.get(subject) == true);
			case "aura.condition": auraCondition(frame, subject, out);
			case "event.combat.entered":
				duration(out, frame.combatKnown, frame.combatEnteredAge);
				out.timeLeft = Math.NaN; // elapsed, never buff remaining
				out.eventSerial = frame.combatEnteredSerial;
			case "event.combat.left":
				duration(out, frame.combatKnown, frame.combatLeftAge);
				out.timeLeft = Math.NaN;
				out.eventSerial = frame.combatLeftSerial;
			case "event.cast.recent", "event.cast.active": readCast(frame, signal, subject, out);
			case "event.playerCast.recent":
				var key = solarflare.geaux.GeauxCache.sanitizeSkillId(subject).toLowerCase();
				duration(out, frame.heroKnown, 1e9);
				out.timeLeft = Math.NaN; // Cast age is elapsed, never buff remaining.
				for (i in 0...frame.playerCastCount) {
					var c = frame.playerCasts[i];
					if (c.skillId == key) {
						duration(out, c.known, c.age);
						out.timeLeft = Math.NaN;
						out.eventSerial = c.serial;
						break;
					}
				}
			case "custom.script":
				var r=solarflare.scripting.ScriptEngine.evaluate(subject,frame);
				bool(out,r.known,r.value);
				out.eventSerial=r.eventSerial;
				if(!r.known) out.code=r.state=="Waiting for data" ? UNKNOWN_DOMAIN : INVALID_RULE;
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
			case "skill.ready": bool(out, s.cooldownKnown, s.ready);
			case "skill.affordable": bool(out, true, s.affordable);
			case "skill.inCooldown": bool(out, s.cooldownKnown, s.inCooldown);
			case "skill.cooldownLeft": duration(out, s.cooldownKnown, s.cooldownLeft, s.cooldownProgress);
			case "skill.cooldownProgress": percent(out, s.cooldownKnown, s.cooldownProgress, s.cooldownLeft);
			case "skill.instantReady": bool(out, s.instantReadyKnown, s.instantReady);
			case "skill.specialReady": bool(out, s.specialReadyKnown, s.specialReady);
			case "skill.charges": count(out, s.chargesMax > 0, s.charges);
			case "skill.chargesMax": count(out, s.chargesMax > 0, s.chargesMax);
			default:
		}
		// Timing is presentation metadata even when ready/affordable evaluates false.
		// Proc readiness has a different lifecycle and must keep its condition timer.
		if (solarflare.aura.AuraTimingReferencePolicy.isCooldown(signal) && s.cooldownKnown) {
			out.timeLeft = s.cooldownLeft;
			out.progress = s.cooldownProgress;
		}
	}
	static function readCast(frame:AuraSignalFrame, signal:String, subject:String, out:AuraResolvedValue):Void {
		var c = frame.findCast(subject);
		if (c == null || !c.known) {
			if (!frame.castDomainKnown) { out.code = UNKNOWN_DOMAIN; return; }
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
	/** Subject "auraId#n" (n counts from 1, as the editor lists conditions). Unknown until that condition has a known answer. */
	public static function splitConditionSubject(subject:String):{id:String, index:Int} {
		var at = subject == null ? -1 : subject.lastIndexOf("#");
		if (at <= 0) return null;
		var n = Std.parseInt(subject.substr(at + 1));
		return n == null || n < 1 ? null : {id: subject.substr(0, at), index: n - 1};
	}

	static function auraCondition(frame:AuraSignalFrame, subject:String, out:AuraResolvedValue):Void {
		var ref = splitConditionSubject(subject);
		if (ref == null) { out.code = MISSING_SUBJECT; return; }
		var r = frame.auraRules.get(ref.id);
		var c = r != null && ref.index < r.totalCount && ref.index < r.conditions.length ? r.conditions[ref.index] : null;
		bool(out, c != null && c.known, c != null && c.hit);
	}

	static function bool(o:AuraResolvedValue, known:Bool, v:Bool):Void { o.kind = Boolean; o.known = known; o.boolValue = v; o.present = v; o.code = known ? OK : UNKNOWN_DOMAIN; }
	static function setNumber(o:AuraResolvedValue, known:Bool, v:Float):Void { o.known = known && Math.isFinite(v); o.numberValue = v; o.code = o.known ? OK : (known ? NON_FINITE : UNKNOWN_DOMAIN); }
}
