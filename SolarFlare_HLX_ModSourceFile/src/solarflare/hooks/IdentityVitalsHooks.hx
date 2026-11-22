package solarflare.hooks;

/** Discrete local skill-use and damage ABI adapters. Continuous state is sampled. */
class IdentityVitalsHooks {
	public static function keep():Void {}

	@:hlx.postfix(ent.Hero.onSkillUse)
	static function onHeroSkillUse(self:Dynamic, skill:Dynamic, result:Void):Void {
		try solarflare.HealthHooks.hookHeroSkillUse(self, skill) catch (_:Dynamic) {}
	}

	/** PTR client receive boundary; DamageInfo is not a DamageResult. */
	@:hlx.postfix(ent.Unit.rpcDisplayDamage__impl)
	static function onNetworkDamage(self:Dynamic, dmgObj:Dynamic, result:Void):Void {
		try solarflare.combatlog.CombatLogCache.noteNetworkDamage(self, cast dmgObj) catch (_:Dynamic) {}
	}
}
