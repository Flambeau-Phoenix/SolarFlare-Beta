package solarflare.aura;

/** Observer-owned. Never store this record or its engine ref in UI/config state. */
class StatusRecord {
	public var ref:Dynamic;
	public var generation:Int;
	public var identity = new AuraStatusSnap();
	public var sourceResolved:Bool = false;
	public var lastReadAt:Float = 0;
	public var seenSweep:Int = -1;
	public var stacks:Int = 0;
	public var stacksKnown:Bool = false;
	public var startTime:Float = 0;
	public var duration:Float = 0;
	public var refreshDuration:Float = 0;
	public var state:String = "unknown";
	public var source:String = "discovered";
	public function new(ref:Dynamic, generation:Int) {
		this.ref = ref; this.generation = generation;
	}
}
