package solarflare.combatlog;

import solarflare.combatlog.CombatLogAnalysis.CombatLogSkillStats;

/**
 * Selection state for the Boss Mods browser: which recording is open, what is being looked at, which
 * abilities are ticked for a batch. Deliberately has no aura/config/settings dependencies.
 */
class CombatLogBrowserState {
	public static inline var VIEW_ENEMY:String = "enemy";
	public static inline var VIEW_MINE:String = "mine";
	public static inline var VIEW_DAMAGE:String = "damage";
	public static inline var VIEW_SETS:String = "sets";
	public static var STYLES:Array<String> = ["banner", "countdown", "glow"];

	public var analysis(default, null):CombatLogAnalysis = null;
	public var path(default, null):String = "";
	public var view(default, null):String = VIEW_ENEMY;
	public var enemy(default, null):Null<String> = null;
	/** Key of the ability whose drawer is open ("" when none). */
	public var expanded(default, null):String = "";
	/** Look chosen for batch-created alerts: banner, countdown or glow. */
	public var style(default, null):String = "banner";
	public var filter(default, null):String = "";
	/** Health threshold (percent) offered by the enemy Health alert. */
	public var healthPercent(default, null):Int = 50;
	/** Bumps whenever anything a cached row list depends on changes. */
	public var revision(default, null):Int = 0;
	var picks:Map<String, Bool> = new Map();
	/** The enemy to return to when coming back to the Enemies tab. */
	var lastEnemy:Null<String> = null;

	public function new() {}

	public function accept(document:CombatLogDocument, path:String):Void {
		// Construct first so a failed load cannot replace the previous recording.
		var next = new CombatLogAnalysis(document);
		analysis = next; this.path = path;
		picks = new Map(); expanded = ""; filter = "";
		if (next.enemyList.length > 0) { view = VIEW_ENEMY; enemy = next.enemyList[0].name; lastEnemy = enemy; }
		else { enemy = null; lastEnemy = null; view = next.mySkills.length > 0 ? VIEW_MINE : VIEW_DAMAGE; }
		revision++;
	}

	public function selectEnemy(name:String):Void { view = VIEW_ENEMY; enemy = name; lastEnemy = name; reset(); }
	/** Enemies tab: the enemy last looked at, else the busiest one. */
	public function showEnemies():Void {
		var name = lastEnemy != null ? lastEnemy : analysis != null && analysis.enemyList.length > 0 ? analysis.enemyList[0].name : null;
		view = VIEW_ENEMY; enemy = name; reset();
	}
	public function selectMine():Void { view = VIEW_MINE; enemy = null; reset(); }
	public function selectDamage():Void { view = VIEW_DAMAGE; enemy = null; reset(); }
	public function selectSets():Void { view = VIEW_SETS; enemy = null; reset(); }
	public function setHealthPercent(value:Int):Void {
		var next = value < 5 ? 5 : value > 95 ? 95 : value;
		if (next != healthPercent) { healthPercent = next; revision++; }
	}
	function reset():Void { expanded = ""; filter = ""; revision++; }

	public function toggleExpanded(key:String):Void { expanded = expanded == key ? "" : key; revision++; }
	public function setFilter(value:String):Void { if (value == filter) return; filter = value; revision++; }
	public function setStyle(value:String):Void { if (STYLES.indexOf(value) >= 0 && value != style) { style = value; revision++; } }

	public function isPicked(key:String):Bool return picks.exists(key);
	public function togglePick(key:String):Void { if (picks.exists(key)) picks.remove(key); else picks.set(key, true); revision++; }
	public function pickAll(keys:Array<String>):Void { for (k in keys) picks.set(k, true); revision++; }
	public function clearPicks():Void { picks = new Map(); revision++; }
	public function pickedCount():Int { var n = 0; for (_ in picks.keys()) n++; return n; }

	/** The ticked abilities of the open enemy, in recorded order. */
	public function pickedAbilities():Array<CombatLogSkillStats> {
		if (analysis == null || enemy == null) return [];
		return [for (stats in analysis.abilitiesOf(enemy)) if (picks.exists(stats.key)) stats];
	}

	public function abilities():Array<CombatLogSkillStats> {
		if (analysis == null) return [];
		return view == VIEW_ENEMY && enemy != null ? analysis.abilitiesOf(enemy) : view == VIEW_MINE ? analysis.mySkills : [];
	}
}
