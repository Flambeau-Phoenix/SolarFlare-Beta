package solarflare.aura;

import solarflare.geaux.GeauxCache;

/**
 * Demand-gated enemy cast / channel snaps for aura signals.
 * Fed from CombatLogCache.noteCast (ROLE_ENEMY) + BaseSkill.doStop.
 * Observe may poll isRunning/isCasting; draw never walks live skills.
 */
class EnemyCastCache {
	public static inline var CAP:Int = 32;

	static var skillIds:Array<String> = [];
	static var startedAt:Array<Float> = [];
	static var active:Array<Bool> = [];
	/** Observe-only live identity for isRunning poll. */
	static var liveSkills:Array<Dynamic> = [];

	public static function keep():Void {}

	public static function noteStart(skill:Dynamic, skillId:String):Void {
		var sid = GeauxCache.sanitizeSkillId(skillId);
		if (sid.length == 0)
			return;
		var now = haxe.Timer.stamp();
		var i = indexOf(sid);
		if (i < 0) {
			if (skillIds.length >= CAP) {
				skillIds.pop();
				startedAt.pop();
				active.pop();
				liveSkills.pop();
			}
			skillIds.insert(0, sid);
			startedAt.insert(0, now);
			active.insert(0, true);
			liveSkills.insert(0, skill);
		} else {
			startedAt[i] = now;
			active[i] = true;
			liveSkills[i] = skill;
			bumpToFront(i);
		}
		if (solarflare.debug.ResolutionLedger.armed()) {
			solarflare.debug.ResolutionLedger.touch("enemy.cast.skillId", "typed", "EnemyCastCache.noteStart", "skillId", "string", sid);
			solarflare.debug.ResolutionLedger.touch("enemy.cast.active", "typed", "EnemyCastCache.noteStart", "active", "bool", "true");
		}
	}

	public static function noteStop(skill:Dynamic):Void {
		if (skill == null)
			return;
		var sid = skillIdOf(skill);
		if (sid.length > 0) {
			var i = indexOf(sid);
			if (i >= 0) {
				active[i] = false;
				liveSkills[i] = null;
				ledgerAge(sid, i);
				return;
			}
		}
		var j = 0;
		while (j < liveSkills.length) {
			if (liveSkills[j] == skill) {
				active[j] = false;
				liveSkills[j] = null;
				if (j < skillIds.length)
					ledgerAge(skillIds[j], j);
				return;
			}
			j++;
		}
	}

	/** Refresh active flags under ObserveDemand.aurasNeedEnemyCast. */
	public static function tick(now:Float):Void {
		if (!solarflare.ObserveDemand.aurasNeedEnemyCast)
			return;
		var i = 0;
		while (i < skillIds.length) {
			if (!active[i]) {
				i++;
				continue;
			}
			var sk = liveSkills[i];
			if (sk == null) {
				active[i] = false;
				i++;
				continue;
			}
			var running = false;
			try {
				var bs:st.skill.BaseSkill = sk;
				if (bs != null)
					running = bs.isRunning();
			} catch (_:Dynamic) {}
			if (!running) {
				try {
					var typed:st.skill.Skill = sk;
					if (typed != null)
						running = typed.isCasting();
				} catch (_:Dynamic) {}
			}
			if (!running) {
				active[i] = false;
				liveSkills[i] = null;
			}
			i++;
		}
	}

	public static function ageOf(skillId:String):Float {
		var i = indexOf(GeauxCache.sanitizeSkillId(skillId));
		if (i < 0)
			return Math.NaN;
		var age = haxe.Timer.stamp() - startedAt[i];
		if (age < 0)
			age = 0;
		return age;
	}

	public static function isActive(skillId:String):Bool {
		var i = indexOf(GeauxCache.sanitizeSkillId(skillId));
		return i >= 0 && active[i];
	}

	public static function known(skillId:String):Bool {
		return indexOf(GeauxCache.sanitizeSkillId(skillId)) >= 0;
	}

	static function indexOf(sid:String):Int {
		if (sid == null || sid.length == 0)
			return -1;
		var low = sid.toLowerCase();
		var i = 0;
		while (i < skillIds.length) {
			if (skillIds[i].toLowerCase() == low)
				return i;
			i++;
		}
		return -1;
	}

	static function bumpToFront(i:Int):Void {
		if (i <= 0)
			return;
		var sid = skillIds[i];
		var t = startedAt[i];
		var a = active[i];
		var sk = liveSkills[i];
		skillIds.splice(i, 1);
		startedAt.splice(i, 1);
		active.splice(i, 1);
		liveSkills.splice(i, 1);
		skillIds.insert(0, sid);
		startedAt.insert(0, t);
		active.insert(0, a);
		liveSkills.insert(0, sk);
	}

	static function skillIdOf(skill:Dynamic):String {
		if (skill == null)
			return "";
		try {
			return GeauxCache.sanitizeSkillId(GeauxCache.getSkillId(skill));
		} catch (_:Dynamic) {
			return "";
		}
	}

	static function ledgerAge(sid:String, i:Int):Void {
		if (!solarflare.debug.ResolutionLedger.armed() || i < 0 || i >= startedAt.length)
			return;
		var age = haxe.Timer.stamp() - startedAt[i];
		solarflare.debug.ResolutionLedger.touch("enemy.cast.active", "typed", "EnemyCastCache.noteStop", "active", "bool", "false");
		solarflare.debug.ResolutionLedger.touch("enemy.cast.age", "typed", "EnemyCastCache", "age", "number", Std.string(Math.round(age * 1000) / 1000));
	}
}
