package solarflare.aura.ui;

import solarflare.aura.AuraConfig;
import solarflare.aura.AuraQuickBuildDraft;
import solarflare.aura.AuraSetDef;

/** What the Boss Mods browser did with a batch of alerts. */
typedef BossAlertResult = { var made:Int; var skipped:Int; var why:String; var set:String; }

/**
 * Everything the Boss Mods browser may ask of the Aura Builder. The browser reads the library through
 * `bossCfg` and changes nothing except through these calls.
 */
interface BossModsHost {
	function bossCfg():AuraConfig;
	/** Opens Quick Build seeded with this draft (the single-aura path). */
	function bossBuild(draft:AuraQuickBuildDraft):Void;
	/** Creates drafts as one undo step. `setId` empty means no Aura Set; `mapId` non-empty arms that set on the map. */
	function bossCreate(drafts:Array<AuraQuickBuildDraft>, setId:String, mapId:String):BossAlertResult;
	function bossAddSet(name:String):AuraSetDef;
	function bossSetsChanged():Void;
	/** Leaves Boss Mods and selects this aura in the editor. */
	function bossOpenAura(id:String):Void;
}
