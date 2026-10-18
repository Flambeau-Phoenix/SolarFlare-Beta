package solarflare.aura.signal;

/** Frozen primitives only; item instances and hero pointers never enter the frame. */
class WeaponSignalSnap {
	public var id:String = "";
	public var known:Bool = false;
	public var equipped:Bool = false;
	public function new() {}
	public function reset():Void { known = false; equipped = false; }
}
