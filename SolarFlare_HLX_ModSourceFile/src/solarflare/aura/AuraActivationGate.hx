package solarflare.aura;

import solarflare.aura.signal.AuraSignalFrame;
import solarflare.aura.signal.AuraConditionDef;

/** Optional extra activation requirement, read exclusively from the frozen frame. */
class AuraActivationGate {
	public static var KEYS(default, null):Array<String> = ["inCombat", "outOfCombat", "alive", "hasTarget", "inRift", "bossFight"];
	static var demands:Array<AuraConditionDef> = makeDemands();
	public static function supported(key:String):Bool return key == "none" || KEYS.indexOf(key) >= 0;
	public static function label(key:String):String return switch (key) {
		case "inCombat": "in combat"; case "outOfCombat": "out of combat"; case "alive": "alive";
		case "hasTarget": "a target is selected"; case "inRift": "in a rift"; case "bossFight": "in a rift boss fight";
		default: "any time";
	};
	/** -1 unknown, 0 false, 1 true. Unknown data can never pass a gate. */
	public static function read(key:String, frame:AuraSignalFrame):Int {
		if (key == "none") return 1;
		if (frame == null || !frame.heroKnown) return -1;
		return switch (key) {
			case "inCombat": !frame.combatKnown ? -1 : frame.inCombat ? 1 : 0;
			case "outOfCombat": !frame.combatKnown ? -1 : frame.inCombat ? 0 : 1;
			case "alive": !frame.aliveKnown ? -1 : frame.alive ? 1 : 0;
			case "hasTarget": !frame.targetKnown ? -1 : frame.targetValid ? 1 : 0;
			case "inRift": !frame.encounterKnown ? -1 : frame.inRift ? 1 : 0;
			case "bossFight": !frame.encounterKnown ? -1 : frame.inBossFight ? 1 : 0;
			default: -1;
		};
	}
	public static function combine(known:Bool, hit:Bool, gate:Int):Int {
		if (gate == 0 || (known && !hit)) return 0;
		return gate < 0 || !known ? -1 : 1;
	}
	public static function appendDemand(key:String, out:Array<AuraConditionDef>):Void {
		var index = KEYS.indexOf(key); if (index >= 0) out.push(demands[index]);
	}
	static function makeDemands():Array<AuraConditionDef> {
		var signals = ["combat.inCombat", "combat.inCombat", "player.alive", "target.valid", "encounter.inRift", "encounter.inBossFight"];
		return [for (i in 0...signals.length) {
			var c = new AuraConditionDef(); c.signal = signals[i]; c.op = "is"; c.boolValue = i != 1; c;
		}];
	}
}
