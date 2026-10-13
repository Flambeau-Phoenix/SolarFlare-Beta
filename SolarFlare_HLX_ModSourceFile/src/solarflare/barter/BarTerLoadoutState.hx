package solarflare.barter;
import solarflare.barter.BarTerWeaponLayouts.BarTerNativeSkill;

/** Persistence commits only after two independent, complete weapon observations. */
class BarTerLoadoutState {
 public var currentKey:String="";
 public var observedKey:String="";
 public var revision:Int=0;
 public var settling(default,null):Bool=true;
 var candidate:String="";
 var candidateAt:Float=0;
 var candidateGeneration:Int=-1;
 public function new() {}
 public function reset():Void { currentKey=observedKey=""; settling=true; resetCandidate(); }
 public function resetCandidate():Void { candidate=""; candidateGeneration=-1; }
 public function observeKey(key:String):Void { if (observedKey!=key) { observedKey=key; settling=true; resetCandidate(); } }
 public function changed(bars:Array<BarTerBarConfig>,layouts:BarTerWeaponLayouts,contentEdit:Bool=true):Void {
  if (!settling && currentKey.length>0 && observedKey==currentKey) layouts.capture(currentKey,bars,contentEdit);
 }
 public function reconcile(key:String,source:Array<BarTerNativeSkill>,generation:Int,now:Float,bars:Array<BarTerBarConfig>,layouts:BarTerWeaponLayouts,follow:Bool,readable:Bool=true):Bool {
  observeKey(key);
  if (key.length==0 || !readable) { settling=true; resetCandidate(); return false; }
  var fingerprint=key;
  for (action in BarTerWeaponLayouts.ACTIONS.slice(0,4)) {
   var found:BarTerNativeSkill=null; for (s in source) if (s.action==action) found=s;
   if (found!=null && (found.availability=="unreadable" || found.fresh==false && found.availability!="absent")) { settling=true; resetCandidate(); return false; }
   fingerprint+="|"+action+":"+(found==null ? "absent" : found.baseId!=null ? found.baseId : found.id);
  }
  if (candidate!=fingerprint) { candidate=fingerprint; candidateAt=now; candidateGeneration=generation; settling=true; return false; }
  if (now-candidateAt<0.099 || generation==candidateGeneration) return false;
  if (currentKey!=key || settling) {
   if (follow) layouts.restore(key,currentKey,bars,source,true);
   currentKey=key; settling=false; layouts.capture(key,bars); revision++;
  }
  return true;
 }
}
