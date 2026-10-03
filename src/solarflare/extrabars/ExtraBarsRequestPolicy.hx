package solarflare.extrabars;

/** Pure stale-request validation shared by clicks and native queue dispatch. */
class ExtraBarsRequestPolicy {
 public static function valid(model:ExtraBarsConfig, barId:String, index:Int, kind:String, requestGeneration:Int,
   currentGeneration:Int, click:Bool, gameplay:Bool, cursorFree:Bool):Bool {
  if (!gameplay || requestGeneration != currentGeneration || (click && !cursorFree) || kind.length==0) return false;
  if (barId=="spark") return index==0 && click && model.sparkEnabled && kind=="SparkCube";
  var bar=model.find(barId);
  return model.enabled && model.prefix!="off" && bar!=null && bar.enabled && (!click || !bar.hidden)
    && index>=0 && index<bar.slotCount && bar.slots[index].itemKind==kind;
 }
}
