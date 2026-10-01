package solarflare.aura;

/** Native-free timer state shared by production AuraDef and lifecycle tests. */
typedef AuraTimerState = {
	var timerActive:Bool;
	var timerValue:Float;
	var timerTotal:Float;
	var timerStartedAt:Float;
	var timerEndsAt:Float;
	var timerExpiredAt:Float;
}

class AuraTimerClock {
	public static inline function trigger(known:Bool, hit:Bool, previous:Bool, edge:Int):Bool {
		return known && (edge == 1 ? !hit && previous : hit && !previous);
	}
	public static function tick(a:AuraTimerState, mode:Int, fixed:Bool, fixedSpan:Float,
			left:Float, hit:Bool, rise:Bool, now:Float, linger:Float):Void {
		if (mode == 0) { reset(a); return; }
		var span = fixed ? fixedSpan : left;
		if (fixed) span = Math.isFinite(span) ? Math.max(0.1, span) : 0.1;
		if (rise) {
			if (mode == 1 && !fixed && !(Math.isFinite(span) && span > 0.02)) return;
			a.timerTotal = mode == 1 || fixed ? span : Math.NaN;
			a.timerEndsAt = mode == 1 || fixed ? now + span : 0;
			a.timerStartedAt = now;
			a.timerActive = true;
			a.timerExpiredAt = 0;
			a.timerValue = mode == 1 ? span : 0;
			return;
		}
		if (!a.timerActive) return;
		if (a.timerExpiredAt <= 0) {
			if (mode == 1) {
				if (!fixed && Math.isFinite(left) && left > 0.02 && hit) {
					a.timerValue = left;
					a.timerEndsAt = now + left;
					if (left > a.timerTotal) a.timerTotal = left;
				} else a.timerValue = Math.max(0, a.timerEndsAt - now);
				if (a.timerValue <= 0) a.timerExpiredAt = now;
			} else {
				a.timerValue = Math.max(0, now - a.timerStartedAt);
				if (fixed && a.timerValue >= a.timerTotal) {
					a.timerValue = a.timerTotal;
					a.timerExpiredAt = now;
				} else if (!fixed && !hit) a.timerExpiredAt = now;
			}
		}
		if (a.timerExpiredAt > 0 && now - a.timerExpiredAt > Math.max(0, linger)) reset(a);
	}
	public static function fraction(a:AuraTimerState):Float {
		if (!(a.timerTotal > 0.001) || !Math.isFinite(a.timerTotal)) return 0;
		return Math.max(0, Math.min(1, a.timerValue / a.timerTotal));
	}
	public static inline function running(a:AuraTimerState):Bool return a.timerActive && a.timerExpiredAt <= 0;
	/** A timer extends normal visibility; it never replaces the condition display. */
	public static inline function visible(normalVisible:Bool, visual:Bool, a:AuraTimerState):Bool {
		return visual && (normalVisible || running(a));
	}
	public static function reset(a:AuraTimerState):Void {
		a.timerActive = false;
		a.timerValue = a.timerTotal = a.timerEndsAt = a.timerStartedAt = a.timerExpiredAt = 0;
	}
}
