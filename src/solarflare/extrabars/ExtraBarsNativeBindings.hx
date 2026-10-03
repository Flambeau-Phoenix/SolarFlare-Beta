package solarflare.extrabars;

import solarflare.EngineText;
import solarflare.ui.HideAllBind;

/** Read-only effective bindings. Prototype conservatively reserves native base keys. */
class ExtraBarsNativeBindings {
	var index = new ExtraBarsBindingIndex();
	public var known(get, never):Bool;
	inline function get_known():Bool return index.known;
	public var error(get, never):String;
	inline function get_error():String return index.error;
	var lastRead:Float = -1;
	public function new() {}
	public function refresh(now:Float, force:Bool = false):Void {
		if (!force && now - lastRead < 1) return;
		lastRead = now; index.begin();
		try {
			var defaults = lib.Input.defaultBinds;
			var users = lib.Input.userBinds;
			if (defaults == null || users == null) throw "Native binding maps unavailable.";
			var ids = new Map<String, Bool>();
			function append(map:hlx.std.haxe.ds.StringMap):Void {
				var it = map.keys();
				if (it == null) throw "Native key iterator unavailable.";
				var n = 0;
				while (it.hasNext()) {
					if (++n > 512) throw "Native binding inventory exceeds the bounded read.";
					var id = EngineText.cleanId(it.next());
					if (id.length == 0) throw "Unresolved native action ID.";
					ids.set(id, true);
				}
			}
			append(defaults); append(users);
			var n = 0;
			for (id in ids.keys()) {
				n++;
				var bindings = lib.Input.getBindings(id);
				if (bindings == null || bindings.length < 0 || bindings.length > 32) throw "Cannot inspect bindings for " + id;
				for (i in 0...bindings.length) {
					var raw = bindings.getDyn(i);
					if (raw == null) throw "Unreadable binding for " + id;
					// Nullable code is intentional for pad-only and cleared native bindings.
					var value:Dynamic = HlxRuntime.resolveField(raw, "code");
					if (!index.add(id, value)) throw index.error;
				}
			}
			index.complete(n);
		} catch (e:Dynamic) { index.fail(Std.string(e)); }
	}
	public function describe(code:Int):String return index.describe(code);
	public function conflict(code:Int, mods:Int, allowNativeBase:Bool = false):String {
		if (ExtraBarsKeyMap.find(code) == null) return "Choose a supported keyboard key.";
		if (code == ExtraBarsKeyMap.f6 || code == ExtraBarsKeyMap.f12) return "Reserved for SolarFlare.";
		if (code == HideAllBind.code()) return "Reserved for SolarFlare Hide All.";
		if ((mods & 1) != 0 && ExtraBarsKeyMap.find(code).label == "S") return "Reserved for SolarFlare Save.";
		if (!index.known) return "Binding inactive: " + index.error;
		return allowNativeBase ? "" : index.conflict(code);
	}
}
