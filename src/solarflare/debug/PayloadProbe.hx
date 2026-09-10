package solarflare.debug;

import solarflare.FieldWalk;
import solarflare.HealthCache;
import solarflare.ProbeHit;
import imgui.ref.BoolRef;
import sys.io.File;

/**
 * Opt-in FieldWalk probe. Session-only. Classify live postfix/observe objects
 * by fixed GameLib name packs. Never Std.string on Dynamic; never Reflect.fields.
 */
@:keep
class PayloadProbe {
	public static var enabled = new BoolRef(false);
	/** Write JSONL / snapshots. Session-only; defaults off. Separate from panel open. */
	public static var recording = new BoolRef(false);
	public static var lastPath:String = "";
	public static var lastLabel:String = "payload-probe idle";
	public static var lastJson:String = "{}";
	/** Session-only last skill.instantReady observation. */
	public static var lastInstantSkillId:String = "";
	public static var lastInstantKnown:Bool = false;
	public static var lastInstantReady:Bool = false;
	public static var lastInstantAt:Float = 0;

	static inline var RING:Int = 12;
	static inline var MIN_GAP:Float = 0.125;
	static inline var SPINE_GAP:Float = 0.5;

	static var dmgNames:Array<String> = [
		"amount", "critical", "kill", "block", "skillId", "stepId", "baseSkill", "source", "target",
		"serverSource", "ctx", "sourceUnit", "targetUnit"
	];
	static var skillNames:Array<String> = [
		"kind", "script", "inf", "owner", "parent",
		"getCooldownLeft", "getEffectiveCooldown", "getCooldownProgress", "isInCooldown"
	];
	static var skillInfNames:Array<String> = ["id", "script"];
	static var statusNames:Array<String> = [
		"duration", "durationLeft", "remaining", "timeLeft", "elapsed", "cdUntil", "progress",
		"getElapsedTime", "getDurationLeft", "getDurationProgress", "getBaseDuration", "evalDuration",
		"stacks", "kind"
	];
	/** Conservative ChatBox.receiveMessage virtual pack — no Channel enum indexes. */
	static var chatNames:Array<String> = [
		"text", "message", "msg", "content", "name", "playerName", "author", "from", "sender",
		"cid", "uid", "id", "channel", "chan", "channelName", "kind", "type", "whisper",
		"player", "receiver", "target", "to"
	];
	static var unitNames:Array<String> = [
		"health", "maxHealth", "name", "kind", "isMe", "player", "targetUnit",
		"summonOwner", "summonSourceSkill", "get_networkPropSummonOwner"
	];
	static var spineNames:Array<String> = ["me", "hero", "layer", "world", "gui", "connectionInfo"];
	static var configNames:Array<String> = ["mapId", "activityID", "difficulty"];

	static var snaps:Array<PayloadSnap> = [];
	static var writeAt:Int = 0;
	static var count:Int = 0;
	static var lastCombat:Float = 0;
	static var lastChat:Float = 0;
	static var lastSpine:Float = 0;
	static var lastStatus:Float = 0;
	static var jsonlPath:String = "";
	static var snapPath:String = "";
	static var buf:Array<String> = [];
	static var lastFlush:Float = 0;
	static var lastSnapWrite:Float = 0;
	static var ready:Bool = false;

	public static function keep():Void {
		ensure();
	}

	@:hlx.postfix(ui.hud.ChatBox.receiveMessage)
	static function onChatBoxReceive(
		self:ui.hud.ChatBox,
		a0:{
			args:Dynamic,
			channel:st.Channel,
			localStamp:Null<Float>,
			localTextId:String,
			notify:String,
			sender:ent.Unit,
			text:String
		},
		result:Void
	):Void {
		try
			captureChat(a0)
		catch (_:Dynamic) {}
	}

	public static function armed():Bool {
		return recording != null && recording.get();
	}

	public static function startRecording():Void {
		recording.set(true);
		lastLabel = "payload-probe recording";
	}

	public static function stopRecording():Void {
		if (!armed())
			return;
		recording.set(false);
		flush();
		writeSnapshot();
		lastLabel = "payload-probe stopped";
	}

	public static function clearSession():Void {
		snaps = [];
		writeAt = 0;
		count = 0;
		buf = [];
		lastJson = "{}";
		lastInstantSkillId = "";
		lastInstantKnown = false;
		lastInstantReady = false;
		lastLabel = armed() ? "payload-probe recording (cleared)" : "payload-probe idle";
	}

	public static function capture(src:String, obj:Dynamic):Void {
		if (!armed())
			return;
		var now = stamp();
		if (now - lastCombat < MIN_GAP)
			return;
		lastCombat = now;
		var pack = src == "cast" ? "Skill" : "DamageResult";
		var names = src == "cast" ? skillNames : dmgNames;
		var rows = probeObj(obj, names);
		if (src == "cast") {
			var inf = FieldWalk.extractObject(obj, "inf");
			if (inf != null) {
				var extra = probeObj(inf, skillInfNames);
				var j = 0;
				while (j < extra.length) {
					var r = extra[j];
					r.name = "inf." + r.name;
					rows.push(r);
					j++;
				}
			}
		} else {
			// Hit path: nest source / ctx.owner so bee summonOwner shows in probe JSONL.
			nestUnit(rows, obj, "source");
			nestUnit(rows, obj, "serverSource");
			nestUnit(rows, obj, "target");
			var ctx = FieldWalk.extractObject(obj, "ctx");
			if (ctx != null)
				nestUnit(rows, ctx, "owner", "ctx.owner");
			var base = FieldWalk.extractObject(obj, "baseSkill");
			if (base != null) {
				var own = FieldWalk.extractObject(base, "owner");
				if (own != null)
					nestUnitDirect(rows, own, "baseSkill.owner");
			}
		}
		pushSnap(src, pack, rows, now);
	}

	static function nestUnit(rows:Array<ProbeRow>, parent:Dynamic, field:String, ?prefix:String):Void {
		var child = FieldWalk.extractObject(parent, field);
		if (child == null)
			return;
		nestUnitDirect(rows, child, prefix != null ? prefix : field);
	}

	static function nestUnitDirect(rows:Array<ProbeRow>, unit:Dynamic, prefix:String):Void {
		if (unit == null || rows == null)
			return;
		var extra = probeObj(unit, unitNames);
		var j = 0;
		while (j < extra.length) {
			var r = extra[j];
			r.name = prefix + "." + r.name;
			rows.push(r);
			j++;
		}
		var owner = FieldWalk.extractObject(unit, "summonOwner");
		if (owner != null) {
			var ownRows = probeObj(owner, ["name", "kind", "isMe", "health"]);
			var k = 0;
			while (k < ownRows.length) {
				var orow = ownRows[k];
				orow.name = prefix + ".summonOwner." + orow.name;
				rows.push(orow);
				k++;
			}
		}
	}

	public static function captureStatus(obj:Dynamic):Void {
		if (!armed() || obj == null)
			return;
		var now = stamp();
		if (now - lastStatus < SPINE_GAP)
			return;
		lastStatus = now;
		var rows = probeObj(obj, statusNames);
		var inf = FieldWalk.extractObject(obj, "inf");
		if (inf != null) {
			var extra = probeObj(inf, statusNames);
			var j = 0;
			while (j < extra.length) {
				var r = extra[j];
				r.name = "inf." + r.name;
				rows.push(r);
				j++;
			}
		}
		var i = 0;
		while (i < rows.length) {
			var row = rows[i];
			if (row != null && row.usable && row.kind == "number")
				solarflare.SkillRemain.noteExtraName(row.name);
			i++;
		}
		pushSnap("status", "Status", rows, now);
	}

	/** Session-only one-liner for skill.instantReady / shouldPlayInstantly. */
	public static function noteInstant(skillId:String, known:Bool, ready:Bool):Void {
		if (!armed())
			return;
		lastInstantSkillId = skillId != null ? skillId : "";
		lastInstantKnown = known;
		lastInstantReady = ready;
		lastInstantAt = stamp();
	}

	public static function captureChat(obj:Dynamic):Void {
		if (!armed())
			return;
		var now = stamp();
		if (now - lastChat < MIN_GAP)
			return;
		lastChat = now;
		var rows = probeObj(obj, chatNames);
		var nested:Array<String> = ["channel", "chan", "player", "sender", "from", "receiver", "target"];
		var i = 0;
		while (i < nested.length) {
			var child = FieldWalk.extractObject(obj, nested[i]);
			if (child != null) {
				var extra = probeObj(child, ["name", "id", "uid", "cid", "text", "kind", "type"]);
				var j = 0;
				while (j < extra.length) {
					var r = extra[j];
					r.name = nested[i] + "." + r.name;
					rows.push(r);
					j++;
				}
			}
			i++;
		}
		pushSnap("chat", "ChatMessage", rows, now);
	}

	public static function sampleApp(app:GameApp):Void {
		if (!armed() || app == null)
			return;
		var now = stamp();
		if (now - lastSpine < SPINE_GAP)
			return;
		lastSpine = now;
		var rows = probeObj(app, spineNames);
		var cfg = FieldWalk.extractPath(app, ["connectionInfo", "instanceInfo", "config"]);
		if (cfg != null) {
			var extra = probeObj(cfg, configNames);
			var i = 0;
			while (i < extra.length) {
				var r = extra[i];
				r.name = "config." + r.name;
				rows.push(r);
				i++;
			}
		} else {
			var miss = new ProbeRow();
			miss.name = "connectionInfo.instanceInfo.config";
			miss.step = "miss";
			miss.kind = "null";
			miss.preview = "null";
			rows.push(miss);
		}
		var hero = HealthCache.localHero;
		if (hero != null) {
			var unitRows = probeObj(hero, unitNames);
			var j = 0;
			while (j < unitRows.length) {
				var ur = unitRows[j];
				ur.name = "hero." + ur.name;
				rows.push(ur);
				j++;
			}
		}
		pushSnap("spine", "Spine", rows, now);
	}

	public static function tick():Void {
		if (!armed())
			return;
		ensure();
		var now = stamp();
		if (buf.length >= 8 || (buf.length > 0 && now - lastFlush >= 0.5))
			flush();
		if (now - lastSnapWrite >= 2)
			writeSnapshot();
	}

	public static function lastSnap():PayloadSnap {
		if (count <= 0 || snaps.length == 0)
			return null;
		var idx = (writeAt + RING - 1) % RING;
		if (idx >= snaps.length)
			idx = snaps.length - 1;
		return snaps[idx];
	}

	static function probeObj(obj:Dynamic, names:Array<String>):Array<ProbeRow> {
		var out:Array<ProbeRow> = [];
		if (names == null)
			return out;
		if (obj == null) {
			var empty = new ProbeRow();
			empty.name = "(root)";
			empty.step = "miss";
			empty.kind = "null";
			empty.preview = "null";
			out.push(empty);
			return out;
		}
		var i = 0;
		while (i < names.length) {
			out.push(rowOf(obj, names[i]));
			i++;
		}
		return out;
	}

	static function rowOf(obj:Dynamic, name:String):ProbeRow {
		var row = new ProbeRow();
		row.name = name != null ? name : "";
		var hit:ProbeHit = null;
		try
			hit = FieldWalk.probeNamed(obj, name)
		catch (_:Dynamic) {
			row.step = "throw";
			row.kind = "null";
			row.preview = "throw";
			return row;
		}
		if (hit == null) {
			row.step = "miss";
			row.kind = "null";
			row.preview = "null";
			return row;
		}
		row.step = hit.step;
		row.usable = hit.usable;
		classify(hit.value, row);
		hit.value = null;
		return row;
	}

	static function classify(v:Dynamic, row:ProbeRow):Void {
		if (v == null) {
			row.kind = "null";
			row.preview = "null";
			return;
		}
		try {
			if (Reflect.isFunction(v)) {
				row.kind = "fn";
				row.preview = "fn";
				row.usable = false;
				return;
			}
		} catch (_:Dynamic) {}
		try {
			if (Std.isOfType(v, String)) {
				var s:String = v;
				row.kind = "string";
				row.preview = clip(s != null ? StringTools.trim(s) : "", 48);
				return;
			}
		} catch (_:Dynamic) {}
		try {
			if (Std.isOfType(v, Bool)) {
				var b:Bool = v;
				row.kind = "bool";
				row.preview = b ? "true" : "false";
				return;
			}
		} catch (_:Dynamic) {}
		try {
			var f:Float = v;
			if (!Math.isNaN(f) && Math.isFinite(f)) {
				row.kind = "number";
				row.preview = Std.string(Math.round(f * 1000) / 1000);
				return;
			}
		} catch (_:Dynamic) {}
		try {
			var n = FieldWalk.arrayLen(v);
			if (n > 0) {
				row.kind = "array";
				row.preview = "len=" + Std.string(n);
				return;
			}
		} catch (_:Dynamic) {}
		try {
			var _b:Int = untyped v.getUI8(0);
			row.kind = "bytes";
			row.preview = "bytes";
			return;
		} catch (_:Dynamic) {}
		try {
			var keys = FieldWalk.extractObject(v, "keys");
			if (keys != null) {
				row.kind = "mapish";
				row.preview = "obj";
				return;
			}
		} catch (_:Dynamic) {}
		row.kind = "object";
		row.preview = "obj";
	}

	static function pushSnap(src:String, pack:String, rows:Array<ProbeRow>, now:Float):Void {
		ensure();
		var snap = new PayloadSnap();
		snap.src = src;
		snap.pack = pack;
		snap.t = now;
		snap.rows = rows;
		snap.label = src + " " + pack + " n=" + Std.string(rows.length);
		if (snaps.length < RING)
			snaps.push(snap);
		else
			snaps[writeAt] = snap;
		writeAt = (writeAt + 1) % RING;
		if (count < RING)
			count++;
		lastLabel = snap.label;
		lastJson = toJson(snap);
		buf.push(lastJson);
	}

	static function toJson(snap:PayloadSnap):String {
		var rows:Array<Dynamic> = [];
		var i = 0;
		while (i < snap.rows.length) {
			var r = snap.rows[i];
			rows.push({
				name: r.name,
				step: r.step,
				kind: r.kind,
				preview: r.preview,
				usable: r.usable
			});
			i++;
		}
		return haxe.Json.stringify({
			type: "payload-probe",
			v: 1,
			src: snap.src,
			pack: snap.pack,
			t: Math.round(snap.t * 100) / 100,
			rows: rows
		});
	}

	static function flush():Void {
		if (buf.length == 0 || jsonlPath.length == 0)
			return;
		try {
			var chunk = buf.join("\n") + "\n";
			buf = [];
			var out = File.append(jsonlPath);
			out.writeString(chunk);
			out.close();
			lastFlush = stamp();
		} catch (_:Dynamic) {}
	}

	static function writeSnapshot():Void {
		lastSnapWrite = stamp();
		if (snapPath.length == 0)
			return;
		var last = lastSnap();
		try {
			File.saveContent(snapPath, haxe.Json.stringify({
				type: "payload-probe",
				v: 1,
				at: Date.now().toString(),
				label: lastLabel,
				path: jsonlPath,
				last: last != null ? haxe.Json.parse(lastJson) : {}
			}));
		} catch (_:Dynamic) {}
	}

	static function ensure():Void {
		if (ready)
			return;
		ready = true;
		jsonlPath = solarflare.ui.SettingsStore.logFile("payload-probe.jsonl");
		snapPath = solarflare.ui.SettingsStore.logFile("payload-probe.json");
		lastPath = jsonlPath;
	}

	static function clip(s:String, n:Int):String {
		if (s == null)
			return "";
		if (s.length <= n)
			return s;
		return s.substr(0, n);
	}

	static function stamp():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}
}
