package solarflare.barter;

/** One BarTer cell — mutually exclusive skill, consumable or status. */
class BarTerSlotConfig {
	public var skillId:String = "";
	public var statusId:String = "";
	/** Effective native input action; only these cells follow weapon loadouts. */
	public var nativeActionId:String = "";
	/** Catalog item id; mutually exclusive with skillId when assigned. */
	public var itemKind:String = "";

	public function new() {}

	public function hasSkill():Bool return skillId != null && skillId.length > 0;
	public function hasItem():Bool return itemKind != null && itemKind.length > 0;
	public function hasStatus():Bool return statusId != null && statusId.length > 0;
	public function hasContent():Bool return hasSkill() || hasItem() || hasStatus();

	public function dump():Dynamic {
		return {
			skillId: skillId,
			statusId: statusId,
			nativeActionId: nativeActionId,
			itemKind: itemKind
		};
	}

	public function apply(data:Dynamic):Void {
		if (data == null) return;
		skillId = text(data, "skillId", "");
		statusId = text(data, "statusId", "");
		nativeActionId = text(data, "nativeActionId", "");
		itemKind = text(data, "itemKind", "");
		if (hasItem() && hasSkill())
			skillId = "";
		if (hasStatus()) { skillId = itemKind = nativeActionId = ""; }
		if (!hasSkill()) nativeActionId = "";
		#if hl
		scrubDirtyIds();
		#end
	}

	public function assignSkill(id:String):Void {
		skillId = solarflare.geaux.GeauxCache.sanitizeSkillId(id);
		itemKind = "";
		statusId = nativeActionId = "";
	}

	public function assignItem(kind:String):Void {
		#if hl
		itemKind = kind != null ? solarflare.ui.ByteUtil.materialize(kind) : "";
		if (solarflare.ui.ByteUtil.isDumpShape(itemKind))
			itemKind = "";
		#else
		itemKind = kind == null ? "" : StringTools.trim(kind);
		#end
		skillId = "";
		statusId = nativeActionId = "";
	}
	public function assignStatus(id:String):Void {
		statusId = id == null ? "" : StringTools.trim(id);
		skillId = itemKind = nativeActionId = "";
	}

	/** Clear dump-shaped / Bytes-leaked ids so seed can refill. */
	public function scrubDirtyIds():Bool {
		var changed = false;
		if (skillId.length > 0) {
			var clean = solarflare.geaux.GeauxCache.sanitizeSkillId(skillId);
			if (clean != skillId) {
				skillId = clean;
				changed = true;
			}
		}
		#if hl
		if (statusId.length > 0) {
			var clean = solarflare.ui.ByteUtil.materialize(statusId);
			if (solarflare.ui.ByteUtil.isDumpShape(clean)) clean = "";
			if (clean != statusId) { statusId = clean; changed = true; }
		}
		if (itemKind.length > 0 && solarflare.ui.ByteUtil.isDumpShape(itemKind)) {
			itemKind = "";
			changed = true;
		}
		#end
		return changed;
	}

	public function clearContent():Void {
		skillId = "";
		itemKind = "";
		statusId = nativeActionId = "";
	}

	public function clearSkill():Void {
		skillId = "";
		nativeActionId = "";
	}

	static function text(data:Dynamic, field:String, fallback:String):String {
		try {
			var v:Dynamic = Reflect.field(data, field);
			if (v == null) return fallback;
			if (Std.isOfType(v, String)) return cast v;
			return fallback;
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
}
