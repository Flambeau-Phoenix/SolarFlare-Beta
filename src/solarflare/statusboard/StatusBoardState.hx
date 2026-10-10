package solarflare.statusboard;

import solarflare.aura.AuraStatusSnap;

/** Board-local exclusions. Exact identities only; never alters observation. */
class StatusBoardState {
 public var hiddenIds:Array<String> = [];
 public function new() {}
 public static function key(id:String):String return id == null ? "" : StringTools.trim(id).toLowerCase();
 public function excluded(s:AuraStatusSnap):Bool {
  if (s == null) return false;
  if (hiddenIds.indexOf(key(s.id)) >= 0) return true;
  for (id in s.ids) if (hiddenIds.indexOf(key(id)) >= 0) return true;
  return false;
 }
 public function hide(id:String):Bool {
  var k = key(id);
  if (k.length == 0 || hiddenIds.indexOf(k) >= 0) return false;
  hiddenIds.push(k); return true;
 }
 public function restore(id:String):Bool return hiddenIds.remove(key(id));
 public function apply(data:Dynamic):Void {
  hiddenIds.resize(0);
  if (Std.isOfType(data, Array)) { var rows:Array<Dynamic> = cast data; for (id in rows) if (Std.isOfType(id, String)) hide(id); }
 }
 public function pack(source:Array<AuraStatusSnap>, count:Int, out:Array<AuraStatusSnap>, limit:Int = 512):Void {
  out.resize(0);
  for (i in 0...Std.int(Math.min(count, source.length))) {
   var s = source[i];
   if (s != null && s.known && s.present && s.id.length > 0 && !excluded(s)) {
    if (out.length < limit) out.push(s);
   }
  }
 }
 public static function seconds(s:AuraStatusSnap, now:Float):Float {
  if (s == null || !s.durationKnown) return Math.NaN;
  if (s.infinite) return -1;
  return s.endsAt > 0 ? Math.max(0, s.endsAt - now) : s.left;
 }
}
