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
	public static var barHudNodes:Int = 0;
	public static var barHudMs:Float = 0;
	public static var barHudMaxMs:Float = 0;
	public static var layoutRecoveryPolls:Int = 0;
	public static var eventQueued:Int = 0;
	public static var eventDrained:Int = 0;
	public static var eventDropped:Int = 0;
	public static var maxQueueDepth:Int = 0;
	public static var clipChecks:Int = 0;
	public static var clipUpdates:Int = 0;
	public static var clipReleases:Int = 0;
	public static var clipFailures:Int = 0;

	public static function reset():Void {
		StatusWorkMetrics.reset();
		hookEdges = coalescedEdges = 0;
		fastPasses = heavyPasses = backgroundPasses = 0;
		identityPolls = vitalsPolls = statusPolls = skillPolls = 0;
		targetPolls = encounterPolls = auraTicks = layoutRecoveryPolls = 0;
		barHudNodes = 0; barHudMs = barHudMaxMs = 0;
		eventQueued = eventDrained = eventDropped = maxQueueDepth = 0;
		clipChecks = clipUpdates = clipReleases = clipFailures = 0;
	}

	public static function toJson():String {
		var statusSeconds = StatusWorkMetrics.elapsedSeconds();
		return haxe.Json.stringify({
			hookEdges: hookEdges,
			coalescedEdges: coalescedEdges,
			passes: {fast: fastPasses, active: heavyPasses, background: backgroundPasses},
			cursor: {checks: clipChecks, updates: clipUpdates, releases: clipReleases, failures: clipFailures},
			polls: {identity: identityPolls, vitals: vitalsPolls, status: statusPolls,
				skills: skillPolls, target: targetPolls, encounter: encounterPolls, auras: auraTicks,
				layoutRecovery: layoutRecoveryPolls},
			statusWork: {
				measurementSeconds: statusSeconds,
				identityResolutionsPerSecond: StatusWorkMetrics.identityResolutions / statusSeconds,
				stateReadsPerSecond: StatusWorkMetrics.stateReads / statusSeconds,
				identityCacheEnabled: StatusWorkMetrics.identityCacheEnabled,
				stateRefreshEnabled: StatusWorkMetrics.stateRefreshEnabled,
				identityResolutions: StatusWorkMetrics.identityResolutions,
				identityCacheHits: StatusWorkMetrics.identityCacheHits,
				stateReads: StatusWorkMetrics.stateReads,
				stateFallbacks: StatusWorkMetrics.stateFallbacks,
				ingestAllocations: StatusWorkMetrics.ingestAllocations,
				recordAllocations: StatusWorkMetrics.recordAllocations,
				discoveryEntries: StatusWorkMetrics.discoveryEntries,
				slices: StatusWorkMetrics.discoverySlices,
				completedSweeps: StatusWorkMetrics.discoveryCompletions,
				lastEntries: StatusWorkMetrics.lastSliceEntries,
				maxEntries: StatusWorkMetrics.maxSliceEntries,
				lastMs: StatusWorkMetrics.lastSliceSeconds * 1000,
				maxMs: StatusWorkMetrics.maxSliceSeconds * 1000,
				typedLookups: StatusWorkMetrics.typedLookups,
				lastTypedSubjects: StatusWorkMetrics.lastTypedSubjects,
				maxTypedSubjects: StatusWorkMetrics.maxTypedSubjects,
				lastTypedMs: StatusWorkMetrics.lastTypedSeconds * 1000,
				maxTypedMs: StatusWorkMetrics.maxTypedSeconds * 1000,
				samples: StatusWorkMetrics.samples,
				lastSampleMs: StatusWorkMetrics.lastSampleSeconds * 1000,
				maxSampleMs: StatusWorkMetrics.maxSampleSeconds * 1000,
				lastRebuildRows: StatusWorkMetrics.lastRebuildRows,
				maxRebuildRows: StatusWorkMetrics.maxRebuildRows,
				lastRebuildMs: StatusWorkMetrics.lastRebuildSeconds * 1000,
				maxRebuildMs: StatusWorkMetrics.maxRebuildSeconds * 1000
			},
			barHudWork: {nodes: barHudNodes, lastMs: barHudMs, maxMs: barHudMaxMs},
			events: {queued: eventQueued, drained: eventDrained, dropped: eventDropped,
				depth: EventRing.depth(), maxDepth: maxQueueDepth}
		});
	}
}
