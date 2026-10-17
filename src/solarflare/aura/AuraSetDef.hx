package solarflare.aura;

/**
 * A named group of auras that can be armed together, for example one boss fight. An aura belongs to the
 * set whose id equals its `fight` tag, so older tags, saves and share packs keep working. Presentation
 * policy only: no engine objects, no timers.
 */
class AuraSetDef {
	public static inline var MODE_ALWAYS:Int = 0;
	public static inline var MODE_MAPS:Int = 1;
	public static inline var MODE_OFF:Int = 2;
	public static inline var MAX_MAPS:Int = 16;

	public var id:String;
	public var name:String;
	public var mode:Int = MODE_ALWAYS;
	/** Normalized (trimmed, lower-case) map ids, matched against AuraMapContext.mapId. */
	public var maps:Array<String> = [];

	public function new(id:String, name:String) {
		this.id = id;
		this.name = name;
	}

	public static function normalizeMap(id:String):String
		return id == null ? "" : StringTools.trim(id).toLowerCase();

	/** Armed state for the given current map. An unknown map never arms a map-bound set. */
	public function activeOn(mapId:String):Bool {
		if (mode == MODE_OFF)
			return false;
		if (mode == MODE_MAPS)
			return mapId != null && mapId.length > 0 && maps.indexOf(mapId) >= 0;
		return true;
	}

	public function hasMap(mapId:String):Bool return maps.indexOf(normalizeMap(mapId)) >= 0;

	public function addMap(mapId:String):Bool {
		var key = normalizeMap(mapId);
		if (key.length == 0 || maps.length >= MAX_MAPS || maps.indexOf(key) >= 0)
			return false;
		maps.push(key);
		return true;
	}

	public function removeMap(mapId:String):Void maps.remove(normalizeMap(mapId));

	public function toObj():Dynamic {
		return {id: id, name: name, mode: mode, maps: maps.copy()};
	}

	/** Null when the record has no usable id. Unknown modes fall back to Always. */
	public static function fromObj(d:Dynamic):AuraSetDef {
		if (d == null || d.id == null)
			return null;
		var id = StringTools.trim(Std.string(d.id));
		if (id.length == 0)
			return null;
		var s = new AuraSetDef(id, d.name != null && StringTools.trim(Std.string(d.name)).length > 0 ? Std.string(d.name) : id);
		var m:Dynamic = d.mode;
		if (Std.isOfType(m, Int) && (m == MODE_MAPS || m == MODE_OFF))
			s.mode = m;
		var raw:Dynamic = d.maps;
		if (raw != null && Std.isOfType(raw, Array)) {
			var list:Array<Dynamic> = cast raw;
			for (item in list)
				if (item != null)
					s.addMap(Std.string(item));
		}
		return s;
	}
}
