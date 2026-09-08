package solarflare.aura;

/** Profile-local counter snapshot keyed by stable Aura ID; live counts stay on AuraDef. */
class AuraCounterState {
	public static function dump<T:{id:String, counterValue:Int}>(auras:Array<T>):Dynamic {
		var counts:Dynamic = {};
		if (auras != null) for (a in auras)
			if (a != null) Reflect.setField(counts, a.id, a.counterValue);
		return counts;
	}

	public static function apply<T:{id:String, counterValue:Int}>(auras:Array<T>, counts:Dynamic):Void {
		if (auras == null) return;
		for (a in auras) {
			if (a == null) continue;
			var raw:Dynamic = counts != null ? Reflect.field(counts, a.id) : null;
			a.counterValue = validCount(raw);
		}
	}

	static function validCount(raw:Dynamic):Int {
		if (!Std.isOfType(raw, Int) && !Std.isOfType(raw, Float)) return 0;
		var value:Float = raw;
		if (!Math.isFinite(value) || value < 0 || value > 2147483647 || Math.floor(value) != value) return 0;
		return Std.int(value);
	}
}
