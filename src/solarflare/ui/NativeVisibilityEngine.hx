package solarflare.ui;

import hlx.runtime.ResolvedMember;
import solarflare.FieldWalk;

/** Runtime type gates and exact-arity presentation setters, never used from drawing. */
class NativeVisibilityEngine implements NativeVisibilitySource {
 var types:Map<String,hl.Type>=new Map();
 var ancestry:Array<{type:hl.Type,names:Array<String>}>=[];
 public var ancestryWalks(default,null):Int=0;
 var setter:ResolvedMember;
 var args:Array<Dynamic>=[null,false];
 public function new() {}
 public function field(node:Dynamic,name:String):Dynamic return node==null ? null : HlxRuntime.resolveField(node,name);
 public function childCount(node:Dynamic):Int return FieldWalk.arrayLen(field(node,"children"),-1);
 public function childAt(node:Dynamic,index:Int):Dynamic return FieldWalk.arrayAt(field(node,"children"),index);
 public function matches(node:Dynamic,typeName:String):Bool {
  if(node==null) return false;
  var live=hl.Type.getDynamic(node);
  var type=types.get(typeName);
  if(type!=null) return live.safeCast(type);
  for(entry in ancestry) if(entry.type==live) return entry.names.indexOf(typeName)>=0;
  var concrete=live;
  var names:Array<String>=[];
  // resolveType returns raw hl.Bytes, not a boxed hl.Type: casting those bytes emits
  // a checked Bytes -> Type cast and throws in HashLink. Learn the actual runtime
  // ancestor from a live object, exactly as HealthCache's Hero gate does.
  for(depth in 0...16) {
   if(live==null || live.kind!=hl.Type.TypeKind.HObj) break;
   var name=live.getTypeName();
   names.push(name); types.set(name,live);
   live=live.getSuper();
  }
  ancestryWalks++;
  // Metadata only; no HUD nodes are retained. Bound even malformed/modded type sets.
  if(ancestry.length<128) ancestry.push({type:concrete,names:names});
  return names.indexOf(typeName)>=0;
 }
 public function canHide(node:Dynamic):Bool return matches(node,"ui.UIElement");
 public function visible(node:Dynamic):Bool {
  var value:Dynamic=field(node,"visible");
  if(!Std.isOfType(value,Bool)) throw "Visibility is unavailable";
  return value;
 }
 public function setVisible(node:Dynamic,value:Bool):Void {
  if(!canHide(node)) throw "Not a UIElement";
  if(setter==null) setter=HlxRuntime.resolveMember(HlxRuntime.resolveType("ui.UIElement"),"set_visible");
  if(setter==null) throw "Native visibility setter unavailable";
  args[0]=node; args[1]=value;
  try { HlxRuntime.callResolved(setter,args); }
  catch(e:Dynamic) { args[0]=null; throw e; }
  args[0]=null;
  if(visible(node)!=value) throw "Native visibility write was not applied";
 }
 public function externalChat():Bool return hlx.runtime.Registry.get("mods","enhanced-chat")!=null;
 public function reset():Void { types.clear(); ancestry.resize(0); ancestryWalks=0; setter=null; args[0]=null; }
}
