package solarflare.barter;

typedef BarTerNativeSkill = {
 var action:String; var id:String; var label:String; var icon:String; var keyText:String; var keyKnown:Bool;
 @:optional var baseId:String;
 @:optional var availability:String;
 @:optional var ownerGeneration:Int;
 @:optional var observationGeneration:Int;
 @:optional var loadoutKey:String;
 @:optional var fresh:Bool;
 @:optional var selectedId:String;
 @:optional var source:String;
 @:optional var reason:String;
}
typedef BarTerPlacement = {var bar:String; var cell:Int; var action:String; var id:String;}

/** Persist action destinations. Weapon arrangements vary; class/signature destinations are shared. */
class BarTerWeaponLayouts {
 public static var ACTIONS(default,null):Array<String>=["WeaponSkill1","WeaponSkill2","WeaponSkill3","WeaponSkill4","Skill1","Skill2","Skill3","Skill4","SignatureSkill"];
 public var layouts:Map<String,Array<BarTerPlacement>>=new Map();
 public var cleared:Map<String,Bool>=new Map();
 public var shared:Map<String,Array<BarTerPlacement>>=new Map();
 public var omitted:Map<String,Array<String>>=new Map();
 public var sharedOmitted:Map<String,Array<String>>=new Map();
 public var classRecoveryVersion:Map<String,Int>=new Map();
 public var signatureRecoveryVersion:Map<String,Int>=new Map();
 var legacyShared:Map<String,Array<BarTerPlacement>>=new Map();
 var configured:Map<String,Array<BarTerPlacement>>=new Map();
 var configuredShared:Map<String,Array<BarTerPlacement>>=new Map();
 public var activeCount:Int=3;
 public var shortfall(default,null):Int=0;
 public function new() {}
 public static function normalize(action:String):String {
  if (action == null) return "";
  if (StringTools.startsWith(action,"ClassSkill")) action="Skill"+action.substr(10);
  return ACTIONS.indexOf(action)>=0 ? action : "";
 }
 public static function weapon(action:String):Bool return StringTools.startsWith(normalize(action),"WeaponSkill");
 public static function character(key:String):String { var i=key.indexOf("|"); return i<0 ? key : key.substr(0,i); }
 static function rows(bars:Array<BarTerBarConfig>,weapons:Bool):Array<BarTerPlacement> {
  var out:Array<BarTerPlacement>=[]; var seen:Map<String,Bool>=new Map();
  for (b in bars) for (i in 0...b.slots.length) {
   var slot=b.slots[i]; var action=normalize(slot.nativeActionId);
   if (!slot.hasSkill() || action.length==0 || weapon(action)!=weapons || seen.exists(action)) continue;
   seen.set(action,true); out.push({bar:b.id,cell:i,action:action,id:slot.skillId});
  }
  return out;
 }
 public function capture(key:String,bars:Array<BarTerBarConfig>,explicit:Bool=false):Void {
  if (key.length==0) return;
  var w=rows(bars,true); var c=rows(bars,false); var owner=character(key);
  var oldWeapon=layouts.get(key); var oldShared=shared.get(owner);
  if (explicit) {
   var previousWeapon=configured.exists(key) ? configured.get(key) : oldWeapon;
   var previousShared=configuredShared.exists(owner) ? configuredShared.get(owner) : oldShared;
   detectOmissions(key,previousWeapon,w,true);
   detectOmissions(owner,previousShared,c,false);
   var hadWeapon=false; if(previousWeapon!=null) for(p in previousWeapon) if(p.cell>=0) hadWeapon=true;
   var hadShared=false; if(previousShared!=null) for(p in previousShared) if(p.cell>=0) hadShared=true;
   if (w.length==0 && hadWeapon) { omitted.set(key,ACTIONS.slice(0,4)); cleared.set(key,true); }
   if (w.length==0 && c.length==0 && hadShared) sharedOmitted.set(owner,ACTIONS.slice(4));
  }
  configured.set(key,w.copy()); configuredShared.set(owner,c.copy());
  retainPending(key,oldWeapon,w); retainPending(key,oldShared,c);
  layouts.set(key,w); shared.set(owner,c);
  if (w.length>0) cleared.remove(key);
 }
 function retainPending(key:String,previous:Array<BarTerPlacement>,current:Array<BarTerPlacement>):Void {
  if(previous==null) return;
  for(p in previous) if(!suppressed(key,p.action)) { var have=false; for(c in current) if(c.action==p.action) have=true; if(!have) current.push(p); }
 }
 function detectOmissions(key:String,previous:Array<BarTerPlacement>,current:Array<BarTerPlacement>,isWeapon:Bool):Void {
  var map=isWeapon ? omitted : sharedOmitted; var list=map.get(key); if (list==null) list=[];
  if (previous!=null) for (p in previous) if(p.cell>=0) { var found=false; for (c in current) if (p.action==c.action) found=true; if (!found && list.indexOf(p.action)<0) list.push(p.action); }
  for (p in current) list.remove(p.action);
  map.set(key,list);
 }
 function suppressed(key:String,action:String):Bool {
  var list=weapon(action) ? omitted.get(key) : sharedOmitted.get(character(key));
  return list!=null && list.indexOf(action)>=0;
 }
 function usable(key:String):Array<BarTerPlacement> {
  var p=layouts.get(key); return p==null || (p.length==0 && !cleared.exists(key) && !omitted.exists(key)) ? null : p;
 }
 /** Fixed replacements are resolved at restoration, preserving other combinations' saved intent. */
 public function reserve(bar:String,cell:Int):Void {}
 static function native(source:Array<BarTerNativeSkill>,action:String):BarTerNativeSkill {
  for (s in source) if (normalize(s.action)==action && s.availability!="absent" && s.availability!="unreadable") return s;
  return null;
 }
 static function base(s:BarTerNativeSkill):String return s.baseId!=null && s.baseId.length>0 ? s.baseId : s.id;
 function free(bars:Array<BarTerBarConfig>):BarTerPlacement {
  for (n in 0...Std.int(Math.min(activeCount,bars.length))) { var b=bars[n]; for (i in 0...b.slotCount) if (!b.slots[i].hasContent()) return {bar:b.id,cell:i,action:"",id:""}; }
  return null;
 }
 function place(p:BarTerPlacement,bars:Array<BarTerBarConfig>,source:Array<BarTerNativeSkill>):Bool {
  var b:BarTerBarConfig=null; for (bar in bars) if (bar.id==p.bar) b=bar;
  var dest=p;
  if (b==null || p.cell<0 || p.cell>=b.slots.length || b.slots[p.cell].hasContent()) {
   dest=free(bars); if (dest==null) { shortfall++; return false; }
   for (bar in bars) if (bar.id==dest.bar) b=bar;
  }
  var s=native(source,p.action); b.slots[dest.cell].assignNative(p.action,s==null ? p.id : base(s));
  return true;
 }
 function direct(p:BarTerPlacement,bars:Array<BarTerBarConfig>,source:Array<BarTerNativeSkill>):Bool {
  for (b in bars) if (b.id==p.bar && p.cell>=0 && p.cell<b.slots.length && !b.slots[p.cell].hasContent()) {
   var s=native(source,p.action); b.slots[p.cell].assignNative(p.action,s==null ? p.id : base(s)); return true;
  }
  return false;
 }
 /** First certified visit upgrades shared placements from current cells or a matching legacy arrangement. */
 function ensureShared(key:String,bars:Array<BarTerBarConfig>):Void {
  var owner=character(key); if (shared.exists(owner)) return;
  var c=rows(bars,false);
  if (c.length==0) { c=legacyShared.get(key); if (c==null) c=[]; }
  shared.set(owner,c);
 }
 /** Lazy, profile-local recovery. A later user clear must never be undone by polling/restart. */
 public function recoverClassOmissions(key:String,bars:Array<BarTerBarConfig>,readable:Bool=false):Bool {
  if (key.length==0 || !readable) return false;
  var owner=character(key); var version=classRecoveryVersion.get(owner);
  if (version!=null && version>=2) return false;
  ensureShared(key,bars);
  var list=sharedOmitted.get(owner);
  if (list!=null) for (action in ACTIONS.slice(4,8)) list.remove(action);
  classRecoveryVersion.set(owner,2);
  return true;
 }
 function signatureRecovered(key:String):Bool {
  var revision=signatureRecoveryVersion.get(character(key)); return revision!=null && revision>=1;
 }
 /** One exact base match becomes managed; aliases and override-only prayers remain pinned. */
 function adoptSignature(key:String,bars:Array<BarTerBarConfig>,signature:BarTerNativeSkill):Bool {
  if (signature==null || signature.fresh!=true || signature.availability!="present" || signature.baseId==null || signature.baseId.length==0) return false;
  for (b in bars) for (slot in b.slots) if (normalize(slot.nativeActionId)=="SignatureSkill") return false;
  var saved=shared.get(character(key));
  if (saved!=null) for (p in saved) if (p.action=="SignatureSkill" && p.cell>=0) return false;
  for (n in 0...Std.int(Math.min(activeCount,bars.length))) {
   var b=bars[n]; for (i in 0...b.slotCount) {
    var slot=b.slots[i];
    if (slot.hasSkill() && slot.nativeActionId.length==0 && slot.skillId==signature.baseId) {
     slot.nativeActionId="SignatureSkill"; return true;
    }
   }
  }
  return false;
 }
 /** Independent of class recovery and Undo. Called only after owner/weapon certification. */
 public function recoverSignatureOmission(key:String,bars:Array<BarTerBarConfig>,signature:BarTerNativeSkill):Bool {
  if (key.length==0 || signatureRecovered(key) || signature==null || signature.fresh!=true || signature.availability!="present" || signature.baseId==null || signature.baseId.length==0) return false;
  ensureShared(key,bars);
  var owner=character(key); var list=sharedOmitted.get(owner); if (list!=null) list.remove("SignatureSkill");
  if (adoptSignature(key,bars,signature)) capture(key,bars);
  signatureRecoveryVersion.set(owner,1);
  return true;
 }
 public function restore(key:String,previous:String,bars:Array<BarTerBarConfig>,source:Array<BarTerNativeSkill>,complete:Bool):Bool {
  if (!complete || key.length==0) return false;
  ensureShared(key,bars); shortfall=0;
  var template=usable(key);
  if (template==null && character(previous)==character(key)) {
   template=usable(previous); var oldOmitted=omitted.get(previous);
   if (oldOmitted!=null) omitted.set(key,oldOmitted.copy());
   if (cleared.exists(previous)) cleared.set(key,true);
  }
  if (template==null) template=rows(bars,true);
  for (b in bars) for (slot in b.slots) if (normalize(slot.nativeActionId).length>0) slot.clearContent();
  var pending:Array<BarTerPlacement>=[];
  var displaced:Array<BarTerPlacement>=[];
  for (p in shared.get(character(key))) if (!suppressed(key,p.action) && !direct(p,bars,source)) displaced.push(p);
  for (p in displaced) if (!place(p,bars,source)) pending.push(p);
  displaced.resize(0);
  for (p in template) if (!suppressed(key,p.action) && !direct(p,bars,source)) displaced.push(p);
  // Reserve non-conflicting saved destinations before finding space for displaced actions.
  for (p in displaced) if (!place(p,bars,source)) pending.push(p);
  seedMissing(key,bars,source,pending);
  capture(key,bars);
  savePending(key,pending);
  return true;
 }
 function savePending(key:String,pending:Array<BarTerPlacement>):Void {
  for(p in pending) {
   var list=weapon(p.action) ? layouts.get(key) : shared.get(character(key));
   var have=false; for(row in list) if(row.action==p.action) have=true;
   if(!have) list.push(p);
  }
 }
 function seedMissing(key:String,bars:Array<BarTerBarConfig>,source:Array<BarTerNativeSkill>,pending:Array<BarTerPlacement>):Int {
  var wrote=0;
  var have:Map<String,Bool>=new Map();
  for (b in bars) for (slot in b.slots) if (normalize(slot.nativeActionId).length>0) have.set(normalize(slot.nativeActionId),true);
  for (p in pending) have.set(p.action,true);
  for (s in populationOrder(source)) {
   var action=normalize(s.action); if (action.length==0 || have.exists(action) || suppressed(key,action) || s.availability=="absent" || s.availability=="unreadable" || s.fresh==false) continue;
   if (action=="SignatureSkill" && !signatureRecovered(key) && adoptSignature(key,bars,s)) { have.set(action,true); wrote++; continue; }
   var dest=free(bars); if (dest==null) { shortfall++; pending.push({bar:bars.length>0 ? bars[0].id : "",cell:-1,action:action,id:base(s)}); continue; }
   dest.action=action; dest.id=base(s); place(dest,bars,source); have.set(action,true); wrote++;
  }
  return wrote;
 }
 /** Repair only managed cells. Fixed catalog/item/status cells remain untouched. */
 public function repair(key:String,bars:Array<BarTerBarConfig>,source:Array<BarTerNativeSkill>,fill:Bool=true):Int {
  var seen:Map<String,Bool>=new Map(); var changed=0;
  for (b in bars) for (slot in b.slots) {
   var action=normalize(slot.nativeActionId); if (action.length==0) { if (slot.nativeActionId.length>0) { slot.nativeActionId=""; changed++; } continue; }
   if (seen.exists(action)) { slot.clearContent(); changed++; continue; }
   seen.set(action,true);
   var s=native(source,action);
   if (slot.nativeActionId!=action || (s!=null && slot.skillId!=base(s))) { slot.assignNative(action,s==null ? slot.skillId : base(s)); changed++; }
  }
  if (fill) {
   shortfall=0; var pending:Array<BarTerPlacement>=[];
   var old=layouts.get(key); var common=shared.get(character(key));
   for (list in [old,common]) if (list!=null) for (p in list) if (!seen.exists(p.action) && !suppressed(key,p.action)) {
    if (place(p,bars,source)) { seen.set(p.action,true); changed++; } else pending.push(p);
   }
   changed+=seedMissing(key,bars,source,pending);
   if (changed>0 || pending.length>0) { capture(key,bars); savePending(key,pending); }
  }
  return changed;
 }
 public static function populate(bar:BarTerBarConfig,source:Array<BarTerNativeSkill>,bars:Array<BarTerBarConfig>):Int {
  if (bar==null) return 0; var wrote=0;
  for (s in populationOrder(source)) {
   var action=normalize(s.action); if (action.length==0 || s.fresh==false || s.availability=="absent" || s.availability=="unreadable") continue;
   var exists=false; for (b in bars) for (slot in b.slots) if (normalize(slot.nativeActionId)==action) exists=true;
   if (exists) continue;
   for (i in 0...bar.slotCount) if (!bar.slots[i].hasContent()) { bar.slots[i].assignNative(action,base(s)); wrote++; break; }
  }
  return wrote;
 }
 public static function populationOrder(source:Array<BarTerNativeSkill>):Array<BarTerNativeSkill> {
  var out=source.copy(); out.sort(function(a,b) return ACTIONS.indexOf(normalize(a.action))-ACTIONS.indexOf(normalize(b.action))); return out;
 }
 public static function replaceSkills(bar:BarTerBarConfig,source:Array<BarTerNativeSkill>,bars:Array<BarTerBarConfig>):Int {
  if (bar==null || source.length==0) return 0;
  for (i in 0...bar.slotCount) if (bar.slots[i].nativeActionId.length>0) bar.slots[i].clearContent();
  return populate(bar,source,bars);
 }
 public function dump():Dynamic return [for (key in layouts.keys()) {
  key:key,placements:layouts.get(key).concat(!shared.exists(character(key)) && legacyShared.exists(key) ? legacyShared.get(key) : []),cleared:cleared.exists(key),omitted:omitted.get(key)
 }];
 public function dumpShared():Dynamic return [for (owner in shared.keys()) {character:owner,placements:shared.get(owner),omitted:sharedOmitted.get(owner),classRecoveryVersion:classRecoveryVersion.exists(owner) ? classRecoveryVersion.get(owner) : 0,signatureRecoveryVersion:signatureRecoveryVersion.exists(owner) ? signatureRecoveryVersion.get(owner) : 0}];
 /** Undo restores its edited combination, retaining combinations visited since that edit. */
 public function mergeUntouched(current:BarTerWeaponLayouts,editedKey:String):Void {
  for (key in current.layouts.keys()) if (key!=editedKey) { layouts.set(key,current.layouts.get(key)); if(current.cleared.exists(key)) cleared.set(key,true); else cleared.remove(key); var o=current.omitted.get(key); if(o!=null) omitted.set(key,o); else omitted.remove(key); }
  var owner=character(editedKey);
  for (key in current.shared.keys()) if (key!=owner) { shared.set(key,current.shared.get(key)); var o=current.sharedOmitted.get(key); if(o!=null) sharedOmitted.set(key,o); }
  // Recovery is a migration, not an arrangement edit. Undo cannot re-arm it.
  for (key in current.classRecoveryVersion.keys()) {
   var revision=current.classRecoveryVersion.get(key); var old=classRecoveryVersion.get(key);
   if (old==null || old<revision) classRecoveryVersion.set(key,revision);
   if (!shared.exists(key)) shared.set(key,[]);
  }
  for (key in current.signatureRecoveryVersion.keys()) {
   var revision=current.signatureRecoveryVersion.get(key); var old=signatureRecoveryVersion.get(key);
   if (old==null || old<revision) signatureRecoveryVersion.set(key,revision);
   if (!shared.exists(key)) shared.set(key,[]);
  }
 }
 static function parse(data:Dynamic):Array<BarTerPlacement> {
  var out:Array<BarTerPlacement>=[]; if (!Std.isOfType(data,Array)) return out; var rows:Array<Dynamic>=cast data; var seen:Map<String,Bool>=new Map();
  for (p in rows) if (p!=null && Std.isOfType(p.bar,String) && Std.isOfType(p.cell,Int) && p.cell>=-1 && p.cell<64 && Std.isOfType(p.action,String)) {
   var action=normalize(p.action); if (action.length==0 || seen.exists(action)) continue; seen.set(action,true);
   out.push({bar:p.bar,cell:p.cell,action:action,id:Std.isOfType(p.id,String) ? p.id : ""});
  }
  return out;
 }
 static function parseOmissions(data:Dynamic,isWeapon:Bool):Array<String> {
  var out:Array<String>=[]; if (Std.isOfType(data,Array)) { var rows:Array<Dynamic>=cast data; for (v in rows) if (Std.isOfType(v,String)) { var a=normalize(v); if (a.length>0 && weapon(a)==isWeapon && out.indexOf(a)<0) out.push(a); } } return out;
 }
 public function apply(data:Dynamic,sharedData:Dynamic=null):Void {
  layouts.clear(); cleared.clear(); shared.clear(); omitted.clear(); sharedOmitted.clear(); classRecoveryVersion.clear(); signatureRecoveryVersion.clear(); legacyShared.clear(); configured.clear(); configuredShared.clear();
  if (Std.isOfType(data,Array)) { var rows:Array<Dynamic>=cast data;
   for (row in rows) if (row!=null && Std.isOfType(row.key,String) && Std.isOfType(row.placements,Array)) {
    var p=parse(row.placements); layouts.set(row.key,[for (v in p) if (weapon(v.action)) v]); legacyShared.set(row.key,[for (v in p) if (!weapon(v.action)) v]);
    var o=parseOmissions(row.omitted,true); if (o.length>0) omitted.set(row.key,o);
    if (row.cleared==true) { cleared.set(row.key,true); omitted.set(row.key,ACTIONS.slice(0,4)); if (sharedData==null) sharedOmitted.set(character(row.key),ACTIONS.slice(4)); }
   }
  }
  if (Std.isOfType(sharedData,Array)) { var rows:Array<Dynamic>=cast sharedData; for (r in rows) if (r!=null && Std.isOfType(r.character,String)) {
   shared.set(r.character,[for (p in parse(r.placements)) if (!weapon(p.action)) p]); sharedOmitted.set(r.character,parseOmissions(r.omitted,false));
   if (Std.isOfType(r.classRecoveryVersion,Int) && r.classRecoveryVersion>=1) classRecoveryVersion.set(r.character,r.classRecoveryVersion);
   if (Std.isOfType(r.signatureRecoveryVersion,Int) && r.signatureRecoveryVersion>=1) signatureRecoveryVersion.set(r.character,r.signatureRecoveryVersion);
  } }
 }
}
