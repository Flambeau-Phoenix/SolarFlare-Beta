package solarflare.statusboard;

import imgui.ImGui;
import solarflare.aura.AuraStatusSnap;
import solarflare.ui.GameIcons;
import solarflare.ui.ThemePalette;

/** Shared by the board and BarTer. Uses prepared identity and frozen timer fields. */
class StatusIcon {
 public static function draw(dl:Dynamic, s:AuraStatusSnap, x:Single, y:Single, size:Single, seconds:Bool = true, stacks:Bool = true, active:Bool = true, fill:Null<Int>=null, border:Null<Int>=null):Void {
  var theme = ThemePalette.current();
  var color = ImGui.colorConvertFloat4ToU32(theme.text);
  ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x,y), ImGui.vec2(x+size,y+size), fill == null ? ImGui.colorConvertFloat4ToU32(theme.windowBg) : fill, 4);
  ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x,y), ImGui.vec2(x+size,y+size), border == null ? ImGui.colorConvertFloat4ToU32(active ? theme.accent : theme.textDisabled) : border, 4, 1);
  var pad:Single = size * 0.1;
  if (!GameIcons.drawKey(dl, s.iconKey, x+pad, y+pad, size-pad*2, size-pad*2, active ? 0xFFFFFFFF : 0x66888888)) {
   var fallback = s.label.length > 0 ? s.label : s.id;
   if (fallback.length > 7) fallback = fallback.substr(0,7);
   ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x+3,y+size*0.35), color, fallback);
  }
  var left = StatusBoardState.seconds(s, haxe.Timer.stamp());
  if (active && s.durationKnown && !s.infinite && s.totalDur > 0 && left > 0) {
   var remaining = Math.max(0, Math.min(1, left / s.totalDur));
   ImGui.ImDrawList_PathClear(dl);
   ImGui.ImDrawList_PathLineTo(dl, ImGui.vec2(x+size/2,y+size/2));
   ImGui.ImDrawList_PathArcTo(dl, ImGui.vec2(x+size/2,y+size/2), size*0.47, -Math.PI/2, -Math.PI/2+(1-remaining)*Math.PI*2, 24);
   ImGui.ImDrawList_PathFillConvex(dl, 0x88000000);
  }
  if (active && seconds && s.durationKnown && !s.infinite) badge(dl,x+size/2,y+size-3,(s.stampSource == "cdb" ? "~" : "")+Std.string(Std.int(Math.ceil(left))),color,true);
  if (active && stacks && s.stacksKnown) badge(dl,x+size-3,y+3,Std.string(s.stacks),color,false);
 }
 static function badge(dl:Dynamic, x:Single, y:Single, value:String, color:Int, bottom:Bool):Void {
  var ts=ImGui.calcTextSize(value);
  var tx:Single=bottom ? x-ts.x/2 : x-ts.x;
  var ty:Single=bottom ? y-ts.y : y;
  ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(tx-2,ty-1),ImGui.vec2(tx+ts.x+2,ty+ts.y+1),0xDD000000,3);
  ImGui.ImDrawList_AddText_Vec2(dl,ImGui.vec2(tx,ty),color,value);
 }
 public static function tooltip(s:AuraStatusSnap):String {
  var tip=(s.label.length > 0 ? s.label : s.id)+"\n"+s.id;
  tip += s.stacksKnown ? "\nStacks: "+s.stacks : "\nStacks unavailable";
  if (!s.durationKnown) tip+="\nDuration unavailable";
  else if (s.infinite) tip+="\nNo expiry";
  else tip+="\n"+(s.stampSource == "cdb" ? "Estimated: " : "Remaining: ")+Math.ceil(StatusBoardState.seconds(s,haxe.Timer.stamp()))+"s";
  if (s.sourceItemId.length > 0) {
   var itemEntry = solarflare.cdb.ConsumableCatalog.find(s.sourceItemId);
   if (itemEntry != null) tip += "\nItem: " + itemEntry.name;
  }
  return tip;
 }
}
