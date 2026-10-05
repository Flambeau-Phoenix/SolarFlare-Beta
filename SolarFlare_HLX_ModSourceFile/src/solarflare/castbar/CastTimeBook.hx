package solarflare.castbar;

typedef CastTimeEntry = {
	var skillId:String;
	var rank:Null<Int>;
	var castSeconds:Null<Float>;
	var recentSamples:Array<Float>;
	var observedFrom:Array<String>;
	var lastObservedAt:String;
}

/** Raw episode evidence only. Never accepts resolved/CDB/manual presentation values. */
class CastTimeBook {
	public var sourceFingerprint(default, null):String;
	public var dirty(default, null):Bool = false;
	var entries:Map<String, CastTimeEntry> = new Map();
	var recentEpisodes:Map<String, Array<Int>> = new Map();
	public function new(fingerprint:String) { sourceFingerprint = fingerprint; }
	public static inline function validSeconds(v:Float):Bool return Math.isFinite(v) && v > 0.001 && v <= 600;
	public static inline function validRank(rank:Null<Int>):Bool return rank == null || rank >= 1;
	static inline function key(id:String, rank:Null<Int>):String return id + "|" + (rank == null ? "unknown" : Std.string(rank));

	public static function stable(samples:Array<Float>):Null<Float> {
		if (samples == null || samples.length < 2 || samples.length > 5) return null;
		for (v in samples) if (!validSeconds(v)) return null;
		var sorted = samples.copy(); sorted.sort(function(a, b) return a < b ? -1 : a > b ? 1 : 0);
		var n = sorted.length;
		var mid = Std.int(n / 2);
		var median = n % 2 == 1 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
		return sorted[n - 1] - sorted[0] <= Math.max(0.05, median * 0.05) + 1e-9 ? median : null;
	}

	/** A positive raw remaining time prevents cancellation elapsed from becoming a sample. */
	public function observe(id:String, rank:Null<Int>, episode:Int, elapsed:Float, remaining:Float, actorSource:String, utc:String):Bool {
		if (id == null || id.length == 0 || !validRank(rank) || episode <= 0
			|| (actorSource != "player" && actorSource != "target") || utc == null
			|| !~/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/.match(utc)
			|| !Math.isFinite(elapsed) || elapsed < 0 || !Math.isFinite(remaining) || remaining <= 0
			|| !validSeconds(elapsed + remaining)) return false;
		var k = key(id, rank);
		var episodes = recentEpisodes.get(k);
		if (episodes == null) { episodes = []; recentEpisodes.set(k, episodes); }
		if (episodes.indexOf(episode) >= 0) return false;
		episodes.push(episode); if (episodes.length > 5) episodes.shift();
		var row = entries.get(k);
		if (row == null) {
			row = {skillId:id, rank:rank, castSeconds:null, recentSamples:[], observedFrom:[], lastObservedAt:utc};
			entries.set(k, row);
		}
		row.recentSamples.push(elapsed + remaining);
		if (row.recentSamples.length > 5) row.recentSamples.shift();
		row.castSeconds = stable(row.recentSamples);
		if (row.observedFrom.indexOf(actorSource) < 0) row.observedFrom.push(actorSource);
		row.lastObservedAt = utc;
		dirty = true;
		return true;
	}
	public function seconds(id:String, rank:Null<Int>):Float {
		var row = entries.get(key(id, rank));
		return row != null && row.castSeconds != null ? row.castSeconds : 0;
	}
	public function samples(id:String, rank:Null<Int>):Array<Float> {
		var row = entries.get(key(id, rank)); return row == null ? [] : row.recentSamples.copy();
	}
	public function ranks(id:String):Array<Null<Int>> {
		var result:Array<Null<Int>> = [];
		for (row in entries) if (row.skillId == id) result.push(row.rank);
		result.sort(function(a, b) return a == null ? (b == null ? 0 : -1) : b == null ? 1 : a - b);
		return result;
	}
	public function markSaved():Void { dirty = false; }
	public function toJson():String {
		var rows = [for (row in entries) row];
		rows.sort(function(a, b) return Reflect.compare(key(a.skillId, a.rank), key(b.skillId, b.rank)));
		return haxe.Json.stringify({version:1, sourceFingerprint:sourceFingerprint, skills:rows}, null, "  ") + "\n";
	}
	public static function fromJson(text:String):CastTimeBook {
		var doc:Dynamic = haxe.Json.parse(text);
		if (doc == null || doc.version != 1 || !Std.isOfType(doc.sourceFingerprint, String)
			|| !~/^[0-9a-f]{64}$/.match(doc.sourceFingerprint) || !Std.isOfType(doc.skills, Array)) throw "Invalid cast-time document";
		var book = new CastTimeBook(doc.sourceFingerprint);
		var rows:Array<Dynamic> = doc.skills;
		for (row in rows) {
			if (row == null || !Std.isOfType(row.skillId, String) || row.skillId.length == 0 || !Reflect.hasField(row, "rank")
				|| (row.rank != null && (!Std.isOfType(row.rank, Int) || row.rank < 1))
				|| !Std.isOfType(row.recentSamples, Array) || !Std.isOfType(row.observedFrom, Array)
				|| !Std.isOfType(row.lastObservedAt, String) || !~/^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\dZ$/.match(row.lastObservedAt)
				|| !Reflect.hasField(row, "castSeconds")) throw "Invalid cast-time entry";
			var values:Array<Dynamic> = row.recentSamples;
			if (values.length < 1 || values.length > 5) throw "Invalid cast samples";
			var samples:Array<Float> = [];
			for (v in values) {
				if (!Std.isOfType(v, Float) || !validSeconds(v)) throw "Invalid cast sample";
				samples.push(v);
			}
			var sources:Array<String> = [];
			var rawSources:Array<Dynamic> = row.observedFrom;
			for (v in rawSources) {
				if (v != "player" && v != "target") throw "Invalid actor source";
				if (sources.indexOf(v) < 0) sources.push(v);
			}
			if (sources.length == 0) throw "Missing actor source";
			var resolved = stable(samples);
			if (row.castSeconds != null && (!Std.isOfType(row.castSeconds, Float) || resolved == null
				|| Math.abs(row.castSeconds - resolved) > 1e-6)) throw "Invalid resolved cast time";
			if (row.castSeconds == null && resolved != null) throw "Missing stable cast time";
			var k = key(row.skillId, row.rank);
			if (book.entries.exists(k)) throw "Duplicate cast key";
			book.entries.set(k, {skillId:row.skillId, rank:row.rank, castSeconds:resolved,
				recentSamples:samples, observedFrom:sources, lastObservedAt:row.lastObservedAt});
		}
		return book;
	}
}
