package solarflare.aura;

/** Only applied IDs and aliases actually observed on that status are identities. */
class StatusIdentity {
 public static function key(id:String):String return id == null ? "" : StringTools.trim(id).toLowerCase();
 public static function matches(s:AuraStatusSnap,id:String):Bool {
  var want=key(id);
  if (s == null || want.length == 0) return false;
  if (key(s.id) == want) return true;
  for (alias in s.ids) if (key(alias) == want) return true;
  return false;
 }
 public static function sameApplied(a:AuraStatusSnap,b:AuraStatusSnap):Bool {
  if (a == null || b == null || a.sourceItemId != b.sourceItemId) return false;
  if (key(a.id) == key(b.id)) return true;
  return !a.present && matches(b,a.id);
 }
}
