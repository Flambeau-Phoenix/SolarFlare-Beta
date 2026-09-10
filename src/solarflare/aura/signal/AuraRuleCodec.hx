package solarflare.aura.signal;

class AuraRuleCodec {
	public static function toObj(rule:AuraRuleDef):Dynamic {
		if (rule == null) return null;
		var cs:Array<Dynamic> = [];
		if (rule.conditions != null) for (c in rule.conditions) if (c != null) cs.push({
			signal: c.signal, subject: c.subject, subjectLabel: c.subjectLabel, op: c.op,
			numberValue: c.numberValue, boolValue: c.boolValue, stringValue: c.stringValue, negate: c.negate
		});
		return {version: rule.version, mode: rule.mode, presentationSource: rule.presentationSource, conditions: cs};
	}
	public static function fromDyn(d:Dynamic):AuraRuleDef {
		if (d == null) return null;
		var r = new AuraRuleDef();
		try if (d.version != null) r.version = Std.int(d.version) catch (_:Dynamic) {}
		try if (d.mode != null) r.mode = Std.string(d.mode) catch (_:Dynamic) {}
		try if (d.presentationSource != null) r.presentationSource = Std.int(d.presentationSource) catch (_:Dynamic) {}
		r.conditions = [];
		try {
			var arr:Array<Dynamic> = cast d.conditions;
			if (arr != null) for (item in arr) {
				if (r.conditions.length >= AuraRuleDef.MAX_CONDITIONS) break;
				if (item == null) continue;
				var c = new AuraConditionDef();
				if (item.signal != null) c.signal = Std.string(item.signal);
				if (item.subject != null) c.subject = Std.string(item.subject);
				if (item.subjectLabel != null) c.subjectLabel = Std.string(item.subjectLabel);
				if (item.op != null) c.op = Std.string(item.op);
				if (item.numberValue != null) c.numberValue = item.numberValue;
				if (item.boolValue == true) c.boolValue = true;
				if (item.stringValue != null) c.stringValue = Std.string(item.stringValue);
				if (item.negate == true) c.negate = true;
				r.conditions.push(c);
			}
		} catch (_:Dynamic) {}
		AuraConditionValidator.validateRule(r);
		return r;
	}
}
