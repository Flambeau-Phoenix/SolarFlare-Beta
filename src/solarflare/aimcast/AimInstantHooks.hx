package solarflare.aimcast;

/** Event-only postfix: aim mode just started for a skill request. See AimInstant. */
class AimInstantHooks {
	public static function keep():Void {}

	/** Native: fun(UnitController, Skill, fun(SkillTarget) -> void, String) -> void; postfix N+1 with trailing result. */
	@:hlx.postfix(client.UnitController.startSkillAim)
	static function onStartSkillAim(self:Dynamic, skill:Dynamic, callback:Dynamic, action:Dynamic, result:Void):Void {
		try AimInstant.onAimStart(self, skill) catch (_:Dynamic) {}
	}
}
