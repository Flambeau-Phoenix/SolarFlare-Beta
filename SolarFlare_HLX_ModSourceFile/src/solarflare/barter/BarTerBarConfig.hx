package solarflare.barter;

/** One BarTer grid — up to 64 cells, including assignments retained outside a smaller grid. */
class BarTerBarConfig {
	public static inline var MAX_SLOTS:Int = 64;

	public var id:String;
	public var name:String;
	public var enabled:Bool = true;
	public var hidden:Bool = false;
	public var locked:Bool = false;
	public var transparent:Bool = false;
	public var opacity:Float = 1;
	/** HUD colors are independent of the F6 editor theme unless explicitly selected. */
	public var colorMode:String = "neutral";
	public var fillColor:Int = 0x181B20;
	public var borderColor:Int = 0x626970;
	public var readyColor:Int = 0xB7C3CE;
	public var showEmptyCells:Bool = false;
	public var slotCount:Int = 9;
	public var columns:Int = 9;
	public var rows(get,never):Int;
	function get_rows():Int return Std.int(Math.ceil(slotCount / columns));
	public var slotSize:Int = 64;
	public var slots:Array<BarTerSlotConfig> = [];

	public function new(id:String, name:String) {
		this.id = id;
		this.name = name;
		for (_ in 0...MAX_SLOTS)
			slots.push(new BarTerSlotConfig());
	}

	public function setCount(count:Int):Void {
		slotCount = Std.int(Math.max(1, Math.min(MAX_SLOTS, count)));
		if (columns > slotCount)
			columns = slotCount;
	}

	public function setColumns(value:Int):Void {
		columns = Std.int(Math.max(1, Math.min(16, Math.min(slotCount, value))));
	}
	/** Resizing retains every assignment outside the visible grid. */
	public function setGrid(rows:Int, cols:Int):Void {
		cols = Std.int(Math.max(1, Math.min(16, cols)));
		rows = Std.int(Math.max(1, Math.min(8, Math.min(Std.int(MAX_SLOTS / cols), rows))));
		columns = cols; slotCount = rows * cols;
	}

	public function dump():Dynamic {
		return {
			id: id,
			name: name,
			enabled: enabled,
			hidden: hidden,
			locked: locked,
			transparent: transparent,
			opacity: opacity,
			colorMode: colorMode,
			fillColor: fillColor,
			borderColor: borderColor,
			readyColor: readyColor,
			showEmptyCells: showEmptyCells,
			slotCount: slotCount,
			columns: columns,
			slotSize: slotSize,
			slots: [for (s in slots) s.dump()]
		};
	}

	public function apply(data:Dynamic):Void {
		if (data == null) return;
		name = text(data, "name", name);
		enabled = Reflect.field(data, "enabled") != false;
		hidden = Reflect.field(data, "hidden") == true;
		locked = Reflect.field(data, "locked") == true;
		transparent = Reflect.field(data, "transparent") == true;
		opacity = number(data, "opacity", 1, 0.15, 1);
		colorMode = text(data,"colorMode","neutral");
		if (colorMode != "theme" && colorMode != "custom") colorMode="neutral";
		fillColor = integer(data,"fillColor",0x181B20,0,0xFFFFFF);
		borderColor = integer(data,"borderColor",0x626970,0,0xFFFFFF);
		readyColor = integer(data,"readyColor",0xB7C3CE,0,0xFFFFFF);
		showEmptyCells = Reflect.field(data,"showEmptyCells") == true;
		if (transparent && opacity >= 0.99)
			opacity = 0.55;
		setCount(integer(data, "slotCount", slotCount, 1, MAX_SLOTS));
		setColumns(integer(data, "columns", columns, 1, MAX_SLOTS));
		slotSize = integer(data, "slotSize", slotSize, 32, 128);
		var saved = Reflect.field(data, "slots");
		if (Std.isOfType(saved, Array)) {
			var rows:Array<Dynamic> = cast saved;
			var n = Std.int(Math.min(MAX_SLOTS, rows.length));
			for (i in 0...n)
				slots[i].apply(rows[i]);
		}
	}

	static function text(data:Dynamic, field:String, fallback:String):String {
		try {
			var v:Dynamic = Reflect.field(data, field);
			if (Std.isOfType(v, String)) return cast v;
		} catch (_:Dynamic) {}
		return fallback;
	}

	static function integer(data:Dynamic, field:String, fallback:Int, lo:Int, hi:Int):Int {
		try {
			var v:Dynamic = Reflect.field(data, field);
			if (v == null) return fallback;
			var n = Std.int(v);
			if (n < lo) n = lo;
			if (n > hi) n = hi;
			return n;
		} catch (_:Dynamic) {}
		return fallback;
	}

	static function number(data:Dynamic, field:String, fallback:Float, lo:Float, hi:Float):Float {
		try {
			var v:Dynamic = Reflect.field(data, field);
			if (v == null) return fallback;
			var n:Float = v;
			if (!Math.isFinite(n)) return fallback;
			if (n < lo) n = lo;
			if (n > hi) n = hi;
			return n;
		} catch (_:Dynamic) {}
		return fallback;
	}
}
