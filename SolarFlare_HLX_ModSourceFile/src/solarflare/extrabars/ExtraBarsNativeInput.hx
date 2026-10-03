package solarflare.extrabars;

/** Native transport only. Item resolution/use remains in observation. */
class ExtraBarsNativeInput {
	@:hlNative("sfcursor", "extra_configure_many")
	public static function configureMany(prefix:Int, mode:Int, eligible:Bool, generation:Int, keys:hl.Bytes, length:Int):Int return -1;
	@:hlNative("sfcursor", "extra_configure")
	public static function configure(prefix:Int, key:Int, mode:Int, eligible:Bool, generation:Int):Int return -1;
	@:hlNative("sfcursor", "extra_take")
	public static function take(generation:Int):Int return 0;
	@:hlNative("sfcursor", "extra_status")
	public static function status():Int return 0;
	@:hlNative("sfcursor", "extra_reset")
	public static function reset():Void {}
	@:hlNative("sfcursor", "extra_shutdown")
	public static function shutdown():Bool return false;
	public static function prefixCode(prefix:String):Int return switch(prefix) {
		case "mouse_back": 5; case "mouse_forward": 6; case "x": 88; case "c": 67;
		case "tab": 9; case "capslock": 20; default: 0;
	};
}
