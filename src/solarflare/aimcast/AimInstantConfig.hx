package solarflare.aimcast;

import imgui.ref.BoolRef;

/** Ground-target skills cast on the first press instead of waiting for the engine's confirm press. Default off. */
class AimInstantConfig {
	public var enabled = new BoolRef(false);
	public function new() {}
	public function dump():Dynamic return {enabled: enabled.get()};
	public function apply(data:Dynamic):Void {
		enabled.set(data != null && Reflect.field(data, "enabled") == true);
	}
}
