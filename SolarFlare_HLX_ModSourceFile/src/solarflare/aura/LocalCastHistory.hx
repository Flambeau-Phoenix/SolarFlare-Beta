package solarflare.aura;

/** Bounded local skill-use history. Fed by the existing observer; no game polling. */
class LocalCastHistory {
	public static inline var MAX:Int = 64;
	public static var shared = new LocalCastHistory();
	public var records(default, null):Array<LocalCastRecord> = [];
	var hero:Dynamic;
	var sequence:Int = 0;
	public function new() {}
	public function bindHero(value:Dynamic):Void {
		if (hero == value) return;
		hero = value;
		records.resize(0);
	}
	public function note(id:String, now:Float, statusIds:Array<String> = null, statusKnown:Bool = false):Void {
		if (hero == null || id == null || id.length == 0 || !Math.isFinite(now)) return;
		var key = StringTools.trim(id).toLowerCase();
		var record = find(key);
		if (record == null) {
			if (records.length >= MAX) records.shift();
			record = new LocalCastRecord(key);
			records.push(record);
		}
		record.at = now;
		record.serial = ++sequence;
		record.statusIds = statusIds != null ? statusIds.copy() : [];
		record.statusKnown = statusKnown;
	}
	public function find(id:String):LocalCastRecord {
		if (id == null) return null;
		var key = StringTools.trim(id).toLowerCase();
		for (r in records) if (r.skillId == key) return r;
		return null;
	}
}

class LocalCastRecord {
	public var skillId:String;
	public var at:Float = 0;
	public var serial:Int = 0;
	public var statusIds:Array<String> = [];
	public var statusKnown:Bool = false;
	public function new(id:String) skillId = id;
}

/** Returns unknown for incomplete status snapshots; never invents a missing buff. */
class CastStatusSnapshot {
	public static function present(ids:Array<String>, known:Bool, subject:String):Null<Bool> {
		var key = subject == null ? "" : StringTools.trim(subject).toLowerCase();
		if (ids != null) for (id in ids) if (id == key) return true;
		return known ? false : null;
	}
}
