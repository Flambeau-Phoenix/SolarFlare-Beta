package solarflare.aura.signal;

class AuraConditionValidator {
	public static function validateRule(rule:AuraRuleDef):Array<String> {
		var out:Array<String> = [];
		if (rule == null) { out.push("rule is null"); return out; }
		if (rule.mode != "all" && rule.mode != "any") { rule.mode = "all"; out.push("mode reset to all"); }
		if (rule.version < 1 || rule.version > AuraRuleDef.CURRENT_VERSION) out.push("unsupported rule version");
		if (rule.conditions == null) { rule.conditions = []; out.push("conditions initialized"); }
		if (rule.conditions.length > AuraRuleDef.MAX_CONDITIONS) { rule.conditions = rule.conditions.slice(0, AuraRuleDef.MAX_CONDITIONS); out.push("conditions truncated"); }
		for (i in 0...rule.conditions.length) {
			if (rule.conditions[i] == null) { rule.conditions[i] = new AuraConditionDef(); out.push('condition $i replaced'); }
			for (d in validateCondition(rule.conditions[i])) out.push('condition $i: $d');
		}
		if (rule.conditions.length == 0) rule.presentationSource = 0;
		else if (rule.presentationSource < 0 || rule.presentationSource >= rule.conditions.length) { rule.presentationSource = 0; out.push("presentation source reset"); }
		return out;
	}
	public static function validateCondition(c:AuraConditionDef):Array<String> {
		var out:Array<String> = [];
		if (c.signal == null) c.signal = ""; if (c.subject == null) c.subject = ""; if (c.subjectLabel == null) c.subjectLabel = "";
		if (c.op == null) c.op = ""; if (c.stringValue == null) c.stringValue = "";
		c.signal = limit(c.signal); c.subject = limit(c.subject); c.subjectLabel = limit(c.subjectLabel); c.stringValue = limit(c.stringValue);
		var d = AuraSignalCatalog.find(c.signal);
		if (d == null) out.push("unknown signal");
		else {
			if (d.subjectKind.length > 0 && c.subject.length == 0) out.push("subject required");
			if (!isValidOperator(c.op, d)) out.push("invalid operator");
			c.numberValue = coerce(c.numberValue, d.kind);
		}
		return out;
	}
	public static function isValidOperator(op:String, d:AuraSignalDescriptor):Bool {
		if (d == null || op == null) return false;
		if (d.id == "status.present") return op == "present" || op == "absent";
		if (d.id == "event.cast.recent" && op == "within") return true;
		return switch (d.kind) {
			case Number | Percent | Count | Duration: op == "lt" || op == "lte" || op == "eq" || op == "neq" || op == "gte" || op == "gt" || (d.kind == Duration && op == "within");
			case Boolean: op == "is" || op == "isNot";
			case Identity: op == "eq" || op == "neq";
		};
	}
	public static function defaultOperator(d:AuraSignalDescriptor):String {
		if (d == null) return "";
		if (d.id == "status.present") return "present";
		if (d.id == "event.cast.recent") return "within";
		return switch (d.kind) { case Boolean: "is"; case Identity: "eq"; default: "gte"; };
	}
	public static function isEventOperator(op:String):Bool {
		return op == "within";
	}
	static function coerce(v:Float, kind:AuraValueKind):Float {
		if (!Math.isFinite(v)) v = 0;
		return switch (kind) {
			case Percent: clamp(v, 0, 1); case Duration: clamp(v, 0, 3600); case Count: clamp(v, 0, 9999);
			case Number: clamp(v, -1e12, 1e12); default: v;
		};
	}
	static inline function clamp(v:Float, lo:Float, hi:Float):Float return v < lo ? lo : (v > hi ? hi : v);
	static function limit(v:String):String return v.length > 256 ? v.substr(0, 256) : v;
}
