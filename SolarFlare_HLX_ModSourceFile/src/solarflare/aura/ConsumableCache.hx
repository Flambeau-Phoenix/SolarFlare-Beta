package solarflare.aura;

import solarflare.cdb.ConsumableCatalog;
import solarflare.aura.signal.ConsumableSignalSnap;

/** Read-only carried inventory and actual charge counts. No hooks or item use. */
class ConsumableCache {
	public static var snaps(default, null):Array<ConsumableSignalSnap> = [];
	static var byId = new Map<String, ConsumableSignalSnap>();
	static var sampledHero:Dynamic;
	static var lastAt:Float = -1;
	static var sampledDemand:Bool = false;
	public static function find(id:String):ConsumableSignalSnap return id == null ? null : byId.get(id.toLowerCase());
	public static function initialize():Void {
		if (snaps.length > 0) return;
		for (entry in ConsumableCatalog.entries) {
			var snap = new ConsumableSignalSnap(); snap.id = entry.id;
			snaps.push(snap); byId.set(entry.id.toLowerCase(), snap);
		}
	}
	public static function sample(hero:Dynamic, now:Float):Void {
		initialize();
		var wanted = solarflare.ObserveDemand.aurasNeedConsumables || solarflare.ObserveDemand.extraBarsNeedConsumables;
		if (hero == sampledHero && wanted == sampledDemand && now - lastAt < 0.25) return;
		sampledDemand = wanted;
		sampledHero = hero; lastAt = now;
		for (snap in snaps) snap.reset();
		if (hero == null || !wanted) return;
		try {
			var h:ent.Hero = hero;
			var loadout = h.loadout;
			var inv = loadout.inventory;
			var equipment = loadout.equipment;
			if (inv == null || equipment == null) return;
			var complete = scan(inv, loadout, h, false) && scan(equipment, loadout, h, true);
			for (snap in snaps) {
				snap.known = complete;
				snap.usableKnown = complete && (snap.usable || !snap.usabilityFailed);
			}
		} catch (_:Dynamic) {}
	}
	static function scan(inv:st.Inventory, loadout:st.Loadout, hero:ent.Hero, equipped:Bool):Bool {
		var n = inv.getSize();
		if (n < 0 || n > 1024) return false;
		for (i in 0...n) {
			if (equipped) { var equipment:st.Equipment = inv; if (equipment.isShortcut(i)) continue; }
			var stack = inv.getStack(i);
			if (stack == null || stack.item == null) continue;
			var id = solarflare.EngineText.cleanId(stack.item.kind);
			var snap = byId.get(id.toLowerCase());
			if (snap == null) continue;
			snap.owned = true;
			snap.count += Std.int(Math.max(0, loadout.getDisplayStackCount(inv, stack)));
			try {
				snap.usable = snap.usable || stack.item.canBeUsed(hero);
			} catch (_:Dynamic) { snap.usabilityFailed = true; }
		}
		return true;
	}
}
