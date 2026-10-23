package solarflare.aura.signal;

/** Configuration node. Leaf indices address the canonical conditions array. */
class AuraRuleNodeDef {
	static var nextKey:Int = 1;
	public var uiKey(default, null):Int;
	public var kind:String;
	public var conditionIndex:Int = -1;
	public var mode:String = "all";
	public var negate:Bool = false;
	public var nodes:Array<AuraRuleNodeDef> = [];
	public function new(kind:String = "group") { this.kind = kind; uiKey = nextKey++; }
	public static function leaf(index:Int):AuraRuleNodeDef {
		var n = new AuraRuleNodeDef("condition"); n.conditionIndex = index; return n;
	}
	public function clone():AuraRuleNodeDef {
		var n = new AuraRuleNodeDef(kind); n.conditionIndex = conditionIndex; n.mode = mode; n.negate = negate;
		n.nodes = nodes == null ? null : [for (c in nodes) c == null ? null : c.clone()]; return n;
	}
}
