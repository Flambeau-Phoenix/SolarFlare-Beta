package solarflare.util;

/** Interned decimal strings for small counters drawn every frame (cooldown seconds, charges, stacks). */
class IntText {
	static inline var LIMIT:Int = 1024;
	static var table:Array<String> = [];

	public static function of(n:Int):String {
		if (n < 0 || n >= LIMIT)
			return Std.string(n);
		var s = table[n];
		if (s == null) {
			s = Std.string(n);
			table[n] = s;
		}
		return s;
	}
}
