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
	/** Status instances use skill IDs; statustype is broad category. */
	public static function matchesSubject(entryKind:String, subjectKind:String):Bool {
		if (subjectKind == "unit") return entryKind == "unit";
		if (subjectKind.indexOf("skill") >= 0) return entryKind == "skill";
		// status.* signals: applied IDs are skills (often *_Status).
		return entryKind == "skill" || entryKind == "statustype";
	}

	/** Status picker: status/proc skills, then other skills, then categories. */
	public static function statusPickRank(id:String, kind:String):Int {
		if (kind == "statustype") return 3;
		if (kind != "skill") return 4;
		if (id == null) return 2;
		var low = id.toLowerCase();
		if (StringTools.endsWith(low, "_status") || StringTools.endsWith(low, "_proc")
			|| StringTools.endsWith(low, "status") || StringTools.endsWith(low, "proc")
			|| low.indexOf("_status_") >= 0 || low.indexOf("status_") >= 0
			|| low.indexOf("_proc_") >= 0 || low.indexOf("proc_") >= 0)
			return 0;
		return 2;
	}

	public static function matchesSearch(id:String, name:String, query:String):Bool {
		var needle = searchKey(query);
		return needle.length == 0 || searchKey(id).indexOf(needle) >= 0 || searchKey(name).indexOf(needle) >= 0;
	}
	static function searchKey(value:String):String {
		if (value == null) return "";
		return StringTools.replace(StringTools.replace(StringTools.replace(value.toLowerCase(), "_", ""), "-", ""), " ", "");
	}
	public static function validName(name:String):Bool {
		if (name == null) return false;
		return switch (StringTools.trim(name).toLowerCase()) {
			case "", "n/a", "na", "none", "null": false;
			default: true;
		};
	}
}
