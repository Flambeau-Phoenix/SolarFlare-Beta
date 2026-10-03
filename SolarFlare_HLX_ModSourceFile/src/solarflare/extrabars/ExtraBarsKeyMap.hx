package solarflare.extrabars;

import imgui.ImGui;
import imgui.Enums.ImGuiKey;

typedef ExtraBarsKey = {var imgui:Int; var code:Int; var nativeCode:Int; var label:String;}

/** Explicit translation, resolved once from the installed game in observation. */
class ExtraBarsKeyMap {
	public static var keys(default, null):Array<ExtraBarsKey> = [];
	static var initialized = false;
	static var prefixCodes:Map<String, Int> = new Map();
	static var leftCtrl = 0; static var rightCtrl = 0;
	static var leftShift = 0; static var rightShift = 0;
	static var leftAlt = 0; static var rightAlt = 0;
	public static var ctrl:Int = 0;
	public static var shift:Int = 0;
	public static var alt:Int = 0;
	public static var f6:Int = 0;
	public static var f12:Int = 0;
	public static var error:String = "";
	public static function initialize():Void {
		if (initialized) return;
		try {
			var type = HlxRuntime.resolveType("hxd.Key");
			if (type == null) throw "hxd.Key unavailable";
			function code(name:String):Int {
				var value:Dynamic = HlxRuntime.resolveStaticField(type, name);
				if (value == null) throw "Missing key constant " + name;
				return value;
			}
			function add(imgui:Int, name:String, label:String):Void {
				var nativeCode = ExtraBarsNativeKeyCode.fromName(name);
				if (nativeCode == 0) throw "Missing Win32 key mapping " + name;
				keys.push({imgui:imgui, code:code(name), nativeCode:nativeCode, label:label});
			}
			ctrl = code("CTRL"); shift = code("SHIFT"); alt = code("ALT");
			leftCtrl = code("LCTRL"); rightCtrl = code("RCTRL");
			leftShift = code("LSHIFT"); rightShift = code("RSHIFT");
			leftAlt = code("LALT"); rightAlt = code("RALT");
			f6 = code("F6"); f12 = code("F12");
			prefixCodes.set("mouse_back", code("MOUSE_BACK")); prefixCodes.set("mouse_forward", code("MOUSE_FORWARD"));
			prefixCodes.set("x", code("X")); prefixCodes.set("c", code("C"));
			prefixCodes.set("tab", code("TAB")); prefixCodes.set("capslock", code("CAPS_LOCK"));
			for (i in 0...26) { var name = String.fromCharCode(65 + i); add(ImGuiKey.A + i, name, name); }
			for (i in 0...10) {
				add(ImGuiKey._0 + i, "NUMBER_" + i, Std.string(i));
				add(ImGuiKey.Keypad0 + i, "NUMPAD_" + i, "Numpad " + i);
			}
			for (i in 0...24) add(ImGuiKey.F1 + i, "F" + (i + 1), "F" + (i + 1));
			var extra = [
				{imgui:ImGuiKey.Space, name:"SPACE", label:"Space"},
				{imgui:ImGuiKey.Tab, name:"TAB", label:"Tab"},
				{imgui:ImGuiKey.Enter, name:"ENTER", label:"Enter"},
				{imgui:ImGuiKey.Delete, name:"DELETE", label:"Delete"},
				{imgui:ImGuiKey.Insert, name:"INSERT", label:"Insert"},
				{imgui:ImGuiKey.Home, name:"HOME", label:"Home"},
				{imgui:ImGuiKey.End, name:"END", label:"End"},
				{imgui:ImGuiKey.PageUp, name:"PGUP", label:"Page Up"},
				{imgui:ImGuiKey.PageDown, name:"PGDOWN", label:"Page Down"},
				{imgui:ImGuiKey.LeftArrow, name:"LEFT", label:"Left"},
				{imgui:ImGuiKey.RightArrow, name:"RIGHT", label:"Right"},
				{imgui:ImGuiKey.UpArrow, name:"UP", label:"Up"},
				{imgui:ImGuiKey.DownArrow, name:"DOWN", label:"Down"},
				{imgui:ImGuiKey.Backspace, name:"BACKSPACE", label:"Backspace"},
				{imgui:ImGuiKey.Apostrophe, name:"QWERTY_QUOTE", label:"Quote"},
				{imgui:ImGuiKey.Comma, name:"QWERTY_COMMA", label:","},
				{imgui:ImGuiKey.Minus, name:"QWERTY_MINUS", label:"-"},
				{imgui:ImGuiKey.Period, name:"QWERTY_PERIOD", label:"."},
				{imgui:ImGuiKey.Slash, name:"QWERTY_SLASH", label:"/"},
				{imgui:ImGuiKey.Semicolon, name:"QWERTY_SEMICOLON", label:";"},
				{imgui:ImGuiKey.Equal, name:"QWERTY_EQUALS", label:"="},
				{imgui:ImGuiKey.LeftBracket, name:"QWERTY_BRACKET_LEFT", label:"["},
				{imgui:ImGuiKey.RightBracket, name:"QWERTY_BRACKET_RIGHT", label:"]"},
				{imgui:ImGuiKey.Backslash, name:"QWERTY_BACKSLASH", label:"Backslash"},
				{imgui:ImGuiKey.GraveAccent, name:"QWERTY_TILDE", label:"Grave"},
				{imgui:ImGuiKey.KeypadAdd, name:"NUMPAD_ADD", label:"Numpad +"},
				{imgui:ImGuiKey.KeypadSubtract, name:"NUMPAD_SUB", label:"Numpad -"},
				{imgui:ImGuiKey.KeypadMultiply, name:"NUMPAD_MULT", label:"Numpad *"},
				{imgui:ImGuiKey.KeypadDivide, name:"NUMPAD_DIV", label:"Numpad /"},
				{imgui:ImGuiKey.KeypadDecimal, name:"NUMPAD_DOT", label:"Numpad ."}
			];
			for (entry in extra) add(entry.imgui, entry.name, entry.label);
			initialized = true; error = "";
		} catch (e:Dynamic) { keys.resize(0); error = Std.string(e); }
	}
	public static function prefixCode(value:String):Int {
		var code = prefixCodes.get(value); return code == null ? 0 : code;
	}
	public static function prefixUIDown(value:String):Bool return switch(value) {
		case "mouse_back": ImGui.isMouseDown(3);
		case "mouse_forward": ImGui.isMouseDown(4);
		case "capslock": ImGui.isKeyDown(ImGuiKey.CapsLock);
		default: var mapped = find(prefixCode(value)); mapped != null && ImGui.isKeyDown(mapped.imgui);
	};
	public static function find(code:Int):ExtraBarsKey {
		for (entry in keys) if (entry.code == code) return entry;
		return null;
	}
	public static function label(code:Int, mods:Int):String {
		var entry = find(code);
		if (entry == null) return code > 0 ? "Unresolved key" : "Unbound";
		return ((mods & 1) != 0 ? "Ctrl+" : "") + ((mods & 2) != 0 ? "Shift+" : "")
			+ ((mods & 4) != 0 ? "Alt+" : "") + entry.label;
	}
	/** Compact key cap; the complete chord remains available in caption/tooltip. */
	public static function keyHint(code:Int):String {
		var entry = find(code);
		if (entry == null) return "";
		if (StringTools.startsWith(entry.label, "Numpad ")) return "NP" + entry.label.substr(7);
		return switch (entry.label) {
			case "Backspace": "Bksp";
			case "Page Up": "PgUp";
			case "Page Down": "PgDn";
			case "Delete": "Del";
			case "Insert": "Ins";
			case "Backslash": "\\";
			case "Quote": "'";
			default: entry.label;
		}
	}
	public static function modifierHint(mods:Int):String {
		var labels:Array<String> = [];
		if ((mods & 1) != 0) labels.push("C");
		if ((mods & 2) != 0) labels.push("S");
		if ((mods & 4) != 0) labels.push("A");
		return labels.join("/");
	}
	public static function gameModifiers():Int {
		return ((hxd.Key.isDown(ctrl) || hxd.Key.isDown(leftCtrl) || hxd.Key.isDown(rightCtrl)) ? 1 : 0)
			| ((hxd.Key.isDown(shift) || hxd.Key.isDown(leftShift) || hxd.Key.isDown(rightShift)) ? 2 : 0)
			| ((hxd.Key.isDown(alt) || hxd.Key.isDown(leftAlt) || hxd.Key.isDown(rightAlt)) ? 4 : 0);
	}
	public static function uiModifiers():Int {
		return ((ImGui.isKeyDown(ImGuiKey.LeftCtrl) || ImGui.isKeyDown(ImGuiKey.RightCtrl)) ? 1 : 0)
			| ((ImGui.isKeyDown(ImGuiKey.LeftShift) || ImGui.isKeyDown(ImGuiKey.RightShift)) ? 2 : 0)
			| ((ImGui.isKeyDown(ImGuiKey.LeftAlt) || ImGui.isKeyDown(ImGuiKey.RightAlt)) ? 4 : 0);
	}
}
