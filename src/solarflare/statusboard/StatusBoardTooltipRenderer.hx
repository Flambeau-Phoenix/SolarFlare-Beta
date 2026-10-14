package solarflare.statusboard;

import imgui.ImGui;
import solarflare.ui.UiCol;

/** Draws already parsed/wrapped text. Tooltip hover sends only a primitive instance identity. */
class StatusBoardTooltipRenderer {
 public static inline var WIDTH:Float=340;
 static function measure(text:String):Float return ImGui.calcTextSize(text).x;
 public static function prepare(row:StatusBoardTooltipCache.StatusBoardTooltip):Void {
  if (row == null) return;
  var size=ImGui.getFontSize();
  if (row.layoutSize == size) return;
  var layout=StatusBoardText.layout(row.runs,WIDTH,size+2,measure);
  row.positioned=layout.runs; row.bodyHeight=layout.height; row.layoutSize=size;
  var heading=StatusBoardText.layout([{text:row.title,bold:true,color:null}],WIDTH,size+2,measure);
  row.heading=heading.runs; row.headingHeight=heading.height;
 }
 public static function draw(instanceId:String,fallback:String):Void {
  StatusBoardTooltipCache.request(instanceId,haxe.Timer.stamp(),fallback);
  var row=StatusBoardTooltipCache.get(instanceId);
  if (!ImGui.beginTooltip()) return;
  try {
   var title=row != null && row.title.length>0 ? row.title : fallback;
   var pos=ImGui.getCursorScreenPos(); var dl=ImGui.getWindowDrawList();
   var color=UiCol.rgb(0xFFFFFF);
   if (row != null && row.heading.length>0) {
    for (run in row.heading) {
     ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(pos.x+run.x,pos.y+run.y),color,run.text);
     ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(pos.x+run.x+0.4,pos.y+run.y),color,run.text);
    }
    ImGui.dummy(ImGui.vec2(WIDTH,row.headingHeight+3));
   } else { ImGui.pushTextWrapPos(ImGui.getCursorPos().x+WIDTH); try { ImGui.textWrapped(title); } catch(e:Dynamic) { ImGui.popTextWrapPos(); throw e; } ImGui.popTextWrapPos(); }
   if (row == null) ImGui.textDisabled(StatusBoardTooltipLabels.loading);
   if (row != null) {
    if (row.caption.length>0) ImGui.textDisabled(row.caption);
    pos=ImGui.getCursorScreenPos();
    for (run in row.positioned) {
     var c=run.color == null ? color : run.color;
     ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(pos.x+run.x,pos.y+run.y),c,run.text);
     if (run.bold) ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(pos.x+run.x+0.4,pos.y+run.y),c,run.text);
    }
    if (row.bodyHeight>0) ImGui.dummy(ImGui.vec2(WIDTH,row.bodyHeight));
    if (row.facts.length>0) ImGui.textDisabled(row.facts);
   }
  } catch (e:Dynamic) { ImGui.endTooltip(); throw e; }
  ImGui.endTooltip();
 }
}
