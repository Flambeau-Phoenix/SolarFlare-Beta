package solarflare.aura;

/** Selection repair shared by the editor and regression tests. */
class CanvasSelection {
	public static function afterRemoval(selected:Int,removed:Int,lengthBefore:Int):Int {
		if(lengthBefore<=1) return -1;
		if(selected==removed) return Std.int(Math.min(removed,lengthBefore-2));
		return selected>removed ? selected-1 : selected;
	}
}
