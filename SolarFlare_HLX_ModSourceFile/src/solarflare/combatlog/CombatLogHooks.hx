package solarflare.combatlog;

/**
 * Read-only cast lifecycle capture. Damage is owned by the local Hero receive
 * and Unit inflict adapters so SolarFlare does not install nested receive hooks.
 */
class CombatLogHooks {
	public static function keep():Void {
		solarflare.aura.EnemyCastCache.keep();
	}

	@:hlx.postfix(st.skill.BaseSkill.doStart)
	static function onBaseSkillStart(skill:Dynamic, result:Void):Void {
		CombatLogCache.noteCast(skill);
		solarflare.attackcombo.AttackComboCache.onBaseSkillStart(skill);
	}

	/** Native: fun(BaseSkill, SkillStopReason) -> void → postfix N+1 with middle reason. */
	@:hlx.postfix(st.skill.BaseSkill.doStop)
	static function onBaseSkillStop(skill:Dynamic, reason:Dynamic, result:Void):Void {
		solarflare.aura.EnemyCastCache.noteStop(skill);
	}

}
