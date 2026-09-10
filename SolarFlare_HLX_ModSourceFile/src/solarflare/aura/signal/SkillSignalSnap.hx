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
	/** script.SkillScript.shouldPlayInstantly() — proc / free-cast available. */
	public var instantReady:Bool = false;
	public var instantReadyKnown:Bool = false;
	/** script.SkillScript.shouldHighlightSkill() — broad proc / recast readiness. */
	public var specialReady:Bool = false;
	public var specialReadyKnown:Bool = false;
	public var charges:Int = 0;
	public var chargesMax:Int = 0;
	public var known:Bool = false;
	public function new() {}
	public function reset():Void {
		rawId = ""; aliasId = ""; label = ""; ready = false; affordable = false;
		inCooldown = false; cooldownLeft = 0; cooldownProgress = 0;
		instantReady = false; instantReadyKnown = false;
		specialReady = false; specialReadyKnown = false;
		charges = 0; chargesMax = 0; known = false;
	}
}
