package solarflare.barter;

import solarflare.geaux.GeauxCache;

/** Observe-phase click submission through the native client controller. */
class BarTerSkillActivation {
 public static function request(skillId:String, action:String, hero:Dynamic):{success:Bool, message:String} {
  skillId=GeauxCache.sanitizeSkillId(skillId);
  action=action == null ? "" : StringTools.trim(action);
  if (hero == null || (skillId.length == 0 && action.length == 0))
   return {success:false,message:"No active skill or action."};
  var label=skillId.length > 0 ? skillId : action;
  try {
   var h:ent.Hero=cast hero;
   var pc=client.PlayerController.inst;
   if (pc == null || pc.get_hero() != h)
    return {success:false,message:"Local skill controller unavailable."};
   var skill:st.skill.Skill=null;
   var managed=BarTerWeaponLayouts.normalize(action);
   if (managed.length>0) {
    var record=BarTerNativeKeys.action(managed);
    if (record==null || !BarTerNativeKeys.current(managed,skillId.length>0 ? skillId : record.id)) return {success:false,message:"Native action observation unavailable: "+label};
    if (record.loadoutKey.length>0 && BarTerLoadoutIdentity.key(hero)!=record.loadoutKey) return {success:false,message:"Weapon combination changed: "+label};
    var current=BarTerNativeAccess.read(hero,managed,null,true);
    if (!current.readable || current.effective==null || BarTerNativeAccess.definition(current.effective)!=record.id || BarTerNativeAccess.definition(current.base)!=record.baseId)
     return {success:false,message:"Skill binding changed: "+label};
    skill=current.effective; action=managed;
   }
   else if (action.length > 0) {
    skill=GeauxCache.skillByInput(h,action);
    if (skill == null && isCoreAction(action))
     return {success:false,message:"Skill binding unavailable: "+label};
    if (skill != null && skillId.length > 0 && !GeauxCache.skillMatches(skill,skillId))
     return {success:false,message:"Skill binding changed: "+label};
   }
   if (skill == null && skillId.length > 0) skill=GeauxCache.liveSkill(skillId);
   var owner:Dynamic=skill == null ? null : skill.owner;
   if (skill == null || owner != hero || skill.removed || (managed.length==0 && skillId.length > 0 && !BarTerNativeAccess.matchesDefinition(skill,skillId)))
    return {success:false,message:"Skill unavailable: "+label};
   var reason=pc.requestSkill(skill,action.length > 0 ? action : skillId);
   if (reason == null) return {success:false,message:"Skill request returned no result: "+label};
   if (!reason.isOk()) return {success:false,message:"Cannot use "+label+": "+reason.getConstructorName()};
   return {success:true,message:"Requested "+label};
  } catch (e:Dynamic) {
   return {success:false,message:"Failed: "+Std.string(e)};
  }
 }
 static function isCoreAction(action:String):Bool {
  return action == "WeaponSkill1" || action == "WeaponSkill2" || action == "WeaponSkill3"
   || action == "WeaponSkill4" || action == "Attack" || action == "Secondary";
 }
}
