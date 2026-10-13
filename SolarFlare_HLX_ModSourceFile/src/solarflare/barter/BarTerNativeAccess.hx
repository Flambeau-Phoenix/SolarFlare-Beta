package solarflare.barter;

import solarflare.geaux.GeauxCache;
import solarflare.barter.BarTerClassSlots.BarTerClassContext;

typedef BarTerNativeRead = {
 var readable:Bool; var base:Dynamic; var effective:Dynamic;
 @:optional var reason:String; @:optional var selectedId:String; @:optional var source:String;
}

/** Engine objects stay on observation/activation stacks; UI sees detached primitive records. */
class BarTerNativeAccess {
 #if hl
 static var skillType:hl.Type;
 static function isSkill(value:Dynamic):Bool {
  if(value==null) return false;
  try {
   var type=hl.Type.getDynamic(value); if(skillType!=null) return type.safeCast(skillType);
   var depth=0; while(type.kind==hl.Type.TypeKind.HObj && depth++<16) {
    if(type.getTypeName()=="st.skill.Skill") { skillType=type; return true; } type=type.getSuper();
   }
  } catch (_:Dynamic) {}
  return false;
 }
 #end
 static function failed(reason:String,selectedId:String="",source:String=""):BarTerNativeRead
  return {readable:false,base:null,effective:null,reason:reason,selectedId:selectedId,source:source};
 public static function read(hero:Dynamic,action:String,context:BarTerClassContext=null,activating:Bool=false):BarTerNativeRead {
  try {
   if(hero==null) return failed("owner_unavailable");
   if(StringTools.startsWith(action,"Skill")) return classSkill(hero,action,context,activating);
   var h:ent.Hero=hero; var base:Dynamic=null;
   if(BarTerWeaponLayouts.weapon(action)) {
    #if hl
    if(h.weaponSkills==null || h.weaponSkills.length==0 || h.needRefreshSkills) return failed("weapon_rebuilding");
    #else
    if(!h.weaponReady) return failed("weapon_rebuilding");
    #end
    base=h.getSkillByInput(action);
   } else if(action=="SignatureSkill") {
    var signature=BarTerSignatureSlot.read(hero);
    if (!signature.readable) return signature;
    return overridden(hero,action,signature.base,signature.selectedId,signature.source);
   } else return failed("action_invalid");
   if(base!=null && !owned(base,hero)) return failed("ownership_invalid");
   return overridden(hero,action,base,"","native_input");
  } catch (_:Dynamic) { return failed("native_read_failed"); }
 }
 static function classSkill(hero:Dynamic,action:String,context:BarTerClassContext,activating:Bool):BarTerNativeRead {
  var parsed=Std.parseInt(action.substr(5));
  if(parsed==null || parsed<1 || parsed>4 || action!="Skill"+parsed) return failed("action_invalid");
  var n=parsed-1;
  if(context==null) context=BarTerClassSlots.read(hero);
  if(context.hero!=hero) return failed("observation_owner_mismatch");
  var fromSpec=context.replicated.available;
  var slots=fromSpec ? context.replicated : context.mirror;
  var source=fromSpec ? "replicated" : "mirror";
  if(!slots.readable) return failed(slots.reason,"",source);
  if(slots.count==0) return failed("selection_uninitialized","",source);
  if(context.rebuilding && !fromSpec) return failed("selection_rebuilding","",source);
  var raw=slots.values[n]; var selected=solarflare.EngineText.cleanId(raw);
  if(raw!=null && selected.length==0) return failed("selection_identifier_unreadable","",source);
  if(raw==null || selected.length==0) return {readable:true,base:null,effective:null,reason:"selection_empty",selectedId:"",source:source};
  var base:Dynamic=null;
  try base=BarTerClassSlots.skill(hero,raw) catch (_:Dynamic) return failed("skill_getter_failed",selected,source);
  // Mirror IDs can differ from native kinds. A descriptor may supply the exact current object,
  // but an unreadable replicated selection can never fall back to stale HUD content.
  if(base==null && !fromSpec) {
   var observed=GeauxCache.nativeSlotSkill(action,hero);
   if(observed.readable && owned(observed.base,hero) && definition(observed.base)==selected) base=observed.base;
  }
  if(base==null) return failed("selected_skill_unresolved",selected,source);
  if(!owned(base,hero)) return failed("ownership_invalid",selected,source);
  if(fromSpec ? skillKind(base)!=selected : definition(base)!=selected) return failed("selected_identity_mismatch",selected,source);
  if(activating && (context.rebuilding || !context.mirror.readable || solarflare.EngineText.cleanId(context.mirror.values[n])!=definition(base)))
   return failed("native_action_unsettled",selected,source);
  if(((cast base:st.skill.Skill).inf.flags & 4096)!=0) base=null;
  return overridden(hero,action,base,selected,source);
 }
 static function overridden(hero:Dynamic,action:String,base:Dynamic,selected:String,source:String):BarTerNativeRead {
  var effective:Dynamic=base;
  #if hl
  var h:ent.Hero=hero; var over=h.getSkillOverride(action); if(over!=null) effective=over.getEffectiveSkill();
  #else
  effective=(cast hero:ent.Hero).effective(action,base);
  #end
  if(effective!=null && !owned(effective,hero)) return failed("override_invalid",selected,source);
  return {readable:true,base:base,effective:effective,reason:base==null && effective==null ? "native_absent" : "",selectedId:selected,source:source};
 }
 public static function owned(skill:Dynamic,hero:Dynamic):Bool {
  if(skill==null || hero==null) return false;
  #if hl
  if(!isSkill(skill)) return false;
  #end
  try { var s:st.skill.Skill=skill; return s.owner==hero && !s.removed; } catch (_:Dynamic) { return false; }
 }
 public static function definition(skill:Dynamic):String {
  if(skill==null) return "";
  try {
   var s:st.skill.Skill=skill; var id=s.inf==null ? "" : solarflare.EngineText.cleanId(s.inf.id);
   return id.length>0 ? id : solarflare.EngineText.cleanId(s.kind);
  } catch (_:Dynamic) { return ""; }
 }
 static function skillKind(skill:Dynamic):String return solarflare.EngineText.cleanId((cast skill:st.skill.Skill).kind);
 public static function matchesDefinition(skill:Dynamic,id:String):Bool {
  if(definition(skill)==id) return true;
  try return skillKind(skill)==id catch (_:Dynamic) return false;
 }
}
