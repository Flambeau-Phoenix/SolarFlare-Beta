package solarflare.aura.signal;

class AuraRuleResult {
	public var known:Bool = false;
	public var hit:Bool = false;
	public var conditions:Array<AuraConditionResult> = [];
	public var resolved:Array<AuraResolvedValue> = [];
	public var progress:Float = Math.NaN;
	public var stacks:Int = -1;
	public var timeLeft:Float = Math.NaN;
	public var knownCount:Int = 0;
	public var hitCount:Int = 0;
	public var totalCount:Int = 0;
	public var code:AuraDiagnosticCode = EMPTY_RULE;

	public function new() {
		for (_ in 0...AuraRuleDef.MAX_CONDITIONS) {
			conditions.push(new AuraConditionResult());
			resolved.push(new AuraResolvedValue());
		}
	}
	public function reset():Void {
		known = false; hit = false; progress = Math.NaN; stacks = -1; timeLeft = Math.NaN;
		knownCount = 0; hitCount = 0; totalCount = 0; code = EMPTY_RULE;
		for (i in 0...AuraRuleDef.MAX_CONDITIONS) { conditions[i].reset(); resolved[i].reset(); }
	}
}
