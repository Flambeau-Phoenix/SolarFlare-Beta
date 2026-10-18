package solarflare.ui;

/** Portable image identity shared by aura data and the file/texture services. No I/O. */
class CustomImageKey {
	public static inline var PREFIX:String = "custom:";
	public static inline function key(stem:String):String return PREFIX + stem;
	public static function stemOf(key:String):String {
		return key != null && StringTools.startsWith(key, PREFIX) ? key.substr(PREFIX.length) : "";
	}
}
