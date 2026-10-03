package solarflare.aura.signal;

/** The immutable portion of a signal frame needed by item evaluation. */
typedef ConsumableObservation = {
	var statusDomainKnown:Bool;
	var statusCount:Int;
	var statuses:Array<StatusSignalSnap>;
	function findConsumable(id:String):ConsumableSignalSnap;
}

/** Frozen inventory/effect truth. Shared statuses require their actual source item. */
class ConsumableSignalReader {
	/** Same -1 sentinel as SkillRemain; this frozen reader has no engine dependency. */
	static inline var INFINITE_LEFT:Float = -1;
	public static function read(frame:ConsumableObservation, signal:String, subject:String, out:AuraResolvedValue):Void {
		out.reset();
		var descriptor = AuraSignalCatalog.find(signal);
		if (descriptor == null) { out.code = UNKNOWN_SIGNAL; return; }
		out.kind = descriptor.kind;
		var entry = solarflare.cdb.ConsumableCatalog.find(subject);
		if (entry == null) { out.code = MISSING_SUBJECT; return; }
		if (signal == "consumable.active" || signal == "consumable.durationLeft" || signal == "consumable.durationProgress") {
			readEffect(frame, signal, entry, out); return;
		}
		var snap = frame.findConsumable(subject);
		if (snap == null || !snap.known) { out.code = UNKNOWN_DOMAIN; return; }
		out.known = true; out.code = OK;
		switch (signal) {
			case "consumable.owned": out.boolValue = snap.owned;
			case "consumable.count": out.intValue = snap.count; out.numberValue = snap.count;
			case "consumable.usable": out.boolValue = snap.owned && snap.count > 0 && snap.usable; out.known = snap.usableKnown;
			case "consumable.needsRefill": out.boolValue = entry.refillable && snap.owned && snap.count == 0;
			default: out.known = false;
		}
		out.present = out.boolValue;
		if (!out.known) out.code = UNKNOWN_DOMAIN;
	}
	static function readEffect(frame:ConsumableObservation, signal:String, entry:solarflare.cdb.ConsumableCatalog.ConsumableEntry, out:AuraResolvedValue):Void {
		// Instant heals and items with no buff have no ongoing effect to observe.
		if (entry.statuses.length == 0) { out.code = UNKNOWN_DOMAIN; return; }
		var uncertain = !frame.statusDomainKnown;
		var selected:StatusSignalSnap = null;
		for (effect in entry.statuses) for (i in 0...frame.statusCount) {
			var snap = frame.statuses[i];
			if (snap.rawId != effect.id && snap.ids.indexOf(effect.id) < 0) continue;
			if (!snap.known) { uncertain = true; continue; }
			if (!snap.present) continue;
			if (snap.sourceItemId.length > 0 && snap.sourceItemId.toLowerCase() != entry.id.toLowerCase()) continue;
			if (effect.shared && snap.sourceItemId.length == 0) { uncertain = true; continue; }
			if (selected == null || snap.durationLeft > selected.durationLeft) selected = snap;
		}
		if (selected == null && uncertain) { out.code = UNKNOWN_DOMAIN; return; }
		out.present = out.boolValue = selected != null;
		out.known = true; out.code = OK;
		if (selected == null) { out.numberValue = 0; return; }
		out.intValue = selected.stacks;
		if (selected.durationKnown) {
			out.timeLeft = selected.infinite ? INFINITE_LEFT : selected.durationLeft;
			out.progress = selected.infinite ? 1 : selected.durationProgress;
			if (!Math.isFinite(out.timeLeft) || !Math.isFinite(out.progress)) {
				out.timeLeft = Math.NaN; out.progress = Math.NaN;
				if (signal != "consumable.active") { out.known = false; out.code = NON_FINITE; return; }
			}
		} else if (signal != "consumable.active") { out.known = false; out.code = UNKNOWN_DOMAIN; return; }
		if (signal == "consumable.durationLeft") out.numberValue = out.timeLeft;
		if (signal == "consumable.durationProgress") out.numberValue = out.progress;
	}
}
