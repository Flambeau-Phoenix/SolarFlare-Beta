package solarflare.aura.signal;

/** Frozen enemy cast edge for event.cast.* signals. */
class EnemyCastSignalSnap {
	public var skillId:String = "";
	public var age:Float = Math.NaN;
	public var active:Bool = false;
	public var known:Bool = false;

	public function new() {}

	public function reset():Void {
		skillId = "";
		age = Math.NaN;
		active = false;
		known = false;
	}
}
