package solarflare;

import solarflare.chaincast.Chaincast;
import solarflare.combo.Combo;
import solarflare.conduit.Conduit;
import solarflare.HealthCache;

/** Latched health.current / health.max rows for one ledgerHp emit site. */
class HpBinds {
	public var cur = new solarflare.debug.LedgerBinding();
	public var max = new solarflare.debug.LedgerBinding();
	public var maxName:String = "maxHealth";

	public function new() {}
}

/**
 * Ring-1 postfix + Layer 1 resource poll. ImGui draws from HealthCache only.
	 * Present sampling owns identity, vitals, status-derived class state, and cooldown state.
 */
class HealthHooks {
	/** Keep this class reachable under `-dce full` so the postfixes are retained. */
	public static function keep():Void {}

	static var conduitScratch:Array<ConduitSlotSnap> = [];
	static var conduitProcScratch:Array<ConduitProcSnap> = [];
	static var conduitProcCount:Int = 0;
	static var conduitSeen:Map<String, Bool> = new Map();

	/**
	 * Layer 1 per-present poll of HUD resource bars from identity-only `HealthCache.localHero`.
	 * Overlay subsystems (prayers / combo / chaincast / conduit / identity) resample on `st.Player.update`.
	 */
	public static function observeLocal():Void {
		var heroDyn = HealthCache.localHero;
		if (heroDyn == null)
			return;
		sampleResources(heroDyn, "HealthHooks.observeLocal", "", "localHero");
	}

	/** Present-loop identity authority; no per-frame player trampoline is installed. */
	public static function observeLocalPlayer(app:GameApp):Void {
		var heroDyn:Dynamic = app == null ? null : app.hero;
		if (heroDyn == null) {
			if (HealthCache.localHero != null) HealthCache.clearLocalHero();
			return;
		}
		if (HealthCache.localHero != heroDyn) {
			// Use the same local-player authority as hooks; never adopt an arbitrary unit.
			if (!HealthCache.isLocalHero(heroDyn)) return;
			adoptLocalHero(heroDyn, "present", "isMyHero", "HealthHooks.observeLocalPlayer");
		} else if (ObserveDemand.dueIdentity(haxe.Timer.stamp())) {
			sampleIdentity(heroDyn);
		}
	}

	/**
	 * Fires once per st.Player per frame, so everything here is on the frame budget.
	 * The pinned localHero doubles as the identity memo: exactly one hero can be local,
	 * so once it is resolved every other player is answered by pointer compare alone.
	 * Recovery from a stale pin is owned by releaseStaleLocalHero / observeLocalPlayer,
	 * not by this hook, so skipping the ladder here cannot strand identity.
	 */
	static function onPlayerUpdate(self:Dynamic, dt:Float):Void {
		var heroDyn = FieldWalk.extractObject(self, "hero");
		if (heroDyn == null) {
			// Local player with cleared hero (zone unload) — drop GC pin.
			// Nothing pinned means nothing to release; skip the reflection probe.
			if (HealthCache.localHero == null)
				return;
			try {
				if (FieldWalk.extractBool(self, "isMe"))
					HealthCache.clearLocalHero();
			} catch (_:Dynamic) {}
			return;
		}
		if (HealthCache.localHero != null) {
			// Identity already resolved — this is either the known local hero (nothing
			// to re-adopt) or, by elimination, a remote player. Either way no ladder.
			return;
		}
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

	/**
	 * Idempotent: re-adopting the already-pinned hero must not re-mark the overlay dirty,
	 * or dueOverlayReconcile can never fall back to OVERLAY_IDLE_S.
	 */
	static function adoptLocalHero(heroDyn:Dynamic, idMethod:String, idName:String,
			src:String = "HealthHooks.onPlayerUpdate"):Void {
		var changed = true;
		try
			changed = HealthCache.localHero == null
				|| (cast HealthCache.localHero : Dynamic) != (cast heroDyn : Dynamic)
		catch (_:Dynamic)
			changed = true;
		HealthCache.setLocalHero(heroDyn);
		if (!changed)
			return;
		ledgerIdent(idMethod, src, idName, idMethod == "present" ? "" : "st.Player.update",
			idMethod == "present" ? "ent.Hero" : "st.Player", idMethod == "present" ? "GameApp.hero" : "hook.self");
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
		HealthCache.deadKnown = false; HealthCache.dead = false;
		try {
			var go:ent.GameObject = cast heroDyn;
			HealthCache.dead = go.isDead(); HealthCache.deadKnown = true;
		} catch (_:Dynamic) {}
		try {
			var hero:ent.Hero = cast heroDyn;
			var hp = hero.get_health();
			var maxHp = hero.get_maxHealth();
			HealthCache.set(hp, maxHp);
			ledgerHp("typed", src, hp, maxHp, "get_health", "", hook, "ent.Hero", role);
		} catch (_:Dynamic) {
			var hp = FieldWalk.extractNumber(heroDyn, "health", Math.NaN);
			var maxHp = FieldWalk.extractNumber(heroDyn, "maxHealth", Math.NaN);
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
				if (s.indexOf("bytes") >= 0 || s.indexOf("Bytes") >= 0 || s.indexOf("{") >= 0)
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

	static function onHeroSkillUse(self:Dynamic, skill:Dynamic):Void {
		if (!HealthCache.isLocalHero(self))
			return;
		if (!ensureLocalPriest(self))
			return;
		PrayerCache.applySkill(skill);
	}

	static function onScriptChargePrayer(self:Dynamic):Void {
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

	static function onPrayerTrigger(self:Dynamic, skill:Dynamic):Void {
		// Live dispatcher (proto 82 / findex 45208). Base script.SkillScript.onPrayerTrigger is empty Ret.
		if (!scriptOwnerIsLocalPriest(self))
			return;
		PrayerCache.spendAll();
	}

	static function onJudgmentProc(self:Dynamic, ctx:Dynamic):Void {
		if (!scriptOwnerIsLocalPriest(self))
			return;
		PrayerCache.spendAll();
	}

	static function onJudgmentStep(self:Dynamic, step:Dynamic):Void {
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

	static function onChargePrayer(self:Dynamic, prayerId:String):Void {
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
		// No engine getMaxRage; Warrior rage cap is a typed constant.
		var mx = 20.0;
		HealthCache.setRage(rv, mx);
		ledgerNum("health.rage", method, "HealthHooks.sampleRage", "rage", rv, "ent.HeroAttributes", "hero.attr");
		ledgerNum("health.rageMax", "typed", "HealthHooks.sampleRage", "defaultRageCap", mx, "ent.HeroAttributes", "hero.attr");
	}

	static function sampleMana(heroDyn:Dynamic):Void {
		var attr = heroAttr(heroDyn);
		if (attr == null) {
			HealthCache.clearMana();
			return;
		}
		// v6 exposes no `mana` field on ent.UnitAttributes; the generic class resource is
		// `specialEnergy` (cdb attribute `SpecialEnergyRegen`). Legacy mana names stay as a
		// last-ditch fallback so this still resolves if a build renames the field.
		var m = FieldWalk.extractNumberAny(attr, ["specialEnergy", "mana", "mp"], -1);
		if (m < 0) {
			HealthCache.clearMana();
			return;
		}
		var mx = FieldWalk.extractNumberAny(attr, ["specialEnergyMax", "maxSpecialEnergy", "maxMana", "manaMax"], 100);
		HealthCache.setMana(m, mx > 0 ? mx : 100);
		ledgerNum("health.specialEnergy", "fieldwalk", "HealthHooks.sampleMana", "specialEnergy", m, "ent.UnitAttributes", "hero.attr");
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
		// Zero absorb is a valid typed result; demote only on cast/call failure.
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

	static function onFinisherStart(self:Dynamic, ctx:Dynamic):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ComboPointsCache.noteRogue();
	}

	static function onTryGetComboPoint(self:Dynamic, a0:Dynamic, a1:String, a2:Bool):Void {
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
	static function beforeHeroReceiveDamage(self:Dynamic, dmgObj:Dynamic):hlx.runtime.HlxPrefixControl {
		return hlx.runtime.HlxPrefixControl.Continue;
	}

	static function onHeroReceiveDamage(self:Dynamic, dmgObj:Dynamic):Void {
		if (HealthCache.isLocalHero(self))
			solarflare.combatlog.CombatLogCache.noteHit(self, dmgObj, "ent.Hero.onReceiveDamage");
	}

	static function onSetRage(self:Dynamic, value:Float, result:Float):Float {
		try {
			var ha:ent.HeroAttributes = self;
			if (HealthCache.isLocalHero(ha.hero)) {
				var mx = 20.0;
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
	static function onInflictDamage(self:Dynamic, dmgObj:Dynamic):Void {
		if (self == null || dmgObj == null)
			return;
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

	/** Fan-out called by the sole Status.set_stacks trampoline in StatusObserveHooks. */
	public static function handleMageStatusStacks(self:Dynamic, result:Int):Void {
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
			ObserveDemand.markOverlayDirty();
		}
	}

	static function onPropagateChainCast(self:Dynamic, ctx:Dynamic):Void {
		try {
			var mage:ent.hero.MageComponent = self;
			var hero = FieldWalk.extractObject(mage, "hero");
			if (hero == null)
				hero = FieldWalk.extractObject(self, "hero");
			if (hero != null && HealthCache.isLocalHero(hero)) {
				ChaincastCache.noteMage();
				ObserveDemand.markOverlayDirty();
			}
		} catch (_:Dynamic) {}
	}

	static function onTalentChainCast(self:Dynamic, ctx:Dynamic):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ChaincastCache.noteMage();
		ObserveDemand.markOverlayDirty();
	}

	static function onTalentChaincastProc(self:Dynamic, ctx:Dynamic):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ChaincastCache.noteMage();
		ObserveDemand.markOverlayDirty();
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

	static function ensureConduitScratch():Void {
		while (conduitScratch.length < ConduitCache.MAX_SLOTS)
			conduitScratch.push(new ConduitSlotSnap());
	}

	static function resetConduitSlot(snap:ConduitSlotSnap):Void {
		if (snap == null)
			return;
		snap.id = "";
		snap.filled = false;
		snap.stacks = 0;
		snap.power = false;
	}

	static function sampleConduit(heroDyn:Dynamic):Void {
		if (!detectMageConduit(heroDyn) && !ConduitCache.active) {
			ConduitCache.clear();
			return;
		}
		try {
			var hero:ent.Hero = cast heroDyn;
			var mage = hero.get_mage();
			ensureConduitScratch();
			var i = 0;
			while (i < ConduitCache.MAX_SLOTS) {
				resetConduitSlot(conduitScratch[i]);
				i++;
			}
			var nSlots = ConduitCache.DEFAULT_SLOTS;
			var filled = 0;
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
					var snap = conduitScratch[i];
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
				var snap = conduitScratch[si];
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
				var extra = conduitScratch[0];
				extra.id = ConduitCache.powerId();
				extra.filled = true;
				extra.power = true;
				extra.stacks = power;
				filled = 1;
				if (nSlots < 1)
					nSlots = 1;
			}
			ConduitCache.setSlots(conduitScratch, nSlots, filled, power, left);
		} catch (_:Dynamic) {
			if (!ConduitCache.active)
				ConduitCache.clear();
		}
	}

	static function findProcForSlot(slotId:String):ConduitProcSnap {
		if (slotId == null || slotId.length == 0)
			return null;
		var want = ConduitCache.canonical(slotId);
		var pi = 0;
		while (pi < conduitProcCount) {
			var p = conduitProcScratch[pi];
			pi++;
			var have = ConduitCache.canonical(p.id);
			if (have == want)
				return p;
			if (want.length > 4 && have.indexOf(want) >= 0)
				return p;
			if (have.length > 4 && want.indexOf(have) >= 0)
				return p;
		}
		return null;
	}

	static function collectConduitProcs(heroDyn:Dynamic, hero:ent.Hero):Void {
		conduitProcCount = 0;
		conduitSeen.clear();
		ingestConduitList(heroDyn, "statuses");
		if (conduitProcCount < 1)
			ingestConduitList(heroDyn, "statusList");
		if (hero != null) {
			for (id in ConduitCache.lookupIds()) {
				if (conduitSeen.exists(id) || conduitSeen.exists(ConduitCache.canonical(id)))
					continue;
				var st = findHeroStatus(hero, id);
				if (st == null)
					continue;
				ingestConduitItem(st);
			}
		}
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
		if (item == null)
			return;
		var id = skillIdOf(item);
		if (!ConduitCache.isConduitKind(id))
			return;
		var key = ConduitCache.canonical(id);
		if (key.length == 0)
			key = id;
		if (conduitSeen.exists(key))
			return;
		conduitSeen.set(key, true);
		conduitSeen.set(id, true);
		var snap:ConduitProcSnap;
		if (conduitProcCount < conduitProcScratch.length)
			snap = conduitProcScratch[conduitProcCount];
		else {
			snap = new ConduitProcSnap();
			conduitProcScratch.push(snap);
		}
		conduitProcCount++;
		snap.id = key;
		snap.stacks = readStatusStacks(item);
		if (snap.stacks < 1)
			snap.stacks = 1;
		var dur = solarflare.SkillRemain.read(item);
		snap.left = dur.left;
		snap.power = ConduitCache.isPowerKind(key);
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

	static function onSetConduits(self:Dynamic, value:Dynamic, result:Dynamic):Dynamic {
		var hero = mageHeroFromComponent(self);
		if (hero != null) {
			ConduitCache.noteMage();
			ObserveDemand.markOverlayDirty();
		}
		return result;
	}

	static function onSyncConduit(self:Dynamic):Void {
		var hero = mageHeroFromComponent(self);
		if (hero != null) {
			ConduitCache.noteMage();
			ObserveDemand.markOverlayDirty();
		}
	}

	static function onPowerConduitStart(self:Dynamic):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ConduitCache.noteMage();
		ObserveDemand.markOverlayDirty();
	}

	static function onProjectileConduitStart(self:Dynamic):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ConduitCache.noteMage();
		ObserveDemand.markOverlayDirty();
	}

	static function onSparkConduitStart(self:Dynamic):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ConduitCache.noteMage();
		ObserveDemand.markOverlayDirty();
	}

	static function onLifeboltConduitStart(self:Dynamic):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ConduitCache.noteMage();
		ObserveDemand.markOverlayDirty();
	}

	static function onConduitResidues(self:Dynamic, a0:Dynamic):Void {
		if (!scriptOwnerIsLocal(self))
			return;
		ConduitCache.noteMage();
		ObserveDemand.markOverlayDirty();
	}

	// Thin public surface for domain-specific hook adapter classes. Business logic
	// and samplers remain here during the staged split; no adapter walks engine state.
	public static inline function hookPlayerUpdate(self:Dynamic, dt:Float):Void onPlayerUpdate(self, dt);
	public static inline function hookHeroSkillUse(self:Dynamic, skill:Dynamic):Void onHeroSkillUse(self, skill);
	public static inline function hookScriptChargePrayer(self:Dynamic):Void onScriptChargePrayer(self);
	public static inline function hookPrayerTrigger(self:Dynamic, skill:Dynamic):Void onPrayerTrigger(self, skill);
	public static inline function hookJudgmentProc(self:Dynamic, ctx:Dynamic):Void onJudgmentProc(self, ctx);
	public static inline function hookJudgmentStep(self:Dynamic, step:Dynamic):Void onJudgmentStep(self, step);
	public static inline function hookChargePrayer(self:Dynamic, prayerId:String):Void onChargePrayer(self, prayerId);
	public static inline function hookSetComboPoint(self:Dynamic, value:Float, result:Float):Float return onSetComboPoint(self, value, result);
	public static inline function hookFinisherStart(self:Dynamic, ctx:Dynamic):Void onFinisherStart(self, ctx);
	public static inline function hookTryGetComboPoint(self:Dynamic, a0:Dynamic, a1:String, a2:Bool):Void onTryGetComboPoint(self, a0, a1, a2);
	public static inline function hookSetHealth(self:Dynamic, value:Float, result:Float):Float return onSetHealth(self, value, result);
	public static inline function hookBeforeHeroDamage(self:Dynamic, dmgObj:Dynamic):hlx.runtime.HlxPrefixControl return beforeHeroReceiveDamage(self, dmgObj);
	public static inline function hookHeroDamage(self:Dynamic, dmgObj:Dynamic):Void onHeroReceiveDamage(self, dmgObj);
	public static inline function hookSetRage(self:Dynamic, value:Float, result:Float):Float return onSetRage(self, value, result);
	public static inline function hookSetSpark(self:Dynamic, value:Float, result:Float):Float return onSetSpark(self, value, result);
	public static inline function hookInflictDamage(self:Dynamic, dmgObj:Dynamic):Void onInflictDamage(self, dmgObj);
	public static inline function hookPropagateChaincast(self:Dynamic, ctx:Dynamic):Void onPropagateChainCast(self, ctx);
	public static inline function hookTalentChaincast(self:Dynamic, ctx:Dynamic):Void onTalentChainCast(self, ctx);
	public static inline function hookTalentChaincastProc(self:Dynamic, ctx:Dynamic):Void onTalentChaincastProc(self, ctx);
	public static inline function hookSetConduits(self:Dynamic, value:Dynamic, result:Dynamic):Dynamic return onSetConduits(self, value, result);
	public static inline function hookSyncConduit(self:Dynamic):Void onSyncConduit(self);
	public static inline function hookPowerConduit(self:Dynamic):Void onPowerConduitStart(self);
	public static inline function hookProjectileConduit(self:Dynamic):Void onProjectileConduitStart(self);
	public static inline function hookSparkConduit(self:Dynamic):Void onSparkConduitStart(self);
	public static inline function hookLifeboltConduit(self:Dynamic):Void onLifeboltConduitStart(self);
	public static inline function hookConduitResidues(self:Dynamic, a0:Dynamic):Void onConduitResidues(self, a0);

	/** Two bound rows per emit site; hp/max previews only rebuild when the value moves. */
	static var hpBinds:Map<String, HpBinds> = new Map();
	static var lastHpMilli:Int = -1;
	static var lastMaxHpMilli:Int = -1;

	static function ledgerHp(method:String, src:String, hp:Float, maxHp:Float, name:String, step:String, hook:String, payloadType:String, role:String):Void {
		if (!solarflare.debug.ResolutionLedger.armed())
			return;
		var L = solarflare.debug.ResolutionLedger;
		var bindKey = method + "|" + src + "|" + name + "|" + step + "|" + hook;
		var b = hpBinds.get(bindKey);
		if (b == null) {
			b = new HpBinds();
			b.maxName = method == "typed" ? "get_maxHealth" : "maxHealth";
			hpBinds.set(bindKey, b);
		}
		if (L.bind(b.cur, "health.current", method, src, name, step, hook)) {
			var milli = Math.round(hp * 1000);
			var prev:String = null;
			if (milli != lastHpMilli) {
				lastHpMilli = milli;
				prev = Std.string(milli / 1000);
			}
			L.bump(b.cur, prev);
		}
		if (L.bind(b.max, "health.max", method, src, b.maxName, step, hook)) {
			var milli = Math.round(maxHp * 1000);
			var prev:String = null;
			if (milli != lastMaxHpMilli) {
				lastMaxHpMilli = milli;
				prev = Std.string(milli / 1000);
			}
			L.bump(b.max, prev);
		}
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
