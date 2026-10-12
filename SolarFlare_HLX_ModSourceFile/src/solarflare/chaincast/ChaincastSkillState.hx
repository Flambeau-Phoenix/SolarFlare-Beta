package solarflare.chaincast;

/** Reused presentation state built exclusively from frozen cooldown primitives. */
class ChaincastSkillState {
	public static inline var UNLINKED = 0;
	public static inline var UNKNOWN = 1;
	public static inline var READY = 2;
	public static inline var COOLDOWN = 3;
	public var state:Int = UNLINKED;
	public var remaining:Float = 0;
	public var progress:Float = 0;
	public var label:String = "LINK SKILL";
	// Retained labels: no countdown strings are allocated in the render loop.
	static final tenths = [for (i in 0...100) Std.string(Std.int(i / 10)) + "." + Std.string(i % 10) + "s"];
	static final seconds = [for (i in 0...601) Std.string(i) + "s"];

	public function new() {}

	public function update(linked:Bool, present:Bool, valid:Bool, ready:Bool, left:Float, total:Float):Void {
		remaining = 0;
		progress = 0;
		state = !linked ? UNLINKED : (!present || !valid ? UNKNOWN : (ready ? READY : COOLDOWN));
		label = state == UNLINKED ? "LINK SKILL" : "NO DATA";
		if (state == READY) {
			progress = 1;
			label = "OFF CD";
		} else if (state == COOLDOWN) {
			// Native readiness wins (a charge may be available during recharge).
			// A blocked cooldown may have no usable duration; keep X without inventing time.
			label = "ON CD";
			if (Math.isFinite(left) && left > 0) {
				remaining = left;
				label = left < 9.9 ? tenths[Std.int(Math.ceil(left * 10))] :
					(left <= 600 ? seconds[Std.int(Math.ceil(left))] : "600s+");
				if (Math.isFinite(total) && total > 0)
					progress = Math.max(0, Math.min(1, 1 - left / total));
			}
		}
	}
}
