package solarflare.extrabars;

import solarflare.aura.signal.ConsumableSignalSnap;

/** Presentation-only values copied during observation; no item/hero/stack references. */
class ExtraBarsPrototypeSlot {
	public var enabled:Bool = false;
	public var name:String = "Unassigned";
	public var icon:String = "";
	public var binding:String = "Unbound";
	public var keyHint:String = "";
	public var modifierHint:String = "";
	public var count:Int = 0;
	public var known:Bool = false;
	public var ready:Bool = false;
	public var reason:String = "";
	public var progress:Float = 0;
	public var inputActive:Bool = false;
	public var inputLabel:String = "Toggle OFF";
	public var inputDetail:String = "Native keys active";
	/** Fading feedback for a submitted use request, frozen during observation. */
	public var triggerStrength:Float = 0;
	public function new() {}
	public function setInputState(active:Bool, mode:String):Void {
		inputActive = active && (mode == "hold" || mode == "toggle");
		inputLabel = (mode == "hold" ? "Hold" : "Toggle") + (inputActive ? " ON" : " OFF");
		inputDetail = inputActive ? "ExtraBars keys active" : "Native keys active";
	}
	public function update(enabled:Bool, name:String, icon:String, binding:String, reason:String, signal:ConsumableSignalSnap, keyHint:String = "", modifierHint:String = ""):Void {
		this.enabled = enabled; this.name = name; this.icon = icon;
		this.binding = binding; this.reason = reason;
		this.keyHint = keyHint; this.modifierHint = modifierHint;
		known = signal != null && signal.known;
		count = known ? signal.count : 0;
		ready = known && count > 0 && signal.usableKnown && signal.usable;
	}
	public function clear():Void {
		setInputState(false, "toggle");
		triggerStrength = 0;
		enabled = false; name = "Unassigned"; icon = ""; binding = "Unbound";
		keyHint = ""; modifierHint = ""; progress = 0;
		count = 0; known = false; ready = false; reason = "Waiting for gameplay.";
	}
}
