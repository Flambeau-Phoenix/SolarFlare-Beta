package solarflare.aura;

class AuraStatusSnap {
	public var id:String = "";
	public var ids:Array<String> = [];
	public var stacks:Int = 1;
	public var known:Bool = true;
	public var present:Bool = true;
	public var durationKnown:Bool = false;
	/** Remaining duration ratio 0..1 when the engine exposes it; else 1 while present. */
	public var progress:Float = 1;
	/** Seconds left when getDurationLeft is exposed; else 0. */
	public var left:Float = 0;

	public function new() {}
}
