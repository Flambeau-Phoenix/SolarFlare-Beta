package solarflare.ui;

/** Validated conversion between a displayed percentage/pixel value and model units. */
class PreciseValuePolicy {
	public static function convert(display:Float,factor:Float,min:Float,max:Float,previous:Float):Float {
		if(!Math.isFinite(display)) return previous;
		return Math.max(min,Math.min(max,display/factor));
	}
}
