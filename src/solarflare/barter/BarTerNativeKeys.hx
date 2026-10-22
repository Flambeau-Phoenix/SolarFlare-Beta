package solarflare.barter;
import solarflare.barter.BarTerWeaponLayouts.BarTerNativeSkill;
import solarflare.geaux.GeauxCache;

/** Fixed native-action observation. Catalog/icon aliases never establish presence. */
class BarTerNativeKeys {
 public static var skills:Array<BarTerNativeSkill>=[];
 public static var records:Array<BarTerNativeSkill>=[];
 public static var known:Bool=false;
 public static var weaponReadable:Bool=false;
 public static var classReadable(default,null):Bool=false;
 public static var signatureReadable(default,null):Bool=false;
 public static var classBoundary(default,null):BarTerClassSlots.BarTerClassBoundary=null;
 public static var ownerGeneration(default,null):Int=0;
 public static var observationGeneration(default,null):Int=0;
 public static var epoch(default,null):Int=0;
 /** Set by BarTer: told about each live skill the moment it is read, so cell tooltips share this populate event. */
 public static var skillSeen:String->Dynamic->Dynamic->Void=null;
 public static var lastEntries(default,null):Int=0;
 public static var lastSeconds(default,null):Float=0;
 public static var maxSeconds(default,null):Float=0;
 static var owner:Dynamic;
 static var ownerKey:String="";
 static var lastRead:Float=-1;
 static var byAction:Map<String,BarTerNativeSkill>=new Map();
 static var aliases:Map<String,String>=new Map();
 static var lastSeen:Map<String,Float>=new Map();
 public static inline var HOLD_S:Float=1.5;
 public static function reset():Void {
  skills.resize(0); records.resize(0); byAction.clear(); aliases.clear(); lastSeen.clear(); owner=null; ownerKey=""; known=weaponReadable=false; lastRead=-1; ownerGeneration++; epoch++;
  solarflare.input.NativeActionBindings.reset();
  classReadable=signatureReadable=false; classBoundary=null;
 }
 public static function sample(now:Float,force:Bool=false,loadoutKey:String="",transition:Bool=false):Void {
  var hero:Dynamic=solarflare.HealthCache.localHero;
  if (hero!=owner) { reset(); owner=hero; }
  if (loadoutKey!=ownerKey) { ownerKey=loadoutKey; epoch++; lastRead=-1; }
  if (!force && now-lastRead<(transition ? 0.1 : 0.5)) return;
  lastRead=now; observationGeneration++; skills.resize(0); records.resize(0); aliases.clear(); known=false; weaponReadable=true;
  var started=haxe.Timer.stamp(); lastEntries=0;
  BarTerSignatureSlot.beginPass(); signatureReadable=false;
  if (hero==null) { byAction.clear(); weaponReadable=false; return; }
  var classes=BarTerClassSlots.read(hero);
  classReadable=true;
  for (actionName in BarTerWeaponLayouts.ACTIONS) {
   var previous=byAction.get(actionName);
   var native=BarTerNativeAccess.read(hero,actionName,classes); lastEntries++;
   var state=native.readable ? (native.base==null && native.effective==null ? "absent" : "present") : "unreadable";
   if (BarTerWeaponLayouts.weapon(actionName) && state=="unreadable") weaponReadable=false;
   var row:BarTerNativeSkill={action:actionName,id:"",baseId:"",label:"",icon:"",keyText:"Unknown",keyKnown:false,availability:state,fresh:state=="present",ownerGeneration:ownerGeneration,observationGeneration:observationGeneration,loadoutKey:loadoutKey,selectedId:native.selectedId==null ? "" : native.selectedId,source:native.source==null ? "" : native.source,reason:native.reason==null ? "" : native.reason};
   if (state=="present") {
    row.baseId=BarTerNativeAccess.definition(native.base);
    row.id=BarTerNativeAccess.definition(native.effective);
    row.icon=GeauxCache.sanitizeSkillId(GeauxCache.getSkillId(native.effective));
    // The owner/type-17 reader already proves the signature action. Art aliases cannot veto it.
    if (actionName=="SignatureSkill" && row.icon.length==0) row.icon=row.id;
    if (row.id.length==0 || native.base!=null && row.baseId.length==0 || actionName!="SignatureSkill" && !GeauxCache.isBarSkillId(row.icon)) { row.availability="unreadable"; row.fresh=false; row.reason="presentation_identity_unreadable"; if (BarTerWeaponLayouts.weapon(actionName)) weaponReadable=false; }
    else {
     var name=solarflare.cdb.AuraCatalog.label(row.icon); row.label=name.length>0 ? name : row.id;
     lastSeen.set(actionName,now); known=true;
     GeauxCache.observeNativeSkill(native.effective,row.id);
     if (skillSeen!=null) skillSeen(row.id,native.effective,hero);
     addAlias(row.id,actionName); addAlias(row.baseId,actionName); addAlias(row.icon,actionName);
     try { addAlias(solarflare.EngineText.cleanId((cast native.effective:st.skill.Skill).kind),actionName); } catch (_:Dynamic) {}
     solarflare.ui.GameIcons.get(row.icon);
    }
   }
   if (row.availability=="unreadable" && previous!=null && previous.ownerGeneration==ownerGeneration && (!BarTerWeaponLayouts.weapon(actionName) || previous.loadoutKey==loadoutKey) && previous.id.length>0) {
    var at=lastSeen.get(actionName);
    if (at!=null && now-at<=HOLD_S) { row.id=previous.id; row.baseId=previous.baseId; row.icon=previous.icon; row.label=previous.label; }
   }
   if (row.id.length>0) {
    var b=solarflare.input.NativeActionBindings.read(actionName,hero,now); row.keyText=b.text; row.keyKnown=b.known;
    skills.push(row);
   }
   records.push(row); byAction.set(actionName,row);
   if(actionName=="SignatureSkill") signatureReadable=row.availability!="unreadable";
   if(StringTools.startsWith(actionName,"Skill") && row.availability=="unreadable") classReadable=false;
  }
  classBoundary={replicatedType:classes.replicated.arrayType,replicatedReadable:classes.replicated.readable,replicatedCount:classes.replicated.count,mirrorType:classes.mirror.arrayType,mirrorReadable:classes.mirror.readable,mirrorIds:[for(raw in classes.mirror.values) solarflare.EngineText.cleanId(raw)],itemReads:BarTerClassSlots.itemReads,getterCalls:BarTerClassSlots.getterCalls};
  lastSeconds=haxe.Timer.stamp()-started; if (lastSeconds>maxSeconds) maxSeconds=lastSeconds;
  #if hl
  var metrics=solarflare.runtime.RuntimeMetrics;
  metrics.barterNativeSamples++; metrics.barterNativeEntries=lastEntries; metrics.barterNativeMs=lastSeconds*1000;
  if (metrics.barterNativeMs>metrics.barterNativeMaxMs) metrics.barterNativeMaxMs=metrics.barterNativeMs;
  #end
 }
 /** Explicit check only, prepared in observe. No engine objects or raw native identifiers. */
 public static function checkReport():String {
  var picker=new BarTerNativePickerState(); picker.refresh(records,ownerGeneration,observationGeneration);
  return haxe.Json.stringify({schema:"solarflare.barter-native-check.v1",boundary:
  #if hl "HashLink/HLX" #else "fixture" #end
  ,ownerGeneration:ownerGeneration,observationGeneration:observationGeneration,weaponReadable:weaponReadable,classReadable:classReadable,classBoundary:classBoundary,
  signatureBoundary:{skillType:BarTerSignatureSlot.TYPE,index:0,readable:signatureReadable,getterCalls:BarTerSignatureSlot.getterCalls},
  picker:{actions:[for(r in picker.rows) r.action],signatureIndex:picker.signatureIndex,signatureId:picker.signatureIndex>=0 ? picker.rows[picker.signatureIndex].id : ""},
  entries:[for(r in records) {action:r.action,selectedId:r.selectedId,baseId:r.baseId,effectiveId:r.id,label:r.label,key:r.keyText,keyKnown:r.keyKnown,availability:r.availability,fresh:r.fresh,source:r.source,reason:r.reason}]},null,"  ");
 }
 static function addAlias(id:String,action:String):Void {
  if (id==null || id.length==0) return;
  var existing=aliases.get(id); if (existing==null) aliases.set(id,action); else if (existing!=action) aliases.set(id,"");
 }
 public static function find(id:String):BarTerNativeSkill {
  var actionName=aliases.get(id); return actionName==null || actionName.length==0 ? null : byAction.get(actionName);
 }
 public static function resolve(id:String,actionId:String):BarTerNativeSkill {
  if (actionId.length>0) return action(BarTerWeaponLayouts.normalize(actionId));
  return find(id);
 }
 public static function action(name:String):BarTerNativeSkill { var row=byAction.get(name); return row!=null && row.id.length>0 ? row : null; }
 public static function actionAbsent(name:String,now:Float):Bool { var r=byAction.get(BarTerWeaponLayouts.normalize(name)); return r!=null && r.id.length==0; }
 public static function current(name:String,id:String):Bool { var r=action(name); return r!=null && r.fresh!=false && r.availability=="present" && r.ownerGeneration==ownerGeneration && r.loadoutKey==ownerKey && (id==r.id || id==r.baseId || find(id)==r); }
 /** Legacy pure helper retained for downstream tests; production retention also checks owner/loadout. */
 public static function carryForward(previous:Array<BarTerNativeSkill>,current:Array<BarTerNativeSkill>,seen:Map<String,Float>,now:Float,hold:Float):Array<BarTerNativeSkill> {
  var out:Array<BarTerNativeSkill>=[]; for (p in previous) { var found=false; for (c in current) if (c.action==p.action) found=true; var at=seen.get(p.action); if (!found && at!=null && now-at<=hold) out.push(p); } return out;
 }
}
