package solarflare.hemorrhage;

/** Structural view of the frozen combat DTO; keeps replay tests engine-free. */
typedef HemorrhageInput = {
	var sequence:Float;
	var kind:Int;
	var sourceRole:Int;
	var targetRole:Int;
	var minionName:String;
	var skillId:String;
	var skillLabel:String;
	var targetName:String;
	var amount:Float;
	var crit:Bool;
	var physical:Bool;
	var isDoT:Bool;
	var t:Float;
	var wallMs:Float;
}

class HemorrhageRow {
	public var sequence:Float;
	public var at:Float;
	public var enemy:String;
	public var ability:String;
	public var amount:Float;
	public var bleed:Bool;
	public var text:String;
	public function new(hit:HemorrhageInput, bleed:Bool) {
		sequence = hit.sequence;
		at = hit.t;
		enemy = hit.targetName;
		ability = hit.skillLabel.length > 0 ? hit.skillLabel : hit.skillId;
		amount = hit.amount;
		this.bleed = bleed;
		text = (bleed ? "Hemorrhage " : "Crit ") + HemorrhageCache.number(amount);
	}
}

/** Scheduler-owned, primitive-only history. No simulated bleed budgets or refresh timers. */
class HemorrhageCache {
	public static inline var STATUS_ID:String = "Warrior_Hemorrhage_Status";
	public static inline var CAPACITY:Int = 1024;
	public static inline var MAX_FLOATING:Int = 3;
	public static var enabled(default, null):Bool = false;
	public static var floatingEnabled(default, null):Bool = false;
	public static var count(default, null):Int = 0;
	public static var revision(default, null):Int = 0;
	public static var criticalTotal(default, null):Float = 0;
	public static var hemorrhageTotal(default, null):Float = 0;
	public static var criticalChance(default, null):Float = Math.NaN;
	public static var criticalRating(default, null):Float = Math.NaN;
	public static var floating(default, null):Array<HemorrhageRow> = [];
	static var history:Array<HemorrhageRow> = [];
	static var writeAt:Int = 0;
	static var lastSequence:Float = 0;

	public static function configure(visible:Bool, floatText:Bool, suppressed:Bool):Void {
		enabled = visible;
		floatingEnabled = visible && floatText && !suppressed;
		if (!floatingEnabled) clearFloating();
		if (!visible) setStats(Math.NaN, Math.NaN);
	}

	/** Called exactly once after each shared event commits, before its ring can roll over. */
	public static function consume(hit:HemorrhageInput):Void {
		if (hit == null || !Math.isFinite(hit.sequence) || hit.sequence <= lastSequence) return;
		lastSequence = hit.sequence;
		if (!enabled || hit.kind != 1 || hit.sourceRole != 1 || hit.targetRole != 3
			|| hit.minionName.length > 0 || !Math.isFinite(hit.amount) || hit.amount <= 0
			|| !Math.isFinite(hit.t)) return;
		var bleed = hit.skillId == STATUS_ID;
		if (!bleed && (!hit.crit || !hit.physical || hit.isDoT)) return;
		var row = new HemorrhageRow(hit, bleed);
		if (bleed) hemorrhageTotal += row.amount; else criticalTotal += row.amount;
		if (count < CAPACITY) {
			history.push(row);
			count++;
		} else history[writeAt] = row;
		writeAt = (writeAt + 1) % CAPACITY;
		revision++;
		if (floatingEnabled) {
			if (floating.length >= MAX_FLOATING) floating.shift();
			floating.push(row);
		}
	}

	public static function rowAt(index:Int):HemorrhageRow {
		if (index < 0 || index >= count) return null;
		return history[((count == CAPACITY ? writeAt : 0) + index) % CAPACITY];
	}

	public static function tick(now:Float, lifetime:Float):Void {
		// The scheduler samples now before draining events. A just-committed event
		// can be slightly newer; it must survive until the next frame, not be discarded.
		while (floating.length > 0 && now - floating[0].at >= lifetime)
			floating.shift();
	}

	public static function setStats(chance:Float, rating:Float):Void {
		criticalChance = Math.isFinite(chance) && chance >= 0 ? chance : Math.NaN;
		criticalRating = Math.isFinite(rating) && rating >= 0 ? rating : Math.NaN;
	}

	public static function clearFloating():Void floating.resize(0);

	/** Sequence watermark survives Clear so already-consumed events never reappear. */
	public static function clear():Void {
		history.resize(0);
		count = writeAt = 0;
		criticalTotal = hemorrhageTotal = 0;
		clearFloating();
		revision++;
	}

	public static function number(value:Float):String {
		if (!Math.isFinite(value)) return "—";
		var raw = Std.string(Math.ffloor(value + 0.5));
		var out = "";
		for (i in 0...raw.length) {
			if (i > 0 && (raw.length - i) % 3 == 0) out += ",";
			out += raw.charAt(i);
		}
		return out;
	}
}
