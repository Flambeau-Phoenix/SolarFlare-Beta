package solarflare.preview;

/** Pure shield proportions shared by every health presentation. */
class ShieldPolicy {
	public static function ratio(valid:Bool, shield:Float, max:Float):Float {
		if (!valid || !Math.isFinite(shield) || !Math.isFinite(max) || max <= 0 || shield <= 0) return 0;
		return Math.min(1, shield / max);
	}
	public static function cell(ratio:Float, index:Int, count:Int):Float {
		return Math.max(0, Math.min(1, ratio * count - index));
	}
}
