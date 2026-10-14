package solarflare.barter;

import solarflare.aura.ConsumableCache;
import solarflare.aura.AuraStatusCache;
import solarflare.geaux.GeauxCache;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.SettingsStore;

/** Observe owns native reads and population; draw consumes prepared cells only. */
class BarTer {
	/** Stable HUD actions; callbacks read current model/configuration at invocation. */
	var hudBar:BarTerBarConfig;
	var hudEditFn:Void->Void;
	var hudHideFn:Void->Void;
	var hudClickFn:Int->Void;
	var hudContextFn:Int->Void;
	var hudMenuFn:Void->Void;

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
 var pendingRepair:Bool=false;
 var pendingNativeCheck:Bool=false;
 public var nativeCheckReport:String="";
 public var nativeCheckSummary:String="";
 public var nativePicker(default,null)=new BarTerNativePickerState();
 var commandEpoch:Int=-1;
 var repairedGeneration:Int=-1;
 var reconciledGeneration:Int=-1;
 var nativeCoherent:Bool=false;
 public var managedEditsReady(default,null):Bool=false;
 public var comboLabel(default,null):String="Waiting for the equipped weapons…";
 var replacePopulation = false;
 public var host:solarflare.ui.ConfigPanel = null;

 public function new() {
		hudEditFn = hudEdit;
		hudHideFn = hudHide;
		hudClickFn = hudClick;
		hudContextFn = hudContext;
		hudMenuFn = hudMenu;
 config=new BarTerConfig(); builder=new BarTerBuilder(this); overlay=new BarTerOverlay(); }
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
 public function changed(contentEdit:Bool=false):Void {
  loadout.changed(config.bars,config.weaponLayouts,contentEdit); snapshotsDirty=true;
  SettingsStore.markDirty(); solarflare.ObserveDemand.markStatusDemandDirty();
 }
 public function reserve(id:String,index:Int):Void { config.weaponLayouts.reserve(id,index); }
 public function requestPopulation(id:String,replace:Bool=false):Void {
  commandEpoch=BarTerNativeKeys.epoch;
  pendingPopulation=id; replacePopulation=replace; lastStatus="Waiting for the current native skills…";
 }
 public function clearCell(b:BarTerBarConfig,index:Int):Void {
  if (b == null || index < 0 || index >= b.slotCount) return;
  if (b.slots[index].nativeActionId.length>0 && !managedEditsReady) { lastStatus="Wait for the weapon change to finish."; return; }
  builder.recordChange(); reserve(b.id,index); b.slots[index].clearContent(); changed(true);
 }
 public function clearBar(b:BarTerBarConfig):Void {
  if (b == null) return;
  if (!managedEditsReady) for (s in b.slots) if (s.nativeActionId.length>0) { lastStatus="Wait for the weapon change to finish."; return; }
  builder.recordChange();
  for (i in 0...b.slotCount) { reserve(b.id,i); b.slots[i].clearContent(); }
  changed(true); lastStatus="Cleared "+b.name+". Undo restores it.";
 }
 public function needsActionBarSeed():Bool return config != null && (config.demand() || config.open.get() || pendingPopulation.length > 0);
 public function clearTransientState():Void {
  pendingNativeCheck=false; nativeCheckReport=nativeCheckSummary="";
  pendingPopulation=""; pendingRepair=false; replacePopulation=false; commandEpoch=-1; BarTerCache.pendingClicks.resize(0);
  loadout.resetCandidate(); reconciledGeneration=-1; nativeCoherent=false; lastStatus=""; snapshotsDirty=true; if (builder != null) builder.clearTransientState();
 }
 public function requestRepair():Void { commandEpoch=BarTerNativeKeys.epoch; pendingRepair=true; lastStatus="Waiting to repair the current native skill cells…"; }
 public function requestNativeCheck():Void { pendingNativeCheck=true; nativeCheckSummary="Waiting for a native skill observation…"; }
 public function observe():Void {
  var next=solarflare.HealthCache.characterId;
  if (next != character || identityGeneration != solarflare.HealthCache.identityGen) {
   clearTransientState(); builder.history.clear(); character=next; loadout.reset(); BarTerNativeKeys.reset(); rawWeaponKey=""; lastWeaponReadAt=-1;
   identityGeneration=solarflare.HealthCache.identityGen; repairedGeneration=reconciledGeneration=-1; statusChoices.resize(0); statusChoiceMap.clear(); statusRevision=-1;
   GeauxCache.actionBarLoadoutKey=""; GeauxCache.actionBarCharacterId="";
   GeauxCache.invalidateBarRoots();
  }
  if (!config.enabled.get() && !config.open.get()) return;
  var hero:Dynamic=solarflare.HealthCache.localHero;
  var now=haxe.Timer.stamp();
  observeStatusChoices();
  if (BarTerCache.hasAnyItem(config) || config.open.get()) try ConsumableCache.sample(hero,now) catch (_:Dynamic) {}
  if (now-lastWeaponReadAt >= 0.1) {
   var key=BarTerCache.weaponLoadoutKey(hero);
   if (key!=rawWeaponKey) {
    builder.clearTransientState(); BarTerCache.pendingClicks.resize(0); snapshotsDirty=true;
    comboLabel=key.length>0 ? [for (part in key.split("|")) if (part.length>0) part].join(" + ") : "Waiting for the equipped weapons…";
   }
   rawWeaponKey=key; lastWeaponReadAt=now;
  }
  var raw=rawWeaponKey;
  var key=raw.length>0 && character.length>0 ? character+"|"+raw : "";
  loadout.observeKey(key);
  var nativeBefore=BarTerNativeKeys.observationGeneration;
  BarTerNativeKeys.sample(now,pendingNativeCheck || managedEditsReady && (pendingRepair || pendingPopulation.length>0),raw,loadout.settling);
  nativePicker.refresh(BarTerNativeKeys.records,BarTerNativeKeys.ownerGeneration,BarTerNativeKeys.observationGeneration);
  if(pendingNativeCheck) {
   pendingNativeCheck=false; nativeCheckReport=BarTerNativeKeys.checkReport();
   var count=0; for(r in BarTerNativeKeys.records) if(StringTools.startsWith(r.action,"Skill") && r.fresh==true) count++;
   var signature=BarTerNativeKeys.action("SignatureSkill");
   nativeCheckSummary=(BarTerNativeKeys.classReadable ? "Read "+count+" equipped class skill(s)." : "Class observation incomplete.")+
    (signature!=null && signature.fresh==true ? " Signature: "+signature.label+"." : BarTerNativeKeys.signatureReadable ? " Signature slot empty." : " Signature observation incomplete. See the native skill check report.");
  }
  if ((pendingRepair || pendingPopulation.length>0) && commandEpoch!=BarTerNativeKeys.epoch) {
   pendingRepair=false; pendingPopulation=""; replacePopulation=false; lastStatus="Weapon combination changed; request the edit again.";
  }
  // Recheck native equipment after the read; a mixed weapon generation cannot commit.
  if(nativeBefore!=BarTerNativeKeys.observationGeneration || pendingRepair || pendingPopulation.length>0) nativeCoherent=key.length>0 && BarTerCache.weaponLoadoutKey(hero)==raw;
  var coherent=key.length>0 && nativeCoherent;
  managedEditsReady=false; config.weaponLayouts.activeCount=config.activeBarCount;
  if (coherent && reconciledGeneration!=BarTerNativeKeys.observationGeneration) { reconciledGeneration=BarTerNativeKeys.observationGeneration; reconcileLoadout(key,now); }
  managedEditsReady=!loadout.settling && coherent;
  if (managedEditsReady && config.autoSeedOnWeaponSwap.get() && config.weaponLayouts.recoverClassOmissions(key,config.bars,BarTerNativeKeys.classReadable)) {
   config.repairPending=true; SettingsStore.markDirty();
  }
  if (managedEditsReady && config.autoSeedOnWeaponSwap.get() && config.weaponLayouts.recoverSignatureOmission(key,config.bars,BarTerNativeKeys.action("SignatureSkill"))) {
   config.repairPending=true; snapshotsDirty=true; SettingsStore.markDirty();
  }
  if (managedEditsReady && (pendingRepair || config.autoSeedOnWeaponSwap.get() && (config.repairPending || repairedGeneration!=BarTerNativeKeys.observationGeneration))) {
   var before=pendingRepair ? dump() : null;
   var edited=config.weaponLayouts.repair(key,config.bars,BarTerNativeKeys.skills,true);
   config.layoutVersion=2; config.repairPending=false; repairedGeneration=BarTerNativeKeys.observationGeneration;
   if (pendingRepair) { builder.history.push(editorSnapshotFrom(before,key)); pendingRepair=false; lastStatus="Repaired native skill cells."; }
   if (edited>0) { snapshotsDirty=true; SettingsStore.markDirty(); }
  }
  if (config.weaponLayouts.shortfall>0) lastStatus=config.weaponLayouts.shortfall+" native action(s) need more available cells. Saved positions are retained.";
  // A deliberate editor command needs current skills, not a settled persistence key.
  if (hero != null && pendingPopulation.length > 0 && managedEditsReady) {
   if (BarTerNativeKeys.weaponReadable && BarTerCache.weaponLoadoutKey(hero)==raw) populateRequestedBar();
   else { pendingPopulation=""; replacePopulation=false; nativeCoherent=false; managedEditsReady=false; lastStatus="Weapon combination changed; request the edit again."; }
  }
  if (snapshotsDirty || now-lastSnapAt >= 0.05) { refreshSnaps(); snapshotsDirty=false; lastSnapAt=now; }
  // Same eligibility the ExtraBars policy enforces before any native use request.
  var block=BarTerCache.pendingClicks.length > 0 ? BarTerCache.gameplayBlockReason(hero) : "";
  if (block.length > 0) lastStatus=block;
  BarTerCache.drainClicks(function(c) {
   var b=config.find(c.barId);
   if (hero == null || !config.enabled.get() || !config.isActive(c.barId) || b == null || !b.enabled || b.hidden || config.hidden.get()
    || c.slot < 0 || c.slot >= b.slotCount) return;
   var slot = b.slots[c.slot];
   if (c.itemKind.length > 0 && slot.hasItem() && slot.itemKind == c.itemKind) {
    var outcome=BarTerCache.useItem(c.itemKind,c.gen,hero); lastStatus=outcome.message;
    var snaps=snapsFor(c.barId); if (outcome.submitted && c.slot < snaps.length) snaps[c.slot].flashUntil=now+0.3;
    } else if (c.skillId.length > 0 && slot.hasSkill() && c.nativeEpoch==BarTerNativeKeys.epoch
     && (slot.nativeActionId.length>0 ? managedEditsReady && slot.nativeActionId==c.action && BarTerNativeKeys.current(c.action,c.skillId) : slot.skillId==c.skillId)) {
    var outcome=BarTerCache.useSkill(c.skillId,c.action,hero); lastStatus=outcome.message;
     var snaps=snapsFor(c.barId); if (outcome.success && c.slot < snaps.length) snaps[c.slot].flashUntil=now+0.3;
   }
  },block.length > 0);
 }
 function reconcileLoadout(key:String,now:Float):Void {
  var revision=loadout.revision;
  if (!loadout.reconcile(key,BarTerNativeKeys.records,BarTerNativeKeys.observationGeneration,now,config.bars,config.weaponLayouts,config.autoSeedOnWeaponSwap.get(),BarTerNativeKeys.weaponReadable)) return;
  if (revision != loadout.revision) { snapshotsDirty=true; SettingsStore.markDirty(); }
 }
 function populateRequestedBar():Void {
  if (BarTerNativeKeys.skills.length == 0) return;
  if (pendingPopulation.length > 0) {
   var b=config.find(pendingPopulation); pendingPopulation="";
   if (b != null && config.isActive(b.id)) {
    if(config.weaponLayouts.recoverSignatureOmission(loadout.currentKey,config.bars,BarTerNativeKeys.action("SignatureSkill"))) SettingsStore.markDirty();
    var before=editorSnapshot();
    if (replacePopulation) for (i in 0...b.slotCount) if (b.slots[i].hasSkill()) reserve(b.id,i);
    var wrote=replacePopulation ? BarTerWeaponLayouts.replaceSkills(b,BarTerNativeKeys.skills,config.activeBars())
     : BarTerWeaponLayouts.populate(b,BarTerNativeKeys.skills,config.activeBars());
    lastStatus=wrote > 0 ? "Added "+wrote+" native skill(s)." : "No new skills fit. Right-click a cell to clear it or replace this bar's skills.";
    if (wrote > 0 || replacePopulation) { builder.history.push(before); changed(true); }
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
   hudBar = b;
   overlay.draw(b,snapsFor(b.id),chrome,hudEditFn,hudHideFn,hudClickFn,config.showHotkeys.get(),hudContextFn,hudMenuFn);
   hudBar = null;
   if (chrome.locked.get() != b.locked || chrome.transparent.get() != b.transparent) {
    b.locked=chrome.locked.get(); b.transparent=chrome.transparent.get(); changed();
   }
  }
 }
 public function drawBuilder():Void builder.draw();
 public function dump():Dynamic return config.dump();
 public function editorSnapshot(scope:String=null):Dynamic return editorSnapshotFrom(dump(),scope==null ? loadout.currentKey : scope);
 function editorSnapshotFrom(data:Dynamic,key:String):Dynamic { Reflect.setField(data,"editorKey",key); return data; }
 public function restoreEditorState(data:Dynamic):Void {
  var current=new BarTerWeaponLayouts(); current.apply(config.weaponLayouts.dump(),config.weaponLayouts.dumpShared());
  var key=loadout.currentKey; var scope=Std.isOfType(data.editorKey,String) ? data.editorKey : key;
  clearTransientState(); config.apply(data); config.weaponLayouts.mergeUntouched(current,scope);
  snapMap.clear(); loadout.reset(); loadout.observeKey(key); snapshotsDirty=true; SettingsStore.markDirty();
 }
 public function apply(data:Dynamic):Void {
  clearTransientState(); builder.history.clear(); config.apply(data);
  loadout.reset(); character=""; BarTerNativeKeys.reset(); snapMap.clear(); rawWeaponKey=""; lastWeaponReadAt=-1;
  solarflare.ObserveDemand.markStatusDemandDirty();
 }

	function hudEdit():Void {
		config.open.set(true); builder.selectBar(hudBar);
	}

	function hudHide():Void {
		hudBar.hidden = true; changed();
	}

	function hudClick(index:Int):Void {
		var b = hudBar; var s = b.slots[index];
		if (s.hasItem()) BarTerCache.queueClick(b.id,index,"",s.itemKind);
		else if (s.hasSkill()) { var snaps=snapsFor(b.id); if (index<snaps.length && snaps[index].available) BarTerCache.queueClick(b.id,index,snaps[index].skillId,"",s.nativeActionId); }
	}

	function hudContext(index:Int):Void {
		builder.drawCellContext(hudBar,index,"hud");
	}

	function hudMenu():Void {
		builder.drawBarMenu(hudBar);
	}
}
