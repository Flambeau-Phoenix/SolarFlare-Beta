package solarflare;

import hlx.runtime.ResolvedMember;

/**
 * Read-only Farever observation ladder.
 *
 * GameLib properties are `HlxRuntime.resolveField(this, name)` (often without `_`).
 * Haxe still emits `_name` backing fields for `(get,set)` props — try `_name` first.
 * 0-arg methods (`get_health`, `getCooldownLeft`, `isInCooldown`) are `callResolved`
 * on **this object's live HashLink type and GameLib parents only**. Never spray
 * Hero getters onto DamageResult / virtual `inf`.
 *
 * Wins are keyed `type#name`, not bare `name`.
 * Never setField / setProperty / callMethod / Type.resolveClass on engine instances.
 */
class FieldWalk {
	static var namedWins:Map<String, FieldWin> = new Map();
	static var memCache:Map<String, ResolvedMember> = new Map();
	static var memMiss:Map<String, Bool> = new Map();
	/** Live type#method with no callable anywhere on the parent chain. */
	static var chainMiss:Map<String, Bool> = new Map();
	/** type#name pairs with no backing `_name` / `name` field — skip repeat resolveField work. */
	static var fieldMiss:Map<String, Bool> = new Map();
	static var mapGetMems:Array<ResolvedMember> = null;
	static var getDynObj:ResolvedMember;
	static var getDynBase:ResolvedMember;
	static var arrayLenMem:ResolvedMember;

	static var mapTypes:Array<String> = [
		"haxe.ds.StringMap",
		"haxe.ds.ObjectMap",
		"haxe.ds.IntMap"
	];

	public static function resolveNamed(obj:Dynamic, name:String):Dynamic {
		var hit = ladder(obj, name, true);
		return hit.usable ? hit.value : null;
	}

	public static function extractObject(obj:Dynamic, propertyName:String):Dynamic {
		return resolveNamed(obj, propertyName);
	}

	/** 0-arg instance method on the live type chain (e.g. getCooldownLeft). */
	public static function callZero(obj:Dynamic, methodName:String):Dynamic {
		if (obj == null || methodName == null || methodName.length == 0)
			return null;
		if (isMutatingName(methodName))
			return null;
		var typed = callTyped(obj, methodName);
		if (usable(typed))
			return typed;
		return callResolvedChain(obj, methodName);
	}

	public static function liveTypeName(obj:Dynamic):String {
		if (obj == null)
			return "";
		try {
			var t = hl.Type.getDynamic(obj);
			if (t == null)
				return "";
			var n = t.getTypeName();
			return n != null ? n : "";
		} catch (_:Dynamic) {}
		return "";
	}

	/**
	 * Debug ladder: which step produced a usable value. Does not change extractors.
	 * Order: `_name` then `name`, then `get_` / `is_` on this type chain.
	 * Exact method-name calls belong in callZero(); property lookup never feeds a
	 * plain data-field name into the callable-member resolver.
	 */
	public static function probeNamed(obj:Dynamic, name:String):ProbeHit {
		return ladder(obj, name, false);
	}

	public static function extractPath(obj:Dynamic, names:Array<String>):Dynamic {
		var cur = obj;
		if (names == null)
			return null;
		for (n in names) {
			cur = extractObject(cur, n);
			if (cur == null)
				return null;
		}
		return cur;
	}

	public static function extractNumber(obj:Dynamic, propertyName:String, fallback:Float = 0.0):Float {
		if (obj == null)
			return fallback;
		try {
			var val = resolveNamed(obj, propertyName);
			if (val != null)
				return asFloat(val, fallback);
		} catch (_:Dynamic) {}
		return fallback;
	}

	public static function extractNumberAny(obj:Dynamic, names:Array<String>, fallback:Float = 0.0):Float {
		if (obj == null || names == null)
			return fallback;
		for (n in names) {
			try {
				var val = resolveNamed(obj, n);
				if (val != null)
					return asFloat(val, fallback);
			} catch (_:Dynamic) {}
		}
		return fallback;
	}

	public static function extractBool(obj:Dynamic, propertyName:String, fallback:Bool = false):Bool {
		if (obj == null)
			return fallback;
		try {
			var val = resolveNamed(obj, propertyName);
			if (val != null)
				return (cast val : Bool);
		} catch (_:Dynamic) {}
		return fallback;
	}

	/** String fields only. Never Std.string on Dynamic (Bytes / `{bytes :…}`). */
	public static function extractString(obj:Dynamic, propertyName:String, fallback:String = ""):String {
		if (obj == null)
			return fallback;
		try {
			var val = resolveNamed(obj, propertyName);
			if (val == null)
				return fallback;
			if (Std.isOfType(val, String)) {
				var s:String = val;
				if (s == null)
					return fallback;
				s = solarflare.ui.ByteUtil.materialize(StringTools.trim(s));
				if (s.length == 0)
					return fallback;
				return s;
			}
		} catch (_:Dynamic) {}
		return fallback;
	}

	public static function arrayLen(arr:Dynamic, fallback:Int = 0):Int {
		arr = unwrapArray(arr);
		if (arr == null)
			return fallback;
		try {
			var n:Dynamic = untyped arr.length;
			if (n != null && Math.isFinite(n) && n >= 0) return Std.int(n);
		} catch (_:Dynamic) {}
		try {
			var n = Std.int(extractNumber(arr, "length", -1));
			if (n >= 0)
				return n;
		} catch (_:Dynamic) {}
		try {
			if (arrayLenMem == null)
				arrayLenMem = resolveMem("hxbit.ArrayProxyData", "get_length");
			if (arrayLenMem != null) {
				var v:Dynamic = HlxRuntime.callResolved(arrayLenMem, [arr]);
				if (v != null)
					return Std.int((v : Float));
			}
		} catch (_:Dynamic) {}
		return fallback;
	}

	public static function arrayAt(arr:Dynamic, i:Int):Dynamic {
		arr = unwrapArray(arr);
		if (arr == null || i < 0)
			return null;
		try {
			return untyped arr.getDyn(i);
		} catch (_:Dynamic) {}
		try {
			if (getDynObj == null)
				getDynObj = resolveMem("hl.types.ArrayObj", "getDyn");
			if (getDynObj != null) {
				var v = HlxRuntime.callResolved(getDynObj, [arr, i]);
				if (v != null)
					return v;
			}
		} catch (_:Dynamic) {}
		try {
			if (getDynBase == null)
				getDynBase = resolveMem("hl.types.ArrayBase", "getDyn");
			if (getDynBase != null)
				return HlxRuntime.callResolved(getDynBase, [arr, i]);
		} catch (_:Dynamic) {}
		return null;
	}

	/** Read-only Map.get via callResolved / untyped. Never Reflect.callMethod. */
	public static function mapGet(map:Dynamic, key:Dynamic):Dynamic {
		if (map == null)
			return null;
		try {
			var v:Dynamic = untyped map.get(key);
			if (v != null)
				return v;
		} catch (_:Dynamic) {}
		ensureMapGetMems();
		for (mem in mapGetMems) {
			try {
				var v:Dynamic = HlxRuntime.callResolved(mem, [map, key]);
				if (v != null)
					return v;
			} catch (_:Dynamic) {}
		}
		return null;
	}

	static function ladder(obj:Dynamic, name:String, remember:Bool):ProbeHit {
		var hit = new ProbeHit();
		hit.name = name != null ? name : "";
		if (obj == null || name == null || name.length == 0 || isMutatingName(name)) {
			hit.step = "miss";
			return hit;
		}
		var tname = liveTypeName(obj);
		var key = tname + "#" + name;
		if (remember) {
			var win = namedWins.get(key);
			if (win != null) {
				var cached = applyWin(obj, name, win);
				// Step already validated once — null check only (no Reflect.isFunction every frame).
				if (cached != null) {
					hit.step = win.step;
					hit.value = cached;
					hit.usable = true;
					return hit;
				}
				namedWins.remove(key);
			}
		}
		var threw = false;
		if (!fieldMiss.exists(key)) {
			try {
				var underscored = resolveOneField(obj, "_" + name);
				if (usable(underscored)) {
					if (remember) {
						rememberWin(key, "_field", "", null);
						try
							solarflare.debug.FieldWalkLog.noteWin(tname, name, "_field")
						catch (_:Dynamic) {}
					}
					hit.step = "_field";
					hit.value = underscored;
					hit.usable = true;
					return hit;
				}
			} catch (_:Dynamic) {
				threw = true;
			}
			try {
				var plain = resolveOneField(obj, name);
				if (usable(plain)) {
					if (remember) {
						rememberWin(key, "field", "", null);
						try
							solarflare.debug.FieldWalkLog.noteWin(tname, name, "field")
						catch (_:Dynamic) {}
					}
					hit.step = "field";
					hit.value = plain;
					hit.usable = true;
					return hit;
				}
			} catch (_:Dynamic) {
				threw = true;
			}
			fieldMiss.set(key, true);
		}
		var g = callTyped(obj, "get_" + name);
		if (usable(g))
			return winHit(hit, remember, key, tname, name, "typed", "get_" + name, g);
		g = callTyped(obj, "is_" + name);
		if (usable(g))
			return winHit(hit, remember, key, tname, name, "typed", "is_" + name, g);
		g = callResolvedChain(obj, "get_" + name);
		if (usable(g))
			return winHit(hit, remember, key, tname, name, "get_", "get_" + name, g);
		g = callResolvedChain(obj, "is_" + name);
		if (usable(g))
			return winHit(hit, remember, key, tname, name, "is_", "is_" + name, g);
		hit.step = threw ? "throw" : "miss";
		return hit;
	}

	static function applyWin(obj:Dynamic, name:String, win:FieldWin):Dynamic {
		if (win == null)
			return null;
		if (win.step == "_field")
			return resolveOneField(obj, "_" + name);
		if (win.step == "field")
			return resolveOneField(obj, name);
		if (win.getter != null && win.getter.length > 0) {
			if (win.step == "typed") {
				if (!StringTools.startsWith(win.getter, "get_") && !StringTools.startsWith(win.getter, "is_"))
					return resolveOneField(obj, win.getter);
				return callTyped(obj, win.getter);
			}
			if (!StringTools.startsWith(win.getter, "get_") && !StringTools.startsWith(win.getter, "is_"))
				return resolveOneField(obj, win.getter);
			return callResolvedChain(obj, win.getter);
		}
		return null;
	}

	static function winHit(hit:ProbeHit, remember:Bool, key:String, tname:String, name:String, step:String, getter:String, value:Dynamic):ProbeHit {
		if (remember) {
			rememberWin(key, step, getter, null);
			try
				solarflare.debug.FieldWalkLog.noteWin(tname, name, step)
			catch (_:Dynamic) {}
		}
		hit.step = step;
		hit.value = value;
		hit.usable = true;
		return hit;
	}

	static function rememberWin(key:String, step:String, getter:String, mem:ResolvedMember):Void {
		var win = namedWins.get(key);
		if (win == null) {
			win = new FieldWin();
			namedWins.set(key, win);
		}
		win.step = step;
		win.getter = getter != null ? getter : "";
		win.mem = mem;
	}

	static function resolveOneField(obj:Dynamic, fieldName:String):Dynamic {
		try {
			var v = HlxRuntime.resolveField(obj, fieldName);
			if (usable(v))
				return v;
		} catch (_:Dynamic) {}
		return null;
	}

	static function callTyped(obj:Dynamic, methodName:String):Dynamic {
		if (obj == null || methodName == null || methodName.length == 0)
			return null;
		var t = liveTypeName(obj);
		var guard = 0;
		while (t != null && t.length > 0 && guard < 12) {
			try {
				var v:Dynamic = FieldWalkGraph.typedZero(obj, t, methodName);
				if (usable(v))
					return v;
			} catch (_:Dynamic) {}
			t = FieldWalkGraph.parentOf(t);
			guard++;
		}
		return null;
	}

	static function callResolvedChain(obj:Dynamic, methodName:String):Dynamic {
		if (obj == null || methodName == null || methodName.length == 0)
			return null;
		var t = liveTypeName(obj);
		var chainKey = t + "#" + methodName;
		if (chainMiss.exists(chainKey))
			return null;
		var guard = 0;
		while (t != null && t.length > 0 && guard < 12) {
			var mem = memberOf(t, methodName);
			if (mem != null) {
				try {
					var v:Dynamic = HlxRuntime.callResolved(mem, [obj]);
					if (usable(v))
						return v;
				} catch (_:Dynamic) {}
			}
			t = FieldWalkGraph.parentOf(t);
			guard++;
		}
		chainMiss.set(chainKey, true);
		return null;
	}

	static function memberOf(typeName:String, methodName:String):ResolvedMember {
		var key = typeName + "#" + methodName;
		if (memMiss.exists(key))
			return null;
		var cached = memCache.get(key);
		if (cached != null)
			return cached;
		var mem = resolveMem(typeName, methodName);
		if (mem == null)
			memMiss.set(key, true);
		else
			memCache.set(key, mem);
		return mem;
	}

	static function isMutatingName(name:String):Bool {
		if (name == null || name.length == 0)
			return true;
		if (StringTools.startsWith(name, "set_"))
			return true;
		if (StringTools.startsWith(name, "__net_"))
			return true;
		return false;
	}

	static function ensureMapGetMems():Void {
		if (mapGetMems != null)
			return;
		mapGetMems = [];
		for (t in mapTypes) {
			var mem = resolveMem(t, "get");
			if (mem != null)
				mapGetMems.push(mem);
		}
	}

	static function resolveMem(typeName:String, name:String):ResolvedMember {
		try {
			var t = HlxRuntime.resolveType(typeName);
			if (t == null)
				return null;
			return HlxRuntime.resolveMember(t, name);
		} catch (_:Dynamic) {}
		return null;
	}

	static function unwrapArray(arr:Dynamic):Dynamic {
		if (arr == null)
			return null;
		var inner = resolveOneField(arr, "_array");
		if (inner == null)
			inner = resolveOneField(arr, "array");
		return inner != null ? inner : arr;
	}

	static function usable(v:Dynamic):Bool {
		if (v == null)
			return false;
		try {
			switch (Type.typeof(v)) {
				case TFunction:
					return false;
				case TNull:
					return false;
				default:
					return true;
			}
		} catch (_:Dynamic) {}
		return true;
	}

	static function asFloat(val:Dynamic, fallback:Float):Float {
		try {
			var f:Float = val;
			if (Math.isNaN(f))
				return fallback;
			return f;
		} catch (_:Dynamic) {}
		return fallback;
	}
}

/** Cached FieldWalk winner for one live type + property. Never stores Dynamic payloads. */
class FieldWin {
	public var step:String = "";
	public var getter:String = "";
	public var mem:ResolvedMember;

	public function new() {}
}
