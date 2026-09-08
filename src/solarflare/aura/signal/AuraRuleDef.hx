package solarflare.aura.signal;

class AuraRuleDef {
	public static inline var MAX_CONDITIONS:Int = 8;
	public static inline var CURRENT_VERSION:Int = 1;
	public var mode:String = "all";
	public var conditions:Array<AuraConditionDef> = [];
	public var presentationSource:Int = 0;
	public var version:Int = CURRENT_VERSION;

	public function new() {}
	public function hasConditions():Bool return conditions != null && conditions.length > 0;
	public function clone():AuraRuleDef {
		var r = new AuraRuleDef(); r.mode = mode; r.presentationSource = presentationSource; r.version = version;
		if (conditions != null) for (c in conditions) if (c != null) r.conditions.push(c.clone());
		return r;
	}
}
