package solarflare.aura;

import solarflare.cdb.StatusTypeCatalog;
import solarflare.aura.signal.AuraConditionDef;

/** Primitive editor requests and configuration demand; no observation or I/O from drawing. */
class StatusTypeDemand {
 public static var meMask(default,null):Int=0;
 public static var enemyMask(default,null):Int=0;
 static var editorMe=0;
 static var editorEnemy=0;
 static var editorUntil:Float=0;
 public static function isTypeSignal(signal:String):Bool return signal=="statusType.present" || signal=="target.statusType.present";
 public static function beginEditorFrame():Void { editorMe=editorEnemy=0; editorUntil=0; }
 public static function requestEditor(signal:String,id:String):Void {
  if(!isTypeSignal(signal)) return;
  var bit=StatusTypeCatalog.bit(id); if(bit==0) return;
  if(signal=="target.statusType.present") editorEnemy|=bit; else editorMe|=bit;
  editorUntil=haxe.Timer.stamp()+0.15;
 }
 public static function collect(conditions:Array<AuraConditionDef>,enabled:Bool,editorOpen:Bool,now:Float):Void {
  meMask=enemyMask=0;
  if(enabled) for(c in conditions) if(c!=null && isTypeSignal(c.signal)) {
   if(c.signal=="target.statusType.present") enemyMask|=StatusTypeCatalog.bit(c.subject); else meMask|=StatusTypeCatalog.bit(c.subject);
  }
  if(editorOpen && now<=editorUntil) { meMask|=editorMe; enemyMask|=editorEnemy; }
 }
}
