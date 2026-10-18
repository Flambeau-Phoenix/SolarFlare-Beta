package solarflare.cdb;

typedef WeaponEntry = { var id:String; var name:String; }

/** Packaged item-definition identities, initialized before observation/drawing. */
class WeaponCatalog {
	public static var entries(default, null):Array<WeaponEntry> = [];
	static var byId = new Map<String, WeaponEntry>();
	static var ready = false;
	public static function keep():Void {
		if (ready) return;
		var raw:Dynamic = haxe.Json.parse(haxe.Resource.getString("weapons"));
		var rows:Array<Dynamic> = raw.entries;
		for (row in rows) {
			var entry:WeaponEntry = {id:row.id, name:row.name};
			entries.push(entry); byId.set(entry.id.toLowerCase(), entry);
		}
		ready = true;
	}
	public static function find(id:String):WeaponEntry return id == null ? null : byId.get(StringTools.trim(id).toLowerCase());
	/** Known names canonicalize case; manual IDs remain available for newly added game items. */
	public static function canonicalId(id:String):String {
		if (id == null) return "";
		var entry = find(id);
		return entry == null ? StringTools.trim(id) : entry.id;
	}
}
