package solarflare.aura;

/**
 * Countdown / countup state for a single aura.
 *
 * Cooldown subjects follow native cooldown episodes. Other timers arm on the
 * selected condition edge or a new qualifying cast, before condWas is overwritten.
 */
class AuraTimer {
	public static inline var MODE_OFF:Int = 0;
	public static inline var MODE_DOWN:Int = 1;
	public static inline var MODE_UP:Int = 2;

	public static inline var SRC_FOLLOW:Int = 0;
	public static inline var SRC_FIXED:Int = 1;

	public static function tick(a:AuraDef, hit:Bool, rise:Bool, now:Float):Void {
		if (a == null) return;
		AuraTimerClock.tick(a, a.timerMode, a.timerSource == SRC_FIXED, a.timerSeconds.get(),
			a.timeLeft, hit, rise, now, a.timerKeepExpired.get());
	}

	public static function tickCooldown(a:AuraDef, snap:solarflare.aura.signal.SkillSignalSnap, now:Float):Void {
		var known = snap != null && snap.known && snap.cooldownKnown;
		var left = known ? snap.cooldownLeft : Math.NaN;
		// A usable charge and an active recharge can coexist. Affordability is independent.
		var active = known && (snap.inCooldown || Math.isFinite(left) && left > 0);
		AuraTimerClock.tickCooldown(a, a.timerMode, a.timerSource == SRC_FIXED ? a.timerSeconds.get() : Math.NaN,
			known, active, left, known ? snap.cooldownTotal : Math.NaN, now, a.timerKeepExpired.get());
	}

	/** Progress in 0..1 for bar draws; 0 when the span is unknown. */
	public static function fraction(a:AuraDef):Float {
		return a == null ? 0 : AuraTimerClock.fraction(a);
	}

	/** True once the timer finished but is still lingering on the board. */
	public static function expired(a:AuraDef):Bool {
		return a != null && a.timerExpiredAt > 0;
	}

	/** Board visibility: active timers plus the configured linger tail. */
	public static function onBoard(a:AuraDef):Bool {
		if (a == null || a.timerMode == MODE_OFF || !a.timerActive)
			return false;
		return a.timerBoard == null || a.timerBoard.get();
	}

	public static function reset(a:AuraDef):Void {
		if (a != null) { AuraTimerClock.reset(a); a.timerCooldownWas = false; }
	}

	/** Configured timers extend condition visibility automatically; board linger is separate. */
	public static function keepsAura(a:AuraDef):Bool {
		return a.timerMode != MODE_OFF;
	}
}
