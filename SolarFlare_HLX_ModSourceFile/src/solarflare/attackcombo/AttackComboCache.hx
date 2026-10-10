package solarflare.attackcombo;

import solarflare.HealthCache;
import solarflare.ui.ByteUtil;
#if solarflare_telemetry
import solarflare.debug.ResolutionLedger;
#end

/**
 * Live weapon attack-chain state (separate from Rogue ComboPoints).
 *
 * Engine facts (hlboot 5f288029, ent.Hero): `attack` stores the used skill's index in
 * `attackSkills` into attackComboCount (0 again after the finisher, so the count alone is
 * ambiguous); `getNextAttackSkill` picks the next link from the most recent basic use and falls
 * back to attackSkills[0] once the combo window lapses. This cache mirrors that function directly.
 */
class AttackComboCache {
	public static inline var ROUTE_UNRESOLVED:String = "unresolved";
	public static inline var ROUTE_DIRECT:String = "direct";
	public static inline var FLASH_SEC:Float = AttackComboState.FLASH_SEC;
	public static var route:String = ROUTE_UNRESOLVED;
	public static var step:Int = 0;
	public static var comboLength:Int = 4;
	public static var moveSetId:String = "";
	public static var withinCombo:Bool = false;
	public static var flashFinal:Bool = false;
	public static var visible:Bool = false;
	public static var known:Bool = false;
	public static var debugLine:String = "attack-combo idle";
	static var state = new AttackComboState();

	public static function keep():Void {}

	public static function clear(reason:String):Void {
		state.clear();
		publishSnap(-1);
		debugLine = "reset:" + reason;
	}

	/**
	 * Native: fun(ent.Hero, i32) -> i32 → postfix N+1 = 3, return result unaltered.
	 * Wake-up only: the written count is ambiguous (finisher writes 0), so the chain is read
	 * from the engine's own skill list instead of reconstructed from this value.
	 */
	@:keep
	@:hlx.postfix(ent.Hero.set_attackComboCount)
	static function onSetAttackComboCount(self:Dynamic, value:Int, result:Int):Int {
		try {
			if (self != null && HealthCache.isLocalHero(self))
				solarflare.ObserveDemand.markAttackComboDirty();
		} catch (_:Dynamic) {}
		return result;
	}

	/** Forwarded from BaseSkill.doStart: exact chain position for basics, flash for the finisher. */
	public static function onBaseSkillStart(skill:Dynamic):Void {
		if (skill == null) return;
		try {
			var bs:st.skill.BaseSkill = skill;
			var unit = bs.get_ownerUnit();
			if (unit == null) unit = bs.get_ownerHero();
			if (unit == null || !HealthCache.isLocalHero(unit)) return;
			var isBase = false;
			var isFinal = false;
			try isBase = bs.isBasicAttack() catch (_:Dynamic) {}
			try isFinal = bs.isFinalAttack() catch (_:Dynamic) {}
			if (!isBase && !isFinal) return;
			var hero:ent.Hero = HealthCache.localHero;
			if (hero == null) return;
			var chain = readChain(hero, skill);
			var metadata = readMoveSet(hero);
			var length = chain.length > 0 ? chain.length : metadata.length;
			if (isFinal) {
				state.finisher(now(), HealthCache.identityGen, length, metadata.id);
				noteEdge("final", state.step, chain.index);
			} else if (chain.index >= 0) {
				state.basic(HealthCache.identityGen, chain.index, length, metadata.id);
				noteEdge("base", state.step, chain.index);
			}
			solarflare.ObserveDemand.markAttackComboDirty();
			publishSnap(chain.index);
		} catch (_:Dynamic) {}
	}

	public static function observe():Void {
		var hero:ent.Hero = HealthCache.localHero;
		if (hero == null) { clear("no_hero"); return; }
		var chain = readChain(hero, null);
		var metadata = readMoveSet(hero);
		var length = chain.length > 0 ? chain.length : metadata.length;
		state.observe(now(), HealthCache.identityGen, chain.next, length, metadata.id);
		publishSnap(chain.next);
	}

	/** Freeze primitive presentation state; draw never reads the engine. */
	static function publishSnap(raw:Int):Void {
		route = state.direct ? ROUTE_DIRECT : ROUTE_UNRESOLVED;
		step = state.step;
		comboLength = state.comboLength;
		moveSetId = state.moveSetId;
		withinCombo = state.withinCombo;
		flashFinal = state.flashFinal;
		visible = state.visible;
		known = state.known;
		debugLine = route + " step=" + step + "/" + comboLength + " next=" + raw + " within=" + withinCombo + " known=" + known + (moveSetId.length > 0 ? " ms=" + moveSetId : "");
	}

	static inline function noteEdge(kind:String, expected:Int, raw:Int):Void {
		#if solarflare_telemetry
		if (ResolutionLedger.armed()) ResolutionLedger.touch("ATTACK_COMBO_EDGE", "hook", "AttackComboCache.onBaseSkillStart", kind, "string", "step=" + expected + " idx=" + raw);
		#end
	}

	/**
	 * length: basic attacks + finisher. index: position of `skill` in attackSkills (-1 unknown).
	 * next: engine's next link as an index (attackSkills.length = finisher primed; 0 = idle).
	 */
	static function readChain(hero:ent.Hero, skill:Dynamic):{length:Int, index:Int, next:Int} {
		var length = 0;
		var index = -1;
		var next = -1;
		try {
			var list = hero.attackSkills;
			if (list != null) {
				var n:Int = list.length;
				var finisher = hero.attackComboSkill;
				length = n + (finisher != null ? 1 : 0);
				if (skill != null) {
					for (i in 0...n)
						if (list.getDyn(i) == skill) { index = i; break; }
				}
				var upcoming = hero.getNextAttackSkill();
				if (upcoming == null) {
					next = 0;
				} else if (finisher != null && upcoming == finisher) {
					next = n;
				} else {
					for (i in 0...n)
						if (list.getDyn(i) == upcoming) { next = i; break; }
				}
			}
		} catch (_:Dynamic) {}
		return {length: length, index: index, next: next};
	}

	static function readMoveSet(hero:ent.Hero):{length:Int, id:Null<String>} {
		try {
			var ms = hero.getMoveSet();
			// A successful null moveset means no active weapon; a thrown read stays unknown.
			if (ms == null) return {length:0, id:""};
			var id = ms.id == null ? null : ByteUtil.materialize(ms.id);
			return {length:ms.comboLength, id:id != null && id.length > 0 ? id : null};
		} catch (_:Dynamic) {}
		return {length:0, id:null};
	}

	static function now():Float { try return haxe.Timer.stamp() catch (_:Dynamic) return Date.now().getTime() / 1000.0; }
}
