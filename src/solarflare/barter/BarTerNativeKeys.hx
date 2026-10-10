package solarflare.barter;
import solarflare.barter.BarTerWeaponLayouts.BarTerNativeSkill;
import solarflare.geaux.GeauxCache;

/** Observe-only effective native bindings, associated with real HUD actions. */
class BarTerNativeKeys {
 public static var skills:Array<BarTerNativeSkill>=[];
 public static var known:Bool=false;
 static var aliases:Map<String,String>=new Map();
 static var mouseKeys:Map<Int,String>=new Map();
 static var lastRead:Float=-1;
 static var lastSeen:Map<String,Float>=new Map();
 public static function reset():Void { skills.resize(0); aliases.clear(); lastSeen.clear(); known=false; lastRead=-1; }
 /**
  * True when the worn loadout does not provide this native action (weapon swap, empty slot).
  * Grace period keeps a cell on screen across the engine's brief array refreshes.
  */
 public static function actionAbsent(action:String,now:Float):Bool {
  // Only weapon-bound actions change with the worn loadout; class skills never hide.
  if (!(action == "Attack" || action == "Secondary" || StringTools.startsWith(action,"WeaponSkill"))) return false;
  if (!known || BarTerNativeKeys.action(action) != null) return false;
  var seen=lastSeen.get(action);
  return seen == null || now-seen > 1.5;
 }
 public static function sample(now:Float,force:Bool=false):Void {
  if (!force && now-lastRead < 0.5) return;
  lastRead=now; skills.resize(0); aliases.clear(); known=false;
  var hero:Dynamic=solarflare.HealthCache.localHero;
  if (hero == null) return;
  if (!mouseKeys.keys().hasNext()) {
   try {
    var type=HlxRuntime.resolveType("hxd.Key");
    for (entry in [{name:"MOUSE_LEFT",label:"LMB"},{name:"MOUSE_RIGHT",label:"RMB"},
     {name:"MOUSE_MIDDLE",label:"MMB"},{name:"MOUSE_BACK",label:"Mouse4"},{name:"MOUSE_FORWARD",label:"Mouse5"}]) {
     var code:Null<Int>=HlxRuntime.resolveStaticField(type,entry.name);
     if (code != null) mouseKeys.set(code,entry.label);
    }
   } catch(_:Dynamic) {}
  }
  for (pair in GeauxCache.nativeActionPairs) {
   for (s in GeauxCache.barSnaps()) if (s.present && s.id == pair.id && pair.action.length > 0) {
    append(pair.action,s.id,s.label,s.iconId); break;
   }
  }
  // These are the complete accepted inputs in the current Hero.getSkillByInput.
  // Use the same script identity as the telemetry cache, never a parallel kind ID.
  for (actionName in ["WeaponSkill1","WeaponSkill2","WeaponSkill3","WeaponSkill4","Attack","Secondary"]) {
   try {
    var h:ent.Hero=cast hero;
    var skill:st.skill.Skill=h.getSkillByInput(actionName);
    if (skill == null) continue;
    var id=GeauxCache.getSkillId(skill);
    if (id == null || id.length == 0) id=solarflare.EngineText.cleanId(skill.kind);
    if (id == null || id.length == 0) continue;
    if (!GeauxCache.isBarSkillId(id)) continue;
    var existing=action(actionName);
    if (existing != null) { existing.id=id; existing.icon=id; existing.label=label(id); }
    else append(actionName,id,label(id),id);
    rememberAliases(id,skill);
   } catch(_:Dynamic) {}
  }
  // Class skills, resolved the way Geaux does: hero.skillSlots[N-1] is the skill id shown in HUD slot SkillN
  // (ent.Hero.getSkillByType with SkillType.Skill). findSkillById + preferScriptId give the same identity
  // Geaux snapshots use, so the cell finds its cooldown and label.
  try {
   var hc:ent.Hero=cast hero;
   var slots=hc.skillSlots;
   var count=slots == null ? 0 : slots.length;
   for (n in 0...(count < 4 ? count : 4)) {
    var slotId=GeauxCache.sanitizeSkillId(slots.getDyn(n));
    if (slotId.length == 0) continue;
    var skill:Dynamic=GeauxCache.findSkillById(hero,slotId);
    var id=skill != null ? GeauxCache.preferScriptId(slotId,skill) : slotId;
    id=GeauxCache.sanitizeSkillId(id);
    if (id.length == 0 || !GeauxCache.isBarSkillId(id)) continue;
    var actionName="Skill"+(n+1);
    var existing=action(actionName);
    if (existing != null) { existing.id=id; existing.icon=id; existing.label=label(id); }
    else append(actionName,id,label(id),id);
    if (skill != null) rememberAliases(id,skill);
   }
  } catch(_:Dynamic) {}
  // Missing input metadata does not remove an observed skill or its cooldown.
  for (s in GeauxCache.barSnaps()) if (s.present && find(s.id) == null)
   append("",s.id,s.label,s.iconId);
  for (s in skills) {
   rememberAliases(s.id,GeauxCache.liveSkill(s.id));
   if (s.action.length > 0) { known=true; lastSeen.set(s.action,now); }
  }
  skills=BarTerWeaponLayouts.populationOrder(skills);
 }
 static function label(id:String):String {
  var text=solarflare.cdb.AuraCatalog.label(id); return text.length > 0 ? text : id;
 }
 static function rememberAliases(id:String,skill:Dynamic):Void {
  if (skill == null) return;
  try {
   var typed:st.skill.Skill=cast skill;
   var kind=solarflare.EngineText.cleanId(typed.kind);
   if (kind.length > 0) aliases.set(kind,id);
  } catch(_:Dynamic) {}
 }
 static function append(action:String,id:String,text:String,icon:String):Void {
  var binding=action.length > 0 ? readBinding(action) : {text:"Unknown",known:false};
  var iconId=icon.length > 0 ? icon : id; solarflare.ui.GameIcons.get(iconId);
  skills.push({action:action,id:id,label:text.length > 0 ? text : id,icon:iconId,keyText:binding.text,keyKnown:binding.known});
 }
 /**
  * One plain key per action. The engine lets a player pick a single key with no modifiers, so only the
  * first keyboard/mouse binding is read (gamepad entries have no code). lib.Input.getBindingText is
  * not used: it returns "?" for any action that also has a gamepad binding.
  */
 static function readBinding(action:String):{text:String,known:Bool} {
  try {
   var bindings=lib.Input.getBindings(action);
   if (bindings == null || bindings.length < 0 || bindings.length > 32) return {text:"Unknown",known:false};
   // getBindings returns a shared scratch array; consume it before another call.
   for (i in 0...bindings.length) {
    var raw=bindings.getDyn(i);
    if (raw == null) continue;
    var code:Null<Int>=HlxRuntime.resolveField(raw,"code");
    if (code == null) continue;
    var key="";
    try key=solarflare.EngineText.cleanId(lib.Input.getKeyName(code)) catch(_:Dynamic) {}
    if (key.length == 0 || key == "?") key=mouseKeys.exists(code) ? mouseKeys.get(code) : plainKeyName(code);
    if (key.length > 0) return {text:key,known:true};
   }
   return {text:"Unbound",known:true};
  } catch(_:Dynamic) { return {text:"Unknown",known:false}; }
 }
 /** Last resort for codes the engine localizer cannot name (hxd.Key codes are ASCII for letters/digits). */
 static function plainKeyName(code:Int):String {
  if (code >= 65 && code <= 90) return String.fromCharCode(code);
  if (code >= 48 && code <= 57) return String.fromCharCode(code);
  if (code >= 112 && code <= 123) return "F"+(code-111);
  if (code >= 96 && code <= 105) return "Num"+(code-96);
  return switch(code) {
   case 32: "Space"; case 9: "Tab"; case 13: "Enter"; case 27: "Esc"; case 16: "Shift"; case 17: "Ctrl"; case 18: "Alt";
   case 37: "Left"; case 38: "Up"; case 39: "Right"; case 40: "Down";
   default: "";
  };
 }
 public static function find(id:String):BarTerNativeSkill {
  var exact=BarTerBindingResolver.find(id,skills); if (exact != null) return exact;
  return aliases.exists(id) ? BarTerBindingResolver.find(aliases.get(id),skills) : null;
 }
 public static function resolve(id:String,actionId:String):BarTerNativeSkill {
  var canonical=aliases.exists(id) ? aliases.get(id) : id;
  return BarTerBindingResolver.resolve(canonical,actionId,skills);
 }
 public static function action(action:String):BarTerNativeSkill {
  for (s in skills) if (s.action == action) return s;
  return null;
 }
}
