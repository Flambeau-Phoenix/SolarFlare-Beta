package solarflare.scripting;

import hscript.Expr;
import hscript.Interp;
import hscript.Parser;
import solarflare.aura.signal.AuraSignalFrame;

/**
 * High-performance, sandboxed Haxe script evaluation engine using hscript.
 * Parses expressions once into ASTs and caches them for zero-allocation per-frame evaluation.
 */
class ScriptEngine {
	static var parser:Parser;
	static var interp:Interp;
	static var exprCache:Map<String, Null<Expr>> = new Map();
	static var parseErrors:Map<String, String> = new Map();

	public static function init():Void {
		if (parser == null) {
			parser = new Parser();
			parser.allowJSON = true;
			parser.allowTypes = true;
			parser.allowMetadata = false;
		}
		if (interp == null) {
			interp = new Interp();
			initBaseContext();
		}
	}

	static function initBaseContext():Void {
		interp.variables.set("Math", Math);
		interp.variables.set("min", Math.min);
		interp.variables.set("max", Math.max);
		interp.variables.set("abs", Math.abs);
		interp.variables.set("floor", Math.floor);
		interp.variables.set("ceil", Math.ceil);
		interp.variables.set("round", Math.round);
		interp.variables.set("sqrt", Math.sqrt);
		interp.variables.set("sin", Math.sin);
		interp.variables.set("cos", Math.cos);
	}

	/**
	 * Validate syntax of an hscript expression without evaluating it.
	 * @return null if valid, or error description string if syntax is invalid.
	 */
	public static function validate(code:String):Null<String> {
		if (code == null || StringTools.trim(code).length == 0)
			return null;
		init();
		try {
			parser.parseString(code);
			return null;
		} catch (e:Dynamic) {
			return Std.string(e);
		}
	}

	/**
	 * Get or parse and cache compiled AST for code.
	 */
	public static function getExpr(code:String):Null<Expr> {
		if (code == null || code.length == 0)
			return null;
		var s = StringTools.trim(code);
		if (s.length == 0)
			return null;

		if (exprCache.exists(s))
			return exprCache.get(s);

		init();
		try {
			var expr = parser.parseString(s);
			exprCache.set(s, expr);
			parseErrors.remove(s);
			return expr;
		} catch (e:Dynamic) {
			exprCache.set(s, null);
			parseErrors.set(s, Std.string(e));
			return null;
		}
	}

	/**
	 * Populate the interpreter context from frozen combat signal frames.
	 */
	public static function bindFrame(frame:AuraSignalFrame):Void {
		init();
		if (frame == null) {
			interp.variables.set("hp", 0.0);
			interp.variables.set("hpCur", 0.0);
			interp.variables.set("shield", 0.0);
			interp.variables.set("rage", 0.0);
			interp.variables.set("mana", 0.0);
			interp.variables.set("spark", 0.0);
			interp.variables.set("combo", 0);
			interp.variables.set("comboMax", 5);
			interp.variables.set("prayers", 0);
			interp.variables.set("chaincast", 0);
			interp.variables.set("conduit", 0);
			interp.variables.set("step", 0);
			interp.variables.set("inRift", false);
			return;
		}

		interp.variables.set("hp", frame.healthRatio * 100.0);
		interp.variables.set("hpRatio", frame.healthRatio);
		interp.variables.set("hpCur", frame.healthCurrent);
		interp.variables.set("shield", frame.shieldRatio * 100.0);
		interp.variables.set("rage", frame.rageRatio * 100.0);
		interp.variables.set("mana", frame.manaRatio * 100.0);
		interp.variables.set("spark", frame.sparkRatio * 100.0);
		interp.variables.set("combo", frame.comboCount);
		interp.variables.set("comboMax", frame.comboMax);
		interp.variables.set("prayers", frame.prayerCharged);
		interp.variables.set("prayerLife", frame.prayerLifeReady);
		interp.variables.set("prayerShield", frame.prayerShieldReady);
		interp.variables.set("prayerSmite", frame.prayerSmiteReady);
		interp.variables.set("chaincast", frame.chaincastStacks);
		interp.variables.set("chaincastReady", frame.chaincastReady);
		interp.variables.set("conduit", frame.conduitFilled);
		interp.variables.set("conduitPower", frame.conduitPowerStacks);
		interp.variables.set("step", frame.attackComboStep);
		interp.variables.set("comboWithin", frame.attackComboWithin);
		interp.variables.set("comboFinal", frame.attackComboFinal);
		interp.variables.set("inRift", frame.inRift);

		// Helpers for skill and status queries
		interp.variables.set("hasSkill", function(id:String):Bool {
			var sk = frame.findSkill(id);
			return sk != null && sk.known;
		});
		interp.variables.set("skillCd", function(id:String):Float {
			var sk = frame.findSkill(id);
			return sk != null ? sk.cooldownLeft : 0.0;
		});
		interp.variables.set("skillReady", function(id:String):Bool {
			var sk = frame.findSkill(id);
			return sk != null && sk.ready;
		});
		interp.variables.set("hasStatus", function(id:String):Bool {
			var st = frame.findStatus(id);
			return st != null && st.known;
		});
		interp.variables.set("statusStacks", function(id:String):Int {
			var st = frame.findStatus(id);
			return st != null && st.known ? st.stacks : 0;
		});
		interp.variables.set("statusDuration", function(id:String):Float {
			var st = frame.findStatus(id);
			return st != null && st.known ? st.durationLeft : 0.0;
		});
	}

	/**
	 * Evaluate expression to boolean. Returns false on parse error, runtime exception, or non-true result.
	 */
	public static function evalBool(code:String, frame:AuraSignalFrame = null):Bool {
		var expr = getExpr(code);
		if (expr == null)
			return false;
		bindFrame(frame);
		try {
			var val:Dynamic = interp.execute(expr);
			if (val == null)
				return false;
			if (Std.isOfType(val, Bool))
				return (val : Bool);
			if (Std.isOfType(val, Float) || Std.isOfType(val, Int))
				return (val : Float) > 0;
			return false;
		} catch (_:Dynamic) {
			return false;
		}
	}

	/**
	 * Evaluate expression to Float number. Returns 0.0 on error.
	 */
	public static function evalFloat(code:String, frame:AuraSignalFrame = null, def:Float = 0.0):Float {
		var expr = getExpr(code);
		if (expr == null)
			return def;
		bindFrame(frame);
		try {
			var val:Dynamic = interp.execute(expr);
			if (val == null)
				return def;
			if (Std.isOfType(val, Float) || Std.isOfType(val, Int)) {
				var f:Float = val;
				return Math.isFinite(f) ? f : def;
			}
			return def;
		} catch (_:Dynamic) {
			return def;
		}
	}

	/**
	 * Clear cached ASTs.
	 */
	public static function clearCache():Void {
		exprCache = new Map();
		parseErrors = new Map();
	}
}
