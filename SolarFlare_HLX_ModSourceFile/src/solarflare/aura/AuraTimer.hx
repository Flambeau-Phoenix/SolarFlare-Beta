package solarflare.aura;

/**
 * Condition-driven countdown / countup state for a single aura.
 *
 * Armed on the rising edge of the aura condition, so `tick` must run before
 * AuraEffects.apply overwrites `condWas`; the caller passes the edge explicitly.
 */
class AuraTimer {
	public static inline var MODE_OFF:Int = 0;
	public static inline var MODE_DOWN:Int = 1;
	public static inline var MODE_UP:Int = 2;

	public static inline var SRC_FOLLOW:Int = 0;
	public static inline var SRC_FIXED:Int = 1;

	public static function tick(a:AuraDef, hit:Bool, rise:Bool, now:Float):Void {
		if (a == null)
			return;
		if (a.timerMode == MODE_OFF) {
			reset(a);
			return;
		}
		var fixed = a.timerSource == SRC_FIXED;
		var span = fixed ? a.timerSeconds.get() : a.timeLeft;
		if (fixed && span < 0.1)
			span = 0.1;

		if (rise) {
			if (a.timerMode == MODE_DOWN) {
				if (!fixed && !(Math.isFinite(span) && span > 0.02))
					return;
				a.timerTotal = span;
				a.timerEndsAt = now + span;
			} else {
				a.timerTotal = fixed ? span : Math.NaN;
				a.timerEndsAt = fixed ? now + span : 0;
			}
			a.timerStartedAt = now;
			a.timerActive = true;
			a.timerExpiredAt = 0;
			a.timerValue = a.timerMode == MODE_DOWN ? span : 0;
			return;
		}

		if (!a.timerActive)
			return;

		if (a.timerMode == MODE_DOWN) {
			// Follow mode re-reads live remaining so CDR / refreshes stay honest.
			if (!fixed && Math.isFinite(a.timeLeft) && a.timeLeft > 0.02 && hit) {
				a.timerValue = a.timeLeft;
				if (a.timeLeft > a.timerTotal)
					a.timerTotal = a.timeLeft;
			} else
				a.timerValue = a.timerEndsAt - now;
			if (a.timerValue <= 0) {
				a.timerValue = 0;
				expire(a, now);
			}
		} else {
			a.timerValue = now - a.timerStartedAt;
			// Fixed count-up stops at the target; follow count-up runs while the condition holds.
			if (fixed && a.timerValue >= a.timerTotal) {
				a.timerValue = a.timerTotal;
				expire(a, now);
			} else if (!fixed && !hit)
				expire(a, now);
		}
		retire(a, now);
	}

	/** Progress in 0..1 for bar draws; 0 when the span is unknown. */
	public static function fraction(a:AuraDef):Float {
		if (a == null || !(a.timerTotal > 0.001) || !Math.isFinite(a.timerTotal))
			return 0;
		var f = a.timerValue / a.timerTotal;
		return f < 0 ? 0 : (f > 1 ? 1 : f);
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
		if (a == null)
			return;
		a.timerActive = false;
		a.timerValue = 0;
		a.timerTotal = 0;
		a.timerEndsAt = 0;
		a.timerStartedAt = 0;
		a.timerExpiredAt = 0;
	}

	static inline function expire(a:AuraDef, now:Float):Void {
		if (a.timerExpiredAt <= 0)
			a.timerExpiredAt = now;
	}

	/**
	 * Drops a finished timer once its linger tail elapses.
	 *
	 * Must stay on the engine clock that stamped `timerExpiredAt`; draw-side time
	 * (ImGui.getTime) shares no origin with it and would never satisfy the tail.
	 */
	static inline function retire(a:AuraDef, now:Float):Void {
		if (a.timerExpiredAt <= 0)
			return;
		var linger = a.timerKeepExpired != null ? a.timerKeepExpired.get() : 0;
		if (now - a.timerExpiredAt > linger)
			reset(a);
	}
}
