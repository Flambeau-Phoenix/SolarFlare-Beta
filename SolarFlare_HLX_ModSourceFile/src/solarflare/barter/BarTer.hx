package solarflare.barter;

import solarflare.aura.ConsumableCache;
import solarflare.aura.AuraStatusCache;
import solarflare.geaux.GeauxCache;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.SettingsStore;

/** Observe owns native reads and population; draw consumes prepared cells only. */
class BarTer {
 public var config:BarTerConfig;
 public var builder:BarTerBuilder;
 var overlay:BarTerOverlay;
 var snapMap:Map<String,Array<BarTerSnap>> = new Map();
 public var lastStatus:String = "";
 var loadout = new BarTerLoadoutState();
 var lastWeaponReadAt:Float = -1;
 var rawWeaponKey:String = "";
 var lastSnapAt:Float = -1;
 var snapshotsDirty:Bool = true;
 var character = "";
 var identityGeneration:Int = -1;
 public var statusChoices:Array<{id:String,label:String,icon:String,active:Bool}> = [];
 var statusChoiceMap:Map<String,{id:String,label:String,icon:String,active:Bool}> = new Map();
 var statusRevision:Int = -1;
 var pendingPopulation = "";
 var replacePopulation = false;
 public var host:solarflare.ui.ConfigPanel = null;

 public function new() { config=new BarTerConfig(); builder=new BarTerBuilder(this); overlay=new BarTerOverlay(); }
 public function demand():Bool return config != null && config.demand();
 public function snapsFor(id:String):Array<BarTerSnap> {
  var a=snapMap.get(id); if (a == null) { a=[]; snapMap.set(id,a); } return a;
 }
 public function refreshSnaps():Void {
  for (i in 0...Std.int(Math.min(config.activeBarCount,config.bars.length))) {
   var b=config.bars[i]; var snaps=snapsFor(b.id); BarTerCache.sampleBar(b,snaps);
   for (j in 0...b.slotCount) BarTerCache.prepareIcons(snaps[j]);
  }
 }
 public function changed():Void {
  loadout.changed(config.bars,config.weaponLayouts); snapshotsDirty=true;
  SettingsStore.markDirty(); solarflare.ObserveDemand.markStatusDemandDirty();
 }
 public function reserve(id:String,index:Int):Void { config.weaponLayouts.reserve(id,index); }
 public function requestPopulation(id:String,replace:Bool=false):Void {
  pendingPopulation=id; replacePopulation=replace; lastStatus="Waiting for the current native skills…";
 }
 public function clearCell(b:BarTerBarConfig,index:Int):Void {
  if (b == null || index < 0 || index >= b.slotCount) return;
  builder.recordChange(); reserve(b.id,index); b.slots[index].clearContent(); changed();
 }
 public function clearBar(b:BarTerBarConfig):Void {
  if (b == null) return;
  builder.recordChange();
  for (i in 0...b.slotCount) { reserve(b.id,i); b.slots[i].clearContent(); }
  changed(); lastStatus="Cleared "+b.name+". Undo restores it.";
 }
 public function needsActionBarSeed():Bool return config != null && (config.demand() || config.open.get() || pendingPopulation.length > 0);
 public function clearTransientState():Void {
  pendingPopulation=""; replacePopulation=false; BarTerCache.pendingClicks.resize(0);
  loadout.resetCandidate(); lastStatus=""; snapshotsDirty=true; if (builder != null) builder.clearTransientState();
 }
 public function observe():Void {
  var next=solarflare.HealthCache.characterId;
  if (next != character || identityGeneration != solarflare.HealthCache.identityGen) {
   clearTransientState(); builder.history.clear(); character=next; loadout.reset(); BarTerNativeKeys.reset(); rawWeaponKey=""; lastWeaponReadAt=-1;
   identityGeneration=solarflare.HealthCache.identityGen; statusChoices.resize(0); statusChoiceMap.clear(); statusRevision=-1;
   GeauxCache.actionBarLoadoutKey=""; GeauxCache.actionBarCharacterId="";
   GeauxCache.invalidateBarRoots();
  }
  if (!config.enabled.get() && !config.open.get()) return;
  var hero:Dynamic=solarflare.HealthCache.localHero;
  var now=haxe.Timer.stamp();
  observeStatusChoices();
  if (BarTerCache.hasAnyItem(config) || config.open.get()) try ConsumableCache.sample(hero,now) catch (_:Dynamic) {}
  if (now-lastWeaponReadAt >= 0.1) { rawWeaponKey=BarTerCache.weaponLoadoutKey(hero); lastWeaponReadAt=now; }
  var raw=rawWeaponKey;
  var coherent=raw.length > 0 && character.length > 0 && GeauxCache.actionBarLoadoutKey == raw && GeauxCache.actionBarCharacterId == character;
  // Identity/loadout completeness gates persistence, never live skill telemetry.
  BarTerNativeKeys.sample(now);
  if (coherent) {
   reconcileLoadout(character+"|"+raw,now);
   migrateAndFollowNativeSkills();
  }
  // A deliberate editor command needs current skills, not a settled persistence key.
  if (hero != null && pendingPopulation.length > 0) {
   BarTerNativeKeys.sample(now,true);
   populateRequestedBar();
  }
  if (snapshotsDirty || now-lastSnapAt >= 0.05) { refreshSnaps(); snapshotsDirty=false; lastSnapAt=now; }
  BarTerCache.drainClicks(function(c) {
   var b=config.find(c.barId);
   if (hero == null || !config.enabled.get() || !config.isActive(c.barId) || b == null || !b.enabled || b.hidden || config.hidden.get()
    || c.slot < 0 || c.slot >= b.slotCount) return;
   var slot = b.slots[c.slot];
   if (c.itemKind.length > 0 && slot.hasItem() && slot.itemKind == c.itemKind) {
    var outcome=BarTerCache.useItem(c.itemKind,c.gen,hero); lastStatus=outcome.message;
    var snaps=snapsFor(c.barId); if (c.slot < snaps.length) snaps[c.slot].flashUntil=now+0.3;
    } else if (c.skillId.length > 0 && slot.hasSkill() && slot.skillId == c.skillId) {
    var outcome=BarTerCache.useSkill(c.skillId,slot.nativeActionId,hero); lastStatus=outcome.message;
     var snaps=snapsFor(c.barId); if (outcome.success && c.slot < snaps.length) snaps[c.slot].flashUntil=now+0.3;
   }
  });
 }
 function reconcileLoadout(key:String,now:Float):Void {
  if (!BarTerNativeKeys.known) return;
  var revision=loadout.revision;
  if (!loadout.reconcile(key,BarTerNativeKeys.skills,GeauxCache.actionBarGeneration,now,config.bars,config.weaponLayouts,config.autoSeedOnWeaponSwap.get())) return;
  if (revision != loadout.revision) changed();
 }
 function migrateAndFollowNativeSkills():Void {
  var edited=false;
  if (config.migrateNativeActions) {
   var unresolved=false;
   var migrated=false;
   // Legacy skills acquire provenance only from an exact match in the observed native actions.
   for (b in config.activeBars()) for (slot in b.slots) if (slot.hasSkill() && slot.nativeActionId.length == 0) {
    var s=BarTerNativeKeys.find(slot.skillId);
    if (s != null && s.action.length > 0) { slot.nativeActionId=s.action; migrated=true; }
    else if (s != null) unresolved=true;
   }
   if (migrated || config.migrateNativeActions != unresolved) { config.migrateNativeActions=unresolved; edited=true; }
  }
  if (config.autoSeedOnWeaponSwap.get()) {
   // Skill replacements within the same weapon use the action's existing destination.
   for (b in config.bars) for (slot in b.slots) if (slot.nativeActionId.length > 0) {
    var s=BarTerNativeKeys.action(slot.nativeActionId);
    if (s != null && slot.skillId != s.id) { slot.assignSkill(s.id); slot.nativeActionId=s.action; edited=true; }
   }
  }
  if (edited) {
   // Immediate telemetry updates must not overwrite the destination weapon's
   // saved arrangement before its stabilized restoration has run.
   if (loadout.currentKey.length > 0 && loadout.currentKey == loadout.observedKey) changed();
   else { snapshotsDirty=true; SettingsStore.markDirty(); solarflare.ObserveDemand.markStatusDemandDirty(); }
  }
 }
 function populateRequestedBar():Void {
  if (BarTerNativeKeys.skills.length == 0) return;
  if (pendingPopulation.length > 0) {
   var b=config.find(pendingPopulation); pendingPopulation="";
   if (b != null && config.isActive(b.id)) {
    var before=dump();
    if (replacePopulation) for (i in 0...b.slotCount) if (b.slots[i].hasSkill()) reserve(b.id,i);
    var wrote=replacePopulation ? BarTerWeaponLayouts.replaceSkills(b,BarTerNativeKeys.skills,config.activeBars())
     : BarTerWeaponLayouts.populate(b,BarTerNativeKeys.skills,config.activeBars());
    lastStatus=wrote > 0 ? "Added "+wrote+" native skill(s)." : "No new skills fit. Right-click a cell to clear it or replace this bar's skills.";
    if (wrote > 0 || replacePopulation) { builder.history.push(before); changed(); }
   }
   replacePopulation=false;
  }
 }
 function observeStatusChoices():Void {
  if (statusRevision == AuraStatusCache.revision || !AuraStatusCache.isCurrent(solarflare.HealthCache.localHero)) return;
  statusRevision=AuraStatusCache.revision;
  for (choice in statusChoices) choice.active=false;
  for (i in 0...AuraStatusCache.count) {
   var s=AuraStatusCache.snaps[i]; if (s == null || !s.known || !s.present || s.id.length == 0) continue;
   var choice=statusChoiceMap.get(s.id);
   if (choice == null) {
    if (statusChoices.length >= 2048) continue;
    choice={id:s.id,label:s.id,icon:s.id,active:true};
    statusChoices.push(choice); statusChoiceMap.set(s.id,choice);
   }
   choice.active=true;
   var label=solarflare.cdb.AuraCatalog.label(s.id); choice.label=label.length > 0 ? label : s.id;
   for (alias in s.ids) {
    solarflare.ui.GameIcons.get(alias);
    if (label.length == 0) { var aliasLabel=solarflare.cdb.AuraCatalog.label(alias); if (aliasLabel.length > 0) { label=aliasLabel; choice.label=label; } }
    if (solarflare.ui.GameIcons.hasKey(alias)) { choice.icon=alias; break; }
   }
  }
 }
 public function draw():Void {
  if (!config.enabled.get() || config.hidden.get()) return;
  for (i in 0...Std.int(Math.min(config.activeBarCount,config.bars.length))) {
   var b=config.bars[i]; if (!b.enabled || b.hidden) continue;
   var chrome=config.chromeFor(b.id); chrome.locked.set(b.locked); chrome.transparent.set(b.transparent);
   chrome.itemContextMenus=true;
   overlay.draw(b,snapsFor(b.id),chrome,function() { config.open.set(true); builder.selectBar(b); },
    function() { b.hidden=true; changed(); },function(index) {
     var s=b.slots[index]; if (s.hasItem()) BarTerCache.queueClick(b.id,index,"",s.itemKind); else if (s.hasSkill()) BarTerCache.queueClick(b.id,index,s.skillId,"");
    },config.showHotkeys.get(),function(index) { builder.drawCellContext(b,index,"hud"); },function() { builder.drawBarMenu(b); });
   if (chrome.locked.get() != b.locked || chrome.transparent.get() != b.transparent) {
    b.locked=chrome.locked.get(); b.transparent=chrome.transparent.get(); changed();
   }
  }
 }
 public function drawBuilder():Void builder.draw();
 public function dump():Dynamic return config.dump();
 public function restoreEditorState(data:Dynamic):Void {
  clearTransientState(); config.apply(data); snapMap.clear(); loadout.reset(); changed();
 }
 public function apply(data:Dynamic):Void {
  clearTransientState(); builder.history.clear(); config.apply(data);
  loadout.reset(); character=""; BarTerNativeKeys.reset(); snapMap.clear(); rawWeaponKey=""; lastWeaponReadAt=-1;
  solarflare.ObserveDemand.markStatusDemandDirty();
 }
}
