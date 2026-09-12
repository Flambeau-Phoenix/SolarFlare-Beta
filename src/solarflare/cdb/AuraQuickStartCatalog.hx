package solarflare.cdb;

typedef AuraQuickStartSkill = {
	var id:String;
	var name:String;
}

typedef AuraQuickStartBoss = {
	var id:String;
	var name:String;
	var skills:Array<AuraQuickStartSkill>;
}

/** Immutable, build-time CastleDB links used by the Aura quick-start wizard. */
class AuraQuickStartCatalog {
	public static var bosses(default, null):Array<AuraQuickStartBoss> = [];
	static var byId = new Map<String, AuraQuickStartBoss>();
	static var skillNames = new Map<String, String>();
	static var ready = false;

	public static function keep():Void {
		ensure();
	}

	public static function boss(id:String):AuraQuickStartBoss {
		ensure();
		return id == null ? null : byId.get(id);
	}

	public static function skillName(id:String):String {
		ensure();
		if (id == null || id.length == 0) return "";
		var name = skillNames.get(id);
		return name != null ? name : "";
	}

	static function ensure():Void {
		if (ready) return;
		ready = true;
		try {
			var raw:Dynamic = haxe.Json.parse(haxe.Resource.getString("aura-quickstart"));
			var rows:Array<Dynamic> = cast raw.bosses;
			for (row in rows) {
				if (row == null) continue;
				var id = Std.string(row.id);
				if (id == null || id.length == 0) continue;
				var name = row.name != null ? Std.string(row.name) : id;
				var skills:Array<AuraQuickStartSkill> = [];
				if (row.skills != null)
					for (skill in (cast row.skills:Array<Dynamic>)) {
						if (skill == null || skill.id == null) continue;
						var skillId = Std.string(skill.id);
						var skillName = skill.name != null ? Std.string(skill.name) : skillId;
						skills.push({id:skillId, name:skillName});
						if (!skillNames.exists(skillId)) skillNames.set(skillId, skillName);
					}
				var entry:AuraQuickStartBoss = {id:id, name:name, skills:skills};
				bosses.push(entry);
				byId.set(id, entry);
			}
		} catch (_:Dynamic) {}
	}
}
