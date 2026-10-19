package solarflare.aura;

/** Engine-facing ownership remains inside observation. Frozen masks are the only UI output. */
class StatusTypeService {
 static var sampler:StatusTypeSampler = #if hl new StatusTypeSampler(new StatusTypeEngine()) #else null #end;
 static var target:Dynamic;
 public static function setTarget(value:Dynamic):Void { target=StatusTypeDemand.enemyMask!=0 ? value : null; }
 public static function reset():Void { target=null; if(sampler!=null) sampler.reset(); }
 public static function observe(hero:Dynamic,now:Float):Void {
  if(sampler==null) return;
  if(StatusTypeDemand.enemyMask==0) target=null;
  if((StatusTypeDemand.meMask|StatusTypeDemand.enemyMask)==0) { reset(); return; }
  sampler.observe(hero,solarflare.HealthCache.statusOwnerGen,target,StatusTypeDemand.meMask,StatusTypeDemand.enemyMask,now);
 }
 public static function publish(frame:solarflare.aura.signal.AuraSignalFrame):Void {
  if(sampler==null) return;
  frame.myStatusTypeKnown=sampler.me.valid ? sampler.me.knownMask : 0;
  frame.myStatusTypePresent=sampler.me.presentMask; frame.myStatusTypeGeneration=sampler.me.generation;
  frame.enemyStatusTypeKnown=sampler.enemy.valid ? sampler.enemy.knownMask : 0;
  frame.enemyStatusTypePresent=sampler.enemy.presentMask; frame.enemyStatusTypeGeneration=sampler.enemy.generation;
 }
}
