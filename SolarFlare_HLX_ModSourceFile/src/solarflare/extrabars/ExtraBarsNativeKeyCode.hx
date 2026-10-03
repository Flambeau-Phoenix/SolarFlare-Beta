package solarflare.extrabars;

/** Explicit Win32 VK translation; persisted Heaps IDs are a different namespace. */
class ExtraBarsNativeKeyCode {
	public static function fromName(name:String):Int {
		if (name.length == 1) {
			var letter = name.charCodeAt(0);
			if (letter >= 65 && letter <= 90) return letter;
		}
		if (StringTools.startsWith(name, "NUMBER_") && name.length == 8) {
			var digit = name.charCodeAt(7) - 48;
			if (digit >= 0 && digit <= 9) return 48 + digit;
		}
		if (StringTools.startsWith(name, "NUMPAD_") && name.length == 8) {
			var digit = name.charCodeAt(7) - 48;
			if (digit >= 0 && digit <= 9) return 96 + digit;
		}
		if (name.charAt(0) == "F") {
			var number = Std.parseInt(name.substr(1));
			if (number != null && number >= 1 && number <= 24 && name == "F" + number) return 111 + number;
		}
		return switch(name) {
			case "SPACE": 32; case "TAB": 9; case "ENTER": 13;
			case "DELETE": 46; case "INSERT": 45; case "HOME": 36; case "END": 35;
			case "PGUP": 33; case "PGDOWN": 34; case "LEFT": 37; case "RIGHT": 39;
			case "UP": 38; case "DOWN": 40; case "BACKSPACE": 8;
			case "QWERTY_QUOTE": 222; case "QWERTY_COMMA": 188;
			case "QWERTY_MINUS": 189; case "QWERTY_PERIOD": 190;
			case "QWERTY_SLASH": 191; case "QWERTY_SEMICOLON": 186;
			case "QWERTY_EQUALS": 187; case "QWERTY_BRACKET_LEFT": 219;
			case "QWERTY_BRACKET_RIGHT": 221; case "QWERTY_BACKSLASH": 220;
			case "QWERTY_TILDE": 192; case "NUMPAD_ADD": 107;
			case "NUMPAD_SUB": 109; case "NUMPAD_MULT": 106;
			case "NUMPAD_DIV": 111; case "NUMPAD_DOT": 110;
			default: 0;
		}
	}
}
