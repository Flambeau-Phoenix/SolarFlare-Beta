package solarflare.barter;
import solarflare.barter.BarTerWeaponLayouts.BarTerNativeSkill;

/** Native input identity follows the assigned skill, independent of its cell position. */
class BarTerBindingResolver {
 /** Unreadable is explained in the tooltip, never rendered as a guessed key. */
 public static function badgeLabel(text:String):String {
  if (text==null || text.length==0 || text=="Unknown") return "";
  return text=="Unbound" ? "-" : primaryLabel(text);
 }
 /** Chip text: first binding, with the engine's long mouse names shortened to fit a cell. */
 public static function primaryLabel(text:String):String {
  var split=text.indexOf(" / "); var first=split < 0 ? text : text.substr(0,split);
  first=StringTools.replace(first,"Mouse Left","LMB");
  first=StringTools.replace(first,"Mouse Right","RMB");
  first=StringTools.replace(first,"Mouse Middle","MMB");
  first=StringTools.replace(first,"Mouse Back","Mouse4");
  return StringTools.replace(first,"Mouse Forward","Mouse5");
 }
 public static function find(id:String,skills:Array<BarTerNativeSkill>):BarTerNativeSkill {
  for (s in skills) if (s.id == id) return s;
  return null;
 }
 public static function resolve(id:String,action:String,skills:Array<BarTerNativeSkill>):BarTerNativeSkill {
  if (action.length == 0) return find(id,skills);
  for (s in skills) if (s.id == id && s.action == action) return s;
  // Saved provenance can outlive a class reassignment. Use only another CURRENT observation of this skill.
  if (StringTools.startsWith(action,"Skill") || StringTools.startsWith(action,"ClassSkill") || action == "SignatureSkill") {
   var current=find(id,skills);
   if (current != null && (StringTools.startsWith(current.action,"Skill") || current.action == "SignatureSkill")) return current;
  }
  return null;
 }
}
