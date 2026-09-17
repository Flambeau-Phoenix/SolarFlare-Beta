package solarflare;

/** One FieldWalk ladder attempt. `value` is live — classify immediately, do not store. */
@:keep
class ProbeHit {
	public var name:String = "";
	public var step:String = "miss";
	public var value:Dynamic = null;
	public var usable:Bool = false;

	public function new() {}
}
