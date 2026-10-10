package solarflare.barter;
import solarflare.barter.BarTerWeaponLayouts.BarTerNativeSkill;

/** Native input identity follows the assigned skill, independent of its cell position. */
class BarTerBindingResolver {
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
  return null;
 }
}
