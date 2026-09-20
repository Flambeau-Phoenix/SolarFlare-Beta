package solarflare.runtime;

/** Allocation-free counters exposed to the opt-in performance panel. */
class RuntimeMetrics {
	public static var hookEdges:Int = 0;
	public static var coalescedEdges:Int = 0;
	public static var fastPasses:Int = 0;
	public static var heavyPasses:Int = 0;
	public static var backgroundPasses:Int = 0;
	public static var identityPolls:Int = 0;
	public static var vitalsPolls:Int = 0;
	public static var statusPolls:Int = 0;
	public static var skillPolls:Int = 0;
	public static var targetPolls:Int = 0;
	public static var encounterPolls:Int = 0;
	public static var auraTicks:Int = 0;
	public static var layoutRecoveryPolls:Int = 0;
	public static var eventQueued:Int = 0;
	public static var eventDrained:Int = 0;
	public static var eventDropped:Int = 0;
	public static var maxQueueDepth:Int = 0;

	public static function reset():Void {
		hookEdges = coalescedEdges = 0;
		fastPasses = heavyPasses = backgroundPasses = 0;
		identityPolls = vitalsPolls = statusPolls = skillPolls = 0;
		targetPolls = encounterPolls = auraTicks = layoutRecoveryPolls = 0;
		eventQueued = eventDrained = eventDropped = maxQueueDepth = 0;
	}

	public static function toJson():String {
		return haxe.Json.stringify({
			hookEdges: hookEdges,
			coalescedEdges: coalescedEdges,
			passes: {fast: fastPasses, active: heavyPasses, background: backgroundPasses},
			polls: {identity: identityPolls, vitals: vitalsPolls, status: statusPolls,
				skills: skillPolls, target: targetPolls, encounter: encounterPolls, auras: auraTicks,
				layoutRecovery: layoutRecoveryPolls},
			events: {queued: eventQueued, drained: eventDrained, dropped: eventDropped,
				depth: EventRing.depth(), maxDepth: maxQueueDepth}
		});
	}
}
