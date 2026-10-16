package solarflare.geaux;

import imgui.ImGui;
import solarflare.ui.VectorGlow;
import solarflare.ui.UiCol;
import solarflare.aura.AuraGlowRenderer;

/** Shared artwork; no timers, game calls or state mutation. Color is ARGB at this boundary. */
class SkillAttentionRenderer {
 public static function nearReady(dl:Dynamic,x:Single,y:Single,size:Single,time:Float):Void {
  var alpha=0.25+0.25*Math.sin(time*8);
  var color=0x00FFFF|(Std.int(alpha*255)<<24);
  VectorGlow.radial(dl,x+size*0.5,y+size*0.5,size*0.5,color,0.4,4);
 }
 public static function ready(dl:Dynamic,mode:Int,style:String,strength:Float,outer:Float,inner:Float,color:Int,
  x:Single,y:Single,size:Single,rounding:Single,alpha:Float):Void {
  if(alpha<=0 || mode==SkillAttentionPolicy.NONE) return;
  if(mode==SkillAttentionPolicy.AURA) {
   AuraGlowRenderer.drawStyle(dl,style,strength,outer,inner,color,x,y,size,size,alpha); return;
  }
  var packed=UiCol.fromArgb((color & 0xFFFFFF)|(Std.int(((color>>>24)&255)*alpha)<<24));
  if(mode==SkillAttentionPolicy.PULSE) VectorGlow.skillAlertBloom(dl,x,y,size,size,packed,Math.min(24,size*0.35),rounding,14,2.2);
  else if(mode==SkillAttentionPolicy.BRIGHT) VectorGlow.skillAlertBloom(dl,x,y,size,size,packed,Math.min(16,size*0.2),rounding,10,1.85);
 }
 public static function proc(dl:Dynamic,x:Single,y:Single,size:Single,start:Float,now:Float):Void
  VectorGlow.glimmer(dl,x,y,size,size,SkillAttentionPolicy.procPhase(start,now));
 public static function configuredReady(dl:Dynamic,g:SkillAttentionStyle,x:Single,y:Single,size:Single,alpha:Float,time:Float):Void {
  if (alpha<=0 || g.readyMode==0 || g.strength<=0) return;
  var phase=g.pulsing ? 0.55+0.45*Math.abs(Math.sin(time*4*g.speed)) : 1.;
  if (g.readyMode==SkillAttentionPolicy.AURA) {
   // Freeze the style's internal animation in steady mode through the explicit phase argument.
   AuraGlowRenderer.drawStyle(dl,g.auraStyle,g.strength,g.outer,g.inner,g.color|0xFF000000,x,y,size,size,alpha,
    g.pulsing ? time*g.speed : 0.);
  } else {
   var packed=UiCol.rgb(g.color,Std.int(255*Math.min(1,alpha*g.strength)));
   var reach=g.readyMode==1 ? Math.min(24,size*0.35) : Math.min(16,size*0.2);
   VectorGlow.skillAlertBloom(dl,x,y,size,size,packed,reach,4,g.readyMode==1 ? 14 : 10,g.readyMode==1 ? 2.2 : 1.85,phase);
  }
 }
 public static function configuredProc(dl:Dynamic,g:SkillAttentionStyle,x:Single,y:Single,size:Single,start:Float,now:Float):Void {
  switch(g.procMode) {
   case 1: VectorGlow.glimmer(dl,x,y,size,size,(Math.max(0,now-start)*g.speed)%2.6);
   case 2: if(g.strength>0) VectorGlow.rect(dl,x,y,size,size,UiCol.rgb(g.color,Std.int(255*Math.min(1,g.strength))),4,2);
   case 3:
    var phase=g.pulsing ? 0.55+0.45*Math.abs(Math.sin((now-start)*4*g.speed)) : 1.;
    if(g.strength>0) VectorGlow.skillAlertBloom(dl,x,y,size,size,UiCol.rgb(g.color,Std.int(255*Math.min(1,g.strength))),Math.min(24,size*0.35),4,14,2.2,phase);
   default:
  }
 }
}
