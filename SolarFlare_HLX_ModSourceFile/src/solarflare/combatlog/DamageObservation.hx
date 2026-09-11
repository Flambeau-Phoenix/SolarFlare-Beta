package solarflare.combatlog;

/**
 * Collapse nested Unit/Foe receive callbacks for one DamageResult payload.
 *
 * Authority: ent.Foe.onReceiveDamage is the outer path (calls Unit stub then foe logic).
 * When both Unit and Foe hooks fire for the same payload, only the outermost leave emits.
 * Never drops a hit that only hits one of the two hooks.
 *
 * Depth counter only — never retains DamageResult pointers (avoids GC pin on missed leave).
 */
class DamageObservation {
	static inline var MAX_DEPTH:Int = 8;
	var depth:Int = 0;

	public function new() {}

	public inline function enter(damage:Dynamic):Void {
		if (damage == null)
			return;
		// Recover from unmatched leave (engine throw / skipped postfix).
		if (depth >= MAX_DEPTH)
			depth = 0;
		depth++;
	}

	/** True when this leave closes the outermost observation → emit one row. */
	public inline function leave(damage:Dynamic):Bool {
		if (damage == null)
			return false;
		if (depth > 0)
			depth--;
		return depth == 0;
	}
}
