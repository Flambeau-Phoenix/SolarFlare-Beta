package solarflare.aura.signal;

class AuraRuleResult {
	public var known:Bool = false;
	public var eventSerial:Int = 0;
	public var hit:Bool = false;
	/** Grown on demand by `ensure`; only the first `totalCount` entries are meaningful. */
	public var conditions:Array<AuraConditionResult> = [];
	public var resolved:Array<AuraResolvedValue> = [];
	public var progress:Float = Math.NaN;
	public var stacks:Int = -1;
	public var timeLeft:Float = Math.NaN;
	public var knownCount:Int = 0;
	public var hitCount:Int = 0;
	public var totalCount:Int = 0;
	public var code:AuraDiagnosticCode = EMPTY_RULE;

	public function new() {}

	/** Slots are allocated for conditions actually in use, so the cap can rise without per-aura cost. */
	public function ensure(n:Int):Void {
		if (n > AuraRuleDef.MAX_CONDITIONS) n = AuraRuleDef.MAX_CONDITIONS;
		while (conditions.length < n) {
			conditions.push(new AuraConditionResult());
			resolved.push(new AuraResolvedValue());
		}
	}
	public function reset():Void {
		eventSerial = 0;
		known = false; hit = false; progress = Math.NaN; stacks = -1; timeLeft = Math.NaN;
		var used = totalCount; if (used > conditions.length) used = conditions.length;
		knownCount = 0; hitCount = 0; totalCount = 0; code = EMPTY_RULE;
		for (i in 0...used) { conditions[i].reset(); resolved[i].reset(); }
	}
}
