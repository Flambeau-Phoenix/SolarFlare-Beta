package solarflare.ui;

/** Bounded production scanner. Only validity/mask/reason leave this observer. */
class WindowAutoHideSampler {
 public static inline var POLL_S:Float=0.25;
 public static inline var MAX_WINDOWS:Int=48;
 public var valid(default,null):Bool=false;
 public var mask(default,null):Int=0;
 public var reason(default,null):String="Auto-hide disabled";
 public var hidden(get,never):Bool;
 inline function get_hidden():Bool return valid && mask!=0;
 var source:WindowAutoHideSource;
 var owner:Dynamic;
 var appOwner:Dynamic;
 var lastPoll:Float=-1e9;
 var lastOptions:Int=-1;
 var objA:Array<Dynamic>=[];
 var kindA:Array<Int>=[];
 var objB:Array<Dynamic>=[];
 var kindB:Array<Int>=[];
 public function new(source:WindowAutoHideSource) { this.source=source; }
 public function reset():Void {
  valid=false; mask=0; reason="Auto-hide disabled"; owner=null; appOwner=null;
  lastPoll=-1e9; lastOptions=-1; clearWindows(); source.reset();
 }
 function clearWindows():Void { objA.resize(0); kindA.resize(0); objB.resize(0); kindB.resize(0); }
 public function observe(app:Dynamic,now:Float,options:Int):Void {
  if(options<0) { if(lastOptions!=-1 || owner!=null) reset(); return; }
  // Check the clock BEFORE crossing into the engine. GUI replacement is picked
  // up by the next 250 ms sample; app/session/options changes remain immediate.
  if(app==appOwner && options==lastOptions && now>=lastPoll && now-lastPoll<POLL_S) return;
  try {
   var gui=source.gui(app);
   if(gui!=owner || app!=appOwner) { reset(); owner=gui; appOwner=app; }
   if(options==lastOptions && now>=lastPoll && now-lastPoll<POLL_S) return;
   lastOptions=options; lastPoll=now;
   if(gui==null) throw "Game UI unavailable";
   var list=source.windows(gui);
   var count=list==null ? -1 : source.count(list);
   if(count<0 || count>MAX_WINDOWS) throw "Open-window list unavailable or exceeds scan limit";
   objB.resize(0); kindB.resize(0);
   var next=0;
   for(i in 0...count) {
    var window=source.at(list,i);
    if(window==null) throw "Unreadable window entry";
    var found=objA.indexOf(window);
    var kind=found>=0 ? kindA[found] : source.classify(window);
    objB.push(window); kindB.push(kind);
    if((kind & options)==0 || !source.isOpen(window)) continue;
    if((kind!=WindowAutoHidePolicy.TRAVEL || source.travelMode(window))
     && (kind!=WindowAutoHidePolicy.OBELISK || source.obeliskDialog(window))) next |= kind;
   }
   var objects=objA; objA=objB; objB=objects; objB.resize(0);
   var kinds=kindA; kindA=kindB; kindB=kinds; kindB.resize(0);
   valid=true; mask=next; reason=WindowAutoHidePolicy.reason(next);
  } catch(_:Dynamic) {
   clearWindows(); source.reset(); valid=false; mask=0; reason="Auto-hide unavailable: could not observe game windows";
  }
 }
}
