package solarflare.attackcombo;

import solarflare.HealthCache;
import solarflare.ui.ByteUtil;
#if solarflare_telemetry
import solarflare.debug.ResolutionLedger;
#end

/**
 * Live weapon attack-chain state (separate from Rogue ComboPoints).
 *
 * The engine's `Hero.attackComboCount` is the step (see AttackComboState for the decompiled
 * model), but on the client it is written server-side and synced about one swing late. So the
 * chain is event-led: `BaseSkill.doStart` of a local basic attack gives the step, taken from the
 * started skill's position in Hero.attackSkills (the game picks the attack by its own count, so
 * which skill started IS the step; increment only when the skill is not in the list). The
 * finisher's doStart flashes, and the combo window ends an idle chain. The window is timed locally
 * (swing start/stop plus Const.Hero.ComboWindow). `isWithinAttackCombo()` is never trusted (it
 * reads false on the client on every event) and non-basic starts such as a dash never touch the
 * chain. The setter postfix and the polled field are the server's late count: they only seed a
 * late join.
 *
 * Replaced 2026-10-11: the step used to be reverse-mapped from `getNextAttackSkill()` by object
 * identity in `attackSkills`, which mis-stepped on duplicate attack skills, on chains longer than
 * `attackSkills` (the engine repeats the last entry) and on talent-replaced attacks, and took the
 * length from `attackSkills` instead of `moveSet.comboLength`.
 */
class AttackComboCache {
	public static inline var ROUTE_UNRESOLVED:String = "unresolved";
	public static inline var ROUTE_DIRECT:String = "direct";
	public static inline var FLASH_SEC:Float = AttackComboState.FLASH_SEC;
	public static var route:String = ROUTE_UNRESOLVED;
	public static var step:Int = 0;
	public static var comboLength:Int = 4;
	public static var moveSetId:String = "";
	public static var withinCombo:Bool = false;
	public static var flashFinal:Bool = false;
	public static var visible:Bool = false;
	public static var known:Bool = false;
	public static var debugLine:String = "attack-combo idle";
	static var state = new AttackComboState();
	/** Identity the last hook write was applied under (a new hero must re-apply even a 0). */
	static var lastHookGen:Int = -1;
	/** tick() lapse checks while a chain is live (ObserveDemand may not be polling). */
	static inline var LAPSE_CHECK_S:Float = 0.05;
	static var lastLapseCheck:Float = 0;
	/** One swing = one step even if the client re-starts the same skill (local + confirmed start). */
	static inline var RESTART_DEDUPE_S:Float = 0.15;
	static var lastBasicSkill:Dynamic = null;
	static var lastBasicAt:Float = -1;
	/** The finisher skill whose stop releases the held full-chain state. */
	static var lastFinalSkill:Dynamic = null;
	/** A basic swing has started and its doStop has not arrived. */
	static var swingActive:Bool = false;
	static var lastStopAt:Float = -1;
	/** Longest a swing is assumed to run if its doStop never arrives. */
	static inline var SWING_MAX_S:Float = 2.5;
	static inline var WINDOW_FALLBACK_S:Float = 1.5;
	static var comboWindow:Float = -1;
	static var comboWindowTried:Bool = false;
	// Diagnostics shown in the builder debug line.
	static var nStart:Int = 0;
	static var nBasic:Int = 0;
	static var nFinal:Int = 0;
	static var nLapse:Int = 0;
	static var lapseWhy:String = "-";
	static var lastWithin:Int = -2;

	public static function keep():Void {}

	public static function clear(reason:String):Void {
		state.clear();
		lastHookGen = -1;
		lastBasicSkill = null;
		lastBasicAt = -1;
		lastFinalSkill = null;
		swingActive = false;
		lastStopAt = -1;
		publishSnap();
		debugLine = "reset:" + reason;
	}

	/**
	 * Native: fun(ent.Hero, i32) -> i32 → postfix N+1 = 3, return result unaltered.
	 * NOT the step authority: on the client this setter also receives the server's late count, which
	 * dragged shown steps back. Recorded for diagnostics and late-join seeding. `result` is the count. Writes matching the applied count (update()'s
	 * per-frame idle reset) cost one comparison.
	 */
	@:keep
	@:hlx.postfix(ent.Hero.set_attackComboCount)
	static function onSetAttackComboCount(self:Dynamic, value:Int, result:Int):Int {
		try {
			if (self != null && (result != state.count || lastHookGen != HealthCache.identityGen)
					&& HealthCache.isLocalHero(self))
				noteCount(result);
		} catch (_:Dynamic) {}
		return result;
	}

	static function noteCount(count:Int):Void {
		lastHookGen = HealthCache.identityGen;
		// O(1): no moveset read inside the hook; observe() keeps length/id current.
		// Server count: trails the swing, so it only seeds a late join (see AttackComboState).
		state.applyCount(now(), HealthCache.identityGen, count, -1, null, true);
		noteEdge("count", count);
		publishSnap();
		solarflare.ObserveDemand.markAttackComboDirty();
	}

	/** Forwarded from BaseSkill.doStart: classifies the finisher; ordinary steps come from the count. */
	public static function onBaseSkillStart(skill:Dynamic):Void {
		if (skill == null) return;
		try {
			var bs:st.skill.BaseSkill = skill;
			var unit = bs.get_ownerUnit();
			if (unit == null) unit = bs.get_ownerHero();
			if (unit == null || !HealthCache.isLocalHero(unit)) return;
			var hero:ent.Hero = HealthCache.localHero;
			if (hero == null) return;
			nStart++;
			// Same test as Hero.attack's reset (identity), plus the flag for talent-replaced finishers.
			var isFinal = false;
			try isFinal = hero.attackComboSkill != null && (skill : Dynamic) == (hero.attackComboSkill : Dynamic) catch (_:Dynamic) {}
			if (!isFinal)
				try isFinal = bs.isFinalAttack() catch (_:Dynamic) {}
			if (isFinal) {
				var ms = readMoveSet(hero);
				state.finisher(now(), HealthCache.identityGen, ms.length, ms.id);
				nFinal++;
				lastFinalSkill = skill;
				swingActive = false;
				noteEdge("final", state.step);
				publishSnap();
			} else {
				var isBasic = false;
				try isBasic = bs.isBasicAttack() catch (_:Dynamic) {}
				var t = now();
				// Non-basic starts (dash, riders such as a 0.08s follow-up skill) never touch the chain:
				// the next attack that starts tells the step, and the window timer ends an idle chain.
				if (!isBasic) {
				} else if (skill == lastBasicSkill && t - lastBasicAt < RESTART_DEDUPE_S) {
					swingActive = true;
				} else {
					lastBasicSkill = skill;
					lastBasicAt = t;
					swingActive = true;
					nBasic++;
					var ms = readMoveSet(hero);
					var idx = attackIndexOf(hero, skill);
					// A list shorter than the chain repeats its last attack, so the index cannot name
					// steps past it: use the increment rule there.
					var listLen = attackListLength(hero);
					var chainBasics = (ms.length > 0 ? ms.length : state.comboLength) - 1;
					if (listLen < chainBasics)
						idx = -1;
					state.basic(t, HealthCache.identityGen, ms.length, ms.id, idx);
					noteEdge("basic", state.step);
					publishSnap();
				}
			}
			solarflare.ObserveDemand.markAttackComboDirty();
		} catch (_:Dynamic) {}
	}

	/** Forwarded from BaseSkill.doStop: only the swing we started matters (reference compare). */
	public static function onBaseSkillStop(skill:Dynamic):Void {
		if (skill == null)
			return;
		if (skill == lastFinalSkill) {
			// The finisher finished: release the held full-chain state after a short tail.
			state.endFinisher(now());
			return;
		}
		if (!swingActive || skill != lastBasicSkill)
			return;
		swingActive = false;
		lastStopAt = now();
	}

	static function windowSeconds():Float {
		if (comboWindow <= 0 && !comboWindowTried) {
			comboWindowTried = true;
			try {
				var v:Float = Const.Hero.ComboWindow;
				if (v > 0.05 && v < 10)
					comboWindow = v;
			} catch (_:Dynamic) {}
		}
		return comboWindow > 0 ? comboWindow : WINDOW_FALLBACK_S;
	}

	/** Ends a live chain from local timers; returns true when it lapsed. */
	static function checkLapse(t:Float, length:Int, id:Null<String>):Bool {
		if (!state.withinCombo)
			return false;
		if (lastBasicAt < 0)
			lastBasicAt = t; // late-join seed: the window starts now.
		var why = "";
		if (swingActive) {
			if (t - lastBasicAt > SWING_MAX_S)
				why = "stuck";
		} else {
			var from = lastStopAt > lastBasicAt ? lastStopAt : lastBasicAt;
			if (t - from > windowSeconds())
				why = "window";
		}
		if (why.length == 0)
			return false;
		nLapse++;
		lapseWhy = why;
		swingActive = false;
		state.lapse(t, HealthCache.identityGen, length, id);
		publishSnap();
		return true;
	}

	/**
	 * Cheap per-observe upkeep when observe() is not due (e.g. overlay hidden, auras reading):
	 * expires a finisher flash and applies the engine's window rule while a chain is live.
	 */
	public static function tick():Void {
		if (!state.flashFinal && !state.withinCombo)
			return;
		var t = now();
		if (state.withinCombo && t - lastLapseCheck >= LAPSE_CHECK_S) {
			lastLapseCheck = t;
			if (checkLapse(t, -1, null))
				return;
		}
		if (state.flashFinal) {
			state.tick(t);
			if (!state.flashFinal)
				publishSnap();
		}
	}

	public static function observe():Void {
		var hero:ent.Hero = HealthCache.localHero;
		if (hero == null) { clear("no_hero"); return; }
		var ms = readMoveSet(hero);
		var length = ms.length > 0 ? ms.length : fallbackLength(hero);
		var t = now();
		lastLapseCheck = t;
		// Diagnostic only: what the engine says. Never drives the display.
		lastWithin = within(hero);
		state.applyCount(t, HealthCache.identityGen, readCount(hero), length, ms.id, false);
		checkLapse(t, length, ms.id);
		publishSnap();
	}

	/** Position of `skill` in Hero.attackSkills by identity, or -1. */
	static function attackIndexOf(hero:ent.Hero, skill:Dynamic):Int {
		try {
			var list = hero.attackSkills;
			if (list != null) {
				var n:Int = list.length;
				for (i in 0...n)
					if (list.getDyn(i) == skill)
						return i;
			}
		} catch (_:Dynamic) {}
		return -1;
	}

	static function attackListLength(hero:ent.Hero):Int {
		try {
			var list = hero.attackSkills;
			if (list != null)
				return list.length;
		} catch (_:Dynamic) {}
		return -1;
	}

	/** Set once `isWithinAttackCombo` is found absent (removed from the 2026-10-08 build): stop throwing every tick. */
	static var withinMissing:Bool = false;
	static var withinMisses:Int = 0;

	/**
	 * Hero.isWithinAttackCombo(): 1 within, 0 not, -1 unreadable (never treated as a break).
	 * Dynamic call: the method is not in the regenerated GameLib, so it cannot be a typed member access.
	 */
	static function within(hero:ent.Hero):Int {
		if (withinMissing)
			return -1;
		try {
			var h:Dynamic = hero;
			var r:Int = h.isWithinAttackCombo() ? 1 : 0;
			withinMisses = 0;
			return r;
		} catch (_:Dynamic) {
			if (++withinMisses >= 8)
				withinMissing = true;
			return -1;
		}
	}

	/** Freeze primitive presentation state; draw never reads the engine. */
	static function publishSnap():Void {
		route = state.direct ? ROUTE_DIRECT : ROUTE_UNRESOLVED;
		step = state.step;
		comboLength = state.comboLength;
		moveSetId = state.moveSetId;
		withinCombo = state.withinCombo;
		flashFinal = state.flashFinal;
		visible = state.visible;
		known = state.known;
		debugLine = route + " step=" + step + "/" + comboLength + " count=" + state.count + " within=" + withinCombo + " known=" + known + (moveSetId.length > 0 ? " ms=" + moveSetId : "")
			+ " | start=" + nStart + " basic=" + nBasic + " final=" + nFinal + " lapse=" + nLapse + "(" + lapseWhy + ")"
			+ " swing=" + swingActive + " engineWithin=" + lastWithin + " win=" + windowSeconds();
	}

	static inline function noteEdge(kind:String, value:Int):Void {
		#if solarflare_telemetry
		if (ResolutionLedger.armed()) ResolutionLedger.touch("ATTACK_COMBO_EDGE", "hook", "AttackComboCache." + kind, kind, "string", "step=" + state.step + " v=" + value);
		#end
	}

	/** `Hero.attackComboCount`, or -1 when unreadable (null, non-numeric, negative). */
	static function readCount(hero:ent.Hero):Int {
		try {
			var raw:Dynamic = HlxRuntime.resolveField(hero, "attackComboCount");
			if (raw != null && Std.isOfType(raw, Int)) {
				var n:Int = raw;
				return n >= 0 ? n : -1;
			}
		} catch (_:Dynamic) {}
		return -1;
	}

	/** Without a moveset: basic attacks + finisher, as the engine's chain would run. */
	static function fallbackLength(hero:ent.Hero):Int {
		try {
			var list = hero.attackSkills;
			if (list != null && list.length > 0)
				return list.length + (hero.attackComboSkill != null ? 1 : 0);
		} catch (_:Dynamic) {}
		return 0;
	}

	static function readMoveSet(hero:ent.Hero):{length:Int, id:Null<String>} {
		try {
			var ms = hero.getMoveSet();
			// A successful null moveset means no active weapon; a thrown read stays unknown.
			if (ms == null) return {length:0, id:""};
			var id = ms.id == null ? null : ByteUtil.materialize(ms.id);
			return {length:ms.comboLength, id:id != null && id.length > 0 ? id : null};
		} catch (_:Dynamic) {}
		return {length:0, id:null};
	}

	static function now():Float { try return haxe.Timer.stamp() catch (_:Dynamic) return Date.now().getTime() / 1000.0; }
}
