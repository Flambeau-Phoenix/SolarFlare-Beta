package solarflare.debug;

import solarflare.FieldWalk;
import solarflare.ProbeHit;
import imgui.ref.BoolRef;
import sys.io.File;

/**
 * Opt-in production-resolve ledger. Panel open is separate from recording.
 * Recording is session-only (never persisted) so logs do not grow across launches.
 * Aggregates winners in memory; JSONL flushes pending deltas ~2s while recording.
 */
@:keep
class ResolutionLedger {
	/** Show the overlay panel (may be restored from settings). */
	public static var enabled = new BoolRef(false);
	/** Write JSONL / snapshots. Session-only; defaults off. */
	public static var recording = new BoolRef(false);
	public static var lastPath:String = "";
	public static var lastLabel:String = "resolution-ledger idle";
	public static var lastJson:String = "{}";

	static inline var FLUSH_S:Float = 2.0;
	static inline var SNAP_S:Float = 2.0;

	static var aggs:Map<String, LedgerAgg> = new Map();
	static var order:Array<String> = [];
	static var buf:Array<String> = [];
	static var jsonlPath:String = "";
	static var snapPath:String = "";
	static var lastFlush:Float = 0;
	static var lastSnapWrite:Float = 0;
	static var ready:Bool = false;
	static var dirty:Bool = false;
	static var lastRecording:Bool = false;

	public static function keep():Void {
		ensure();
		ResolutionCatalog.keep();
	}

	/** Bumped on clearSession so stale LedgerBinding handles re-resolve instead of writing. */
	static var sessionGen:Int = 0;

	/** True only while the user explicitly started recording. */
	public static function armed():Bool {
		return recording != null && recording.get();
	}

	public static function startRecording():Void {
		ensure();
		LogRotation.enforce(jsonlPath);
		recording.set(true);
		FieldWalkLog.clearSession();
		lastLabel = "resolution-ledger recording";
	}

	public static function stopRecording():Void {
		if (!armed())
			return;
		recording.set(false);
		flush();
		writeSnapshot();
		ResolutionCoverage.writeReport();
		lastLabel = "resolution-ledger stopped";
	}

	/** Clear in-memory aggs (does not delete log files). */
	public static function clearSession():Void {
		// Invalidate every LedgerBinding so none keeps writing into a detached row.
		sessionGen++;
		aggs = new Map();
		order = [];
		buf = [];
		dirty = false;
		lastJson = "{}";
		FieldWalkLog.clearSession();
		lastLabel = armed() ? "resolution-ledger recording (cleared)" : "resolution-ledger idle";
	}

	public static function tick():Void {
		var on = armed();
		if (on != lastRecording) {
			lastRecording = on;
			if (!on)
				flush();
		}
		if (!on)
			return;
		ensure();
		var now = stamp();
		if (dirty && now - lastFlush >= FLUSH_S)
			flush();
		if (now - lastSnapWrite >= SNAP_S)
			writeSnapshot();
	}

	public static function note(key:String):ResolutionNote {
		var n = new ResolutionNote();
		n.key = key != null ? key : "";
		return n;
	}

	public static function commit(n:ResolutionNote):Void {
		if (!armed() || n == null || n.key == null || n.key.length == 0)
			return;
		ensure();
		var method = n.method != null ? n.method : "";
		var step = n.step != null ? n.step : "";
		var nameWon = cleanId(n.nameWon);
		var hook = n.hook != null ? n.hook : "";
		var agg = resolveAgg(n.key, method, step, nameWon, hook);
		agg.hits++;
		agg.src = n.src != null ? n.src : agg.src;
		if (step.length > 0)
			agg.step = step;
		if (hook.length > 0)
			agg.hook = hook;
		agg.payloadType = n.payloadType != null && n.payloadType.length > 0 ? n.payloadType : agg.payloadType;
		agg.payloadRole = n.payloadRole != null && n.payloadRole.length > 0 ? n.payloadRole : agg.payloadRole;
		if (n.args != null && n.args.length > 0)
			agg.args = n.args;
		if (n.kind != null && n.kind.length > 0)
			agg.kind = n.kind;
		if (n.preview != null && n.preview.length > 0)
			agg.preview = cleanId(n.preview);
		mergeTried(agg, n.tried);
		mergeNames(agg, n.namesTried);
		agg.t = stamp();
		agg.pending++;
		dirty = true;
		lastLabel = n.key + " " + method + (step.length > 0 ? "/" + step : "") + " n=" + Std.string(agg.hits);
		lastJson = rowJson(agg, agg.hits);
		// JSONL is flushed from tick() as pending deltas — never append per observe.
	}

	/** Get-or-create the agg row for a fully-cleaned identity. Does not count a hit. */
	static function resolveAgg(key:String, method:String, step:String, nameWon:String, hook:String):LedgerAgg {
		// Keep full identity so no status/phase row is dropped. Long lists OK.
		var aggKey = key + "|" + method + "|" + step + "|" + nameWon + "|" + hook;
		var agg = aggs.get(aggKey);
		if (agg != null)
			return agg;
		agg = new LedgerAgg();
		agg.key = key;
		agg.method = method;
		agg.step = step;
		agg.nameWon = nameWon;
		agg.hook = hook;
		var def = ResolutionCatalog.get(key);
		if (def != null) {
			agg.feature = def.feature;
			agg.element = def.element;
			agg.reason = def.reason;
			agg.importance = def.importance;
		} else {
			agg.feature = "";
			agg.element = "";
			agg.reason = "uncataloged";
			agg.importance = "P4";
		}
		aggs.set(aggKey, agg);
		order.push(aggKey);
		return agg;
	}

	/**
	 * Latch the agg row for a fixed emit site so the hot path can skip the five-part key
	 * concat and the two cleanId() calls that `touch` pays on every single call.
	 *
	 * Returns false while unarmed or before the row exists, which also lets callers skip
	 * building their preview string. Re-resolves itself after clearSession().
	 */
	public static function bind(b:LedgerBinding, key:String, method:String, src:String, nameWon:String,
			step:String = "", hook:String = ""):Bool {
		if (b == null || !armed() || key == null || key.length == 0)
			return false;
		if (b.agg != null && b.gen == sessionGen)
			return true;
		ensure();
		var agg = resolveAgg(key, method != null ? method : "", step != null ? step : "", cleanId(nameWon),
			hook != null ? hook : "");
		if (src != null && src.length > 0)
			agg.src = src;
		b.agg = agg;
		b.gen = sessionGen;
		b.preview = "";
		return true;
	}

	/** Hot path for a bound row: count the hit, and only re-store a preview that moved. */
	public static function bump(b:LedgerBinding, preview:String):Void {
		if (b == null || b.agg == null || b.gen != sessionGen || !armed())
			return;
		var agg = b.agg;
		agg.hits++;
		agg.pending++;
		if (preview != null && preview.length > 0 && preview != b.preview) {
			b.preview = preview;
			agg.preview = preview;
		}
		agg.t = stamp();
		dirty = true;
	}

	/**
	 * Hot-path record: increment an existing winner without allocating ResolutionNote.
	 * First sighting still goes through commit via a tiny note.
	 */
	public static function touch(key:String, method:String, src:String, nameWon:String, kind:String, preview:String, step:String = "", hook:String = ""):Void {
		if (!armed() || key == null || key.length == 0)
			return;
		ensure();
		var st = step != null ? step : "";
		var hk = hook != null ? hook : "";
		var nm = cleanId(nameWon);
		var meth = method != null ? method : "";
		var prev = cleanId(preview);
		var aggKey = key + "|" + meth + "|" + st + "|" + nm + "|" + hk;
		var agg = aggs.get(aggKey);
		if (agg != null) {
			agg.hits++;
			agg.pending++;
			if (prev != null && prev.length > 0)
				agg.preview = prev;
			if (src != null && src.length > 0)
				agg.src = src;
			if (st.length > 0)
				agg.step = st;
			if (hk.length > 0)
				agg.hook = hk;
		agg.t = stamp();
			dirty = true;
			return;
		}
		var n = new ResolutionNote();
		n.key = key;
		n.method = method;
		n.src = src != null ? src : "";
		n.nameWon = nm;
		n.step = st;
		n.hook = hk;
		n.kind = kind != null ? kind : "";
		n.preview = prev;
		commit(n);
	}

	/**
	 * Status lifecycle trampoline: one row per (status.hook, phase, statusId).
	 * Hits increment and preview updates in place.
	 */
	public static function recordStatusHook(phase:String, statusId:String, previewValue:Dynamic, stepTag:String = "", hookPath:String = ""):Void {
		if (!armed())
			return;
		var id = cleanId(statusId);
		if (id.length == 0)
			id = "unknownStatus";
		var meth = phase != null && phase.length > 0 ? phase : "postfix:unknown";
		var preview = previewOf(previewValue, id);
		touch("status.hook", meth, "StatusObserveHooks", id, "string", preview, stepTag != null ? stepTag : "", hookPath != null ? hookPath : "");
	}

	/** Preview without Std.string-first (Bytes → {bytes…} dumps). */
	static function previewOf(previewValue:Dynamic, fallback:String):String {
		if (previewValue == null)
			return fallback;
		var cleaned = cleanId(previewValue);
		if (cleaned.length > 0)
			return cleaned;
		if (Std.isOfType(previewValue, Int) || Std.isOfType(previewValue, Float) || Std.isOfType(previewValue, Bool))
			return Std.string(previewValue);
		return fallback;
	}

	/** Decode HL String / Bytes dumps into a stable Haxe id for keys + ImGui. Never returns {bytes…}. */
	public static function cleanId(raw:Dynamic):String {
		if (raw == null)
			return "";
		// Opaque HL String: UCS-2 char-code copy (not fromUTF8).
		if (Std.isOfType(raw, String)) {
			var s:String = cast raw;
			if (s.length == 0)
				return "";
			var mat = "";
			try
				mat = solarflare.ui.ByteUtil.materialize(s)
			catch (_:Dynamic)
				mat = "";
			mat = StringTools.trim(mat);
			if (mat.length > 0 && !isDumpId(mat))
				return mat;
		}
		// Raw hl.Bytes / dump objects via Geaux coerce.
		var coerced = solarflare.geaux.GeauxCache.coerceSkillId(raw);
		coerced = StringTools.trim(coerced);
		if (coerced.length > 0 && !isDumpId(coerced))
			return coerced;
		return "";
	}

	static function isDumpId(s:String):Bool {
		if (s == null || s.length == 0)
			return true;
		if (s.indexOf("{") >= 0 || s.indexOf("}") >= 0)
			return true;
		var low = s.toLowerCase();
		return low.indexOf("bytes") >= 0;
	}

	public static function rowsForDraw():Array<LedgerAgg> {
		var out:Array<LedgerAgg> = [];
		var i = 0;
		while (i < order.length) {
			var a = aggs.get(order[i]);
			if (a != null)
				out.push(a);
			i++;
		}
		return out;
	}

	public static function fieldStep(obj:Dynamic, name:String):String {
		if (!armed() || obj == null || name == null)
			return "miss";
		try {
			var hit:ProbeHit = FieldWalk.probeNamed(obj, name);
			if (hit != null && hit.step != null)
				return hit.step;
		} catch (_:Dynamic) {
			return "throw";
		}
		return "miss";
	}

	public static function clip(s:String, n:Int):String {
		if (s == null)
			return "";
		s = solarflare.ui.ByteUtil.materialize(s);
		if (s.length <= n)
			return s;
		return s.substr(0, n);
	}

	static function mergeTried(agg:LedgerAgg, tried:Array<Dynamic>):Void {
		if (tried == null)
			return;
		var i = 0;
		while (i < tried.length) {
			var t:Dynamic = tried[i];
			var m = "";
			var nm = "";
			try
				m = t.method
			catch (_:Dynamic) {}
			try
				nm = t.name
			catch (_:Dynamic) {}
			var token = m + ":" + nm;
			if (token != ":" && !agg.triedSeen.exists(token)) {
				agg.triedSeen.set(token, true);
				agg.tried.push({method: m, name: nm});
			}
			i++;
		}
	}

	static function mergeNames(agg:LedgerAgg, names:Array<String>):Void {
		if (names == null)
			return;
		var i = 0;
		while (i < names.length) {
			var nm = names[i];
			if (nm != null && nm.length > 0 && agg.namesTried.indexOf(nm) < 0)
				agg.namesTried.push(nm);
			i++;
		}
	}

	static function rowJson(agg:LedgerAgg, hitCount:Int):String {
		return haxe.Json.stringify({
			type: "resolution-ledger",
			event: "hit",
			v: 1,
			key: agg.key,
			feature: agg.feature,
			element: agg.element,
			reason: agg.reason,
			importance: agg.importance,
			method: agg.method,
			step: agg.step,
			nameWon: safeStr(agg.nameWon),
			namesTried: safeStrArr(agg.namesTried),
			tried: safeTried(agg.tried),
			hook: safeStr(agg.hook),
			payload: {type: safeStr(agg.payloadType), role: safeStr(agg.payloadRole)},
			args: safeStrArr(agg.args),
			kind: agg.kind,
			preview: safeStr(agg.preview),
			src: safeStr(agg.src),
			// Math.round returns Int on HL and overflowed long monotonic uptimes.
			t: Math.floor(agg.t * 100.0 + 0.5) / 100.0,
			hits: hitCount
		});
	}

	static function safeStr(s:String):String {
		return solarflare.ui.ByteUtil.materialize(s);
	}

	static function safeStrArr(arr:Array<String>):Array<String> {
		if (arr == null || arr.length == 0)
			return [];
		var out:Array<String> = [];
		var i = 0;
		while (i < arr.length) {
			out.push(safeStr(arr[i]));
			i++;
		}
		return out;
	}

	static function safeTried(tried:Array<Dynamic>):Array<Dynamic> {
		if (tried == null || tried.length == 0)
			return [];
		var out:Array<Dynamic> = [];
		var i = 0;
		while (i < tried.length) {
			var t:Dynamic = tried[i];
			var m = "";
			var nm = "";
			try
				m = safeStr(Std.string(t.method))
			catch (_:Dynamic) {}
			try
				nm = safeStr(Std.string(t.name))
			catch (_:Dynamic) {}
			out.push({method: m, name: nm});
			i++;
		}
		return out;
	}

	static function flush():Void {
		if (jsonlPath.length == 0)
			return;
		var i = 0;
		while (i < order.length) {
			var a = aggs.get(order[i]);
			if (a != null && a.pending > 0) {
				buf.push(rowJson(a, a.pending));
				a.pending = 0;
			}
			i++;
		}
		if (buf.length == 0)
			return;
		try {
			var chunk = buf.join("\n") + "\n";
			buf = [];
			var out = File.append(jsonlPath);
			out.writeString(chunk);
			out.close();
			LogRotation.enforce(jsonlPath);
			lastFlush = stamp();
			dirty = false;
		} catch (_:Dynamic) {}
	}

	static function writeSnapshot():Void {
		lastSnapWrite = stamp();
		if (snapPath.length == 0)
			return;
		var rows:Array<Dynamic> = [];
		var i = 0;
		while (i < order.length) {
			var a = aggs.get(order[i]);
			if (a != null) {
				try
					rows.push(haxe.Json.parse(rowJson(a, a.hits)))
				catch (_:Dynamic) {}
			}
			i++;
		}
		try {
			File.saveContent(snapPath, haxe.Json.stringify({
				type: "resolution-ledger",
				event: "summary",
				v: 1,
				at: Date.now().toString(),
				label: lastLabel,
				path: jsonlPath,
				catalog: ResolutionCatalog.toJsonRows(),
				rows: rows
			}));
		} catch (_:Dynamic) {}
	}

	static function ensure():Void {
		if (ready)
			return;
		ready = true;
		ResolutionCatalog.keep();
		jsonlPath = solarflare.ui.SettingsStore.logFile("resolution-ledger.jsonl");
		snapPath = solarflare.ui.SettingsStore.logFile("resolution-ledger.json");
		lastPath = jsonlPath;
	}

	static function stamp():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}
}

@:keep
class LedgerAgg {
	public var key:String = "";
	public var feature:String = "";
	public var element:String = "";
	public var reason:String = "";
	public var importance:String = "";
	public var method:String = "";
	public var step:String = "";
	public var nameWon:String = "";
	public var namesTried:Array<String> = [];
	public var tried:Array<Dynamic> = [];
	public var triedSeen:Map<String, Bool> = new Map();
	public var hook:String = "";
	public var payloadType:String = "";
	public var payloadRole:String = "";
	public var args:Array<String> = [];
	public var kind:String = "";
	public var preview:String = "";
	public var src:String = "";
	public var t:Float = 0;
	public var hits:Int = 0;
	public var pending:Int = 0;

	public function new() {}
}
