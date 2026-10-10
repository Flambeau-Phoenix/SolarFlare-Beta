package solarflare.attackcombo;

/**
 * Primitive attack-chain presentation state.
 *
 * Source of truth is the engine's own chain: `Hero.attackSkills` (basic attacks, in order),
 * `Hero.attackComboSkill` (finisher) and `Hero.getNextAttackSkill()`, which already applies the
 * combo window. `step` counts attacks completed in the live chain (0 = idle, length = finisher).
 */
class AttackComboState {
	public static inline var FLASH_SEC:Float = 0.35;
	public var step(default, null):Int = 0;
	public var comboLength(default, null):Int = 4;
	public var moveSetId(default, null):String = "";
	public var withinCombo(default, null):Bool = false;
	public var flashFinal(default, null):Bool = false;
	public var known(default, null):Bool = false;
	public var direct(default, null):Bool = false;
	public var visible(get, never):Bool;
	var flashUntil:Float = 0;
	var identity:Null<Int> = null;

	public function new() {}

	public function clear():Void {
		resetChain();
		identity = null;
		comboLength = 4;
		moveSetId = "";
	}

	function resetChain():Void {
		step = 0;
		withinCombo = flashFinal = known = direct = false;
		flashUntil = 0;
	}

	/** null ID / nonpositive length mean failed reads, not a weapon change. */
	function bind(epoch:Int, length:Int, id:Null<String>):Void {
		if (identity == null || identity != epoch) {
			clear();
			identity = epoch;
		}
		if (id != null && id != moveSetId)
			resetChain();
		else if (length > 0 && length != comboLength)
			resetChain();
		if (id != null)
			moveSetId = id;
		if (length > 0)
			comboLength = length;
	}

	inline function get_visible():Bool return withinCombo || flashFinal || step > 0;

	/** A basic attack began; `index` is its 0-based position in Hero.attackSkills. */
	public function basic(epoch:Int, index:Int, length:Int, id:Null<String>):Void {
		bind(epoch, length, id);
		flashFinal = false;
		flashUntil = 0;
		withinCombo = known = direct = true;
		step = Std.int(Math.min(comboLength - 1, index + 1));
	}

	/** The finisher began: hold the full chain briefly. */
	public function finisher(now:Float, epoch:Int, length:Int, id:Null<String>):Void {
		bind(epoch, length, id);
		withinCombo = known = direct = true;
		flashFinal = true;
		flashUntil = now + FLASH_SEC;
		step = comboLength;
	}

	/**
	 * Poll: `next` is the 0-based index the engine will use for the next attack (0 once the combo
	 * window has lapsed), or -1 when unreadable. Never overrides a running finisher flash.
	 */
	public function observe(now:Float, epoch:Int, next:Int, length:Int, id:Null<String>):Void {
		bind(epoch, length, id);
		if (flashFinal && now >= flashUntil) {
			flashFinal = false;
			flashUntil = 0;
		}
		if (flashFinal) {
			step = comboLength;
			return;
		}
		if (next < 0)
			return;
		known = direct = true;
		step = Std.int(Math.min(comboLength - 1, next));
		withinCombo = next > 0;
	}
}
