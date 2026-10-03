package solarflare.extrabars;

class ExtraBarsSlotConfig {
	public var itemKind:String = "";
	public var keyCode:Int = 0;
	public var modifiers:Int = 0;
	public function new() {}
	public function dump():Dynamic return {itemKind:itemKind, keyCode:keyCode, modifiers:modifiers};
	public function apply(data:Dynamic):Void {
		if (data == null) return;
		itemKind = ExtraBarsConfig.text(data, "itemKind", "");
		keyCode = ExtraBarsConfig.integer(data, "keyCode", 0, 0, 65535);
		modifiers = ExtraBarsConfig.integer(data, "modifiers", 0, 0, 7);
	}
}

class ExtraBarsBarConfig {
	public var id:String;
	public var name:String;
	public var enabled:Bool = false;
	public var hidden:Bool = false;
	public var locked:Bool = false;
	public var transparent:Bool = false;
	public var opacity:Float = 1;
	public var slotCount:Int = 8;
	public var columns:Int = 4;
	public var rows(get, never):Int;
	function get_rows():Int return Std.int(Math.ceil(slotCount / columns));
	public var slotSize:Int = 48;
	public var slots:Array<ExtraBarsSlotConfig> = [];
	public function new(id:String, name:String) {
		this.id = id; this.name = name;
		for (i in 0...10) slots.push(new ExtraBarsSlotConfig());
	}
	public function setCount(count:Int):Void { slotCount = Std.int(Math.max(1, Math.min(10, count))); columns = Std.int(Math.min(columns, slotCount)); }
	public function setColumns(value:Int):Void columns = Std.int(Math.max(1, Math.min(slotCount, value)));
	public function setRows(value:Int):Void setColumns(Std.int(Math.ceil(slotCount / Math.max(1, Math.min(slotCount, value)))));
	public function dump():Dynamic return {id:id, name:name, enabled:enabled, hidden:hidden, locked:locked, transparent:transparent,
		opacity:opacity, slotCount:slotCount, columns:columns, slotSize:slotSize, slots:[for (slot in slots) slot.dump()]};
	public function apply(data:Dynamic):Void {
		name = ExtraBarsConfig.text(data, "name", name);
		enabled = Reflect.field(data, "enabled") == true; hidden = Reflect.field(data, "hidden") == true;
		locked = Reflect.field(data, "locked") == true; transparent = Reflect.field(data, "transparent") == true;
		opacity = ExtraBarsConfig.number(data, "opacity", 1, 0.15, 1);
		setCount(ExtraBarsConfig.integer(data, "slotCount", 8, 1, 10));
		setColumns(ExtraBarsConfig.integer(data, "columns", 4, 1, 10));
		slotSize = ExtraBarsConfig.integer(data, "slotSize", 48, 24, 96);
		var saved = Reflect.field(data, "slots");
		if (Std.isOfType(saved, Array)) { var rows:Array<Dynamic> = cast saved; for (i in 0...Std.int(Math.min(10, rows.length))) slots[i].apply(rows[i]); }
	}
}

/** Global remembered settings. Screen positions belong to the controller's placement map. */
class ExtraBarsConfig {
	public var enabled:Bool = true;
	public var prefix:String = "mouse_back";
	public var mode:String = "toggle";
	public var bars:Array<ExtraBarsBarConfig> = [];
	public var nextId:Int = 1;
	public var sparkEnabled:Bool = false;
	public var sparkSize:Int = 64;
	public var sparkLocked:Bool = false;
	public var sparkTransparent:Bool = false;
	public var sparkShowHotkey:Bool = false;
	/** Display only; never parsed or registered as an input binding. */
	public var sparkHotkeyLabel:String = "";
	public function new() { addBar(); }
	public function addBar():ExtraBarsBarConfig {
		while (find("bar" + nextId) != null) nextId++;
		var bar = new ExtraBarsBarConfig("bar" + nextId, "Bar " + nextId++); bars.push(bar); return bar;
	}
	public function find(id:String):ExtraBarsBarConfig { for (bar in bars) if (bar.id == id) return bar; return null; }
	public function removeBar(id:String):Bool { var bar = find(id); return bar != null && bars.remove(bar); }
	public function swap(aId:String, a:Int, bId:String, b:Int):Bool {
		var from = find(aId); var to = find(bId);
		if (from == null || to == null || a < 0 || a >= from.slotCount || b < 0 || b >= to.slotCount) return false;
		var temp = from.slots[a]; from.slots[a] = to.slots[b]; to.slots[b] = temp; return true;
	}
	public function demand():Bool { if (sparkEnabled) return true; if (!enabled || prefix == "off") return false; for (bar in bars) if (bar.enabled) return true; return false; }
	public function dump():Dynamic return {version:1, enabled:enabled, prefix:prefix, mode:mode, nextId:nextId,
		bars:[for (bar in bars) bar.dump()], sparkEnabled:sparkEnabled, sparkSize:sparkSize, sparkLocked:sparkLocked, sparkTransparent:sparkTransparent,
		sparkShowHotkey:sparkShowHotkey, sparkHotkeyLabel:sparkHotkeyLabel};
	public function apply(data:Dynamic):Void {
		enabled = true; prefix = "mouse_back"; mode = "toggle"; bars = []; nextId = 1;
		sparkEnabled = false; sparkSize = 64; sparkLocked = false; sparkTransparent = false;
		sparkShowHotkey = false; sparkHotkeyLabel = "";
		if (data == null) { addBar(); return; }
		enabled = Reflect.field(data, "enabled") != false;
		var p = text(data, "prefix", prefix); if (ExtraBarsActivationConfig.prefixes.indexOf(p) >= 0) prefix = p;
		var m = text(data, "mode", mode); if (ExtraBarsActivationConfig.modes.indexOf(m) >= 0) mode = m;
		sparkEnabled = Reflect.field(data, "sparkEnabled") == true;
		sparkSize = integer(data, "sparkSize", 64, 40, 120);
		sparkLocked = Reflect.field(data, "sparkLocked") == true; sparkTransparent = Reflect.field(data, "sparkTransparent") == true;
		sparkShowHotkey = Reflect.field(data, "sparkShowHotkey") == true;
		sparkHotkeyLabel = cleanHotkeyLabel(text(data, "sparkHotkeyLabel", ""));
		nextId = integer(data, "nextId", 1, 1, 2147483646);
		var saved = Reflect.field(data, "bars");
		if (Std.isOfType(saved, Array)) {
			var rows:Array<Dynamic> = cast saved;
			for (row in rows) {
				if (row == null) continue;
				var id = text(row, "id", "");
				if (id.length == 0 || id == "spark" || find(id) != null) id = allocateId();
				var bar = new ExtraBarsBarConfig(id, "ExtraBar"); bar.apply(row); bars.push(bar);
			}
		} else addBar();
	}
	function allocateId():String { while (find("bar" + nextId) != null) nextId++; return "bar" + nextId++; }
	public function applyLegacy(data:Dynamic):Void {
		apply(null); if (data == null) return;
		var old = new ExtraBarsPrototypeModel(); old.apply(data);
		prefix = old.prefix; mode = old.mode;
		var bar = bars[0]; bar.enabled = old.enabled; bar.setCount(old.rows * old.columns); bar.setColumns(old.columns); bar.slotSize = old.slotSize;
		bar.slots[0].itemKind = old.itemKind; bar.slots[0].keyCode = old.keyCode; bar.slots[0].modifiers = old.modifiers;
	}
	public function activationSignature():String {
		return haxe.Json.stringify({enabled:enabled, prefix:prefix, mode:mode, bars:[for (bar in bars)
			{id:bar.id, enabled:bar.enabled, count:bar.slotCount, slots:[for (i in 0...bar.slotCount) bar.slots[i].dump()]}]});
	}
	public static function cleanHotkeyLabel(value:String):String {
		if (value == null) return "";
		var singleLine = StringTools.replace(StringTools.replace(StringTools.replace(value, "\r", " "), "\n", " "), "\t", " ");
		return StringTools.trim(singleLine).substr(0,32);
	}
	public static function text(data:Dynamic, field:String, fallback:String):String { var value = Reflect.field(data, field); return Std.isOfType(value, String) ? value : fallback; }
	public static function integer(data:Dynamic, field:String, fallback:Int, low:Int, high:Int):Int {
		var value:Dynamic = Reflect.field(data, field);
		if (!Std.isOfType(value, Int) && !Std.isOfType(value, Float)) return fallback;
		var number:Float = value; return Math.isFinite(number) ? Std.int(Math.max(low, Math.min(high, number))) : fallback;
	}
	public static function number(data:Dynamic, field:String, fallback:Float, low:Float, high:Float):Float {
		var value:Dynamic = Reflect.field(data, field);
		if (!Std.isOfType(value, Int) && !Std.isOfType(value, Float)) return fallback;
		var number:Float = value; return Math.isFinite(number) ? Math.max(low, Math.min(high, number)) : fallback;
	}
}
