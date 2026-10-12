package solarflare.attackcombo;

/**
 * Primitive attack-chain presentation state (2026-10-11, from decompiled engine logic).
 *
 * Engine model (ent.Hero, hlboot 5f288029):
 * - `attack(skill)`: the finisher (`skill == attackComboSkill`) writes `attackComboCount = 0`;
 *   otherwise a basic attack with `count < moveSet.comboLength - 1` writes `count + 1`.
 *   Both writes happen before `useSkill`, i.e. before `BaseSkill.doStart`.
 * - `update()`: while `!isWithinAttackCombo()` it writes 0 every frame. Within = a basic attack
 *   is the active skill, or an attack skill stopped less than `Const.Hero.ComboWindow` ago.
 * - `getNextAttackSkill()`: the finisher once `count >= comboLength - 1`, else attackSkills[count].
 *
 * So the count is the step: basic attacks landed in the live chain, 0..comboLength-1, with the
 * finisher primed at comboLength-1. `step == comboLength` only while a real finisher flashes.
 *
 * Live findings (atkcombo1/2.webm, 2026-10-11): on the client those writes run server-side and
 * the server's count arrives late, through the synced field AND through the setter postfix. So the
 * chain is EVENT-LED: each local basic-attack doStart applies the engine's increment rule here,
 * the combo window (timed by the cache) ends the chain, and the finisher doStart flashes.
 * The setter and the polled field only seed a late join, before any local attack event; once a
 * local event has been seen they are ignored.
 */
class AttackComboState {
	/** How long the full-chain state lingers after the finisher's stop event (the tail). */
	public static inline var FLASH_SEC:Float = 0.25;
	/** Safety cap: full state is held at most this long if the finisher's stop event never arrives. */
	public static inline var FINISHER_HOLD_MAX_S:Float = 1.5;
	public var step(default, null):Int = 0;
	public var comboLength(default, null):Int = 4;
	public var moveSetId(default, null):String = "";
	public var withinCombo(default, null):Bool = false;
	public var flashFinal(default, null):Bool = false;
	public var known(default, null):Bool = false;
	public var direct(default, null):Bool = false;
	public var visible(get, never):Bool;
	/** Engine count as tracked here (0..comboLength-1); what the display returns to after a flash. */
	public var count(default, null):Int = 0;
	var flashUntil:Float = 0;
	var identity:Null<Int> = null;
	/** Whether moveSetId / comboLength came from a real read (the first read is not a "change"). */
	var idKnown:Bool = false;
	var lengthKnown:Bool = false;
	/**
	 * A local attack event (doStart) has been seen: from then on only local events drive the step.
	 * The synced field AND the set_attackComboCount postfix both carry the server's count, which
	 * trails the swing (atkcombo2.webm: each step was dragged back ~0.08s after it was shown).
	 */
	public var eventLed(default, null):Bool = false;

	public function new() {}

	public function clear():Void {
		resetChain();
		identity = null;
		comboLength = 4;
		moveSetId = "";
		idKnown = lengthKnown = false;
		eventLed = false;
	}

	function resetChain():Void {
		step = count = 0;
		withinCombo = flashFinal = known = direct = false;
		flashUntil = 0;
	}

	/** null ID / nonpositive length mean failed (or skipped) reads, not a weapon change. */
	function bind(epoch:Int, length:Int, id:Null<String>):Void {
		if (identity == null || identity != epoch) {
			clear();
			identity = epoch;
		}
		if (id != null && idKnown && id != moveSetId) {
			resetChain();
			// Do not borrow the previous weapon's length while the new read is unavailable.
			comboLength = length > 0 ? length : 4;
			lengthKnown = length > 0;
		} else if (length > 0 && lengthKnown && length != comboLength) {
			resetChain();
		}
		if (id != null) {
			moveSetId = id;
			idKnown = true;
		}
		if (length > 0) {
			comboLength = length;
			lengthKnown = true;
		}
		if (count > comboLength - 1) {
			// A first real length read can be shorter than the default the chain started under.
			count = comboLength - 1;
			if (!flashFinal)
				step = count;
		}
	}

	inline function get_visible():Bool return withinCombo || flashFinal || step > 0;

	inline function flashing(now:Float):Bool return flashFinal && now < flashUntil;

	/**
	 * A local basic attack began (doStart). `index` is the started skill's position in
	 * Hero.attackSkills (-1 unknown): the game picks the attack by its own count, so which skill
	 * started IS the step (atkcombo/devlog 20261011-125209: dashes and cancelled swings made a
	 * pure increment drift). Without an index, apply Hero.attack's increment rule; a chain ended
	 * by the window or a finisher starts again at 1.
	 */
	public function basic(now:Float, epoch:Int, length:Int, id:Null<String>, index:Int = -1):Void {
		bind(epoch, length, id);
		expireFlash(now);
		eventLed = true;
		if (index >= 0) {
			count = Std.int(Math.min(comboLength - 1, index + 1));
		} else {
			var base = withinCombo ? count : 0;
			count = base < comboLength - 1 ? base + 1 : base;
		}
		flashFinal = false;
		flashUntil = 0;
		withinCombo = known = direct = true;
		step = count;
	}

	/** A real finisher began (doStart): show the full chain for FLASH_SEC; the engine count is 0. */
	public function finisher(now:Float, epoch:Int, length:Int, id:Null<String>):Void {
		bind(epoch, length, id);
		eventLed = true;
		known = direct = true;
		count = 0;
		withinCombo = false;
		flashFinal = true;
		// Held while the finisher plays; endFinisher() releases it on the stop event.
		flashUntil = now + FINISHER_HOLD_MAX_S;
		step = comboLength;
	}

	/** The finisher's stop event: keep the full state a short tail, then return to idle. */
	public function endFinisher(now:Float):Void {
		if (flashFinal && now + FLASH_SEC < flashUntil)
			flashUntil = now + FLASH_SEC;
	}

	/**
	 * `Hero.isWithinAttackCombo()` read false: the engine's update() is resetting the count.
	 * A running finisher flash still plays out.
	 */
	public function lapse(now:Float, epoch:Int, length:Int, id:Null<String>):Void {
		bind(epoch, length, id);
		expireFlash(now);
		known = true;
		count = 0;
		withinCombo = false;
		if (!flashing(now))
			step = 0;
	}

	/**
	 * Server count from the setter postfix (`fromHook`) or a field poll: a late-join seed only.
	 * Ignored once any local attack event has been seen, because the server's count trails the
	 * swing and would pull the display back. `raw < 0` = unreadable. The hook passes length <= 0 /
	 * id null; `fromHook` is kept for call-site clarity.
	 */
	public function applyCount(now:Float, epoch:Int, raw:Int, length:Int, id:Null<String>, fromHook:Bool):Void {
		bind(epoch, length, id);
		expireFlash(now);
		if (raw < 0 || eventLed)
			return;
		known = true;
		direct = raw < comboLength;
		count = raw < comboLength ? raw : comboLength - 1;
		if (count == 0) {
			withinCombo = false;
			if (!flashing(now))
				step = 0;
			return;
		}
		flashFinal = false;
		flashUntil = 0;
		withinCombo = true;
		step = count;
	}

	/** Advance time only (no new reads): ends an expired finisher flash. */
	public function tick(now:Float):Void {
		expireFlash(now);
	}

	function expireFlash(now:Float):Void {
		if (flashFinal && now >= flashUntil) {
			flashFinal = false;
			flashUntil = 0;
			step = count;
		}
	}
}
