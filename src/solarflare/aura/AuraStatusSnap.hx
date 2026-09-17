package solarflare.aura;

class AuraStatusSnap {
	public var id:String = "";
	public var ids:Array<String> = [];
	public var idsLower:Array<String> = [];
	public var stacks:Int = 1;
	public var known:Bool = true;
	public var present:Bool = true;
	public var durationKnown:Bool = false;
	/** Remaining duration ratio 0..1 when the engine exposes it; else 1 while present. */
	public var progress:Float = 1;
	/** Seconds left when getDurationLeft is exposed; else 0. Infinite → SkillRemain.INFINITE_LEFT. */
	public var left:Float = 0;
	public var infinite:Bool = false;
	/** Wall-clock expiry from the one-shot stamp; 0 when this status is unstamped. */
	public var endsAt:Float = 0;
	/** Full span the stamp was taken over, for progress without a live getter. */
	public var totalDur:Float = 0;
	/** Which resolver won the stamp: "live", "cdb", or "" while unstamped. */
	public var stampSource:String = "";

	public function new() {}

	public function clear():Void {
		id = "";
		ids.resize(0);
		idsLower.resize(0);
		stacks = 0;
		known = true;
		present = false;
		durationKnown = false;
		progress = 1;
		left = 0;
		infinite = false;
		endsAt = 0;
		totalDur = 0;
		stampSource = "";
	}
}
