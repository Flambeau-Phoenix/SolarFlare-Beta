package solarflare.aura.signal;

class AuraSignalFrame {
	public static inline var MAX_SKILLS:Int = 24;
	public static inline var MAX_STATUSES:Int = 48;
	public var generation:Int = 0;
	public var builtAt:Float = 0;
	public var heroKnown:Bool = false;
	public var healthCurrent:Float = 0;
	public var healthRatio:Float = 0;
	public var healthKnown:Bool = false;
	public var shieldRatio:Float = 0;
	public var rageRatio:Float = 0;
	public var rageKnown:Bool = false;
	public var manaRatio:Float = 0;
	public var manaKnown:Bool = false;
	public var sparkRatio:Float = 0;
	public var sparkKnown:Bool = false;
	public var genericRatio:Float = 0;
	public var genericKnown:Bool = false;
	public var comboCount:Int = 0;
	public var comboMax:Int = 0;
	public var comboKnown:Bool = false;
	public var prayerCharged:Int = 0;
	public var prayerLifeReady:Bool = false;
	public var prayerShieldReady:Bool = false;
	public var prayerSmiteReady:Bool = false;
	public var prayerKnown:Bool = false;
	public var chaincastStacks:Int = 0;
	public var chaincastReady:Bool = false;
	public var chaincastRemaining:Float = 0;
	public var chaincastProgress:Float = 0;
	public var chaincastKnown:Bool = false;
	public var conduitFilled:Int = 0;
	public var conduitPowerStacks:Int = 0;
	public var conduitPowerLeft:Float = 0;
	public var conduitKnown:Bool = false;
	public var attackComboStep:Int = 0;
	public var attackComboWithin:Bool = false;
	public var attackComboFinal:Bool = false;
	public var attackComboKnown:Bool = false;
	public var inRift:Bool = false;
	public var encounterKnown:Bool = false;
	public var targetKnown:Bool = false;
	public var targetValid:Bool = false;
	public var targetKind:String = "";
	public var targetName:String = "";
	public var targetRatio:Float = 0;
	public var targetIsBoss:Bool = false;
	public var targetIsElite:Bool = false;
	public var targetIsMiniboss:Bool = false;
	public var killKnown:Bool = false;
	public var killKind:String = "";
	public var skills:Array<SkillSignalSnap> = [];
	public var skillCount:Int = 0;
	public var statuses:Array<StatusSignalSnap> = [];
	public var statusCount:Int = 0;
	public var statusDomainKnown:Bool = false;

	public function new() {
		for (_ in 0...MAX_SKILLS) skills.push(new SkillSignalSnap());
		for (_ in 0...MAX_STATUSES) statuses.push(new StatusSignalSnap());
	}
	public function resetCollections():Void {
		for (i in 0...skillCount) skills[i].reset();
		for (i in 0...statusCount) statuses[i].reset();
		skillCount = 0; statusCount = 0;
	}
	public function findSkill(id:String):SkillSignalSnap {
		if (id == null || id.length == 0) return null;
		for (i in 0...skillCount) { var s = skills[i]; if (s.rawId == id || s.aliasId == id) return s; }
		return null;
	}
	public function findStatus(id:String):StatusSignalSnap {
		if (id == null || id.length == 0) return null;
		for (i in 0...statusCount) if (statuses[i].rawId == id) return statuses[i];
		return null;
	}
}
