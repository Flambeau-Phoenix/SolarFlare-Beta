package solarflare.ui;

/** Native input configuration and viewport reads run only during observation. */
class FullscreenShortcutGuard {
 public static var status(default,null):Int=0;
 static var sampleAt:Float=0;
 static function configure(enabled:Bool,eligible:Bool):Int {
  #if hl
  if(!hl.Api.isPrimLoaded(FullscreenShortcutNative.configure)) return enabled ? -1 : 0;
  #end
  return FullscreenShortcutNative.configure(enabled,eligible);
 }
 public static function observe(cfg:ConfigPanel):Void {
  var now=haxe.Timer.stamp(); if(now<sampleAt) return; sampleAt=now+0.05;
  try {
   var window=hxd.Window.getInstance();
   if(window==null) { status=configure(false,false); return; }
   HudChrome.observeViewport(window.get_width(),window.get_height());
   status=configure(cfg.preventCtrlFullscreen.get(),window.get_isFocused());
  } catch(_:Dynamic) { status=-1; }
 }
}
