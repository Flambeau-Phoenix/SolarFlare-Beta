package solarflare.aura.ui;

import imgui.ImGui;
import solarflare.ui.ByteUtil;
import solarflare.ui.UiLayout;
import solarflare.ui.UiChrome;
import solarflare.ui.UiActionQueue;
import solarflare.aura.AuraShareService;

/** Existing sharing modal content; only cached package metadata and explicit action requests. */
class AuraSharePanel {
 static var scopes:Array<String>=["Aura","Selection","Group","Set","Library"];
 var scope="Aura";
 var file="";
 var path="";
 var pathBuffer=new hl.Bytes(1024);
 var requestedRefresh=false;
 var service:AuraShareService;
 var exportAction:String->Void;
 var inspectAction:String->Void;
 var importAction:String->Void;
 static function label(value:String):String return value;
 public function new(service:AuraShareService,exportAction:String->Void,inspectAction:String->Void,importAction:String->Void) {
  this.service=service; this.exportAction=exportAction; this.inspectAction=inspectAction; this.importAction=importAction;
 }
 public function draw(hasAura:Bool,hasSelection:Bool,hasGroup:Bool,hasSet:Bool):Void {
  if(!requestedRefresh) { service.requestRefresh(); requestedRefresh=true; }
  UiChrome.sectionHeader("Share files with images");
  ImGui.textWrapped("One ZIP carries the Aura artwork and settings. Import it directly without extracting images.");
  ImGui.beginDisabled(service.busy);
  UiLayout.propertyGrid("##aura_share_export",function() {
   UiLayout.propertyRow("Export",function() {
    var chosen=UiLayout.stringCombo("##aura_share_scope",scope,scopes,label);
    if(chosen!=null) scope=chosen;
   });
  });
  var available=switch(scope) { case "Aura": hasAura; case "Selection": hasSelection; case "Group": hasGroup; case "Set": hasSet; default: true; };
  ImGui.beginDisabled(!available);
  if(UiChrome.ghostButton("Export with images##aura_share_export")) exportAction(scope);
  ImGui.endDisabled();
  ImGui.sameLine();
  if(UiChrome.ghostButton("Refresh files##aura_share_refresh")) service.requestRefresh();
  UiLayout.propertyGrid("##aura_share_import",function() {
   UiLayout.propertyRow("Share ZIP",function() {
    var chosen=UiLayout.stringCombo("##aura_share_file",file,service.files,label);
    if(chosen!=null) {
     file=chosen; path=haxe.io.Path.join([service.folder,chosen]); ByteUtil.fillBuf(pathBuffer,1024,path); inspectAction(path);
    }
   });
   UiLayout.propertyRow("Or file path",function() {
    if(ImGui.inputTextWithHint("##aura_share_path","Paste a ZIP path from Downloads...",pathBuffer,1024)) { path=ByteUtil.readBytes(pathBuffer,1024); service.choose(path); }
   });
  });
  ImGui.beginDisabled(StringTools.trim(path).length==0);
  if(UiChrome.ghostButton("Inspect file##aura_share_inspect")) inspectAction(path);
  ImGui.sameLine();
  if(UiChrome.ghostButton("Import share file##aura_share_import")) importAction(path);
  ImGui.sameLine();
  if(UiChrome.ghostButton("Copy path##aura_share_copy")) UiActionQueue.copyText(AuraShareService.cleanPath(path));
  ImGui.endDisabled();
  ImGui.endDisabled();
  if(service.summary.length>0) ImGui.textWrapped(service.summary);
  if(service.busy) {
   ImGui.textDisabled(Std.int(service.progress*100)+"% · "+service.status);
   if(UiChrome.ghostButton("Cancel##aura_share_cancel")) service.cancel();
  } else ImGui.textWrapped(service.status);
  ImGui.textDisabled("Share folder: "+service.folder);
  if(UiChrome.ghostButton("Copy folder path##aura_share_folder")) UiActionQueue.copyText(service.folder);
  if(service.lastExport.length>0) {
   ImGui.sameLine();
   if(UiChrome.ghostButton("Copy exported file path##aura_share_export_path")) UiActionQueue.copyText(service.lastExport);
  }
 }
}
