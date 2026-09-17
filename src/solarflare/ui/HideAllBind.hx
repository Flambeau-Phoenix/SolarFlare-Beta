package solarflare.ui;

import imgui.ref.BoolRef;
import imgui.ref.IntRef;

/**
 * "Hide All" hotkey: one key that blanks every in-world SolarFlare window.
 *
 * Menu detection can only hide what it recognises, and a window that is merely
 * undrawn is still gone from the player's control. The hotkey is the reliable
 * escape hatch: press it, the overlays stop drawing, the game is unobstructed.
 *
 * The saved value is an index into CHOICES, not a raw key code. Engine key
 * constants are resolved from the live module and are not guaranteed stable
 * across game patches; an index keeps a player's binding meaningful anyway.
 *
 * Codes are resolved once via `ensureCodes()` from the observe phase. Resolving
 * them lazily from the settings draw would put reflection inside a draw loop.
 */
class HideAllBind {
	/** Numpad 0: off the movement/ability rows and unbound in a default Farever profile. */
	public static inline var DEFAULT_CHOICE:Int = 0;

	public static var choice = new IntRef(DEFAULT_CHOICE);
	/** Opt-in: middle click is a camera control for some players, so it is never assumed. */
	public static var middleMouse = new BoolRef(false);

	/** Combo item list; order must match `resolve()`. */
	public static inline var ITEMS:String = "Numpad 0\x00Numpad 1\x00Numpad 2\x00Numpad 3\x00Numpad 4\x00Numpad 5"
		+ "\x00Numpad 6\x00Numpad 7\x00Numpad 8\x00Numpad 9\x00Numpad .\x00Numpad *\x00Numpad -\x00Numpad +"
		+ "\x00Pause / Break\x00Scroll Lock\x00Insert\x00End\x00No key\x00";

	static inline var COUNT:Int = 19;
	static inline var NONE:Int = 18;

	static var codes:Array<Int> = null;

	public static function keep():Void {}

	/** Resolve every candidate once. Safe to call every observe tick; only the first works. */
	public static function ensureCodes():Void {
		if (codes != null)
			return;
		var out:Array<Int> = [];
		for (i in 0...COUNT) {
			var c = -1;
			try
				c = resolve(i)
			catch (_:Dynamic)
				c = -1;
			out.push(c);
		}
		codes = out;
	}

	/** Engine key code for the current binding, or -1 when unresolved or unbound. */
	public static function code():Int {
		if (codes == null)
			return -1;
		var i = choice.get();
		if (i < 0 || i >= COUNT || i == NONE)
			return -1;
		return codes[i];
	}

	static function resolve(i:Int):Int {
		return switch (i) {
			case 0: hxd.Key.NUMPAD_0;
			case 1: hxd.Key.NUMPAD_1;
			case 2: hxd.Key.NUMPAD_2;
			case 3: hxd.Key.NUMPAD_3;
			case 4: hxd.Key.NUMPAD_4;
			case 5: hxd.Key.NUMPAD_5;
			case 6: hxd.Key.NUMPAD_6;
			case 7: hxd.Key.NUMPAD_7;
			case 8: hxd.Key.NUMPAD_8;
			case 9: hxd.Key.NUMPAD_9;
			case 10: hxd.Key.NUMPAD_DOT;
			case 11: hxd.Key.NUMPAD_MULT;
			case 12: hxd.Key.NUMPAD_SUB;
			case 13: hxd.Key.NUMPAD_ADD;
			case 14: hxd.Key.PAUSE_BREAK;
			case 15: hxd.Key.SCROLL_LOCK;
			case 16: hxd.Key.INSERT;
			case 17: hxd.Key.END;
			default: -1;
		};
	}
}
