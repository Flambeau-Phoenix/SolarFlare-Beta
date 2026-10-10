package solarflare.runtime;

/** Primitive-only observation work counters; usable by native-boundary replays. */
class StatusWorkMetrics {
 public static var identityCacheEnabled:Bool = false;
 public static var stateRefreshEnabled:Bool = false;
 public static var identityResolutions:Int = 0;
 public static var identityCacheHits:Int = 0;
 public static var stateReads:Int = 0;
 public static var stateFallbacks:Int = 0;
 /** Snapshot pool growth, not a GC allocation estimate. */
 public static var ingestAllocations:Int = 0;
 public static var recordAllocations:Int = 0;
 static var startedAt:Float = haxe.Timer.stamp();
 public static function elapsedSeconds():Float return Math.max(0.000001, haxe.Timer.stamp() - startedAt);
 public static var discoveryEntries:Int = 0;
 public static var discoverySlices:Int = 0;
 public static var discoveryCompletions:Int = 0;
 public static var lastSliceEntries:Int = 0;
 public static var lastSliceSeconds:Float = 0;
 public static var maxSliceEntries:Int = 0;
 public static var maxSliceSeconds:Float = 0;
 public static var typedLookups:Int = 0;
 public static var lastTypedSubjects:Int = 0;
 public static var maxTypedSubjects:Int = 0;
 public static var lastTypedSeconds:Float = 0;
 public static var maxTypedSeconds:Float = 0;
 /** Whole AuraStatusCache.sample passes that ran (past the 50 ms gate). */
 public static var samples:Int = 0;
 public static var lastSampleSeconds:Float = 0;
 public static var maxSampleSeconds:Float = 0;
 /** Rows re-copied into the frozen snapshot from discovery cache per sample. */
 public static var lastRebuildRows:Int = 0;
 public static var maxRebuildRows:Int = 0;
 public static var lastRebuildSeconds:Float = 0;
 public static var maxRebuildSeconds:Float = 0;
 public static function reset():Void {
  startedAt = haxe.Timer.stamp();
  identityResolutions = identityCacheHits = stateReads = stateFallbacks = ingestAllocations = recordAllocations = 0;
  discoveryEntries = discoverySlices = discoveryCompletions = typedLookups = 0;
  lastSliceEntries = maxSliceEntries = lastTypedSubjects = maxTypedSubjects = 0;
  lastSliceSeconds = maxSliceSeconds = lastTypedSeconds = maxTypedSeconds = 0;
  samples = lastRebuildRows = maxRebuildRows = 0;
  lastSampleSeconds = maxSampleSeconds = lastRebuildSeconds = maxRebuildSeconds = 0;
 }
}
