package solarflare.aura.signal;

class AuraRuleEvaluator {
	static inline var EPS:Float = 1e-9;
	public static function evaluate(rule:AuraRuleDef, frame:AuraSignalFrame, result:AuraRuleResult):Void {
		result.reset();
		if (rule == null || frame == null || rule.conditions == null || rule.conditions.length == 0 || rule.version != AuraRuleDef.CURRENT_VERSION) { result.code = EMPTY_RULE; return; }
		var n = rule.conditions.length; if (n > AuraRuleDef.MAX_CONDITIONS) n = AuraRuleDef.MAX_CONDITIONS; result.totalCount = n;
		for (i in 0...n) evalCondition(rule.conditions[i], frame, result.resolved[i], result.conditions[i]);
		aggregate(result, rule.mode == "all");
		var pi = rule.presentationSource; if (pi < 0 || pi >= n) pi = 0;
		var p = result.conditions[pi]; result.progress = p.progress; result.stacks = p.stacks; result.timeLeft = p.timeLeft;
	}
	static function evalCondition(c:AuraConditionDef, frame:AuraSignalFrame, value:AuraResolvedValue, out:AuraConditionResult):Void {
		out.reset(); value.reset();
		if (c == null) { out.code = INVALID_RULE; return; }
		var d = AuraSignalCatalog.find(c.signal);
		if (d == null) { out.code = UNKNOWN_SIGNAL; return; }
		if (!AuraConditionValidator.isValidOperator(c.op, d)) { out.code = INVALID_OPERATOR; return; }
		AuraSignalReader.read(frame, c.signal, c.subject, value);
		copy(value, out); if (!value.known) return;
		var raw:Null<Bool> = compareValue(c, value);
		if (raw == null) { out.known = false; out.code = NON_FINITE; return; }
		out.known = true; out.hit = c.negate ? !raw : raw; out.code = OK;
	}
	/** Pure typed comparator, public for the standalone truth-table suite. */
	public static function compareValue(c:AuraConditionDef, v:AuraResolvedValue):Null<Bool> {
		return switch (c.op) {
			case "present": v.present; case "absent": !v.present;
			case "is": v.boolValue == c.boolValue; case "isNot": v.boolValue != c.boolValue;
			case "eq" if (v.kind == Identity): v.stringValue == c.stringValue;
			case "neq" if (v.kind == Identity): v.stringValue != c.stringValue;
			case "lt": finite(v.numberValue, c.numberValue) ? v.numberValue < c.numberValue : null;
			case "lte": finite(v.numberValue, c.numberValue) ? v.numberValue <= c.numberValue + EPS : null;
			case "eq": finite(v.numberValue, c.numberValue) ? Math.abs(v.numberValue - c.numberValue) <= EPS : null;
			case "neq": finite(v.numberValue, c.numberValue) ? Math.abs(v.numberValue - c.numberValue) > EPS : null;
			case "gte": finite(v.numberValue, c.numberValue) ? v.numberValue >= c.numberValue - EPS : null;
			case "gt": finite(v.numberValue, c.numberValue) ? v.numberValue > c.numberValue : null;
			default: null;
		};
	}
	static inline function finite(a:Float, b:Float):Bool return Math.isFinite(a) && Math.isFinite(b);
	static function copy(v:AuraResolvedValue, o:AuraConditionResult):Void {
		o.known = v.known; o.kind = v.kind; o.value = v.numberValue; o.intValue = v.intValue; o.boolValue = v.boolValue;
		o.stringValue = v.stringValue; o.progress = v.progress; o.stacks = v.kind == Count ? v.intValue : -1; o.timeLeft = v.timeLeft; o.code = v.code;
	}
	static function aggregate(r:AuraRuleResult, all:Bool):Void {
		for (i in 0...r.totalCount) if (r.conditions[i].known) { r.knownCount++; if (r.conditions[i].hit) r.hitCount++; }
		var unknown = r.totalCount - r.knownCount;
		if (all) {
			if (r.knownCount > r.hitCount) { r.known = true; r.hit = false; }
			else if (unknown == 0) { r.known = true; r.hit = true; }
		} else {
			if (r.hitCount > 0) { r.known = true; r.hit = true; }
			else if (unknown == 0) { r.known = true; r.hit = false; }
		}
		r.code = r.known ? OK : UNKNOWN_DOMAIN;
	}
}
