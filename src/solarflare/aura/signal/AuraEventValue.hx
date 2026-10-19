package solarflare.aura.signal;

/** Frozen, non-consuming event value. Every reader sees the same episode. */
class AuraEventValue {
	public var known:Bool = false;
	public var age:Float = 1e9;
	public var serial:Int = 0;
	public function new() {}
}
