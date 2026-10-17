package solarflare.hemorrhage;

import solarflare.hemorrhage.HemorrhageCache.HemorrhageInput;

/** Pure primitive model. These states never depend on window visibility. */
enum abstract HemorrhageRunState(String) from String to String {
	var Idle = "Idle";
	var Armed = "Armed";
	var Recording = "Recording";
	var Draining = "Draining";
	var Complete = "Complete";
	var Interrupted = "Interrupted";
}

class HemorrhageMetrics {
	public var damage:Float = 0;
	public var physicalBleed:Float = 0;
	public var sparkBleed:Float = 0;
	public var physicalHits:Int = 0;
	public var physicalCrits:Int = 0;
	public var magicHits:Int = 0;
	public var magicCrits:Int = 0;
	public var criticalDamage:Float = 0;
	public var bleedTicks:Int = 0;
	public var bleedCrits:Int = 0;
	public var unknown:Int = 0;
	public var events:Int = 0;
	public function new() {}
	public inline function bleed():Float return physicalBleed + sparkBleed;
	public function add(h:HemorrhageInput):Void {
		events++;
		damage += h.amount;
		if (h.skillId == HemorrhageCache.STATUS_ID || h.skillId == HemorrhageCache.SPARK_ID) {
			if (h.skillId == HemorrhageCache.STATUS_ID) physicalBleed += h.amount; else sparkBleed += h.amount;
			bleedTicks++;
			if (h.crit) bleedCrits++;
		} else if (h.isDoTKnown != true) unknown++;
		else if (!h.isDoT) {
			if (h.physical) { physicalHits++; if (h.crit) physicalCrits++; }
			if (h.magic == true) { magicHits++; if (h.crit) magicCrits++; }
			if (h.crit) criticalDamage += h.amount;
		}
	}
}

class HemorrhageAbility {
	public var id:String;
	public var label:String;
	public var metrics = new HemorrhageMetrics();
	public function new(id:String, label:String) { this.id = id; this.label = label; }
}

class HemorrhageRun {
	public static inline var TAIL_SECONDS:Float = 10;
	public var state:HemorrhageRunState = Idle;
	public var id:String = "";
	public var character:String = "";
	public var build:String = "";
	public var notes:String = "";
	public var modBuild:String = "";
	public var gameBuild:String = "";
	public var wallMs:Float = 0;
	public var armedAt:Float = 0;
	public var firstAt:Float = -1;
	public var endAt:Float = -1;
	public var finishAt:Float = -1;
	public var deadline:Float = -1;
	public var elapsed:Float = 0;
	public var attackSeconds:Float = 0;
	public var tailSeconds:Float = 0;
	public var chanceStart:Float = Math.NaN;
	public var chanceMin:Float = Math.NaN;
	public var chanceMax:Float = Math.NaN;
	public var ratingStart:Float = Math.NaN;
	public var ratingMin:Float = Math.NaN;
	public var ratingMax:Float = Math.NaN;
	public var dropped:Int = 0;
	public var reason:String = "";
	public var notice:String = "";
	public var metrics = new HemorrhageMetrics();
	public var abilities:Array<HemorrhageAbility> = [];
	var byAbility:Map<String,HemorrhageAbility> = new Map();
	var lastSequence:Float = 0;
	var dropStart:Int = 0;
	var statsSeeded:Bool = false;
	public function new() {}
	public inline function active():Bool return state == Armed || state == Recording || state == Draining;
	public function start(now:Float, character:String, label:String, notes:String, wallMs:Float, dropped:Int):Void {
		state = Armed; armedAt = now; this.character = character;
		this.build = StringTools.trim(label).substr(0, 80); this.notes = notes.substr(0, 1024);
		this.wallMs = wallMs; id = Std.string(wallMs) + "-" + Std.string(now);
		dropStart = dropped;
	}
	public function stats(chance:Float, rating:Float):Void {
		if (!active()) return;
		if (!statsSeeded) {
			statsSeeded = true;
			chanceStart = Math.isFinite(chance) && chance >= 0 ? chance : Math.NaN;
			ratingStart = Math.isFinite(rating) && rating >= 0 ? rating : Math.NaN;
		}
		if (Math.isFinite(chance) && chance >= 0) {
			if (!Math.isFinite(chanceMin)) chanceMin = chanceMax = chance;
			chanceMin = Math.min(chanceMin, chance); chanceMax = Math.max(chanceMax, chance);
		}
		if (Math.isFinite(rating) && rating >= 0) {
			if (!Math.isFinite(ratingMin)) ratingMin = ratingMax = rating;
			ratingMin = Math.min(ratingMin, rating); ratingMax = Math.max(ratingMax, rating);
		}
	}
	public function consume(h:HemorrhageInput):Bool {
		if (h == null || !Math.isFinite(h.sequence) || h.sequence <= lastSequence) return false;
		lastSequence = h.sequence;
		if (!active() || h.kind != 1 || h.sourceRole != 1 || h.targetRole != 3 || h.minionName != ""
			|| !Math.isFinite(h.amount) || h.amount <= 0 || !Math.isFinite(h.t) || h.t < armedAt) return false;
		if (state == Draining && h.t > deadline) return false;
		if (state == Armed) { firstAt = h.t; state = Recording; }
		var bleed = h.skillId == HemorrhageCache.STATUS_ID || h.skillId == HemorrhageCache.SPARK_ID;
		if (state == Draining && h.t >= finishAt && !bleed && h.isDoTKnown == true && !h.isDoT) {
			state = Recording; finishAt = deadline = -1;
			notice = "Direct hit detected: recording resumed. Stop attacking, then Finish again.";
		}
		metrics.add(h);
		var key = h.skillId == null ? "" : h.skillId;
		var a = byAbility.get(key);
		if (a == null) {
			// Bound unknown/modded skill IDs without losing aggregate damage.
			if (abilities.length >= 255) key = "__other";
			a = byAbility.get(key);
			if (a == null) {
				a = new HemorrhageAbility(key, key == "__other" ? "Other abilities" : (h.skillLabel != "" ? h.skillLabel : key));
				byAbility.set(key, a); abilities.push(a);
			}
		}
		a.metrics.add(h);
		return true;
	}
	public function finish(now:Float):Void {
		if (state == Armed) { state = Idle; return; }
		if (state != Recording) return;
		finishAt = Math.max(firstAt, now); deadline = finishAt + TAIL_SECONDS; state = Draining;
		notice = "Stop attacking while remaining bleed ticks are collected.";
	}
	/** Call after draining queued events; a backlog cannot silently truncate the tail. */
	public function tick(now:Float, dropped:Int, queueEmpty:Bool = true):Void {
		if (!active()) return;
		this.dropped = Std.int(Math.max(0, dropped - dropStart));
		if (state == Draining && now >= deadline && queueEmpty) {
			endAt = deadline; state = Complete; notice = "Test complete.";
		}
		updateDuration(state == Complete ? endAt : now);
	}
	public function interrupt(now:Float, reason:String):Void {
		if (!active()) return;
		if (firstAt < 0) { state = Idle; return; }
		this.reason = reason; endAt = Math.max(firstAt, now); state = Interrupted;
		updateDuration(endAt);
	}
	function updateDuration(now:Float):Void {
		elapsed = firstAt < 0 ? 0 : Math.max(0, now - firstAt);
		attackSeconds = firstAt < 0 ? 0 : Math.max(0, (finishAt >= 0 ? Math.min(now, finishAt) : now) - firstAt);
		tailSeconds = finishAt < 0 ? 0 : Math.max(0, now - finishAt);
	}
	public inline function dps():Float return elapsed > 0 ? metrics.damage / elapsed : Math.NaN;
	public inline function bleedDps():Float return elapsed > 0 ? metrics.bleed() / elapsed : Math.NaN;
	public function quality():String {
		var flags:Array<String> = [];
		if (state == Interrupted) flags.push("Interrupted: " + reason + "; tail may be incomplete");
		if (dropped > 0) flags.push(Std.string(dropped) + " shared events dropped");
		if (metrics.unknown > 0) flags.push(Std.string(metrics.unknown) + " events lack DoT classification");
		if (!Math.isFinite(chanceStart) || !Math.isFinite(ratingStart)) flags.push("Character stats unavailable");
		return flags.length == 0 ? "No collection issues detected" : flags.join(" | ");
	}
}
