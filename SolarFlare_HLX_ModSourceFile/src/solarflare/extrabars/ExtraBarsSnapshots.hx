package solarflare.extrabars;

/**
 * Allocation-free equality probes over ExtraBarsConfig. They replace per-frame Json.stringify signatures:
 * `matches` is a handful of primitive compares that exits on the first difference; `capture` runs only after a change.
 */
class ExtraBarsActivationSnapshot {
	var valid = false;
	var enabled = false;
	var prefix = "";
	var mode = "";
	var ids:Array<String> = [];
	var barOn:Array<Bool> = [];
	var counts:Array<Int> = [];
	var kinds:Array<String> = [];
	var keys:Array<Int> = [];
	var mods:Array<Int> = [];
	public function new() {}
	public function invalidate():Void valid = false;
	/** Same inputs as ExtraBarsConfig.activationSignature(): globals, bar id/enabled/count and visible-slot assignments. */
	public function matches(cfg:ExtraBarsConfig):Bool {
		if (!valid || cfg.enabled != enabled || cfg.prefix != prefix || cfg.mode != mode || cfg.bars.length != ids.length) return false;
		var at = 0;
		for (b in 0...cfg.bars.length) {
			var bar = cfg.bars[b];
			if (bar.id != ids[b] || bar.enabled != barOn[b] || bar.slotCount != counts[b]) return false;
			for (i in 0...bar.slotCount) {
				var slot = bar.slots[i];
				if (at >= kinds.length || slot.itemKind != kinds[at] || slot.keyCode != keys[at] || slot.modifiers != mods[at]) return false;
				at++;
			}
		}
		return at == kinds.length;
	}
	public function capture(cfg:ExtraBarsConfig):Void {
		valid = true; enabled = cfg.enabled; prefix = cfg.prefix; mode = cfg.mode;
		ids = []; barOn = []; counts = []; kinds = []; keys = []; mods = [];
		for (bar in cfg.bars) {
			ids.push(bar.id); barOn.push(bar.enabled); counts.push(bar.slotCount);
			for (i in 0...bar.slotCount) { var slot = bar.slots[i]; kinds.push(slot.itemKind); keys.push(slot.keyCode); mods.push(slot.modifiers); }
		}
	}
}

/** Inputs of ExtraBarsAssignmentIndex.rebuild: bar id, bar name and every retained cell's key (all 10, visible or not). */
class ExtraBarsAssignmentSnapshot {
	var valid = false;
	var ids:Array<String> = [];
	var names:Array<String> = [];
	var keys:Array<Int> = [];
	public function new() {}
	public function invalidate():Void valid = false;
	public function matches(cfg:ExtraBarsConfig):Bool {
		if (!valid || cfg.bars.length != ids.length) return false;
		for (b in 0...cfg.bars.length) {
			var bar = cfg.bars[b];
			if (bar.id != ids[b] || bar.name != names[b]) return false;
			for (i in 0...10) if (bar.slots[i].keyCode != keys[b * 10 + i]) return false;
		}
		return true;
	}
	public function capture(cfg:ExtraBarsConfig):Void {
		valid = true; ids = []; names = []; keys = [];
		for (bar in cfg.bars) {
			ids.push(bar.id); names.push(bar.name);
			for (i in 0...10) keys.push(bar.slots[i].keyCode);
		}
	}
}
