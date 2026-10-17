package solarflare.combatlog;

import solarflare.combatlog.CombatLogDocument.CombatLogEvent;

class CombatLogSkillStats {
	public var key(default, null):String;
	public var role(default, null):Int;
	public var source(default, null):String;
	public var skill(default, null):String;
	public var label(default, null):String;
	public var casts(default, null):Int = 0;
	public var hits(default, null):Int = 0;
	public var damage(default, null):Float = 0;
	public var largest(default, null):Float = 0;
	public var events(default, null):Array<CombatLogEvent> = [];
	public var examples(default, null):Array<CombatLogEvent> = [];
	/** Elapsed seconds of each cast (finite clocks only), in recorded order. Filled once by the analysis. */
	public var castTimes(default, null):Array<Float> = [];
	/** Seconds from the start of the recording to the first cast, NaN when unknown. */
	public var firstT(default, null):Float = Math.NaN;
	/** Median seconds between consecutive casts, NaN with fewer than two timed casts. */
	public var medianGap(default, null):Float = Math.NaN;
	/** Casting enemy's health fraction (0..1) when this ability first appeared; NaN when unknown. */
	public var firstHp(default, null):Float = Math.NaN;
	public function setFirstHp(value:Float):Void firstHp = value;
	public function new(key:String, event:CombatLogEvent) {
		this.key = key; role = event.sourceRole; source = event.source; skill = event.skill; label = event.label;
	}
	public function add(event:CombatLogEvent):Void {
		events.push(event);
		if (event.kind == "cast") casts++;
		if (event.kind == "hit") { hits++; damage += event.amount; largest = Math.max(largest, event.amount); }
		if (examples.length < 2) examples.push(event);
		if (label.length == 0 && event.label.length > 0) label = event.label;
	}
	/** Derived timing, computed once when the recording is indexed. */
	public function addCastTime(seconds:Float):Void {
		if (Math.isFinite(seconds) && castTimes.length < 400) castTimes.push(seconds);
	}
	public function finishTiming():Void {
		if (castTimes.length == 0) return;
		firstT = castTimes[0];
		if (castTimes.length < 2) return;
		var gaps:Array<Float> = [for (i in 1...castTimes.length) castTimes[i] - castTimes[i - 1]];
		gaps.sort(function(a, b) return a < b ? -1 : a > b ? 1 : 0);
		var mid = Std.int(gaps.length / 2);
		medianGap = gaps.length % 2 == 1 ? gaps[mid] : (gaps[mid - 1] + gaps[mid]) / 2;
	}
}

/** One enemy name in a recording, ranked for the fight list. */
class CombatLogEnemy {
	public var name(default, null):String;
	public var abilities(default, null):Int = 0;
	public var casts(default, null):Int = 0;
	public var firstT(default, null):Float = Math.NaN;
	/** Lowest and highest health fraction seen while this enemy was being hit; NaN when never seen. */
	public var lowestHp(default, null):Float = Math.NaN;
	public var highestHp(default, null):Float = Math.NaN;
	public function new(name:String) this.name = name;
	public function setHealthRange(low:Float, high:Float):Void { lowestHp = low; highestHp = high; }
	public function add(stats:CombatLogSkillStats):Void {
		if (stats.casts <= 0) return;
		abilities++; casts += stats.casts;
		if (Math.isFinite(stats.firstT) && (!Math.isFinite(firstT) || stats.firstT < firstT)) firstT = stats.firstT;
	}
}

/** Indexes refer to frozen event rows; no engine access or presentation state. */
class CombatLogAnalysis {
	public var document(default, null):CombatLogDocument;
	public var enemyCasts(default, null):Array<CombatLogEvent> = [];
	public var mySkills(default, null):Array<CombatLogSkillStats> = [];
	public var damageTaken(default, null):Array<CombatLogEvent> = [];
	var skills:Map<String, CombatLogSkillStats> = new Map();
	var enemyHistories:Map<String, Array<CombatLogEvent>> = new Map();
	var enemySkills:Map<String, Array<CombatLogSkillStats>> = new Map();
	/** Per enemy name: (elapsed seconds, health fraction) of every hit that landed on it. */
	var enemyHealth:Map<String, Array<{t:Float, hp:Float}>> = new Map();
	/** Enemies that cast something, busiest first. */
	public var enemyList(default, null):Array<CombatLogEnemy> = [];
	/** Seconds covered by the recording (0 when no usable clock). */
	public var duration(default, null):Float = 0;
	public function new(document:CombatLogDocument) {
		this.document = document;
		var mySeen:Map<String, Bool> = new Map();
		for (event in document.events) {
			var key = skillKey(event.sourceRole, event.source, event.skill);
			var stats = skills.get(key);
			if (stats == null) {
				stats = new CombatLogSkillStats(key, event); skills.set(key, stats);
				if (event.sourceRole == CombatLogDocument.ENEMY) {
					if (!enemySkills.exists(event.source)) enemySkills.set(event.source, []);
					enemySkills.get(event.source).push(stats);
				}
			}
			stats.add(event);
			if (event.kind == "cast") stats.addCastTime(document.elapsed(event));
			var elapsed = document.elapsed(event);
			if (Math.isFinite(elapsed) && elapsed > duration) duration = elapsed;
			if (event.kind == "cast" && event.sourceRole == CombatLogDocument.ENEMY) {
				enemyCasts.push(event);
				if (!enemyHistories.exists(event.source)) enemyHistories.set(event.source, []);
				enemyHistories.get(event.source).push(event);
			}
			if (event.kind == "cast" && event.sourceRole == CombatLogDocument.YOU && !mySeen.exists(key)) {
				mySeen.set(key, true); mySkills.push(stats);
			}
			if (event.kind == "hit" && event.targetRole == CombatLogDocument.YOU) damageTaken.push(event);
			if (event.kind == "hit" && event.targetRole == CombatLogDocument.ENEMY && event.targetHp >= 0 && Math.isFinite(elapsed)) {
				if (!enemyHealth.exists(event.target)) enemyHealth.set(event.target, []);
				enemyHealth.get(event.target).push({t: elapsed, hp: Math.min(1, event.targetHp)});
			}
		}
		for (stats in skills) stats.finishTiming();
		for (name in enemySkills.keys()) {
			var enemy = new CombatLogEnemy(name);
			var series = enemyHealth.get(name);
			for (stats in enemySkills.get(name)) {
				enemy.add(stats);
				if (series != null && Math.isFinite(stats.firstT)) stats.setFirstHp(healthAt(series, stats.firstT));
			}
			if (series != null && series.length > 0) {
				var low = 1.0;
				var high = 0.0;
				for (point in series) { if (point.hp < low) low = point.hp; if (point.hp > high) high = point.hp; }
				enemy.setHealthRange(low, high);
			}
			if (enemy.casts > 0) enemyList.push(enemy);
		}
		enemyList.sort(function(a, b) return a.casts != b.casts ? b.casts - a.casts : Reflect.compare(a.name, b.name));
	}
	/** Health fraction from the latest hit at or before `t`; the earliest known value when nothing came before. */
	static function healthAt(series:Array<{t:Float, hp:Float}>, t:Float):Float {
		var found = Math.NaN;
		for (point in series) {
			if (point.t <= t) found = point.hp;
			else break;
		}
		return Math.isFinite(found) ? found : series[0].hp;
	}
	/** Abilities this enemy actually cast, in the order they first appeared. Hit-only rows are left out. */
	public function abilitiesOf(enemy:String):Array<CombatLogSkillStats> {
		var out = [for (stats in skillsBy(enemy)) if (stats.casts > 0 && StringTools.trim(stats.skill).length > 0) stats];
		out.sort(function(a, b) {
			var an = Math.isFinite(a.firstT) ? a.firstT : 1e12;
			var bn = Math.isFinite(b.firstT) ? b.firstT : 1e12;
			return an < bn ? -1 : an > bn ? 1 : Reflect.compare(a.key, b.key);
		});
		return out;
	}
	public static function skillKey(role:Int, source:String, skill:String):String
		return haxe.Json.stringify([Std.string(role), role == CombatLogDocument.YOU ? "" : source, skill]);
	public function forEvent(event:CombatLogEvent):CombatLogSkillStats
		return skills.get(skillKey(event.sourceRole, event.source, event.skill));
	public function castsBy(enemy:String):Array<CombatLogEvent> {
		var found = enemyHistories.get(enemy); return found != null ? found : [];
	}
	public function skillsBy(enemy:String):Array<CombatLogSkillStats> {
		var found = enemySkills.get(enemy); return found != null ? found : [];
	}
	public static function label(skill:String, recorded:String, lookup:String->String):String {
		var resolved = lookup != null && skill.length > 0 ? lookup(skill) : "";
		return resolved != null && resolved.length > 0 ? resolved : recorded.length > 0 ? recorded : skill.length > 0 ? skill : "Unknown skill";
	}
}
