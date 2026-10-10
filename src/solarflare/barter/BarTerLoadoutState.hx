package solarflare.barter;
import solarflare.barter.BarTerWeaponLayouts.BarTerNativeSkill;

/** Primitive transition state. Edits during a pending swap belong to its observed loadout. */
class BarTerLoadoutState {
 public var currentKey:String = "";
 public var observedKey:String = "";
 public var revision:Int = 0;
 var staged:Bool = false;
 var editsBeforeIdentity:Bool = false;
 var candidate:String = "";
 var candidateAt:Float = 0;
 var candidateGeneration:Int = -1;
 public function new() {}
 public function reset():Void { currentKey=""; observedKey=""; staged=false; editsBeforeIdentity=false; resetCandidate(); }
 public function resetCandidate():Void { candidate=""; candidateGeneration=-1; }
 public function changed(bars:Array<BarTerBarConfig>,layouts:BarTerWeaponLayouts):Void {
  var key=observedKey.length > 0 ? observedKey : currentKey;
  if (key.length > 0) layouts.capture(key,bars); else editsBeforeIdentity=true;
 }
 /** A stable action set must appear in two distinct native observation generations. */
 public function reconcile(key:String,source:Array<BarTerNativeSkill>,generation:Int,now:Float,
   bars:Array<BarTerBarConfig>,layouts:BarTerWeaponLayouts,follow:Bool):Bool {
  if (key.length == 0 || source.length == 0) return false;
  if (observedKey != key) {
   if (currentKey.length > 0 && currentKey == observedKey) layouts.capture(currentKey,bars);
   observedKey=key; staged=true; resetCandidate();
   if (editsBeforeIdentity) { layouts.capture(key,bars); editsBeforeIdentity=false; }
  }
  var fingerprint=key;
  for (s in source) fingerprint+="|"+s.action+":"+s.id;
  if (candidate != fingerprint) { candidate=fingerprint; candidateAt=now; candidateGeneration=generation; return false; }
  if (now-candidateAt < 1.05 || generation == candidateGeneration) return false;
  if (staged || currentKey != key) {
   if (follow) layouts.restore(key,currentKey,bars,source,true);
   currentKey=key; staged=false; layouts.capture(key,bars); revision++;
  }
  return true;
 }
}
