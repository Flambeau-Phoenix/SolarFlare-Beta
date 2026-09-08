package solarflare.attackcombo;

import solarflare.FieldWalk;
import solarflare.HealthCache;
import solarflare.debug.ResolutionLedger;

/** Live weapon attack-chain state. This is separate from Rogue ComboPoints. */
class AttackComboCache {
	public static inline var ROUTE_UNRESOLVED:String = "unresolved";
	public static inline var ROUTE_DIRECT:String = "direct";
	public static inline var FLASH_SEC:Float = 0.35;
	public static var route:String = ROUTE_UNRESOLVED;
	public static var step:Int = 0;
	public static var comboLength:Int = 4;
	public static var moveSetId:String = "";
	public static var withinCombo:Bool = false;
	public static var flashFinal:Bool = false;
	public static var visible:Bool = false;
	public static var debugLine:String = "attack-combo idle";
	static var expectedStep:Int = 0;
	static var flashUntil:Float = 0;
	static var lastRawCount:Int = -1;
	static var lastWithin:Bool = false;

	public static function keep():Void {}

	public static function clear(reason:String):Void {
		expectedStep = 0; step = 0; withinCombo = false; flashFinal = false; flashUntil = 0; visible = false;
		debugLine = "reset:" + reason;
	}

	/** Forwarded from the existing BaseSkill.doStart postfix. */
	public static function onBaseSkillStart(skill:Dynamic):Void {
		if (skill == null) return;
		try {
			var bs:st.skill.BaseSkill = skill;
			var unit = bs.get_ownerUnit();
			if (unit == null) unit = bs.get_ownerHero();
			if (unit == null || !HealthCache.isLocalHero(unit)) return;
			var isBase = false;
			var isFinal = false;
			try isBase = bs.isBaseAttack() catch (_:Dynamic) {}
			try isFinal = bs.isFinalAttack() catch (_:Dynamic) {}
			if (!isBase && !isFinal) return;
			var hero = HealthCache.localHero;
			var raw = readComboCount(hero);
			var length = readComboLength(hero);
			if (length > 0) comboLength = length;
			moveSetId = readMoveSetId(hero);
			var nextExpected = expectedStep + 1;
			var isFinalStep = isFinal || (comboLength > 0 && nextExpected >= comboLength);
			if (isFinalStep) {
				expectedStep = comboLength > 0 ? comboLength : nextExpected;
				flashUntil = now() + FLASH_SEC;
				noteEdge("final", expectedStep, raw);
			} else {
				expectedStep = nextExpected;
				noteEdge("base", expectedStep, raw);
			}
			// A base/final attack start is authoritative combo state; observe()
			// may not have caught up yet, and publishSnap gates route mapping on it.
			withinCombo = true;
			solarflare.ObserveDemand.markAttackComboDirty();
			publishSnap(hero, true);
		} catch (_:Dynamic) {}
	}

	public static function observe():Void {
		var hero = HealthCache.localHero;
		if (hero == null) { clear("no_hero"); return; }
		var within = readWithinCombo(hero);
		var raw = readComboCount(hero);
		var length = readComboLength(hero);
		if (length > 0) comboLength = length;
		var id = readMoveSetId(hero);
		if (id.length > 0) moveSetId = id;
		if (lastWithin && !within) {
			clear("engine_break");
			noteTarget(raw, within, "engine_break");
			lastWithin = within; lastRawCount = raw;
			return;
		}
		lastWithin = within;
		withinCombo = within;
		if (raw != lastRawCount) { noteTarget(raw, within, "count_change"); lastRawCount = raw; }
		flashFinal = now() < flashUntil;
		if (!flashFinal) flashUntil = 0;
		publishSnap(hero, false);
	}

	/** Freeze one display step. Hook edges lead engine count briefly; observe polls use direct count. */
	static function publishSnap(hero:Dynamic, preferExpected:Bool):Void {
		var raw = readComboCount(hero);
		var display = 0;
		if (raw >= 0)
			route = ROUTE_DIRECT;

		if (flashFinal && comboLength > 0)
			display = comboLength;
		else if (withinCombo) {
			if (preferExpected && expectedStep > 0)
				display = expectedStep;
			else if (raw > 0)
				display = raw;
			else
				display = expectedStep;
		}

		if (display < 0)
			display = 0;
		if (comboLength > 0 && display > comboLength)
			display = comboLength;

		step = display;
		visible = withinCombo || flashFinal || step > 0;
		debugLine = route + " step=" + step + "/" + comboLength + " raw=" + raw + " within=" + withinCombo + (moveSetId.length > 0 ? " ms=" + moveSetId : "");
	}

	static function noteEdge(kind:String, expected:Int, raw:Int):Void { if (ResolutionLedger.armed()) ResolutionLedger.touch("ATTACK_COMBO_EDGE", "hook", "AttackComboCache.onBaseSkillStart", kind, "string", "exp=" + expected + " raw=" + raw); }
	static function noteTarget(raw:Int, within:Bool, why:String):Void { if (ResolutionLedger.armed()) ResolutionLedger.touch("ATTACK_COMBO_TARGET", "poll", "AttackComboCache.observe", why, "string", "raw=" + raw + " within=" + within + " route=" + route); }
	static function readComboCount(hero:Dynamic):Int {
		if (hero == null) return -1;
		try { var h:ent.Hero = cast hero; return Std.int(h.attackComboCount); } catch (_:Dynamic) {}
		var v = FieldWalk.extractObject(hero, "attackComboCount");
		var n = v == null ? Math.NaN : Std.parseFloat(Std.string(v));
		return Math.isNaN(n) ? -1 : Std.int(n);
	}
	static function readWithinCombo(hero:Dynamic):Bool { try { var h:ent.Hero = cast hero; return h.isWithinAttackCombo(); } catch (_:Dynamic) {} return false; }
	static function readComboLength(hero:Dynamic):Int {
		if (hero == null) return 0;
		try { var h:ent.Hero = cast hero; var ms:Dynamic = h.getMoveSet(); var n = ms == null ? Math.NaN : Std.parseFloat(Std.string(FieldWalk.extractObject(ms, "comboLength"))); if (!Math.isNaN(n) && n > 0) return Std.int(n); } catch (_:Dynamic) {}
		try { var ms:Dynamic = FieldWalk.extractObject(hero, "moveSet"); var n = Std.parseFloat(Std.string(FieldWalk.extractObject(ms, "comboLength"))); return Math.isNaN(n) ? 0 : Std.int(n); } catch (_:Dynamic) {}
		return 0;
	}
	static function readMoveSetId(hero:Dynamic):String { try { var h:ent.Hero = cast hero; var ms:Dynamic = h.getMoveSet(); var id = ms == null ? null : FieldWalk.extractObject(ms, "id"); return id == null ? "" : Std.string(id); } catch (_:Dynamic) {} return ""; }
	static function now():Float { try return haxe.Timer.stamp() catch (_:Dynamic) return Date.now().getTime() / 1000.0; }
}
