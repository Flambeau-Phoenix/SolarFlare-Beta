package solarflare.aura;

/** Native-free, production import planning. Never mutates the supplied package or recipient. */
class AuraSharePlan {
 public static function prepare(pack:Dynamic,auraIds:Array<String>,groupIds:Array<String>,setIds:Array<String>):Dynamic {
  AuraSharePackage.validatePack(pack);
  var auras:Array<Dynamic>=cast pack.auras; var groups:Array<Dynamic>=cast pack.groups; var sets:Array<Dynamic>=cast pack.sets;
  if(auras.length+auraIds.length>32) throw "Import needs "+auras.length+" free Aura slots; "+(32-auraIds.length)+" available.";
  if(groups.length+groupIds.length>32) throw "Not enough free display-group slots for the complete package.";
  if(sets.length+setIds.length>32) throw "Not enough free set slots for the complete package.";
  var copy=AuraSharePackage.clone(pack);
  var takenAuras=new Map<String,Bool>(); for(id in auraIds) takenAuras.set(id,true);
  var takenGroups=new Map<String,Bool>(); for(id in groupIds) takenGroups.set(id,true);
  var takenSets=new Map<String,Bool>(); for(id in setIds) takenSets.set(id,true);
  var groupMap=new Map<String,String>(); var setMap=new Map<String,String>();
  var rows:Array<Dynamic>=cast copy.groups;
  for(row in rows) { var prior:String=row.id; row.id=allocate(prior,takenGroups,160); groupMap.set(prior,row.id); }
  rows=cast copy.sets;
  for(row in rows) { var prior:String=row.id; row.id=allocate(prior,takenSets,31); setMap.set(prior,row.id); }
  rows=cast copy.auras;
  for(row in rows) {
   row.id=allocate(row.id,takenAuras,160);
   row.group=row.group==null || row.group=="" ? "" : groupMap.get(row.group);
   row.fight=row.fight==null || row.fight=="" ? "" : setMap.get(row.fight);
  }
  return copy;
 }
 static function allocate(base:String,taken:Map<String,Bool>,max:Int):String {
  var root=boundedId(base,max); var id=root; var n=2;
  while(taken.exists(id)) { var suffix="_"+(n++); id=boundedId(root,max-suffix.length)+suffix; }
  taken.set(id,true); return id;
 }
 // Editor buffers are UTF-8 byte-sized. Iterate code points so truncation never cuts a character.
 static function boundedId(value:String,max:Int):String {
  var out=new StringBuf(); var bytes=0;
  for(c in new haxe.iterators.StringIteratorUnicode(value)) {
   var size=c<0x80 ? 1 : c<0x800 ? 2 : c<0x10000 ? 3 : 4;
   if(bytes+size>max) break;
   out.addChar(c); bytes+=size;
  }
  return out.toString();
 }
}
