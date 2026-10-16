package solarflare.geaux;

import solarflare.aura.AuraGlowStyle;

/** Plain persisted appearance, independent of either feature's enabled state or ImGui refs. */
class SkillAttentionStyle {
 public var readyMode:Int=SkillAttentionPolicy.PULSE;
 public var cooldownMode:Int=SkillAttentionPolicy.CD_DIM;
 public var color:Int=0xFFC040;
 public var auraStyle:String="proc";
 public var strength:Float=1;
 public var outer:Float=12;
 public var inner:Float=0;
 /** 0 off, 1 observed completion flash, 2 continuously usable. */
 public var behavior:Int=1;
 public var flashDuration:Float=15;
 public var fade:Bool=true;
 public var pulsing:Bool=true;
 public var speed:Float=1;
 public var nearEnabled:Bool=true;
 public var nearThreshold:Float=1.2;
 /** 0 off, 1 legacy glimmer, 2 steady outline, 3 continuous pulse. */
 public var procMode:Int=1;
 public function new() {}
 public function dump():Dynamic return {readyMode:readyMode,cooldownMode:cooldownMode,color:color,auraStyle:auraStyle,strength:strength,outer:outer,inner:inner,
  behavior:behavior,flashDuration:flashDuration,fade:fade,pulsing:pulsing,speed:speed,nearEnabled:nearEnabled,nearThreshold:nearThreshold,procMode:procMode};
 public function apply(data:Dynamic):Void {
  readyMode=1; cooldownMode=1; color=0xFFC040; auraStyle="proc"; strength=1; outer=12; inner=0;
  behavior=1; flashDuration=15; fade=true; pulsing=true; speed=1; nearEnabled=true; nearThreshold=1.2; procMode=1;
  if(data==null) return;
  readyMode=Std.int(number(data,"readyMode",1,0,3)); cooldownMode=Std.int(number(data,"cooldownMode",1,0,2));
  color=Std.int(number(data,"color",0xFFC040,0,0xFFFFFF));
  var style=Reflect.field(data,"auraStyle"); auraStyle=AuraGlowStyle.normalize(Std.isOfType(style,String) ? style : "proc");
  strength=number(data,"strength",1,0,2); outer=number(data,"outer",12,0,96); inner=number(data,"inner",0,0,96);
  behavior=Std.int(number(data,"behavior",1,0,2)); flashDuration=number(data,"flashDuration",15,0.1,60);
  fade=Reflect.field(data,"fade")!=false; pulsing=Reflect.field(data,"pulsing")!=false;
  speed=number(data,"speed",1,0.1,4); nearEnabled=Reflect.field(data,"nearEnabled")!=false;
  nearThreshold=number(data,"nearThreshold",1.2,0.1,10); procMode=Std.int(number(data,"procMode",1,0,3));
 }
 static function number(data:Dynamic,key:String,fallback:Float,lo:Float,hi:Float):Float {
  var value:Dynamic=Reflect.field(data,key);
  return (Std.isOfType(value,Float) || Std.isOfType(value,Int)) && Math.isFinite(value) ? Math.max(lo,Math.min(hi,value)) : fallback;
 }
 public function reach(size:Float):Float {
  var reach = switch(readyMode) {
   case SkillAttentionPolicy.AURA: AuraGlowStyle.reach(auraStyle,outer)+3;
   case SkillAttentionPolicy.PULSE: Math.min(24,size*0.35)+3;
   case SkillAttentionPolicy.BRIGHT: Math.min(16,size*0.2)+3;
   default: 4;
  };
  return procMode==3 ? Math.max(reach,Math.min(24,size*0.35)+3) : reach;
 }
}
