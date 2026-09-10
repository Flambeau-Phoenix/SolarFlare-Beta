package solarflare.aura.signal;

class AuraResolvedValue {
	public var known:Bool = false;
	public var kind:AuraValueKind = Boolean;
	public var numberValue:Float = Math.NaN;
	public var intValue:Int = 0;
	public var boolValue:Bool = false;
	public var stringValue:String = "";
	public var present:Bool = false;
	public var progress:Float = Math.NaN;
	public var timeLeft:Float = Math.NaN;
	public var code:AuraDiagnosticCode = UNKNOWN_SIGNAL;
	public function new() {}
	public function reset():Void {
		known = false; kind = Boolean; numberValue = Math.NaN; intValue = 0; boolValue = false;
		stringValue = ""; present = false; progress = Math.NaN; timeLeft = Math.NaN; code = UNKNOWN_SIGNAL;
	}
}
