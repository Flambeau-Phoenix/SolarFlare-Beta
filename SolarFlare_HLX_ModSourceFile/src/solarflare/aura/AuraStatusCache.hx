package solarflare.aura;

import solarflare.EngineSkillId;
import solarflare.FieldWalk;

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
	 * Gate: skip unless dirty wake, hero change, or 50 ms elapsed.
	 * Consumes ObserveDemand.auraStatusDirty on entry.
	 */
	public static function sample(hero:Dynamic):Void {
		var now = stamp();
		var dirty = solarflare.ObserveDemand.auraStatusDirty;
		var heroChanged = hero != null && hero != sampledHero;
		if (!dirty && !heroChanged && (now - lastSampleAt) < SAMPLE_INTERVAL_S)
			return;
		lastSampleAt = now;
		solarflare.ObserveDemand.auraStatusDirty = false;

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

	/** Immediate expiry from Status.onRemove — includes already-absent snaps. */
	public static function markAbsent(want:String):Void {
		if (want == null || want.length < 2)
			return;
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

	static function applyRemain(snap:AuraStatusSnap, item:Dynamic):Void {
		var rp = solarflare.SkillRemain.read(item);
		snap.progress = rp.valid ? rp.progress : 1;
		snap.left = rp.left;
		snap.infinite = rp.infinite;
		snap.durationKnown = rp.valid;
		if (rp.valid && !rp.infinite && rp.left <= 0.02) {
			snap.present = false;
			snap.progress = 0;
			snap.left = rp.left < 0 ? 0 : rp.left;
			snap.stacks = 0;
			return;
		}
		snap.present = true;
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
			} else if (snap.present) {
				// Re-check duration on typed hit (ingest already applied; reinforce).
				var item = h.getStatus(want, null);
				if (item != null)
					applyRemain(snap, item);
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
