package solarflare.input;

/** Four real equipment slots, independent of ExtraBars cell order and carried inventory. */
class NativeConsumableBindings {
 static var owner:Dynamic;
 static var lastRead:Float = -1;
 static var items:Map<String,NativeActionBindings.NativeBindingSnap> = new Map();
 static var complete:Bool = false;
 static var notEquipped:NativeActionBindings.NativeBindingSnap={actionId:"",state:"not-equipped",text:"Not equipped in a native consumable slot",known:true};
 static var unreadable:NativeActionBindings.NativeBindingSnap={actionId:"",state:"unreadable",text:"Unknown",known:false};
 public static function reset():Void { owner=null; lastRead=-1; items.clear(); complete=false; }
 public static function sample(hero:Dynamic, now:Float):Void {
  if (hero != owner) { reset(); owner=hero; }
  if (hero == null) return;
  if (now-lastRead < NativeActionBindings.INTERVAL_S) return;
  lastRead=now; items.clear(); complete=true;
  try {
   var h:ent.Hero=hero;
   var equipment=h.loadout.equipment;
   if (equipment == null) { complete=false; return; }
   for (i in 1...5) {
    var item=equipment.getSlot("Slot_Consumable"+i);
    if (item == null) continue;
    var kind=solarflare.EngineText.cleanId(item.kind);
    if (kind.length == 0) { complete=false; continue; }
    var row=NativeActionBindings.read("Consumable"+i,hero,now);
    var old=items.get(kind);
    if (old == null || (!old.known && row.known)) items.set(kind,row);
   }
  } catch (_:Dynamic) { complete=false; }
 }
 public static function find(kind:String):NativeActionBindings.NativeBindingSnap {
  var row=items.get(kind);
  if (row != null) return row;
  return complete ? notEquipped : unreadable;
 }
}
