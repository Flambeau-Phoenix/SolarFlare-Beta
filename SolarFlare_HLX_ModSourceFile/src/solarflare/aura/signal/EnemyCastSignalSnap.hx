package solarflare.aura.signal;

/** Frozen enemy cast edge for event.cast.* signals. */
class EnemyCastSignalSnap {
	/** Local cast sequence when used in playerCasts; enemy readers ignore this. */
	public var serial:Int = 0;
	public var statusIds:Array<String> = [];
	public var statusKnown:Bool = false;
	public var skillId:String = "";
	public var age:Float = Math.NaN;
	public var active:Bool = false;
	public var known:Bool = false;

	public function new() {}

	public function reset():Void {
		serial = 0;
		statusIds = null;
		statusKnown = false;
		skillId = "";
		age = Math.NaN;
		active = false;
		known = false;
	}
}
