package solarflare.ui;

/** Checks actual Windows confinement; never selects or draws a cursor. */
class CursorConfinement {
	/** 0 = unchanged, 1 = applied, 2 = released, 3 = inactive, -1 = failed. */
	@:hlNative("sfcursor", "sync_confinement")
	public static function sync(confined:Bool):Int return -1;
}
