package solarflare.target;

/** Display policy chosen by the user; these are not Farever reward thresholds. */
class TargetDifficulty {
	public static function color(delta:Int):Int {
		if (delta <= -5) return 0xFFAAAAAA;
		if (delta < 0) return 0xFF71CC2E;
		if (delta == 0) return 0xFF40DDEE;
		if (delta <= 2) return 0xFF40A0FF;
		return 0xFF4545E0;
	}
	public static function skull(delta:Int):Bool return delta >= 5;
}
