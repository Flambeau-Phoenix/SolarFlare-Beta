package solarflare.barter;

import hlx.runtime.ResolvedMember;

typedef BarTerSlotRead = {
 var available:Bool; var readable:Bool; var count:Int;
 var values:Array<Dynamic>; var reason:String; var arrayType:String;
}
typedef BarTerClassContext = {
 var hero:Dynamic; var replicated:BarTerSlotRead; var mirror:BarTerSlotRead; var rebuilding:Bool;
}
typedef BarTerClassBoundary = {
 var replicatedType:String; var replicatedReadable:Bool; var replicatedCount:Int;
 var mirrorType:String; var mirrorReadable:Bool; var mirrorIds:Array<String>; var itemReads:Int; var getterCalls:Int;
}

/** Foreign objects stay on the observation stack. Only native member descriptors are cached. */
class BarTerClassSlots {
 static var arrayGetters:Map<String,ResolvedMember>=new Map();
 static var skillGetter:ResolvedMember;
 public static var itemReads(default,null):Int=0;
 public static var getterCalls(default,null):Int=0;
 static function typeName(value:Dynamic):String {
  #if hl
  return hl.Type.getDynamic(value).getTypeName();
  #else
  return Type.getClassName(Type.getClass(value));
  #end
 }
 public static function array(array:Dynamic):BarTerSlotRead {
  var out:BarTerSlotRead={available:array!=null,readable:false,count:0,values:[null,null,null,null],reason:"container_unavailable",arrayType:""};
  if(array==null) return out;
  try {
   out.arrayType=typeName(array);
   var count:Dynamic=HlxRuntime.resolveField(array,"length");
   if(!Std.isOfType(count,Int) || count<0 || count>512) { out.reason="array_length_unreadable"; return out; }
   out.count=count;
   var getter=arrayGetters.get(out.arrayType);
   if(getter==null) { getter=HlxRuntime.resolveMember(HlxRuntime.resolveType(out.arrayType),"getDyn"); if(getter!=null) arrayGetters.set(out.arrayType,getter); }
   if(getter==null) { out.reason="array_getter_unavailable"; return out; }
   for(i in 0...Std.int(Math.min(count,4))) {
    itemReads++; out.values[i]=HlxRuntime.callResolved(getter,[array,i]);
   }
   out.readable=true; out.reason="";
  } catch (_:Dynamic) { out.reason="array_read_failed"; }
  return out;
 }
 public static function read(hero:Dynamic):BarTerClassContext {
  itemReads=getterCalls=0;
  var empty=array(null);
  var context:BarTerClassContext={hero:hero,replicated:empty,mirror:empty,rebuilding:false};
  if(hero==null) return context;
  try {
   var spec:Dynamic=HlxRuntime.resolveField(hero,"specialization");
   if(spec!=null) {
    var owner:Dynamic=HlxRuntime.resolveField(spec,"hero");
    if(owner!=null && owner!=hero) context.replicated={available:true,readable:false,count:0,values:[null,null,null,null],reason:"specialization_owner_mismatch",arrayType:""};
    else {
     var proxy:Dynamic=HlxRuntime.resolveField(spec,"skillSlots");
     // Unwrap the replicated proxy once; never unwrap ArrayObj's internal storage.
     var raw:Dynamic=proxy==null ? null : HlxRuntime.resolveField(proxy,"array");
     context.replicated=array(raw);
     if(proxy!=null && raw==null) { context.replicated.available=true; context.replicated.reason="proxy_array_unavailable"; }
    }
   }
  } catch (_:Dynamic) { context.replicated={available:true,readable:false,count:0,values:[null,null,null,null],reason:"specialization_read_failed",arrayType:""}; }
  try context.mirror=array(HlxRuntime.resolveField(hero,"skillSlots")) catch (_:Dynamic) context.mirror={available:true,readable:false,count:0,values:[null,null,null,null],reason:"mirror_read_failed",arrayType:""};
  try context.rebuilding=HlxRuntime.resolveField(hero,"needRefreshSkills")==true catch (_:Dynamic) context.rebuilding=true;
  return context;
 }
 public static function skill(hero:Dynamic,rawIdentifier:Dynamic):Dynamic {
  if(skillGetter==null) skillGetter=HlxRuntime.resolveMember(HlxRuntime.resolveType("ent.GameObject"),"getSkill");
  if(skillGetter==null) throw "skill_getter_unavailable";
  getterCalls++;
  // Passing the original native identifier avoids reboxing it as a mod-local String.
  return HlxRuntime.callResolved(skillGetter,[hero,rawIdentifier]);
 }
}
