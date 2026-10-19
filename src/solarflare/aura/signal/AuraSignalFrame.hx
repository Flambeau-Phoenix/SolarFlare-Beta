package solarflare.aura.signal;

class AuraSignalFrame {
	/** 32 auras x 8 conditions plus the action-bar strips. */
	public static inline var MAX_SKILLS:Int = 288;
	public static inline var MAX_STATUSES:Int = 512;
	public static inline var MAX_CASTS:Int = 32;
	public var generation:Int = 0;
	public var builtAt:Float = 0;
	/** Aura id -> is currently showing. Filled by AuraStates after the aura pass, before state rules run. */
	public var auraShowing:Map<String, Bool> = new Map();
	/** Aura id -> its latest rule result, so a state can watch one condition ("aura.condition", subject "id#n"). */
	public var auraRules:Map<String, AuraRuleResult> = new Map();
	public var heroKnown:Bool = false;
	public var healthCurrent:Float = 0;
	public var healthRatio:Float = 0;
	public var healthKnown:Bool = false;
	public var manaCurrent:Float=0;
	public var rageCurrent:Float=0;
	public var sparkCurrent:Float=0;
	public var shieldCurrent:Float=0;
	public var aliveKnown:Bool=false;
	public var alive:Bool=false;
	public var dashKnown:Bool=false;
	public var dashId:String="";
	public var dashGeneration:Int=0;
	public var dashCharges:Int=0;
	public var dashMax:Int=0;
	public var dashRecharge:Float=Math.NaN;
	public var targetDistance:Float=Math.NaN;
	public var damageTakenAge:Float=1e9;
	public var damageAgeKnown:Bool=false;
	public var critAge:Float=1e9;
	public var blockAge:Float=1e9;
	public var critSerial:Int=0;
	public var blockSerial:Int=0;
	public var events:Map<String,AuraEventValue> = [];
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
	public var inBossFight:Bool = false;
	public var riftRemain:Float = 0;
	public var targetBossId:String = "";
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
	public var combatKnown:Bool = false;
	public var inCombat:Bool = false;
	/** Seconds since the local hero entered / left combat; CombatStateTracker.NEVER when it has not happened. */
	public var combatEnteredAge:Float = 1e9;
	public var combatLeftAge:Float = 1e9;
	public var combatEnteredSerial:Int = 0;
	public var combatLeftSerial:Int = 0;
	public var skills:Array<SkillSignalSnap> = [];
	public var skillCount:Int = 0;
	public var consumables:Array<ConsumableSignalSnap> = [];
	public var consumableCount:Int = 0;
	public var weapons:Array<WeaponSignalSnap> = [];
	public var weaponCount:Int = 0;
	public var statuses:Array<StatusSignalSnap> = [];
	public var targetStatuses:Array<StatusSignalSnap> = [];
	public var targetStatusCount:Int=0;
	public var targetStatusDomainKnown:Bool=false;
	public var targetStatusValid:Bool=false;
	public var targetStatusGeneration:Int=0;
	public var myStatusTypeKnown:Int=0;
	public var myStatusTypePresent:Int=0;
	public var myStatusTypeGeneration:Int=0;
	public var enemyStatusTypeKnown:Int=0;
	public var enemyStatusTypePresent:Int=0;
	public var enemyStatusTypeGeneration:Int=0;
	public var statusCount:Int = 0;
	public var casts:Array<EnemyCastSignalSnap> = [];
	public var castCount:Int = 0;
	/** False when bounded cast publication omitted requested subjects. */
	public var castDomainKnown:Bool = true;
	public var playerCasts:Array<EnemyCastSignalSnap> = [];
	public var playerCastCount:Int = 0;
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
		for (_ in 0...solarflare.aura.WeaponEquipmentSampler.MAX_SUBJECTS) weapons.push(new WeaponSignalSnap());
		for (entry in solarflare.cdb.ConsumableCatalog.entries) { var snap = new ConsumableSignalSnap(); snap.id = entry.id; consumables.push(snap); }
		for (_ in 0...MAX_SKILLS) skills.push(new SkillSignalSnap());
		for (_ in 0...MAX_STATUSES) statuses.push(new StatusSignalSnap());
		for (_ in 0...MAX_STATUSES) targetStatuses.push(new StatusSignalSnap());
		for (_ in 0...MAX_CASTS) casts.push(new EnemyCastSignalSnap());
		for (_ in 0...solarflare.aura.LocalCastHistory.MAX) playerCasts.push(new EnemyCastSignalSnap());
	}
	public function resetCollections():Void {
		myStatusTypeKnown=myStatusTypePresent=enemyStatusTypeKnown=enemyStatusTypePresent=0;
		for (i in 0...weaponCount) weapons[i].reset();
		weaponCount = 0;
		for (i in 0...consumableCount) consumables[i].reset();
		consumableCount = 0;
		for (i in 0...skillCount) skills[i].reset();
		for (i in 0...statusCount) statuses[i].reset();
		for (i in 0...castCount) casts[i].reset();
		for (i in 0...playerCastCount) playerCasts[i].reset();
		for (i in 0...targetStatusCount) targetStatuses[i].reset();
		targetStatusCount=0; targetStatusDomainKnown=false; targetStatusValid=false;
		playerCastCount = 0;
		skillCount = 0; statusCount = 0; castCount = 0;
		statusDomainKnown = false;
		damageTakenRecent = 0;
		damageTakenKnown = false;
		combatKnown = false; inCombat = false; combatEnteredAge = 1e9; combatLeftAge = 1e9;
		setStatusContainerLength(-1);
	}
	public function publishWeapons(snaps:Array<WeaponSignalSnap>):Void {
		for (i in 0...weaponCount) weapons[i].reset();
		weaponCount = 0;
		for (src in snaps) {
			if (weaponCount >= weapons.length) break;
			var dst = weapons[weaponCount++];
			dst.id = src.id; dst.known = src.known; dst.equipped = src.equipped;
		}
	}
	public function findWeapon(id:String):WeaponSignalSnap {
		if (id == null || id.length == 0) return null;
		var key = StringTools.trim(id).toLowerCase();
		for (i in 0...weaponCount) if (weapons[i].id.toLowerCase() == key) return weapons[i];
		return null;
	}
	public function findConsumable(id:String):ConsumableSignalSnap {
		if (id == null || id.length == 0) return null;
		for (i in 0...consumableCount) if (consumables[i].id.toLowerCase() == id.toLowerCase()) return consumables[i];
		return null;
	}
	public function findSkill(id:String):SkillSignalSnap {
		if (id == null || id.length == 0) return null;
		for (i in 0...skillCount) { var s = skills[i]; if (s.rawId == id || s.aliasId == id) return s; }
		var key = solarflare.geaux.GeauxCache.sanitizeSkillId(id).toLowerCase();
		for (i in 0...skillCount) { var s = skills[i]; if (s.rawId.toLowerCase() == key || s.aliasId.toLowerCase() == key) return s; }
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
	public function findTargetStatus(id:String):StatusSignalSnap {
		var key=solarflare.aura.StatusIdentity.key(id);
		for(i in 0...targetStatusCount) { var s=targetStatuses[i]; if(s.known && s.present && solarflare.aura.StatusIdentity.key(s.rawId)==key) return s; }
		return null;
	}
	public function findStatus(id:String):StatusSignalSnap {
		if (id == null || id.length == 0) return null;
		return findStatusExact(StringTools.trim(id).toLowerCase());
	}

	/**
	 * Same precedence as AuraStatusCache.findByWant: a row whose applied id IS the demanded id outranks shared-alias
	 * rows (present over absent within each tier). A live alias row never hides the exact applied identity.
	 */
	function findStatusExact(key:String):StatusSignalSnap {
		var exactAbsent:StatusSignalSnap = null;
		var aliasPresent:StatusSignalSnap = null;
		var aliasAbsent:StatusSignalSnap = null;
		for (i in 0...statusCount) {
			var s = statuses[i];
			if (s.rawId.toLowerCase() == key) {
				if (s.present) return s;
				if (exactAbsent == null) exactAbsent = s;
				continue;
			}
			var viaAlias = false;
			for (alias in s.ids) {
				if (alias.toLowerCase() == key) {
					viaAlias = true;
					break;
				}
			}
			if (!viaAlias) continue;
			if (s.present) { if (aliasPresent == null) aliasPresent = s; }
			else if (aliasAbsent == null) aliasAbsent = s;
		}
		if (exactAbsent != null) return exactAbsent;
		return aliasPresent != null ? aliasPresent : aliasAbsent;
	}
}
