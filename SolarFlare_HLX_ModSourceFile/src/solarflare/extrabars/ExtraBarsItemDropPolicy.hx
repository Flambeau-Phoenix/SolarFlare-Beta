package solarflare.extrabars;

/** Validate untrusted catalog payloads before the editor's undoable mutation. */
class ExtraBarsItemDropPolicy {
 public static function itemId(model:ExtraBarsConfig,barId:String,index:Int,payload:Dynamic,generation:Int,known:String->Bool):Null<String> {
  var bar=model.find(barId);
  if (bar==null || index<0 || index>=bar.slotCount || index>=bar.slots.length || payload==null) return null;
  var stamp=Reflect.field(payload,"generation");
  var id=Reflect.field(payload,"item");
  if (!Std.isOfType(stamp,Int) || stamp!=generation || !Std.isOfType(id,String) || id.length==0 || !known(id)) return null;
  return id;
 }
}
