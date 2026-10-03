package solarflare.aura.signal;

class ConsumableSignalSnap {
	public var id:String = "";
	public var owned:Bool = false;
	public var count:Int = 0;
	public var known:Bool = false;
	public var usable:Bool = false;
	public var usableKnown:Bool = false;
	/** Observation accumulator: one failed stack must not become a confirmed false. */
	public var usabilityFailed:Bool = false;
	public function new() {}
	public function reset():Void { owned = false; count = 0; known = false; usable = false; usableKnown = false; usabilityFailed = false; }
}
