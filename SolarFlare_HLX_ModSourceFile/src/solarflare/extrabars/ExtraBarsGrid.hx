package solarflare.extrabars;

/** Pure geometry: changing the visible grid never clears an assignment. */
class ExtraBarsGrid {
	public static inline var GAP:Int = 4;
	public static inline var CAPTION:Int = 34;
	public static function valid(rows:Int, columns:Int):Bool
		return rows >= 1 && rows <= 8 && columns >= 1 && columns <= 8 && rows * columns <= 8;
	public static function size(value:Int):Int return value < 24 ? 24 : value > 96 ? 96 : value;
	public static function width(columns:Int, pixels:Int):Int return columns * size(pixels) + (columns - 1) * GAP;
	public static function height(rows:Int, pixels:Int):Int return rows * size(pixels) + (rows - 1) * GAP + CAPTION;
	public static function resized(rows:Int, columns:Int, width:Float, height:Float):Int {
		if (!valid(rows, columns) || !Math.isFinite(width) || !Math.isFinite(height)) return 48;
		return size(Std.int(Math.min((width - (columns - 1) * GAP) / columns,
			(height - CAPTION - (rows - 1) * GAP) / rows)));
	}
}
