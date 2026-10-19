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

	/** Plain-words state of the key filter. Native-free logic lives here so it can be tested. */
	public static function describeArming(enabled:Bool, available:Bool, gate:String, routeCount:Int, firstIssue:String, active:Bool, nativeBits:Int, mode:String):String {
		var label = modeLabel(mode);
		if (!enabled) return label + ": ExtraBars is switched off (All bars enabled).";
		if (!available) return label + ": choose an activation modifier.";
		if (gate.length > 0) return label + ": paused. " + gate;
		if (routeCount == 0) return label + ": no key is live. " + (firstIssue.length > 0 ? firstIssue : "Assign an item and a key to a cell of an enabled bar.");
		if (active) return label + ": live on " + routeCount + " key" + (routeCount == 1 ? "" : "s") + ".";
		if ((nativeBits & 2) != 0) return label + ": waiting until every assigned key and modifier is released.";
		return label + ": the native key filter is not armed yet (" + routeCount + " key" + (routeCount == 1 ? "" : "s") + " ready). If this stays, alt-tab out and back in, then check for a native key conflict.";
	}
}
