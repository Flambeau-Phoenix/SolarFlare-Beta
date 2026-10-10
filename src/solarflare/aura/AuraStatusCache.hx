package solarflare.aura;

import solarflare.EngineSkillId;
import solarflare.FieldWalk;

/** Duration stamp for an observed status. Candidate builds periodically refresh live timers. */
class StatusStamp {
	/** Wall-clock expiry. Meaningless when infinite. */
	public var endsAt:Float = 0;
	public var totalDur:Float = 0;
	public var infinite:Bool = false;
	/**
	 * Wall-clock re-resolve deadline. The candidate rechecks finite live timers at 10 Hz
	 * and explicit infinite timers at 1 Hz; the default route retains its previous policy.
	 */
	public var recheckAt:Float = 0;
	/** "live" or "cdb" — which resolver produced the span. */
	public var source:String = "";

	public function new() {}
}

/**
 * Frozen local-hero status snaps for AuraEngine. Observe-only: typed getStatus /
 * BaseSkill duration getters. Board/builder discovery is incremental; count and
 * overflow read length only. Neither can trigger a full container ingest per tick.
 *
 * Poll authority: 20 Hz accumulator, dirty-wake via ObserveDemand.auraStatusDirty.
 * Expiry authority: SkillRemain left <= 0.02 clears present (recycled snaps start absent).
 */
class AuraStatusCache {
	public static inline var MAX:Int = solarflare.aura.signal.AuraSignalFrame.MAX_STATUSES;
	/** 20 Hz ceiling shared by all consumers, including coalesced dirty requests. */
	public static inline var SAMPLE_INTERVAL_S:Float = 0.05;
	/** Broad discovery is sliced; adding a consumer never raises its work budget. */
	public static inline var DISCOVERY_INTERVAL_S:Float = 0.50;
	public static inline var DISCOVERY_WAKE_S:Float = 0.10;
	public static inline var DISCOVERY_ENTRIES_PER_SLICE:Int = 16;
	public static inline var DISCOVERY_BUDGET_S:Float = 0.001;
	public static inline var TYPED_SUBJECTS_PER_SLICE:Int = 16;
	/** Retained refs require live O1 proof. Candidate flags opt in; normal builds collect baseline metrics. */
	public static var identityCacheEnabled:Bool = #if (solarflare_status_identity || solarflare_status_state) true #else false #end;
	public static var stateRefreshEnabled:Bool = #if solarflare_status_state true #else false #end;
	public static inline var STATE_SUBJECTS_PER_SLICE:Int = 192;
	public static inline var WORK_BUDGET_S:Float = 0.002;
	public static inline var URGENT_SHARE:Float = 0.60;
	static var records = new haxe.ds.ObjectMap<Dynamic, StatusRecord>();
	static var bindings = new Map<String, StatusRecord>();
	static var recordCount:Int = 0;
	static var generation:Int = 0;
	static var sweep:Int = 0;
	static var passDeadline:Float = 0;
	static var cacheMode:Int = -1;
	static var work = solarflare.runtime.StatusWorkMetrics;
	public static var snaps:Array<AuraStatusSnap> = [];
	public static var count:Int = 0;
	public static var revision:Int = 0;
	public static var domainKnown:Bool = false;
	/** Full container length before scan cap; -1 when unavailable. */
	public static var containerLength:Int = -1;
	static var sampledHero:Dynamic;
	static var lastSampleAt:Float = 0;
	// Primitive discovery rows survive fast demanded polls. No game objects reach UI.
	static var discovered = new Map<String, AuraStatusSnap>();
	static var scanSeen = new Map<String, Bool>();
	static var scanArray:Dynamic;
	static var scanCursor:Int = 0;
	static var scanLength:Int = -1;
	static var scanActive:Bool = false;
	static var scanComplete:Bool = false;
	static var nextDiscoveryAt:Float = 0;
	static var lastDiscoveryStart:Float = -1;
	static var discoveryWanted:Bool = false;
	static var discoveredCount:Int = 0;
	static var targeted = new Map<String, AuraStatusSnap>();
	static var typedCursor:Int = 0;
	static var rowsExact = new Map<String, AuraStatusSnap>();
	static var rowsAlias = new Map<String, AuraStatusSnap>();
	static var rowsApplied = new Map<String, AuraStatusSnap>();
	static var discoveryCompletedThisPass:Bool = false;
	/**
	 * One-shot duration stamps keyed by lowercased status id.
	 *
	 * Must live outside the snaps: reset() clears every snap on each pass, so a stamp
	 * stored on the snap would be thrown away before it could save any work. Cleared on
	 * hero change and explicit invalidations. Candidate builds also resample timers and
	 * prune absent IDs after complete container observations; status hooks are currently retired.
	 */
	static var stamps = new Map<String, StatusStamp>();

	public static function reset():Void {
		clearRecords();
		clearDiscovery();
		targeted.clear(); typedCursor = 0;
		stamps.clear();
		lastSampleAt = -1;
		resetSnapshots();
	}
	static function clearRecords():Void {
		generation++;
		for (record in records) record.ref = null;
		records.clear(); bindings.clear(); recordCount = 0;
	}
	/** Called on profile/character transitions even when no status consumer is active. */
	public static function invalidateOwner():Void reset();
	static function resetSnapshots():Void {
		rowsExact.clear(); rowsAlias.clear(); rowsApplied.clear();
		revision++;
		count = 0;
		domainKnown = false;
		sampledHero = null;
		containerLength = -1;
		var i = 0;
		while (i < snaps.length) {
			var s = snaps[i];
			if (s != null)
				s.clear();
			i++;
		}
	}

	public static function isCurrent(hero:Dynamic):Bool return hero != null && sampledHero == hero;
	/** Cached primitives only, captured at local skill-use before deferred proc consumption. */
	public static function capturePresentIds(hero:Dynamic):Array<String> {
		var ids:Array<String> = [];
		if (!isCurrent(hero)) return ids;
		for (i in 0...count) {
			var s = snaps[i];
			if (s != null && s.known && s.present) for (id in s.idsLower) ids.push(id);
		}
		return ids;
	}

	/**
	 * Gate: skip unless hero change or 50 ms elapsed.
	 *
	 * Dirty wakes are throttled by ObserveDemand.dueAuraStatus, which consumes the flag
	 * before this runs; this gate is the single 20 Hz authority. Status removal does not
	 * wait for a pass, it lands immediately through markAbsent.
	 */
	public static function sample(hero:Dynamic, observedAt:Null<Float> = null):Void {
		var now = observedAt == null ? stamp() : observedAt;
		var heroChanged = hero != sampledHero;
		var mode = (identityCacheEnabled ? 1 : 0) | (stateRefreshEnabled ? 2 : 0);
		var modeChanged = mode != cacheMode;
		if (!heroChanged && !modeChanged && (now - lastSampleAt) < SAMPLE_INTERVAL_S)
			return;
		cacheMode = mode;
		lastSampleAt = now;
		var sampleStarted = stamp();
		work.identityCacheEnabled = identityCacheEnabled;
		work.stateRefreshEnabled = stateRefreshEnabled && identityCacheEnabled;
		solarflare.ObserveDemand.auraStatusDirty = false;

		if (heroChanged || modeChanged) {
			clearRecords();
			stamps.clear();
			clearDiscovery();
			targeted.clear(); typedCursor = 0;
		}
		resetSnapshots();
		if (hero == null)
		{ clearRecords(); clearDiscovery(); stamps.clear(); targeted.clear(); typedCursor = 0; return; }
		sampledHero = hero;
		#if solarflare_telemetry
		if (solarflare.debug.ResolutionLedger.armed())
			solarflare.debug.ResolutionLedger.touch("status.sample", "observe", "AuraStatusCache.sample", "hero", "bool", "true");
		#end
		// Count/overflow need length only, never status ingestion. Targeted values
		// stay on the fast path while broad discovery has its own bounded budget.
		measureContainer(hero);
		passDeadline = stamp() + WORK_BUDGET_S;
		sampleTargeted();
		var fast = stateRefreshEnabled && identityCacheEnabled;
		if (!fast) publishTargeted();
		var publishDiscovery = solarflare.ObserveDemand.auraBuilderOpen
			|| solarflare.ObserveDemand.barterBuilderOpen
			|| solarflare.ObserveDemand.statusBoard;
		// Held refs require periodic membership reconciliation even with builders hidden.
		var wantDiscovery = publishDiscovery || (fast && wantedBuf.length > 0);
		if (wantDiscovery) {
			if (!discoveryWanted) { nextDiscoveryAt = 0; solarflare.ObserveDemand.statusDiscoveryDirty = true; }
			discoverSlice(hero, now);
			if (fast) publishTargeted();
			domainKnown = domainKnown && !scanActive && scanComplete;
			var rebuildStarted = stamp(); var rebuildRows = 0;
			for (key => cached in discovered) if (publishDiscovery && findByWant(cached.id) == null && count < MAX) {
				var out = allocSnap(); copySnap(out, cached);
				var span = stamps.get(key);
				if (span != null) applyStamp(out, span, now);
				count++; rebuildRows++;
				indexRow(out);
			}
			work.lastRebuildRows = rebuildRows;
			if (rebuildRows > work.maxRebuildRows) work.maxRebuildRows = rebuildRows;
			work.lastRebuildSeconds = stamp() - rebuildStarted;
			if (work.lastRebuildSeconds > work.maxRebuildSeconds) work.maxRebuildSeconds = work.lastRebuildSeconds;
			if (discoveryCompletedThisPass) pruneAbsentStamps();
		} else if (discoveryWanted) {
			clearDiscovery();
		}
		if (!wantDiscovery && fast) publishTargeted();
		discoveryWanted = wantDiscovery;
		work.samples++;
		work.lastSampleSeconds = stamp() - sampleStarted;
		if (work.lastSampleSeconds > work.maxSampleSeconds) work.maxSampleSeconds = work.lastSampleSeconds;
	}

	static function clearDiscovery():Void {
		discovered.clear(); discoveredCount = 0; scanSeen.clear(); scanArray = null;
		scanCursor = 0; scanLength = -1; scanActive = scanComplete = discoveryWanted = false;
		nextDiscoveryAt = 0; lastDiscoveryStart = -1;
		work.lastSliceEntries = 0; work.lastSliceSeconds = 0;
	}

	static var wantedBuf:Array<String> = [];
	static var wantedKeysBuf = new Map<String, Bool>();
	static var staleBuf:Array<String> = [];
	static function collectWanted(subjects:Iterable<String>, wanted:Array<String>, keys:Map<String, Bool>):Void {
		for (id in subjects) {
			var key = StatusIdentity.key(id);
			if (key.length > 0 && !keys.exists(key)) { keys.set(key, true); wanted.push(id); }
		}
	}

	/** Round-robin only demanded subjects; small configurations still update at 20 Hz. */
	static function sampleTargeted():Void {
		var wanted = wantedBuf; wanted.resize(0);
		var wantedKeys = wantedKeysBuf; wantedKeys.clear();
		collectWanted(solarflare.ObserveDemand.statusIds, wanted, wantedKeys);
		collectWanted(solarflare.ObserveDemand.barterStatusIds, wanted, wantedKeys);
		var started = stamp(); work.lastTypedSubjects = 0; work.lastTypedSeconds = 0;
		var n = wanted.length;
		if (n == 0) { targeted.clear(); bindings.clear(); typedCursor = 0; return; }
		if (typedCursor >= n) typedCursor = 0;
		var fast = stateRefreshEnabled && identityCacheEnabled;
		var amount = Std.int(Math.min(n, fast ? STATE_SUBJECTS_PER_SLICE : TYPED_SUBJECTS_PER_SLICE));
		var nativeStarted = work.typedLookups;
		for (_ in 0...amount) {
			if (work.lastTypedSubjects > 0 && (stamp() >= (fast ? passDeadline - WORK_BUDGET_S * (1 - URGENT_SHARE) : started + DISCOVERY_BUDGET_S)
				|| work.typedLookups - nativeStarted >= TYPED_SUBJECTS_PER_SLICE)) break;
			var want = wanted[typedCursor]; typedCursor = (typedCursor + 1) % n;
			var row = lookupTyped(want); work.lastTypedSubjects++;
			if (row == null) continue;
			var key = want.toLowerCase(); var cached = targeted.get(key);
			if (cached == null) { cached = new AuraStatusSnap(); targeted.set(key, cached); }
			copySnap(cached, row);
		}
		if (work.lastTypedSubjects > work.maxTypedSubjects) work.maxTypedSubjects = work.lastTypedSubjects;
		work.lastTypedSeconds = stamp() - started;
		if (work.lastTypedSeconds > work.maxTypedSeconds) work.maxTypedSeconds = work.lastTypedSeconds;
		staleBuf.resize(0);
		for (key in targeted.keys()) if (!wantedKeys.exists(key)) staleBuf.push(key);
		for (key in staleBuf) targeted.remove(key);
		staleBuf.resize(0);
		for (key in bindings.keys()) if (!wantedKeys.exists(key)) staleBuf.push(key);
		for (key in staleBuf) bindings.remove(key);
	}
	/** Primitive publication runs after both observation lanes, outside the native allowance. */
	static function publishTargeted():Void {
		for (want in wantedBuf) {
			if (findByWant(want) != null || count >= MAX) continue;
			var cached = targeted.get(want.toLowerCase());
			var out = allocSnap();
			if (cached == null) { out.id = want; pushId(out, want); out.known = false; }
			else {
				copySnap(out, cached);
				var span = stamps.get(stampKey(out));
				if (out.present && span != null) applyStamp(out, span, stamp());
			}
			count++;
			indexRow(out);
		}
	}
	public static function resetWorkMetrics():Void work.reset();

	/** A slice pays at most 16 ingests and stops after 1 ms between entries. */
	static function discoverSlice(hero:Dynamic, now:Float):Void {
		discoveryCompletedThisPass = false;
		work.lastSliceEntries = 0; work.lastSliceSeconds = 0;
		if (stateRefreshEnabled && identityCacheEnabled && stamp() >= passDeadline) return;
		var dirty = solarflare.ObserveDemand.statusDiscoveryDirty;
		if (!scanActive && now < nextDiscoveryAt
			&& !(dirty && now - lastDiscoveryStart >= DISCOVERY_WAKE_S)) return;
		var started = stamp();
		var arr = FieldWalk.extractObject(hero, "statuses");
		if (arr == null) arr = FieldWalk.extractObject(hero, "statusList");
		var len = FieldWalk.arrayLen(arr, -1);
		if (len < 0) { scanActive = false; scanArray = null; scanComplete = false; nextDiscoveryAt = now + DISCOVERY_INTERVAL_S; return; }
		if (!scanActive || arr != scanArray) {
			sweep++;
			scanArray = arr; scanLength = len; scanCursor = 0; scanSeen.clear();
			scanActive = true; scanComplete = true; lastDiscoveryStart = now;
			solarflare.ObserveDemand.statusDiscoveryDirty = false;
		} else if (len != scanLength) {
			// A status applied or removed mid-sweep must not restart it: a busy status list changes
			// faster than a budgeted sweep finishes, so entries late in the list were never reached.
			// Keep the cursor; an indexing shift means this sweep cannot certify absence.
			scanLength = len; scanComplete = false;
		}
		var end = Std.int(Math.min(len, MAX));
		while (scanCursor < end && work.lastSliceEntries < DISCOVERY_ENTRIES_PER_SLICE) {
			if (work.lastSliceEntries > 0 && (stamp() - started >= DISCOVERY_BUDGET_S
				|| (stateRefreshEnabled && identityCacheEnabled && stamp() >= passDeadline))) break;
			var item = FieldWalk.arrayAt(arr, scanCursor++);
			var row = item == null ? null : ingest(item);
			var record = item == null ? null : records.get(item);
			if (record != null) record.seenSweep = sweep;
			work.lastSliceEntries++; work.discoveryEntries++;
			if (row == null) { scanComplete = false; continue; }
			var key = stampKey(row); scanSeen.set(key, true);
			var cached = discovered.get(key);
			if (cached == null) {
				if (discoveredCount >= MAX) continue;
				cached = new AuraStatusSnap(); discovered.set(key, cached); discoveredCount++;
			}
			copySnap(cached, row);
		}
		work.discoverySlices++;
		work.lastSliceSeconds = stamp() - started;
		if (work.lastSliceEntries > work.maxSliceEntries) work.maxSliceEntries = work.lastSliceEntries;
		if (work.lastSliceSeconds > work.maxSliceSeconds) work.maxSliceSeconds = work.lastSliceSeconds;
		if (scanCursor >= end) {
			scanActive = false; scanArray = null; nextDiscoveryAt = now + DISCOVERY_INTERVAL_S;
			if (!scanComplete) nextDiscoveryAt = now + DISCOVERY_WAKE_S;
			if (scanComplete && len <= MAX) {
				// Retire refs only after a complete, valid walk; failed/truncated scans retain them.
				var retired:Array<Dynamic> = [];
				for (ref => record in records) if (record.seenSweep != sweep) retired.push(ref);
				for (ref in retired) retireRecord(records.get(ref));
				var gone = [for (key in discovered.keys()) if (!scanSeen.exists(key)) key];
				for (key in gone) { discovered.remove(key); discoveredCount--; stamps.remove(key); }
				work.discoveryCompletions++;
				discoveryCompletedThisPass = true;
			} else scanComplete = false;
		}
		// An incomplete sweep cannot certify a complete present-state capture.
		domainKnown = domainKnown && !scanActive && scanComplete;
	}

	/** Cheap length only — no per-status FieldWalk / SkillRemain. */
	static function measureContainer(owner:Dynamic):Void {
		containerLength = -1;
		domainKnown = false;
		var arr = FieldWalk.extractObject(owner, "statuses");
		if (arr == null)
			arr = FieldWalk.extractObject(owner, "statusList");
		if (arr == null)
			return;
		var len = FieldWalk.arrayLen(arr, -1);
		if (len < 0)
			return;
		containerLength = len;
		domainKnown = true;
	}

	/** Exact applied IDs take precedence over shared observed aliases. */
    public static function findExact(want:String):AuraStatusSnap return findByWant(want);
    public static function find(want:String):AuraStatusSnap {
		var s = findByWant(want);
		return s != null && s.known && s.present ? s : null;
	}

	/**
	 * Drop a one-shot stamp so the next pass re-resolves the duration. Called from the
	 * Status hooks that change a live timer (refresh / extend / remove).
	 */
	public static function invalidateStamp(want:String):Void {
		if (want == null || want.length == 0)
			return;
		stamps.remove(want.toLowerCase());
		// Hooks report `kind`, but stamps are keyed on ids[0] (the EngineSkillId form).
		// Those are often different spellings of the same status, so clear by alias set.
		var i = 0;
		while (i < count) {
			var s = snaps[i];
			if (s != null && s.id.length > 0 && matches(s, want))
				stamps.remove(s.id.toLowerCase() + (s.sourceItemId.length > 0 ? ":" + s.sourceItemId.toLowerCase() : ""));
			i++;
		}
	}

	/** Immediate expiry from Status.onRemove — includes already-absent snaps. */
	public static function markAbsent(want:String):Void {
		revision++;
		if (want == null || want.length == 0)
			return;
		invalidateStamp(want);
		var i = 0;
		while (i < count) {
			var s = snaps[i];
			if (s != null && matches(s, want)) {
				s.present = false;
				s.stacks = 0;
				s.left = 0;
				s.progress = 0;
			}
			i++;
		}
	}


	static function allocSnap():AuraStatusSnap {
		if (count < snaps.length) {
			var reuse = snaps[count];
			reuse.clear();
			return reuse;
		}
		var snap = new AuraStatusSnap();
		work.ingestAllocations++;
		snap.clear();
		snaps.push(snap);
		return snap;
	}

	/**
	 * Ingest one status object. Expired finite timers (SkillRemain) are stored as
	 * present=false and are not treated as active by find().
	 */
	static function ingest(item:Dynamic):AuraStatusSnap {
		if (item == null || count >= MAX)
			return null;
		var snap = allocSnap();
		var record = identityCacheEnabled ? records.get(item) : null;
		if (record != null && (record.generation != generation || record.ref == null)) record = null;
		if (record == null && identityCacheEnabled && recordCount < MAX) {
			record = new StatusRecord(item, generation);
			records.set(item, record); recordCount++; work.recordAllocations++;
		}
		if (record != null && record.identity.id.length > 0) {
			copySnap(snap, record.identity); work.identityCacheHits++;
		} else {
			work.identityResolutions++;
			pushId(snap, skillIdOf(item));
			pushId(snap, EngineSkillId.ofSkill(item));
			var inf = FieldWalk.extractObject(item, "inf");
			pushId(snap, FieldWalk.extractString(inf, "id"));
			pushId(snap, FieldWalk.extractString(inf, "script"));
			pushId(snap, FieldWalk.extractString(item, "kind"));
			if (snap.ids.length == 0)
				return null;
			snap.id = snap.ids[0];
		}
		if ((record == null || !record.sourceResolved) && (solarflare.ObserveDemand.aurasNeedConsumables || solarflare.ObserveDemand.auraBuilderOpen || solarflare.ObserveDemand.statusBoard)) {
			try {
				var base:st.skill.BaseSkill = item;
				var source = base.getSourceItem();
				snap.sourceItemId = source == null ? "" : solarflare.EngineText.cleanId(source.kind);
				snap.sourceItemKnown = true;
				if (record != null) record.sourceResolved = true;
			} catch (_:Dynamic) {}
			if (snap.sourceItemId.length == 0) {
				for (alias in snap.ids) {
					var c = solarflare.cdb.ConsumableCatalog.findByStatus(alias);
					if (c != null) {
						snap.sourceItemId = c.id;
						snap.sourceItemKnown = true;
						if (record != null) record.sourceResolved = true;
						break;
					}
				}
			}
		}
		if (record != null) copySnap(record.identity, snap);
		if (stateRefreshEnabled && record != null) readState(record, snap);
		else {
			work.stateReads++;
			var observedStacks = readStacks(item);
			snap.stacksKnown = observedStacks >= 0;
			snap.stacks = observedStacks < 0 ? 0 : observedStacks;
			applyRemain(snap, item);
			if (record != null) {
				record.lastReadAt = stamp(); record.stacks = snap.stacks; record.stacksKnown = snap.stacksKnown;
				record.state = snap.known ? "live" : "unknown";
			}
		}
		if (snap.known && !snap.present) {
			// Keep known-absent row for typed ids; do not count as active.
			snap.stacks = 0;
		}
		var existing = findExistingSnap(snap);
		if (existing != null) {
			copySnap(existing, snap);
			indexRow(existing);
			return existing;
		}
		count++;
		indexRow(snap);
		return snap;
	}

	static function retireRecord(record:StatusRecord):Void {
		if (record == null || record.ref == null) return;
		records.remove(record.ref); recordCount--;
		stamps.remove(stampKey(record.identity));
		record.ref = null; record.state = "gone";
		for (key => binding in bindings) if (binding == record) {
			var cached = targeted.get(key);
			if (cached != null) setGone(cached);
			var row = findByWant(key);
			if (row != null) setGone(row);
		}
	}
	static function setGone(snap:AuraStatusSnap):Void {
		snap.known = true; snap.present = false; snap.stacksKnown = true; snap.stacks = 0;
		snap.durationKnown = false; snap.left = snap.progress = snap.endsAt = snap.totalDur = 0;
		snap.infinite = false; snap.stampSource = "";
	}

	/** Typed state only. Use the engine elapsed clock; startTime is not wall-clock time. */
	static function readState(record:StatusRecord, snap:AuraStatusSnap):Void {
		work.stateReads++;
		var removalKnown = false;
		try {
			var status:st.skill.Status = record.ref;
			var removed = status.removed; removalKnown = true;
			if (removed) {
				setGone(snap);
				retireRecord(record); return;
			}
			record.stacks = status.stacks;
			record.startTime = status.startTime;
			record.duration = status.duration;
			record.refreshDuration = status.refreshDuration;
			if (!Math.isFinite(record.duration) || !Math.isFinite(record.startTime) || !Math.isFinite(record.refreshDuration)) throw "invalid timing";
			var now = stamp();
			if (status.isInfinite()) stampInfinite(snap, stampKey(snap));
			else {
				// Preserve SkillRemain's distinction between an untimed zero and finite expiry.
				if (record.duration <= 0.05) throw "no finite duration domain";
				var elapsed = status.getElapsedTime();
				if (!Math.isFinite(elapsed)) throw "invalid elapsed time";
				var left = Math.max(0, record.duration - elapsed);
				// Status overrides progress; keep its semantics (including refreshDuration).
				var progress = status.getDurationProgress();
				if (!Math.isFinite(progress) || progress < 0 || progress > 1.01) progress = left / record.duration;
				stampFinite(snap, stampKey(snap), left, clamp01(progress), now, "live");
			}
			record.stacksKnown = record.stacks >= 0;
			snap.stacksKnown = record.stacksKnown; snap.stacks = record.stacksKnown ? record.stacks : 0;
			snap.known = true; record.lastReadAt = now; record.state = "live";
		} catch (_:Dynamic) {
			work.stateFallbacks++;
			// Legacy state ladders preserve partial knowledge; no identity work on this fallback.
			var stacks = readStacks(record.ref);
			snap.stacksKnown = stacks >= 0; snap.stacks = stacks < 0 ? 0 : stacks;
			applyRemain(snap, record.ref);
			if (!removalKnown) snap.known = false;
			record.state = "unknown";
		}
	}

	/** Distinct applied statuses must never merge through a guessed suffix or shared category. */
	static function findExistingSnap(incoming:AuraStatusSnap):AuraStatusSnap {
		var same = rowsApplied.get(stampKey(incoming));
		if (same != null) return same;
		for (id in incoming.idsLower) {
			var existing = rowsExact.get(id);
			if (existing != null && StatusIdentity.sameApplied(existing,incoming)) return existing;
		}
		return null;
	}
	static function indexRow(row:AuraStatusSnap):Void {
		rowsApplied.set(stampKey(row), row);
		var key = row.id.toLowerCase();
		var exact = rowsExact.get(key);
		if (exact == null || !exact.present || row.present) rowsExact.set(key, row);
		for (alias in row.idsLower) {
			var old = rowsAlias.get(alias);
			if (old == null || !old.present) rowsAlias.set(alias, row);
		}
	}
	/**
	 * Stamp-once duration. A live stamp is answered by arithmetic with no native calls;
	 * only a miss pays SkillRemain's ladder, and only then do we fall back to the CDB.
	 *
	 * An elapsed stamp is dropped and re-resolved rather than trusted, so a status that
	 * outlives its stamp self-heals on the next pass instead of vanishing.
	 */
	static function applyRemain(snap:AuraStatusSnap, item:Dynamic):Void {
		var now = stamp();
		var key = stampKey(snap);
		var st = stamps.get(key);
		if (st != null && solarflare.EngineTimerMath.reuseDurationStamp(now, st.recheckAt, st.endsAt, st.infinite)) {
			applyStamp(snap, st, now);
			return;
		}
		// Re-read the actual Status timer to catch refreshes, extensions and modifiers.
		var rp = solarflare.SkillRemain.read(item);
		if (rp.valid) {
			if (rp.infinite) { stampInfinite(snap, key); return; }
			stampFinite(snap, key, rp.left < 0 ? 0 : rp.left, rp.progress, now, "live");
			return;
		}
		// A failed read may retain an unexpired observation, but cannot renew its span.
		if (st != null) {
			st.recheckAt = now + 0.1;
			if (st.infinite || now < st.endsAt) { applyStamp(snap, st, now); return; }
		} else {
			var cdb = resolveCdbDuration(snap);
			if (cdb > 0.05) { stampFinite(snap, key, cdb, Math.NaN, now, "cdb"); return; }
		}
		// An expired estimate is not evidence of removal. Observed presence remains true.
		snap.durationKnown = false;
		snap.infinite = false;
		snap.progress = 1;
		snap.left = 0;
		snap.endsAt = 0;
		snap.totalDur = 0;
		snap.stampSource = "";
		snap.present = true;
	}

	static function stampKey(snap:AuraStatusSnap):String {
		return snap.id.toLowerCase() + (snap.sourceItemId.length > 0 ? ":" + snap.sourceItemId.toLowerCase() : "");
	}

	static function pruneAbsentStamps():Void {
		// Missing/truncated containers cannot prove absence or establish a new apply edge.
		if (!domainKnown || containerLength < 0 || containerLength > MAX) return;
		var seen = new Map<String, Bool>();
		for (i in 0...count) {
			var snap = snaps[i];
			if (snap != null && snap.known && snap.present) seen.set(stampKey(snap), true);
		}
		var remove:Array<String> = [];
		for (key in stamps.keys()) if (!seen.exists(key)) remove.push(key);
		for (key in remove) stamps.remove(key);
	}

	/** Longest CDB span across the snap's alias set; ids vary by how the status was found. */
	static function resolveCdbDuration(snap:AuraStatusSnap):Float {
		var best = 0.0;
		var i = 0;
		while (i < snap.ids.length) {
			var d = solarflare.cdb.CdbAuraTable.listedSpan(snap.ids[i]);
			if (d > best)
				best = d;
			i++;
		}
		return best;
	}

	static function stampFinite(snap:AuraStatusSnap, key:String, left:Float, prog:Float, now:Float, src:String):Void {
		// Recover the full span from progress when the engine exposes it, so a status
		// first seen mid-drain still gets a correct denominator.
		var total = left;
		if (!Math.isNaN(prog) && prog > 0.02 && prog <= 1.0001) {
			var implied = left / prog;
			if (implied > total)
				total = implied;
		}
		var st = stamps.get(key);
		if (st == null) st = new StatusStamp();
		st.endsAt = now + left;
		st.totalDur = total;
		st.infinite = false;
		st.recheckAt = now + 0.1;
		st.source = src;
		stamps.set(key, st);
		applyStamp(snap, st, now);
	}

	/** 1 Hz re-resolve: 20x cheaper than the raw poll, still catches the drop under 60s. */
	static inline var INFINITE_RECHECK_S:Float = 1.0;

	static function stampInfinite(snap:AuraStatusSnap, key:String):Void {
		var now = stamp();
		var st = stamps.get(key);
		if (st == null) st = new StatusStamp();
		st.infinite = true;
		st.recheckAt = now + INFINITE_RECHECK_S;
		st.source = "live";
		stamps.set(key, st);
		applyStamp(snap, st, now);
	}

	/** Pure arithmetic — the steady-state path, and the reason this rework exists. */
	static function applyStamp(snap:AuraStatusSnap, st:StatusStamp, now:Float):Void {
		snap.durationKnown = true;
		snap.infinite = st.infinite;
		snap.stampSource = st.source;
		snap.present = st.infinite || st.source != "live" || st.endsAt - now > 0.02;
		if (st.infinite) {
			snap.left = solarflare.SkillRemain.INFINITE_LEFT;
			snap.progress = 1;
			snap.endsAt = 0;
			snap.totalDur = 0;
			return;
		}
		var left = st.endsAt - now;
		if (left < 0)
			left = 0;
		snap.left = left;
		snap.endsAt = st.endsAt;
		snap.totalDur = st.totalDur;
		snap.progress = st.totalDur > 0.05 ? clamp01(left / st.totalDur) : 1;
	}

	static function clamp01(v:Float):Float {
		if (v < 0)
			return 0;
		return v > 1 ? 1 : v;
	}

	static function copySnap(dst:AuraStatusSnap, src:AuraStatusSnap):Void {
		dst.id = src.id;
		dst.sourceItemId = src.sourceItemId; dst.sourceItemKnown = src.sourceItemKnown;
		dst.ids.resize(0);
		dst.idsLower.resize(0);
		var j = 0;
		while (j < src.ids.length) {
			dst.ids.push(src.ids[j]);
			dst.idsLower.push(src.idsLower[j]);
			j++;
		}
		dst.stacks = src.stacks;
		dst.stacksKnown = src.stacksKnown;
		dst.known = src.known;
		dst.present = src.present;
		dst.durationKnown = src.durationKnown;
		dst.progress = src.progress;
		dst.left = src.left;
		dst.infinite = src.infinite;
		dst.endsAt = src.endsAt;
		dst.totalDur = src.totalDur;
		dst.stampSource = src.stampSource;
	}

	static function lookupTyped(want:String):AuraStatusSnap {
		var hero = sampledHero;
		if (hero == null)
			return null;
		if (count >= MAX) return null;
		var snap:AuraStatusSnap = null;
		try {
			var binding = stateRefreshEnabled && identityCacheEnabled ? bindings.get(StatusIdentity.key(want)) : null;
			if (binding != null && binding.ref != null && binding.generation == generation) {
				snap = ingest(binding.ref);
				if (snap != null && binding.ref != null) { indexRow(snap); return snap; }
			}
			work.typedLookups++;
			var h:ent.GameObject = cast hero;
			var applied = h.getStatus(want, null);
			if (applied != null) {
				// Stacks come from the applied object (typed Status.stacks); getStatusCount would
				// repeat the same linear scan for the same field.
				snap = ingest(applied);
				var observedRecord = identityCacheEnabled ? records.get(applied) : null;
				if (observedRecord != null) observedRecord.source = "typed";
				if (snap != null)
					pushId(snap, want);
				if (stateRefreshEnabled && identityCacheEnabled) {
					var record = records.get(applied);
					if (record != null && record.ref != null) {
						pushId(record.identity, want);
						bindings.set(StatusIdentity.key(want), record);
					}
				}
			}
			if (snap == null) {
				// Merge into any walked row that already aliases this demand id.
				var existing = findByWant(want);
				if (existing != null) {
					pushId(existing, want);
					snap = existing;
				} else {
					snap = allocSnap();
					snap.id = want;
					pushId(snap, want);
					snap.present = false;
					snap.stacks = 0;
					count++;
				}
			}
		} catch (_:Dynamic) {
			snap = allocSnap();
			snap.id = want;
			pushId(snap, want);
			snap.known = false;
			snap.present = false;
			snap.stacks = 0;
			count++;
		}
		#if solarflare_telemetry
		if (solarflare.debug.ResolutionLedger.armed() && snap != null) {
			var id = solarflare.debug.ResolutionLedger.cleanId(want);
			if (id.length == 0)
				id = "unknown";
			solarflare.debug.ResolutionLedger.touch(
				"status.present",
				"typed",
				"AuraStatusCache.lookupTyped",
				id,
				"bool",
				snap.present ? "true" : "false",
				snap.known ? "known" : "unknown"
			);
			if (snap.present)
				solarflare.debug.ResolutionLedger.touch(
					"status.stacks",
					"getStatusCount",
					"AuraStatusCache.lookupTyped",
					id,
					"int",
					Std.string(snap.stacks),
					"typed"
				);
		}
		#end
		if (snap != null) indexRow(snap);
		return snap;
	}

	static function findByWant(want:String):AuraStatusSnap {
		var key = StatusIdentity.key(want);
		if (key.length == 0) return null;
		var exact = rowsExact.get(key);
		return exact != null ? exact : rowsAlias.get(key);
	}

	/**
	 * Prefer typed Status.stacks (incl. real 0). FieldWalk only on typed miss.
	 * Presence already established by walk/ingest — do not invent floor-1 over a known typed 0.
	 */
	static function readStacks(item:Dynamic):Int {
		var n = -1;
		var method = "miss";
		var typedOk = false;
		try {
			var st:st.skill.Status = item;
			var typed = st.stacks;
			typedOk = true;
			n = typed;
			method = "typed.stacks";
		} catch (_:Dynamic) {
			typedOk = false;
		}
		if (!typedOk) {
			var s = Std.int(FieldWalk.extractNumber(item, "stacks", -1));
			if (s >= 0) {
				n = s;
				method = "fieldwalk";
			}
		}
		// Unknown remains unknown; presentation must never invent a stack count.
		#if solarflare_telemetry
		if (solarflare.debug.ResolutionLedger.armed()) {
			var id = "";
			try
				id = solarflare.debug.ResolutionLedger.cleanId(skillIdOf(item))
			catch (_:Dynamic)
				id = "";
			if (id.length == 0)
				id = "unknown";
			solarflare.debug.ResolutionLedger.touch(
				"status.stacks",
				method,
				"AuraStatusCache.readStacks",
				id,
				"int",
				Std.string(n),
				method
			);
		}
		#end
		return n;
	}

	static function skillIdOf(item:Dynamic):String {
		if (item == null)
			return "";
		try {
			var s:st.skill.BaseSkill = item;
			var k = s.kind;
			if (k != null && k.length > 0)
				return k;
		} catch (_:Dynamic) {}
		var k = FieldWalk.extractString(item, "kind");
		if (k.length > 0)
			return k;
		var id = FieldWalk.extractString(item, "id");
		if (id.length > 0)
			return id;
		var inf = FieldWalk.extractObject(item, "inf");
		return FieldWalk.extractString(inf, "id");
	}

	static function pushId(snap:AuraStatusSnap, id:String):Void {
		if (id == null)
			return;
		var s = solarflare.EngineText.cleanId(id);
		if (s.length == 0)
			return;
		var shown = EngineSkillId.display(s);
		if (shown.length > 0)
			s = shown;
		var low = s.toLowerCase();
		var i = 0;
		while (i < snap.ids.length) {
			if (snap.ids[i] == s)
				return;
			i++;
		}
		snap.ids.push(s);
		snap.idsLower.push(low);
	}

	static function matches(snap:AuraStatusSnap, want:String):Bool {
		return StatusIdentity.matches(snap,want);
	}

	static function stamp():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}
}

