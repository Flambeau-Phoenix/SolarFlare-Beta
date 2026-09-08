package solarflare.combatlog;

import solarflare.HealthCache;
import solarflare.FieldWalk;
import solarflare.geaux.GeauxCache;
import solarflare.target.TargetSnap;
import solarflare.target.RecentTargetCache;
import solarflare.ui.GameIcons;

/**
 * Ring of combat events. Hooks write snapshots; draw never walks engine objects.
 * Also freezes the local hero's current target into TargetSnap each tick.
 */
class CombatLogCache {
	public static inline var KIND_CAST:Int = 0;
	public static inline var KIND_HIT:Int = 1;

	public static inline var ROLE_UNKNOWN:Int = 0;
	public static inline var ROLE_YOU:Int = 1;
	public static inline var ROLE_PLAYER:Int = 2;
	public static inline var ROLE_ENEMY:Int = 3;

	static inline var CAP:Int = 200;
	static inline var DEDUPE_S:Float = 0.05;

	static var lines:Array<CombatLogLine> = [];
	static var writeAt:Int = 0;
	static var count:Int = 0;
	static var currentTarget:Dynamic = null;
	static var lastTargetRef:Dynamic = null;
	static var targetSnap:TargetSnap = new TargetSnap();
	static var targetSnapOut:TargetSnap = new TargetSnap();
	/** One-shot kill victim kind for aura frame (cleared on consume). */
	static var pendingKillKind:String = "";

	/** Frozen target for HUD/aura consumers. Draw-safe copy. */
	public static function currentTargetSnap():TargetSnap {
		targetSnapOut.copyFrom(targetSnap);
		return targetSnapOut;
	}

	/** Consume pending kill kind pulse (empty if none since last consume). */
	public static function consumeKillKind():String {
		var k = pendingKillKind;
		pendingKillKind = "";
		return k != null ? k : "";
	}

	/**
	 * Resolve current target pointer. Identity/classification only on pointer change;
	 * HP at ObserveDemand target cadence while the Target HUD is shown.
	 */
	public static function tick(localHero:Dynamic):Void {
		currentTarget = null;
		if (localHero == null) {
			if (lastTargetRef != null) {
				lastTargetRef = null;
				targetSnap.clear();
			}
			return;
		}
		try {
			var hero:ent.Hero = cast localHero;
			var t = hero.getTarget();
			if (t != null)
				currentTarget = t;
		} catch (_:Dynamic) {}
		if (currentTarget == null) {
			try {
				var unit:ent.Unit = cast localHero;
				currentTarget = unit.get_targetUnit();
			} catch (_:Dynamic) {}
		}
		if (currentTarget == null)
			currentTarget = extractObject(localHero, "targetUnit");
		if (solarflare.debug.ResolutionLedger.armed() && currentTarget != null)
			solarflare.debug.ResolutionLedger.touch("combat.target", "typed", "CombatLogCache.tick", "getTarget", "string", "obj");

		// Combat-log-only: keep pointer for involvesCurrentTarget; skip HUD snap work.
		if (!solarflare.ObserveDemand.targetHud) {
			if (currentTarget != lastTargetRef)
				lastTargetRef = currentTarget;
			return;
		}

		var ptrChanged = currentTarget != lastTargetRef || solarflare.ObserveDemand.targetPtrDirty;
		solarflare.ObserveDemand.targetPtrDirty = false;
		lastTargetRef = currentTarget;
		if (currentTarget == null) {
			targetSnap.clear();
			return;
		}
		if (ptrChanged)
			fillTargetIdentity(currentTarget);
		var now = haxe.Timer.stamp();
		if (ptrChanged || solarflare.ObserveDemand.dueTargetHp(now))
			fillTargetHp(currentTarget);
	}

	static function fillTargetIdentity(unit:Dynamic):Void {
		if (unit == null)
			return;
		targetSnap.valid = true;
		targetSnap.name = unitName(unit);
		targetSnap.kind = unitKindId(unit);
		targetSnap.role = classify(unit);
		targetSnap.observedAt = haxe.Timer.stamp();
		targetSnap.isBoss = false;
		targetSnap.isMiniboss = false;
		targetSnap.isElite = false;
		try {
			var u:ent.Unit = cast unit;
			if (u != null) {
				try
					targetSnap.isBoss = u.isBoss()
				catch (_:Dynamic) {}
				try
					targetSnap.isMiniboss = u.isMiniboss()
				catch (_:Dynamic) {}
				try
					targetSnap.isElite = u.isElite()
				catch (_:Dynamic) {}
			}
		} catch (_:Dynamic) {}
		if (targetSnap.kind.length > 0) {
			GameIcons.preload(targetSnap.kind);
			RecentTargetCache.note(targetSnap.kind, targetSnap.name);
		}
	}

	static function fillTargetHp(unit:Dynamic):Void {
		if (unit == null)
			return;
		var hp = unitHealth(unit);
		if (hp.max <= 0 && hp.cur <= 0) {
			if (!targetSnap.valid)
				return;
			targetSnap.health = 0;
			targetSnap.maxHealth = 0;
			targetSnap.ratio = 0;
			return;
		}
		targetSnap.valid = true;
		targetSnap.health = hp.cur;
		targetSnap.maxHealth = hp.max;
		targetSnap.ratio = hp.max > 0 ? hp.cur / hp.max : 0;
		if (targetSnap.ratio < 0)
			targetSnap.ratio = 0;
		else if (targetSnap.ratio > 1)
			targetSnap.ratio = 1;
		targetSnap.observedAt = haxe.Timer.stamp();
		if (solarflare.debug.ResolutionLedger.armed()) {
			solarflare.debug.ResolutionLedger.note("combat.target.hp")
				.withMethod("typed")
				.withSrc("CombatLogCache.fillTargetHp")
				.withName("get_health")
				.withPayload("ent.Unit", "currentTarget")
				.num(hp.cur)
				.emit();
		}
	}

	/** Unit kind basename for GameIcons `{kind}.png` / atlas frame. */
	static function unitKindId(unit:Dynamic):String {
		if (unit == null)
			return "";
		try {
			var u:ent.Unit = cast unit;
			if (u != null) {
				var k = GeauxCache.sanitizeSkillId(u.kind);
				if (k.length > 0)
					return k;
				try {
					if (u.inf != null) {
						k = GeauxCache.sanitizeSkillId(u.inf.id);
						if (k.length > 0)
							return k;
					}
				} catch (_:Dynamic) {}
			}
		} catch (_:Dynamic) {}
		var fromField = GeauxCache.sanitizeSkillId(cleanString(extractObject(unit, "kind")));
		if (fromField.length > 0)
			return fromField;
		var inf = extractObject(unit, "inf");
		return GeauxCache.sanitizeSkillId(cleanString(extractObject(inf, "id")));
	}

	public static function noteCast(skill:Dynamic):Void {
		if (skill == null)
			return;
		try
			solarflare.debug.PayloadProbe.capture("cast", skill)
		catch (_:Dynamic) {}
		try {
			var bs:st.skill.BaseSkill = skill;
			if (bs.isPassive())
				return;
		} catch (_:Dynamic) {}
		var owner = ownerOfSkill(skill);
		var aim = aimOfSkill(skill);
		if (!shouldCapture(owner, aim))
			return;
		var sid = skillIdOf(skill);
		pushCast(sid, owner, aim);
		if (solarflare.debug.ResolutionLedger.armed())
			solarflare.debug.ResolutionLedger.note("combat.cast.skillId")
				.withMethod("engine")
				.withSrc("CombatLogCache.noteCast")
				.withName("skill")
				.withHook("st.skill.BaseSkill.doStart")
				.withPayload("st.skill.BaseSkill", "hook.skill")
				.str(sid)
				.emit();
	}

	public static function noteHit(victim:Dynamic, dmg:Dynamic):Void {
		if (dmg == null)
			return;
		try
			solarflare.debug.PayloadProbe.capture("hit", dmg)
		catch (_:Dynamic) {}
		var source = sourceOfDamage(dmg);
		var target = targetOfDamage(dmg, victim);
		if (!shouldCapture(source, target))
			return;
		var skill = skillOfDamage(dmg);
		pushHit(skill, source, target, dmg);
	}

	public static function linesForDraw(cfg:CombatLogConfig):Array<CombatLogLine> {
		var out:Array<CombatLogLine> = [];
		if (cfg == null || cfg.hidden.get())
			return out;
		var n = count < CAP ? count : CAP;
		var start = count < CAP ? 0 : writeAt;
		var i = 0;
		while (i < n) {
			var idx = (start + i) % CAP;
			var line = lines[idx];
			if (line != null && cfg.passes(line))
				out.push(line);
			i++;
		}
		return out;
	}

	public static function recentAll():Array<CombatLogLine> {
		var out:Array<CombatLogLine> = [];
		var n = count < CAP ? count : CAP;
		var start = count < CAP ? 0 : writeAt;
		var i = 0;
		while (i < n) {
			var idx = (start + i) % CAP;
			var line = lines[idx];
			if (line != null)
				out.push(line);
			i++;
		}
		return out;
	}

	static function pushCast(skillId:String, source:Dynamic, target:Dynamic):Void {
		var line = beginLine(KIND_CAST, skillId, source, target, 0);
		if (isDupe(line.kind, line.skillId, line.sourceName, line.targetName, line.amount, line.t))
			return;
		commit(line);
	}

	static function pushHit(skillId:String, source:Dynamic, target:Dynamic, dmg:Dynamic):Void {
		var amount = extractNumber(dmg, "amount", 0);
		var line = beginLine(KIND_HIT, skillId, source, target, amount);
		fillDamage(line, dmg);
		if (isDupe(line.kind, line.skillId, line.sourceName, line.targetName, line.amount, line.t))
			return;
		if (line.kill)
			noteKillOf(target);
		commit(line);
	}

	static function noteKillOf(target:Dynamic):Void {
		var k = unitKindId(target);
		if (k.length > 0)
			pendingKillKind = k;
	}

	static function beginLine(kind:Int, skillId:String, source:Dynamic, target:Dynamic, amount:Float):CombatLogLine {
		var now = haxe.Timer.stamp();
		var srcName = unitName(source);
		var tgtName = unitName(target);
		var sid = skillId != null ? skillId : "";
		var shown = solarflare.EngineSkillId.display(sid);
		var line = new CombatLogLine();
		line.kind = kind;
		line.skillId = sid;
		line.skillName = shown.length > 0 ? shown : sid;
		line.skillLabel = line.skillName;
		line.sourceName = srcName;
		line.sourcePlayer = UniqueHeroName.of(source);
		line.targetName = tgtName;
		line.targetPlayer = UniqueHeroName.of(target);
		line.sourceRole = classify(source);
		line.targetRole = classify(target);
		line.amount = amount;
		line.involvesCurrentTarget = sameUnit(source, currentTarget) || sameUnit(target, currentTarget);
		line.heroInvolved = line.sourceRole == ROLE_YOU || line.sourceRole == ROLE_PLAYER
			|| line.targetRole == ROLE_YOU || line.targetRole == ROLE_PLAYER;
		line.t = now;
		try
			line.wallMs = Date.now().getTime()
		catch (_:Dynamic)
			line.wallMs = now * 1000;
		var hp = unitHealth(target);
		line.targetHp = hp.cur;
		line.targetMaxHp = hp.max;
		return line;
	}

	static function fillDamage(line:CombatLogLine, dmg:Dynamic):Void {
		try {
			var dr:st.skill.DamageResult = dmg;
			if (dr != null) {
				line.amount = dr.get_amount();
				line.blockAmt = dr.get_block();
				line.crit = dr.get_critical();
				line.kill = dr.get_kill();
				line.physical = dr.get_isPhysical();
				line.magic = dr.get_isMagic();
				line.auto = dr.get_isBaseAttack();
				var aff = dr.affinity;
				if (aff != null && isPlainName(aff))
					line.affinity = aff;
				if (solarflare.debug.ResolutionLedger.armed()) {
					solarflare.debug.ResolutionLedger.note("combat.hit.amount")
						.withMethod("typed")
						.withSrc("CombatLogCache.fillDamage")
						.withName("get_amount")
						.withHook("ent.Hero.onReceiveDamage")
						.withPayload("st.skill.DamageResult", "hook.dmgObj")
						.withArgs(["self", "dmgObj", "result"])
						.tryRoute("typed", "get_amount")
						.tryRoute("fieldwalk", "amount")
						.num(line.amount)
						.emit();
					solarflare.debug.ResolutionLedger.note("combat.hit.crit")
						.withMethod("typed")
						.withSrc("CombatLogCache.fillDamage")
						.withName("get_critical")
						.withPayload("st.skill.DamageResult", "hook.dmgObj")
						.bool(line.crit)
						.emit();
					solarflare.debug.ResolutionLedger.note("combat.hit.kill")
						.withMethod("typed")
						.withSrc("CombatLogCache.fillDamage")
						.withName("get_kill")
						.withPayload("st.skill.DamageResult", "hook.dmgObj")
						.bool(line.kill)
						.emit();
				}
			}
		} catch (_:Dynamic) {}
		if (line.amount == 0) {
			line.amount = extractNumber(dmg, "amount", 0);
			if (solarflare.debug.ResolutionLedger.armed() && line.amount != 0)
				solarflare.debug.ResolutionLedger.note("combat.hit.amount")
					.withMethod("fieldwalk")
					.withSrc("CombatLogCache.fillDamage")
					.withName("amount")
					.withPayload("st.skill.DamageResult", "hook.dmgObj")
					.tryRoute("typed", "get_amount")
					.tryRoute("fieldwalk", "amount")
					.num(line.amount)
					.emit();
		}
		if (line.blockAmt == 0)
			line.blockAmt = extractNumber(dmg, "block", 0);
		if (!line.crit)
			line.crit = extractBool(dmg, "critical", false);
		if (!line.kill)
			line.kill = extractBool(dmg, "kill", false);
		line.blocked = line.blockAmt > 0 || extractBool(dmg, "blocked", false);
		if (line.affinity.length == 0)
			line.affinity = cleanString(extractObject(dmg, "affinity"));
	}

	static function commit(line:CombatLogLine):Void {
		if (lines.length < CAP) {
			lines.push(line);
			writeAt = lines.length % CAP;
			count++;
		} else {
			lines[writeAt] = line;
			writeAt = (writeAt + 1) % CAP;
			if (count < CAP)
				count++;
		}
		try
			CombatLogRecorder.queue(line)
		catch (_:Dynamic) {}
	}

	static function isDupe(kind:Int, skillId:String, src:String, tgt:String, amount:Float, now:Float):Bool {
		if (count <= 0)
			return false;
		var lastIdx = count < CAP ? count - 1 : (writeAt + CAP - 1) % CAP;
		var last = lines[lastIdx];
		if (last == null)
			return false;
		if (now - last.t > DEDUPE_S)
			return false;
		return last.kind == kind && last.skillId == skillId && last.sourceName == src && last.targetName == tgt
			&& Math.abs(last.amount - amount) < 0.01;
	}

	static function shouldCapture(a:Dynamic, b:Dynamic):Bool {
		if (HealthCache.isLocalHero(a) || HealthCache.isLocalHero(b))
			return true;
		if (sameUnit(a, currentTarget) || sameUnit(b, currentTarget))
			return true;
		var me = HealthCache.localHero;
		if (me == null)
			return false;
		return inCombatWithLocal(a, me) || inCombatWithLocal(b, me);
	}

	static function inCombatWithLocal(unit:Dynamic, me:Dynamic):Bool {
		if (unit == null)
			return false;
		try {
			var u:ent.Unit = cast unit;
			var local:ent.Unit = cast me;
			return u.inCombatWith(local);
		} catch (_:Dynamic) {
			return false;
		}
	}

	static function classify(unit:Dynamic):Int {
		if (unit == null)
			return ROLE_UNKNOWN;
		if (HealthCache.isLocalHero(unit))
			return ROLE_YOU;
		try {
			var hero:ent.Hero = cast unit;
			if (hero.getPlayer() != null)
				return ROLE_PLAYER;
		} catch (_:Dynamic) {}
		if (extractObject(unit, "player") != null)
			return ROLE_PLAYER;
		if (extractObject(unit, "foeState") != null)
			return ROLE_ENEMY;
		try {
			var foe:ent.Foe = cast unit;
			if (foe != null && extractObject(foe, "controller") != null)
				return ROLE_ENEMY;
		} catch (_:Dynamic) {}
		return ROLE_UNKNOWN;
	}

	static function unitName(unit:Dynamic):String {
		if (unit == null)
			return "";
		try {
			var u:ent.Unit = cast unit;
			var n = u.getName();
			if (n != null && n.length > 0 && GeauxCache.sanitizeSkillId(n).length > 0)
				return n;
			if (n != null && n.length > 0 && isPlainName(n))
				return n;
		} catch (_:Dynamic) {}
		var name = cleanString(extractObject(unit, "name"));
		if (name.length > 0)
			return name;
		var kind = cleanString(extractObject(unit, "kind"));
		if (kind.length > 0)
			return kind;
		return "";
	}

	static function isPlainName(s:String):Bool {
		if (s == null || s.length == 0)
			return false;
		var low = s.toLowerCase();
		return low.indexOf("bytes") < 0 && low.indexOf("{") < 0;
	}

	static function cleanString(v:Dynamic):String {
		if (v == null)
			return "";
		try {
			if (Std.isOfType(v, String)) {
				var s:String = v;
				if (s != null && isPlainName(s))
					return s;
			}
		} catch (_:Dynamic) {}
		return "";
	}

	static function skillLabel(id:String):String {
		return solarflare.EngineSkillId.display(id);
	}

	static function skillIdOf(skill:Dynamic):String {
		var id = GeauxCache.getSkillId(skill);
		if (id.length > 0)
			return id;
		return GeauxCache.sanitizeSkillId(cleanString(extractObject(skill, "kind")));
	}

	static function skillOfDamage(dmg:Dynamic):String {
		var base = extractObject(dmg, "baseSkill");
		var id = skillIdOf(base);
		if (id.length > 0)
			return id;
		id = skillIdOf(dmg);
		if (id.length > 0)
			return id;
		var ctx = extractObject(dmg, "ctx");
		id = skillIdOf(extractObject(ctx, "baseSkill"));
		if (id.length > 0)
			return id;
		return "";
	}

	static function unitHealth(unit:Dynamic):{cur:Float, max:Float} {
		var cur = 0.0;
		var max = 0.0;
		if (unit == null)
			return {cur: cur, max: max};
		try {
			var u:ent.Unit = cast unit;
			if (u != null) {
				cur = u.get_health();
				max = u.get_maxHealth();
				if (cur > 0 || max > 0)
					return {cur: cur, max: max};
			}
		} catch (_:Dynamic) {}
		cur = extractNumber(unit, "health", 0);
		max = extractNumber(unit, "maxHealth", 0);
		return {cur: cur, max: max};
	}

	static function ownerOfSkill(skill:Dynamic):Dynamic {
		try {
			var bs:st.skill.BaseSkill = skill;
			var u = bs.get_ownerUnit();
			if (u != null)
				return u;
			var h = bs.get_ownerHero();
			if (h != null)
				return h;
			var f = bs.get_ownerFoe();
			if (f != null)
				return f;
		} catch (_:Dynamic) {}
		var owner = extractObject(skill, "owner");
		if (owner != null)
			return owner;
		var parent = extractObject(skill, "parent");
		return extractObject(parent, "owner");
	}

	static function aimOfSkill(skill:Dynamic):Dynamic {
		try {
			var bs:st.skill.BaseSkill = skill;
			var aim = bs.get_aimTarget();
			if (aim != null)
				return aim;
		} catch (_:Dynamic) {}
		var ctx = extractObject(skill, "curCtx");
		if (ctx == null)
			ctx = extractObject(skill, "ctx");
		var aim2 = extractObject(ctx, "aimTarget");
		if (aim2 != null)
			return aim2;
		return extractObject(skill, "aimTarget");
	}

	static function sourceOfDamage(dmg:Dynamic):Dynamic {
		var src = extractObject(dmg, "serverSource");
		if (src != null)
			return src;
		try {
			var dr:st.skill.DamageResult = dmg;
			src = dr.get_sourceUnit();
			if (src != null)
				return src;
		} catch (_:Dynamic) {}
		return extractObject(dmg, "source");
	}

	static function targetOfDamage(dmg:Dynamic, victim:Dynamic):Dynamic {
		var t = extractObject(dmg, "target");
		if (t != null)
			return t;
		if (victim != null)
			return victim;
		try {
			var dr:st.skill.DamageResult = dmg;
			return dr.get_targetUnit();
		} catch (_:Dynamic) {
			return null;
		}
	}

	static function sameUnit(a:Dynamic, b:Dynamic):Bool {
		if (a == null || b == null)
			return false;
		return (cast a : Dynamic) == (cast b : Dynamic);
	}

	static function extractObject(obj:Dynamic, propertyName:String):Dynamic {
		return FieldWalk.extractObject(obj, propertyName);
	}

	static function extractNumber(obj:Dynamic, propertyName:String, fallback:Float = 0.0):Float {
		return FieldWalk.extractNumber(obj, propertyName, fallback);
	}

	static function extractBool(obj:Dynamic, propertyName:String, fallback:Bool = false):Bool {
		return FieldWalk.extractBool(obj, propertyName, fallback);
	}
}
