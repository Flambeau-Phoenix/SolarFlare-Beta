package solarflare.combatlog;

import solarflare.HealthCache;
import solarflare.FieldWalk;
import solarflare.cdb.CdbUnitNames;
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
	static inline var DEDUPE_S:Float = 0.08;

	static var lines:Array<CombatLogLine> = [];
	static var writeAt:Int = 0;
	static var count:Int = 0;
	public static var latestSequence(default, null):Float = 0;
	static var currentTarget:Dynamic = null;
	static var lastTargetRef:Dynamic = null;
	static var targetSnap:TargetSnap = new TargetSnap();
	static var targetSnapOut:TargetSnap = new TargetSnap();
	static var drawLinesBuf:Array<CombatLogLine> = [];
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
	 * Max hit amount on the local hero within the last `windowSec` seconds.
	 * Used by combat.damageTakenRecent aura signal.
	 */
	public static function maxDamageTakenRecent(windowSec:Float):Float {
		if (windowSec < 0.05)
			windowSec = 0.05;
		var now = haxe.Timer.stamp();
		var best:Float = 0;
		var n = count < CAP ? count : CAP;
		var i = 0;
		while (i < n) {
			var idx = count < CAP ? i : (writeAt + i) % CAP;
			var line = lines[idx];
			i++;
			if (line == null || line.kind != KIND_HIT)
				continue;
			if (line.targetRole != ROLE_YOU)
				continue;
			if (now - line.t > windowSec)
				continue;
			if (line.amount > best)
				best = line.amount;
		}
		return best;
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

		// Combat-log-only: keep pointer for involvesCurrentTarget; skip HUD snap unless auras need target.
		if (!solarflare.ObserveDemand.targetHud && !solarflare.ObserveDemand.aurasNeedTarget
			&& !solarflare.ObserveDemand.auraBuilderOpen) {
			if (currentTarget != lastTargetRef)
				lastTargetRef = currentTarget;
			if (currentTarget == null)
				targetSnap.clear();
			return;
		}

		var ptrChanged = currentTarget != lastTargetRef || solarflare.ObserveDemand.targetPtrDirty;
		solarflare.ObserveDemand.targetPtrDirty = false;
		lastTargetRef = currentTarget;
		if (currentTarget == null) {
			lastTargetRef = null;
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
		var owner = CombatOwnership.resolve(ownerOfSkill(skill), extractObject, ownerOfSkill);
		var aim = aimOfSkill(skill);
		if (!shouldCapture(owner, aim))
			return;
		var sid = skillIdOf(skill);
		pushCast(sid, owner, aim);
		if (classify(owner) == ROLE_ENEMY)
			solarflare.aura.EnemyCastCache.noteStart(skill, sid);
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

	public static function noteHit(victim:Dynamic, dmg:Dynamic, hook:String = ""):Void {
		if (dmg == null)
			return;
		try
			solarflare.debug.PayloadProbe.capture("hit", dmg)
		catch (_:Dynamic) {}
		var rawSource = sourceCandidateOfDamage(dmg);
		var source = CombatOwnership.resolve(rawSource, extractObject, ownerOfSkill);
		var minion = minionNameOf(rawSource, source);
		var target = targetOfDamage(dmg, victim);
		if (!shouldCapture(source, target) && !shouldCapture(rawSource, target))
			return;
		var skill = skillOfDamage(dmg);
		pushHit(skill, source, minion, target, dmg, hook);
	}

	/**
	 * CheatSheet Phase 0 DPS path: `ent.Unit.onInflictDamage` — attacker is `self`.
	 * Credits owned summons (bee/imp/…) to summonOwner; dedupes against receive-side noteHit.
	 */
	public static function noteInflict(attacker:Dynamic, dmg:Dynamic):Void {
		if (attacker == null || dmg == null)
			return;
		try
			solarflare.debug.PayloadProbe.capture("hit", dmg)
		catch (_:Dynamic) {}
		var source = CombatOwnership.resolve(attacker, extractObject, ownerOfSkill);
		if (source == null)
			source = attacker;
		var minion = minionNameOf(attacker, source);
		var target = targetOfDamage(dmg, null);
		if (!shouldCapture(source, target) && !shouldCapture(attacker, target))
			return;
		var skill = skillOfDamage(dmg);
		pushHit(skill, source, minion, target, dmg, "ent.Unit.onInflictDamage");
	}

	public static function linesForDraw(cfg:CombatLogConfig):Array<CombatLogLine> {
		drawLinesBuf.resize(0);
		if (cfg == null || cfg.hidden.get())
			return drawLinesBuf;
		var n = count < CAP ? count : CAP;
		var start = count < CAP ? 0 : writeAt;
		var i = 0;
		while (i < n) {
			var idx = (start + i) % CAP;
			var line = lines[idx];
			if (line != null && cfg.passes(line))
				drawLinesBuf.push(line);
			i++;
		}
		return drawLinesBuf;
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

	static function pushHit(skillId:String, source:Dynamic, minion:String, target:Dynamic, dmg:Dynamic, hook:String = ""):Void {
		var amount = extractNumber(dmg, "amount", 0);
		var line = beginLine(KIND_HIT, skillId, source, target, amount);
		line.minionName = minion;
		fillDamage(line, dmg, hook);
		// Dedupe inflict vs receive paths within DEDUPE_S (same skill/src/tgt/amount).
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
		line.inProximity = line.sourceRole == ROLE_YOU || line.targetRole == ROLE_YOU
			|| nearLocal(source) || nearLocal(target);
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

	static function fillDamage(line:CombatLogLine, dmg:Dynamic, hook:String = ""):Void {
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
					var note = solarflare.debug.ResolutionLedger.note("combat.hit.amount")
						.withMethod("typed")
						.withSrc("CombatLogCache.fillDamage")
						.withName("get_amount")
						.withPayload("st.skill.DamageResult", "hook.dmgObj")
						.withArgs(["self", "dmgObj", "result"])
						.tryRoute("typed", "get_amount")
						.tryRoute("fieldwalk", "amount");
					if (hook != null && hook.length > 0)
						note.withHook(hook);
					note.num(line.amount).emit();
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
		line.sequence = ++latestSequence;
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
		try {
			var cfg = CombatLogConfig.live;
			if (cfg == null || cfg.shouldRecord(line))
				CombatLogRecorder.queue(line);
		} catch (_:Dynamic) {}
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
		if (ownedByLocalHero(a) || ownedByLocalHero(b))
			return true;
		if (sameUnit(a, currentTarget) || sameUnit(b, currentTarget))
			return true;
		var me = HealthCache.localHero;
		if (me == null)
			return false;
		return inCombatWithLocal(a, me) || inCombatWithLocal(b, me);
	}

	static function ownedByLocalHero(unit:Dynamic):Bool {
		if (unit == null)
			return false;
		var owner = CombatOwnership.summonOwnerOf(unit, extractObject);
		if (HealthCache.isLocalHero(owner))
			return true;
		var credited = CombatOwnership.resolve(unit, extractObject, ownerOfSkill);
		return HealthCache.isLocalHero(credited);
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

	/** Typed Entity.get_pos2D distance vs local hero — no new hooks. */
	static function nearLocal(unit:Dynamic):Bool {
		if (unit == null)
			return false;
		var me = HealthCache.localHero;
		if (me == null)
			return false;
		try {
			var a:ent.Entity = cast me;
			var b:ent.Entity = cast unit;
			var pa = a.get_pos2D();
			var pb = b.get_pos2D();
			if (pa == null || pb == null)
				return false;
			return pa.distance(pb) <= CombatLogConfig.PROXIMITY;
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
		// Avoid toLowerCase alloc on hot hit path; reject dumps / object traces.
		if (s.charCodeAt(0) == "{".code)
			return false;
		return s.indexOf("bytes") < 0 && s.indexOf("Bytes") < 0;
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
		if (skill == null)
			return "";
		var shown = solarflare.EngineSkillId.ofSkill(skill);
		if (shown.length > 0)
			return shown;
		var id = GeauxCache.getSkillId(skill);
		if (id.length > 0)
			return id;
		return GeauxCache.sanitizeSkillId(cleanString(extractObject(skill, "kind")));
	}

	/**
	 * Authoritative skill id for a hit: DamageResult.get_skillId() → BaseSkill.kind
	 * (physical ordinal 28). serverSource is actor attribution (GameObject), not a skill string.
	 */
	static function skillOfDamage(dmg:Dynamic):String {
		if (dmg == null)
			return "";
		try {
			var dr:st.skill.DamageResult = dmg;
			if (dr != null) {
				var typed = solarflare.EngineSkillId.display(dr.get_skillId());
				if (typed.length > 0)
					return typed;
				var viaSkill = skillIdOf(dr.skill);
				if (viaSkill.length > 0)
					return viaSkill;
				viaSkill = skillIdOf(dr.get_activeSkill());
				if (viaSkill.length > 0)
					return viaSkill;
			}
		} catch (_:Dynamic) {}
		var base = extractObject(dmg, "baseSkill");
		var id = skillIdOf(base);
		if (id.length > 0)
			return id;
		var ctx = extractObject(dmg, "ctx");
		id = skillIdOf(extractObject(ctx, "baseSkill"));
		if (id.length > 0)
			return id;
		id = skillIdOf(extractObject(ctx, "skill"));
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

	static function sourceCandidateOfDamage(dmg:Dynamic):Dynamic {
		var src:Dynamic = null;
		try {
			var dr:st.skill.DamageResult = dmg;
			src = dr.get_sourceUnit();
		} catch (_:Dynamic) {}
		if (src == null)
			src = extractObject(dmg, "serverSource");
		if (src == null)
			src = extractObject(dmg, "source");
		// Projectile / honey-bolt path: docs list ctx.owner as source fallback.
		if (src == null) {
			var ctx = extractObject(dmg, "ctx");
			src = extractObject(ctx, "owner");
		}
		if (src == null)
			src = ownerOfSkill(extractObject(dmg, "baseSkill"));
		return src;
	}

	/** Display minion only when runtime ownership changed its credited source. */
	static function minionNameOf(rawSource:Dynamic, creditedSource:Dynamic):String {
		if (rawSource == null || sameUnit(rawSource, creditedSource))
			return "";
		var kind = unitKindId(rawSource);
		if (kind.length == 0)
			return "";
		var label = CdbUnitNames.lookup(kind);
		return label.length > 0 ? label : unitName(rawSource);
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
