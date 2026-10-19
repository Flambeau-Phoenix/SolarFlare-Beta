package solarflare.aura;

import solarflare.cdb.StatusTypeCatalog;

/** One subject; resumable entry/type cursor. No engine references escape this observer. */
class StatusTypeObserver {
 public static inline var MAX:Int=512;
 public var generation(default,null):Int=0;
 public var presentMask(default,null):Int=0;
 public var knownMask(default,null):Int=0;
 public var valid(default,null):Bool=false;
 public var lastPassEntries(default,null):Int=0;
 public var lastPassPredicates(default,null):Int=0;
 var source:StatusTypeSource;
 var enemy:Bool;
 var owner:Dynamic;
 var ownerGeneration=-1;
 var mask=0;
 var list:Dynamic;
 var length=-1;
 var cursor=0;
 var typeCursor=0;
 var pending:Dynamic;
 var rowMask=0;
 var scanning=false;
 public function new(source:StatusTypeSource,enemy:Bool) { this.source=source; this.enemy=enemy; }
 function clear():Void {
  presentMask=knownMask=0; valid=false; list=null; length=-1; cursor=typeCursor=rowMask=0; pending=null; scanning=false;
 }
 public function reset():Void {
  if(owner!=null || mask!=0 || valid || knownMask!=0) generation++;
  clear(); owner=null; mask=0; ownerGeneration=-1;
 }
 public function sync(subject:Dynamic,identityGeneration:Int,demand:Int):Void {
  if(demand==0) subject=null;
  if(subject!=owner || identityGeneration!=ownerGeneration || demand!=mask) {
   generation++; clear(); owner=subject; mask=demand; ownerGeneration=identityGeneration;
  }
 }
 public function step(deadline:Float,clock:Void->Float):Void {
  lastPassEntries=lastPassPredicates=0;
  if(owner==null || mask==0 || clock()>=deadline) return;
  try {
   if(!source.validOwner(owner,enemy)) { if(valid || knownMask!=0) generation++; clear(); return; }
   var current=source.container(owner); var size=current==null ? -1 : source.length(current);
   if(size<0) throw "Unreadable status-type container";
   if(!scanning || current!=list || size!=length) {
    clear(); list=current; length=size; scanning=true; valid=true;
   }
   if(pending!=null && source.at(list,cursor)!=pending) { generation++; clear(); return; }
   var limit=length>MAX ? MAX : length;
   while(cursor<limit) {
    if(clock()>=deadline) return;
    if(pending==null) {
     pending=source.at(list,cursor); lastPassEntries++; typeCursor=rowMask=0;
     if(pending==null) throw "Unreadable status-type application";
    }
    var state=source.state(pending);
    if(state<0) throw "Unreadable status-type metadata";
    if(state==0) { pending=null; cursor++; continue; }
    while(typeCursor<StatusTypeCatalog.entries.length) {
     if(clock()>=deadline) return;
     var bit=1<<typeCursor;
     if((mask&bit)!=0 && (presentMask&bit)==0) {
      lastPassPredicates++;
      if(source.matches(pending,StatusTypeCatalog.entries[typeCursor].id)) rowMask|=bit;
     }
     typeCursor++;
    }
    presentMask|=rowMask; knownMask=presentMask;
    pending=null; cursor++;
   }
   knownMask=length<=MAX ? mask : presentMask;
   scanning=false;
  } catch(_:Dynamic) { generation++; clear(); }
 }
}
