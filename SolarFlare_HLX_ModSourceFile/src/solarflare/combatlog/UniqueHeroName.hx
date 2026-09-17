package solarflare.combatlog;

import solarflare.FieldWalk;

/**
 * Unique long-form hero callout. Never class tokens (Warrior/Mage/…).
 * Draw loops must not call this — snapshot strings only.
 */
class UniqueHeroName {
	public static function keep():Void {}

	public static function of(unit:Dynamic):String {
		if (unit == null || !isHero(unit))
			return "";
		var best = "";
		try {
			var hero:ent.Hero = cast unit;
			if (hero != null) {
				try
					best = consider(best, hero.name)
				catch (_:Dynamic) {}
				try {
					var p:st.Player = hero.getPlayer();
					if (p == null)
						p = hero.player;
					if (p != null)
						best = consider(best, p.name);
				} catch (_:Dynamic) {}
			}
		} catch (_:Dynamic) {}
		best = consider(best, FieldWalk.extractString(unit, "networkPropName"));
		best = consider(best, FieldWalk.extractString(unit, "name"));
		var player = FieldWalk.extractObject(unit, "player");
		best = consider(best, FieldWalk.extractString(player, "name"));
		return best;
	}

	public static function isClassToken(s:String):Bool {
		if (s == null)
			return false;
		var t = StringTools.trim(s).toLowerCase();
		return t == "priest" || t == "warrior" || t == "mage" || t == "rogue" || t == "cleric";
	}

	public static function rejectClass(s:String):String {
		if (s == null || s.length == 0 || isClassToken(s))
			return "";
		return s;
	}

	static function isHero(unit:Dynamic):Bool {
		try {
			var hero:ent.Hero = cast unit;
			if (hero != null)
				return true;
		} catch (_:Dynamic) {}
		try {
			var hero:ent.Hero = cast unit;
			if (hero != null && hero.getPlayer() != null)
				return true;
		} catch (_:Dynamic) {}
		if (FieldWalk.extractObject(unit, "player") != null)
			return true;
		return false;
	}

	static function consider(best:String, cand:String):String {
		var s = clean(cand);
		if (s.length == 0 || isClassToken(s))
			return best;
		if (s.length > best.length)
			return s;
		return best;
	}

	static function clean(s:String):String {
		if (s == null)
			return "";
		s = StringTools.trim(s);
		if (s.length == 0)
			return "";
		var low = s.toLowerCase();
		if (low.indexOf("bytes") >= 0 || s.indexOf("{") >= 0)
			return "";
		return s;
	}
}
