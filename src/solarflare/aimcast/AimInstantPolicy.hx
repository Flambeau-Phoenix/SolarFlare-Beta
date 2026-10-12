package solarflare.aimcast;

/**
 * Pure gate for "confirm this aim for the player". The conditions mirror the engine's own branch in
 * `UnitController.startSkillAim`: aim mode only starts when the skill has an Aim step AND its script allows aiming,
 * and only the local controller's player confirms.
 */
class AimInstantPolicy {
	/** `null` when the aim should be confirmed, otherwise the first reason it should be left alone. */
	public static function skipReason(enabled:Bool, isLocalController:Bool, aimingNow:Bool, hasAimStep:Bool, allowAiming:Bool):Null<String> {
		if (!enabled) return "option off";
		if (!isLocalController) return "not the local controller";
		if (!aimingNow) return "aim mode not entered";
		if (!hasAimStep) return "no aim step";
		if (!allowAiming) return "allowAiming false";
		return null;
	}
}
