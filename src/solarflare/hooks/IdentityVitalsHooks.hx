package solarflare.hooks;

/** Discrete local skill-use and damage ABI adapters. Continuous state is sampled. */
class IdentityVitalsHooks {
	public static function keep():Void {}

	@:hlx.postfix(ent.Hero.onSkillUse)
	static function onHeroSkillUse(self:Dynamic, skill:Dynamic, result:Void):Void {
		try solarflare.HealthHooks.hookHeroSkillUse(self, skill) catch (_:Dynamic) {}
	}

	@:hlx.postfix(ent.Hero.onReceiveDamage)
	static function onHeroReceiveDamage(self:Dynamic, dmgObj:Dynamic, result:Void):Void {
		try solarflare.HealthHooks.hookHeroDamage(self, dmgObj) catch (_:Dynamic) {}
	}

	@:hlx.postfix(ent.Unit.onInflictDamage)
	static function onInflictDamage(self:Dynamic, dmgObj:Dynamic, result:Void):Void {
		try solarflare.HealthHooks.hookInflictDamage(self, dmgObj) catch (_:Dynamic) {}
	}
}
