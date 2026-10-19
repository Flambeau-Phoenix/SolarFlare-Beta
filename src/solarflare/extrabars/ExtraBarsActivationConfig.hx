package solarflare.extrabars;

/** Primitive remembered activation settings. */
class ExtraBarsActivationConfig {
	public static var prefixes(default, null):Array<String> = ["mouse_back", "mouse_forward", "x", "c", "tab", "capslock", "off"];
	public static var modes(default, null):Array<String> = ["hold", "toggle", "long_press", "always"];
	/** Legacy mode remains readable in saved settings, but is no longer offered. */
	public static var liveModes(default, null):Array<String> = ["hold", "toggle", "always"];
	public static function prefixLabel(value:String):String return switch(value) {
		case "mouse_back": "Mouse-Back"; case "mouse_forward": "Mouse-Forward";
		case "x": "X"; case "c": "C"; case "tab": "Tab"; case "capslock": "CapsLock"; case "off": "Off";
		default: "Unknown";
	};
	public static function modeLabel(value:String):String return switch(value) {
		case "always": "Always Active"; case "hold": "Hold"; case "toggle": "Toggle"; case "long_press": "Long-press"; default: "Unknown";
	};
	/** Compact presentation: '+' means held together, '>' means toggle then press. */
	public static function badge(prefix:String, mode:String, key:String):String {
		if (mode == "always") return key;
		if (key.length == 0 || prefix == "off" || mode == "long_press") return key;
		var hint = switch(prefix) {
			case "mouse_back": "M4"; case "mouse_forward": "M5"; case "capslock": "Caps";
			default: prefixLabel(prefix);
		};
		return hint + (mode == "toggle" ? ">" : "+") + key;
	}
	public static function modifierRequired(mode:String):Bool return mode != "always";
	public static function available(prefix:String,mode:String):Bool return mode == "always" || prefix != "off";
	public static function nativeMode(mode:String):Int return switch(mode) { case "hold": 1; case "toggle": 2; case "always": 3; default: 0; };
	public static function threshold(value:Int):Int return Std.int(Math.max(100, Math.min(2000, value)));
}
