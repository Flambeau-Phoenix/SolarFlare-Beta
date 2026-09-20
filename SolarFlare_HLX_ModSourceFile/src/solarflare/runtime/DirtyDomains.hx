package solarflare.runtime;

/** Coalescible runtime domains. One bit represents any number of hook edges. */
class DirtyDomains {
	public static inline var IDENTITY:Int = 1 << 0;
	public static inline var VITALS:Int = 1 << 1;
	public static inline var STATUS:Int = 1 << 2;
	public static inline var SKILLS:Int = 1 << 3;
	public static inline var TARGET:Int = 1 << 4;
	public static inline var ENCOUNTER:Int = 1 << 5;
	public static inline var PRAYER:Int = 1 << 6;
	public static inline var COMBO:Int = 1 << 7;
	public static inline var CHAINCAST:Int = 1 << 8;
	public static inline var CONDUIT:Int = 1 << 9;
	public static inline var ATTACK_COMBO:Int = 1 << 10;

	public static inline var OVERLAYS:Int = PRAYER | COMBO | CHAINCAST | CONDUIT;
	public static inline var ALL:Int = IDENTITY | VITALS | STATUS | SKILLS | TARGET
		| ENCOUNTER | OVERLAYS | ATTACK_COMBO;
}
