package solarflare.aura.signal;

import solarflare.aura.AuraCanvasElement;
import solarflare.aura.AuraStateDef;

/** Flatten only during configuration-demand rebuilds; never in rendering. */
class AuraRuleDemand {
	public static function append(rule:AuraRuleDef, elements:Array<AuraCanvasElement>, out:Array<AuraConditionDef>, states:Array<AuraStateDef> = null):Void {
		appendRule(rule, out);
		if (states != null) for (s in states) if (s != null) appendRule(s.rule, out);
		if (elements != null) for (el in elements) if (el != null) appendRule(el.visibilityRule, out);
	}
	static function appendRule(rule:AuraRuleDef, out:Array<AuraConditionDef>):Void {
		if (rule == null || rule.conditions == null) return;
		var n = Std.int(Math.min(rule.conditions.length, AuraRuleDef.MAX_CONDITIONS));
		for (i in 0...n) if (rule.conditions[i] != null) out.push(rule.conditions[i]);
	}
}
