package solarflare.ui;

/** Observer facade: the controller owns every live reference and presentation lease. */
class NativeElementCache {
 static var controller=new NativeElementController(new NativeVisibilityEngine());
 public static function hasChatLease():Bool return controller.hasChatLease();
 public static function hasLeases():Bool return controller.hasLeases();
 public static function reassert(hud:Dynamic):Void {
  var start=haxe.Timer.stamp(); controller.reassert(hud);
  NativeVisibilityWork.late((haxe.Timer.stamp()-start)*1000);
 }
 public static function apply(hud:Dynamic,heroBar:Dynamic,heroBarPad:Dynamic,cfg:NativeHideConfig):Void {
  var start=haxe.Timer.stamp();
  controller.apply(hud,heroBar,heroBarPad,cfg,start);
  NativeVisibilityWork.observe((haxe.Timer.stamp()-start)*1000,controller.scannedNodes);
 }
 public static function reassertChat(hud:Dynamic):Void {
  var start=haxe.Timer.stamp(); controller.reassertChat(hud);
  NativeVisibilityWork.late((haxe.Timer.stamp()-start)*1000);
 }
 public static function releaseAll(attached:Bool,resetFailure:Bool=true):Void controller.clear(attached);
}
