package solarflare.aura;

import solarflare.FieldWalk;
import solarflare.HealthCache;
import solarflare.ObserveDemand;

/**
 * Status lifecycle dirty-wake for AuraStatusCache.
 * Present poll remains duration/list authority; hooks only mark local edges.
 * ABI from Farever gamelib_metadata (Ubuntu data dir).
 */
class StatusObserveHooks {
	public static function keep():Void {}

	@:hlx.postfix(st.skill.Status.init)
	static function onInit(self:Dynamic, result:Void):Void {
		if (isLocalStatus(self))
			wake("st.skill.Status.init", self);
	}

	@:hlx.postfix(st.skill.Status.set_stacks)
	static function onSetStacks(self:Dynamic, value:Int, result:Int):Int {
		if (isLocalStatus(self))
			wake("st.skill.Status.set_stacks", self);
		return result;
	}

	@:hlx.postfix(st.skill.Status.set_refreshDuration)
	static function onRefresh(self:Dynamic, value:Float, result:Float):Float {
		if (isLocalStatus(self))
			wake("st.skill.Status.set_refreshDuration", self);
		return result;
	}

	@:hlx.postfix(st.skill.Status.extendDuration)
	static function onExtend(self:Dynamic, value:Float, result:Void):Void {
		if (isLocalStatus(self))
			wake("st.skill.Status.extendDuration", self);
	}

	/** Pending live for expiry authority; still useful as cancel wake. */
	@:hlx.postfix(st.skill.Status.onRemove)
	static function onRemove(self:Dynamic, result:Void):Void {
		if (isLocalStatus(self))
			wake("st.skill.Status.onRemove", self);
	}

	@:hlx.postfix(ent.GameObject.__net_mark_statuses)
	static function onNetStatuses(self:Dynamic, incoming:Dynamic, result:Dynamic):Dynamic {
		if (HealthCache.isLocalHero(self)) {
			ObserveDemand.markAuraStatusDirty();
			if (solarflare.debug.ResolutionLedger.armed())
				solarflare.debug.ResolutionLedger.touch(
					"status.hook",
					"postfix",
					"StatusObserveHooks.onNetStatuses",
					"localHero",
					"bool",
					"true",
					"",
					"ent.GameObject.__net_mark_statuses"
				);
		}
		return result;
	}

	static function wake(hook:String, statusDyn:Dynamic):Void {
		ObserveDemand.markAuraStatusDirty();
		if (!solarflare.debug.ResolutionLedger.armed())
			return;
		var id = "";
		try {
			var bs:st.skill.BaseSkill = statusDyn;
			if (bs != null && bs.kind != null)
				id = bs.kind;
		} catch (_:Dynamic) {}
		solarflare.debug.ResolutionLedger.touch(
			"status.hook",
			"postfix",
			"StatusObserveHooks",
			id.length > 0 ? id : "localStatus",
			"string",
			id,
			"",
			hook
		);
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
