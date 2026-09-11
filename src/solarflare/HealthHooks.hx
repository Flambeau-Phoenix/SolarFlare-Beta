package solarflare;

import solarflare.chaincast.Chaincast;
import solarflare.combo.Combo;
import solarflare.conduit.Conduit;
import solarflare.HealthCache;

/**
 * Ring-1 postfix + Layer 1 resource poll. ImGui draws from HealthCache only.
 * Present: HP / shield / rage / mana / spark. Player.update: those plus overlay subsystems.
 */
class HealthHooks {
	/** Keep this class reachable under `-dce full` so the postfixes are retained. */
	public static function keep():Void {}

	/** Reused Sparkmaster slot snaps — no per-call Array / ConduitSlotSnap alloc. */
	static var conduitScratch:Array<ConduitSlotSnap> = null;
	static var conduitProcScratch:Array<ConduitProcSnap> = null;
	static var conduitProcCount:Int = 0;
	static var conduitSeenScratch:Array<String> = null;
	static var conduitSeenCount:Int = 0;
	static inline var MAX_CONDUIT_PROCS:Int = 16;

	static function ensureConduitScratch():Void {
		if (conduitScratch == null) {
			conduitScratch = [];
			var i = 0;
			while (i < ConduitCache.MAX_SLOTS) {
				conduitScratch.push(new ConduitSlotSnap());
				i++;
			}
		}
		if (conduitProcScratch == null) {
			conduitProcScratch = [];
			var j = 0;
			while (j < MAX_CONDUIT_PROCS) {
				conduitProcScratch.push(new ConduitProcSnap());
				j++;
			}
		}
		if (conduitSeenScratch == null)
			conduitSeenScratch = [];
	}

	/**
	 * Layer 1 light poll: mana/shield (no setter postfixes) from identity-only `localHero`.
	 * HP / rage / spark are mutator-driven; releaseStale runs from the observe loop.
	 */
	public static function observeLocal():Void {
		var heroDyn = HealthCache.localHero;
		if (heroDyn == null)
			return;
		if (ObserveDemand.resourceBars || ObserveDemand.auras) {
			sampleMana(heroDyn);
			sampleShield(heroDyn);
		}
	}

	@:hlx.postfix(st.Player.update)
	static function onPlayerUpdate(self:Dynamic, dt:Float, result:Void):Void {
		var heroDyn = FieldWalk.extractObject(self, "hero");
		if (heroDyn == null)
			return;
		if (!claimLocalPlayer(self, heroDyn))
			return;
	}

	/** Typed `isMyHero` then FieldWalk `isMe`. Both branches adopt via `sampleFull`. */
	static function claimLocalPlayer(self:Dynamic, heroDyn:Dynamic):Bool {
		try {
			var hero:ent.Hero = cast heroDyn;
			var mine = false;
			try
				mine = hero.isMyHero()
			catch (_:Dynamic)
				mine = false;
			if (mine) {
				adoptLocalHero(heroDyn, "typed", "isMyHero");
				return true;
			}
		} catch (_:Dynamic) {}
		if (!FieldWalk.extractBool(self, "isMe"))
			return false;
		adoptLocalHero(heroDyn, "fieldwalk", "isMe");
		return true;
	}

	static function adoptLocalHero(heroDyn:Dynamic, idMethod:String, idName:String):Void {
		HealthCache.setLocalHero(heroDyn);
		ledgerIdent(idMethod, "HealthHooks.onPlayerUpdate", idName, "st.Player.update", "st.Player", "hook.self");
		// Identity + dirty only — full overlay reconcile is cadence-gated in observe().
		ObserveDemand.markOverlayDirty();
		var now = haxe.Timer.stamp();
		if (ObserveDemand.dueIdentity(now))
			sampleIdentity(heroDyn);
	}

	/** HP / max / shield / rage / mana / spark — HealthCache bars. Mana has no setter postfix. */
	static function sampleResources(heroDyn:Dynamic, src:String, hook:String, role:String):Void {
		sampleHp(heroDyn, src, hook, role);
		// Class resources: only while a vitals bar is shown or an aura may read them.
		if (ObserveDemand.resourceBars || ObserveDemand.auras) {
			sampleRage(heroDyn);
			sampleMana(heroDyn);
			sampleSpark(heroDyn);
			sampleShield(heroDyn);
		}
	}

	static function sampleFull(heroDyn:Dynamic, src:String, hook:String, role:String):Void {
		sampleResources(heroDyn, src, hook, role);
		if (ObserveDemand.prayers)
			samplePrayers(heroDyn);
		if (ObserveDemand.comboPoints)
			sampleComboPoints(heroDyn);
		if (ObserveDemand.chaincast)
			sampleChaincast(heroDyn);
		if (ObserveDemand.conduit)
			sampleConduit(heroDyn);
		sampleIdentity(heroDyn);
	}

	/**
	 * Bounded overlay reconcile from observe(). Hooks mark ObserveDemand.overlayDirty;
	 * this runs prayers / combo / chaincast / conduit only when demanded and due.
	 */
	public static function reconcileOverlays():Void {
		var heroDyn = HealthCache.localHero;
		if (heroDyn == null)
			return;
		var now = haxe.Timer.stamp();
		if (!ObserveDemand.dueOverlayReconcile(now))
			return;
		if (ObserveDemand.prayers)
			samplePrayers(heroDyn);
		if (ObserveDemand.comboPoints)
			sampleComboPoints(heroDyn);
		if (ObserveDemand.chaincast)
			sampleChaincast(heroDyn);
		if (ObserveDemand.conduit)
			sampleConduit(heroDyn);
	}

	static function sampleHp(heroDyn:Dynamic, src:String, hook:String, role:String):Void {
		try {
			var hero:ent.Hero = cast heroDyn;
			var hp = hero.get_health();
			var maxHp = hero.get_maxHealth();
			HealthCache.set(hp, maxHp);
			ledgerHp("typed", src, hp, maxHp, "get_health", "", hook, "ent.Hero", role);
		} catch (_:Dynamic) {
			var hp = FieldWalk.extractNumber(heroDyn, "health", HealthCache.current);
			var maxHp = FieldWalk.extractNumber(heroDyn, "maxHealth", HealthCache.max);
			HealthCache.set(hp, maxHp);
			ledgerHp("fieldwalk", src, hp, maxHp, "health",
				solarflare.debug.ResolutionLedger.fieldStep(heroDyn, "health"), hook, "ent.Hero", role);
		}
	}

	static function sampleIdentity(heroDyn:Dynamic):Void {
		var name = "";
		var region = "";
		var uid = "";
		try {
			var hero:ent.Hero = cast heroDyn;
			if (hero != null) {
				name = solarflare.combatlog.UniqueHeroName.of(hero);
				if (name == null || name.length == 0) {
					try
						name = hero.getName()
					catch (_:Dynamic) {}
				}
				if (name == null || name.length == 0) {
					try
						name = hero.name
					catch (_:Dynamic) {}
				}
				try {
					var p:st.Player = hero.getPlayer();
					if (p == null)
						p = hero.player;
					region = firstRegionString(p);
					uid = playerUidOf(p);
				} catch (_:Dynamic) {}
			}
		} catch (_:Dynamic) {}
		if (name == null || name.length == 0)
			name = solarflare.combatlog.UniqueHeroName.of(heroDyn);
		if (name == null || name.length == 0)
			name = cleanIdent(FieldWalk.extractString(heroDyn, "name"));
		if (name == null || name.length == 0)
			name = cleanIdent(FieldWalk.extractString(heroDyn, "networkPropName"));
		if (region == null || region.length == 0)
			region = firstRegionString(FieldWalk.extractObject(heroDyn, "player"));
		if (uid == null || uid.length == 0)
			uid = playerUidOf(FieldWalk.extractObject(heroDyn, "player"));
		if (region == null || region.length == 0) {
			try
				region = firstRegionString(GameApp.get())
			catch (_:Dynamic) {}
		}
		if (region == null || region.length == 0) {
			try {
				var hero:ent.Hero = cast heroDyn;
				var loc:Dynamic = hero.getWorldLocation();
				region = cleanIdent(loc);
			} catch (_:Dynamic) {}
		}
		if (name == null)
			name = "";
		if (region == null)
			region = "";
		if (uid == null)
			uid = "";
		HealthCache.setIdentity(name, region, uid);
		if (solarflare.debug.ResolutionLedger.armed()) {
			var L = solarflare.debug.ResolutionLedger;
			if (name.length > 0)
				L.touch("identity.heroName", "typed", "HealthHooks.sampleIdentity", "UniqueHeroName", "string", L.clip(name, 48));
			if (region.length > 0)
				L.touch("identity.region", "fieldwalk", "HealthHooks.sampleIdentity", "region", "string", L.clip(region, 48));
			if (uid.length > 0)
				L.touch("identity.playerUid", "typed", "HealthHooks.sampleIdentity", "uid", "string", L.clip(uid, 48));
		}
	}

	static function playerUidOf(obj:Dynamic):String {
		if (obj == null)
			return "";
		try {
			var p:st.Player = obj;
			if (p != null && p.uid != null && p.uid.length > 0)
				return cleanIdent(p.uid);
		} catch (_:Dynamic) {}
		var s = cleanIdent(FieldWalk.extractString(obj, "uid"));
		if (s.length > 0)
			return s;
		return cleanIdent(FieldWalk.extractString(obj, "_uid"));
	}

	static function firstRegionString(obj:Dynamic):String {
		if (obj == null)
			return "";
		var names = [
			"region", "serverRegion", "server", "serverName", "shard", "gateway",
			"world", "realm", "cluster", "datacenter", "dc"
		];
		for (n in names) {
			var s = cleanIdent(FieldWalk.extractString(obj, n));
			if (s.length > 0)
				return s;
		}
		return "";
	}

	static function cleanIdent(v:Dynamic):String {
		if (v == null)
			return "";
		try {
			if (Std.isOfType(v, String)) {
				var s:String = v;
				if (s == null)
					return "";
				s = StringTools.trim(s);
				if (s.length == 0)
					return "";
				var low = s.toLowerCase();
				if (low.indexOf("bytes") >= 0 || s.indexOf("{") >= 0)
					return "";
				return s;
			}
		} catch (_:Dynamic) {}
		return "";
	}

	static function samplePrayers(heroDyn:Dynamic):Void {
		try {
			var hero:ent.Hero = cast heroDyn;
			var priest = hero.get_priest();
			if (priest == null) {
				PrayerCache.clear();
				return;
			}
			var charged = 0;
			var slots = 0;
			try
				charged = priest.getChargedPrayerCount()
			catch (_:Dynamic) {}
			try
				slots = priest.getAvailablePrayerSlots()
			catch (_:Dynamic) {}
			if (solarflare.debug.ResolutionLedger.armed())
				solarflare.debug.ResolutionLedger.touch("prayer.ready", "typed", "HealthHooks.samplePrayers", "getChargedPrayerCount", "number", Std.string(charged));
			PrayerCache.notePriest(charged, slots);
		} catch (_:Dynamic) {
			PrayerCache.clear();
		}
	}

	@:hlx.postfix(ent.Hero.onSkillUse)
	static function onHeroSkillUse(self:Dynamic, skill:Dynamic, result:Void):Void {
		if (!HealthCache.isLocalHero(self))
			return;
		solarflare.geaux.GeauxCache.noteUse(self, skill);
		if (ComboPointsCache.isFinisherSkill(skill) || ComboPointsCache.isRogueSkillId(skillIdOf(skill)))
			ComboPointsCache.noteRogue();
		if (!ensureLocalPriest(self))
			return;
		PrayerCache.applySkill(skill);
	}

	@:hlx.postfix(script.SkillScript.chargePrayer)
	static function onScriptChargePrayer(self:Dynamic, result:Void):Void {
		try {
			var script:script.SkillScript = self;
			var hero = script.get_ownerHero();
			if (hero != null && !HealthCache.isLocalHero(hero))
				return;
			if (hero != null && !ensureLocalPriest(hero))
				return;
			var skill:Dynamic = script.skill;
			if (skill == null)
				skill = script.get_activeSkill();
			PrayerCache.applySkill(skill);
		} catch (_:Dynamic) {}
	}

	static function ensureLocalPriest(heroDyn:Dynamic):Bool {
		if (PrayerCache.active)
			return true;
		try {
			var hero:ent.Hero = cast heroDyn;
			if (hero.get_priest() == null)
				return false;
			PrayerCache.notePriest(0, 0);
			return true;
		} catch (_:Dynamic) {
			return PrayerCache.active;
		}
	}

	@:hlx.postfix(script.SkillScript.onPrayerTrigger)
	static function onPrayerTrigger(self:Dynamic, skill:Dynamic, result:Void):Void {
		if (!scriptOwnerIsLocalPriest(self))
			return;
		PrayerCache.spendAll();
	}

	@:hlx.postfix(script.skills.Priest_Sig_DivineIntervention.onSkillProc)
	static function onJudgmentProc(self:Dynamic, ctx:Dynamic, result:Void):Void {
		if (!scriptOwnerIsLocalPriest(self))
			return;
		PrayerCache.spendAll();
	}

	@:hlx.postfix(script.skills.Priest_Sig_DivineIntervention.onStep)
	static function onJudgmentStep(self:Dynamic, step:Dynamic, result:Void):Void {
		if (!scriptOwnerIsLocalPriest(self))
			return;
		PrayerCache.spendAll();
	}

	static function scriptOwnerIsLocalPriest(self:Dynamic):Bool {
		try {
			var script:script.SkillScript = self;
			var hero = script.get_ownerHero();
			if (hero == null || !HealthCache.isLocalHero(hero))
				return false;
			return ensureLocalPriest(hero);
		} catch (_:Dynamic) {
			return PrayerCache.active;
		}
	}

	@:hlx.postfix(ent.hero.PriestComponent.chargePrayer)
	static function onChargePrayer(self:Dynamic, prayerId:String, result:Void):Void {
		try {
			var hero = FieldWalk.extractObject(self, "hero");
			if (hero != null && !HealthCache.isLocalHero(hero))
				return;
			PrayerCache.chargeById(prayerId);
		} catch (_:Dynamic) {}
	}

	static function heroAttr(heroDyn:Dynamic):Dynamic {
		try {
			var hero:ent.Hero = cast heroDyn;
			if (hero != null && hero.attr != null)
				return hero.attr;
		} catch (_:Dynamic) {}
		return FieldWalk.extractObject(heroDyn, "attr");
	}

	static function sampleRage(heroDyn:Dynamic):Void {
		var attr = heroAttr(heroDyn);
		if (attr == null)
			return;
		var rv = Math.NaN;
		var method = "typed";
		try {
			var ha:ent.HeroAttributes = attr;
			if (ha != null)
				rv = ha.rage;
		} catch (_:Dynamic) {}
		if (Math.isNaN(rv)) {
			rv = FieldWalk.extractNumber(attr, "rage", HealthCache.rage);
			method = "fieldwalk";
		}
		var mx = FieldWalk.extractNumberAny(attr, ["maxRage", "rageMax"], 20);
		if (mx <= 0)
			mx = 20;
		HealthCache.setRage(rv, mx);
		ledgerNum("health.rage", method, "HealthHooks.sampleRage", "rage", rv, "ent.HeroAttributes", "hero.attr");
		ledgerNum("health.rageMax", "fieldwalk", "HealthHooks.sampleRage", "maxRage", mx, "ent.HeroAttributes", "hero.attr");
	}

	static function sampleMana(heroDyn:Dynamic):Void {
		var attr = heroAttr(heroDyn);
		if (attr == null) {
			HealthCache.clearMana();
			return;
		}
		var m = FieldWalk.extractNumberAny(attr, ["mana", "mp"], -1);
		if (m < 0) {
			HealthCache.clearMana();
			return;
		}
		var mx = FieldWalk.extractNumberAny(attr, ["maxMana", "manaMax"], 100);
		HealthCache.setMana(m, mx > 0 ? mx : 100);
		ledgerNum("health.mana", "fieldwalk", "HealthHooks.sampleMana", "mana", m, "ent.HeroAttributes", "hero.attr");
	}

	static function sampleSpark(heroDyn:Dynamic):Void {
		var isMage = false;
		try {
			var hero:ent.Hero = cast heroDyn;
			if (hero.get_mage() != null)
				isMage = true;
		} catch (_:Dynamic) {}
		var attr = heroAttr(heroDyn);
		if (attr == null) {
			HealthCache.clearSpark();
			return;
		}
		var s = FieldWalk.extractNumber(attr, "spark", -1);
		if (s < 0 || (!isMage && s <= 0)) {
			HealthCache.clearSpark();
			return;
		}
		var mx = FieldWalk.extractNumberAny(attr, ["maxSpark", "sparkMax"], 100);
		HealthCache.setSpark(s, mx > 0 ? mx : 100);
		ledgerNum("health.spark", "fieldwalk", "HealthHooks.sampleSpark", "spark", s, "ent.HeroAttributes", "attr");
	}

	/**
	 * Typed `Unit.getShield` is authority (ledger: positive absorb always typed across zones).
	 * FieldWalk `shield` only on cast/call failure — never when getShield returns 0.
	 */
	static function sampleShield(heroDyn:Dynamic):Void {
		var amount = 0.0;
		var method = "typed";
		var name = "getShield";
		var typedOk = false;
		try {
			var hero:ent.Unit = cast heroDyn;
			amount = hero.getShield();
			typedOk = true;
		} catch (_:Dynamic) {
			amount = 0;
		}
		if (!typedOk) {
			amount = FieldWalk.extractNumber(heroDyn, "shield", 0);
			method = "fieldwalk";
			name = "shield";
		}
		HealthCache.setShield(amount);
		ledgerNum("health.shield", method, "HealthHooks.sampleShield", name, amount, "ent.Unit", "localHero");
	}

	static function sampleComboPoints(heroDyn:Dynamic):Void {
		if (!detectRogue(heroDyn) && !ComboPointsCache.active) {
			ComboPointsCache.clear();
			return;
		}
		ComboPointsCache.noteRogue();
		var attr = heroAttr(heroDyn);
		if (attr == null)
			return;
		var pts = Math.NaN;
		var method = "typed";
		try {
			var ha:ent.HeroAttributes = attr;
			if (ha != null)
				pts = ha.comboPoint;
		} catch (_:Dynamic) {}
		if (Math.isNaN(pts)) {
			pts = FieldWalk.extractNumber(attr, "comboPoint", ComboPointsCache.current);
			method = "fieldwalk";
		}
		ComboPointsCache.set(pts);
		ledgerNum("combo.points", method, "HealthHooks.sampleComboPoints", "comboPoint", pts, "ent.HeroAttributes", "hero.attr");
	}

	/** No get_rogue — detect via Finisher / ComboPoints overrides, skill book, or Rogue_ ids. */
	static function detectRogue(heroDyn:Dynamic):Bool {
		if (heroDyn == null)
			return false;
		try {
			var hero:ent.Hero = cast heroDyn;
			if (hero.getSkillOverride(ComboPointsCache.comboId()) != null
				|| hero.getSkillOverride(ComboPointsCache.finisherId()) != null) {
				ComboPointsCache.noteRogue();
				return true;
			}
			var sig = hero.getSkillByInput("SignatureSkill");
			if (sig == null)
				sig = hero.getSkillByInput("Signature");
			if (ComboPointsCache.isFinisherSkill(sig) || ComboPointsCache.isRogueSkillId(skillIdOf(sig))) {
				ComboPointsCache.noteRogue();
				return true;
			}
			if (hero.getSkillOverride(solarflare.geaux.GeauxCache.ROGUE_SIG_SCRIPT) != null) {
				ComboPointsCache.noteRogue();
				return true;
			}
		} catch (_:Dynamic) {}
		for (id in solarflare.geaux.GeauxCache.bookIds) {
			if (ComboPointsCache.isRogueSkillId(id)) {
				ComboPointsCache.noteRogue();
				return true;
			}
		}
		for (s in solarflare.geaux.GeauxCache.signatures) {
			if (s != null && ComboPointsCache.isRogueSkillId(s.id)) {
				ComboPointsCache.noteRogue();
				return true;
			}
		}
		if (scanSkillLists(heroDyn))
			return true;
		try {
			if (scanSkillLists(FieldWalk.extractObject(heroDyn, "specialization")))
				return true;
		} catch (_:Dynamic) {}
		return ComboPointsCache.active;
	}

	static function scanSkillLists(owner:Dynamic):Bool {
		if (owner == null)
			return false;
		var names = ["skillSlots", "attackSkills", "weaponSkills", "skills"];
		for (name in names) {
			var arr = FieldWalk.extractObject(owner, name);
			if (arr == null)
				continue;
			var len = 0;
			try
				len = untyped arr.length
			catch (_:Dynamic)
				continue;
			if (len > 64)
				len = 64;
			for (i in 0...len) {
				var item:Dynamic = null;
				try
					item = untyped arr.getDyn(i)
				catch (_:Dynamic) {}
				var id = skillIdOf(item);
				if (id.length == 0) {
					try {
						var asStr:String = item;
						if (asStr != null)
							id = asStr;
					} catch (_:Dynamic) {}
				}
				if (ComboPointsCache.isRogueSkillId(id)) {
					ComboPointsCache.noteRogue();
					return true;
				}
			}
		}
		return false;
	}

	static function skillIdOf(skill:Dynamic):String {
		if (skill == null)
			return "";
		try {
			var shown = EngineSkillId.ofSkill(skill);
			if (shown != null && shown.length > 0)
				return shown;
		} catch (_:Dynamic) {}
		try {
			var s:st.skill.BaseSkill = skill;
			var k = s.kind;
			if (k != null && k.length > 0)
				return k;
		} catch (_:Dynamic) {}
		try {
			var k:String = FieldWalk.extractObject(skill, "kind");
			if (k != null && k.length > 0)
				return k;
		} catch (_:Dynamic) {}
		try {
			var id:String = FieldWalk.extractObject(skill, "id");
			if (id != null && id.length > 0)
				return id;
		} catch (_:Dynamic) {}
		try {
			var inf = FieldWalk.extractObject(skill, "inf");
			var id:String = FieldWalk.extractObject(inf, "id");
			if (id != null && id.length > 0)
				return id;
		} catch (_:Dynamic) {}
		return "";
	}

	@:hlx.postfix(ent.HeroAttributes.set_comboPoint)
	static function onSetComboPoint(self:Dynamic, value:Float, result:Float):Float {
		try {
			var ha:ent.HeroAttributes = self;
			if (HealthCache.isLocalHero(ha.hero)) {
				ComboPointsCache.noteRogue();
				ComboPointsCache.set(result);
				ledgerNum("combo.points", "engine", "HealthHooks.onSetComboPoint", "result", result, "ent.HeroAttributes", "hook.self");
			}
		} catch (_:Dynamic) {}
		return result;
	}

	@:hlx.postfix(script.skills.Rogue_Sig_Finisher.onStart)
	static function onFinisherStart(self:Dynamic, ctx:Dynamic, result:Void):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ComboPointsCache.noteRogue();
	}

	@:hlx.postfix(script.skills.Rogue_ComboPoints.tryGetComboPoint)
	static function onTryGetComboPoint(self:Dynamic, a0:Dynamic, a1:String, a2:Bool, result:Void):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ComboPointsCache.noteRogue();
	}

	static function scriptOwnerIsLocal(self:Dynamic):Bool {
		try {
			var script:script.SkillScript = self;
			var hero = script.get_ownerHero();
			return hero != null && HealthCache.isLocalHero(hero);
		} catch (_:Dynamic) {
			return false;
		}
	}

	/** Native: ent.Unit.set_health(a0:Float):Float — HP is not a Unit field; mutations go through this setter. */
	@:hlx.postfix(ent.Unit.set_health)
	static function onSetHealth(self:Dynamic, value:Float, result:Float):Float {
		if (HealthCache.isLocalHero(self)) {
			HealthCache.setCurrent(result);
			if (solarflare.debug.ResolutionLedger.armed())
				solarflare.debug.ResolutionLedger.note("health.current")
					.withMethod("engine")
					.withSrc("HealthHooks.onSetHealth")
					.withName("result")
					.withHook("ent.Unit.set_health")
					.withPayload("ent.Unit", "hook.self")
					.withArgs(["self", "value", "result"])
					.tryRoute("engine", "result")
					.tryRoute("typed", "get_health")
					.tryRoute("fieldwalk", "health")
					.num(result)
					.emit();
		}
		return result;
	}

	/**
	 * Leaf receive path (condensed: ent.Hero.onReceiveDamage). Incoming hits update local vitals.
	 * Native: (self, a0:st.skill.DamageResult):Void
	 */
	@:hlx.prefix(ent.Hero.onReceiveDamage)
	static function beforeHeroReceiveDamage(self:Dynamic, dmgObj:Dynamic):hlx.runtime.HlxPrefixControl {
		solarflare.combatlog.CombatLogHooks.beginDamage(dmgObj);
		return hlx.runtime.HlxPrefixControl.Continue;
	}

	@:hlx.postfix(ent.Hero.onReceiveDamage)
	static function onHeroReceiveDamage(self:Dynamic, dmgObj:Dynamic, result:Void):Void {
		solarflare.combatlog.CombatLogHooks.endDamage(self, dmgObj);
		if (!HealthCache.isLocalHero(self))
			return;
		try {
			var hero:ent.Hero = cast self;
			HealthCache.set(hero.get_health(), hero.get_maxHealth());
		} catch (_:Dynamic) {}
	}

	@:hlx.postfix(ent.HeroAttributes.set_rage)
	static function onSetRage(self:Dynamic, value:Float, result:Float):Float {
		try {
			var ha:ent.HeroAttributes = self;
			if (HealthCache.isLocalHero(ha.hero)) {
				var mx = HealthCache.rageMax > 0 ? HealthCache.rageMax : 20.0;
				try {
					var dyn:Dynamic = self;
					var cap = FieldWalk.extractNumberAny(dyn, ["maxRage", "rageMax"], -1);
					if (cap > 0)
						mx = cap;
					else
						mx = 20;
				} catch (_:Dynamic) {
					mx = 20;
				}
				HealthCache.setRage(result, mx);
				if (solarflare.debug.ResolutionLedger.armed())
					solarflare.debug.ResolutionLedger.note("health.rage")
						.withMethod("engine")
						.withSrc("HealthHooks.onSetRage")
						.withName("result")
						.withHook("ent.HeroAttributes.set_rage")
						.withPayload("ent.HeroAttributes", "hook.self")
						.withArgs(["self", "value", "result"])
						.tryRoute("engine", "result")
						.tryRoute("typed", "ha.rage")
						.num(result)
						.emit();
			}
		} catch (_:Dynamic) {}
		return result;
	}

	@:hlx.postfix(ent.HeroAttributes.set_spark)
	static function onSetSpark(self:Dynamic, value:Float, result:Float):Float {
		try {
			var ha:ent.HeroAttributes = self;
			if (HealthCache.isLocalHero(ha.hero)) {
				var mx = HealthCache.sparkMax > 0 ? HealthCache.sparkMax : 100.0;
				try {
					var dyn:Dynamic = self;
					var cap = FieldWalk.extractNumberAny(dyn, ["maxSpark", "sparkMax"], -1);
					if (cap > 0)
						mx = cap;
				} catch (_:Dynamic) {}
				HealthCache.setSpark(result, mx);
				if (solarflare.debug.ResolutionLedger.armed())
					solarflare.debug.ResolutionLedger.note("health.spark")
						.withMethod("engine")
						.withSrc("HealthHooks.onSetSpark")
						.withName("result")
						.withHook("ent.HeroAttributes.set_spark")
						.withPayload("ent.HeroAttributes", "hook.self")
						.withArgs(["self", "value", "result"])
						.num(result)
						.emit();
			}
		} catch (_:Dynamic) {}
		return result;
	}

	/**
	 * Native: ent.Unit.onInflictDamage(a0:st.skill.DamageResult):Void
	 * Postfix N+1: (self, damageResult, result:Void)
	 * CheatSheet Phase 0 DPS path — `self` is attacker (hero or owned summon).
	 */
	@:hlx.postfix(ent.Unit.onInflictDamage)
	static function onInflictDamage(self:Dynamic, dmgObj:Dynamic, result:Void):Void {
		if (self == null || dmgObj == null)
			return;
		if (HealthCache.isLocalHero(self)) {
			try {
				var hero:ent.Hero = cast self;
				HealthCache.set(hero.get_health(), hero.get_maxHealth());
			} catch (_:Dynamic) {}
		}
		// Credit bee/imp/… via summonOwner; Lightsaber ingests ROLE_YOU combat-log lines.
		try
			solarflare.combatlog.CombatLogCache.noteInflict(self, dmgObj)
		catch (_:Dynamic) {}
	}

	static function sampleChaincast(heroDyn:Dynamic):Void {
		if (!detectMageChaincast(heroDyn) && !ChaincastCache.active) {
			ChaincastCache.clear();
			return;
		}
		try {
			var hero:ent.Hero = cast heroDyn;
			var readySt = findHeroStatusAny(hero, ChaincastCache.lookupReadyIds());
			if (readySt == null)
				readySt = findStatusByKind(heroDyn, true, false);
			if (readySt != null) {
				ChaincastCache.noteMage();
				applyChainRemain(readySt);
				ChaincastCache.setReady();
				return;
			}
			var st = findHeroStatusAny(hero, ChaincastCache.lookupAccumIds());
			if (st == null)
				st = findStatusByKind(heroDyn, false, true);
			if (st == null) {
				if (ChaincastCache.active)
					ChaincastCache.setAccum(0);
				ChaincastCache.setRemain(0, 0, false);
				return;
			}
			ChaincastCache.noteMage();
			applyChainRemain(st);
			ChaincastCache.setAccum(readStatusStacks(st));
		} catch (_:Dynamic) {
			if (!ChaincastCache.active)
				ChaincastCache.clear();
		}
	}

	static function detectMageChaincast(heroDyn:Dynamic):Bool {
		if (heroDyn == null)
			return false;
		try {
			var hero:ent.Hero = cast heroDyn;
			if (hero.get_mage() == null)
				return false;
			if (hero.getSkillOverride(ChaincastCache.talentId()) != null) {
				ChaincastCache.noteMage();
				return true;
			}
			var th = ChaincastCache.talentHashId();
			if (th.length > 0 && hero.getSkillOverride(th) != null) {
				ChaincastCache.noteMage();
				return true;
			}
			if (findChaincastStatus(hero) != null) {
				ChaincastCache.noteMage();
				return true;
			}
		} catch (_:Dynamic) {}
		for (id in solarflare.geaux.GeauxCache.bookIds) {
			if (ChaincastCache.isChaincastKind(id)) {
				ChaincastCache.noteMage();
				return true;
			}
		}
		return ChaincastCache.active;
	}

	static function findChaincastStatus(hero:ent.Hero):st.skill.Status {
		var ready = findHeroStatusAny(hero, ChaincastCache.lookupReadyIds());
		if (ready != null)
			return ready;
		return findHeroStatusAny(hero, ChaincastCache.lookupAccumIds());
	}

	static function findHeroStatus(hero:ent.Hero, id:String):st.skill.Status {
		if (hero == null || id == null || id.length == 0)
			return null;
		try {
			var st = hero.getStatus(id, null);
			if (st != null)
				return st;
		} catch (_:Dynamic) {}
		try {
			var asGo:ent.GameObject = cast hero;
			var st = hero.getStatus(id, asGo);
			if (st != null)
				return st;
		} catch (_:Dynamic) {}
		return null;
	}

	static function findHeroStatusAny(hero:ent.Hero, ids:Array<String>):st.skill.Status {
		if (hero == null || ids == null)
			return null;
		for (id in ids) {
			var st = findHeroStatus(hero, id);
			if (st != null)
				return st;
		}
		return null;
	}

	static function findStatusByKind(heroDyn:Dynamic, wantReady:Bool, wantAccum:Bool):st.skill.Status {
		var item = findListItemByKind(heroDyn, "statuses", wantReady, wantAccum);
		if (item != null)
			return item;
		return findListItemByKind(heroDyn, "statusList", wantReady, wantAccum);
	}

	static function findListItemByKind(owner:Dynamic, name:String, wantReady:Bool, wantAccum:Bool):st.skill.Status {
		var arr = FieldWalk.extractObject(owner, name);
		if (arr == null)
			return null;
		var len = FieldWalk.arrayLen(arr);
		if (len > 64)
			len = 64;
		var i = 0;
		while (i < len) {
			var item = FieldWalk.arrayAt(arr, i);
			i++;
			if (item == null)
				continue;
			var id = skillIdOf(item);
			if (wantReady && ChaincastCache.isReadyKind(id)) {
				try {
					var st:st.skill.Status = item;
					return st;
				} catch (_:Dynamic) {}
			}
			if (wantAccum && ChaincastCache.isAccumKind(id)) {
				try {
					var st:st.skill.Status = item;
					return st;
				} catch (_:Dynamic) {}
			}
		}
		return null;
	}

	@:hlx.postfix(st.skill.Status.set_stacks)
	static function onStatusSetStacks(self:Dynamic, value:Int, result:Int):Int {
		if (isLocalChaincastStatus(self)) {
			ChaincastCache.noteMage();
			var kind = "";
			try
				kind = skillIdOf(self)
			catch (_:Dynamic) {}
			if (ChaincastCache.isReadyKind(kind)) {
				if (result > 0) {
					applyChainRemain(self);
					ChaincastCache.setReady();
				} else {
					ChaincastCache.setAccum(0);
					ChaincastCache.setRemain(0, 0, false);
				}
			} else {
				applyChainRemain(self);
				ChaincastCache.setAccum(result);
			}
		} else if (isLocalConduitStatus(self)) {
			ConduitCache.noteMage();
			sampleConduit(HealthCache.localHero);
		}
		return result;
	}

	@:hlx.postfix(ent.hero.MageComponent.propagateMageChainCast)
	static function onPropagateChainCast(self:Dynamic, ctx:Dynamic, result:Void):Void {
		try {
			var mage:ent.hero.MageComponent = self;
			var hero = FieldWalk.extractObject(mage, "hero");
			if (hero == null)
				hero = FieldWalk.extractObject(self, "hero");
			if (hero != null && HealthCache.isLocalHero(hero)) {
				ChaincastCache.noteMage();
				sampleChaincast(hero);
			}
		} catch (_:Dynamic) {}
	}

	@:hlx.postfix(script.skills.Mage_Talent_Chaincast.onMageChainCast)
	static function onTalentChainCast(self:Dynamic, ctx:Dynamic, result:Void):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ChaincastCache.noteMage();
		try {
			var script:script.SkillScript = self;
			var hero = script.get_ownerHero();
			if (hero != null)
				sampleChaincast(hero);
		} catch (_:Dynamic) {}
	}

	@:hlx.postfix(script.skills.Mage_Talent_Chaincast.onSkillProc)
	static function onTalentChaincastProc(self:Dynamic, ctx:Dynamic, result:Void):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ChaincastCache.noteMage();
		try {
			var script:script.SkillScript = self;
			var hero = script.get_ownerHero();
			if (hero != null)
				sampleChaincast(hero);
		} catch (_:Dynamic) {}
	}

	static function isLocalChaincastStatus(statusDyn:Dynamic):Bool {
		if (statusDyn == null)
			return false;
		var kind = "";
		try
			kind = skillIdOf(statusDyn)
		catch (_:Dynamic) {}
		if (!ChaincastCache.isChaincastKind(kind))
			return false;
		return statusOwnerIsLocal(statusDyn);
	}

	static function isLocalConduitStatus(statusDyn:Dynamic):Bool {
		if (statusDyn == null)
			return false;
		var kind = "";
		try
			kind = skillIdOf(statusDyn)
		catch (_:Dynamic) {}
		if (!ConduitCache.isConduitKind(kind))
			return false;
		return statusOwnerIsLocal(statusDyn);
	}

	static function statusOwnerIsLocal(statusDyn:Dynamic):Bool {
		try {
			var st:st.skill.Status = statusDyn;
			var owner = st.instigator;
			if (owner != null && HealthCache.isLocalHero(owner))
				return true;
		} catch (_:Dynamic) {}
		try {
			var owner = FieldWalk.extractObject(statusDyn, "owner");
			if (owner != null && HealthCache.isLocalHero(owner))
				return true;
		} catch (_:Dynamic) {}
		try {
			var script:script.SkillScript = statusDyn;
			var hero = script.get_ownerHero();
			if (hero != null && HealthCache.isLocalHero(hero))
				return true;
		} catch (_:Dynamic) {}
		return false;
	}

	static function sampleConduit(heroDyn:Dynamic):Void {
		if (!detectMageConduit(heroDyn) && !ConduitCache.active) {
			ConduitCache.clear();
			return;
		}
		ensureConduitScratch();
		try {
			var hero:ent.Hero = cast heroDyn;
			var mage = hero.get_mage();
			var snaps = conduitScratch;
			var nSlots = ConduitCache.DEFAULT_SLOTS;
			var filled = 0;
			var i = 0;
			while (i < ConduitCache.MAX_SLOTS) {
				var snap = snaps[i];
				snap.id = "";
				snap.filled = false;
				snap.stacks = 0;
				snap.power = false;
				i++;
			}
			if (mage != null) {
				var cap = 0;
				try
					cap = mage.getAvailableConduitLevel()
				catch (_:Dynamic)
					cap = 0;
				if (cap < 1 || cap > ConduitCache.MAX_SLOTS)
					cap = 0;
				var lastFilled = -1;
				i = 0;
				while (i < ConduitCache.MAX_SLOTS) {
					var skill:Dynamic = null;
					try
						skill = mage.getConduitSlot(i)
					catch (_:Dynamic)
						skill = null;
					var snap = snaps[i];
					if (skill != null) {
						var id = skillIdOf(skill);
						snap.id = ConduitCache.canonical(id);
						if (snap.id.length == 0)
							snap.id = id != null ? id : "";
						snap.filled = snap.id.length > 0;
						snap.power = ConduitCache.isPowerKind(snap.id);
						if (snap.filled)
							lastFilled = i;
					}
					i++;
				}
				if (cap > 0)
					nSlots = cap;
				else if (lastFilled >= 0)
					nSlots = lastFilled + 1;
				if (nSlots < 1)
					nSlots = ConduitCache.DEFAULT_SLOTS;
				if (nSlots > ConduitCache.MAX_SLOTS)
					nSlots = ConduitCache.MAX_SLOTS;
			}
			var power = 0;
			var left = 0.0;
			collectConduitProcs(heroDyn, hero);
			var pi = 0;
			while (pi < conduitProcCount) {
				var p = conduitProcScratch[pi];
				pi++;
				if (p.power && p.stacks > power) {
					power = p.stacks;
					left = p.left;
				}
			}
			var si = 0;
			while (si < nSlots) {
				var snap = snaps[si];
				si++;
				if (!snap.filled)
					continue;
				filled++;
				var match = findProcForSlot(snap.id);
				if (match != null)
					snap.stacks = match.stacks;
				else if (snap.power)
					snap.stacks = power;
			}
			if (power > 0 && filled == 0) {
				var extra = snaps[0];
				extra.id = ConduitCache.powerId();
				extra.filled = true;
				extra.power = true;
				extra.stacks = power;
				filled = 1;
				if (nSlots < 1)
					nSlots = 1;
			}
			ConduitCache.setSlots(snaps, nSlots, filled, power, left);
		} catch (_:Dynamic) {
			if (!ConduitCache.active)
				ConduitCache.clear();
		}
	}

	static function findProcForSlot(slotId:String):ConduitProcSnap {
		if (slotId == null || slotId.length == 0 || conduitProcCount < 1)
			return null;
		var want = ConduitCache.canonical(slotId);
		var pi = 0;
		while (pi < conduitProcCount) {
			var p = conduitProcScratch[pi];
			pi++;
			var have = ConduitCache.canonical(p.id);
			if (ConduitCache.idEq(have, want))
				return p;
			if (want.length > 4 && ConduitCache.idContains(have, want))
				return p;
			if (have.length > 4 && ConduitCache.idContains(want, have))
				return p;
		}
		return null;
	}

	static function collectConduitProcs(heroDyn:Dynamic, hero:ent.Hero):Void {
		conduitProcCount = 0;
		conduitSeenCount = 0;
		ingestConduitList(heroDyn, "statuses");
		if (conduitProcCount < 1)
			ingestConduitList(heroDyn, "statusList");
		if (hero != null) {
			for (id in ConduitCache.lookupIds()) {
				if (seenHas(id) || seenHas(ConduitCache.canonical(id)))
					continue;
				var st = findHeroStatus(hero, id);
				if (st == null)
					continue;
				ingestConduitItem(st);
			}
		}
	}

	static function seenHas(key:String):Bool {
		if (key == null || key.length == 0)
			return false;
		var i = 0;
		while (i < conduitSeenCount) {
			if (conduitSeenScratch[i] == key)
				return true;
			i++;
		}
		return false;
	}

	static function seenAdd(key:String):Void {
		if (key == null || key.length == 0 || seenHas(key))
			return;
		if (conduitSeenCount < conduitSeenScratch.length)
			conduitSeenScratch[conduitSeenCount] = key;
		else
			conduitSeenScratch.push(key);
		conduitSeenCount++;
	}

	static function ingestConduitList(owner:Dynamic, name:String):Void {
		var arr = FieldWalk.extractObject(owner, name);
		if (arr == null)
			return;
		var len = FieldWalk.arrayLen(arr);
		if (len > 64)
			len = 64;
		var i = 0;
		while (i < len) {
			ingestConduitItem(FieldWalk.arrayAt(arr, i));
			i++;
		}
	}

	static function ingestConduitItem(item:Dynamic):Void {
		if (item == null || conduitProcCount >= MAX_CONDUIT_PROCS)
			return;
		var id = skillIdOf(item);
		if (!ConduitCache.isConduitKind(id))
			return;
		var key = ConduitCache.canonical(id);
		if (key.length == 0)
			key = id;
		if (seenHas(key))
			return;
		seenAdd(key);
		seenAdd(id);
		var snap = conduitProcScratch[conduitProcCount];
		snap.id = key;
		snap.stacks = readStatusStacks(item);
		if (snap.stacks < 1)
			snap.stacks = 1;
		var dur = solarflare.SkillRemain.read(item);
		snap.left = dur.left;
		snap.power = ConduitCache.isPowerKind(key);
		conduitProcCount++;
	}

	static function readStatusStacks(item:Dynamic):Int {
		var n = 0;
		try {
			var st:st.skill.Status = item;
			n = st.stacks;
			try {
				var info = st.getStatusInfo();
				if (info != null && info.stacks > 0)
					n = info.stacks;
			} catch (_:Dynamic) {}
		} catch (_:Dynamic) {
			n = Std.int(FieldWalk.extractNumber(item, "stacks", 0));
		}
		if (n < 0)
			n = 0;
		return n;
	}

	static function applyChainRemain(item:Dynamic):Void {
		var dur = solarflare.SkillRemain.read(item);
		ChaincastCache.setRemain(dur.left, dur.progress, dur.valid);
		if (!dur.valid)
			solarflare.debug.PayloadProbe.captureStatus(item);
	}

	static function detectMageConduit(heroDyn:Dynamic):Bool {
		if (heroDyn == null)
			return false;
		try {
			var hero:ent.Hero = cast heroDyn;
			if (hero.get_mage() == null)
				return false;
			ConduitCache.noteMage();
			return true;
		} catch (_:Dynamic) {}
		for (id in solarflare.geaux.GeauxCache.bookIds) {
			if (ConduitCache.isConduitKind(id)) {
				ConduitCache.noteMage();
				return true;
			}
		}
		return ConduitCache.active;
	}

	static function mageHeroFromComponent(self:Dynamic):Dynamic {
		try {
			var mage:ent.hero.MageComponent = self;
			var hero = FieldWalk.extractObject(mage, "hero");
			if (hero == null)
				hero = FieldWalk.extractObject(self, "hero");
			if (hero != null && HealthCache.isLocalHero(hero))
				return hero;
		} catch (_:Dynamic) {}
		return null;
	}

	@:hlx.postfix(ent.hero.MageComponent.set_conduits)
	static function onSetConduits(self:Dynamic, value:Dynamic, result:Dynamic):Dynamic {
		var hero = mageHeroFromComponent(self);
		if (hero != null) {
			ConduitCache.noteMage();
			sampleConduit(hero);
		}
		return result;
	}

	@:hlx.postfix(ent.hero.MageComponent.syncConduit)
	static function onSyncConduit(self:Dynamic, result:Void):Void {
		var hero = mageHeroFromComponent(self);
		if (hero != null) {
			ConduitCache.noteMage();
			sampleConduit(hero);
		}
	}

	@:hlx.postfix(script.skills.Mage_Conduit_Power.onStartConduit)
	static function onPowerConduitStart(self:Dynamic, result:Void):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ConduitCache.noteMage();
		sampleConduit(HealthCache.localHero);
	}

	@:hlx.postfix(script.skills.Mage_Conduit_Projectile.onStartConduit)
	static function onProjectileConduitStart(self:Dynamic, result:Void):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ConduitCache.noteMage();
		sampleConduit(HealthCache.localHero);
	}

	@:hlx.postfix(script.skills.Mage_Talent_ConduitSparkExplosion_Conduit.onStartConduit)
	static function onSparkConduitStart(self:Dynamic, result:Void):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ConduitCache.noteMage();
		sampleConduit(HealthCache.localHero);
	}

	@:hlx.postfix(script.skills.Mage_Talent_ConduitLifebolt_Conduit.onStartConduit)
	static function onLifeboltConduitStart(self:Dynamic, result:Void):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ConduitCache.noteMage();
		sampleConduit(HealthCache.localHero);
	}

	@:hlx.postfix(script.skills.Mage_Talent_ConduitResidues.onConduitTriggers)
	static function onConduitResidues(self:Dynamic, a0:Dynamic, result:Void):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ConduitCache.noteMage();
		sampleConduit(HealthCache.localHero);
	}

	static function ledgerHp(method:String, src:String, hp:Float, maxHp:Float, name:String, step:String, hook:String, payloadType:String, role:String):Void {
		if (!solarflare.debug.ResolutionLedger.armed())
			return;
		var L = solarflare.debug.ResolutionLedger;
		L.touch("health.current", method, src, name, "number", Std.string(Math.round(hp * 1000) / 1000), step, hook);
		L.touch("health.max", method, src, method == "typed" ? "get_maxHealth" : "maxHealth", "number", Std.string(Math.round(maxHp * 1000) / 1000), step, hook);
	}

	static function ledgerIdent(method:String, src:String, name:String, hook:String, payloadType:String, role:String):Void {
		if (!solarflare.debug.ResolutionLedger.armed())
			return;
		solarflare.debug.ResolutionLedger.touch("identity.localHero", method, src, name, "bool", "true", "", hook);
	}

	static function ledgerNum(key:String, method:String, src:String, name:String, v:Float, payloadType:String, role:String):Void {
		if (!solarflare.debug.ResolutionLedger.armed())
			return;
		solarflare.debug.ResolutionLedger.touch(key, method, src, name, "number", Std.string(Math.round(v * 1000) / 1000));
	}
}
