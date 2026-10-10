package solarflare.cdb;

typedef ConsumableEffect = { var id:String; var duration:Float; var shared:Bool; }
typedef ConsumableEntry = {
	var id:String; var name:String; var type:String; var refillable:Bool;
	var statuses:Array<ConsumableEffect>;
}

/** Authored item identities; initialized before UI/observation, never from draw(). */
class ConsumableCatalog {
	public static var entries(default, null):Array<ConsumableEntry> = [];
	static var byId = new Map<String, ConsumableEntry>();
	static var byStatusId = new Map<String, ConsumableEntry>();
	static var ready = false;
	public static function keep():Void {
		if (ready) return;
		ready = true;
		var data:Dynamic = haxe.Json.parse(haxe.Resource.getString("consumables"));
		var rows:Array<Dynamic> = data.entries;
		for (row in rows) {
			var entry:ConsumableEntry = {id:row.id, name:row.name, type:row.type,
				refillable:row.refillable == true, statuses:[]};
			var effects:Array<Dynamic> = row.statuses;
			for (effect in effects) {
				entry.statuses.push({id:effect.id, duration:effect.duration, shared:effect.shared == true});
				if (effect.id != null) byStatusId.set(effect.id.toLowerCase(), entry);
			}
			entries.push(entry); byId.set(entry.id.toLowerCase(), entry);
		}
	}
	public static function find(id:String):ConsumableEntry return id == null ? null : byId.get(id.toLowerCase());
	public static function findByStatus(statusId:String):ConsumableEntry return statusId == null ? null : byStatusId.get(statusId.toLowerCase());
	public static function iconKey(id:String):String {
		var entry = find(id);
		return entry == null ? "" : "consumable_" + entry.id;
	}
	public static function listedSpan(id:String):Float {
		var entry = find(id);
		var span:Float = 0;
		if (entry != null) for (effect in entry.statuses) if (effect.duration > span) span = effect.duration;
		return span;
	}
}
