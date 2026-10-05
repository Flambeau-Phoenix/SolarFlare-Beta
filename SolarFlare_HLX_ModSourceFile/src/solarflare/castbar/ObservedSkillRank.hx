package solarflare.castbar;

/** Learning must distinguish unknown rank from a real rank 1. Observe-only typed getter. */
class ObservedSkillRank {
	public static function read(skill:Dynamic):Null<Int> {
		if (skill == null) return null;
		try {
			var typed:st.skill.BaseSkill = cast skill;
			var rank = typed.get_rank();
			if (rank >= 1) return rank;
		} catch (_:Dynamic) {}
		return null;
	}
}
