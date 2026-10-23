package solarflare.aura.signal;

class AuraRuleDef {
	public static inline var MAX_CONDITIONS:Int = 32;
	public static inline var CURRENT_VERSION:Int = 2;
	public static inline var MAX_GROUP_DEPTH:Int = 4;
	public static inline var MAX_GROUPS:Int = 32;
	public static inline var MAX_NODES:Int = 64;
	public var mode:String = "all";
	public var conditions:Array<AuraConditionDef> = [];
	public var presentationSource:Int = 0;
	public var version:Int = 1;
	public var negate:Bool = false;
	public var nodes:Array<AuraRuleNodeDef> = [];
	/** Malformed saved v2 data is preserved for round-trip recovery and never evaluated as a flat rule. */
	public var structureError:String = "";
	public var invalidSource:Dynamic = null;
	public var plan:AuraRulePlan = null;
	public function prepared():AuraRulePlan {
		if (plan == null || !plan.matches(this)) plan = new AuraRulePlan(this);
		return plan;
	}

	public function new() {}
	public function hasConditions():Bool return conditions != null && conditions.length > 0;
	public function clone():AuraRuleDef {
		var r = new AuraRuleDef(); r.mode = mode; r.presentationSource = presentationSource; r.version = version;
		r.negate = negate; r.structureError = structureError;
		r.invalidSource = invalidSource == null ? null : haxe.Json.parse(haxe.Json.stringify(invalidSource));
		r.nodes = nodes == null ? null : [for (n in nodes) n == null ? null : n.clone()];
		if (conditions != null) for (c in conditions) r.conditions.push(c == null ? null : c.clone());
		return r;
	}
}
