package solarflare.extrabars;

/** Detached native keyboard reservations. A nullable code is a valid non-keyboard/unbound row. */
class ExtraBarsBindingIndex {
	public var known(default, null):Bool = false;
	public var error(default, null):String = "Native bindings have not been read.";
	var actions = new Map<Int, String>();
	var failed = false;
	public function new() {}
	public function begin():Void {
		known = false; error = "Native bindings have not been read."; actions.clear(); failed = false;
	}
	public function fail(message:String):Void {
		known = false; failed = true; error = message; actions.clear();
	}
	public function add(action:String, code:Dynamic):Bool {
		if (failed) return false;
		if (action == null || action.length == 0) { fail("Unresolved native action ID."); return false; }
		// GameLib declares code:Null<Int>; pad-only and explicitly cleared bindings have no code.
		if (code == null) return true;
		if (!Std.isOfType(code, Int)) { fail("Invalid native key code for " + action); return false; }
		var value:Int = code;
		if (value <= 0) return true;
		var prior = actions.get(value);
		actions.set(value, prior == null ? action : prior + ", " + action);
		return true;
	}
	public function complete(actionCount:Int):Bool {
		if (failed) return false;
		if (actionCount <= 0) { fail("Native action inventory is empty."); return false; }
		known = true; error = ""; return true;
	}
	public function describe(code:Int):String {
		if (!known) return "unknown";
		var action = actions.get(code); return action == null ? "unbound" : "bound (" + action + ")";
	}
	public function conflict(code:Int):String {
		if (!known) return "Binding inactive: " + error;
		var action = actions.get(code);
		return action == null ? "" : "Native conflict: " + action + ". This base key remains reserved until native modifier matching is verified; use an unbound base key for a modifier chord.";
	}
}
