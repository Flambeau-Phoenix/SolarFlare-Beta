package solarflare.aura.signal;


class AuraConditionDef {
	static var nextUiKey:Int = 1;
	/** Stable for the lifetime of this condition; intentionally not serialized. */
	public var uiKey(default, null):Int;
	public var signal:String = "";
	public var subject:String = "";
	public var subjectLabel:String = "";
	public var op:String = "";
	public var numberValue:Float = 0;
	public var boolValue:Bool = false;
	public var stringValue:String = "";
	public var negate:Bool = false;
	public function new() {
		uiKey = nextUiKey++;
		if (nextUiKey < 1)
			nextUiKey = 1;
	}

	public function clone():AuraConditionDef {
		var c = new AuraConditionDef();
		c.signal = signal; c.subject = subject; c.subjectLabel = subjectLabel; c.op = op;
		c.numberValue = numberValue; c.boolValue = boolValue; c.stringValue = stringValue; c.negate = negate;
		return c;
	}
}
