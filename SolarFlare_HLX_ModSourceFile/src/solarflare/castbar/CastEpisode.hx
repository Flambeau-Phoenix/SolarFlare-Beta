package solarflare.castbar;

import solarflare.castbar.CastDurationResolver.CastDuration;

/** One observed cast step. Object identities and native ingress delimit repeated uses. */
class CastEpisode {
	static var nextSerial:Int = 0;
	public var serial(default, null):Int = 0;
	public var sampled:Bool = false;
	public var frozen:CastDuration = null;
	public var observedRank(default, null):Null<Int> = null;
	var unit:Dynamic;
	var skill:Dynamic;
	var id:String = "";
	var elapsed:Float = 0;
	var seenAt:Float = 0;
	public function new() {}
	public function matches(value:Dynamic):Bool return skill != null && skill == value;
	public function reset():Void { unit = skill = null; id = ""; observedRank = null; serial = 0; sampled = false; frozen = null; elapsed = seenAt = 0; }
	public function update(owner:Dynamic, value:Dynamic, skillId:String, observedRank:Null<Int>, rawElapsed:Float, now:Float):Bool {
		// Native start/stop ingress resets this state, even between demand ticks.
		var fresh = serial == 0 || owner != unit || value != skill || skillId != id
			|| (Math.isFinite(rawElapsed) && rawElapsed + 0.01 < elapsed);
		if (fresh) { serial = ++nextSerial; sampled = false; frozen = null; this.observedRank = observedRank; }
		unit = owner; skill = value; id = skillId;
		if (Math.isFinite(rawElapsed)) elapsed = rawElapsed;
		seenAt = now;
		return fresh;
	}
}
