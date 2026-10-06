package solarflare;

/** Current native getters expose seconds; charge progress grows while duration progress drains. */
class EngineTimerMath {
    public static inline function seconds(value:Float):Float {
        return Math.isFinite(value) && value >= 0 ? value : Math.NaN;
    }

    public static inline function cooldownRemaining(recharge:Float):Float {
        return Math.isFinite(recharge) && recharge >= 0 && recharge <= 1 ? 1 - recharge : Math.NaN;
    }

    public static inline function cooldownReady(inCooldownKnown:Bool, inCooldown:Bool, left:Float):Bool {
        if (inCooldownKnown) return !inCooldown;
        return Math.isFinite(left) && left >= 0 && left <= 0.02;
    }

    /** A finite stamp also expires at its observed deadline, even before the recheck. */
    public static inline function reuseDurationStamp(now:Float, recheckAt:Float, endsAt:Float, infinite:Bool):Bool {
        return now < recheckAt && (infinite || now < endsAt);
    }
}
