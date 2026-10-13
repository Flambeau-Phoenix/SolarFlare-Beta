package solarflare.barter;

/** Typed HUD descriptor reader, shared by the observer and native-boundary replays. */
class BarTerNativeSlotAccess {
 #if hl
 static var slotType:hl.Type;
 static function isSlot(node:Dynamic):Bool {
  var type=hl.Type.getDynamic(node); if (slotType!=null) return type.safeCast(slotType);
  var depth=0; while (type.kind==hl.Type.TypeKind.HObj && depth++<16) {
   if (type.getTypeName()=="ui.hud.SkillSlotButton") { slotType=type; return true; } type=type.getSuper();
  }
  return false;
 }
 #end
 public static function read(node:Dynamic,action:String,hero:Dynamic):{readable:Bool,base:Dynamic,effective:Dynamic} {
  if (node==null || hero==null) return {readable:false,base:null,effective:null};
  try {
   #if hl
   if (!isSlot(node)) return {readable:false,base:null,effective:null};
   #else
   if (!Std.isOfType(node,ui.hud.SkillSlotButton)) return {readable:false,base:null,effective:null};
   #end
   var slot:ui.hud.SkillSlotButton=node;
   if (slot.unit!=hero || BarTerWeaponLayouts.normalize(solarflare.EngineText.cleanId(slot.input))!=action)
    return {readable:false,base:null,effective:null};
   var isClass=StringTools.startsWith(action,"Skill");
   if (isClass && (slot.index!=Std.parseInt(action.substr(5))-1 || slot.skillType<8 || slot.skillType>11))
    return {readable:false,base:null,effective:null};
   if (action=="SignatureSkill") {
    if (slot.skillType!=BarTerSignatureSlot.TYPE || slot.index!=0) return {readable:false,base:null,effective:null};
    var current=BarTerNativeAccess.read(hero,action);
    var prepared=slot.skill;
    if (prepared!=null && (!BarTerNativeAccess.owned(prepared,hero) || BarTerNativeAccess.definition(prepared)!=BarTerNativeAccess.definition(current.base)))
     return {readable:false,base:null,effective:null};
    return {readable:current.readable,base:current.base,effective:current.effective};
   }
   var index=slot.index; var base:Dynamic;
   #if hl
   if (isClass) base=slot.skill;
   else { var object:ent.GameObject=hero; base=object.getActiveSkillByType(slot.skillType,new hl.Ref<Int>(index)); }
   #else
   base=isClass ? slot.skill : (cast hero:ent.Hero).getSkillByType(slot.skillType,index);
   #end
   if (base!=null && !BarTerNativeAccess.owned(base,hero)) return {readable:false,base:null,effective:null};
   if (base!=null && ((cast base:st.skill.Skill).inf.flags & 4096)!=0) base=null;
   var effective:Dynamic=base; var over=slot.getOverrideSkill(); if (over!=null) effective=over;
   if (base!=null && !BarTerNativeAccess.owned(base,hero) || effective!=null && !BarTerNativeAccess.owned(effective,hero))
    return {readable:false,base:null,effective:null};
   return {readable:true,base:base,effective:effective};
  } catch (_:Dynamic) { return {readable:false,base:null,effective:null}; }
 }
}
