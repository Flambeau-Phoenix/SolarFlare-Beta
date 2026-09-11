package solarflare.combatlog;

/**
 * Collapse nested Unit/Foe receive callbacks for one DamageResult payload.
 *
 * Authority: ent.Foe.onReceiveDamage is the outer path (calls Unit stub then foe logic).
 * When both Unit and Foe hooks fire for the same payload, only the outermost leave emits.
 * Never drops a hit that only hits one of the two hooks.
 */
class DamageObservation {
	var active:Array<Dynamic> = [];

	public function new() {}

	public function enter(damage:Dynamic):Void {
		if (damage == null)
			return;
		active.push(damage);
	}

	/** True when this leave closes the outermost observation for `damage` → emit one row. */
	public function leave(damage:Dynamic):Bool {
		if (damage == null)
			return false;
		if (active.length > 0)
			active.pop();
		return active.indexOf(damage) < 0;
	}
}
