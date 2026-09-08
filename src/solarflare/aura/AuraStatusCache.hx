package solarflare.aura;

import solarflare.EngineSkillId;
import solarflare.FieldWalk;
import solarflare.HealthCache;

/**
 * Frozen local-hero status snaps for AuraEngine. Observe-only: typed getStatus /
 * BaseSkill duration getters, then FieldWalk list walk. Draw never reads this.
 */
class AuraStatusCache {
	public static inline var MAX:Int = 48;
	public static var snaps:Array<AuraStatusSnap> = [];
	public static var count:Int = 0;

	public static function sample(hero:Dynamic):Void {
		snaps = [];
		count = 0;
		if (hero == null)
			return;
		walkList(hero, "statuses");
		if (count < 1)
			walkList(hero, "statusList");
	}

	public static function find(want:String):AuraStatusSnap {
		if (want == null || want.length < 2)
			return null;
		var i = 0;
		while (i < count) {
			var s = snaps[i];
			if (s != null && matches(s, want))
				return s;
			i++;
		}
		return lookupTyped(want);
	}

	static function walkList(owner:Dynamic, name:String):Void {
		var arr = FieldWalk.extractObject(owner, name);
		if (arr == null)
			return;
		var len = FieldWalk.arrayLen(arr);
		if (len > MAX)
			len = MAX;
		var i = 0;
		while (i < len) {
			ingest(FieldWalk.arrayAt(arr, i));
			i++;
		}
	}

	static function ingest(item:Dynamic):Void {
		if (item == null || count >= MAX)
			return;
		var snap = new AuraStatusSnap();
		pushId(snap, EngineSkillId.ofSkill(item));
		pushId(snap, skillIdOf(item));
		var inf = FieldWalk.extractObject(item, "inf");
		pushId(snap, FieldWalk.extractString(inf, "id"));
		pushId(snap, FieldWalk.extractString(inf, "script"));
		pushId(snap, FieldWalk.extractString(item, "kind"));
		if (snap.ids.length == 0)
			return;
		snap.id = snap.ids[0];
		snap.stacks = readStacks(item);
		var rp = solarflare.SkillRemain.read(item);
		snap.progress = rp.valid ? rp.progress : 1;
		snap.left = rp.left;
		snaps.push(snap);
		count++;
	}

	static function lookupTyped(want:String):AuraStatusSnap {
		var hero = HealthCache.localHero;
		if (hero == null)
			return null;
		var st:Dynamic = null;
		try {
			var h:ent.Hero = cast hero;
			st = h.getStatus(want, null);
			if (st == null) {
				var asGo:ent.GameObject = cast hero;
				st = h.getStatus(want, asGo);
			}
		} catch (_:Dynamic) {
			st = null;
		}
		if (st == null)
			return null;
		var before = count;
		ingest(st);
		if (count > before)
			return snaps[count - 1];
		return null;
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
		var i = 0;
		while (i < snap.ids.length) {
			if (snap.ids[i] == s)
				return;
			i++;
		}
		snap.ids.push(s);
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
		while (i < snap.ids.length) {
			var have = snap.ids[i];
			if (have == null)
				continue;
			var hl = have.toLowerCase();
			if (hl == wl)
				return true;
			if (wl.length >= 8 && hl.indexOf(wl) >= 0)
				return true;
			i++;
		}
		return false;
	}
}
