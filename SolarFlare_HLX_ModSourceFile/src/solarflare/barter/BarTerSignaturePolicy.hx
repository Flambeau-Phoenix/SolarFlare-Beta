package solarflare.barter;

/** A catalog name is insufficient: only a live owner-owned signature may be present. */
class BarTerSignaturePolicy {
 public static function present(hero:Dynamic,skill:Dynamic):Bool {
  if (!BarTerNativeAccess.owned(skill,hero)) return false;
  try { var s:st.skill.Skill=skill; return s.isSignature(); } catch (_:Dynamic) { return false; }
 }
}
