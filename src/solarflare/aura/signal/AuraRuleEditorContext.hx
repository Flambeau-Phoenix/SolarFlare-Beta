package solarflare.aura.signal;

/** Retained editor ownership shared by auras and individual canvas elements. */
class AuraRuleEditorContext {
	public var id:String;
	public var rule:AuraRuleDef;
	public var result:AuraRuleResult;
	public var conditionUi:Array<AuraConditionUiState>;
	public var presentation:Bool;
	public var snapshot:Void->Void;
	public function new(id:String, rule:AuraRuleDef, result:AuraRuleResult, ui:Array<AuraConditionUiState>, presentation:Bool) {
		this.id = id; this.rule = rule; this.result = result; this.conditionUi = ui; this.presentation = presentation;
	}
}
