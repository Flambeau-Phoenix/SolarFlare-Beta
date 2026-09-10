package solarflare.combatlog;

/** Collapse nested Unit/Foe callbacks for one payload, never equal-valued hits. */
class DamageObservation {
	var active:Array<Dynamic> = [];
	public function new() {}
	public function enter(damage:Dynamic):Void active.push(damage);
	public function leave(damage:Dynamic):Bool {
		active.pop();
		return damage != null && active.indexOf(damage) < 0;
	}
}
