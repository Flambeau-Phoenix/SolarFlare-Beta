package solarflare.extrabars;

typedef ExtraBarsUseCandidate = {var item:Dynamic; var count:Int; var shortcut:Bool; var usable:Bool;}
typedef ExtraBarsUseOutcome = {var submitted:Bool; var countBefore:Int; var message:String;}

/** Event-only dispatcher; tests exercise the same validation and selection as native use. */
class ExtraBarsUsePolicy {
	public static function request(kind:String, catalogKnown:Bool, expectedGeneration:Int, generation:Int,
			allowed:Bool, collect:String->Array<ExtraBarsUseCandidate>, send:Dynamic->Void):ExtraBarsUseOutcome {
		function denied(message:String):ExtraBarsUseOutcome return {submitted:false, countBefore:0, message:message};
		if (expectedGeneration != generation) return denied("Discarded a stale request.");
		if (!allowed) return denied("Gameplay input is blocked.");
		if (!catalogKnown || kind == null || kind.length == 0) return denied("Item is not in the audited catalog.");
		try {
			var candidates = collect(kind);
			var count = 0;
			var selected:Dynamic = null;
			for (candidate in candidates) {
				if (candidate.shortcut || candidate.item == null) continue;
				count += Std.int(Math.max(0, candidate.count));
				if (selected == null && candidate.count > 0 && candidate.usable) selected = candidate.item;
			}
			if (selected == null) return denied("No carried matching item can be used.");
			send(selected);
			return {submitted:true, countBefore:count, message:"Native use request submitted; verify the effect in game."};
		} catch (e:Dynamic) {
			return denied("Item use failed: " + Std.string(e));
		}
	}
}
