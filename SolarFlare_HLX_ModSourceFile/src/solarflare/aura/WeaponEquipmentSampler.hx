package solarflare.aura;

import solarflare.aura.signal.WeaponSignalSnap;

/** Demand-owned, bounded 10 Hz observer. Only this layer retains its current hero. */
class WeaponEquipmentSampler {
	public static inline var POLL_S:Float = 0.1;
	public static inline var MAX_SUBJECTS:Int = 288;
	public var snaps(default, null):Array<WeaponSignalSnap> = [];
	var source:WeaponEquipmentSource;
	var owner:Dynamic;
	var identity:Int = -1;
	var generation:Int = -1;
	var demand:Int = -1;
	var lastAt:Float = -1e9;
	public function new(source:WeaponEquipmentSource) { this.source = source; }
	public function reset():Void {
		owner = null; identity = generation = demand = -1; lastAt = -1e9;
		for (snap in snaps) snap.reset();
		snaps.resize(0);
	}
	public function observe(hero:Dynamic, identity:Int, generation:Int, now:Float, ids:Array<String>, demand:Int, wanted:Bool):Void {
		if (!wanted || hero == null) { reset(); return; }
		var changed = hero != owner || identity != this.identity || generation != this.generation || demand != this.demand;
		if (!changed && now >= lastAt && now - lastAt < POLL_S) return;
		if (changed) {
			reset(); owner = hero; this.identity = identity; this.generation = generation; this.demand = demand;
			for (id in ids) {
				if (snaps.length >= MAX_SUBJECTS) break;
				var snap = new WeaponSignalSnap(); snap.id = id; snaps.push(snap);
			}
		}
		lastAt = now;
		for (snap in snaps) snap.reset();
		try { if (!source.isHero(hero)) return; } catch (_:Dynamic) { return; }
		for (snap in snaps) {
			try { snap.equipped = source.equipped(hero, snap.id); snap.known = true; }
			catch (_:Dynamic) { snap.reset(); }
		}
	}
}
