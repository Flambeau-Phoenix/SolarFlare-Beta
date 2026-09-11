package solarflare.combatlog;

/**
 * Read-only capture for casts and received hits. Prefixes Continue; void postfixes.
 *
 * Receive path: Foe.onReceiveDamage is outer authority (nests Unit.onReceiveDamage).
 * DamageObservation collapses the nest so one payload → one CombatLog row.
 * Unit stubs remain hooked so Class B empty-frame patches stay healthy; emission is gated.
 */
class CombatLogHooks {
	static var damageObservation = new DamageObservation();
	public static function keep():Void {
		solarflare.aura.EnemyCastCache.keep();
	}
	public static function beginDamage(dmg:Dynamic):Void damageObservation.enter(dmg);
	public static function endDamage(victim:Dynamic, dmg:Dynamic, hook:String = ""):Void {
		if (damageObservation.leave(dmg))
			CombatLogCache.noteHit(victim, dmg, hook);
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

	/** Native: ent.Unit.onReceiveDamage(a0:st.skill.DamageResult):Void — empty stub; nested under Foe. */
	@:hlx.prefix(ent.Unit.onReceiveDamage)
	static function beforeUnitReceiveDamage(self:Dynamic, dmgObj:Dynamic):hlx.runtime.HlxPrefixControl {
		try
			beginDamage(dmgObj)
		catch (_:Dynamic) {}
		return hlx.runtime.HlxPrefixControl.Continue;
	}

	@:hlx.prefix(ent.Foe.onReceiveDamage)
	static function beforeFoeReceiveDamage(self:Dynamic, dmgObj:Dynamic):hlx.runtime.HlxPrefixControl {
		try
			beginDamage(dmgObj)
		catch (_:Dynamic) {}
		return hlx.runtime.HlxPrefixControl.Continue;
	}

	@:hlx.postfix(ent.Unit.onReceiveDamage)
	static function onUnitReceiveDamage(self:Dynamic, dmgObj:Dynamic, result:Void):Void {
		try
			endDamage(self, dmgObj, "ent.Unit.onReceiveDamage")
		catch (_:Dynamic) {}
	}

	/** Outer receive authority; matching N+1 trampoline. */
	@:hlx.postfix(ent.Foe.onReceiveDamage)
	static function onFoeReceiveDamage(self:Dynamic, dmgObj:Dynamic, result:Void):Void {
		try
			endDamage(self, dmgObj, "ent.Foe.onReceiveDamage")
		catch (_:Dynamic) {}
	}
}
