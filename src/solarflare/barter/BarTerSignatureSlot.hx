package solarflare.barter;

import hlx.runtime.ResolvedMember;

/** Native center action, independent of HUD visibility. No engine objects are retained. */
class BarTerSignatureSlot {
 public static inline var TYPE:Int=17;
 static var getter:ResolvedMember;
 public static var getterCalls(default,null):Int=0;
 public static function beginPass():Void { getterCalls=0; }
 public static function read(hero:Dynamic):BarTerNativeAccess.BarTerNativeRead {
  var source="native_signature_type";
  try {
   #if hl
   if (!solarflare.HealthCache.isHeroObject(hero)) return {readable:false,base:null,effective:null,source:source,reason:"owner_invalid"};
   #else
   if (!Std.isOfType(hero,ent.Hero)) return {readable:false,base:null,effective:null,source:source,reason:"owner_invalid"};
   #end
   var h:ent.Hero=hero;
   if (h.needRefreshSkills) return {readable:false,base:null,effective:null,source:source,reason:"signature_rebuilding"};
   if (getter==null) getter=HlxRuntime.resolveMember(HlxRuntime.resolveType("ent.GameObject"),"getActiveSkillByType");
   if (getter==null) return {readable:false,base:null,effective:null,source:source,reason:"signature_getter_unavailable"};
   getterCalls++;
   // Native null index means zero; the engine creates its own Ref inside this call.
   var base:Dynamic=HlxRuntime.callResolved(getter,[hero,TYPE,null]);
   if (base!=null) {
    if (!BarTerNativeAccess.owned(base,hero)) return {readable:false,base:null,effective:null,source:source,reason:"ownership_invalid"};
    var skill:st.skill.Skill=base;
    if (skill.inf==null || skill.inf.type!=TYPE) return {readable:false,base:null,effective:null,source:source,reason:"signature_type_mismatch"};
    if ((skill.inf.flags & 4096)!=0) base=null;
    else if (BarTerNativeAccess.definition(base).length==0) return {readable:false,base:null,effective:null,source:source,reason:"signature_identity_unreadable"};
   }
   return {readable:true,base:base,effective:base,selectedId:BarTerNativeAccess.definition(base),source:source,reason:base==null ? "native_absent" : ""};
  } catch (_:Dynamic) { return {readable:false,base:null,effective:null,source:source,reason:"signature_read_failed"}; }
 }
}
