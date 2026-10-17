package solarflare.runtime;

/** Allocation-free counters exposed to the opt-in performance panel. */
class RuntimeMetrics {
	public static var hookEdges:Int = 0;
	/** BaseSkill.doStart invocations for every unit in the world (all players, foes), and how many were the local hero's. */
	public static var skillStartHooks:Int = 0;
	public static var skillStartLocal:Int = 0;
	/** Enemy-cast funnel: where BaseSkill.doStart casts drop out before an aura can see them. */
	public static var castSeen:Int = 0;      // CombatLogCache.noteCast entered
	public static var castLive:Int = 0;      // passed the demand gate and is not a passive
	public static var castCaptured:Int = 0;  // shouldCapture: you / yours / your target / in combat with you
	public static var castEnemy:Int = 0;     // owner classified as an enemy
	public static var castTracked:Int = 0;   // skill id is one an aura asked for (ObserveDemand.castSkillIds)
	public static var castWanted:Int = 0;    // not about you, but an aura asked for it: handed to the enemy-cast cache
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
	public static var barterNativeSamples:Int=0;
	public static var barterNativeEntries:Int=0;
	public static var barterNativeMs:Float=0;
	public static var barterNativeMaxMs:Float=0;
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
		solarflare.ui.NativeVisibilityWork.reset();
		hookEdges = coalescedEdges = skillStartHooks = skillStartLocal = 0;
		castSeen = castLive = castCaptured = castEnemy = castTracked = castWanted = 0;
		fastPasses = heavyPasses = backgroundPasses = 0;
		identityPolls = vitalsPolls = statusPolls = skillPolls = 0;
		targetPolls = encounterPolls = auraTicks = layoutRecoveryPolls = 0;
		barHudNodes = 0; barHudMs = barHudMaxMs = 0;
		barterNativeSamples=barterNativeEntries=0; barterNativeMs=barterNativeMaxMs=0;
		eventQueued = eventDrained = eventDropped = maxQueueDepth = 0;
		clipChecks = clipUpdates = clipReleases = clipFailures = 0;
	}

	public static function toJson():String {
		var statusSeconds = StatusWorkMetrics.elapsedSeconds();
		return haxe.Json.stringify({
			hookEdges: hookEdges,
			coalescedEdges: coalescedEdges,
			skillStarts: {all: skillStartHooks, local: skillStartLocal},
			castFunnel: {seen: castSeen, live: castLive, captured: castCaptured, enemy: castEnemy, tracked: castTracked, wanted: castWanted},
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
			nativeVisibilityWork: {lastMs: solarflare.ui.NativeVisibilityWork.lastMs, maxMs: solarflare.ui.NativeVisibilityWork.maxMs,
				scans: solarflare.ui.NativeVisibilityWork.scans, nodes: solarflare.ui.NativeVisibilityWork.nodes,
				lateMs: solarflare.ui.NativeVisibilityWork.lateMs, lateMaxMs: solarflare.ui.NativeVisibilityWork.lateMaxMs},
			barterNativeWork: {samples:barterNativeSamples,entries:barterNativeEntries,lastMs:barterNativeMs,maxMs:barterNativeMaxMs},
			events: {queued: eventQueued, drained: eventDrained, dropped: eventDropped,
				depth: EventRing.depth(), maxDepth: maxQueueDepth}
		});
	}
}
