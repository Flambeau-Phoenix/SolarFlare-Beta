package solarflare.aura.signal;

class AuraRuleSummary {
	public static function format(rule:AuraRuleDef, leaf:AuraConditionDef->String):String {
		if (rule == null) return "No conditions.";
		if (rule.version == 2) {
			var p = rule.prepared(); if (p.error != "") return p.error;
			return group(rule, rule.nodes, rule.mode, rule.negate, leaf);
		}
		return (rule.conditions == null || rule.conditions.length == 0) ? "No conditions." :
			"(" + [for (c in rule.conditions) leaf(c)].join(rule.mode == "all" ? " AND " : " OR ") + ")";
	}
	static function group(rule:AuraRuleDef, nodes:Array<AuraRuleNodeDef>, mode:String, negate:Bool, leaf:AuraConditionDef->String):String {
		var parts = [];
		for (n in nodes) parts.push(n.kind == "condition" ? leaf(rule.conditions[n.conditionIndex]) : group(rule, n.nodes, n.mode, n.negate, leaf));
		return (negate ? "NOT " : "") + "(" + parts.join(mode == "all" ? " AND " : " OR ") + ")";
	}
}
