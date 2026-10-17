package solarflare.ui;

import hlx.runtime.ResolvedMember;
import solarflare.FieldWalk;

/** Live engine access is confined to observation; game arrays use the shared accessor. */
class WindowAutoHideEngine implements WindowAutoHideSource {
 var getMode:ResolvedMember;
 var modeInit=false;
 var modeArgs:Array<Dynamic>=[null];
 public function new() {}
 public function gui(app:Dynamic):Dynamic return app==null ? null : HlxRuntime.resolveField(app,"gui");
 public function windows(gui:Dynamic):Dynamic return HlxRuntime.resolveField(gui,"windows");
 public function count(list:Dynamic):Int return FieldWalk.arrayLen(list,-1);
 public function at(list:Dynamic,index:Int):Dynamic return FieldWalk.arrayAt(list,index);
 public function isOpen(window:Dynamic):Bool {
  if(HlxRuntime.resolveField(window,"parent")==null) return false;
  var node=window;
  for(depth in 0...16) {
   var visible:Dynamic=HlxRuntime.resolveField(node,"visible");
   if(visible==null) throw "Window visibility unavailable";
   if(visible==false) return false;
   node=HlxRuntime.resolveField(node,"parent");
   if(node==null) return true;
  }
  throw "Window ancestry exceeds bound";
 }
 public function classify(window:Dynamic):Int {
  var type=hl.Type.getDynamic(window);
  for(depth in 0...16) {
   if(type==null || type.kind!=hl.Type.TypeKind.HObj) break;
   var kind=WindowAutoHidePolicy.kindOfType(type.getTypeName());
   if(kind!=WindowAutoHidePolicy.OTHER) return kind;
   type=type.getSuper();
  }
  return WindowAutoHidePolicy.OTHER;
 }
 public function travelMode(window:Dynamic):Bool {
  if(!modeInit) {
   modeInit=true;
   var type=HlxRuntime.resolveType("ui.win.MapWindow");
   if(type!=null) getMode=HlxRuntime.resolveMember(type,"get_mode");
  }
  var mode:Dynamic=null;
  if(getMode!=null) {
   modeArgs[0]=window;
   try { mode=HlxRuntime.callResolved(getMode,modeArgs); }
   catch(e:Dynamic) { modeArgs[0]=null; throw e; }
   modeArgs[0]=null;
  } else mode=HlxRuntime.resolveField(window,"mode");
  if(mode==null) throw "Map mode unavailable";
  return WindowAutoHidePolicy.hidesForMapMode(Type.enumConstructor(cast mode));
 }
 public function obeliskDialog(window:Dynamic):Bool {
  var element:Dynamic=HlxRuntime.resolveField(window,"currentElement");
  if(element==null) return false;
  var type=hl.Type.getDynamic(element);
  for(depth in 0...16) {
   if(type==null || type.kind!=hl.Type.TypeKind.HObj) break;
   if(type.getTypeName()=="ent.interactible.Obelisk") return true;
   type=type.getSuper();
  }
  return false;
 }
 public function reset():Void { getMode=null; modeInit=false; modeArgs[0]=null; }
}
