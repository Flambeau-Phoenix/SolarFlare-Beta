package solarflare.aura;

import solarflare.aura.signal.AuraConditionDef;
import solarflare.cdb.WeaponCatalog;

/** Rebuilt on configuration edits, including per-element visibility rules. */
class WeaponEquipmentDemand {
	public static function collect(conditions:Array<AuraConditionDef>, out:Array<String>):Void {
		out.resize(0);
		for (condition in conditions) if (condition != null && condition.signal == "equipment.weaponEquipped") {
			var id = WeaponCatalog.canonicalId(condition.subject);
			if (id.length > 0 && out.indexOf(id) < 0) out.push(id);
		}
	}
}
