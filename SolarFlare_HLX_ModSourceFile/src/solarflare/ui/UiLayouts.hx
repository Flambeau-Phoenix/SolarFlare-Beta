package solarflare.ui;

import imgui.ImGui;
import solarflare.ui.HudLayoutModel.HudLayoutRow;

/**
 * Profile-owned HUD layout bank. The strip mirrors the universal Profile strip
 * (FeatureProfiles.drawStrip): selector, Save, More menu, and one modal for names.
 * UI edits enqueue geometry/clipboard work; persistence stays in SettingsStore.
 */
class UiLayouts {
 public var bank=new HudLayoutModel();
 var nameBuf=new hl.Bytes(96);
 var initialized:Bool=false;
 var defaults:Array<HudLayoutRow>=[];
 var applied=new Map<String,HudChrome>();
 var reconcileWanted:Bool=false;
 var generation:Int=-1;
 public function requestReconcile():Void { reconcileWanted=true; generation=FeatureProfiles.statusOwnerGen; }
 /** Snapshot constructor geometry before settings/profile loading changes any widget. */
 public function captureDefaults(c:ConfigPanel):Void defaults=HudLayoutBindings.capture(c);
 /** "New" or "Rename" while the name modal is wanted; empty when closed. */
 var nameAction:String="";
 /** Strip id that opens the name modal next; set in the More menu, consumed outside the popup scope. */
 var openFor:String="";
 public function new() { ByteUtil.clearBytes(nameBuf,96); }
 public function clearTransientState():Void { nameAction=""; openFor=""; ByteUtil.clearBytes(nameBuf,96); }
 public function retain(c:ConfigPanel):Void {
  if(!initialized) { bank=HudLayoutModel.load(null,HudLayoutBindings.capture(c)); initialized=true; }
  else bank.retain(HudLayoutBindings.capture(c));
 }
 public function dumpCurrent(c:ConfigPanel):Dynamic { retain(c); return bank.dump(); }
 public function load(c:ConfigPanel,data:Dynamic,fallback:Array<HudLayoutRow>):Void {
  clearTransientState(); generation=FeatureProfiles.statusOwnerGen;
  bank=HudLayoutModel.load(data,HudLayoutModel.merge(defaults,fallback)); initialized=true;
  applySelected(c);
  if(!bank.saveSafe) SettingsStore.blockSaving(bank.loadWarning);
 }
 public static function migrateSnapshot(snapshot:Dynamic,root:Dynamic=null):Void {
  if(snapshot==null) return;
  var before=Reflect.field(snapshot,"uiLayouts");
  var bank=HudLayoutModel.load(before,HudLayoutModel.legacy(snapshot,HudChrome.viewportWidth,HudChrome.viewportHeight,root));
  if(bank.saveSafe) Reflect.setField(snapshot,"uiLayouts",bank.dump());
  else SettingsStore.blockSaving(bank.loadWarning);
 }
 function applySelected(c:ConfigPanel):Int {
  reconcileWanted=false;
  applied.clear();
  var bindings=HudLayoutBindings.build(c);
  var rows=bank.layouts.get(bank.active);
  var missing=HudLayoutBinding.applyRows(bindings,rows);
  for(b in bindings) applied.set(b.id,b.chrome);
  traceApply("apply",bindings,rows,missing);
  return missing;
 }
 function traceApply(tag:String,bindings:Array<HudLayoutBinding>,rows:Array<HudLayoutRow>,missing:Int):Void {
  var rowIds=new Map<String,Bool>(); for(r in rows) rowIds.set(r.id,true);
  var noRow=[for(b in bindings) if(!rowIds.exists(b.id)) b.id];
  var state=[for(b in bindings) b.id+"@"+Std.int(b.chrome.x.get())+","+Std.int(b.chrome.y.get())];
  ProfileTrace.note("layout",tag+" layout=\""+bank.active+"\" "+FeatureProfiles.summary()+" rows="+rows.length+" bindings="+bindings.length+" rowsWithoutBinding="+missing+" bindingsWithoutRow["+noRow.length+"]="+noRow.join("|"));
  ProfileTrace.note("layout",tag+" positions "+state.join(" "));
 }
 /** Observe-only: character restores can replace dynamic chromes after profile loading. */
 public function reconcile(c:ConfigPanel):Void {
  if(!initialized || !reconcileWanted || !FeatureProfiles.ready || generation!=FeatureProfiles.statusOwnerGen) return;
  reconcileWanted=false;
  var rows=bank.layouts.get(bank.active); var bindings=HudLayoutBindings.build(c);
  var fixed=[];
  for(b in bindings) if(applied.get(b.id)!=b.chrome) {
   for(row in rows) if(row.id==b.id) { b.apply(row); fixed.push(b.id); break; }
   applied.set(b.id,b.chrome);
  }
  ProfileTrace.note("layout","reconcile layout=\""+bank.active+"\" reapplied["+fixed.length+"]="+fixed.join("|"));
 }
 /** Explicit deletion only; absence during loading never removes a saved row. */
 public function forgetWidget(id:String):Void {
  if(initialized) bank.forget(id); applied.remove(id);
 }
 public function select(c:ConfigPanel,name:String):Void {
  if(!bank.layouts.exists(name)) return;
  retain(c); bank.active=name;
  var missing=applySelected(c); SettingsStore.markDirty();
  if(missing>0) ToastManager.warn("Loaded layout \""+name+"\"; "+missing+" unmatched widgets left unchanged.");
  else ToastManager.info("Switched to layout \""+name+"\"");
 }
 function save(c:ConfigPanel):Void {
  retain(c); SettingsStore.markDirty(); SettingsStore.saveNow();
  ToastManager.success("Layout \""+bank.active+"\" saved!");
 }
 function copy(c:ConfigPanel):Void {
  retain(c); var key=bank.add(bank.active+" (Copy)",bank.layouts.get(bank.active)); SettingsStore.markDirty();
  ToastManager.success("Created layout \""+key+"\"!");
 }
 function named(c:ConfigPanel,action:String,name:String):Void {
  retain(c);
  switch(action) {
   case "Rename":
    if(bank.layouts.exists(name) && name!=bank.active) { ToastManager.warn("A layout named \""+name+"\" already exists."); return; }
    var old=bank.active; var rows=bank.layouts.get(old); var index=bank.order.indexOf(old);
    bank.layouts.remove(old); bank.order[index]=name; bank.layouts.set(name,rows); bank.active=name;
    ToastManager.success("Renamed layout to \""+name+"\"");
   default:
    var key=bank.add(name,bank.layouts.get(bank.active));
    ToastManager.success("Created layout \""+key+"\"!");
  }
  SettingsStore.markDirty();
 }
 function remove(c:ConfigPanel):Void {
  if(bank.order.length<=1) return;
  var old=bank.active; bank.layouts.remove(old); bank.order.remove(old); bank.active=bank.order[0];
  applySelected(c); SettingsStore.markDirty();
  ToastManager.info("Deleted layout \""+old+"\".");
 }
 function importClipboard(c:ConfigPanel):Void {
  try {
   var raw=ImGui.getClipboardText(); var text=raw==null ? "" : ByteUtil.readString(raw,1048577,true);
   // Parse into a temporary bank first; invalid input cannot even save outgoing edits.
   var temporary=new HudLayoutModel(); var key=temporary.importText(text); var rows=temporary.layouts.get(key);
   retain(c); key=bank.add(key,rows);
   var missing=applySelected(c); SettingsStore.markDirty();
   ToastManager.success("Imported layout \""+key+"\""+(missing>0 ? "; "+missing+" unmatched widgets." : "."));
  } catch(e:Dynamic) { ToastManager.error("Import failed: "+Std.string(e)); }
 }
 /** Selector, Save and More; same shape as the Profile strip so the two read as one control. */
 public function drawToolbar(c:ConfigPanel,id:String,comboWidth:Single):Void {
  ImGui.textDisabled("Layout");
  if(ImGui.isItemHovered()) ImGui.setTooltip("Positions and sizes of HUD windows. Stored inside the selected Profile.");
  ImGui.sameLine(0,8);
  ImGui.setNextItemWidth(comboWidth);
  if(ImGui.beginCombo("##layout_select_"+id,bank.active)) {
   try { for(name in bank.order) if(ImGui.selectable(name+"##layout_option_"+id+"_"+name,name==bank.active)) {
    if(name!=bank.active) { var chosen=name; UiActionQueue.custom(function() select(c,chosen)); }
   } } catch(e:Dynamic) { ImGui.endCombo(); throw e; }
   ImGui.endCombo();
  }
  ImGui.sameLine(0,6);
  if(UiChrome.ghostButton("Save##layout_save_"+id,ImGui.vec2(56,26))) UiActionQueue.custom(function() save(c));
  ImGui.sameLine(0,6);
  if(UiChrome.ghostButton("More##layout_more_"+id,ImGui.vec2(60,26))) ImGui.openPopup("##layout_menu_"+id);
  drawMoreMenu(c,id);
  if(openFor==id) {
   openFor="";
   if(nameAction=="Rename") ByteUtil.fillBuf(nameBuf,96,bank.active);
   else ByteUtil.clearBytes(nameBuf,96);
   ImGui.openPopup("Layout Name##layout_name_popup_"+id);
  }
  drawNameModal(c,id);
 }
 function drawMoreMenu(c:ConfigPanel,id:String):Void {
  if(!ImGui.beginPopup("##layout_menu_"+id)) return;
  try {
   if(ImGui.menuItem("New layout...##layout_new_"+id)) { nameAction="New"; openFor=id; ImGui.closeCurrentPopup(); }
   if(ImGui.menuItem("Copy this layout##layout_copy_"+id)) UiActionQueue.custom(function() copy(c));
   if(ImGui.menuItem("Rename layout...##layout_rename_"+id)) { nameAction="Rename"; openFor=id; ImGui.closeCurrentPopup(); }
   ImGui.beginDisabled(bank.order.length<=1);
   var deleted=ImGui.menuItem("Delete this layout##layout_delete_"+id); ImGui.endDisabled();
   if(deleted) UiActionQueue.custom(function() remove(c));
   ImGui.separator();
   if(ImGui.menuItem("Import from clipboard##layout_import_"+id)) UiActionQueue.custom(function() importClipboard(c));
   if(ImGui.menuItem("Export to clipboard##layout_export_"+id)) UiActionQueue.custom(function() {
    retain(c); ImGui.setClipboardText(bank.exportSelected()); ToastManager.success("Layout share key copied to clipboard.");
   });
  } catch(e:Dynamic) { ImGui.endPopup(); throw e; }
  ImGui.endPopup();
 }
 function drawNameModal(c:ConfigPanel,id:String):Void {
  if(!ImGui.beginPopupModal("Layout Name##layout_name_popup_"+id,null,imgui.Enums.ImGuiWindowFlags.AlwaysAutoResize)) return;
  try {
   // clearTransientState (camera entry, profile load) drops nameAction: close with it.
   if(nameAction.length==0) ImGui.closeCurrentPopup();
   else {
    var renaming=nameAction=="Rename";
    UiChrome.heading(renaming ? "Rename Layout" : "New Layout",1.15);
    ImGui.spacing();
    ImGui.text("Enter layout name:");
    ImGui.inputText("##layout_name_"+id,nameBuf,96);
    ImGui.spacing();
    UiLayout.inlinePair("##layout_name_btns_"+id,function(w:Single) {
     if(UiChrome.accentButton((renaming ? "Rename" : "Create")+"##layout_name_ok_"+id,ImGui.vec2(w,28))) {
      var requested=StringTools.trim(ByteUtil.readBytes(nameBuf,96)).substr(0,80);
      if(requested.length==0) ToastManager.warn("Layout name required.");
      else if(renaming && requested!=bank.active && bank.layouts.exists(requested)) ToastManager.warn("A layout named \""+requested+"\" already exists.");
      else {
       var action=nameAction; nameAction="";
       UiActionQueue.custom(function() named(c,action,requested));
       ImGui.closeCurrentPopup();
      }
     }
    },function(w:Single) {
     if(UiChrome.ghostButton("Cancel##layout_name_cancel_"+id,ImGui.vec2(w,28))) { nameAction=""; ImGui.closeCurrentPopup(); }
    },8);
   }
  } catch(e:Dynamic) { ImGui.endPopup(); throw e; }
  ImGui.endPopup();
 }
}
