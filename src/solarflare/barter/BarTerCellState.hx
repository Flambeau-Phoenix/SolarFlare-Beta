package solarflare.barter;

/** Presentation state is independent of whether the skill's key can be read. */
class BarTerCellState {
 public static function active(s:BarTerSnap):Bool {
  return s != null && s.kind != "empty" && (s.isItem ? s.count > 0 : s.available);
 }
 public static function lit(s:BarTerSnap):Bool {
  if (!active(s)) return false;
  if (s.isItem) return s.usable;
  var ammo=s.chargesMax > 0 && s.charges > 0;
  return s.affordable && (ammo || (s.chargesMax == 0 && s.ready && !s.onCd));
 }
 public static function empty(s:BarTerSnap):Bool return s == null || s.kind == "empty";
}
