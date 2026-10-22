package solarflare.barter;

/** Hover-only, bounded read of a real carried item. No construction, mutation or retained pointer. */
class BarTerItemAccess {
 public static inline var MAX_SLOTS:Int=1024;
 public static function find(kind:String,hero:Dynamic):Dynamic {
  if (hero == null || kind == null || kind.length == 0) return null;
  try {
   var h:ent.Hero=hero;
   var loadout=h.loadout;
   if (loadout == null) return null;
   var found=scan(loadout.equipment,kind);
   return found != null ? found : scan(loadout.inventory,kind);
  } catch (_:Dynamic) { return null; }
 }
 static function scan(inv:st.Inventory,kind:String):Dynamic {
  if (inv == null) return null;
  try {
  var count=inv.getSize();
  if (count<0 || count>MAX_SLOTS) return null;
  for (i in 0...count) {
   var stack=inv.getStack(i);
   if (stack != null && stack.item != null && solarflare.EngineText.cleanId(stack.item.kind) == kind) return stack.item;
  }
  } catch (_:Dynamic) {}
  return null;
 }
}
