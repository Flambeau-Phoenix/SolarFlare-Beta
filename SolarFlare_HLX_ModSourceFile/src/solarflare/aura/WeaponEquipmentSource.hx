package solarflare.aura;

/** Observer boundary. Implementations gate Hero-only calls on actual runtime identity. */
interface WeaponEquipmentSource {
	function isHero(hero:Dynamic):Bool;
	function equipped(hero:Dynamic, id:String):Bool;
}
