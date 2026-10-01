package solarflare.aura;

/**
 * Condition-driven countdown / countup state for a single aura.
 *
 * Armed on the selected condition edge or a new qualifying cast. `tick` runs
 * before AuraEffects.apply overwrites `condWas`; the caller passes the trigger.
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
		if (a != null) AuraTimerClock.reset(a);
	}

	/** Configured timers extend condition visibility automatically; board linger is separate. */
	public static function keepsAura(a:AuraDef):Bool {
		return a.timerMode != MODE_OFF;
	}
}
