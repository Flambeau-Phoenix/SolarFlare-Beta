package solarflare.ui;

/** Optional ABI extension: older helpers must still allow the mod to load. */
class FullscreenShortcutNative {
 @:hlNative("?sfcursor","shortcut_configure")
 public static function configure(enabled:Bool,eligible:Bool):Int return -1;
}
