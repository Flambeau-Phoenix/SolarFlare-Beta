package solarflare.aura.signal;

class AuraSignalCatalog {
	static var list:Array<AuraSignalDescriptor>;
	static var groupNames:Array<String>;
	public static function all():Array<AuraSignalDescriptor> { ensure(); return list; }
	public static function groups():Array<String> { ensure(); return groupNames; }
	public static function find(id:String):AuraSignalDescriptor {
		ensure(); if (id == null) return null; for (d in list) if (d.id == id) return d; return null;
	}
	public static function inGroup(group:String):Array<AuraSignalDescriptor> {
		ensure();
		var out:Array<AuraSignalDescriptor> = [];
		for (d in list) if (d.group == group) out.push(d);
		return out;
	}
	static function ensure():Void {
		if (list != null) return;
		list = [];
		groupNames = [];
		add("resource.health.current", "Health current", "Resources", Number);
		add("resource.health.ratio", "Health percent", "Resources", Percent);
		add("resource.shield.ratio", "Shield percent", "Resources", Percent);
		add("resource.rage.ratio", "Rage percent", "Resources", Percent);
		add("resource.mana.ratio", "Mana percent", "Resources", Percent);
		add("resource.spark.ratio", "Spark percent", "Resources", Percent);
		add("resource.generic.ratio", "Class resource percent", "Resources", Percent);
		add("resource.combo.count", "Combo points", "Resources", Count);
		add("resource.combo.atMax", "Combo points at max", "Resources", Boolean);
		add("skill.ready", "Skill ready", "Skills", Boolean, "skill");
		add("skill.affordable", "Skill affordable", "Skills", Boolean, "skill");
		add("skill.inCooldown", "Skill in cooldown", "Skills", Boolean, "skill");
		add("skill.cooldownLeft", "Skill cooldown left", "Skills", Duration, "skill");
		add("skill.cooldownProgress", "Skill cooldown progress", "Skills", Percent, "skill");
		// skill.specialReady (shouldHighlightSkill) kept in reader for legacy saves; not offered in picker.
		add("skill.instantReady", "Instant cast ready (skill script)", "Instant cast", Boolean, "skill");
		add("status.present", "Buff/debuff on me", "Statuses", Boolean, "status");
		add("status.stacks", "Stacks on me", "Statuses", Count, "status");
		add("status.durationLeft", "Duration left on me", "Statuses", Duration, "status");
		add("status.durationProgress", "Duration progress on me", "Statuses", Percent, "status");
		add("status.count", "Status container count", "Statuses", Count);
		add("status.overflow", "Status scan overflow", "Statuses", Boolean);
		add("prayer.charged", "Charged prayers", "Class mechanics", Count);
		add("prayer.lifeReady", "Life prayer ready", "Class mechanics", Boolean);
		add("prayer.shieldReady", "Shield prayer ready", "Class mechanics", Boolean);
		add("prayer.smiteReady", "Smite prayer ready", "Class mechanics", Boolean);
		add("chaincast.stacks", "Chaincast stacks", "Class mechanics", Count);
		add("chaincast.ready", "Chaincast ready", "Class mechanics", Boolean);
		add("chaincast.remaining", "Chaincast time left", "Class mechanics", Duration);
		add("conduit.filledCount", "Filled conduits", "Class mechanics", Count);
		add("conduit.powerStacks", "Conduit power stacks", "Class mechanics", Count);
		add("conduit.effectiveStacks", "Conduit active stacks", "Class mechanics", Count);
		add("conduit.powerLeft", "Conduit power time left", "Class mechanics", Duration);
		add("attackCombo.step", "Attack combo step", "Class mechanics", Count);
		add("attackCombo.withinChain", "Within attack combo", "Class mechanics", Boolean);
		add("attackCombo.finalFlash", "Attack combo final flash", "Class mechanics", Boolean);
		add("encounter.inRift", "In rift", "Encounter", Boolean);
		add("target.valid", "Has current target", "Target", Boolean);
		add("target.kindMatches", "Target kind matches", "Target", Boolean, "unit");
		add("target.isBoss", "Target is boss", "Target", Boolean);
		add("target.isElite", "Target is elite", "Target", Boolean);
		add("target.hpRatio", "Target HP percent", "Target", Percent);
		add("combat.killKindMatches", "Kill of unit kind", "Combat", Boolean, "unit");
		add("combat.damageTakenRecent", "Recent damage taken (max hit)", "Combat", Number);
		add("event.cast.recent", "Enemy cast age (seconds)", "Enemy casts", Duration, "skill");
		add("event.cast.active", "Enemy cast/channel active", "Enemy casts", Boolean, "skill");
		add("skill.charges", "Skill charges remaining", "Skills", Count, "skill");
		add("skill.chargesMax", "Skill charges max", "Skills", Count, "skill");
		add("custom.script", "Custom Haxe Expression", "Scripting", Boolean, "script");
	}
	static function add(id:String, label:String, group:String, kind:AuraValueKind, subjectKind:String = ""):Void {
		list.push(new AuraSignalDescriptor(id, label, group, kind, subjectKind));
		if (groupNames.indexOf(group) < 0)
			groupNames.push(group);
	}
}
