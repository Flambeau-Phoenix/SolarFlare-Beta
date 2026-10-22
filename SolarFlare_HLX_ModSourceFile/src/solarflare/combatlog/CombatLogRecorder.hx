package solarflare.combatlog;

import imgui.ref.BoolRef;

/**
 * JSONL combat recording under hlx/mods/solarflare/logs/combatlog/.
 *
 * Recording is passive: it runs whenever `enabled` is true and does not depend on the
 * combat overlay being on screen. Writes are flushed on the recorder's own cadence from
 * `queue`, so a hidden meter or a stalled/crashed frame loop cannot discard queued combat.
 */
class CombatLogRecorder {
	public static inline var IDLE_S:Float = 30;
	/** Opportunistic flush cadence so recording never rides on the draw/observe loop. */
	public static inline var FLUSH_S:Float = 0.5;
	/** In-RAM queue bound when a disk write keeps failing. */
	public static inline var MAX_BYTES:Int = 5 * 1024 * 1024;
	/** Once the clog-*.jsonl files total more than this, the oldest data is pruned. */
	public static inline var PRUNE_ABOVE_BYTES:Int = 15 * 1024 * 1024;
	/** A prune keeps this much of the most recent data (oldest files go first, then the oldest lines of the boundary file). */
	public static inline var PRUNE_KEEP_BYTES:Int = 15 * 1024 * 512;
	/** Appended bytes between folder-size checks, so the folder is not scanned on every flush. */
	static inline var CHECK_EVERY_BYTES:Int = 256 * 1024;

	/** Fresh installs are silent; SettingsStore restores an explicit persisted opt-in. */
	public static var enabled = new BoolRef(false);
	public static var lastPath:String = "";
	public static var lastStatus:String = "record idle";
	public static var written:Int = 0;
	public static var trimmed:Int = 0;

	static var buf:Array<String> = [];
	static var bufBytes:Int = 0;
    static var pending:Array<{transaction:solarflare.util.AppendTransaction,lines:Int}>=[];
    static var pendingBytes=0;
    static var requestedFlush=false;
    static var retryAt=0.0;
    static var storage=new solarflare.util.AppendTransaction.DiskAppendStorage();
	static var sessionPath:String = "";
	static var lastFlushAt:Float = 0;
	static var lastEventAt:Float = 0;
	/** Map the open file belongs to; a known change of map closes it so each file is one map visit. */
	static var sessionMap:String = "";
	/** Header timestamp of the open file, so the header line can be rewritten once the map becomes known. */
	static var sessionAt:String = "";
	/** Bytes appended since the last folder-size check; the check is edge-driven off this counter. */
	static var sinceCheck:Int = 0;

	/**
	 * One switch for every UI that records. Turning it on also captures nearby world activity, because enemy
	 * casts aimed at other players or the ground are otherwise never saved; turning it off only stops recording
	 * and leaves the player's own filter choices alone.
	 */
	public static function setCapture(on:Bool):Void {
        if(solarflare.ModEntry.inDraw) { solarflare.ui.UiActionQueue.custom(function() setCapture(on)); return; }
		if (enabled.get() == on)
			return;
		enabled.set(on);
		if (on) {
			var cfg = CombatLogConfig.live;
			if (cfg != null) {
				cfg.recordWorld.set(true);
				cfg.recordInProximity.set(true);
			}
			newSession();
		} else
			endSession();
	}

	public static function queue(line:CombatLogLine):Void {
		if (!enabled.get() || line == null)
			return;
		// Session creation and disk work are serviced by tick/flush.
		try {
			var json = line.toJson();
			buf.push(json);
			bufBytes += haxe.io.Bytes.ofString(json).length + 1;
		} catch (_:Dynamic) {}
		lastEventAt = stamp();
		// Passive durability: flush on our own cadence. A hidden overlay or a stalled
		// frame loop (modal exception dialog) must never discard queued combat.
		var now = stamp();
		if (bufBytes+pendingBytes >= MAX_BYTES || now - lastFlushAt >= FLUSH_S)
			requestedFlush=true;
		// If the disk write failed we still bound RAM rather than grow forever.
		if (bufBytes+pendingBytes > MAX_BYTES)
			trimBuf();
	}

	public static function tick():Void {
		var now = stamp();
		var map = solarflare.aura.AuraMapContext.mapId;
		if (sessionPath.length > 0 && map.length > 0) {
			if (sessionMap.length == 0) {
				sessionMap = map;
				stampMapOnHeader(map);
			} else if (map != sessionMap)
				endSession();
		}
		if (sessionPath.length > 0 && lastEventAt > 0 && now - lastEventAt >= IDLE_S)
			endSession();
		if (buf.length == 0 && pending.length==0)
			return;
		if (now>=retryAt && (requestedFlush || buf.length >= 24 || now - lastFlushAt >= 0.4))
			flush();
	}

    public static function flush():Void {
        if(solarflare.ModEntry.inDraw) { requestedFlush=true; return; }
        requestedFlush=false;
        if(buf.length>0) {
            ensureSession(false);
            if(sessionPath.length==0) return;
            var bytes=haxe.io.Bytes.ofString(buf.join("\n")+"\n");
            pending.push({transaction:new solarflare.util.AppendTransaction(sessionPath,bytes),lines:buf.length});
            pendingBytes+=bytes.length; buf=[]; bufBytes=0;
        }
        while(pending.length>0) {
            var batch=pending[0];
            if(!batch.transaction.commit(storage)) { lastStatus="record fail: "+batch.transaction.error; retryAt=stamp()+2.0; return; }
            retryAt=0; pending.shift(); pendingBytes-=batch.transaction.bytes.length;
            written+=batch.lines; sinceCheck+=batch.transaction.bytes.length; lastFlushAt=stamp();
        }
        if(sinceCheck>=CHECK_EVERY_BYTES) pruneLogs();
        lastStatus="recording "+written+"  "+fileName()+(trimmed>0 ? "  (trimmed "+trimmed+")" : "");
    }

	/** Bounds in-RAM queue when a disk write fails, so a stuck loop cannot leak. */
    static function trimBuf():Void {
        while(bufBytes+pendingBytes>MAX_BYTES) {
            var discard=-1;
            for(i in 0...pending.length) if(pending[i].transaction.offset<0) { discard=i; break; }
            if(discard>=0) {
                var batch=pending.splice(discard,1)[0]; pendingBytes-=batch.transaction.bytes.length; trimmed+=batch.lines;
            } else if(buf.length>0) {
                var first=buf.shift(); bufBytes-=haxe.io.Bytes.ofString(first).length+1; trimmed++;
            } else break;
        }
    }

	/**
	 * Folder cap: when the clog-*.jsonl files total more than PRUNE_ABOVE_BYTES, delete the oldest files and then
	 * drop the oldest lines of the boundary file (its session header stays) so PRUNE_KEEP_BYTES of the most recent
	 * data remain. The file name carries the timestamp, so name order is age order and the open file is the newest.
	 * Runs at session start and every CHECK_EVERY_BYTES of recording, never per flush.
	 */
	static function pruneLogs():Void {
		sinceCheck = 0;
		try {
			var dir = logDir();
			if (dir == null || !sys.FileSystem.exists(dir))
				return;
			var files:Array<{name:String, size:Int}> = [];
			var total = 0;
			for (name in sys.FileSystem.readDirectory(dir)) {
				if (!StringTools.startsWith(name, "clog-") || !StringTools.endsWith(name, ".jsonl"))
					continue;
				var size = sys.FileSystem.stat(haxe.io.Path.join([dir, name])).size;
				files.push({name: name, size: size});
				total += size;
			}
			if (total <= PRUNE_ABOVE_BYTES)
				return;
			files.sort(function(a, b) return a.name < b.name ? -1 : (a.name > b.name ? 1 : 0));
			var excess = total - PRUNE_KEEP_BYTES;
			for (f in files) {
				if (excess <= 0)
					break;
				var path = haxe.io.Path.join([dir, f.name]);
				var protectedFile=false; for(batch in pending) if(batch.transaction.path==path) protectedFile=true;
				if(protectedFile) continue;
				if (f.size <= excess && path != sessionPath) {
					sys.FileSystem.deleteFile(path);
					excess -= f.size;
				} else {
					trimOldest(path, excess);
					break;
				}
			}
		} catch (_:Dynamic) {}
	}

	/** Drops about `cut` of the oldest bytes of a recording at a line boundary, keeping its session header. */
	static function trimOldest(path:String, cut:Int):Void {
		var content = sys.io.File.getContent(path);
		var nl = content.indexOf("\n");
		var header = nl >= 0 && content.substr(0, nl).indexOf("\"type\":\"session\"") >= 0 ? content.substr(0, nl + 1) : "";
		var body = content.substr(header.length);
		var at = body.indexOf("\n", cut);
		var kept = at >= 0 ? body.substr(at + 1) : "";
		trimmed += body.length - kept.length;
		sys.io.File.saveContent(path, header + kept);
	}

	public static function endSession():Void {
        if(solarflare.ModEntry.inDraw) { solarflare.ui.UiActionQueue.custom(endSession); return; }
		flush();
		if (sessionPath.length == 0)
			return;
		lastStatus = pending.length>0 ? "record fail: pending data retained" : "saved " + fileName() + "  " + written + " events";
		sessionPath = "";
	}

	public static function newSession():Void {
        if(solarflare.ModEntry.inDraw) { solarflare.ui.UiActionQueue.custom(newSession); return; }
		endSession();
		ensureSession(true);
	}

	static function ensureSession(forceNew:Bool):Void {
		if (!forceNew && sessionPath.length > 0)
			return;
		if (forceNew && sessionPath.length > 0)
			endSession();
		var logDir = logDir();
		if (logDir == null)
			return;
		try {
			if (!sys.FileSystem.exists(logDir))
				sys.FileSystem.createDirectory(logDir);
		} catch (_:Dynamic) {}
		var d = Date.now();
		var name = "clog-"
			+ pad(d.getFullYear(), 4) + pad(d.getMonth() + 1, 2) + pad(d.getDate(), 2)
			+ "-" + pad(d.getHours(), 2) + pad(d.getMinutes(), 2) + pad(d.getSeconds(), 2)
			+ ".jsonl";
		sessionPath = haxe.io.Path.join([logDir, name]);
        var collision=1; while(sys.FileSystem.exists(sessionPath)) sessionPath=haxe.io.Path.join([logDir,name.substr(0,name.length-6)+"-"+(collision++)+".jsonl"]);
		lastPath = sessionPath;
		written = 0;
		try {
			sessionMap = solarflare.aura.AuraMapContext.mapId;
			sessionAt = d.toString();
			sys.io.File.saveContent(sessionPath, headerLine(sessionAt, sessionMap) + "\n");
			lastStatus = "recording " + name;
			lastEventAt = stamp();
			pruneLogs();
		} catch (_:Dynamic) {
			sessionPath = "";
			lastStatus = "record fail (create)";
		}
	}

	static function headerLine(at:String, map:String):String {
		return haxe.Json.stringify({
			type: "session",
			v: 1,
			mod: "solarflare",
			at: at,
			map: map
		});
	}

	/**
	 * Recording often starts before the map has been sampled (the first background pass after the switch is turned
	 * on), which left the header without a map. Once the map is known, rewrite the header line of the still-small
	 * open file so the browser can group recordings by map.
	 */
	static function stampMapOnHeader(map:String):Void {
		if (sessionPath.length == 0 || map.length == 0)
			return;
		try {
			flush();
            for(batch in pending) if(batch.transaction.path==sessionPath) return;
			if (!sys.FileSystem.exists(sessionPath))
				return;
			var content = sys.io.File.getContent(sessionPath);
			var nl = content.indexOf("\n");
			if (nl < 0 || content.substr(0, nl).indexOf("\"type\":\"session\"") < 0)
				return;
			sys.io.File.saveContent(sessionPath, headerLine(sessionAt, map) + content.substr(nl));
		} catch (_:Dynamic) {}
	}

	static function logDir():String {
		try {
			solarflare.ui.SettingsStore.migrateCombatLogs();
			return solarflare.ui.SettingsStore.logSubdir("combatlog");
		} catch (_:Dynamic) {
			return null;
		}
	}

	static function fileName():String {
		if (lastPath.length == 0)
			return "";
		return haxe.io.Path.withoutDirectory(lastPath);
	}

	static function pad(n:Int, w:Int):String {
		var s = Std.string(n);
		while (s.length < w)
			s = "0" + s;
		return s;
	}

	static function stamp():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}
}
