package solarflare.aura;

import solarflare.EngineSkillId;
import solarflare.FieldWalk;

/**
 * Frozen local-hero status snaps for AuraEngine. Observe-only: typed getStatus /
 * BaseSkill duration getters, then FieldWalk list walk. Draw never reads this.
 */
class AuraStatusCache {
	public static inline var MAX:Int = solarflare.aura.signal.AuraSignalFrame.MAX_STATUSES;
	public static var snaps:Array<AuraStatusSnap> = [];
	public static var count:Int = 0;
	public static var domainKnown:Bool = false;
	/** Full container length before scan cap; -1 when unavailable. */
	public static var containerLength:Int = -1;
	static var sampledHero:Dynamic;

	public static function reset():Void {
		count = 0;
		domainKnown = false;
		sampledHero = null;
		containerLength = -1;
	}

	public static function isCurrent(hero:Dynamic):Bool return hero != null && sampledHero == hero;

	public static function sample(hero:Dynamic):Void {
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
		snaps.push(snap);
		return snap;
	}

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
		var rp = solarflare.SkillRemain.read(item);
		snap.progress = rp.valid ? rp.progress : 1;
		snap.left = rp.left;
		snap.infinite = rp.infinite;
		snap.durationKnown = rp.valid;
		var i = 0;
		while (i < count) {
			var existing = snaps[i];
			if (matches(existing, snap.id)) {
				if (existing.known)
					return existing;
				existing.clear();
				copySnap(existing, snap);
				return existing;
			}
			i++;
		}
		count++;
		return snap;
	}

	static function copySnap(dst:AuraStatusSnap, src:AuraStatusSnap):Void {
		dst.id = src.id;
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
			if (n > 0) snap = ingest(h.getStatus(want, null));
			if (snap == null) {
				snap = allocSnap();
				snap.id = want;
				pushId(snap, want);
				snap.present = n > 0;
				snap.stacks = n;
				count++;
			} else pushId(snap, want);
		} catch (_:Dynamic) {
			snap = allocSnap();
			snap.id = want;
			pushId(snap, want);
			snap.known = false;
			snap.present = false;
			count++;
		}
		if (solarflare.debug.ResolutionLedger.armed() && snap != null)
			solarflare.debug.ResolutionLedger.touch(
				"status.present",
				"typed",
				"AuraStatusCache.lookupTyped",
				want,
				"bool",
				snap.present ? "true" : "false",
				snap.known ? "known" : "unknown"
			);
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
}
