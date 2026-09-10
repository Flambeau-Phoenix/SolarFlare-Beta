package solarflare.localtime;

import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import solarflare.ui.HudChrome;

/**
 * Stub kept so settings JSON fields remain loadable.
 * SolarFlare does not ship the Local Time overlay.
 */
class LocalTimeConfig {
	public var open = new BoolRef(false);
	public var enabled = new BoolRef(false);
	public var width = new FloatRef(160);
	public var height = new FloatRef(48);
	public var sizeDirty = false;
	public var chrome:HudChrome;

	public function new() {
		chrome = new HudChrome(20, 20);
	}

	public function draw():Void {}
}

class LocalTimeOverlay {
	public function new() {}

	public function draw(cfg:LocalTimeConfig):Void {}
}
