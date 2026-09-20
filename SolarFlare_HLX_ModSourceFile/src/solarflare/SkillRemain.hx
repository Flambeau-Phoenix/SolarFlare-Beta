package solarflare;

import hlx.runtime.ResolvedMember;

/**
 * Observe remaining duration on Status / BaseSkill. Typed getters first, then
 * FieldWalk, then resolveMember. Draw must never call this.
 *
 * Returns a reused SkillRemainResult — copy fields immediately; do not stash the reference
 * across another read().
 */
class SkillRemain {
	/** Sentinel left value when Status.isInfinite is true. */
	public static inline var INFINITE_LEFT:Float = -1;
	/** Finite remain above this is treated as non-expiring (clone/residual residues). */
	static inline var MAX_FINITE_LEFT:Float = 3600;

	static var PACK:Array<String> = [
		"remaining", "timeLeft", "durationLeft", "elapsed", "cdUntil", "progress"
	];

	static var extraNames:Array<String> = [];
	static var leftMem:ResolvedMember;
	static var progMem:ResolvedMember;
	static var elapsedMem:ResolvedMember;
	static var baseMem:ResolvedMember;
	static var evalMem:ResolvedMember;
	static var memReady:Bool = false;
	static var lastResult:SkillRemainResult = new SkillRemainResult();

	static inline var RUNG_STATUS:Int = 0;
	static inline var RUNG_TYPED:Int = 1;
	static inline var RUNG_ELAPSED:Int = 2;
	static inline var RUNG_INFO:Int = 3;
	static inline var RUNG_WALK:Int = 4;
	static inline var RUNG_INF:Int = 5;
	static inline var RUNG_RESOLVED:Int = 6;
	static inline var RUNG_COUNT:Int = 7;
	static inline var RUNG_MEMO_CAP:Int = 48;

	/**
	 * Lowest ladder rung ever observed to win, per HL type name. Items whose typed path
	 * fails used to re-walk the whole ladder at sample rate; now they start at the winner.
	 * Storing the minimum (never the latest) means a rung that has previously produced a
	 * result for this type can never be skipped, so the memo cannot change an outcome.
	 */
	static var rungByType:Map<String, Int> = new Map();

	public static function read(item:Dynamic):SkillRemainResult {
		if (item == null)
			return miss();
		var typeName:String = null;
		try
			typeName = FieldWalk.liveTypeName(item)
		catch (_:Dynamic)
			typeName = null;
		var keyed = typeName != null && typeName.length > 0;
		var start = -1;
		if (keyed) {
			var memo = rungByType.get(typeName);
			if (memo != null)
				start = memo;
		}
		if (start > 0) {
			var hit = tryRung(item, start);
			if (hit != null)
				return hit;
		}
		var i = 0;
		while (i < RUNG_COUNT) {
			if (i != start) {
				var hit = tryRung(item, i);
				if (hit != null) {
					if (keyed && (start < 0 || i < start) && countKeys() < RUNG_MEMO_CAP)
						rungByType.set(typeName, i);
					return hit;
				}
			}
			i++;
		}
		return miss();
	}

	/** One ladder step. Returns null when the rung has nothing usable. */
	static function tryRung(item:Dynamic, rung:Int):SkillRemainResult {
		switch (rung) {
			case RUNG_STATUS:
				var r = statusRemain(item);
				if (usable(r)) {
					ledgerRemain("typed", r.infinite ? "isInfinite" : "Status.getDurationLeft", r, item);
					return r;
				}
			case RUNG_TYPED:
				var r = typedRemain(item);
				if (usable(r)) {
					ledgerRemain("typed", "getDurationLeft", r, item);
					return r;
				}
			case RUNG_ELAPSED:
				var r = elapsedRemain(item);
				if (usable(r)) {
					ledgerRemain("callResolved", "getElapsedTime", r, item);
					return r;
				}
			case RUNG_INFO:
				var r = infoRemain(item);
				if (usable(r)) {
					ledgerRemain("typed", "getStatusInfo", r, item);
					return r;
				}
			case RUNG_WALK:
				var r = walkRemain(item);
				if (usable(r)) {
					ledgerRemain("fieldwalk", "remaining", r, item);
					return r;
				}
			case RUNG_INF:
				var inf = FieldWalk.extractObject(item, "inf");
				if (inf != null) {
					var r = walkRemain(inf);
					if (usable(r)) {
						ledgerRemain("fieldwalk", "inf.remaining", r, item);
						return r;
					}
				}
			case RUNG_RESOLVED:
				var r = resolvedRemain(item);
				if (usable(r)) {
					ledgerRemain("callResolved", "getDurationLeft", r, item);
					return r;
				}
			default:
		}
		return null;
	}

	static function countKeys():Int {
		var n = 0;
		for (_ in rungByType.keys())
			n++;
		return n;
	}

	public static function noteExtraName(name:String):Void {
		if (name == null)
			return;
		var s = StringTools.trim(name);
		if (s.length < 2 || s.length > 48)
			return;
		if (StringTools.startsWith(s, "inf."))
			s = s.substr(4);
		if (StringTools.startsWith(s, "get_"))
			s = s.substr(4);
		var i = 0;
		while (i < extraNames.length) {
			if (extraNames[i] == s)
				return;
			i++;
		}
		if (extraNames.length >= 12)
			return;
		extraNames.push(s);
	}

	/** Status-first path matching EventHorizon AuraTracker candidates. */
	static function statusRemain(item:Dynamic):SkillRemainResult {
		try {
			var st:st.skill.Status = item;
			try {
				if (st.isInfinite())
					return lastResult.set(1, INFINITE_LEFT, true, true);
			} catch (_:Dynamic) {}
			var dur = 0.0;
			try dur = st.duration catch (_:Dynamic) dur = 0;
			if (dur <= 0.05) {
				return lastResult.set(1, INFINITE_LEFT, true, true);
			}
			var left = 0.0;
			var gotLeft = false;
			try {
				left = st.getDurationLeft();
				gotLeft = true;
			} catch (_:Dynamic)
				left = 0;
			var prog = Math.NaN;
			try
				prog = st.getDurationProgress()
			catch (_:Dynamic)
				prog = Math.NaN;
			var progLive = !Math.isNaN(prog) && prog > 0.001 && prog < 0.999;
			var max = dur;
			if (max <= 0.05 && !progLive) {
				try {
					var info = st.getStatusInfo();
					if (info != null) {
						var d:Float = info.duration;
						if (d > 0.05)
							max = d;
					}
				} catch (_:Dynamic) {}
			}
			// Known finite expiry only when a duration domain exists (max > 0.05), not untimed 0.
			if (gotLeft && left <= 0.02 && max > 0.05) {
				return lastResult.set(0, left < 0 ? 0 : left, true, false);
			}
			return finish(left, prog, max, false);
		} catch (_:Dynamic) {}
		return miss();
	}

	static function typedRemain(item:Dynamic):SkillRemainResult {
		try {
			var bs:st.skill.BaseSkill = item;
			var dur = 0.0;
			try dur = bs.duration catch (_:Dynamic) dur = 0;
			if (dur <= 0.05) {
				return lastResult.set(1, INFINITE_LEFT, true, true);
			}
			var left = 0.0;
			var gotLeft = false;
			try {
				left = bs.getDurationLeft();
				gotLeft = true;
			} catch (_:Dynamic)
				left = 0;
			var prog = Math.NaN;
			try
				prog = bs.getDurationProgress()
			catch (_:Dynamic)
				prog = Math.NaN;
			if (gotLeft && left <= 0.02 && dur > 0.05)
				return lastResult.set(0, left < 0 ? 0 : left, true, false);
			return finish(left, prog, dur, false);
		} catch (_:Dynamic) {}
		return miss();
	}

	static function elapsedRemain(item:Dynamic):SkillRemainResult {
		var elapsed = callFloat(item, elapsedMem, "getElapsedTime");
		var max = callFloat(item, baseMem, "getBaseDuration");
		if (!(max > 0.05))
			max = callFloat(item, evalMem, "evalDuration");
		if (!(max > 0.05) || Math.isNaN(elapsed) || elapsed < 0)
			return miss();
		var left = max - elapsed;
		if (left < 0)
			left = 0;
		return finish(left, left / max, max, false);
	}

	static function infoRemain(item:Dynamic):SkillRemainResult {
		try {
			var st:st.skill.Status = item;
			var info:Dynamic = st.getStatusInfo();
			if (info == null)
				return miss();
			return walkRemain(info);
		} catch (_:Dynamic) {}
		return miss();
	}

	static function walkRemain(obj:Dynamic):SkillRemainResult {
		if (obj == null)
			return miss();
		var left = FieldWalk.extractNumberAny(obj, PACK, -1);
		if (!(left > 0) && extraNames.length > 0)
			left = FieldWalk.extractNumberAny(obj, extraNames, -1);
		var max = FieldWalk.extractNumber(obj, "duration", 0);
		if (!(max > 0.05))
			max = FieldWalk.extractNumber(obj, "baseDuration", 0);
		// Prefer remaining-named fields; treat bare "duration" as max, not left.
		if (!(left > 0) && max > 0.05) {
			var elapsed = FieldWalk.extractNumber(obj, "elapsed", Math.NaN);
			if (!Math.isNaN(elapsed) && elapsed >= 0)
				left = max - elapsed;
		}
		var until = FieldWalk.extractNumber(obj, "cdUntil", -1);
		if (until > 100) {
			var now = gameNow();
			if (now > 0 && until > now)
				left = until - now;
		}
		var prog = FieldWalk.extractNumber(obj, "progress", Math.NaN);
		if (Math.isNaN(prog))
			prog = FieldWalk.extractNumber(obj, "durationProgress", Math.NaN);
		return finish(left, prog, max, false);
	}

	static function resolvedRemain(item:Dynamic):SkillRemainResult {
		ensureMems();
		var left = callFloat(item, leftMem, "getDurationLeft");
		var prog = callFloat(item, progMem, "getDurationProgress");
		var max = callFloat(item, baseMem, "getBaseDuration");
		if (!(max > 0.05))
			max = callFloat(item, evalMem, "evalDuration");
		if (!(left > 0) && max > 0.05) {
			var elapsed = callFloat(item, elapsedMem, "getElapsedTime");
			if (!Math.isNaN(elapsed) && elapsed >= 0)
				left = max - elapsed;
		}
		return finish(left, prog, max, false);
	}

	static function finish(left:Float, prog:Float, max:Float, infinite:Bool):SkillRemainResult {
		if (infinite)
			return lastResult.set(1, INFINITE_LEFT, true, true);
		var l = left;
		if (Math.isNaN(l) || l < 0)
			l = 0;
		// Residual / clone leftovers above one hour are treated as non-expiring.
		if (l > MAX_FINITE_LEFT)
			return lastResult.set(1, INFINITE_LEFT, true, true);
		var p = prog;
		if (Math.isNaN(p) || p < 0 || p > 1.01) {
			if (max > 0.05 && l >= 0)
				p = l / max;
			else if (l > 0.05)
				p = 1;
			else
				p = 0;
		}
		if (p > 1)
			p = 1;
		if (p < 0)
			p = 0;
		// Known when seconds remain, mid-progress, or a fresh/full timer with positive left.
		var valid = l > 0.02 || (p > 0.001 && p < 0.999);
		if (!valid)
			return miss();
		return lastResult.set(p, l, true, false);
	}

	static function usable(r:SkillRemainResult):Bool {
		return r != null && r.valid;
	}

	static function miss():SkillRemainResult {
		return lastResult.set(1, 0, false, false);
	}

	/** One binding per (method, name) winner; the ladder only ever uses a handful. */
	static var remainBinds:Map<String, solarflare.debug.LedgerBinding> = new Map();
	static var lastLeftMilli:Int = -1;

	static function ledgerRemain(method:String, name:String, r:SkillRemainResult, item:Dynamic):Void {
		if (r == null || !solarflare.debug.ResolutionLedger.armed())
			return;
		var bindKey = method + "|" + name;
		var b = remainBinds.get(bindKey);
		if (b == null) {
			b = new solarflare.debug.LedgerBinding();
			remainBinds.set(bindKey, b);
		}
		if (!solarflare.debug.ResolutionLedger.bind(b, "status.remain", method, "SkillRemain.read", name))
			return;
		// Only re-stringify when the rounded value actually moved.
		var milli = r.infinite ? -1 : Math.round(r.left * 1000);
		var val:String = null;
		if (milli != lastLeftMilli) {
			lastLeftMilli = milli;
			val = r.infinite ? "inf" : Std.string(milli / 1000);
		}
		solarflare.debug.ResolutionLedger.bump(b, val);
	}

	static function callFloat(item:Dynamic, mem:ResolvedMember, method:String):Float {
		ensureMems();
		if (mem != null) {
			try {
				var v:Dynamic = HlxRuntime.callResolved(mem, [item]);
				if (v != null) {
					var f:Float = v;
					if (!Math.isNaN(f))
						return f;
				}
			} catch (_:Dynamic) {}
		}
		var n = FieldWalk.extractNumber(item, method, Math.NaN);
		return n;
	}

	static function ensureMems():Void {
		if (memReady)
			return;
		memReady = true;
		leftMem = resolveMem("st.skill.BaseSkill", "getDurationLeft");
		progMem = resolveMem("st.skill.BaseSkill", "getDurationProgress");
		elapsedMem = resolveMem("st.skill.BaseSkill", "getElapsedTime");
		baseMem = resolveMem("st.skill.BaseSkill", "getBaseDuration");
		evalMem = resolveMem("st.skill.BaseSkill", "evalDuration");
	}

	static function resolveMem(typeName:String, name:String):ResolvedMember {
		try
			return HlxRuntime.resolveMember(HlxRuntime.resolveType(typeName), name)
		catch (_:Dynamic) {}
		return null;
	}

	static function gameNow():Float {
		try {
			var t = hxd.Timer.lastTimeStamp;
			if (t > 0)
				return t;
		} catch (_:Dynamic) {}
		try {
			var t = hxd.Timer.elapsedTime;
			if (t > 0)
				return t;
		} catch (_:Dynamic) {}
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}
}

/** Reused by SkillRemain.read — copy fields before the next read. */
class SkillRemainResult {
	public var progress:Float = 1;
	public var left:Float = 0;
	public var valid:Bool = false;
	public var infinite:Bool = false;

	public function new() {}

	public function set(progress:Float, left:Float, valid:Bool, infinite:Bool):SkillRemainResult {
		this.progress = progress;
		this.left = left;
		this.valid = valid;
		this.infinite = infinite;
		return this;
	}
}
