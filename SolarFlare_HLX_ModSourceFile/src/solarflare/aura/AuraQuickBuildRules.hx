package solarflare.aura;

import solarflare.aura.signal.AuraConditionDef;
import solarflare.aura.signal.AuraConditionValidator;
import solarflare.aura.signal.AuraSignalCatalog;
import solarflare.aura.signal.AuraSignalDescriptor;

/** Pure input policy shared by the popup and its standalone regression suite. */
class AuraQuickBuildRules {
	public static function selectSignal(c:AuraConditionDef, signal:String):Bool {
		var d = AuraSignalCatalog.find(signal);
		if (d == null || c.signal == signal) return false;
		var old = AuraSignalCatalog.find(c.signal);
		if (old == null || old.subjectKind != d.subjectKind) {
			c.subject = "";
			c.subjectLabel = "";
		}
		c.signal = signal;
		c.op = AuraConditionValidator.defaultOperator(d);
		c.numberValue = d.kind == Percent ? 0.35 : 1;
		c.boolValue = true;
		c.stringValue = "";
		c.negate = false;
		if (signal == "resource.health.ratio") c.op = "lte";
		return true;
	}

	public static function operators(d:AuraSignalDescriptor):Array<String> {
		var out:Array<String> = [];
		for (op in ["present", "absent", "is", "isNot", "within", "lt", "lte", "eq", "neq", "gte", "gt"])
			if (AuraConditionValidator.isValidOperator(op, d)) out.push(op);
		return out;
	}

	public static function overlayAllowed(key:String, turnOn:Bool, stacks:Bool, counter:Bool):Bool {
		// Every decoration is independent, including the two count sources.
		return true;
	}

	public static function subjectId(id:String, kind:String):String {
		if (kind != "status") return id;
		return solarflare.cdb.CdbAuraTable.statusSubjectId(id);
	}

	public static function conditionIssue(c:AuraConditionDef):String {
		var d = AuraSignalCatalog.find(c.signal);
		if (d == null) return "Choose a signal to watch.";
		if (d.subjectKind.length > 0 && StringTools.trim(c.subject).length == 0)
			return d.subjectKind == "script" ? "Configure the expression in Advanced." : "Choose a " + d.subjectKind + " to watch.";
		if (!AuraConditionValidator.isValidOperator(c.op, d)) return "Choose a valid comparison.";
		if (!Math.isFinite(c.numberValue)) return "Enter a finite threshold.";
		var checked = c.clone();
		AuraConditionValidator.validateCondition(checked);
		if (checked.numberValue != c.numberValue) return "Enter a threshold within the signal's range.";
		return "";
	}

	public static function opLabel(op:String):String {
		return switch (op) {
			case "lt": "below";
			case "lte": "at most";
			case "eq": "equal to";
			case "neq": "not equal to";
			case "gte": "at least";
			case "gt": "above";
			case "is": "is";
			case "isNot": "is not";
			case "within": "within";
			case "present": "active";
			case "absent": "absent";
			default: op;
		};
	}

	public static function conditionSummary(c:AuraConditionDef):String {
		var issue = conditionIssue(c);
		if (issue.length > 0) return issue;
		var d = AuraSignalCatalog.find(c.signal);
		var subject = c.subjectLabel.length > 0 ? c.subjectLabel : c.subject;
		if (d.id == "status.present") return subject + " is " + opLabel(c.op);
		var label = d.label + (subject.length > 0 ? " (" + subject + ")" : "");
		var value = switch (d.kind) {
			case Boolean: c.boolValue ? "true" : "false";
			case Percent: Std.string(Math.round(c.numberValue * 10000) / 100) + "%";
			case Count: Std.string(c.numberValue);
			case Duration: Std.string(c.numberValue) + " seconds";
			case Identity: c.stringValue;
			default: Std.string(c.numberValue);
		};
		return label + " " + opLabel(c.op) + " " + value;
	}
}
