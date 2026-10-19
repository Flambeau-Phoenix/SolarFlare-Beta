package solarflare.aura;

import solarflare.aura.signal.StatusSignalSnap;

/** One enemy, bounded slices, first matching application in engine order. No game calls outside source. */
class TargetStatusObserver {
 public static inline var MAX:Int=512;
 public static inline var INTERVAL:Float=0.05;
 public static inline var BUDGET:Float=0.001;
 public var generation(default,null):Int=0;
 public var domainKnown(default,null):Bool=false;
 public var valid(default,null):Bool=false;
 public var count(default,null):Int=0;
 public var snapshots(default,null):Array<StatusSignalSnap>=[];
 public var samples(default,null):Int=0;
 public var lastPassEntries(default,null):Int=0;
 public var lastPassSeconds(default,null):Float=0;
 var source:TargetStatusSource;
 var clock:Void->Float;
 var owner:Dynamic;
 var hero:Dynamic;
 var heroGeneration:Int=-1;
 var list:Dynamic;
 var cursor:Int=0;
 var length:Int=-1;
 var scanning:Bool=false;
 var lastAt:Float=-1e9;
 public function new(source:TargetStatusSource,clock:Void->Float=null) {
  this.source=source; this.clock=clock==null ? haxe.Timer.stamp : clock;
  for (_ in 0...MAX) snapshots.push(new StatusSignalSnap());
 }
 function clearRows():Void {
  for(i in 0...count) snapshots[i].reset();
  count=0; domainKnown=false; scanning=false; list=null; cursor=0; length=-1;
 }
 public function reset():Void {
  if(owner!=null || hero!=null || valid || count>0) generation++;
  clearRows(); owner=null; hero=null; heroGeneration=-1; valid=false; lastAt=-1e9;
 }
 function fail():Void { generation++; clearRows(); valid=false; }
 public function observe(localHero:Dynamic,ownerGeneration:Int,target:Dynamic,now:Float,demanded:Bool):Void {
  lastPassEntries=0; lastPassSeconds=0;
  if(!demanded || localHero==null || !Math.isFinite(now)) { reset(); return; }
  if(owner!=target || hero!=localHero || heroGeneration!=ownerGeneration) {
   generation++; clearRows(); valid=false; owner=target; hero=localHero; heroGeneration=ownerGeneration;
  }
  if(target==null) { valid=false; return; }
  if(now>=lastAt && now-lastAt<INTERVAL-1e-9) return;
  lastAt=now; samples++; var start=clock();
  try {
   if(!source.isEnemy(target) || !source.alive(target)) { if(valid || count>0) fail(); return; }
   var current=source.container(target);
   var n=current==null ? -1 : source.length(current);
   if(n<0) throw "Unreadable enemy status container";
   if(!scanning || current!=list || n!=length) {
    clearRows(); list=current; length=n; scanning=true; valid=true;
   }
   var limit=length>MAX ? MAX : length;
   while(cursor<limit) {
    if(lastPassEntries>0 && clock()-start>=BUDGET) break;
    var application=source.at(list,cursor++); lastPassEntries++;
    if(application==null) throw "Unreadable enemy status application";
    var row=snapshots[count]; row.reset();
    var state=source.read(application,row);
    if(state<0 || (state>0 && row.rawId.length==0)) throw "Unresolved enemy status application";
    if(state>0) { row.observedAt=now; count++; }
   }
   if(cursor>=limit) { scanning=false; domainKnown=length<=MAX; }
  } catch(_:Dynamic) { fail(); }
  lastPassSeconds=clock()-start;
 }
}
