package solarflare;

import hlx.runtime.ResolvedMember;

/**
 * Observe remaining duration on Status / BaseSkill. Typed getters first, then
 * FieldWalk, then resolveMember. Draw must never call this.
 */
class SkillRemain {
	static var PACK:Array<String> = [
		"remaining", "timeLeft", "durationLeft", "duration", "elapsed", "cdUntil", "progress"
	];

	static var extraNames:Array<String> = [];
	static var leftMem:ResolvedMember;
	static var progMem:ResolvedMember;
	static var elapsedMem:ResolvedMember;
	static var baseMem:ResolvedMember;
	static var evalMem:ResolvedMember;
	static var memReady:Bool = false;

	public static function read(item:Dynamic):{progress:Float, left:Float, valid:Bool} {
		if (item == null)
			return miss();
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

	static function typedRemain(item:Dynamic):{progress:Float, left:Float, valid:Bool} {
		try {
			var bs:st.skill.BaseSkill = item;
			var left = 0.0;
			try
				left = bs.getDurationLeft()
			catch (_:Dynamic)
				left = 0;
			var prog = Math.NaN;
			try
				prog = bs.getDurationProgress()
			catch (_:Dynamic)
				prog = Math.NaN;
			return finish(left, prog, 0);
		} catch (_:Dynamic) {}
		return miss();
	}

	static function elapsedRemain(item:Dynamic):{progress:Float, left:Float, valid:Bool} {
		var elapsed = callFloat(item, elapsedMem, "getElapsedTime");
		var max = callFloat(item, baseMem, "getBaseDuration");
		if (!(max > 0.05))
			max = callFloat(item, evalMem, "evalDuration");
		if (!(max > 0.05) || Math.isNaN(elapsed) || elapsed < 0)
			return miss();
		var left = max - elapsed;
		if (left < 0)
			left = 0;
		return finish(left, left / max, max);
	}

	static function infoRemain(item:Dynamic):{progress:Float, left:Float, valid:Bool} {
		try {
			var st:st.skill.Status = item;
			var info:Dynamic = st.getStatusInfo();
			if (info == null)
				return miss();
			return walkRemain(info);
		} catch (_:Dynamic) {}
		return miss();
	}

	static function walkRemain(obj:Dynamic):{progress:Float, left:Float, valid:Bool} {
		if (obj == null)
			return miss();
		var names = PACK.concat(extraNames);
		var left = FieldWalk.extractNumberAny(obj, names, -1);
		var max = FieldWalk.extractNumber(obj, "duration", 0);
		if (!(max > 0.05))
			max = FieldWalk.extractNumber(obj, "baseDuration", 0);
		var until = FieldWalk.extractNumber(obj, "cdUntil", -1);
		if (until > 100) {
			var now = gameNow();
			if (now > 0 && until > now)
				left = until - now;
		}
		var prog = FieldWalk.extractNumber(obj, "progress", Math.NaN);
		if (Math.isNaN(prog))
			prog = FieldWalk.extractNumber(obj, "durationProgress", Math.NaN);
		return finish(left, prog, max);
	}

	static function resolvedRemain(item:Dynamic):{progress:Float, left:Float, valid:Bool} {
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
		return finish(left, prog, max);
	}

	static function finish(left:Float, prog:Float, max:Float):{progress:Float, left:Float, valid:Bool} {
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
		var valid = l > 0.02 || (p > 0.001 && p < 0.999);
		if (!valid)
			return miss();
		return {progress: p, left: l, valid: true};
	}

	static function usable(r:{progress:Float, left:Float, valid:Bool}):Bool {
		return r != null && r.valid;
	}

	static function miss():{progress:Float, left:Float, valid:Bool} {
		return {progress: 1, left: 0, valid: false};
	}

	static function ledgerRemain(method:String, name:String, r:{progress:Float, left:Float, valid:Bool}, item:Dynamic):Void {
		if (r == null || !solarflare.debug.ResolutionLedger.armed())
			return;
		solarflare.debug.ResolutionLedger.touch("status.remain", method, "SkillRemain.read", name, "number", Std.string(Math.round(r.left * 1000) / 1000));
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
