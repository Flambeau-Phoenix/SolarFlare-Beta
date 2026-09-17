package solarflare.aura;

import solarflare.EngineSkillId;
import solarflare.FieldWalk;

/** One-shot duration stamp for a status id, taken on its apply edge. */
class StatusStamp {
	/** Wall-clock expiry. Meaningless when infinite. */
	public var endsAt:Float = 0;
	public var totalDur:Float = 0;
	public var infinite:Bool = false;
	/**
	 * Wall-clock re-resolve deadline for infinite stamps. SkillRemain reports infinite for
	 * anything over MAX_FINITE_LEFT, so "infinite" may just mean "long"; without a recheck
	 * a 5-minute buff would stay infinite forever and never show a countdown.
	 */
	public var recheckAt:Float = 0;
	/** "live" or "cdb" — which resolver produced the span. */
	public var source:String = "";

	public function new() {}
}

/**
 * Frozen local-hero status snaps for AuraEngine. Observe-only: typed getStatus /
 * BaseSkill duration getters, then FieldWalk list walk. Draw never reads this.
 *
 * Poll authority: 20 Hz accumulator, dirty-wake via ObserveDemand.auraStatusDirty.
 * Expiry authority: SkillRemain left <= 0.02 clears present (recycled snaps start absent).
 */
class AuraStatusCache {
	public static inline var MAX:Int = solarflare.aura.signal.AuraSignalFrame.MAX_STATUSES;
	/** 20 Hz sample ceiling unless ObserveDemand.auraStatusDirty wakes early. */
	public static inline var SAMPLE_INTERVAL_S:Float = 0.05;
	public static var snaps:Array<AuraStatusSnap> = [];
	public static var count:Int = 0;
	public static var domainKnown:Bool = false;
	/** Full container length before scan cap; -1 when unavailable. */
	public static var containerLength:Int = -1;
	static var sampledHero:Dynamic;
	static var lastSampleAt:Float = 0;
	/**
	 * One-shot duration stamps keyed by lowercased status id.
	 *
	 * Must live outside the snaps: reset() clears every snap on each pass, so a stamp
	 * stored on the snap would be thrown away before it could save any work. Cleared on
	 * hero change, and per-id by the lifecycle hooks that actually move a duration.
	 */
	static var stamps = new Map<String, StatusStamp>();

	public static function reset():Void {
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

	/**
	 * Gate: skip unless hero change or 50 ms elapsed.
	 *
	 * Dirty wakes are throttled by ObserveDemand.dueAuraStatus, which consumes the flag
	 * before this runs; this gate is the single 20 Hz authority. Status removal does not
	 * wait for a pass, it lands immediately through markAbsent.
	 */
	public static function sample(hero:Dynamic):Void {
		var now = stamp();
		var heroChanged = hero != null && hero != sampledHero;
		if (!heroChanged && (now - lastSampleAt) < SAMPLE_INTERVAL_S)
			return;
		lastSampleAt = now;
		solarflare.ObserveDemand.auraStatusDirty = false;

		if (heroChanged)
			stamps.clear();
		reset();
		if (hero == null)
			return;
		sampledHero = hero;
		if (solarflare.debug.ResolutionLedger.armed())
			solarflare.debug.ResolutionLedger.touch("status.sample", "observe", "AuraStatusCache.sample", "hero", "bool", "true");
		// Query configured IDs first so list truncation cannot hide requested procs.
		for (id in solarflare.ObserveDemand.statusIds) lookupTyped(id);
		walkList(hero, "statuses");
		if (containerLength < 0)
			walkList(hero, "statusList");
	}

	public static function find(want:String):AuraStatusSnap {
		if (want == null || want.length < 2)
			return null;
		var i = 0;
		while (i < count) {
			var s = snaps[i];
			if (s != null && s.known && s.present && matches(s, want))
				return s;
			i++;
		}
		return null;
	}

	/**
	 * Drop a one-shot stamp so the next pass re-resolves the duration. Called from the
	 * Status hooks that change a live timer (refresh / extend / remove).
	 */
	public static function invalidateStamp(want:String):Void {
		if (want == null || want.length < 2)
			return;
		stamps.remove(want.toLowerCase());
		// Hooks report `kind`, but stamps are keyed on ids[0] (the EngineSkillId form).
		// Those are often different spellings of the same status, so clear by alias set.
		var i = 0;
		while (i < count) {
			var s = snaps[i];
			if (s != null && s.id.length > 0 && matches(s, want))
				stamps.remove(s.id.toLowerCase());
			i++;
		}
	}

	/** Immediate expiry from Status.onRemove — includes already-absent snaps. */
	public static function markAbsent(want:String):Void {
		if (want == null || want.length < 2)
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

	static function walkList(owner:Dynamic, name:String):Void {
		var arr = FieldWalk.extractObject(owner, name);
		if (arr == null)
			return;
		var len = FieldWalk.arrayLen(arr, -1);
		if (len < 0) return;
		containerLength = len;
		var complete = len <= MAX;
		if (len > MAX) len = MAX;
		var i = 0;
		while (i < len) {
			var item = FieldWalk.arrayAt(arr, i);
			if (item == null || ingest(item) == null) complete = false;
			i++;
		}
		domainKnown = domainKnown || complete;
	}

	static function allocSnap():AuraStatusSnap {
		if (count < snaps.length) {
			var reuse = snaps[count];
			reuse.clear();
			return reuse;
		}
		var snap = new AuraStatusSnap();
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
		pushId(snap, EngineSkillId.ofSkill(item));
		pushId(snap, skillIdOf(item));
		var inf = FieldWalk.extractObject(item, "inf");
		pushId(snap, FieldWalk.extractString(inf, "id"));
		pushId(snap, FieldWalk.extractString(inf, "script"));
		pushId(snap, FieldWalk.extractString(item, "kind"));
		if (snap.ids.length == 0)
			return null;
		snap.id = snap.ids[0];
		snap.stacks = readStacks(item);
		applyRemain(snap, item);
		if (!snap.present) {
			// Keep known-absent row for typed ids; do not count as active.
			snap.stacks = 0;
		}
		var i = 0;
		while (i < count) {
			var existing = snaps[i];
			if (matches(existing, snap.id)) {
				if (existing.known) {
					copySnap(existing, snap);
					return existing;
				}
				existing.clear();
				copySnap(existing, snap);
				return existing;
			}
			i++;
		}
		count++;
		return snap;
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
		var key = snap.id.toLowerCase();
		var st = stamps.get(key);
		if (st != null && (st.infinite ? now < st.recheckAt : now < st.endsAt)) {
			applyStamp(snap, st, now);
			return;
		}
		if (st != null)
			stamps.remove(key);

		// Live first so haste / talent-modified spans are captured exactly.
		var rp = solarflare.SkillRemain.read(item);
		if (rp.valid) {
			if (rp.infinite) {
				stampInfinite(snap, key);
				return;
			}
			if (rp.left <= 0.02) {
				// Genuinely expired — do not stamp, the status is about to drop.
				snap.durationKnown = true;
				snap.infinite = false;
				snap.present = false;
				snap.progress = 0;
				snap.left = rp.left < 0 ? 0 : rp.left;
				snap.stacks = 0;
				return;
			}
			stampFinite(snap, key, rp.left, rp.progress, now, "live");
			return;
		}

		// No usable live timer: fall back to the baked CastleDB span, if the id has one.
		var cdb = resolveCdbDuration(snap);
		if (cdb > 0.05) {
			stampFinite(snap, key, cdb, Math.NaN, now, "cdb");
			return;
		}

		// Present but untimed — visible with no countdown.
		snap.durationKnown = false;
		snap.infinite = false;
		snap.progress = 1;
		snap.left = 0;
		snap.endsAt = 0;
		snap.totalDur = 0;
		snap.stampSource = "";
		snap.present = true;
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
		var st = new StatusStamp();
		st.endsAt = now + left;
		st.totalDur = total;
		st.infinite = false;
		st.source = src;
		stamps.set(key, st);
		applyStamp(snap, st, now);
	}

	/** 1 Hz re-resolve: 20x cheaper than the raw poll, still catches the drop under 60s. */
	static inline var INFINITE_RECHECK_S:Float = 1.0;

	static function stampInfinite(snap:AuraStatusSnap, key:String):Void {
		var now = stamp();
		var st = new StatusStamp();
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
		snap.present = true;
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
		dst.ids.resize(0);
		dst.idsLower.resize(0);
		var j = 0;
		while (j < src.ids.length) {
			dst.ids.push(src.ids[j]);
			dst.idsLower.push(src.idsLower[j]);
			j++;
		}
		dst.stacks = src.stacks;
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
			var h:ent.GameObject = cast hero;
			var n = h.getStatusCount(want, null);
			if (n > 0) {
				snap = ingest(h.getStatus(want, null));
				if (snap != null)
					pushId(snap, want);
			}
			if (snap == null) {
				snap = allocSnap();
				snap.id = want;
				pushId(snap, want);
				snap.present = false;
				snap.stacks = 0;
				count++;
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
		}
		return snap;
	}

	static function readStacks(item:Dynamic):Int {
		var n = 1;
		try {
			var st:st.skill.Status = item;
			if (st.stacks > 1)
				n = st.stacks;
			try {
				var info = st.getStatusInfo();
				if (info != null && info.stacks > 1)
					n = info.stacks;
			} catch (_:Dynamic) {}
		} catch (_:Dynamic) {
			var s = Std.int(FieldWalk.extractNumber(item, "stacks", 1));
			if (s > 1)
				n = s;
		}
		if (n < 1)
			n = 1;
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
		var s = StringTools.trim(id);
		if (s.length < 2)
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
		var w = StringTools.trim(want);
		if (w.length < 2)
			return false;
		var shown = EngineSkillId.display(w);
		if (shown.length > 0)
			w = shown;
		var wl = w.toLowerCase();
		var i = 0;
		while (i < snap.idsLower.length) {
			if (snap.idsLower[i] == wl)
				return true;
			i++;
		}
		return false;
	}

	static function stamp():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}
}
