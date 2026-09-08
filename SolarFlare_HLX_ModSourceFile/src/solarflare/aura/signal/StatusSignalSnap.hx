package solarflare.aura.signal;

class StatusSignalSnap {
	public var rawId:String = "";
	public var label:String = "";
	public var stacks:Int = 0;
	public var durationLeft:Float = 0;
	public var durationProgress:Float = 0;
	public var known:Bool = false;
	public function new() {}
	public function reset():Void { rawId = ""; label = ""; stacks = 0; durationLeft = 0; durationProgress = 0; known = false; }
}
