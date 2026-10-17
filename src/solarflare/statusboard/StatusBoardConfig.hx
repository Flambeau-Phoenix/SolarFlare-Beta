package solarflare.statusboard;
import imgui.ImGui;
import imgui.ref.BoolRef;
import imgui.ref.IntRef;
import solarflare.aura.AuraStatusCache;
import solarflare.aura.AuraStatusSnap;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiChrome;
import solarflare.ui.UiLayout;
import solarflare.ui.UiScope;
import solarflare.ui.SearchBar;

class StatusBoardConfig {
 public var enabled=new BoolRef(true);
 public var hidden=new BoolRef(false);
 public var chrome=new HudChrome(40,120);
 public var slotSize:Int=40;
 public var columns:Int=12;
 public var contentWidth:Single=0;
 public var contentHeight:Single=0;
 public var maxIcons:Int=512;
 public var showSeconds:Bool=true;
 public var showStacks:Bool=true;
 public var exclusions=new StatusBoardState();
 public var visible:Array<AuraStatusSnap>=[];
 public var active:Array<AuraStatusSnap>=[];
 public var visuals:Array<StatusBoardVisual>=[];
 var visualByKey:Map<String,StatusBoardVisual>=new Map();
 var retiredVisuals:Array<String>=[];
 var visualBySnapshot=new haxe.ds.ObjectMap<AuraStatusSnap,StatusBoardVisual>();
 var intRef=new IntRef(1);
 var boolRef=new BoolRef(false);
 var search=new SearchBar("Search status names or IDs");
 var labels:Map<String,String>=new Map();
 var lastRevision:Int=-1;
 var copyTooltipCoverageFn:Void->Void;
 public function new() { copyTooltipCoverageFn=copyTooltipCoverage; }
 function copyTooltipCoverage():Void {
  solarflare.ui.UiActionQueue.copyText(haxe.Json.stringify({schema:"solarflare.status-tooltip-coverage.v1",scope:"hovered applications only",rows:StatusBoardTooltipCache.coverage()},null,"  "));
 }
 public function demand():Bool return enabled.get() && !hidden.get();
 public function hideStatus(id:String):Void { if (exclusions.hide(id)) SettingsStore.markDirty(); }
 public function setColumnsFromWidth(w:Single,gap:Int):Void {
  var c=Std.int(Math.max(1,Math.min(16,Math.floor((w+gap)/(slotSize+gap)))));
  if (c != columns) { columns=c; SettingsStore.markDirty(); }
 }
 public function resize(w:Single,h:Single,gap:Int):Void {
  contentWidth=Math.max(slotSize,w); contentHeight=Math.max(slotSize,h);
  setColumnsFromWidth(contentWidth,gap); SettingsStore.markDirty();
 }
 var stabilizer=new StatusBoardStabilizer();
 public function observe():Void {
  if (stabilizer.syncOwner(AuraStatusCache.ownerGeneration)) lastRevision=-1;
  if (lastRevision != AuraStatusCache.revision) {
   lastRevision=AuraStatusCache.revision;
   stabilizer.update(AuraStatusCache.snaps,AuraStatusCache.count,describe,maxIcons);
   active=stabilizer.shown;
  }
  exclusions.pack(stabilizer.shown,stabilizer.shown.length,visible,maxIcons);
  for (v in visualByKey) v.seen=false;
  var now=haxe.Timer.stamp();
  for (i in 0...active.length) {
   var s=active[i]; var key=s.instanceId.length>0 ? s.instanceId : s.id+"|"+s.sourceItemId+"|"+i;
   var v=visualByKey.get(key);
   if (v == null) { v=new StatusBoardVisual(key); visualByKey.set(key,v); }
   if (v.snapshot != null && v.snapshot != s) visualBySnapshot.remove(v.snapshot);
   v.seen=true; v.prepare(s,now,showSeconds,showStacks);
   visualBySnapshot.set(s,v);
   StatusBoardTooltipCache.facts(s,now);
   StatusBoardTooltipRenderer.prepare(StatusBoardTooltipCache.get(s.instanceId));
  }
  retiredVisuals.resize(0); for (key in visualByKey.keys()) if (!visualByKey.get(key).seen) retiredVisuals.push(key);
  for (key in retiredVisuals) { var v=visualByKey.get(key); visualBySnapshot.remove(v.snapshot); visualByKey.remove(key); }
  visuals.resize(0);
  for (s in visible) {
   var v=visualBySnapshot.get(s); if (v != null) visuals.push(v);
  }
  lastActive=active.length; lastVisible=visible.length;
 }
 /** Primitive mirror of the board's own lists for the Dev Log (what is actually drawn, not what the cache holds). */
 public static var lastActive:Int=0;
 public static var lastVisible:Int=0;
 /** Label, icon and source item for a board-owned copy; the cache row is never written. */
 function describe(s:AuraStatusSnap):Void {
  var entry=solarflare.cdb.ConsumableCatalog.find(s.sourceItemId);
  if (entry == null) entry=solarflare.cdb.ConsumableCatalog.findByStatus(s.id);
  if (entry == null) for (alias in s.ids) {
   entry=solarflare.cdb.ConsumableCatalog.findByStatus(alias);
   if (entry != null) break;
  }
  if (entry != null) {
   s.label=entry.name;
   if (s.sourceItemId.length == 0) s.sourceItemId=entry.id;
   s.iconKey=solarflare.cdb.ConsumableCatalog.iconKey(entry.id);
  } else {
   var label=solarflare.cdb.AuraCatalog.label(s.id);
   s.label=StatusBoardNativeText.fallback(label,s.id);
   s.iconKey=s.id;
   for (alias in s.ids) {
    solarflare.ui.GameIcons.get(alias);
    if (label.length == 0) { var aliasLabel=solarflare.cdb.AuraCatalog.label(alias); if (StatusBoardNativeText.meaningful(aliasLabel,alias) && aliasLabel!=alias) { s.label=aliasLabel; label=aliasLabel; } }
    if (solarflare.ui.GameIcons.hasKey(alias)) { s.iconKey=alias; break; }
   }
  }
  labels.set(StatusBoardState.key(s.id),s.label);
 }
 public function dump():Dynamic return {
  enabled:enabled.get(),hidden:hidden.get(),slotSize:slotSize,columns:columns,maxIcons:maxIcons,
  contentWidth:contentWidth,contentHeight:contentHeight,
  showSeconds:showSeconds,showStacks:showStacks,hiddenStatusIds:exclusions.hiddenIds.copy(),
  hiddenStatusLabels:[for (id in exclusions.hiddenIds) {id:id,label:labels.exists(id) ? labels.get(id) : id}],
  locked:chrome.locked.get(),transparent:chrome.transparent.get(),x:chrome.x.get(),y:chrome.y.get(),
  referenceWidth:chrome.referenceWidth,referenceHeight:chrome.referenceHeight
 };
 public function apply(data:Dynamic):Void {
  if (data == null) return;
  enabled.set(data.enabled != false); hidden.set(data.hidden == true);
  slotSize=clamp(data.slotSize,28,72,40); columns=clamp(data.columns,1,16,12);
  contentWidth=dimension(data.contentWidth); contentHeight=dimension(data.contentHeight);
  // Legacy boards silently truncated at 24/48; migration displays the whole list.
  maxIcons=data.hiddenStatusIds == null ? 512 : clamp(data.maxIcons,1,512,512);
  showSeconds=data.showSeconds != false; showStacks=data.showStacks != false;
  exclusions.apply(data.hiddenStatusIds);
  visualByKey.clear(); visuals.resize(0);
  visualBySnapshot.clear(); StatusBoardTooltipCache.clear();
  labels.clear(); lastRevision=-1; stabilizer.reset(); active=stabilizer.shown; visible.resize(0);
  if (Std.isOfType(data.hiddenStatusLabels,Array)) {
   var saved:Array<Dynamic>=cast data.hiddenStatusLabels;
   for (row in saved) if (row != null && Std.isOfType(row.id,String) && Std.isOfType(row.label,String)) labels.set(StatusBoardState.key(row.id),row.label);
  }
  chrome.restoreReference(data); chrome.locked.set(data.locked == true); chrome.transparent.set(data.transparent == true);
  if (data.x != null) chrome.x.set(data.x); if (data.y != null) chrome.y.set(data.y);
  chrome.posDirty=true;
 }
 static function clamp(v:Dynamic,lo:Int,hi:Int,fallback:Int):Int return v == null ? fallback : Std.int(Math.max(lo,Math.min(hi,v)));
 static function dimension(v:Dynamic):Single {
  if ((!Std.isOfType(v,Float) && !Std.isOfType(v,Int)) || !Math.isFinite(v) || v <= 0) return 0;
  return Math.min(10000,v);
 }
 public function drawContents():Void {
  UiChrome.heading("Status Board",1.15);
  ImGui.textWrapped("Your character's active statuses. Empty boards disappear during gameplay. Hidden statuses remain available to Auras and BarTer.");
  UiLayout.propertyGrid("##sb_properties",function() {
   UiLayout.propertyRow("Window",function() {
    UiLayout.inlineSplit("##sb_window",4,function(i:Int,_:Single) {
     if (i == 0) { boolRef.set(demand()); if (ImGui.checkbox("Show##sb_show",boolRef)) { enabled.set(boolRef.get()); hidden.set(!boolRef.get()); SettingsStore.markDirty(); } }
     if (i == 1 && ImGui.checkbox("Lock##sb_lock",chrome.locked)) SettingsStore.markDirty();
     if (i == 2 && ImGui.checkbox("Transparent##sb_trans",chrome.transparent)) SettingsStore.markDirty();
     if (i == 3 && ImGui.button("Place##sb_place")) { enabled.set(true); hidden.set(false); chrome.locked.set(false); SettingsStore.markDirty(); }
    });
   });
   chrome.drawPositionRow("sb_pos");
   UiLayout.propertyRow("Icon size",function() { intRef.set(slotSize); if (ImGui.sliderInt("##sb_size",intRef,28,72)) { slotSize=intRef.get(); contentWidth=0; SettingsStore.markDirty(); } });
   UiLayout.propertyRow("Columns",function() { intRef.set(columns); if (ImGui.sliderInt("##sb_columns",intRef,1,16)) { columns=intRef.get(); contentWidth=0; SettingsStore.markDirty(); } });
   UiLayout.propertyRow("Badges",function() {
    UiLayout.inlinePair("##sb_badges",function(_:Single) { boolRef.set(showSeconds); if (ImGui.checkbox("Duration##sb_duration",boolRef)) { showSeconds=boolRef.get(); SettingsStore.markDirty(); } },function(_:Single) { boolRef.set(showStacks); if (ImGui.checkbox("Stacks##sb_stacks",boolRef)) { showStacks=boolRef.get(); SettingsStore.markDirty(); } });
   });
  });
  ImGui.textDisabled(active.length+" active / "+visible.length+" visible / "+exclusions.hiddenIds.length+" hidden");
  if (ImGui.smallButton("Check statuses##sb_audit")) AuraStatusCache.auditRequested=true;
  if (ImGui.isItemHovered()) ImGui.setTooltip("Compares the game's own status list with what SolarFlare read and what this board shows.");
  ImGui.sameLine();
  if (ImGui.smallButton("Copy tooltip coverage##sb_tooltip_audit")) solarflare.ui.UiActionQueue.custom(copyTooltipCoverageFn);
  if (ImGui.isItemHovered()) ImGui.setTooltip("Copies resolution details for hovered status applications. Hover an effect first; unhovered effects have not been formatted.");
  if (AuraStatusCache.lastAudit.length > 0) ImGui.textWrapped(AuraStatusCache.lastAudit);
  if (!AuraStatusCache.domainKnown) ImGui.textWrapped("Status observation is incomplete; unavailable values are not treated as absence.");
  var q=search.draw("##sb_search");
  UiChrome.centeredHeader("Active statuses",30);
  UiScope.child("##sb_active",ImGui.vec2(0,170),function() {
   for (s in active) {
    if (q.length > 0 && (s.label+" "+s.id).toLowerCase().indexOf(q) < 0) continue;
    ImGui.pushID_Str(s.instanceId);
    try {
    ImGui.text(s.label); if (ImGui.isItemHovered()) StatusBoardTooltipRenderer.draw(s.instanceId,s.label);
    ImGui.sameLine();
    if (exclusions.excluded(s)) { if (ImGui.smallButton("Restore##active")) { exclusions.restore(s.id); for (id in s.ids) exclusions.restore(id); SettingsStore.markDirty(); } }
    else if (ImGui.smallButton("Hide##active")) hideStatus(s.id);
    } catch(e:Dynamic) { ImGui.popID(); throw e; }
    ImGui.popID();
   }
   if (active.length == 0) ImGui.textDisabled("No active statuses observed.");
  });
  UiChrome.centeredHeader("Hidden statuses",30);
  if (ImGui.smallButton("Restore All##sb_all")) { exclusions.hiddenIds.resize(0); SettingsStore.markDirty(); }
  UiScope.child("##sb_hidden",ImGui.vec2(0,140),function() {
   var restore="";
   for (id in exclusions.hiddenIds) {
    var label=labels.get(id); if (label == null) label=solarflare.cdb.AuraCatalog.label(id); if (label == null || label.length == 0) label=id;
    if (q.length > 0 && (label+" "+id).toLowerCase().indexOf(q) < 0) continue;
    ImGui.text(label); ImGui.sameLine(); if (ImGui.smallButton("Restore##sb_"+id)) restore=id;
   }
   if (restore.length > 0) { exclusions.restore(restore); SettingsStore.markDirty(); }
   if (exclusions.hiddenIds.length == 0) ImGui.textDisabled("No statuses hidden.");
  });
 }
}
