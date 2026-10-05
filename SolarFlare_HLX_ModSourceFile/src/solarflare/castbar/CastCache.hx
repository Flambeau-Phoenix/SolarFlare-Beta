package solarflare.castbar;

import solarflare.EngineSkillId;
import solarflare.geaux.GeauxCache;
import solarflare.ui.GameIcons;

/** Shared 20 Hz cast observer for the local player and current target. */
class CastCache {
	static var player = new CastSnap();
	static var target = new CastSnap();
	static var playerEpisode = new CastEpisode();
	static var targetEpisode = new CastEpisode();
	static var playerStopped:Dynamic = null;
	static var targetStopped:Dynamic = null;

	public static inline function playerSnap():CastSnap return player;
	public static inline function targetSnap():CastSnap return target;

	public static function observe(localHero:Dynamic, currentTarget:Dynamic):Void {
		if (localHero == null) {
			player.clear(); target.clear(); playerEpisode.reset(); targetEpisode.reset();
			playerStopped = targetStopped = null;
			return;
		}
		fill(player, playerEpisode, localHero, "player");
		if (localHero != null && currentTarget == localHero) {
			target.copyFrom(player); targetEpisode.reset();
		} else fill(target, targetEpisode, currentTarget, "target");
	}

	/** Existing native lifecycle hooks only reset identity state; no getters or disk access. */
	public static function noteStart(skill:Dynamic):Void {
		if (playerStopped == skill) playerStopped = null;
		if (targetStopped == skill) targetStopped = null;
		if (playerEpisode.matches(skill)) playerEpisode.reset();
		if (targetEpisode.matches(skill)) targetEpisode.reset();
	}
	public static function noteStop(skill:Dynamic):Void {
		if (playerEpisode.matches(skill)) { playerStopped = skill; playerEpisode.reset(); player.clear(); }
		if (targetEpisode.matches(skill)) { targetStopped = skill; targetEpisode.reset(); target.clear(); }
	}

	static function fill(out:CastSnap, episode:CastEpisode, unit:Dynamic, actorSource:String):Void {
		if (out == null || unit == null) {
			if (out != null) out.clear();
			// Target loss hides the strip but preserves a sampled episode if reacquired.
			return;
		}
		try {
			var go:ent.GameObject = cast unit;
			var skill:st.skill.Skill = go.getActiveSkill();
			var stopped = actorSource == "player" ? playerStopped : targetStopped;
			if (skill != null && skill == stopped) { out.clear(); return; }
			if (actorSource == "player") playerStopped = null; else targetStopped = null;
			if (skill == null) {
				out.clear();
				episode.reset();
				return;
			}
			var elapsed:Float = skill.getCastElapsed();
			var remaining:Float = skill.getCastTimeLeft();
			var rawElapsed = elapsed;
			var rawRemaining = remaining;
			// isCasting() is the strict running-step predicate. Charge/hold skills can
			// expose their cast step timing slightly outside that narrow window, so
			// accept positive authoritative cast timing while an active skill exists.
			var haveTiming = Math.isFinite(rawElapsed) && rawElapsed > 0.001 || Math.isFinite(rawRemaining) && rawRemaining > 0.001;
			if (!skill.isCasting() && !haveTiming) {
				out.clear();
				episode.reset();
				return;
			}
			var id = EngineSkillId.ofSkill(skill);
			if (id.length == 0)
				id = GeauxCache.sanitizeSkillId(GeauxCache.getSkillId(skill));
			var rank = ObservedSkillRank.read(skill);
			var now = haxe.Timer.stamp();
			episode.update(unit, skill, id, rank, rawElapsed, now);
			rank = episode.observedRank;
			// Use untouched raw values; sanitized presentation and CDB never feed evidence.
			if (!episode.sampled)
				episode.sampled = LearnedCastTimes.observe(id, rank, episode.serial, rawElapsed, rawRemaining, actorSource);
			if (!Math.isFinite(elapsed) || elapsed < 0) elapsed = 0;
			if (!Math.isFinite(remaining) || remaining < 0) remaining = 0;
			if (episode.frozen == null) episode.frozen = LearnedCastTimes.resolve(id, rank);
			var duration = episode.frozen.seconds;
			out.active = true;
			out.skillId = id;
			out.label = pretty(id);
			out.elapsed = elapsed;
			out.remaining = remaining;
			out.duration = duration;
			out.observedRank = rank;
			out.durationSource = episode.frozen.source;
			out.durationEstimated = episode.frozen.estimated;
			out.rawDuration = Math.isFinite(rawElapsed + rawRemaining) ? rawElapsed + rawRemaining : 0;
			out.progress = duration > 0.001 ? clamp01(elapsed / duration)
				: elapsed + remaining > 0.001 ? clamp01(elapsed / (elapsed + remaining)) : 0;
			out.observedAt = now;
			if (id.length > 0)
				GameIcons.get(id);
		} catch (_:Dynamic) {
			out.clear();
			// A transient getter failure must not turn the next frame into a second episode.
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
