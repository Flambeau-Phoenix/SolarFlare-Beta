package solarflare.preview;

import solarflare.preview.PreviewScenario;

/**
 * Frozen sample values for HUD previews.
 *
 * Presentation-side data model used by the ResourceTracker Builder and Attack
 * Combo options previews. It mirrors the fields the live overlays read out of
 * their caches so the shared renderer helpers (Segment 1.3) can draw identical
 * content from deterministic sample data.
 *
 * Contract (docs/SOLARFLARE_MODDER_GUIDE.md §6.3):
 * - Never reads or writes HealthCache / PrayerCache / ComboPointsCache /
 *   ChaincastCache / ConduitCache / AttackComboCache.
 * - Never touches persisted positions, visibility, or window geometry.
 * - No texture loading and no JSON processing; the fields below are plain values.
 * - Deterministic: the same inputs always produce the same sample.
 */
class PreviewState {
	// Health --------------------------------------------------------------
	public var hpCurrent:Float = 0;
	public var hpMax:Float = 1;
	public var hpValid:Bool = false;
	public var hpShield:Float = 0;

	// Rage ----------------------------------------------------------------
	public var rage:Float = 0;
	public var rageMax:Float = 20;
	public var rageValid:Bool = false;

	// Mana / Spark --------------------------------------------------------
	public var mana:Float = 0;
	public var manaMax:Float = 100;
	public var manaValid:Bool = false;
	public var spark:Float = 0;
	public var sparkMax:Float = 100;
	public var sparkValid:Bool = false;

	// Prayers -------------------------------------------------------------
	public var prayersActive:Bool = false;
	public var prayersCharged:Int = 0;
	public var prayerSlotCount:Int = 0;
	public var smiteReady:Bool = false;
	public var lifeReady:Bool = false;
	public var shieldReady:Bool = false;

	// Combo points --------------------------------------------------------
	public var comboActive:Bool = false;
	public var comboCurrent:Int = 0;
	public var comboMax:Int = 6;
	public var comboValid:Bool = false;
	public var comboAlert:Bool = false;

	// Attack combo --------------------------------------------------------
	public var attackStep:Int = 0;
	public var attackLength:Int = 4;
	public var attackFlashFinal:Bool = false;
	public var attackWithinCombo:Bool = false;
	public var attackVisible:Bool = false;

	// Chaincast -----------------------------------------------------------
	public var chainActive:Bool = false;
	public var chainCurrent:Int = 0;
	public var chainMax:Int = 4;
	public var chainValid:Bool = false;
	public var chainReady:Bool = false;
	public var chainRemainLeft:Float = 0;
	public var chainRemainProg:Float = 0;
	public var chainRemainValid:Bool = false;
	public var chainAlert:Bool = false;
	public var chainPulse:Bool = false;
	public static inline var CHAIN_SLOTS:Int = 5;

	// Conduits ------------------------------------------------------------
	public var conduitActive:Bool = false;
	public var conduitValid:Bool = false;
	public var conduitSlotCount:Int = 3;
	public var conduitFilled:Int = 0;
	public var conduitPower:Int = 0;
	public var conduitSlots:Array<PreviewSlot> = [];

	public function new() {}

	/** Frozen, deterministic canonical sample for every ResourceTracker element and Attack Combo. */
	public static function sample():PreviewState {
		return partial();
	}

	/** Mid-fill canonical sample: same profile as Segment 1.1 `sample()`. */
	public static function partial():PreviewState {
		var s = new PreviewState();
		s.hpCurrent = 428;
		s.hpMax = 600;
		s.hpValid = true;
		s.hpShield = 50;
		s.rage = 14;
		s.rageMax = 20;
		s.rageValid = true;
		s.mana = 64;
		s.manaMax = 100;
		s.manaValid = true;
		s.spark = 0;
		s.sparkMax = 100;
		s.sparkValid = false;
		s.prayersActive = true;
		s.prayersCharged = 2;
		s.prayerSlotCount = 3;
		s.smiteReady = true;
		s.lifeReady = true;
		s.shieldReady = false;
		s.comboActive = true;
		s.comboCurrent = 3;
		s.comboMax = 6;
		s.comboValid = true;
		s.comboAlert = false;
		s.attackStep = 2;
		s.attackLength = 4;
		s.attackFlashFinal = false;
		s.attackWithinCombo = true;
		s.attackVisible = true;
		s.chainActive = true;
		s.chainCurrent = 2;
		s.chainMax = 4;
		s.chainValid = true;
		s.chainReady = false;
		s.chainRemainLeft = 3.4;
		s.chainRemainProg = 0.68;
		s.chainRemainValid = true;
		s.chainAlert = false;
		s.chainPulse = false;
		s.conduitActive = true;
		s.conduitValid = true;
		s.conduitSlotCount = 3;
		s.conduitFilled = 2;
		s.conduitPower = 0;
		s.conduitSlots = [
			slot("", true, 0, false),
			slot("", true, 0, false),
			slot("", false, 0, false)
		];
		return s;
	}

	/** Empty: valid frames at zero — nothing charged, filled, or in progress. */
	public static function empty():PreviewState {
		var s = new PreviewState();
		s.hpCurrent = 0;
		s.hpMax = 600;
		s.hpValid = true;
		s.hpShield = 0;
		s.rage = 0;
		s.rageMax = 20;
		s.rageValid = true;
		s.mana = 0;
		s.manaMax = 100;
		s.manaValid = true;
		s.spark = 0;
		s.sparkMax = 100;
		s.sparkValid = false;
		s.prayersActive = true;
		s.prayersCharged = 0;
		s.prayerSlotCount = 3;
		s.smiteReady = false;
		s.lifeReady = false;
		s.shieldReady = false;
		s.comboActive = true;
		s.comboCurrent = 0;
		s.comboMax = 6;
		s.comboValid = true;
		s.comboAlert = false;
		s.attackStep = 0;
		s.attackLength = 4;
		s.attackFlashFinal = false;
		s.attackVisible = true;
		s.chainActive = true;
		s.chainCurrent = 0;
		s.chainMax = 4;
		s.chainValid = true;
		s.chainReady = false;
		s.chainRemainLeft = 0;
		s.chainRemainProg = 0;
		s.chainRemainValid = false;
		s.chainAlert = false;
		s.chainPulse = false;
		s.conduitActive = true;
		s.conduitValid = true;
		s.conduitSlotCount = 3;
		s.conduitFilled = 0;
		s.conduitPower = 0;
		s.conduitSlots = [
			slot("", false, 0, false),
			slot("", false, 0, false),
			slot("", false, 0, false)
		];
		return s;
	}

	/** Full: everything capped — full bars, all charges, final combo step without flash. */
	public static function full():PreviewState {
		var s = new PreviewState();
		s.hpCurrent = 600;
		s.hpMax = 600;
		s.hpValid = true;
		s.hpShield = 200;
		s.rage = 20;
		s.rageMax = 20;
		s.rageValid = true;
		s.mana = 100;
		s.manaMax = 100;
		s.manaValid = true;
		s.spark = 0;
		s.sparkMax = 100;
		s.sparkValid = false;
		s.prayersActive = true;
		s.prayersCharged = 3;
		s.prayerSlotCount = 3;
		s.smiteReady = true;
		s.lifeReady = true;
		s.shieldReady = true;
		s.comboActive = true;
		s.comboCurrent = 6;
		s.comboMax = 6;
		s.comboValid = true;
		s.comboAlert = false;
		s.attackStep = 4;
		s.attackLength = 4;
		s.attackFlashFinal = false;
		s.attackVisible = true;
		s.chainActive = true;
		s.chainCurrent = 4;
		s.chainMax = 4;
		s.chainValid = true;
		s.chainReady = false;
		s.chainRemainLeft = 0;
		s.chainRemainProg = 0;
		s.chainRemainValid = false;
		s.chainAlert = false;
		s.chainPulse = false;
		s.conduitActive = true;
		s.conduitValid = true;
		s.conduitSlotCount = 3;
		s.conduitFilled = 3;
		s.conduitPower = 0;
		s.conduitSlots = [
			slot("", true, 0, false),
			slot("", true, 0, false),
			slot("", true, 0, false)
		];
		return s;
	}

	/** Final/alert: combo flash, chaincast ready + pulse, all prayers, conduit power. */
	public static function finalAlert():PreviewState {
		var s = new PreviewState();
		s.hpCurrent = 600;
		s.hpMax = 600;
		s.hpValid = true;
		s.hpShield = 350;
		s.rage = 20;
		s.rageMax = 20;
		s.rageValid = true;
		s.mana = 100;
		s.manaMax = 100;
		s.manaValid = true;
		s.spark = 0;
		s.sparkMax = 100;
		s.sparkValid = false;
		s.prayersActive = true;
		s.prayersCharged = 3;
		s.prayerSlotCount = 3;
		s.smiteReady = true;
		s.lifeReady = true;
		s.shieldReady = true;
		s.comboActive = true;
		s.comboCurrent = 6;
		s.comboMax = 6;
		s.comboValid = true;
		s.comboAlert = true;
		s.attackStep = 4;
		s.attackLength = 4;
		s.attackFlashFinal = true;
		s.attackVisible = true;
		s.chainActive = true;
		s.chainCurrent = 4;
		s.chainMax = 4;
		s.chainValid = true;
		s.chainReady = true;
		s.chainRemainLeft = 0;
		s.chainRemainProg = 0;
		s.chainRemainValid = false;
		s.chainAlert = true;
		s.chainPulse = true;
		s.conduitActive = true;
		s.conduitValid = true;
		s.conduitSlotCount = 3;
		s.conduitFilled = 3;
		s.conduitPower = 20;
		s.conduitSlots = [
			slot("", true, 6, true),
			slot("", true, 6, true),
			slot("", true, 6, true)
		];
		return s;
	}

	/** Dispatch to the four deterministic preset scenarios. */
	public static function forScenario(scenario:PreviewScenario):PreviewState {
		return switch (scenario) {
			case Empty: empty();
			case Partial: partial();
			case Full: full();
			case FinalAlert: finalAlert();
		};
	}

	/** User-facing label for a preset scenario (stable for combo/button IDs). */
	public static function scenarioLabel(scenario:PreviewScenario):String {
		return switch (scenario) {
			case Empty: "Empty";
			case Partial: "Partially filled";
			case Full: "Full";
			case FinalAlert: "Final / Alert";
		};
	}

	// Derived helpers mirror the live cache accessor names so shared renderer
	// functions never need a live cache reference.

	public function hpRatio():Float {
		return clamp01(hpCurrent / (hpMax > 0.0 ? hpMax : 1.0));
	}

	public function hpOverlay():String {
		if (!hpValid)
			return "HP --";
		var base = Std.string(Std.int(hpCurrent)) + " / " + Std.string(Std.int(hpMax));
		var s = Std.int(hpShield);
		if (s > 0)
			base += " (+" + Std.string(s) + ")";
		return base;
	}

	public function rageRatio():Float {
		return clamp01(rage / (rageMax > 0.0 ? rageMax : 1.0));
	}

	public function rageLabel():String {
		if (!rageValid)
			return "Rage";
		return Std.string(Std.int(rage)) + " / " + Std.string(Std.int(rageMax));
	}

	public function resourceValid():Bool {
		return sparkValid || manaValid;
	}

	public function resourceCurrent():Float {
		return sparkValid ? spark : mana;
	}

	public function resourceMax():Float {
		return sparkValid ? sparkMax : manaMax;
	}

	public function resourceRatio():Float {
		return sparkValid ? sparkRatio() : manaRatio();
	}

	public function sparkRatio():Float {
		return clamp01(spark / (sparkMax > 0.0 ? sparkMax : 1.0));
	}

	public function manaRatio():Float {
		return clamp01(mana / (manaMax > 0.0 ? manaMax : 1.0));
	}

	public function resourceLabel():String {
		return sparkValid ? "Spark" : "Mana";
	}

	public function attackRatio():Float {
		var n = attackLength > 0 ? attackLength : 4;
		return clamp01(attackStep / n);
	}

	public function chainShownCount():Int {
		if (chainReady)
			return CHAIN_SLOTS;
		return chainCurrent < 0 ? 0 : chainCurrent;
	}

	public function conduitLabel():String {
		if (conduitPower > 0)
			return Std.string(conduitPower);
		return Std.string(conduitFilled);
	}

	static function slot(id:String, filled:Bool, stacks:Int, power:Bool):PreviewSlot {
		var s = new PreviewSlot();
		s.id = id;
		s.filled = filled;
		s.stacks = stacks;
		s.power = power;
		return s;
	}

	static function clamp01(v:Float):Float {
		if (v < 0)
			return 0;
		if (v > 1)
			return 1;
		return v;
	}
}

/**
 * Frozen Sparkmaster slot copy used only by previews. Mirrors the live
 * ConduitSlotSnap shape so conduit rendering shares one code path.
 */
class PreviewSlot {
	public var id:String = "";
	public var filled:Bool = false;
	public var stacks:Int = 0;
	public var power:Bool = false;

	public function new() {}
}