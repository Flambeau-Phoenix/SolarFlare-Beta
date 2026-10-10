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
   if (action.length > 0) {
    try skill=h.getSkillByInput(action) catch (_:Dynamic) {}
    if (skill == null && isCoreAction(action))
     return {success:false,message:"Skill binding unavailable: "+label};
    if (skill != null && skillId.length > 0 && !GeauxCache.skillMatches(skill,skillId))
     return {success:false,message:"Skill binding changed: "+label};
   }
   if (skill == null && skillId.length > 0) skill=GeauxCache.liveSkill(skillId);
   var owner:Dynamic=skill == null ? null : skill.owner;
   if (skill == null || owner != hero || (skillId.length > 0 && !GeauxCache.skillMatches(skill,skillId)))
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
