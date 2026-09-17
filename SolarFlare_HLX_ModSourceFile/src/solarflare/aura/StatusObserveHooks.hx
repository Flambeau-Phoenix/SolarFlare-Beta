package solarflare.aura;

import solarflare.FieldWalk;
import solarflare.HealthCache;
import solarflare.ObserveDemand;
import solarflare.debug.ResolutionLedger;

/**
 * Status lifecycle dirty-wake for AuraStatusCache.
 * Present poll remains duration/list authority; hooks only mark local edges.
 * Ledger: one row per (status.hook, postfix:<phase>, statusId); hits/preview update in place.
 * ABI from Farever gamelib_metadata (Ubuntu data dir).
 */
class StatusObserveHooks {
	public static function keep():Void {}

	/** New Status instance — the apply edge, so any stamp from a prior instance is stale. */
	@:hlx.postfix(st.skill.Status.init)
	static function onInit(self:Dynamic, result:Void):Void {
		if (isLocalStatus(self))
			wake("st.skill.Status.init", "postfix:init", self, "init", true);
	}

	@:hlx.postfix(st.skill.Status.set_stacks)
	static function onSetStacks(self:Dynamic, value:Int, result:Int):Int {
		if (isLocalStatus(self))
			wake("st.skill.Status.set_stacks", "postfix:set_stacks", self, value);
		return result;
	}

	@:hlx.postfix(st.skill.Status.set_refreshDuration)
	static function onRefresh(self:Dynamic, value:Float, result:Float):Float {
		if (isLocalStatus(self))
			wake("st.skill.Status.set_refreshDuration", "postfix:set_refreshDuration", self, value, true);
		return result;
	}

	@:hlx.postfix(st.skill.Status.extendDuration)
	static function onExtend(self:Dynamic, value:Float, result:Void):Void {
		if (isLocalStatus(self))
			wake("st.skill.Status.extendDuration", "postfix:extendDuration", self, value, true);
	}

	/** Immediate expiry authority: clear cached present before next 20 Hz poll. */
	@:hlx.postfix(st.skill.Status.onRemove)
	static function onRemove(self:Dynamic, result:Void):Void {
		if (!isLocalStatus(self))
			return;
		try {
			var id = statusIdOf(self);
			if (id != null && id.length > 0)
				AuraStatusCache.markAbsent(id);
		} catch (_:Dynamic) {}
		wake("st.skill.Status.onRemove", "postfix:onRemove", self, "removed");
	}

	@:hlx.postfix(ent.GameObject.__net_mark_statuses)
	static function onNetStatuses(self:Dynamic, incoming:Dynamic, result:Dynamic):Dynamic {
		if (HealthCache.isLocalHero(self)) {
			ObserveDemand.markAuraStatusDirty();
			if (ResolutionLedger.armed())
				ResolutionLedger.recordStatusHook(
					"postfix:__net_mark_statuses",
					"localHero",
					"true",
					"__net_mark_statuses",
					"ent.GameObject.__net_mark_statuses"
				);
		}
		return result;
	}

	/**
	 * `reStamp` marks the hooks that actually move a live timer, so AuraStatusCache drops
	 * its one-shot stamp and re-resolves. The id must be resolved regardless of whether
	 * the ledger is armed, otherwise invalidation would only work while recording.
	 */
	static function wake(hookPath:String, phase:String, statusDyn:Dynamic, previewValue:Dynamic,
			reStamp:Bool = false):Void {
		ObserveDemand.markAuraStatusDirty();
		var id = reStamp || ResolutionLedger.armed() ? statusIdOf(statusDyn) : "";
		if (reStamp && id.length > 0)
			AuraStatusCache.invalidateStamp(id);
		if (!ResolutionLedger.armed())
			return;
		ResolutionLedger.recordStatusHook(phase, id, previewValue, hookPhase(phase), hookPath);
	}

	static function statusIdOf(statusDyn:Dynamic):String {
		if (statusDyn == null)
			return "";
		try {
			var bs:st.skill.BaseSkill = statusDyn;
			if (bs != null && bs.kind != null)
				return ResolutionLedger.cleanId(bs.kind);
		} catch (_:Dynamic) {}
		try {
			var s = FieldWalk.extractString(statusDyn, "kind");
			if (s != null && s.length > 0)
				return ResolutionLedger.cleanId(s);
		} catch (_:Dynamic) {}
		try {
			var s = FieldWalk.extractString(statusDyn, "id");
			if (s != null && s.length > 0)
				return ResolutionLedger.cleanId(s);
		} catch (_:Dynamic) {}
		return "";
	}

	static function hookPhase(phase:String):String {
		if (phase == null || phase.length == 0)
			return "unknown";
		if (StringTools.startsWith(phase, "postfix:"))
			return phase.substr(8);
		var i = phase.lastIndexOf(".");
		if (i >= 0 && i + 1 < phase.length)
			return phase.substr(i + 1);
		return phase;
	}

	/** Carrier on local hero — not instigator (who applied). */
	static function isLocalStatus(statusDyn:Dynamic):Bool {
		if (statusDyn == null)
			return false;
		try {
			var bs:st.skill.BaseSkill = statusDyn;
			var unit = bs.get_ownerUnit();
			if (unit != null)
				return HealthCache.isLocalHero(unit);
			var hero = bs.get_ownerHero();
			if (hero != null)
				return HealthCache.isLocalHero(hero);
			if (bs.owner != null)
				return HealthCache.isLocalHero(bs.owner);
		} catch (_:Dynamic) {}
		var owner = FieldWalk.extractObject(statusDyn, "owner");
		if (owner != null && HealthCache.isLocalHero(owner))
			return true;
		var target = FieldWalk.extractObject(statusDyn, "target");
		if (target != null && HealthCache.isLocalHero(target))
			return true;
		var unit = FieldWalk.extractObject(statusDyn, "unit");
		return unit != null && HealthCache.isLocalHero(unit);
	}
}
