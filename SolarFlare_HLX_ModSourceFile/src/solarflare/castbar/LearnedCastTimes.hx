package solarflare.castbar;

import solarflare.castbar.CastDurationResolver.CastDuration;
import solarflare.ui.ModPaths;

/** Startup/observe owns disk access. Quick Build and renderers only read cached data. */
class LearnedCastTimes {
	static var store:CastTimeStore = null;
	public static function keep():Void {
		if (store != null) return;
		var fingerprint = "";
		try {
			var path = ModPaths.findCdbFile("patch-source.json");
			if (path != null) fingerprint = haxe.Json.parse(sys.io.File.getContent(path)).sha256;
		} catch (_:Dynamic) {}
		store = new CastTimeStore(ModPaths.child("assets/cdb/skill-cast-times.json"), fingerprint);
	}
	public static function resolve(id:String, rank:Null<Int>):CastDuration {
		return CastDurationResolver.resolve(store == null ? null : store.book, id, rank, solarflare.cdb.CdbAuraTable.castDuration(id));
	}
	public static function ranks(id:String):Array<Null<Int>> return store == null ? [] : store.book.ranks(id);
	public static function observe(id:String, rank:Null<Int>, episode:Int, elapsed:Float, remaining:Float, actorSource:String):Bool {
		if (store == null || !store.canLearn) return false;
		return store.book.observe(id, rank, episode, elapsed, remaining, actorSource, utcNow());
	}
	public static function tick(now:Float, shutdown:Bool = false):Void { if (store != null) store.flush(now, shutdown); }
	static function utcNow():String {
		var date = Date.now();
		return date.getUTCFullYear() + "-" + pad(date.getUTCMonth() + 1) + "-" + pad(date.getUTCDate()) + "T"
			+ pad(date.getUTCHours()) + ":" + pad(date.getUTCMinutes()) + ":" + pad(date.getUTCSeconds()) + "Z";
	}
	static inline function pad(value:Int):String return value < 10 ? "0" + value : Std.string(value);
}
