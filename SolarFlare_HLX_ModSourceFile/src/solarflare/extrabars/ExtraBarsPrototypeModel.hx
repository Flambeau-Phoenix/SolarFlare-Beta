package solarflare.extrabars;

/** One-slot, opt-in runtime gate. Only primitives cross persistence boundaries. */
class ExtraBarsPrototypeModel {
	public var enabled:Bool = false;
	public var itemKind:String = "";
	public var keyCode:Int = 0;
	/** Retain legacy settings; non-zero chords are inactive and require re-recording. */
	public var modifiers:Int = 0;
	public var prefix:String = "mouse_back";
	public var mode:String = "toggle";
	public var thresholdMs:Int = 350;
	public var rows:Int = 2;
	public var columns:Int = 4;
	public var slotSize:Int = 48;
	public function setGrid(rows:Int, columns:Int):Bool {
		if (!ExtraBarsGrid.valid(rows, columns)) return false;
		this.rows = rows; this.columns = columns; return true;
	}
	public function new() {}
	public function dump():Dynamic return {enabled:enabled, itemKind:itemKind, keyCode:keyCode, modifiers:modifiers,
		prefix:prefix, mode:mode, thresholdMs:thresholdMs, rows:rows, columns:columns, slotSize:slotSize};
	public function apply(data:Dynamic):Void {
		enabled = false; itemKind = ""; keyCode = 0; modifiers = 0;
		prefix = "mouse_back"; mode = "toggle"; thresholdMs = 350;
		rows = 2; columns = 4; slotSize = 48;
		if (data == null) return;
		enabled = Reflect.field(data, "enabled") == true;
		var kind = Reflect.field(data, "itemKind");
		if (Std.isOfType(kind, String)) itemKind = kind;
		var key = Std.parseInt(Std.string(Reflect.field(data, "keyCode")));
		var mods = Std.parseInt(Std.string(Reflect.field(data, "modifiers")));
		if (key != null && key > 0 && mods != null && mods >= 0 && mods <= 7) keyCode = key;
		if (mods != null && mods >= 0 && mods <= 7) modifiers = mods;
		var savedPrefix:Dynamic = Reflect.field(data, "prefix");
		var savedMode:Dynamic = Reflect.field(data, "mode");
		if (Std.isOfType(savedPrefix, String) && ExtraBarsActivationConfig.prefixes.indexOf(savedPrefix) >= 0) prefix = savedPrefix;
		if (Std.isOfType(savedMode, String) && ExtraBarsActivationConfig.modes.indexOf(savedMode) >= 0) mode = savedMode;
		var threshold = Std.parseInt(Std.string(Reflect.field(data, "thresholdMs")));
		if (threshold != null) thresholdMs = ExtraBarsActivationConfig.threshold(threshold);
		var savedRows = Std.parseInt(Std.string(Reflect.field(data, "rows")));
		var savedColumns = Std.parseInt(Std.string(Reflect.field(data, "columns")));
		if (savedRows != null && savedColumns != null) setGrid(savedRows, savedColumns);
		var savedSize = Std.parseInt(Std.string(Reflect.field(data, "slotSize")));
		if (savedSize != null) slotSize = ExtraBarsGrid.size(savedSize);
	}
	public function signature():String return enabled + ":" + itemKind + ":" + keyCode + ":" + modifiers
		+ ":" + prefix + ":" + mode + ":" + thresholdMs;
}
