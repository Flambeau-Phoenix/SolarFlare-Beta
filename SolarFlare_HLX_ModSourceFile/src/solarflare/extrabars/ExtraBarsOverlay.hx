package solarflare.extrabars;

import imgui.ImGui;
import imgui.Enums.ImGuiStyleVar;
import solarflare.ui.HudChrome;
import solarflare.ui.HUDWidgetWindow;
import solarflare.ui.SettingsStore;
import solarflare.extrabars.ExtraBarsConfig.ExtraBarsBarConfig;

/** Draws frozen cells only; clicks are queued for the observation tick. */
class ExtraBarsOverlay {
 public function new() {}
 public function draw(bar:ExtraBarsBarConfig, slots:Array<ExtraBarsPrototypeSlot>, chrome:HudChrome,
   edit:Void->Void, hide:Void->Void, click:Int->Void):Void {
  var w:Single = ExtraBarsLayout.width(bar.columns,bar.slotSize);
  var h:Single = ExtraBarsLayout.height(bar.slotCount,bar.columns,bar.slotSize);
  ImGui.pushStyleVar(ImGuiStyleVar.Alpha,bar.opacity);
  try {
   HUDWidgetWindow.draw("SolarFlare.ExtraBars."+bar.id,bar.name,chrome,w,h,function(_) {
    var origin = ImGui.getCursorScreenPos(); var dl = ImGui.getWindowDrawList();
    for (i in 0...bar.slotCount) {
     var x:Single = origin.x+(i%bar.columns)*(bar.slotSize+4);
     var y:Single = origin.y+Std.int(i/bar.columns)*(bar.slotSize+4);
     ImGui.setCursorScreenPos(ImGui.vec2(x,y));
     var pressed = ImGui.invisibleButton("##use_"+bar.id+"_"+i,ImGui.vec2(bar.slotSize,bar.slotSize));
     ExtraBarsPrototypeBar.drawItem(dl,slots[i],x,y,bar.slotSize);
     if (ImGui.isItemHovered()) ImGui.setTooltip(slots[i].name+"\n"+slots[i].binding+"\n"+(slots[i].reason.length>0?slots[i].reason:"Click to request use."));
     if (pressed && click != null) click(i);
    }
    var state = slots[0];
    ExtraBarsPrototypeBar.drawKeyBadge(dl,w>=88?state.inputLabel:(state.inputActive?"ON":"OFF"),origin.x+2,origin.y+h-18,state.inputActive?0xFF75D855:0xFF777777,w-4,true);
    ImGui.setCursorScreenPos(origin); ImGui.dummy(ImGui.vec2(w,h));
   },edit,hide,false,null,function(width:Single,height:Single) {
    bar.slotSize = ExtraBarsLayout.resized(bar.slotCount,bar.columns,width,height); SettingsStore.markDirty();
   });
  } catch(e:Dynamic) { ImGui.popStyleVar(); throw e; }
  ImGui.popStyleVar();
 }
}
