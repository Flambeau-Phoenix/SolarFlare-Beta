package solarflare.barter;

/** Ordered equipment definition identities; instance UIDs, ranks and temporary effects are excluded. */
class BarTerLoadoutIdentity {
 public static function key(hero:Dynamic):String {
  if (hero==null) return "";
  try {
   var h:ent.Hero=hero; var main=tag(h.get_activeWeapon());
   if (main.length==0) return "";
   return main+"|"+tag(h.get_activeOffhand())+"|"+tag(h.get_secondaryWeapon());
  } catch (_:Dynamic) { return ""; }
 }
 static function tag(item:Dynamic):String {
  if (item==null) return "";
  var kind=solarflare.EngineText.cleanId(HlxRuntime.resolveField(item,"kind")); if (kind.length>0) return kind;
  try { var inf=HlxRuntime.resolveField(item,"inf"); return solarflare.EngineText.cleanId(HlxRuntime.resolveField(inf,"id")); } catch (_:Dynamic) { return ""; }
 }
}
