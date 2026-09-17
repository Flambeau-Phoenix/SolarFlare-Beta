package solarflare.combatlog;

class CombatLogLine {
	public var sequence:Float = 0;
	public var kind:Int = 0;
	public var skillId:String = "";
	public var skillName:String = "";
	public var skillLabel:String = "";
	public var sourceName:String = "";
	public var sourcePlayer:String = "";
	/** Summoned unit that dealt hit; source remains credited owner. */
	public var minionName:String = "";
	public var targetName:String = "";
	public var targetPlayer:String = "";
	public var sourceRole:Int = 0;
	public var targetRole:Int = 0;
	public var amount:Float = 0;
	public var blockAmt:Float = 0;
	public var crit:Bool = false;
	public var kill:Bool = false;
	public var blocked:Bool = false;
	public var physical:Bool = false;
	public var magic:Bool = false;
	public var auto:Bool = false;
	public var affinity:String = "";
	public var involvesCurrentTarget:Bool = false;
	public var heroInvolved:Bool = false;
	/** Source or target within CombatLogConfig.PROXIMITY of local hero (pos2D). */
	public var inProximity:Bool = false;
	public var t:Float = 0;
	public var wallMs:Float = 0;
	public var targetHp:Float = 0;
	public var targetMaxHp:Float = 0;
	var cachedTimeMs:Float = -1;
	var cachedTimeText:String = "";

	public function new() {}

	/** Cached local HH:MM:SS label; recomputed only if the snapshot timestamp changes. */
	public function timeText():String {
		var ms = wallMs > 0 ? wallMs : t * 1000;
		if (ms == cachedTimeMs)
			return cachedTimeText;
		cachedTimeMs = ms;
		if (wallMs > 0) {
			var d = Date.fromTime(ms);
			cachedTimeText = two(d.getHours()) + ":" + two(d.getMinutes()) + ":" + two(d.getSeconds());
		} else {
			var sec = Std.int(t);
			cachedTimeText = two(Std.int(sec / 3600) % 24) + ":" + two(Std.int(sec / 60) % 60) + ":" + two(sec % 60);
		}
		return cachedTimeText;
	}

	static function two(v:Int):String return v < 10 ? "0" + v : Std.string(v);

	public function toJson():String {
		var o:Dynamic = {
			type: "event",
			kind: kindName(kind),
			skill: jsonStr(skillId),
			skillName: jsonStr(skillName.length > 0 ? skillName : skillLabel),
			sourcePlayer: jsonStr(sourcePlayer),
			source: jsonStr(sourceName),
			minion: jsonStr(minionName),
			sourceRole: sourceRole,
			targetPlayer: jsonStr(targetPlayer),
			target: jsonStr(targetName),
			targetRole: targetRole,
			amount: round1(amount),
			block: round1(blockAmt),
			crit: crit,
			kill: kill,
			blocked: blocked,
			physical: physical,
			magic: magic,
			auto: auto,
			affinity: jsonStr(affinity),
			targetHp: round1(targetHp),
			targetMaxHp: round1(targetMaxHp),
			targetHpPct: targetMaxHp > 0 ? round2(targetHp / targetMaxHp) : 0,
			t: round2(t),
			ms: wallMs
		};
		return haxe.Json.stringify(o);
	}

	static function kindName(k:Int):String {
		if (k == CombatLogCache.KIND_CAST)
			return "cast";
		if (k == CombatLogCache.KIND_HIT)
			return "hit";
		return "?";
	}

	static function jsonStr(s:String):String {
		if (s == null || s.length == 0)
			return "";
		try {
			var out = new StringBuf();
			var i = 0;
			while (i < s.length) {
				var c = s.charCodeAt(i);
				if (c != null)
					out.addChar(c);
				i++;
			}
			return out.toString();
		} catch (_:Dynamic) {
			return "";
		}
	}

	static function round1(v:Float):Float {
		return Math.isFinite(v) ? Math.ffloor(v * 10 + 0.5) / 10 : 0;
	}

	static function round2(v:Float):Float {
		return Math.isFinite(v) ? Math.ffloor(v * 100 + 0.5) / 100 : 0;
	}
}
