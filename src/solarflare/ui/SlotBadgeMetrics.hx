package solarflare.ui;

/** Shared scale policy for bindings and charges. Text never changes the icon/cell dimensions. */
class SlotBadgeMetrics {
	public static function scale(value:Dynamic):Float return HudLayoutModel.finite(value) ? Math.max(0.5,Math.min(3,value)) : 1;
	public static function font(base:Float,value:Float,cell:Float):Float return Math.max(6,Math.min(72,Math.min(base*scale(value),cell*0.7)));
	public static function fit(requested:Float,base:Float,naturalWidth:Float,w:Float,h:Float):Float {
		var fitted=naturalWidth>0 ? Math.min(requested,Math.max(1,w-4)*base/naturalWidth) : requested;
		return Math.max(1,Math.min(fitted,h-2));
	}
}
