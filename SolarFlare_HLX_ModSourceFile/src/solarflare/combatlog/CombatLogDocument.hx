package solarflare.combatlog;

/** Primitive snapshots only. Consumers treat the document and its arrays as read-only. */
class CombatLogEvent {
	public var row(default, null):Int;
	public var kind(default, null):String;
	public var skill(default, null):String;
	public var label(default, null):String;
	public var source(default, null):String;
	public var target(default, null):String;
	public var sourceRole(default, null):Int;
	public var targetRole(default, null):Int;
	public var amount(default, null):Float;
	public var t(default, null):Float;
	public var ms(default, null):Float;
	public var crit(default, null):Bool;
	public var kill(default, null):Bool;
	/** Target health as a 0..1 fraction at the moment of the event, or -1 when the line did not carry one. */
	public var targetHp(default, null):Float;
	public function new(row:Int, o:Dynamic) {
		this.row = row;
		kind = string(o, "kind"); skill = string(o, "skill"); label = string(o, "skillName");
		source = string(o, "source"); target = string(o, "target");
		sourceRole = role(o, "sourceRole"); targetRole = role(o, "targetRole");
		amount = number(o, "amount"); t = number(o, "t", -1); ms = number(o, "ms", -1);
		crit = flag(o, "crit"); kill = flag(o, "kill");
		targetHp = number(o, "targetHpPct", -1);
		if (kind.length == 0) throw "Missing event kind.";
		// Validate known fields even when they are not used by this browser.
		for (key in ["sourcePlayer", "targetPlayer", "minion", "affinity"]) string(o, key);
		for (key in ["block", "targetHp", "targetMaxHp"]) number(o, key);
		for (key in ["blocked", "physical", "magic", "auto"]) flag(o, key);
	}
	static function string(o:Dynamic, key:String):String {
		if (!Reflect.hasField(o, key)) return "";
		var v:Dynamic = Reflect.field(o, key);
		if (!Std.isOfType(v, String)) throw "Invalid " + key + ": expected text.";
		return StringTools.trim(cast v);
	}
	static function number(o:Dynamic, key:String, fallback:Float = 0):Float {
		if (!Reflect.hasField(o, key)) return fallback;
		var v:Dynamic = Reflect.field(o, key);
		if (!Std.isOfType(v, Int) && !Std.isOfType(v, Float)) throw "Invalid " + key + ": expected a number.";
		var n:Float = v;
		if (!Math.isFinite(n) || n < 0) throw "Invalid " + key + ": expected a finite nonnegative number.";
		return n;
	}
	static function role(o:Dynamic, key:String):Int {
		var n = number(o, key);
		if (n > 3 || Math.floor(n) != n) throw "Invalid " + key + ": unknown role.";
		return Std.int(n);
	}
	static function flag(o:Dynamic, key:String):Bool {
		if (!Reflect.hasField(o, key)) return false;
		var v:Dynamic = Reflect.field(o, key);
		if (!Std.isOfType(v, Bool)) throw "Invalid " + key + ": expected true or false.";
		return cast v;
	}
}

class CombatLogDocument {
	public static inline var MAX_BYTES:Int = 16 * 1024 * 1024;
	public static inline var MAX_EVENTS:Int = 20000;
	public static inline var YOU:Int = 1;
	public static inline var ENEMY:Int = 3;
	public var events(default, null):Array<CombatLogEvent>;
	public var legacy(default, null):Bool;
	public var recordedAt(default, null):String;
	/** Map the recording was made on; empty for older files or when the map was unknown. */
	public var mapId(default, null):String;
	public function new(events:Array<CombatLogEvent>, legacy:Bool, recordedAt:String, mapId:String = "") {
		this.events = events.copy(); this.legacy = legacy; this.recordedAt = recordedAt; this.mapId = mapId == null ? "" : mapId;
	}
	/** Seconds since the first recorded event, or NaN when the clock is unusable (reset, missing, huge). */
	public function elapsed(event:CombatLogEvent):Float {
		var first = events.length > 0 ? events[0] : event;
		var value = event.t >= 0 && first.t >= 0 ? event.t - first.t
			: event.ms >= 0 && first.ms >= 0 ? (event.ms - first.ms) / 1000 : Math.NaN;
		// Clock discontinuity: preserve recording order and never fabricate a time.
		return Math.isFinite(value) && value >= 0 && value <= 214748364.7 ? value : Math.NaN;
	}
	public function time(event:CombatLogEvent):String {
		var secs = elapsed(event);
		if (!Math.isFinite(secs)) return "line " + event.row;
		return clock(secs, true);
	}
	/** "+m:ss" or "+m:ss.t". */
	public static function clock(seconds:Float, tenths:Bool = false):String {
		var ticks = Math.round(seconds * 10);
		var sec = Std.int(ticks / 10);
		return "+" + Std.int(sec / 60) + ":" + (sec % 60 < 10 ? "0" : "") + (sec % 60) + (tenths ? "." + (ticks % 10) : "");
	}
}

private class CombatLogBoundedInput extends haxe.io.Input {
	var source:haxe.io.Input;
	var bytes:Int = 0;
	public function new(source:haxe.io.Input) this.source = source;
	override public function readByte():Int {
		var value = source.readByte();
		if (++bytes > CombatLogDocument.MAX_BYTES) throw "Log exceeds the 16 MiB limit.";
		return value;
	}
	override public function close():Void source.close();
}

/** Incremental JSONL validation. No document is published until EOF succeeds. */
class CombatLogParseJob {
	public var done(default, null):Bool = false;
	public var error(default, null):String = "";
	public var result(default, null):CombatLogDocument = null;
	public var lines(default, null):Int = 0;
	var input:haxe.io.Input;
	var events:Array<CombatLogEvent> = [];
	var header:Bool = false;
	var at:String = "";
	var map:String = "";
	public function new(input:haxe.io.Input) this.input = new CombatLogBoundedInput(input);
	public static function text(raw:String):CombatLogParseJob {
		var data = haxe.io.Bytes.ofString(raw);
		if (data.length > CombatLogDocument.MAX_BYTES) throw "Log exceeds the 16 MiB limit.";
		return new CombatLogParseJob(new haxe.io.BytesInput(data));
	}
	public function step(maxLines:Int = 200):Void {
		if (done) return;
		for (_ in 0...maxLines) {
			var line:String;
			try { line = input.readLine(); }
			catch (_:haxe.io.Eof) {
				if (!header && events.length == 0) fail("The file contains no combat recording.");
				else { result = new CombatLogDocument(events, !header, at, map); finish(); }
				return;
			} catch (e:Dynamic) { fail("Could not read the log: " + Std.string(e)); return; }
			lines++;
			if (lines == 1 && StringTools.startsWith(line, "\uFEFF")) line = line.substr(1);
			line = StringTools.trim(line);
			if (line.length == 0) continue;
			try {
				var o:Dynamic = haxe.Json.parse(line);
				if (o == null || Std.isOfType(o, Array) || !Reflect.isObject(o)) throw "Expected a JSON object.";
				if (o.type == "session") {
					if (header || events.length > 0) throw "Unexpected session header.";
					if (o.v != 1 || !Std.isOfType(o.v, Int)) throw "Unsupported recording version.";
					if (o.mod != "solarflare") throw "This is not a SolarFlare combat log.";
					if (o.at != null && !Std.isOfType(o.at, String)) throw "Invalid session date.";
					header = true; at = o.at != null ? o.at : "";
					if (Std.isOfType(o.map, String)) map = o.map;
				} else if (o.type == "event") {
					if (events.length >= CombatLogDocument.MAX_EVENTS) throw "Log exceeds the 20,000-event limit.";
					events.push(new CombatLogEvent(lines, o));
				} else throw "Expected a session or event row.";
			} catch (e:Dynamic) { fail("Line " + lines + ": " + Std.string(e)); return; }
		}
	}
	public function cancel():Void { events = []; finish(); }
	function fail(message:String):Void { error = message; events = []; finish(); }
	function finish():Void { done = true; try input.close() catch (_:Dynamic) {} }
}
