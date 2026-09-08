package solarflare.cdb;

/** Immutable build-time CastleDB catalog, initialized by ModEntry before drawing. */
class AuraCatalog {
	public static var entries(default, null):Array<{id:String, name:String, kind:String}> = [];
	static var names = new Map<String, String>();
	static var ready = false;
	public static function keep():Void {
		if (ready) return;
		ready = true;
		var raw:Dynamic = haxe.Json.parse(haxe.Resource.getString("aura-catalog"));
		var rows:Array<Dynamic> = raw.entries;
		for (row in rows) {
			var id:String = row.id;
			var name:String = row.name;
			var kind:String = row.kind;
			if (!validName(name)) name = id;
			entries.push({id:id, name:name, kind:kind});
			names.set(id, name);
		}
	}
	public static function label(id:String):String {
		var name = names.get(id);
		return name == null ? "" : name;
	}
	public static function validName(name:String):Bool {
		if (name == null) return false;
		return switch (StringTools.trim(name).toLowerCase()) {
			case "", "n/a", "na", "none", "null": false;
			default: true;
		};
	}
}
