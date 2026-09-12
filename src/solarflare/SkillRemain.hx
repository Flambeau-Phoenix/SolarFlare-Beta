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

	public static function read(item:Dynamic):SkillRemainResult {
		if (item == null)
			return miss();
		var status = statusRemain(item);
		if (usable(status)) {
			ledgerRemain("typed", status.infinite ? "isInfinite" : "Status.getDurationLeft", status, item);
			return status;
		}
		var typed = typedRemain(item);
		if (usable(typed)) {
			ledgerRemain("typed", "getDurationLeft", typed, item);
			return typed;
		}
		var math = elapsedRemain(item);
		if (usable(math)) {
			ledgerRemain("callResolved", "getElapsedTime", math, item);
			return math;
		}
		var info = infoRemain(item);
		if (usable(info)) {
			ledgerRemain("typed", "getStatusInfo", info, item);
			return info;
		}
		var walked = walkRemain(item);
		if (usable(walked)) {
			ledgerRemain("fieldwalk", "remaining", walked, item);
			return walked;
		}
		var inf = FieldWalk.extractObject(item, "inf");
		if (inf != null) {
			var nested = walkRemain(inf);
			if (usable(nested)) {
				ledgerRemain("fieldwalk", "inf.remaining", nested, item);
				return nested;
			}
		}
		var resolved = resolvedRemain(item);
		if (usable(resolved)) {
			ledgerRemain("callResolved", "getDurationLeft", resolved, item);
			return resolved;
		}
		return miss();
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
			var max = 0.0;
			try {
				var info = st.getStatusInfo();
				if (info != null) {
					var d:Float = info.duration;
					if (d > 0.05)
						max = d;
				}
			} catch (_:Dynamic) {}
			// Known finite expiry only when a duration domain exists (max/progress), not bare 0.
			if (gotLeft && left <= 0.02) {
				var hadTimer = max > 0.05 || (!Math.isNaN(prog) && prog >= 0 && prog < 0.999);
				if (hadTimer)
					return lastResult.set(0, left < 0 ? 0 : left, true, false);
			}
			return finish(left, prog, max, false);
		} catch (_:Dynamic) {}
		return miss();
	}

	static function typedRemain(item:Dynamic):SkillRemainResult {
		try {
			var bs:st.skill.BaseSkill = item;
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
			if (gotLeft && left <= 0.02 && !Math.isNaN(prog) && prog >= 0 && prog < 0.999)
				return lastResult.set(0, left < 0 ? 0 : left, true, false);
			return finish(left, prog, 0, false);
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

	static function ledgerRemain(method:String, name:String, r:SkillRemainResult, item:Dynamic):Void {
		if (r == null || !solarflare.debug.ResolutionLedger.armed())
			return;
		var val = r.infinite ? "inf" : Std.string(Math.round(r.left * 1000) / 1000);
		solarflare.debug.ResolutionLedger.touch("status.remain", method, "SkillRemain.read", name, "number", val);
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
