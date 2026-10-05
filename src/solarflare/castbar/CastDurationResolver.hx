package solarflare.castbar;

typedef CastDuration = { var seconds:Float; var source:String; var estimated:Bool; }

/** Presentation-only hierarchy. No cooldown, buff, listed span, or manual override input. */
class CastDurationResolver {
	public static function resolve(book:CastTimeBook, skillId:String, rank:Null<Int>, cdbSeconds:Float):CastDuration {
		var recorded = book == null ? 0 : book.seconds(skillId, rank);
		if (CastTimeBook.validSeconds(recorded)) return {seconds:recorded, source:"recorded", estimated:false};
		if (CastTimeBook.validSeconds(cdbSeconds)) return {seconds:cdbSeconds, source:"cdb", estimated:true};
		return {seconds:0, source:"unknown", estimated:true};
	}
	public static function label(value:CastDuration):String {
		return value.source == "recorded" ? "Recorded cast time" : value.source == "cdb" ? "CDB suggestion" : "Unknown";
	}
}
