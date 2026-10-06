package solarflare.aura;

/** Pure Quick Build policy. Native provenance is explicit; derived cdMax is never an input. */
class AuraTimingReferencePolicy {
	public static inline function isCast(signal:String):Bool {
		return StringTools.startsWith(signal, "event.cast.") || signal == "event.playerCast.recent";
	}
	public static inline function isCooldown(signal:String):Bool return switch (signal) {
		case "skill.ready", "skill.affordable", "skill.inCooldown", "skill.cooldownLeft", "skill.cooldownProgress", "skill.charges", "skill.chargesMax": true;
		default: false;
	};
	public static inline function seconds(choice:String, cdb:Float, observed:Float, nativeValid:Bool):Float {
		var v = choice == "Observed" ? (nativeValid ? observed : 0) : cdb;
		return Math.isFinite(v) && v > 0.001 && v <= 600 ? v : 0;
	}
}
