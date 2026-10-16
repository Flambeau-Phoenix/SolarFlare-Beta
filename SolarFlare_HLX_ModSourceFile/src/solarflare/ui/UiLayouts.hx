package solarflare.ui;

import imgui.ImGui;
import imgui.ref.BoolRef;
import solarflare.ui.HudLayoutModel.HudLayoutRow;

/** UI edits enqueue geometry/clipboard work; persistence stays in SettingsStore. */
class UiLayouts {
 public var open=new BoolRef(false);
 public var bank=new HudLayoutModel();
 var nameBuf=new hl.Bytes(96);
 var message:String="";
 var initialized:Bool=false;
 var nameAction:String="";
 public function new() { ByteUtil.clearBytes(nameBuf,96); }
 public function clearTransientState():Void { nameAction=""; ByteUtil.clearBytes(nameBuf,96); }
 public function retain(c:ConfigPanel):Void {
  if(!initialized) { bank=HudLayoutModel.load(null,HudLayoutBindings.capture(c)); initialized=true; }
  else bank.layouts.set(bank.active,HudLayoutBindings.capture(c));
 }
 public function dumpCurrent(c:ConfigPanel):Dynamic { retain(c); return bank.dump(); }
 public function load(c:ConfigPanel,data:Dynamic,fallback:Array<HudLayoutRow>):Void {
  clearTransientState(); bank=HudLayoutModel.load(data,fallback); initialized=true;
  var missing=HudLayoutBindings.apply(c,bank.layouts.get(bank.active));
  message=missing>0 ? missing+" unmatched widgets were left unchanged." : "Loaded "+bank.active+".";
 }
 public static function migrateSnapshot(snapshot:Dynamic):Void {
  if(snapshot==null || Reflect.field(snapshot,"uiLayouts")!=null) return;
  Reflect.setField(snapshot,"uiLayouts",HudLayoutModel.load(null,HudLayoutModel.legacy(snapshot,HudChrome.viewportWidth,HudChrome.viewportHeight)).dump());
 }
 public function select(c:ConfigPanel,name:String):Void {
  if(!bank.layouts.exists(name)) return;
  retain(c); bank.active=name;
  var missing=HudLayoutBindings.apply(c,bank.layouts.get(name));
  message="Loaded "+name+(missing>0 ? " · "+missing+" unmatched widgets." : "."); SettingsStore.markDirty();
 }
 function named(c:ConfigPanel,action:String,name:String):Void {
  name=StringTools.trim(name).substr(0,80); if(name.length==0) { message="Enter a layout name."; return; }
  retain(c);
  switch(action) {
   case "Rename":
    if(bank.layouts.exists(name) && name!=bank.active) { message="A layout with that name already exists."; return; }
    var old=bank.active; var rows=bank.layouts.get(old); var index=bank.order.indexOf(old);
    bank.layouts.remove(old); bank.order[index]=name; bank.layouts.set(name,rows); bank.active=name;
   default: bank.add(name,bank.layouts.get(bank.active));
  }
  message=action+" complete · "+bank.active; SettingsStore.markDirty();
 }
 function remove(c:ConfigPanel):Void {
  if(bank.order.length<=1) return;
  var old=bank.active; bank.layouts.remove(old); bank.order.remove(old); bank.active=bank.order[0];
  HudLayoutBindings.apply(c,bank.layouts.get(bank.active)); message="Deleted "+old+"."; SettingsStore.markDirty();
 }
 function importClipboard(c:ConfigPanel):Void {
  try {
   var raw=ImGui.getClipboardText(); var text=raw==null ? "" : ByteUtil.readString(raw,1048577,true);
   // Parse into a temporary bank first; invalid input cannot even save outgoing edits.
   var temporary=new HudLayoutModel(); var key=temporary.importText(text); var rows=temporary.layouts.get(key);
   retain(c); key=bank.add(key,rows);
   var missing=HudLayoutBindings.apply(c,rows); message="Imported "+key+" · "+missing+" unmatched widgets.";
   SettingsStore.markDirty();
  } catch(e:Dynamic) { message="Import failed: "+Std.string(e); ToastManager.error(message); }
 }
 public function draw(c:ConfigPanel):Void {
  if(!open.get()) return;
  EditorWindow.drawMenuWindow("UI Layouts###SolarFlare.UiLayouts",open,560,420,function() {
   FeatureProfiles.drawToolbar(c,"layouts","ui_layouts");
   UiChrome.heading("UI Layouts");
   ImGui.textWrapped("Positions and sizes belong to the selected profile. Skills, visibility and glow settings stay in the profile.");
   UiLayout.propertyGrid("##ui_layout_properties",function() {
    UiLayout.propertyRow("Selected layout",function() {
     if(ImGui.beginCombo("##ui_layout_select",bank.active)) {
      try { for(name in bank.order) if(ImGui.selectable(name,name==bank.active)) { var chosen=name; UiActionQueue.custom(function() select(c,chosen)); } }
      catch(e:Dynamic) { ImGui.endCombo(); throw e; }
      ImGui.endCombo();
     }
    });
   });
   UiLayout.inlineSplit("##ui_layout_actions",4,function(i,w) {
    switch(i) {
     case 0: if(UiChrome.ghostButton("New##ui_layout_new",ImGui.vec2(w,28))) { nameAction="New"; ByteUtil.clearBytes(nameBuf,96); }
     case 1: if(UiChrome.ghostButton("Save##ui_layout_save",ImGui.vec2(w,28))) UiActionQueue.custom(function() { retain(c); SettingsStore.saveNow(); message="Saved "+bank.active+"."; });
     case 2: if(UiChrome.ghostButton("Copy##ui_layout_copy",ImGui.vec2(w,28))) UiActionQueue.custom(function() { retain(c); bank.add(bank.active+" (Copy)",bank.layouts.get(bank.active)); SettingsStore.markDirty(); });
     case 3: if(UiChrome.ghostButton("Rename##ui_layout_rename",ImGui.vec2(w,28))) { nameAction="Rename"; ByteUtil.clearBytes(nameBuf,96); }
    }
   });
   if(nameAction.length>0) {
    UiLayout.propertyGrid("##ui_layout_name_properties",function() UiLayout.propertyRow("Layout name",function() ImGui.inputText("##ui_layout_name",nameBuf,96)));
    UiLayout.inlinePair("##ui_layout_name_actions",function(w) {
     if(UiChrome.ghostButton("Apply##ui_layout_name_apply",ImGui.vec2(w,26))) {
      var requested=ByteUtil.readBytes(nameBuf,96); var action=nameAction; nameAction="";
      UiActionQueue.custom(function() named(c,action,requested));
     }
    },function(w) { if(UiChrome.ghostButton("Cancel##ui_layout_name_cancel",ImGui.vec2(w,26))) clearTransientState(); });
   }
   UiLayout.inlineSplit("##ui_layout_io",3,function(i,w) {
    if(i==0) {
     ImGui.beginDisabled(bank.order.length<=1);
     var clicked=UiChrome.ghostButton("Delete##ui_layout_delete",ImGui.vec2(w,28)); ImGui.endDisabled();
     if(clicked) UiActionQueue.custom(function() remove(c));
    } else if(i==1) {
     if(UiChrome.ghostButton("Import##ui_layout_import",ImGui.vec2(w,28))) UiActionQueue.custom(function() importClipboard(c));
    } else if(UiChrome.ghostButton("Export##ui_layout_export",ImGui.vec2(w,28))) UiActionQueue.custom(function() {
     retain(c); ImGui.setClipboardText(bank.exportSelected()); message="Layout share key copied to clipboard.";
    });
   });
   if(message.length>0) ImGui.textWrapped(message);
   ImGui.textDisabled("Import accepts Base64 or JSON. Export copies a Base64 share key.");
  });
 }
}
