package solarflare.aura;

import solarflare.castbar.CastCache;
import solarflare.castbar.LearnedCastTimes;
import solarflare.castbar.CastDurationResolver;
import solarflare.geaux.GeauxCache;
import solarflare.geaux.GeauxCdTable;
import solarflare.cdb.CdbAuraTable;

typedef AuraTimingReference = {
	var cdbSeconds:Float;
	var observedSeconds:Float;
	var nativeValid:Bool;
	var rank:Null<Int>;
	var castSeconds:Float;
	var castLabel:String;
}

/** Reads frozen primitives and startup caches only. No game getters, learning, or I/O. */
class AuraTimingReferences {
	public static function forSubject(id:String, signal:String, chosenRank:Null<Int> = null, hasChosenRank:Bool = false):AuraTimingReference {
		var out:AuraTimingReference = {cdbSeconds:0, observedSeconds:0, nativeValid:false, rank:null, castSeconds:0, castLabel:"Unknown"};
		if (id == null || id.length == 0) return out;
		var matched = false;
		for (snaps in [GeauxCache.auraSkills, GeauxCache.slots, GeauxCache.weapons, GeauxCache.signatures]) {
			if (snaps == null) continue;
			for (snap in snaps) if (!matched && snap != null && snap.present && (snap.id == id || snap.iconId == id)) {
				out.rank = snap.observedRank;
				out.nativeValid = snap.nativeCdTotalValid;
				out.observedSeconds = snap.nativeCdTotal;
				matched = true;
			}
		}
		if (AuraTimingReferencePolicy.isCast(signal)) {
			var snap = signal == "event.playerCast.recent" ? CastCache.playerSnap() : CastCache.targetSnap();
			// Enemy ranks never inherit the local player's rank for the same skill.
			out.rank = snap != null && snap.active && snap.skillId == id ? snap.observedRank
				: signal == "event.playerCast.recent" ? out.rank : null;
			if (hasChosenRank) out.rank = chosenRank;
			var resolved = LearnedCastTimes.resolve(id, out.rank);
			out.castSeconds = resolved.seconds;
			out.castLabel = CastDurationResolver.label(resolved);
		} else {
			out.cdbSeconds = out.rank != null ? GeauxCdTable.maxFor(id, out.rank) : GeauxCdTable.baseFor(id);
			if (out.cdbSeconds <= 0) out.cdbSeconds = CdbAuraTable.cooldown(id);
		}
		return out;
	}
}
