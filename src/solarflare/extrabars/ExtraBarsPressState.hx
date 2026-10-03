package solarflare.extrabars;

/** One press, one request. Blocked/changed sessions must observe release first. */
class ExtraBarsPressState {
	var lastFrame:Int = -1;
	var armed:Bool = false;
	var recovering:Bool = true;
	public function new() {}
	public function reset():Void { armed = false; recovering = true; lastFrame = -1; }
	public function step(frame:Int, allowed:Bool, down:Bool, pressed:Bool, actualMods:Int, requiredMods:Int):Bool {
		if (frame == lastFrame) return false;
		lastFrame = frame;
		if (!allowed) { armed = false; recovering = true; return false; }
		if (recovering) {
			if (!down && !pressed && actualMods == 0) { recovering = false; armed = true; }
			return false;
		}
		if (pressed) {
			var fire = armed && actualMods == requiredMods;
			armed = false;
			return fire;
		}
		if (!down) armed = true;
		return false;
	}
}
