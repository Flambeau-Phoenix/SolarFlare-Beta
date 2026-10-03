package solarflare.extrabars;

/** Capture waits for release both before recording and before accepting/cancelling. */
class ExtraBarsCaptureState {
	public var active(default, null):Bool = false;
	public var waitingRelease(default, null):Bool = false;
	public var key(default, null):Int = 0;
	public var modifiers(default, null):Int = 0;
	public var message(default, null):String = "";
	var primed = false;
	public function new() {}
	public function start():Void {
		clear(); active = true; waitingRelease = true;
		message = "Release held keys, then press your chord. Escape cancels.";
	}
	public function clear():Void {
		active = false; waitingRelease = false; primed = false; key = 0; modifiers = 0;
	}
	public function step(anyDown:Bool, escapePressed:Bool, pressedKey:Int, mods:Int):Void {
		if (!waitingRelease) return;
		if (escapePressed) {
			active = false; key = 0; message = "Binding cancelled. Release the keys.";
			anyDown = true;
		}
		if (active) {
			if (!primed) { if (!anyDown) primed = true; return; }
			if (pressedKey > 0) {
				key = pressedKey; modifiers = mods; active = false;
				message = "Release the chord to validate it.";
			}
		}
		if (!active && !anyDown) waitingRelease = false;
	}
	public function takeKey():Int {
		if (waitingRelease) return 0;
		var result = key; key = 0; return result;
	}
}
