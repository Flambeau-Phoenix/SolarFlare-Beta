package solarflare.aura.signal;

class StatusSignalSnap {
	public var rawId:String = "";
	public var ids:Array<String> = [];
	public var present:Bool = true;
	public var durationKnown:Bool = false;
	public var label:String = "";
	public var stacks:Int = 0;
	public var durationLeft:Float = 0;
	public var durationProgress:Float = 0;
	public var infinite:Bool = false;
	public var known:Bool = false;
	public function new() {}
	public function reset():Void { rawId = ""; ids = []; present = true; durationKnown = false; label = ""; stacks = 0; durationLeft = 0; durationProgress = 0; infinite = false; known = false; }
}
