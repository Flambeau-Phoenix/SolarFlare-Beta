package solarflare.barter;

class BarTerLayout {
	public static inline var GAP:Int = 4;

	public static function width(columns:Int, slotSize:Int):Single {
		var c = columns < 1 ? 1 : columns;
		return c * slotSize + (c - 1) * GAP;
	}

	public static function height(slotCount:Int, columns:Int, slotSize:Int):Single {
		var c = columns < 1 ? 1 : columns;
		var rows = Std.int(Math.ceil(slotCount / c));
		if (rows < 1) rows = 1;
		return rows * slotSize + (rows - 1) * GAP;
	}

	public static function resized(slotCount:Int, columns:Int, width:Single, height:Single):Int {
		var c = columns < 1 ? 1 : columns;
		var rows = Std.int(Math.ceil(slotCount / c));
		if (rows < 1) rows = 1;
		var byW = (width - (c - 1) * GAP) / c;
		var byH = (height - (rows - 1) * GAP) / rows;
		var s = Std.int(Math.min(byW, byH));
		if (s < 32) s = 32;
		if (s > 128) s = 128;
		return s;
	}
}
