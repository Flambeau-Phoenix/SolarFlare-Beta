package solarflare.aura.signal;

class AuraSignalFrame {
	public static inline var MAX_SKILLS:Int = 24;
	public static inline var MAX_STATUSES:Int = 512;
	public static inline var MAX_CASTS:Int = 32;
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
	/** Max amount on YOU-target hits within recent window (seconds). */
	public var damageTakenRecent:Float = 0;
	public var damageTakenKnown:Bool = false;
	public var skills:Array<SkillSignalSnap> = [];
	public var skillCount:Int = 0;
	public var statuses:Array<StatusSignalSnap> = [];
	public var statusCount:Int = 0;
	public var casts:Array<EnemyCastSignalSnap> = [];
	public var castCount:Int = 0;
	public var statusDomainKnown:Bool = false;
	public var statusContainerKnown:Bool = false;
	public var statusContainerCount:Int = 0;
	public var statusOverflow:Bool = false;

	public function setStatusContainerLength(length:Int):Void {
		statusContainerKnown = length >= 0;
		statusContainerCount = statusContainerKnown ? length : 0;
		statusOverflow = statusContainerKnown && length > MAX_STATUSES;
	}

	public function new() {
		for (_ in 0...MAX_SKILLS) skills.push(new SkillSignalSnap());
		for (_ in 0...MAX_STATUSES) statuses.push(new StatusSignalSnap());
		for (_ in 0...MAX_CASTS) casts.push(new EnemyCastSignalSnap());
	}
	public function resetCollections():Void {
		for (i in 0...skillCount) skills[i].reset();
		for (i in 0...statusCount) statuses[i].reset();
		for (i in 0...castCount) casts[i].reset();
		skillCount = 0; statusCount = 0; castCount = 0;
		statusDomainKnown = false;
		damageTakenRecent = 0;
		damageTakenKnown = false;
		setStatusContainerLength(-1);
	}
	public function findSkill(id:String):SkillSignalSnap {
		if (id == null || id.length == 0) return null;
		for (i in 0...skillCount) { var s = skills[i]; if (s.rawId == id || s.aliasId == id) return s; }
		return null;
	}
	public function findCast(id:String):EnemyCastSignalSnap {
		if (id == null || id.length == 0) return null;
		var key = solarflare.geaux.GeauxCache.sanitizeSkillId(id).toLowerCase();
		if (key.length == 0) return null;
		for (i in 0...castCount) {
			var c = casts[i];
			if (c.skillId.toLowerCase() == key) return c;
		}
		return null;
	}
	public function findStatus(id:String):StatusSignalSnap {
		if (id == null || id.length == 0) return null;
		var key = StringTools.trim(id).toLowerCase();
		var hit = findStatusExact(key);
		if (hit != null) return hit;
		// Plain skill subjects often refer to companion proc/status IDs.
		if (!(StringTools.endsWith(key, "_status") || StringTools.endsWith(key, "_proc")
			|| StringTools.endsWith(key, "status") || key.indexOf("_status_") >= 0
			|| key.indexOf("status_") >= 0 || key.indexOf("_proc_") >= 0)) {
			hit = findStatusExact(key + "_proc");
			if (hit != null) return hit;
			hit = findStatusExact(key + "_status");
			if (hit != null) return hit;
		}
		return null;
	}

	function findStatusExact(key:String):StatusSignalSnap {
		for (i in 0...statusCount) {
			var s = statuses[i];
			if (s.rawId.toLowerCase() == key) return s;
			for (alias in s.ids) if (alias.toLowerCase() == key) return s;
		}
		return null;
	}
}
