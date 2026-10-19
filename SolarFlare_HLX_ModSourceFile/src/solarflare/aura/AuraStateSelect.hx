package solarflare.aura;

import solarflare.aura.signal.AuraRuleEvaluator;
import solarflare.aura.signal.AuraSignalFrame;

/** Native-free state resolution: first matching state in order wins, otherwise the Default look (""). */
class AuraStateSelect {
	public static function pick(states:Array<AuraStateDef>, frame:AuraSignalFrame):String {
		if (states == null || frame == null) return "";
		for (s in states) {
			if (s == null || s.rule == null) continue;
			AuraRuleEvaluator.evaluate(s.rule, frame, s.result);
			if (s.result.known && s.result.hit) return s.id;
		}
		return "";
	}
}
