package solarflare.aura.signal;

class AuraConditionResult {
	public var known:Bool = false;
	public var hit:Bool = false;
	public var kind:AuraValueKind = Boolean;
	public var value:Float = Math.NaN;
	public var intValue:Int = 0;
	public var boolValue:Bool = false;
	public var stringValue:String = "";
	public var progress:Float = Math.NaN;
	public var stacks:Int = -1;
	public var timeLeft:Float = Math.NaN;
	public var code:AuraDiagnosticCode = UNKNOWN_SIGNAL;
	public function new() {}
	public function reset():Void {
		known = false; hit = false; kind = Boolean; value = Math.NaN; intValue = 0; boolValue = false;
		stringValue = ""; progress = Math.NaN; stacks = -1; timeLeft = Math.NaN; code = UNKNOWN_SIGNAL;
	}
}
