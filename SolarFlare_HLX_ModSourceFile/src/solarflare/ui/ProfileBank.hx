package solarflare.ui;

typedef OwnedProfile = {
 var id:String;
 var name:String;
 var ownerHeroId:String;
 var sourceId:String;
 var snapshot:Dynamic;
}

/** Pure persistence and ownership policy. No native objects and no live configuration defaults. */
class ProfileBank {
 public static inline var VERSION=2;
 public static inline var FACTORY_VERSION=1;
 public var profiles:Map<String,OwnedProfile>=new Map();
 public var order:Array<String>=[];
 public var defaults:Map<String,String>=new Map();
 public var active:String="";
 public var legacyRecovery:Dynamic=null;
 public var extraRecovery:Dynamic=null;
 public var compatibilityPending:Bool=false;
 public var compatibilitySnapshot:Dynamic=null;
 /** Runtime selections survive maps/reconnects, but never override defaults after a restart. */
 var sessionActive:Map<String,String>=new Map();
 var compatibilityAssigned:Array<String>=[];
 var factory:Dynamic;
 var nextId:Int=1;
 public function new(factory:Dynamic) this.factory=copy(factory);
 public static function copy(v:Dynamic):Dynamic return v==null ? null : haxe.Json.parse(haxe.Json.stringify(v));
 public static function heroId(v:Dynamic):String {
  if(!Std.isOfType(v,String)) return "";
  var s:String=cast v;
  if(s.length==0 || s=="0" || s=="null" || s=="undefined" || s.length>256 || s.indexOf("\n")>=0 || s.indexOf("\r")>=0 || StringTools.trim(s)!=s) return "";
  return s;
 }
 /** Arrays are atomic, including explicit empty arrays. Only absent schema members receive defaults. */
 public static function normalize(value:Dynamic,base:Dynamic,path:String=""):Dynamic {
  if(value==null) return copy(base);
  if(["modules","chromes","placements","artwork","auraCounter"].indexOf(path.split(".").pop())>=0) return copy(value);
  if(base==null || Std.isOfType(value,Array) || Std.isOfType(base,Array)
   || !Reflect.isObject(value) || Std.isOfType(value,String) || !Reflect.isObject(base) || Std.isOfType(base,String)) return copy(value);
  var out=copy(value);
  // An explicit empty map is a collection value, not a missing schema block.
  if(Reflect.fields(value).length==0 && Reflect.fields(base).length==0) return out;
  for(k in Reflect.fields(base)) Reflect.setField(out,k,Reflect.hasField(value,k) && Reflect.field(value,k)!=null
   ? normalize(Reflect.field(value,k),Reflect.field(base,k),path=="" ? k : path+"."+k) : copy(Reflect.field(base,k)));
  return out;
 }
 public function normalized(id:String):Dynamic {
  var p=profiles.get(id); if(p==null) throw "Missing profile";
  return normalize(p.snapshot,factory);
 }
 function insert(name:String,owner:String,snapshot:Dynamic,source:String=""):String {
  var id="p"+(nextId++); while(profiles.exists(id)) id="p"+(nextId++);
  profiles.set(id,{id:id,name:name,ownerHeroId:owner,sourceId:source,snapshot:copy(snapshot)}); order.push(id); return id;
 }
 public function create(hero:String,name:String,snapshot:Dynamic=null):String {
  if(heroId(hero)=="") throw "Character unavailable";
  return insert(uniqueName(hero,name),hero,snapshot==null ? factory : snapshot);
 }
 function uniqueName(hero:String,name:String):String {
  var candidate=name; var n=2;
  while(true) {
   var exists=false; for(p in profiles) if(p.ownerHeroId==hero && p.name==candidate) { exists=true; break; }
   if(!exists) return candidate;
   candidate=name+" ("+(n++)+")";
  }
 }
 public function ownedCopy(hero:String,id:String):String {
  if(heroId(hero)=="" || !profiles.exists(id)) throw "Invalid profile owner/source";
  var source=profiles.get(id); if(source.ownerHeroId==hero) return id;
  for(key in order) { var p=profiles.get(key); if(p.ownerHeroId==hero && p.sourceId==id) return key; }
  return insert(uniqueName(hero,source.name),hero,source.snapshot,id);
 }
 public function ensureDefault(hero:String):String {
  if(heroId(hero)=="") throw "Invalid hero ID";
  var id=defaults.get(hero); var p=id==null ? null : profiles.get(id);
  if(p!=null && p.ownerHeroId==hero) return id;
  for(key in order) if(profiles.get(key).ownerHeroId==hero) { defaults.set(hero,key); return key; }
  id=create(hero,"Default"); defaults.set(hero,id); return id;
 }
 /** First login per hero uses its default; later visits in this process retain its selected profile. */
 public function login(hero:String):String {
  if(heroId(hero)=="") throw "Invalid hero ID";
  if(compatibilityPending) {
   compatibilityPending=false;
   if(compatibilityAssigned.indexOf(hero)<0) {
    var id=create(hero,"Recovered active setup",compatibilitySnapshot); importExtra(hero,id); defaults.set(hero,id);
   }
  }
  var selected=sessionActive.get(hero); var p=selected==null ? null : profiles.get(selected);
  active=p!=null && p.ownerHeroId==hero ? selected : ensureDefault(hero);
  sessionActive.set(hero,active); return active;
 }
 public function select(hero:String,id:String):String { active=ownedCopy(hero,id); sessionActive.set(hero,active); return active; }
 public function setDefault(hero:String):Void {
  var p=profiles.get(active); if(p==null || p.ownerHeroId!=hero) throw "Profile owner mismatch";
  defaults.set(hero,active);
 }
 public function resetDefault(hero:String):String {
  var id=create(hero,"Default"); defaults.set(hero,id); return id;
 }
 public function remove(hero:String,id:String):String {
  var p=profiles.get(id); if(p==null || p.ownerHeroId!=hero) throw "Only character-owned profiles can be deleted";
  profiles.remove(id); order.remove(id);
  if(defaults.get(hero)==id) { defaults.remove(hero); ensureDefault(hero); }
  if(active==id) active=ensureDefault(hero);
  sessionActive.set(hero,active);
  return active;
 }
 public function store(hero:String,snapshot:Dynamic):Void {
  var p=profiles.get(active); if(p==null || p.ownerHeroId!=hero) throw "Profile owner mismatch";
  // Retain unknown fields for forward compatible round trips.
  p.snapshot=retainUnknown(snapshot,p.snapshot);
  sessionActive.set(hero,active);
 }
 static function retainUnknown(value:Dynamic,old:Dynamic):Dynamic {
  if(value==null || old==null || Std.isOfType(value,Array) || Std.isOfType(old,Array)
   || !Reflect.isObject(value) || Std.isOfType(value,String) || !Reflect.isObject(old) || Std.isOfType(old,String)) return copy(value);
  if(Reflect.fields(value).length==0) return {};
  var out=copy(value);
  for(k in Reflect.fields(old)) {
   if(!Reflect.hasField(value,k)) Reflect.setField(out,k,copy(Reflect.field(old,k)));
   else Reflect.setField(out,k,retainUnknown(Reflect.field(value,k),Reflect.field(old,k)));
  }
  return out;
 }
 /** `share` keeps references into `data` (no deep copies): only for a throwaway bank used to validate parsed text. */
 public function load(data:Dynamic,lastSaved:Dynamic,extra:Dynamic=null,legacyRoot:Dynamic=null,width:Float=1920,height:Float=1080,share:Bool=false):Void {
  var own=function(v:Dynamic):Dynamic return share ? v : copy(v);
  profiles.clear(); defaults.clear(); sessionActive.clear(); order=[]; active=""; nextId=1;
  compatibilityAssigned=[]; compatibilityPending=false; compatibilitySnapshot=null; legacyRecovery=null; extraRecovery=null;
  if(data!=null && Reflect.hasField(data,"version")) {
   if(data.version!=VERSION || data.factoryVersion!=FACTORY_VERSION || !Std.isOfType(data.records,Array) || !Std.isOfType(data.characterDefaults,Array)) throw "Unsupported or damaged profile bank";
   var rows:Array<Dynamic>=data.records;
   for(r in rows) {
    if(r==null || !Std.isOfType(r.id,String) || r.id.length==0 || profiles.exists(r.id) || !Std.isOfType(r.name,String)
     || !Std.isOfType(r.ownerHeroId,String) || (r.ownerHeroId!="" && heroId(r.ownerHeroId)=="") || r.snapshot==null) throw "Invalid profile record";
    var p:OwnedProfile={id:r.id,name:r.name,ownerHeroId:r.ownerHeroId,sourceId:Std.isOfType(r.sourceId,String) ? r.sourceId : "",snapshot:own(r.snapshot)};
    profiles.set(p.id,p); order.push(p.id);
    if(~/^p[0-9]+$/.match(p.id)) { var number=Std.parseInt(p.id.substr(1)); if(number!=null && number>=nextId && number<2147483646) nextId=number+1; }
   }
   if(Std.isOfType(data.nextId,Int) && data.nextId>nextId && data.nextId<2147483647) nextId=data.nextId;
   var bindings:Array<Dynamic>=data.characterDefaults;
   for(r in bindings) {
    var hero=heroId(r.heroId); var p=Std.isOfType(r.profileId,String) ? profiles.get(r.profileId) : null;
    if(hero=="" || defaults.exists(hero) || p==null || p.ownerHeroId!=hero) throw "Invalid character default";
    defaults.set(hero,p.id);
   }
   active=Std.isOfType(data.active,String) ? data.active : "";
   if(active!="" && !profiles.exists(active)) throw "Invalid active profile";
   compatibilityPending=data.compatibilityPending==true; compatibilitySnapshot=own(data.compatibilitySnapshot);
   compatibilityAssigned=Std.isOfType(data.compatibilityAssigned,Array) ? own(data.compatibilityAssigned) : [for(h in defaults.keys()) h];
   legacyRecovery=own(data.legacyRecovery); extraRecovery=own(data.extraRecovery);
   if(compatibilityPending && compatibilitySnapshot==null) throw "Missing compatibility snapshot";
  } else {
   legacyRecovery=copy(data); extraRecovery=copy(extra);
   var oldToNew=new Map<String,String>();
   var saved=data==null ? null : Reflect.field(data,"profiles");
   if(saved!=null) for(name in Reflect.fields(saved)) {
    var id="legacy-"+haxe.crypto.Md5.encode(name);
    var snapshot=copy(Reflect.field(saved,name));
    if(legacyRoot!=null) {
     var root=copy(legacyRoot); Reflect.deleteField(root,"extraBars"); Reflect.deleteField(root,"extraBarsPlacement");
     var layouts=HudLayoutModel.load(Reflect.field(snapshot,"uiLayouts"),HudLayoutModel.legacy(snapshot,width,height,name==data.active ? root : null));
     if(!layouts.saveSafe) throw layouts.loadWarning;
     Reflect.setField(snapshot,"uiLayouts",layouts.dump());
     for(field in ["auxiliary","extraBars","extraBarsPlacement"]) if(!Reflect.hasField(snapshot,field) && lastSaved!=null && Reflect.hasField(lastSaved,field)) Reflect.setField(snapshot,field,copy(Reflect.field(lastSaved,field)));
    }
    profiles.set(id,{id:id,name:name,ownerHeroId:"",sourceId:"",snapshot:snapshot}); order.push(id); oldToNew.set(name,id);
   }
   if(data!=null && Std.isOfType(data.characterProfiles,Array)) {
    var rows:Array<Dynamic>=data.characterProfiles;
    for(row in rows) if(Std.isOfType(row.uid,String) && StringTools.startsWith(row.uid,"hero:")) {
     var uidText:String=cast row.uid; var hero=heroId(uidText.substr(5)); var id=oldToNew.get(row.profile);
     if(hero!="" && id!=null) defaults.set(hero,ownedCopy(hero,id));
    }
   }
   active=data==null ? "" : oldToNew.get(data.active); if(active==null) active="";
   compatibilityAssigned=[for(h in defaults.keys()) h];
   // Every known ExtraBars-only hero also receives a private fallback. The recovery bank stops being a writer.
   if(extraRecovery!=null && Std.isOfType(extraRecovery.characters,Array)) {
    var rows:Array<Dynamic>=extraRecovery.characters;
    for(row in rows) {
     var hero=heroId(row.id); if(hero=="") throw "Invalid legacy ExtraBars hero ID";
     var id=ensureDefault(hero); importExtra(hero,id);
    }
   }
   compatibilityPending=lastSaved!=null; compatibilitySnapshot=copy(lastSaved);
   if(compatibilitySnapshot!=null && legacyRoot!=null && profiles.exists(active)) compatibilitySnapshot.uiLayouts=copy(profiles.get(active).snapshot.uiLayouts);
  }
  validate();
 }
 /** Legacy ExtraBars storage is recovery input only. Explicit profile layout rows always win. */
 function importExtra(hero:String,id:String):Void {
  if(extraRecovery==null || !Std.isOfType(extraRecovery.characters,Array)) return;
  var rows:Array<Dynamic>=extraRecovery.characters;
  for(row in rows) if(row.id==hero) {
   var s=profiles.get(id).snapshot;
   Reflect.setField(s,"extraBars",copy(row.config)); Reflect.setField(s,"extraBarsPlacement",copy(row.placement));
   var positions=HudLayoutModel.legacy({extraBars:row.config,extraBarsPlacement:row.placement});
   var bank=HudLayoutModel.load(Reflect.field(s,"uiLayouts"),positions);
   if(!bank.saveSafe) throw bank.loadWarning;
   Reflect.setField(s,"uiLayouts",bank.dump()); return;
  }
 }
 public function validate():Void {
  for(id in order) {
   var p=profiles.get(id); if(p==null || p.snapshot==null || !Reflect.isObject(p.snapshot) || Std.isOfType(p.snapshot,String) || Std.isOfType(p.snapshot,Array)) throw "Invalid profile snapshot";
   var layouts=Reflect.field(p.snapshot,"uiLayouts");
   if(layouts!=null && !HudLayoutModel.load(layouts,[]).saveSafe) throw "Invalid saved profile layout";
  }
  for(hero in defaults.keys()) { var p=profiles.get(defaults.get(hero)); if(p==null || p.ownerHeroId!=hero) throw "Invalid profile assignment"; }
 }
 /**
  * `share` returns references to the live records instead of deep copies. Use it only when the result is serialized
  * immediately and never mutated (the settings save): a copy of 20 profiles is a JSON stringify+parse of megabytes.
  */
 public function dump(share:Bool=false,pruneRecovery:Bool=false):Dynamic {
  validate(); var heroes=[for(h in defaults.keys()) h]; heroes.sort(Reflect.compare);
  var own=function(v:Dynamic):Dynamic return share ? v : copy(v);
  // Migration recovery payloads are write-only once migration has finished (nothing reads them back), and the caller
  // vouches that a byte-exact .bak of the pre-migration file exists. They stay while a compatibility login is pending.
  var drop=pruneRecovery && !compatibilityPending;
  return {version:VERSION,factoryVersion:FACTORY_VERSION,nextId:nextId,active:active,records:[for(id in order) own(profiles.get(id))],
   characterDefaults:[for(h in heroes) {heroId:h,profileId:defaults.get(h)}],legacyRecovery:drop ? null : own(legacyRecovery),extraRecovery:drop ? null : own(extraRecovery),
   compatibilityPending:compatibilityPending,compatibilitySnapshot:drop ? null : own(compatibilitySnapshot),compatibilityAssigned:compatibilityAssigned.copy()};
 }
}
