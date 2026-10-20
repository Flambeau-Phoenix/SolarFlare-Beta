package solarflare.ui;

/** The owner fence is independent of engine references and can be replayed with delayed identity. */
class ProfileTransition {
 public var owner(default,null):String="";
 public var ready(default,null):Bool=false;
 public var generation(default,null):Int=0;
 var identityGeneration:Int=-1;
 var pendingOutgoing:String="";
 public function new(initialGeneration:Int=0) generation=initialGeneration;
 /** Returns true only when a confirmed destination needs restoration. Outgoing capture always runs first. */
 public function begin(id:String,confirmed:Bool,identity:Int,save:String->Void,cancel:Void->Void):Bool {
  confirmed=confirmed && ProfileBank.heroId(id)!="";
  if(confirmed && ready && owner==id && identityGeneration==identity) return false;
  if(ready) { ready=false; generation++; pendingOutgoing=owner; }
  if(pendingOutgoing!="") {
   // Fail closed. A failed capture retries before any destination can replace the live configuration.
   try { save(pendingOutgoing); pendingOutgoing=""; } catch(e:Dynamic) { cancel(); throw e; }
   cancel();
  }
  if(!confirmed) return false;
  owner=id; identityGeneration=identity; generation++; return true;
 }
 public function complete():Void ready=true;
 public function restoring():Void { ready=false; generation++; }
 public function changed():Void generation++;
 public function accepts(token:Int,wasReady:Bool):Bool return ready && wasReady && token==generation;
}
