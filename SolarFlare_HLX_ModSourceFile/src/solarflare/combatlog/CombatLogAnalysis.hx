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
			if (event.kind == "cast" && event.sourceRole == CombatLogDocument.ENEMY) {
				enemyCasts.push(event);
				if (!enemyHistories.exists(event.source)) enemyHistories.set(event.source, []);
				enemyHistories.get(event.source).push(event);
			}
			if (event.kind == "cast" && event.sourceRole == CombatLogDocument.YOU && !mySeen.exists(key)) {
				mySeen.set(key, true); mySkills.push(stats);
			}
			if (event.kind == "hit" && event.targetRole == CombatLogDocument.YOU) damageTaken.push(event);
		}
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
