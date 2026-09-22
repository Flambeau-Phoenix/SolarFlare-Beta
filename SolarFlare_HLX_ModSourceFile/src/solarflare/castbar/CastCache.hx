package solarflare.castbar;

import solarflare.EngineSkillId;
import solarflare.geaux.GeauxCache;
import solarflare.ui.GameIcons;

/** Shared 20 Hz cast observer for the local player and current target. */
class CastCache {
	static var player = new CastSnap();
	static var target = new CastSnap();

	public static inline function playerSnap():CastSnap return player;
	public static inline function targetSnap():CastSnap return target;

	public static function observe(localHero:Dynamic, currentTarget:Dynamic):Void {
		fill(player, localHero);
		fill(target, currentTarget);
	}

	static function fill(out:CastSnap, unit:Dynamic):Void {
		if (out == null || unit == null) {
			if (out != null) out.clear();
			return;
		}
		try {
			var go:ent.GameObject = cast unit;
			var skill:st.skill.Skill = go.getActiveSkill();
			if (skill == null) {
				out.clear();
				return;
			}
			var elapsed:Float = skill.getCastElapsed();
			var remaining:Float = skill.getCastTimeLeft();
			if (!Math.isFinite(elapsed) || elapsed < 0) elapsed = 0;
			if (!Math.isFinite(remaining) || remaining < 0) remaining = 0;
			// isCasting() is the strict running-step predicate. Charge/hold skills can
			// expose their cast step timing slightly outside that narrow window, so
			// accept positive authoritative cast timing while an active skill exists.
			if (!skill.isCasting() && elapsed <= 0.001 && remaining <= 0.001) {
				out.clear();
				return;
			}
			var duration = elapsed + remaining;
			var id = EngineSkillId.ofSkill(skill);
			if (id.length == 0)
				id = GeauxCache.sanitizeSkillId(GeauxCache.getSkillId(skill));
			out.active = true;
			out.skillId = id;
			out.label = pretty(id);
			out.elapsed = elapsed;
			out.remaining = remaining;
			out.duration = duration;
			out.progress = duration > 0.001 ? clamp01(elapsed / duration) : 0;
			out.observedAt = haxe.Timer.stamp();
			if (id.length > 0)
				GameIcons.get(id);
		} catch (_:Dynamic) {
			out.clear();
		}
	}

	static function pretty(id:String):String {
		if (id == null || id.length == 0)
			return "Casting";
		var part = id;
		var split = id.lastIndexOf("_");
		if (split >= 0 && split + 1 < id.length)
			part = id.substr(split + 1);
		var out = "";
		for (i in 0...part.length) {
			var c = part.charAt(i);
			var code = part.charCodeAt(i);
			if (i > 0 && code >= 65 && code <= 90)
				out += " ";
			out += c;
		}
		return out.length > 0 ? out : "Casting";
	}

	static inline function clamp01(v:Float):Float return v < 0 ? 0 : (v > 1 ? 1 : v);
}
