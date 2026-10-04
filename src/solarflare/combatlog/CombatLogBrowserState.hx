package solarflare.combatlog;

import solarflare.combatlog.CombatLogDocument.CombatLogEvent;
import solarflare.combatlog.CombatLogAnalysis.CombatLogSkillStats;

/** Session navigation only; deliberately has no aura/config/settings dependencies. */
class CombatLogBrowserState {
	public var analysis(default, null):CombatLogAnalysis = null;
	public var path(default, null):String = "";
	public var page(default, null):String = "files";
	public var tab(default, null):String = "Enemies";
	public var enemy(default, null):Null<String> = null;
	public var skill(default, null):CombatLogSkillStats = null;
	public var hit(default, null):CombatLogEvent = null;
	public var showMore:Bool = false;
	public var filters:Map<String, String> = new Map();
	public var scroll:Map<String, Float> = new Map();
	var selections:Map<String, Int> = new Map();
	public var revision(default, null):Int = 0;
	public function new() {}
	public function accept(document:CombatLogDocument, path:String):Void {
		// Construct first so a failed load cannot replace the previous recording.
		var next = new CombatLogAnalysis(document);
		analysis = next; this.path = path; page = "recording"; tab = "Enemies";
		enemy = null; skill = null; hit = null; showMore = false;
		filters = new Map(); scroll = new Map(); selections = new Map(); revision++;
	}
	public function files():Void { page = "files"; revision++; }
	public function recording():Void { if (analysis != null) { page = "recording"; enemy = null; skill = null; hit = null; revision++; } }
	public function setTab(value:String):Void {
		if (["Enemies", "Me", "Damage taken"].indexOf(value) < 0 || tab == value) return;
		tab = value; enemy = null; skill = null; hit = null; revision++;
	}
	public function selectEnemy(name:String):Void { enemy = name; skill = null; hit = null; page = "enemy"; revision++; }
	public function selectSkill(stats:CombatLogSkillStats):Void {
		if (page == "recording") { enemy = null; hit = null; }
		if (page == "enemy") hit = null;
		skill = stats; page = "skill"; showMore = false; revision++;
	}
	public function selectHit(event:CombatLogEvent):Void { enemy = null; hit = event; skill = analysis.forEvent(event); page = "damage"; showMore = false; revision++; }
	public function back():Void {
		if (page == "skill" && hit != null) page = "damage";
		else if ((page == "skill" || page == "damage") && enemy != null) page = "enemy";
		else if (page == "enemy" || page == "skill" || page == "damage") page = "recording";
		else page = "files";
		revision++;
	}
	public function key():String {
		return haxe.Json.stringify([page, tab, page == "enemy" ? enemy : page == "skill" && skill != null ? skill.key
			: page == "damage" && hit != null ? Std.string(hit.row) : ""]);
	}
	public function filter():String { var value = filters.get(key()); return value != null ? value : ""; }
	public function setFilter(value:String):Void { filters.set(key(), value); revision++; }
	public function selectRow(row:Int):Void selections.set(key(), row);
	public function rowSelected(row:Int):Bool return selections.exists(key()) && selections.get(key()) == row;
	public function eventRows():Array<CombatLogEvent> {
		if (analysis == null) return [];
		return switch (page) {
			case "enemy": analysis.castsBy(enemy);
			case "skill": skill != null ? skill.events : [];
			case "damage": hit != null ? [hit] : [];
			default: tab == "Enemies" ? analysis.enemyCasts : tab == "Damage taken" ? analysis.damageTaken : [];
		};
	}
	public function skillRows():Array<CombatLogSkillStats> {
		if (analysis == null) return [];
		return page == "enemy" ? analysis.skillsBy(enemy) : page == "recording" && tab == "Me" ? analysis.mySkills : [];
	}
}
