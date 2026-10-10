package solarflare.statusboard;
import imgui.ImGui;
import solarflare.ui.HUDWidgetWindow;

class StatusBoardOverlay {
 static inline var GAP:Int = 4;
 public function new() {}
 public function draw(cfg:StatusBoardConfig, edit:Void->Void, hide:Void->Void):Void {
  if (cfg == null || !cfg.demand()) return;
  var n=cfg.visible.length;
  if (n == 0 && cfg.chrome.locked.get()) return;
  var unlocked=!cfg.chrome.locked.get();
  var size=StatusBoardLayout.size(n,cfg.slotSize,cfg.columns,unlocked,cfg.contentWidth,cfg.contentHeight);
  var cols=size.columns; var w=size.width; var h=size.height;
  HUDWidgetWindow.draw("SolarFlare.StatusBoard","Statuses",cfg.chrome,w,h,function(_) {
   var origin=ImGui.getCursorScreenPos(); var dl=ImGui.getWindowDrawList();
   if (n == 0) ImGui.textDisabled("Status placement preview");
   for (i in 0...n) {
    var s=cfg.visible[i];
    var x:Single=origin.x+(i%cols)*(cfg.slotSize+GAP);
    var y:Single=origin.y+Std.int(i/cols)*(cfg.slotSize+GAP);
    StatusIcon.draw(dl,s,x,y,cfg.slotSize,cfg.showSeconds,cfg.showStacks);
    ImGui.setCursorScreenPos(ImGui.vec2(x,y));
    ImGui.invisibleButton("##sb_status_"+s.id+"_"+s.sourceItemId,ImGui.vec2(cfg.slotSize,cfg.slotSize));
    if (ImGui.isItemHovered()) ImGui.setTooltip(StatusIcon.tooltip(s));
    if (!cfg.chrome.locked.get() && ImGui.beginPopupContextItem("##sb_menu_"+s.id+"_"+s.sourceItemId)) {
     try { if (ImGui.menuItem("Hide this status")) cfg.hideStatus(s.id); }
     catch(e:Dynamic) { ImGui.endPopup(); throw e; }
     ImGui.endPopup();
    }
   }
   ImGui.setCursorScreenPos(origin); ImGui.dummy(ImGui.vec2(w,h));
  },edit,hide,false,null,function(newW:Single,newH:Single) { cfg.resize(newW,newH,GAP); });
 }
}
