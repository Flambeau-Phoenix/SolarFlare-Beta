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
 public function new() {}
 public function dump():Dynamic return {readyMode:readyMode,cooldownMode:cooldownMode,color:color,auraStyle:auraStyle,strength:strength,outer:outer,inner:inner};
 public function apply(data:Dynamic):Void {
  readyMode=1; cooldownMode=1; color=0xFFC040; auraStyle="proc"; strength=1; outer=12; inner=0;
  if(data==null) return;
  readyMode=Std.int(number(data,"readyMode",1,0,3)); cooldownMode=Std.int(number(data,"cooldownMode",1,0,2));
  color=Std.int(number(data,"color",0xFFC040,0,0xFFFFFF));
  var style=Reflect.field(data,"auraStyle"); auraStyle=AuraGlowStyle.normalize(Std.isOfType(style,String) ? style : "proc");
  strength=number(data,"strength",1,0,2); outer=number(data,"outer",12,0,96); inner=number(data,"inner",0,0,96);
 }
 static function number(data:Dynamic,key:String,fallback:Float,lo:Float,hi:Float):Float {
  var value:Dynamic=Reflect.field(data,key);
  return (Std.isOfType(value,Float) || Std.isOfType(value,Int)) && Math.isFinite(value) ? Math.max(lo,Math.min(hi,value)) : fallback;
 }
 public function reach(size:Float):Float {
  return switch(readyMode) {
   case SkillAttentionPolicy.AURA: AuraGlowStyle.reach(auraStyle,outer)+3;
   case SkillAttentionPolicy.PULSE: Math.min(24,size*0.35)+3;
   case SkillAttentionPolicy.BRIGHT: Math.min(16,size*0.2)+3;
   default: 4;
  };
 }
}
