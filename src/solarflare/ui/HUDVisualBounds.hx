package solarflare.ui;

/** Visual allocation around a face; never changes its configured dimensions. */
class HUDVisualBounds {
	public var minX:Float = 0;
	public var minY:Float = 0;
	public var maxX:Float = 0;
	public var maxY:Float = 0;
	public function new() {}
	public function reset(w:Float, h:Float):Void {
		minX = minY = 0;
		maxX = w;
		maxY = h;
	}
	public function include(x:Float, y:Float, w:Float, h:Float):Void {
		minX = Math.min(minX, x);
		minY = Math.min(minY, y);
		maxX = Math.max(maxX, x + w);
		maxY = Math.max(maxY, y + h);
	}
	public inline function width():Float return maxX - minX;
	public inline function height():Float return maxY - minY;
	public static inline function hostCoordinate(anchor:Float, inset:Float):Float return anchor - inset;
	public static inline function anchorCoordinate(host:Float, inset:Float):Float return host + inset;
	public static inline function fontSize(side:Float, ratio:Float, scale:Float):Float {
		return Math.max(11, Math.min(48, side * ratio * scale));
	}
	public static inline function ringThickness(radius:Float, scale:Float):Float {
		return Math.max(5.5 * (scale > 0 ? scale : 1), radius * 0.28);
	}
	/** Includes RingGauge's halo, stroke, animated tip, and antialiasing. */
	public function includeRing(cx:Float, cy:Float, radius:Float, scale:Float):Void {
		if (scale <= 0) scale = 1;
		var thickness = ringThickness(radius, scale);
		var reach = radius + Math.max(thickness * 0.625, Math.max(2.5 * scale, thickness * 0.42)) + 1;
		include(cx - reach, cy - reach, reach * 2, reach * 2);
	}
	public static inline function plateY(y:Float, h:Float, textH:Float, place:Int):Float {
		return switch (place) {
			case 1: y - textH - 2;
			case 2: y + h + 2;
			default: y + (h - textH) * 0.5;
		};
	}
	/** Matches the plate padding and shadow in AuraVisualRenderer. */
	public function includePlate(x:Float, y:Float, w:Float, h:Float, textW:Float, textH:Float, place:Int):Void {
		include(x + (w - textW) * 0.5 - 4, plateY(y, h, textH, place) - 2, textW + 8, textH + 4);
	}
}
