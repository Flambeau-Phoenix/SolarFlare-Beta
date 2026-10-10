package solarflare.barter;

import solarflare.ui.HudChrome;
import solarflare.ui.UiChrome;
import imgui.ImGui;
import imgui.ref.BoolRef;

/** Root BarTer settings — character placement owned by BarTer controller. */
class BarTerConfig {
	public static inline var MAX_BARS:Int = 3;
	public var activeBarCount:Int = 1;
	public var weaponLayouts = new BarTerWeaponLayouts();
	public var migrateNativeActions:Bool = false;

	public var open = new BoolRef(false);
	public var enabled = new BoolRef(true);
	public var hidden = new BoolRef(false);
	/** Restore native-action placements when the weapon loadout changes. */
	public var autoSeedOnWeaponSwap = new BoolRef(true);
	/** Draw effective native skill keys and user-recorded consumable keys. */
	public var showHotkeys = new BoolRef(true);
	public var bars:Array<BarTerBarConfig> = [];
	public var nextId:Int = 1;
	public var chromes:Map<String, HudChrome> = new Map();

	public function new() {
		ensureDefaultBars();
	}

	function ensureDefaultBars():Void {
		if (bars.length > 0) return;
		addBar("Skills");
		addBar("Bar 2");
		addBar("Bar 3");
	}

	public function addBar(name:String = null):BarTerBarConfig {
		if (bars.length >= MAX_BARS) return null;
		while (find("bar" + nextId) != null) nextId++;
		var id = "bar" + nextId++;
		var label = name != null && name.length > 0 ? name : ("Bar " + (bars.length + 1));
		var bar = new BarTerBarConfig(id, label);
		if (bars.length == 0) {
			bar.slotCount = 9;
			bar.columns = 9;
			bar.slotSize = 72;
		}
		bars.push(bar);
		chromeFor(id);
		return bar;
	}

	public function find(id:String):BarTerBarConfig {
		for (b in bars) if (b.id == id) return b;
		return null;
	}

	public function removeBar(id:String):Bool {
		var b = find(id);
		if (b == null || bars.length <= 1) return false;
		bars.remove(b);
		chromes.remove(id);
		return true;
	}

	public function chromeFor(id:String):HudChrome {
		var c = chromes.get(id);
		if (c == null) {
			c = new HudChrome(40, 200);
			chromes.set(id, c);
		}
		return c;
	}

	public function swap(aId:String, a:Int, bId:String, b:Int):Bool {
		var from = find(aId);
		var to = find(bId);
		if (from == null || to == null) return false;
		if (a < 0 || a >= from.slotCount || b < 0 || b >= to.slotCount) return false;
		var tmp = from.slots[a];
		from.slots[a] = to.slots[b];
		to.slots[b] = tmp;
		return true;
	}

	public function demand():Bool {
		if (!enabled.get() || hidden.get()) return false;
		for (b in activeBars()) if (b.enabled && !b.hidden) return true;
		return false;
	}
	public function activeBars():Array<BarTerBarConfig> return bars.slice(0, activeBarCount);
	public function isActive(id:String):Bool { for (i in 0...Std.int(Math.min(activeBarCount,bars.length))) if (bars[i].id == id) return true; return false; }
	public function setActiveCount(count:Int):Void {
		activeBarCount = Std.int(Math.max(1, Math.min(MAX_BARS,count)));
		while (bars.length < activeBarCount) addBar();
	}

	public function dump():Dynamic {
		var ch:Dynamic = {};
		for (id in chromes.keys()) {
			var c = chromes.get(id);
			if (c != null)
				Reflect.setField(ch, id, dumpChrome(c));
		}
		return {
			activeBarCount: activeBarCount,
			weaponLayouts: weaponLayouts.dump(),
			migrateNativeActions: migrateNativeActions,
			enabled: enabled.get(),
			hidden: hidden.get(),
			autoSeedOnWeaponSwap: autoSeedOnWeaponSwap.get(),
			showHotkeys: showHotkeys.get(),
			nextId: nextId,
			bars: [for (b in bars) b.dump()],
			chromes: ch
		};
	}

	static function dumpChrome(c:HudChrome):Dynamic {
		if (c == null) return {};
		return {
			hudLayoutVersion: c.hudLayoutVersion,
			lock: c.locked.get(),
			trans: c.transparent.get(),
			collapsed: c.collapsed.get(),
			sun: c.showGrip.get(),
			x: c.x.get(),
			y: c.y.get()
		};
	}

	public function apply(data:Dynamic):Void {
		if (data == null) {
			ensureDefaultBars();
			return;
		}
		enabled.set(Reflect.field(data, "enabled") != false);
		migrateNativeActions = data.migrateNativeActions == true || !Reflect.hasField(data,"weaponLayouts");
		hidden.set(Reflect.field(data, "hidden") == true);
		autoSeedOnWeaponSwap.set(Reflect.field(data, "autoSeedOnWeaponSwap") != false);
		showHotkeys.set(Reflect.field(data, "showHotkeys") != false);
		nextId = 1;
		try {
			var n:Dynamic = Reflect.field(data, "nextId");
			if (Std.isOfType(n, Int)) nextId = n;
		} catch (_:Dynamic) {}
		bars = [];
		chromes = new Map();
		var saved = Reflect.field(data, "bars");
		if (Std.isOfType(saved, Array)) {
			var rows:Array<Dynamic> = cast saved;
			for (row in rows) {
				if (row == null) continue;
				var id = "";
				try {
					var v:Dynamic = Reflect.field(row, "id");
					if (Std.isOfType(v, String)) id = cast v;
				} catch (_:Dynamic) {}
				if (id.length == 0) id = "bar" + nextId++;
				var bar = new BarTerBarConfig(id, "BarTer");
				bar.apply(row);
				bars.push(bar);
				chromeFor(id);
			}
		}
		if (bars.length == 0)
			ensureDefaultBars();
		setActiveCount(data.activeBarCount == null ? Std.int(Math.min(3,bars.length)) : Std.int(data.activeBarCount));
		weaponLayouts.apply(data.weaponLayouts);
		applyChromes(Reflect.field(data, "chromes"));
	}

	function applyChromes(data:Dynamic):Void {
		if (data == null) return;
		for (b in bars) {
			if (b == null) continue;
			var row:Dynamic = null;
			try
				row = Reflect.field(data, b.id)
			catch (_:Dynamic) {}
			if (row == null) continue;
			var c = chromeFor(b.id);
			c.hudLayoutVersion = row.hudLayoutVersion != null ? Std.int(row.hudLayoutVersion) : 0;
			if (Reflect.hasField(row, "lock") || Reflect.hasField(row, "locked"))
				c.locked.set(Reflect.field(row, "lock") == true || Reflect.field(row, "locked") == true);
			if (Reflect.hasField(row, "trans") || Reflect.hasField(row, "transparent"))
				c.transparent.set(Reflect.field(row, "trans") == true || Reflect.field(row, "transparent") == true);
			c.collapsed.set(Reflect.field(row, "collapsed") == true);
			try {
				if (row.x != null) c.x.set(row.x);
				if (row.y != null) c.y.set(row.y);
			} catch (_:Dynamic) {}
			c.posDirty = true;
			b.locked = c.locked.get();
			b.transparent = c.transparent.get();
			b.opacity = 1;
		}
	}

	public function drawHubSummary():Void {
		ImGui.textWrapped("Build up to three bars with skills, consumables, and display-only statuses. Choose a cell, then assign from the searchable catalogs.");
		ImGui.text(Std.string(activeBarCount)+" active bar(s)");
		if (bars.length > MAX_BARS) ImGui.textDisabled(Std.string(bars.length-MAX_BARS)+" legacy bar(s) retained as inactive saved data.");
		if (UiChrome.accentButton("Open BarTer editor##barter_open",ImGui.vec2(-1,32))) open.set(true);
	}
}
