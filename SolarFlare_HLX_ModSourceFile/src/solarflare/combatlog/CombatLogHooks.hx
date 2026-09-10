package solarflare.combatlog;

/**
 * Read-only postfix capture for casts and received hits. Continue-only (void postfix).
 */
class CombatLogHooks {
	static var damageObservation = new DamageObservation();
	public static function keep():Void {
		solarflare.aura.EnemyCastCache.keep();
	}
	public static function beginDamage(dmg:Dynamic):Void damageObservation.enter(dmg);
	public static function endDamage(victim:Dynamic, dmg:Dynamic):Void {
		if (damageObservation.leave(dmg))
			CombatLogCache.noteHit(victim, dmg);
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

	/** Native: ent.Unit.onReceiveDamage(a0:st.skill.DamageResult):Void */
	@:hlx.prefix(ent.Unit.onReceiveDamage)
	static function beforeUnitReceiveDamage(self:Dynamic, dmgObj:Dynamic):hlx.runtime.HlxPrefixControl {
		beginDamage(dmgObj);
		return hlx.runtime.HlxPrefixControl.Continue;
	}

	@:hlx.prefix(ent.Foe.onReceiveDamage)
	static function beforeFoeReceiveDamage(self:Dynamic, dmgObj:Dynamic):hlx.runtime.HlxPrefixControl {
		beginDamage(dmgObj);
		return hlx.runtime.HlxPrefixControl.Continue;
	}

	@:hlx.postfix(ent.Unit.onReceiveDamage)
	static function onUnitReceiveDamage(self:Dynamic, dmgObj:Dynamic, result:Void):Void {
		endDamage(self, dmgObj);
	}

	/** Foe may override Unit; keep a matching N+1 trampoline. */
	@:hlx.postfix(ent.Foe.onReceiveDamage)
	static function onFoeReceiveDamage(self:Dynamic, dmgObj:Dynamic, result:Void):Void {
		endDamage(self, dmgObj);
	}
}
