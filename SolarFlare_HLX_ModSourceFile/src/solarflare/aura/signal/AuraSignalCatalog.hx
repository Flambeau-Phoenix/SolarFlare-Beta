package solarflare.aura.signal;

class AuraSignalCatalog {
	static var list:Array<AuraSignalDescriptor>;
	public static function all():Array<AuraSignalDescriptor> { ensure(); return list; }
	public static function find(id:String):AuraSignalDescriptor {
		ensure(); if (id == null) return null; for (d in list) if (d.id == id) return d; return null;
	}
	static function ensure():Void {
		if (list != null) return;
		list = [];
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
		add("status.present", "Status present", "Statuses", Boolean, "status");
		add("status.stacks", "Status stacks", "Statuses", Count, "status");
		add("status.durationLeft", "Status duration left", "Statuses", Duration, "status");
		add("status.durationProgress", "Status duration progress", "Statuses", Percent, "status");
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
		add("custom.script", "Custom Haxe Expression", "Scripting", Boolean, "script");
	}
	static function add(id:String, label:String, group:String, kind:AuraValueKind, subjectKind:String = ""):Void
		list.push(new AuraSignalDescriptor(id, label, group, kind, subjectKind));
}
