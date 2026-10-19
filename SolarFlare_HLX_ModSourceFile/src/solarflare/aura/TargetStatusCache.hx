package solarflare.aura;

/** Current-enemy statuses are available in normal builds; observation remains demand-driven. */
class TargetStatusCache {
 public static inline var AVAILABLE:Bool = true;
 public static var observer(default,null):TargetStatusObserver = #if hl new TargetStatusObserver(new TargetStatusEngine()) #else null #end;
 public static function generation():Int return observer==null ? 0 : observer.generation;
 public static function publish(frame:solarflare.aura.signal.AuraSignalFrame,now:Float):Void {
  if(observer==null) return;
  frame.targetStatusGeneration=observer.generation;
  frame.targetStatusValid=observer.valid; frame.targetStatusDomainKnown=observer.domainKnown;
  for(i in 0...observer.count) {
   if(frame.targetStatusCount>=frame.targetStatuses.length) { frame.targetStatusDomainKnown=false; break; }
   var src=observer.snapshots[i]; var dst=frame.targetStatuses[frame.targetStatusCount++];
   dst.rawId=src.rawId; dst.instanceId=src.instanceId; dst.known=src.known; dst.present=src.present;
   dst.stacks=src.stacks; dst.stacksKnown=src.stacksKnown; dst.durationKnown=src.durationKnown; dst.infinite=src.infinite;
   var elapsed=Math.max(0,now-src.observedAt);
   dst.durationLeft=src.infinite ? solarflare.SkillRemain.INFINITE_LEFT : Math.max(0,src.durationLeft-elapsed);
   dst.durationProgress=src.durationLeft>0 ? Math.max(0,src.durationProgress*dst.durationLeft/src.durationLeft) : src.durationProgress;
  }
 }
 public static function observe(hero:Dynamic,target:Dynamic,now:Float):Void {
  if(observer==null) return;
  observer.observe(hero,solarflare.HealthCache.statusOwnerGen,target,now,
   AVAILABLE && solarflare.ObserveDemand.aurasNeedTargetStatus);
 }
 public static function reset():Void { if(observer!=null) observer.reset(); }
}
