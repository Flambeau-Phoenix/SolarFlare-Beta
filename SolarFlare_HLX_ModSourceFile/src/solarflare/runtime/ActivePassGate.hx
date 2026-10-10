package solarflare.runtime;

/** Demand-aware cadence; take pending edges before consumers can raise new ones. */
class ActivePassGate {
	public static inline var INTERVAL:Float = 0.050;
	static inline var DOMAINS:Int = DirtyDomains.STATUS | DirtyDomains.SKILLS | DirtyDomains.TARGET;
	var lastRun:Float = -1;
	public function new() {}
	public function due(now:Float, wanted:Int, active:Bool):Bool {
		var pending = HookIngress.consumeMask(DOMAINS & wanted);
		if (!active) {
			lastRun = -1;
			return false;
		}
		if (pending == 0 && lastRun >= 0 && now - lastRun < INTERVAL)
			return false;
		lastRun = now;
		return true;
	}
	public function reset():Void lastRun = -1;
}
