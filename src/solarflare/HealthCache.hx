package solarflare;

/**
 * HP / rage snapshot for ImGui. localHero is identity-only — never read through it from the draw loop.
 */
class HealthCache {
	public static var current:Float = 0.0;
	public static var max:Float = 1.0;
	public static var valid:Bool = false;

	public static var rage:Float = 0.0;
	public static var rageMax:Float = 20.0;
	public static var rageValid:Bool = false;
	public static var rageAlertUntil:Float = 0;

	public static var mana:Float = 0.0;
	public static var manaMax:Float = 100.0;
	public static var manaValid:Bool = false;

	/** Mage spark resource (`ent.HeroAttributes.spark`). */
	public static var spark:Float = 0.0;
	public static var sparkMax:Float = 100.0;
	public static var sparkValid:Bool = false;

	/** Absorb / shield pool shown as (+N) after HP. */
	public static var shield:Float = 0.0;

	/** Live local hero instance for identity gating only. */
	public static var localHero:Dynamic = null;

	/** Display name of the local hero (`ent.Hero.name` / getName). */
	public static var heroName:String = "";
	/** Server / shard / region string when the engine exposes one. */
	public static var serverRegion:String = "";
	/** `st.Player.uid` when the engine exposes one. */
	public static var playerUid:String = "";
	/** Bumped on rage / spark / mana writes so Geaux affordability can skip unchanged frames. */
	public static var resourceGen:Int = 0;

	public static function setLocalHero(hero:Dynamic):Void {
		localHero = hero;
	}

	public static function setIdentity(name:String, region:String, uid:String = null):Void {
		if (name != null)
			heroName = name;
		if (region != null)
			serverRegion = region;
		if (uid != null)
			playerUid = uid;
	}

	public static function isLocalHero(unit:Dynamic):Bool {
		if (unit == null)
			return false;
		// condensed_signatures: ent.Hero.isMyHero() — leaf identity, not pointer compare alone
		try {
			var hero:ent.Hero = cast unit;
			if (hero.isMyHero())
				return true;
		} catch (_:Dynamic) {}
		if (localHero == null)
			return false;
		return (cast unit : Dynamic) == (cast localHero : Dynamic);
	}

	public static function set(currentHp:Float, maxHp:Float):Void {
		current = currentHp;
		max = maxHp > 0.0 ? maxHp : 1.0;
		valid = true;
	}

	public static function setCurrent(currentHp:Float):Void {
		current = currentHp;
		valid = true;
	}

	public static function setMax(maxHp:Float):Void {
		max = maxHp > 0.0 ? maxHp : 1.0;
		valid = true;
	}

	public static function ratio():Float {
		return clampRatio(current, max);
	}

	public static function setRage(currentRage:Float, maxRage:Float = 20.0):Void {
		var prev = rage;
		var wasValid = rageValid;
		rage = currentRage;
		var cap = maxRage > 0.0 ? maxRage : 20.0;
		if (currentRage > cap)
			cap = currentRage;
		rageMax = cap;
		rageValid = true;
		resourceGen++;
		if (wasValid && cap > 0.05 && currentRage >= cap - 0.05 && prev < cap - 0.05)
			rageAlertUntil = nowSec() + 2;
	}

	public static function rageAlertActive():Bool {
		return nowSec() < rageAlertUntil;
	}

	static function nowSec():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}

	public static function rageRatio():Float {
		return clampRatio(rage, rageMax);
	}

	public static function setMana(currentMana:Float, maxMana:Float = 100.0):Void {
		mana = currentMana;
		var cap = maxMana > 0.0 ? maxMana : 100.0;
		if (currentMana > cap)
			cap = currentMana;
		manaMax = cap;
		manaValid = currentMana > 0.0 || cap > 0.0;
		resourceGen++;
	}

	public static function clearMana():Void {
		mana = 0;
		manaMax = 100;
		manaValid = false;
	}

	public static function manaRatio():Float {
		return clampRatio(mana, manaMax);
	}

	public static function setSpark(currentSpark:Float, maxSpark:Float = 100.0):Void {
		spark = currentSpark;
		var cap = maxSpark > 0.0 ? maxSpark : 100.0;
		if (currentSpark > cap)
			cap = currentSpark;
		sparkMax = cap;
		sparkValid = true;
		resourceGen++;
	}

	public static function clearSpark():Void {
		spark = 0;
		sparkMax = 100;
		sparkValid = false;
	}

	public static function sparkRatio():Float {
		return clampRatio(spark, sparkMax);
	}

	/** Mage resource bar prefers spark when present; otherwise mana. */
	public static function resourceCurrent():Float {
		return sparkValid ? spark : mana;
	}

	public static function resourceMax():Float {
		return sparkValid ? sparkMax : manaMax;
	}

	public static function resourceValid():Bool {
		return sparkValid || manaValid;
	}

	public static function resourceRatio():Float {
		return sparkValid ? sparkRatio() : manaRatio();
	}

	public static function resourceLabel():String {
		return sparkValid ? "Spark" : "Mana";
	}

	public static function setShield(amount:Float):Void {
		if (amount < 0)
			amount = 0;
		shield = amount;
	}

	/** HP overlay like the game: `642 / 642 (+50)` when shield &gt; 0. */
	public static function hpOverlay():String {
		if (!valid)
			return "HP --";
		var base = Std.string(Std.int(current)) + " / " + Std.string(Std.int(max));
		var s = Std.int(shield);
		if (s > 0)
			base += " (+" + Std.string(s) + ")";
		return base;
	}

	static function clampRatio(value:Float, cap:Float):Float {
		var m = cap > 0.0 ? cap : 1.0;
		var r = value / m;
		if (r < 0.0)
			return 0.0;
		if (r > 1.0)
			return 1.0;
		return r;
	}
}

/**
 * Priest prayer snapshot. Ready flags come from skill events, not sequence length.
 * Display order is Smite / Heal / Shield (vanilla UI, left to right).
 * Heal: main-hand skill. Shield: arsenal weapon skill. Smite: final attack combo.
 * Judgment (Priest_Sig_DivineIntervention) spends every readied prayer.
 */
class PrayerCache {
	public static var active:Bool = false;
	public static var chargedCount:Int = 0;
	public static var slotCount:Int = 0;
	public static var lifeReady:Bool = false;
	public static var shieldReady:Bool = false;
	public static var smiteReady:Bool = false;

	static var lifeKey:String = "Priest_Prayer_Life";
	static var shieldKey:String = "Priest_Prayer_Shield";
	static var smiteKey:String = "Priest_Prayer_Smite";
	static var judgmentKey:String = "Priest_Sig_DivineIntervention";
	static var hashesReady:Bool = false;

	public static function clear():Void {
		active = false;
		chargedCount = 0;
		slotCount = 0;
		lifeReady = false;
		shieldReady = false;
		smiteReady = false;
	}

	public static function notePriest(charged:Int, slots:Int):Void {
		active = true;
		var prev = chargedCount;
		chargedCount = charged < 0 ? 0 : charged;
		slotCount = slots < 0 ? 0 : slots;
		ensureHashes();
		if (prev > 0 && chargedCount == 0 && anyReady())
			spendAll();
	}

	public static function anyReady():Bool {
		return lifeReady || shieldReady || smiteReady;
	}

	public static function lifeId():String {
		ensureHashes();
		return lifeKey;
	}

	public static function shieldId():String {
		ensureHashes();
		return shieldKey;
	}

	public static function smiteId():String {
		ensureHashes();
		return smiteKey;
	}

	/** Class signature (Judgment). Prefer stable script id for icons; HASH may differ. */
	public static function judgmentId():String {
		ensureHashes();
		return judgmentKey;
	}

	public static inline var JUDGMENT_SCRIPT:String = "Priest_Sig_DivineIntervention";

	public static function isPrayerId(id:String):Bool {
		if (id == null || id.length == 0)
			return false;
		ensureHashes();
		if (id == lifeKey || id == shieldKey || id == smiteKey)
			return true;
		var s = id.toLowerCase();
		return s.indexOf("prayer_life") >= 0
			|| s.indexOf("prayer_shield") >= 0
			|| s.indexOf("prayer_smite") >= 0
			|| s == "priest_prayer_life"
			|| s == "priest_prayer_shield"
			|| s == "priest_prayer_smite";
	}

	public static function prayerKind(id:String):String {
		if (id == null || id.length == 0)
			return "";
		ensureHashes();
		if (id == lifeKey)
			return "life";
		if (id == shieldKey)
			return "shield";
		if (id == smiteKey)
			return "smite";
		var s = id.toLowerCase();
		if (s.indexOf("prayer_life") >= 0 || s == "priest_prayer_life")
			return "life";
		if (s.indexOf("prayer_shield") >= 0 || s == "priest_prayer_shield")
			return "shield";
		if (s.indexOf("prayer_smite") >= 0 || s == "priest_prayer_smite")
			return "smite";
		return "";
	}

	public static function prayerLabel(id:String):String {
		var k = prayerKind(id);
		if (k == "life")
			return "Heal";
		if (k == "shield")
			return "Shield";
		if (k == "smite")
			return "Smite";
		return "Prayer";
	}

	public static function prayerReady(id:String):Bool {
		var k = prayerKind(id);
		if (k == "life")
			return lifeReady;
		if (k == "shield")
			return shieldReady;
		if (k == "smite")
			return smiteReady;
		return false;
	}

	public static function spendAll():Void {
		lifeReady = false;
		shieldReady = false;
		smiteReady = false;
		chargedCount = 0;
	}

	/** Classify a used/charging skill: Judgment spends all, otherwise light Heal / Shield / Smite. */
	public static function applySkill(skill:Dynamic):Void {
		if (skill == null)
			return;
		ensureHashes();
		if (isJudgementSkill(skill)) {
			spendAll();
			return;
		}
		try {
			var s:st.skill.BaseSkill = skill;
			if (s.isFinalAttack()) {
				smiteReady = true;
				return;
			}
			if (s.isFromArsenal()) {
				shieldReady = true;
				return;
			}
			if (s.isWeaponSkill())
				lifeReady = true;
		} catch (_:Dynamic) {}
	}

	public static function isJudgementSkill(skill:Dynamic):Bool {
		if (skill == null)
			return false;
		ensureHashes();
		if (isJudgementKind(skillKind(skill)))
			return true;
		try {
			var inf = FieldWalk.extractObject(skill, "inf");
			if (isJudgementKind(stringField(inf, "id")) || isJudgementKind(stringField(inf, "script")))
				return true;
		} catch (_:Dynamic) {}
		return false;
	}

	public static function chargeById(id:String):Void {
		if (id == null)
			return;
		ensureHashes();
		if (isJudgementKind(id)) {
			spendAll();
			return;
		}
		var s = id.toLowerCase();
		if (id == lifeKey || s.indexOf("prayer_life") >= 0 || s == "life" || s == "heal") {
			active = true;
			lifeReady = true;
		} else if (id == shieldKey || s.indexOf("prayer_shield") >= 0 || s == "shield" || s.indexOf("virtue") >= 0) {
			active = true;
			shieldReady = true;
		} else if (id == smiteKey || s.indexOf("prayer_smite") >= 0 || s == "smite") {
			active = true;
			smiteReady = true;
		}
	}

	public static function isJudgementId(id:String):Bool {
		return isJudgementKind(id);
	}

	static function isJudgementKind(kind:String):Bool {
		if (kind == null || kind.length == 0)
			return false;
		if (kind == judgmentKey)
			return true;
		var s = kind.toLowerCase();
		return s.indexOf("divineintervention") >= 0
			|| s.indexOf("divine_intervention") >= 0
			|| s.indexOf("sig_divine") >= 0
			|| s.indexOf("priest_sig") >= 0
			|| s.indexOf("judgement") >= 0
			|| s.indexOf("judgment") >= 0;
	}

	static function skillKind(skill:Dynamic):String {
		try {
			var s:st.skill.BaseSkill = skill;
			var k = s.kind;
			if (k != null && k.length > 0)
				return k;
		} catch (_:Dynamic) {}
		var k = stringField(skill, "kind");
		if (k != null)
			return k;
		return stringField(skill, "id");
	}

	static function stringField(obj:Dynamic, name:String):String {
		if (obj == null)
			return null;
		try {
			var v:String = FieldWalk.extractObject(obj, name);
			if (v != null && v.length > 0)
				return v;
		} catch (_:Dynamic) {}
		return null;
	}

	static function ensureHashes():Void {
		if (hashesReady)
			return;
		hashesReady = true;
		try {
			var h = script.skills.Priest_Prayer_Life.HASH;
			if (h != null && h.length > 0)
				lifeKey = h;
		} catch (_:Dynamic) {}
		try {
			var h = script.skills.Priest_Prayer_Shield.HASH;
			if (h != null && h.length > 0)
				shieldKey = h;
		} catch (_:Dynamic) {}
		try {
			var h = script.skills.Priest_Prayer_Smite.HASH;
			if (h != null && h.length > 0)
				smiteKey = h;
		} catch (_:Dynamic) {}
		try {
			var h = script.skills.Priest_Sig_DivineIntervention.HASH;
			if (h != null && h.length > 0)
				judgmentKey = h;
		} catch (_:Dynamic) {}
	}
}
