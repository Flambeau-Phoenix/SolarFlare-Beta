package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.BoolRef;

private class ManagedSetup {
 public var key:String;
 public var name:String;
 public var caption:String;
 public var searchName:String;
 public var selected=new BoolRef(false);
 public function new(key:String,name:String,suffix:String) {
  this.key=key; this.name=name; searchName=name.toLowerCase();
  caption=name+suffix+"###setup_"+key;
 }
}

/** Parent-owned modal: camera/profile transitions clear it with ConfigPanel's transient state. */
class ProfileLayoutManager {
 var rows:Array<ManagedSetup>=[];
 var strip:String="";
 var popup:String="";
 var opening=false;
 var active=false;
 var layouts=false;
 var generation=-1;
 var profile="";
 var revision=0;
 var pending=false;
 var confirming=false;
 var selectedCount=0;
 var single:ManagedSetup=null;
 var countLabel="0 selected";
 var message="";
 var filter="";
 var nameBuf=new hl.Bytes(96);
 var filterBuf=new hl.Bytes(96);
 var windowSize=ImGui.vec2(620,400);
 var listSize=ImGui.vec2(350,300);
 var actionSize=ImGui.vec2(220,300);
 var buttonSize=ImGui.vec2(140,28);
 var smallSize=ImGui.vec2(72,26);
 var host:ConfigPanel;
 var drawListFn:Void->Void;
 var drawActionsFn:Void->Void;

 public function new() {
  ByteUtil.clearBytes(nameBuf,96); ByteUtil.clearBytes(filterBuf,96);
  drawListFn=drawList; drawActionsFn=drawActions;
 }
 public function clearTransientState():Void {
  revision++; active=false; opening=false; pending=false; confirming=false;
  rows.resize(0); single=null; selectedCount=0; message=""; filter="";
  ByteUtil.clearBytes(nameBuf,96); ByteUtil.clearBytes(filterBuf,96);
 }
 public function request(cfg:ConfigPanel,id:String,isLayout:Bool):Void {
  if(!FeatureProfiles.ready) return;
  clearTransientState(); host=cfg; layouts=isLayout; strip=id; opening=true; active=true;
  popup=(layouts ? "Manage Layouts" : "Manage Profiles")+"###setup_manager_"+id;
  generation=FeatureProfiles.statusOwnerGen; profile=FeatureProfiles.activeProfile;
  rebuild();
 }
 function valid():Bool return active && strip!="" && FeatureProfiles.ready
  && generation==FeatureProfiles.statusOwnerGen && profile==FeatureProfiles.activeProfile;
 function rebuild():Void {
  rows.resize(0);
  if(layouts) {
   for(key in host.uiLayouts.bank.order)
    rows.push(new ManagedSetup(key,key,key==host.uiLayouts.bank.active ? " (active)" : ""));
  } else {
   var bank=FeatureProfiles.bank,active=bank.profiles.get(profile);
   if(active!=null) for(key in bank.order) {
    var p=bank.profiles.get(key);
    if(p.ownerHeroId==active.ownerHeroId)
     rows.push(new ManagedSetup(key,p.name,(key==profile ? " (active)" : "")
      +(bank.defaults.get(active.ownerHeroId)==key ? " (default)" : "")));
   }
  }
  selectionChanged();
 }
 function selectionChanged():Void {
  confirming=false; message=""; selectedCount=0; single=null;
  for(row in rows) if(row.selected.get()) { selectedCount++; single=row; }
  if(selectedCount!=1) single=null;
  countLabel=selectedCount+" selected";
  ByteUtil.fillBuf(nameBuf,96,single==null ? "" : single.name);
 }
 public function draw(cfg:ConfigPanel,id:String):Void {
  if(strip!=id) return;
  if(opening) { opening=false; ImGui.openPopup(popup); ImGui.setNextWindowSize(windowSize,ImGuiCond.Always); }
  if(!ImGui.beginPopupModal(popup,null,ImGuiWindowFlags.NoDocking|ImGuiWindowFlags.NoResize)) {
   if(!active) strip="";
   return;
  }
  var failure:Dynamic=null;
  try {
   if(!valid()) { ImGui.closeCurrentPopup(); clearTransientState(); strip=""; }
   else {
    var available=ImGui.getContentRegionAvail();
    listSize.x=(available.x-8)*0.60; listSize.y=Math.max(120,available.y-42);
    actionSize.x=available.x-listSize.x-8; actionSize.y=listSize.y;
    ImGui.beginDisabled(pending);
    var bodyFailure:Dynamic=null;
    try {
     UiChrome.celChild("##setup_list",listSize,drawListFn);
     ImGui.sameLine(0,8);
     UiChrome.celChild("##setup_actions",actionSize,drawActionsFn);
    } catch(e:Dynamic) bodyFailure=e;
    ImGui.endDisabled();
    if(bodyFailure!=null) throw bodyFailure;
    UiChrome.gap(UiChrome.SP_M);
    if(UiChrome.ghostButton("Close##setup_close",buttonSize)) { ImGui.closeCurrentPopup(); clearTransientState(); strip=""; }
   }
  } catch(e:Dynamic) failure=e;
  ImGui.endPopup();
  if(failure!=null) throw failure;
 }
 function drawList():Void {
  UiChrome.subHeader(layouts ? "Layouts in this profile" : "Profiles for this character");
  ImGui.setNextItemWidth(-1);
  if(ImGui.inputTextWithHint("##setup_filter","Filter names...",filterBuf,96))
   filter=ByteUtil.readBytes(filterBuf,96).toLowerCase();
  if(UiChrome.ghostButton("All##setup_all",smallSize)) {
   for(row in rows) if(filter=="" || row.searchName.indexOf(filter)>=0) row.selected.set(true);
   selectionChanged();
  }
  ImGui.sameLine(0,6);
  if(UiChrome.ghostButton("None##setup_none",smallSize)) {
   for(row in rows) row.selected.set(false);
   selectionChanged();
  }
  ImGui.separator();
  var visible=0;
  for(row in rows) if(filter=="" || row.searchName.indexOf(filter)>=0) {
   visible++;
   if(ImGui.checkbox(row.caption,row.selected)) selectionChanged();
   if(ImGui.isItemHovered()) ImGui.setTooltip(row.name);
  }
  if(visible==0) UiHints.noteWrapped("No names match this filter.");
 }
 function drawActions():Void {
  UiChrome.subHeader(countLabel);
  ImGui.beginDisabled(single==null);
  var failure:Dynamic=null;
  try {
   ImGui.setNextItemWidth(-1);
   ImGui.inputTextWithHint("##setup_name","Select one to rename",nameBuf,layouts ? 96 : 49);
   if(UiChrome.ghostButton("Change name##setup_rename",buttonSize)) queueRename();
  } catch(e:Dynamic) failure=e;
  ImGui.endDisabled(); if(failure!=null) throw failure;
  UiChrome.gap(UiChrome.SP_M);
  ImGui.beginDisabled(selectedCount==0 || selectedCount>=rows.length);
  failure=null;
  try {
   if(UiChrome.ghostButton(confirming ? "Confirm delete?##setup_delete" : "Delete selected##setup_delete",buttonSize)) {
    if(confirming) queueDelete(); else confirming=true;
   }
  } catch(e:Dynamic) failure=e;
  ImGui.endDisabled(); if(failure!=null) throw failure;
  if(confirming) UiHints.noteWrapped("Click again to permanently delete the checked entries.");
  else UiHints.noteWrapped("Tick several entries to delete together. Keep at least one.");
  if(message!="") UiHints.noteWrapped(message);
 }
 function queueRename():Void {
  if(single==null || pending) return;
  var row=single,requested=ByteUtil.readBytes(nameBuf,96),ticket=revision;
  var cfg=host,isLayout=layouts;
  pending=true;
  UiActionQueue.custom(function() {
   if(ticket!=revision || !valid()) return;
   pending=false;
   var name=StringTools.trim(requested);
   var ok=isLayout ? cfg.uiLayouts.renameSelected(cfg,row.key,name)
    : FeatureProfiles.rename(cfg,row.key,name,generation);
   if(ok) { rebuild(); ToastManager.success("Name changed."); }
   else message="Use a unique, non-empty name.";
  });
 }
 function queueDelete():Void {
  if(pending) return;
  var keys=[for(row in rows) if(row.selected.get()) row.key];
  var ticket=revision,cfg=host,isLayout=layouts;
  pending=true;
  UiActionQueue.custom(function() {
   if(ticket!=revision || !valid()) return;
   pending=false;
   var ok=isLayout ? cfg.uiLayouts.removeSelected(cfg,keys) : FeatureProfiles.removeSelected(cfg,keys);
   // Removing the active profile closes this modal during its normal restore lifecycle.
   if(ticket!=revision) return;
   if(ok) { rebuild(); ToastManager.info("Selected entries deleted."); }
   else { confirming=false; message="Keep at least one entry. Selection may have changed."; }
  });
 }
}
