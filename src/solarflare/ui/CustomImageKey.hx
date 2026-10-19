package solarflare.ui;

/** Portable image identity shared by aura data and the file/texture services. No I/O. */
class CustomImageKey {
	public static inline var PREFIX:String = "custom:";
	public static function managedStem(hash:String):String return "sfshare_"+hash;
	public static function isManagedStem(stem:String):Bool return stem!=null && ~/^sfshare_[a-f0-9]{64}$/.match(stem.toLowerCase());
	public static inline function key(stem:String):String return PREFIX + stem;
	public static function stemOf(key:String):String {
		return key != null && StringTools.startsWith(key, PREFIX) ? key.substr(PREFIX.length) : "";
	}
}
