package solarflare.castbar;

/** Frozen cast sample. Observe writes; ImGui draw code only copies/reads it. */
class CastSnap {
	public var active:Bool = false;
	public var skillId:String = "";
	public var label:String = "";
	public var elapsed:Float = 0;
	public var remaining:Float = 0;
	public var duration:Float = 0;
	public var observedRank:Null<Int> = null;
	public var durationSource:String = "unknown";
	public var durationEstimated:Bool = true;
	public var rawDuration:Float = 0;
	public var progress:Float = 0;
	public var observedAt:Float = 0;

	public function new() {}

	public function clear():Void {
		active = false;
		skillId = "";
		label = "";
		elapsed = 0;
		remaining = 0;
		duration = 0;
		observedRank = null;
		durationSource = "unknown";
		durationEstimated = true;
		rawDuration = 0;
		progress = 0;
		observedAt = 0;
	}

	public function copyFrom(src:CastSnap):Void {
		if (src == null) {
			clear();
			return;
		}
		active = src.active;
		skillId = src.skillId;
		label = src.label;
		elapsed = src.elapsed;
		remaining = src.remaining;
		duration = src.duration;
		observedRank = src.observedRank;
		durationSource = src.durationSource;
		durationEstimated = src.durationEstimated;
		rawDuration = src.rawDuration;
		progress = src.progress;
		observedAt = src.observedAt;
	}
}
