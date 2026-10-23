package solarflare.aura.signal;

/** Retained editor ownership shared by auras and individual canvas elements. */
class AuraRuleEditorContext {
	public var id:String;
	public var rule:AuraRuleDef;
	public var result:AuraRuleResult;
	public var conditionUi:Array<AuraConditionUiState>;
	public var presentation:Bool;
	public var snapshot:Void->Void;
	public var picker:solarflare.aura.ui.AuraConditionPicker;
	/** Optional owner identity check in addition to the picker's root-window and rule-membership checks. */
	public var pickerOwnerValid:Void->Bool;
	var summary:String = "";
	var summaryRule:AuraRuleDef;
	var summaryPlan:AuraRulePlan;
	var summaryMode:String;
	var summaryLeaves:Array<AuraConditionDef> = [];
	public function summaryText():String {
		var p = rule.version == 2 ? rule.prepared() : null;
		var changed = summaryRule != rule || summaryPlan != p || summaryMode != rule.mode || summaryLeaves.length != rule.conditions.length;
		if (!changed) for (i in 0...summaryLeaves.length) {
			var a = summaryLeaves[i]; var b = rule.conditions[i];
			if (a == null || b == null) { if (a != b) changed = true; }
			else if (a.signal != b.signal || a.subject != b.subject || a.subjectLabel != b.subjectLabel || a.op != b.op
				|| a.numberValue != b.numberValue || a.boolValue != b.boolValue || a.stringValue != b.stringValue || a.negate != b.negate) changed = true;
		}
		if (changed) {
			summary = AuraRuleSummary.format(rule, AuraConditionEditor.humanConditionSummary);
			summaryRule = rule; summaryPlan = p; summaryMode = rule.mode;
			summaryLeaves = [for (c in rule.conditions) c == null ? null : c.clone()];
		}
		return summary;
	}
	public function new(id:String, rule:AuraRuleDef, result:AuraRuleResult, ui:Array<AuraConditionUiState>, presentation:Bool) {
		this.id = id; this.rule = rule; this.result = result; this.conditionUi = ui; this.presentation = presentation;
	}
}
