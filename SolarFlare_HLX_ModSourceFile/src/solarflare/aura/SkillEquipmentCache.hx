package solarflare.aura;

import solarflare.barter.BarTerNativeKeys;
import solarflare.geaux.GeauxCache;

/**
 * Which skills the local hero has on its action bars right now (active weapon slots, class slots and the
 * signature slot, which is where an arsenal weapon's skill sits). Read from BarTer's native slot observer, so
 * Aura, BarTer and Geaux all agree. Observe phase only; drawing sees frozen keys on the signal frame.
 */
class SkillEquipmentCache {
	public static inline var MAX_KEYS:Int = solarflare.aura.signal.AuraSignalFrame.MAX_EQUIPPED;
	/** Lower-case sanitized ids (definition, base, icon and class-signature aliases) of every equipped skill. */
	public static var keys:Array<String> = [for (_ in 0...MAX_KEYS) ""];
	public static var count(default, null):Int = 0;
	/** At least one native read has completed for this hero. */
	public static var known(default, null):Bool = false;
	/** Every slot was readable, so a skill that is not listed is truly not equipped (not merely unread). */
	public static var complete(default, null):Bool = false;
	static var lastGeneration:Int = -1;
	static var lastOwner:Int = -1;

	public static function sample(now:Float):Void {
		// BarTer samples with its own loadout key; sampling here as well would fight that, so only sample when it is off.
		if (!solarflare.ObserveDemand.barter) BarTerNativeKeys.sample(now);
		var generation = BarTerNativeKeys.observationGeneration;
		var owner = BarTerNativeKeys.ownerGeneration;
		known = generation > 0 && solarflare.HealthCache.localHero != null;
		complete = known && BarTerNativeKeys.weaponReadable && BarTerNativeKeys.classReadable && BarTerNativeKeys.signatureReadable;
		if (generation == lastGeneration && owner == lastOwner) return;
		lastGeneration = generation;
		lastOwner = owner;
		count = 0;
		for (row in BarTerNativeKeys.skills) {
			add(row.id);
			add(row.baseId);
			add(row.icon);
		}
	}

	static function add(id:String):Void {
		if (id == null || id.length == 0) return;
		var key = GeauxCache.sanitizeSkillId(id).toLowerCase();
		if (key.length == 0) return;
		push(key);
	}

	static function push(key:String):Void {
		if (count >= MAX_KEYS) return;
		for (i in 0...count) if (keys[i] == key) return;
		keys[count++] = key;
	}
}
