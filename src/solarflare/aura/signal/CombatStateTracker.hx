package solarflare.aura.signal;

/**
 * Enter/leave transitions of the local hero's combat state, timestamped on the observe thread.
 *
 * Sample-owned like every other continuous datum (the release hook allowlist has no combat hook). The first read of a
 * hero only establishes the baseline: loading into a fight is not an "enter combat" event. A hero/character change
 * (identity generation) starts over. Pure primitives, no engine access: the frame builder feeds it.
 */
class CombatStateTracker {
	/** Age reported when the transition has not happened (larger than any `within` window). */
	public static inline var NEVER:Float = 1e9;
	public static var known:Bool = false;
	public static var inCombat:Bool = false;
	static var baseline:Bool = false;
	static var generation:Int = -1;
	static var ownerGeneration:Int = -1;
	public static var enteredSerial(default, null):Int = 0;
	public static var leftSerial(default, null):Int = 0;
	static var enteredAt:Float = -1;
	static var leftAt:Float = -1;

	public static function reset():Void {
		known = false; inCombat = false; baseline = false; enteredAt = -1; leftAt = -1;
		enteredSerial = leftSerial = 0;
	}

	/** `state` is null when the hero or the flag is unreadable; that makes the signal unknown, not false. */
	public static function observe(state:Null<Bool>, now:Float, identityGeneration:Int, characterGeneration:Int = 0):Void {
		if (identityGeneration != generation || characterGeneration != ownerGeneration) {
			reset(); generation = identityGeneration; ownerGeneration = characterGeneration;
		}
		if (state == null || !Math.isFinite(now)) { known = false; return; }
		known = true;
		if (!baseline) { baseline = true; inCombat = state; return; }
		if (state == inCombat) return;
		inCombat = state;
		if (state) { enteredAt = now; enteredSerial = AuraEventSequence.next(); }
		else { leftAt = now; leftSerial = AuraEventSequence.next(); }
	}

	public static function enteredAge(now:Float):Float return enteredAt < 0 ? NEVER : Math.max(0, now - enteredAt);
	public static function leftAge(now:Float):Float return leftAt < 0 ? NEVER : Math.max(0, now - leftAt);
}
