package solarflare.aura.signal;

class SkillSignalSnap {
	public var rawId:String = "";
	public var aliasId:String = "";
	public var label:String = "";
	public var ready:Bool = false;
	public var affordable:Bool = false;
	public var inCooldown:Bool = false;
	public var cooldownLeft:Float = 0;
	public var cooldownProgress:Float = 0;
	public var known:Bool = false;
	public function new() {}
	public function reset():Void {
		rawId = ""; aliasId = ""; label = ""; ready = false; affordable = false;
		inCooldown = false; cooldownLeft = 0; cooldownProgress = 0; known = false;
	}
}
