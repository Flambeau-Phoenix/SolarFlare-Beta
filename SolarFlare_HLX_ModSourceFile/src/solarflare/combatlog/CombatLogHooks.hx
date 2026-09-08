package solarflare.combatlog;

/**
 * Read-only postfix capture for casts and received hits. Continue-only (void postfix).
 */
class CombatLogHooks {
	public static function keep():Void {}

	@:hlx.postfix(st.skill.BaseSkill.doStart)
	static function onBaseSkillStart(skill:Dynamic, result:Void):Void {
		CombatLogCache.noteCast(skill);
		solarflare.attackcombo.AttackComboCache.onBaseSkillStart(skill);
	}

	/** Native: ent.Unit.onReceiveDamage(a0:st.skill.DamageResult):Void */
	@:hlx.postfix(ent.Unit.onReceiveDamage)
	static function onUnitReceiveDamage(self:Dynamic, dmgObj:Dynamic, result:Void):Void {
		CombatLogCache.noteHit(self, dmgObj);
	}

	/** Foe may override Unit; keep a matching N+1 trampoline. */
	@:hlx.postfix(ent.Foe.onReceiveDamage)
	static function onFoeReceiveDamage(self:Dynamic, dmgObj:Dynamic, result:Void):Void {
		CombatLogCache.noteHit(self, dmgObj);
	}
}
