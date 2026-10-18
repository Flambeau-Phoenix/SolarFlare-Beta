package solarflare.aura;

private class WeaponEquipmentEngine implements WeaponEquipmentSource {
	public function new() {}
	public function isHero(hero:Dynamic):Bool return solarflare.HealthCache.isHeroObject(hero);
	public function equipped(hero:Dynamic, id:String):Bool {
		var h:ent.Hero = hero;
		return h.hasWeaponEquipped(id);
	}
}

/** Runtime facade independent of BarTer/Geaux. Called only during observation. */
class WeaponEquipmentCache {
	static var sampler = new WeaponEquipmentSampler(new WeaponEquipmentEngine());
	public static var snaps(get, never):Array<solarflare.aura.signal.WeaponSignalSnap>;
	static function get_snaps() return sampler.snaps;
	public static function reset():Void sampler.reset();
	public static function sample(now:Float):Void {
		sampler.observe(solarflare.HealthCache.localHero, solarflare.HealthCache.identityGen, solarflare.HealthCache.statusOwnerGen,
			now, solarflare.ObserveDemand.weaponIds, solarflare.ObserveDemand.weaponDemandGeneration, solarflare.ObserveDemand.aurasNeedWeapons);
	}
}
