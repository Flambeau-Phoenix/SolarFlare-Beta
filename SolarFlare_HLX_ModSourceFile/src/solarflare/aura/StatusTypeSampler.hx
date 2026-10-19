package solarflare.aura;

/** Shared 20Hz / 1ms scheduler, alternating first subject to avoid starvation. */
class StatusTypeSampler {
 public static inline var INTERVAL:Float=0.05;
 public static inline var BUDGET:Float=0.001;
 public var me(default,null):StatusTypeObserver;
 public var enemy(default,null):StatusTypeObserver;
 public var samples(default,null):Int=0;
 public var lastPassSeconds(default,null):Float=0;
 var clock:Void->Float;
 var lastAt:Float=-1e9;
 var enemyFirst=false;
 public function new(source:StatusTypeSource,clock:Void->Float=null) {
  this.clock=clock==null ? haxe.Timer.stamp : clock;
  me=new StatusTypeObserver(source,false); enemy=new StatusTypeObserver(source,true);
 }
 public function reset():Void { me.reset(); enemy.reset(); lastAt=-1e9; }
 public function observe(hero:Dynamic,identityGeneration:Int,target:Dynamic,meMask:Int,enemyMask:Int,now:Float):Void {
  me.sync(hero,identityGeneration,meMask); enemy.sync(hero==null ? null : target,identityGeneration,enemyMask);
  if(hero==null || (meMask|enemyMask)==0 || !Math.isFinite(now)) return;
  if(now>=lastAt && now-lastAt<INTERVAL-1e-9) return;
  lastAt=now; samples++; var start=clock(); var deadline=start+BUDGET;
  if(enemyFirst) { enemy.step(deadline,clock); me.step(deadline,clock); }
  else { me.step(deadline,clock); enemy.step(deadline,clock); }
  enemyFirst=!enemyFirst; lastPassSeconds=clock()-start;
 }
}
