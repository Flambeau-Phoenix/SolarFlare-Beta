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
        try solarflare.castbar.CastCache.noteStart(skill) catch (_:Dynamic) {}
        try CombatLogCache.noteCast(skill) catch (_:Dynamic) {}
        try solarflare.attackcombo.AttackComboCache.onBaseSkillStart(skill) catch (_:Dynamic) {}
	}

	/** Native: fun(BaseSkill, SkillStopReason) -> void → postfix N+1 with middle reason. */
	@:hlx.postfix(st.skill.BaseSkill.doStop)
	static function onBaseSkillStop(skill:Dynamic, reason:Dynamic, result:Void):Void {
        try solarflare.castbar.CastCache.noteStop(skill) catch (_:Dynamic) {}
        try solarflare.aura.EnemyCastCache.noteStop(skill) catch (_:Dynamic) {}
	}

}
