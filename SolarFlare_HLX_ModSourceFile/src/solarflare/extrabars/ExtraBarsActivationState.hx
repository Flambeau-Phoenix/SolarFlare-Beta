package solarflare.extrabars;

/** No native writes. One attempt per physical key press; all mode state is transient. */
class ExtraBarsActivationState {
	public var active(default, null):Bool = false;
	public var toggled(default, null):Bool = false;
	public var progress(default, null):Float = 0;
	public var elapsedMs(default, null):Float = 0;
	var recovering = true;
	public var needsRelease(get, never):Bool;
	inline function get_needsRelease():Bool return recovering;
	var prefixLatched = false;
	var keyLatched = false;
	var longStart:Float = -1;
	var longFired = false;
	var lastFrame:Int = -1;
	public function new() {}
	public function reset():Void {
		active = false; toggled = false; progress = 0; elapsedMs = 0; recovering = true;
		prefixLatched = false; keyLatched = false; longStart = -1; longFired = false; lastFrame = -1;
	}
	public function step(frame:Int, now:Float, allowed:Bool, prefixEnabled:Bool, mode:String,
		prefixDown:Bool, prefixPressed:Bool, keyDown:Bool, keyPressed:Bool, nativeModifiers:Int, thresholdMs:Int):Bool {
		if (frame == lastFrame) return false;
		lastFrame = frame;
		if (!allowed || !prefixEnabled || ExtraBarsActivationConfig.modes.indexOf(mode) < 0 || !Math.isFinite(now)) {
			active = false; toggled = false; progress = 0; elapsedMs = 0; longStart = -1;
			recovering = true; prefixLatched = prefixDown || prefixPressed; keyLatched = keyDown || keyPressed; return false;
		}
		if (recovering) {
			if (!prefixDown && !prefixPressed && !keyDown && !keyPressed && nativeModifiers == 0) {
				recovering = false; prefixLatched = false; keyLatched = false; longFired = false;
			}
			return false;
		}
		var prefixEdge = (prefixDown || prefixPressed) && !prefixLatched;
		var keyEdge = (keyDown || keyPressed) && !keyLatched;
		if (prefixDown || prefixPressed) prefixLatched = true; else prefixLatched = false;
		if (keyDown || keyPressed) keyLatched = true; else {
			keyLatched = false; longStart = -1; longFired = false; progress = 0; elapsedMs = 0;
		}
		// Ctrl/Alt/Shift stay native. Never adopt one as a prefix or reinterpret its chord.
		if (nativeModifiers != 0) {
			active = false; progress = 0; elapsedMs = 0; longStart = -1; return false;
		}
		if (mode == "toggle" && prefixEdge) toggled = !toggled;
		active = mode == "toggle" ? toggled : mode == "hold" && prefixDown;
		if (mode != "long_press") return active && keyEdge;
		// Long-press is additive by user choice: native press is never buffered/delayed.
		if (keyEdge && keyDown) { longStart = now; longFired = false; }
		if (!keyDown || longStart < 0 || now < longStart) { active = false; return false; }
		elapsedMs = (now - longStart) * 1000;
		var threshold = ExtraBarsActivationConfig.threshold(thresholdMs);
		progress = Math.min(1, elapsedMs / threshold);
		active = progress >= 1;
		if (!active || longFired) return false;
		longFired = true;
		return true;
	}
}
