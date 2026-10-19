package solarflare.aura;

import solarflare.util.JsonSchema;
import solarflare.ui.HudChrome;
import solarflare.ui.HudLayoutBinding;
import solarflare.ui.HudLayoutModel.HudLayoutRow;

/** Prepares complete copies before the library is touched. The final publish swaps retained collections only. */
@:access(solarflare.aura.AuraConfig)
class AuraShareImport {
 public var added(default,null):Int=0;
 var cfg:AuraConfig;
 var beforeAuras:Array<AuraDef>;
 var beforeSets:Array<AuraSetDef>;
 var beforeGroups:Array<AuraGroupDef>;
 var beforeChromes:Map<String,HudChrome>;
 var auras:Array<AuraDef>;
 var sets:Array<AuraSetDef>;
 var groups:Array<AuraGroupDef>;
 var chromes:Map<String,HudChrome>;
 public static function capture(cfg:AuraConfig,members:Array<AuraDef>,name:String,wholeLibrary:Bool=false):Dynamic {
  if(cfg==null || members==null || members.length==0) throw "Select at least one Aura to export.";
  var rows:Array<Dynamic>=[]; var wantedGroups=new Map<String,Bool>(); var wantedSets=new Map<String,Bool>();
  for(a in members) {
   if(a==null || cfg.auras.indexOf(a)<0) throw "The export selection has changed.";
   var row=AuraEngine.toObjStrict(a); rows.push(row);
   if(a.group!=null && a.group.length>0) wantedGroups.set(a.group,true);
   if(a.fight!=null && a.fight.length>0) wantedSets.set(a.fight,true);
  }
  var groupRows:Array<Dynamic>=[]; var setRows:Array<Dynamic>=[];
  for(g in cfg.groups) if(wholeLibrary || wantedGroups.exists(g.id)) groupRows.push(cfg.dumpGroup(g));
  for(s in cfg.sets) if(wholeLibrary || wantedSets.exists(s.id)) { setRows.push(s.toObj()); wantedSets.remove(s.id); }
  // Legacy encounter tags are portable set definitions, not references into another user's library.
  for(id in wantedSets.keys()) setRows.push(new AuraSetDef(id,id).toObj());
  var pack:Dynamic={kind:AuraPack.KIND,v:AuraPack.VER,id:"share",name:name,auras:rows,groups:groupRows,sets:setRows};
  AuraSharePackage.validatePack(pack);
  return AuraSharePackage.clone(pack);
 }
 public static function preflight(pack:Dynamic,cfg:AuraConfig):Void {
  AuraSharePackage.validatePack(pack);
  var rows:Array<Dynamic>=cast pack.auras; var groupRows:Array<Dynamic>=cast pack.groups; var setRows:Array<Dynamic>=cast pack.sets;
  if(cfg.auras.length+rows.length>AuraEngine.MAX) throw "Import needs "+rows.length+" free Aura slots; "+(AuraEngine.MAX-cfg.auras.length)+" available.";
  if(cfg.groups.length+groupRows.length>AuraGroupDef.MAX) throw "Not enough free display-group slots for the complete package.";
  if(cfg.sets.length+setRows.length>AuraConfig.MAX_SETS) throw "Not enough free set slots for the complete package.";
  for(row in rows) if(JsonSchema.parseAuraImport(haxe.Json.stringify(row))==null) throw "Invalid Aura definition: "+row.name;
 }
 public function new(pack:Dynamic,cfg:AuraConfig) {
  preflight(pack,cfg); this.cfg=cfg;
  beforeAuras=cfg.auras; beforeGroups=cfg.groups; beforeSets=cfg.sets; beforeChromes=cfg.groupChromes;
  auras=cfg.auras.copy(); groups=cfg.groups.copy(); sets=cfg.sets.copy(); chromes=cfg.groupChromes.copy();
  pack=AuraSharePlan.prepare(pack,[for(a in cfg.auras) a.id],[for(g in cfg.groups) g.id],[for(s in cfg.sets) s.id]);
  var groupRows:Array<Dynamic>=cast pack.groups;
  for(row in groupRows) {
   var g=AuraGroupDef.fromObj(row);
   var chrome=new HudChrome(240,240); AuraConfig.applyGroupChrome(chrome,row); chromes.set(g.id,chrome); groups.push(g);
  }
  var setRows:Array<Dynamic>=cast pack.sets;
  for(row in setRows) {
   var s=AuraSetDef.fromObj(row); sets.push(s);
  }
  var rows:Array<Dynamic>=cast pack.auras;
  for(row in rows) {
   var data=row;
   var aura=AuraConfig.fromDyn(data); auras.push(aura); added++;
  }
 }
 public function commit():Void {
  if(cfg.auras!=beforeAuras || cfg.groups!=beforeGroups || cfg.sets!=beforeSets || cfg.auras.length+added!=auras.length)
   throw "The library changed during import. Try again.";
  cfg.auras=auras; cfg.groups=groups; cfg.sets=sets; cfg.groupChromes=chromes; cfg.markSetsDirty();
 }
 /** Seed the active layout with authored geometry before reconciliation can see older orphan rows. */
 public function layoutRows():Array<HudLayoutRow> {
  var rows:Array<HudLayoutRow>=[];
  for(i in beforeAuras.length...auras.length) {
   var a=auras[i]; rows.push(new HudLayoutBinding("aura:"+a.id,a.chrome,a.w,a.h,a.scale).capture());
  }
  for(i in beforeGroups.length...groups.length) {
   var g=groups[i]; rows.push(new HudLayoutBinding("auraGroup:"+g.id,chromes.get(g.id)).capture());
  }
  return rows;
 }
 public function rollback():Void {
  cfg.auras=beforeAuras; cfg.groups=beforeGroups; cfg.sets=beforeSets; cfg.groupChromes=beforeChromes; cfg.markSetsDirty();
 }
}
