package solarflare.statusboard;

import imgui.ImGui;
import solarflare.ui.GameIcons;
import solarflare.ui.UiCol;
import solarflare.ui.EnhancedText;

/** Native-style status face, used exclusively by Status Board. */
class StatusBoardRenderer {
 static var rimX:Array<Float>=[0,1,1,1,0,-1,-1,-1,0];
 static var rimY:Array<Float>=[-1,-1,0,1,1,1,0,-1,-1];
 public static function draw(dl:Dynamic,v:StatusBoardVisual,x:Single,y:Single,size:Single,band:Single):Void {
  var s=v.snapshot; var iconY:Single=y+band; var white=UiCol.rgb(0xFFFFFF);
  var font=ImGui.getFont(); var pushed=false;
  if (font != null) { ImGui.pushFont(font,StatusBoardLayout.textSize(size)); pushed=true; }
  try {
   if (v.timer.length>0) {
    text(dl,v.timer,x,y,size,white,true);
   }
   // Match the reference's square, thin neutral frame rather than SolarFlare's accent chrome.
   ImGui.ImDrawList_AddRectFilled(dl,ImGui.vec2(x,iconY),ImGui.vec2(x+size,iconY+size),UiCol.rgb(0x161616,180));
   var pad:Single=Math.max(1,size*0.06);
   if (!GameIcons.drawKey(dl,s.iconKey,x+pad,iconY+pad,size-pad*2,size-pad*2))
    EnhancedText.shadowed(dl,ImGui.vec2(x+pad,iconY+size*0.35),v.faceLabel,white);
   var left=StatusBoardState.seconds(s,haxe.Timer.stamp());
   if (s.nativeProgressVisible && s.durationKnown && !s.infinite && s.totalDur>0 && left>0) {
    var remaining=Math.max(0,Math.min(1,left/s.totalDur));
    var sweep=(1-remaining)*Math.PI*2;
    var cx:Single=x+size/2; var cy:Single=iconY+size/2; var half=(size-pad*2)/2;
    // A triangle fan remains correct beyond a half-circle; a convex polygon fill does not.
    var full=Std.int(Math.floor(sweep/(Math.PI/4)));
    for (i in 0...full) {
     ImGui.ImDrawList_AddTriangleFilled(dl,ImGui.vec2(cx,cy),ImGui.vec2(cx+rimX[i]*half,cy+rimY[i]*half),ImGui.vec2(cx+rimX[i+1]*half,cy+rimY[i+1]*half),UiCol.rgb(0x000000,125));
    }
    if (full<8) {
     var angle=-Math.PI/2+sweep; var cos=Math.cos(angle); var sin=Math.sin(angle); var radius=half/Math.max(Math.abs(cos),Math.abs(sin));
     ImGui.ImDrawList_AddTriangleFilled(dl,ImGui.vec2(cx,cy),ImGui.vec2(cx+rimX[full]*half,cy+rimY[full]*half),ImGui.vec2(cx+cos*radius,cy+sin*radius),UiCol.rgb(0x000000,125));
    }
   }
   ImGui.ImDrawList_AddRect(dl,ImGui.vec2(x,iconY),ImGui.vec2(x+size,iconY+size),UiCol.rgb(0xB9B9A4),0,Math.max(1,size/40));
   if (v.stacks.length>0) {
    text(dl,v.stacks,x+pad,iconY+pad,size-pad*2,white,false);
   }
  } catch (e:Dynamic) { if (pushed) ImGui.popFont(); throw e; }
  if (pushed) ImGui.popFont();
 }
 static function text(dl:Dynamic,value:String,x:Single,y:Single,width:Single,color:Int,center:Bool):Void {
  var measured=ImGui.calcTextSize(value); var font=ImGui.getFont(); var smaller=false;
  if (font != null && measured.x>width-1) { ImGui.pushFont(font,ImGui.getFontSize()*Math.max(0.01,(width-1)/measured.x)); smaller=true; measured=ImGui.calcTextSize(value); }
  try { EnhancedText.shadowed(dl,ImGui.vec2(x+(center ? (width-measured.x)*0.5 : width-measured.x),y),value,color,UiCol.rgb(0x000000,230)); }
  catch(e:Dynamic) { if (smaller) ImGui.popFont(); throw e; }
  if (smaller) ImGui.popFont();
 }
}
