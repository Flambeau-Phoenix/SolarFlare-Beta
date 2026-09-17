package solarflare.combatlog;

/**
 * Runtime ownership only: IDs and display names never imply player ownership.
 *
 * GameLib (`ent.Foe`): `summonOwner` is the summoner GameObject; `summonSourceSkill`
 * is the BaseSkill that spawned the foe. Docs also mention `get_networkPropSummonOwner`
 * but that returns a network Int, not the unit pointer — prefer `summonOwner`.
 */
class CombatOwnership {
	public static function resolve(source:Dynamic, read:(Dynamic, String)->Dynamic, ownerOfSkill:Dynamic->Dynamic):Dynamic {
		var current = source;
		var seen:Array<Dynamic> = [];
		while (current != null && seen.length < 16) {
			if (seen.indexOf(current) >= 0)
				return null;
			seen.push(current);
			var next = summonOwnerOf(current, read);
			if (next == null && ownerOfSkill != null)
				next = ownerOfSkill(summonSourceSkillOf(current, read));
			if (next == null)
				return current;
			current = next;
		}
		return null;
	}

	/** Typed Foe.summonOwner first; FieldWalk fallback. */
	public static function summonOwnerOf(unit:Dynamic, read:(Dynamic, String)->Dynamic):Dynamic {
		if (unit == null)
			return null;
		try {
			var foe:ent.Foe = cast unit;
			if (foe != null) {
				var owner = foe.summonOwner;
				if (owner != null)
					return owner;
			}
		} catch (_:Dynamic) {}
		if (read != null)
			return read(unit, "summonOwner");
		return null;
	}

	public static function summonSourceSkillOf(unit:Dynamic, read:(Dynamic, String)->Dynamic):Dynamic {
		if (unit == null)
			return null;
		try {
			var foe:ent.Foe = cast unit;
			if (foe != null) {
				var skill = foe.summonSourceSkill;
				if (skill != null)
					return skill;
			}
		} catch (_:Dynamic) {}
		if (read != null)
			return read(unit, "summonSourceSkill");
		return null;
	}

	public static function isOwnedSummon(unit:Dynamic, read:(Dynamic, String)->Dynamic):Bool {
		return summonOwnerOf(unit, read) != null || summonSourceSkillOf(unit, read) != null;
	}
}
