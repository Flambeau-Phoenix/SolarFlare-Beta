package solarflare.debug;

/**
 * Semantic keys the HUD actually uses. Live hits join these so analysis can
 * flag catalog-but-never-hit vs hit-but-not-cataloged.
 */
@:keep
class ResolutionDef {
	public var key:String;
	public var feature:String;
	public var element:String;
	public var reason:String;
	public var importance:String;

	public function new(key:String, feature:String, element:String, reason:String, importance:String) {
		this.key = key;
		this.feature = feature;
		this.element = element;
		this.reason = reason;
		this.importance = importance;
	}
}

@:keep
class ResolutionCatalog {
	static var byKey:Map<String, ResolutionDef>;
	static var list:Array<ResolutionDef>;

	public static function keep():Void {
		ensure();
	}

	public static function get(key:String):ResolutionDef {
		ensure();
		if (key == null)
			return null;
		return byKey.get(key);
	}

	public static function all():Array<ResolutionDef> {
		ensure();
		return list;
	}

	public static function toJsonRows():Array<Dynamic> {
		ensure();
		var rows:Array<Dynamic> = [];
		var i = 0;
		while (i < list.length) {
			var d = list[i];
			rows.push({
				key: d.key,
				feature: d.feature,
				element: d.element,
				reason: d.reason,
				importance: d.importance
			});
			i++;
		}
		return rows;
	}

	static function ensure():Void {
		if (list != null)
			return;
		list = [];
		byKey = new Map();
		add("identity.localHero", "Identity", "localHeroPointer", "Stable unit for later vitals / Geaux / combat polls", "P0");
		add("health.current", "Vitals", "hpFill", "Draw HP ratio on the vitals bar", "P0");
		add("health.max", "Vitals", "hpFill", "HP bar denominator", "P0");
		add("health.shield", "Vitals", "hpShieldSuffix", "Absorb shown as (+N) after HP", "P0");
		add("geaux.slot.id", "GeauxBar", "slotIdentity", "Icon stem and CD key for an action-bar cell", "P0");
		add("geaux.slot.cdLeft", "GeauxBar", "slotCdSweep", "Remaining cooldown on a Geaux cell", "P0");
		add("geaux.slot.cdMax", "GeauxBar", "slotCdSweep", "Cooldown duration for remaining ratio", "P0");
		add("geaux.slot.ready", "GeauxBar", "slotReady", "Cell not on cooldown", "P0");
		add("skill.id", "GeauxBar", "engineSkillId", "Confirmed script-style skill id", "P0");
		add("health.rage", "Vitals", "rageFill", "Warrior rage bar / pips", "P1");
		add("health.rageMax", "Vitals", "rageFill", "Rage cap (usually 20)", "P1");
		add("health.mana", "Vitals", "manaFill", "Mana bar when the class exposes it", "P1");
		add("health.spark", "Vitals", "sparkFill", "Mage spark resource bar", "P1");
		add("combo.points", "Combo", "comboPips", "Rogue combo point pips", "P1");
		add("prayer.ready", "Prayer", "prayerPips", "Priest life/shield/smite ready flags", "P1");
		add("geaux.slot.affordable", "GeauxBar", "slotDim", "Dim cell when resource cost is missing", "P1");
		add("combat.hit.amount", "CombatLog", "hitAmount", "Damage number on a hit line", "P2");
		add("combat.hit.crit", "CombatLog", "hitFlags", "Critical flag on a hit line", "P2");
		add("combat.hit.kill", "CombatLog", "hitFlags", "Kill flag on a hit line", "P2");
		add("combat.cast.skillId", "CombatLog", "castLine", "Skill id on a cast line", "P2");
		add("combat.target", "CombatLog", "currentTarget", "Hero target pointer for involvement filter", "P2");
		add("chat.text", "Chat", "messageBody", "Incoming chat text", "P2");
		add("chat.sender", "Chat", "senderName", "Incoming chat sender", "P2");
		add("chat.channel", "Chat", "channelLabel", "Incoming chat channel", "P2");
		add("status.remain", "Aura", "statusRemain", "Status / BaseSkill remaining duration", "P2");
		add("status.present", "Aura", "statusPresent", "Typed getStatusCount / list match for aura status.present", "P2");
		add("status.sample", "Aura", "statusSample", "AuraStatusCache sample / dirty-wake reconcile", "P2");
		add("status.hook", "Aura", "statusHook", "Local Status lifecycle dirty-wake postfix", "P2");
		add("skill.instantReady", "Aura", "instantReady", "SkillScript.shouldPlayInstantly / owner *_Proc status", "P2");
		add("getrifty.inInstance", "GetRifty", "riftFlag", "Show instance remain vs portal schedule", "P2");
		add("getrifty.remain", "GetRifty", "instanceRemain", "Instance time remaining text", "P2");
		add("identity.heroName", "Identity", "heroName", "Local hero display name / resource profiles", "P3");
		add("identity.region", "Identity", "serverRegion", "Shard / region string when exposed", "P3");
		add("identity.playerUid", "Identity", "playerUid", "st.Player.uid when exposed", "P3");
		add("geaux.drag.skillId", "GeauxBar", "dragAssign", "Skill id from HUD drag onto a Geaux cell", "P3");
		add("geaux.slot.cdMaxCdb", "GeauxBar", "cdbCdMax", "CastleDB cooldown max when Skill getters are 0", "P3");
	}

	static function add(key:String, feature:String, element:String, reason:String, importance:String):Void {
		var d = new ResolutionDef(key, feature, element, reason, importance);
		list.push(d);
		byKey.set(key, d);
	}
}
