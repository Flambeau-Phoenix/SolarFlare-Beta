package solarflare.geaux;

import solarflare.HealthCache;
import solarflare.FieldWalk;
import solarflare.combo.Combo;
import hlx.runtime.ResolvedMember;

/**
 * Snapshot of hero skill slots + skill book for ImGui.
 * Slot snaps are primitives only. Live Skill pointers live in `liveById` (identity-only,
 * observe/postfix) — draw must never walk them.
 * Game arrays are hl.types.ArrayObj; never recast them to ArrayBase/ArrayDyn across modules.
 */
class GeauxSlotSnap {
	public var index:Int = 0;
	public var id:String = "";
	/** PNG stem for GameIcons (`{iconId}.png`) — prefer script-style `inf.id` over HASH. */
	public var iconId:String = "";
	public var label:String = "";
	public var group:String = "";
	public var present:Bool = false;
	public var ready:Bool = false;
	public var cooldownValid:Bool = false;
	public var readyFlashUntil:Float = 0;
	/** False when off cooldown but missing cast resources (rage/spark/etc.). */
	public var affordable:Bool = true;
	/** SkillScript.shouldPlayInstantly — frozen observe; draw must not query scripts. */
	public var procReady:Bool = false;
	public var cdLeft:Float = 0;
	public var cdMax:Float = 0;
	public var remaining:Float = 0;
	/** Live remaining charges; 0 when skill has no charge pool. */
	public var charges:Int = 0;
	/** Live max charges; 0 = not a charged skill (draw skips). */
	public var chargesMax:Int = 0;
	/** True while this snap occupies a visible bar cell; replaces an O(count) scan. */
	public var onBar:Bool = false;
	/**
	 * Cooldown duration and charge capacity only move on gear / talent swap, so they are
	 * sampled on the equip cadence and reused until GeauxCache.staticGen advances.
	 * Separate stamps: the two are written by different callers in the same tick.
	 */
	public var cdStaticGen:Int = -1;
	public var cdMaxStatic:Float = 0;
	public var chargeStaticGen:Int = -1;
	public var chargesMaxStatic:Int = 0;
	/** Frozen PNG stems — draw must not call findSkillById. */
	public var iconCandidates:Array<String> = [];

	public function new() {}
}

/** Reused cooldown poll — no per-slot allocation. */
class GeauxCdPoll {
	public var valid:Bool = false;
	public var max:Float = 0;
	public var left:Float = Math.NaN;
	public var prog:Float = Math.NaN;
	public var inCd:Bool = false;

	public function new() {}

	public function reset():Void {
		valid = false;
		max = 0;
		left = Math.NaN;
		prog = Math.NaN;
		inCd = false;
	}
}

/** Latched ledger rows for one GeauxCache cooldown emit site. */
class GeauxCdBinds {
	public var owner:String = "";
	public var cdLeft = new solarflare.debug.LedgerBinding();
	public var cdMax = new solarflare.debug.LedgerBinding();
	public var ready = new solarflare.debug.LedgerBinding();
	public var id = new solarflare.debug.LedgerBinding();
	public var lastId:String = "";

	public function new() {}
}

class GeauxCache {
	static var readyFlashes = new Map<String, ReadyFlashState>();
	static var readySkillRefs = new Map<String, Dynamic>();
	static function clearReadyFlashes():Void { readyFlashes.clear(); readySkillRefs.clear(); }

	public static var slots:Array<GeauxSlotSnap> = [];
	public static var count:Int = 0;
	public static var bookIds:Array<String> = [];
	/** Cached PNG stem parallel to bookIds; resolved during observation, never in a picker draw. */
	public static var bookIconIds:Array<String> = [];
	public static var bookLabels:Array<String> = [];
	public static var bookGroups:Array<String> = [];
	/** Skills currently on the vanilla action bar (flat list). */
	public static var weapons:Array<GeauxSlotSnap> = [];
	/** Unused — kept for older settings / API compat. */
	public static var classSkills:Array<GeauxSlotSnap> = [];
	public static var signatures:Array<GeauxSlotSnap> = [];
	public static var lastUseAt:Map<String, Float> = new Map();
	/** Game-time when CD ends, keyed by Solarflare skill id / kind / inf.id. */
	public static var cdUntil:Map<String, Float> = new Map();
	public static var cdMaxById:Map<String, Float> = new Map();

	/** Identity-only Skill instances keyed by script/HASH id. Observe polls getters; draw never reads this. */
	static var liveById:Map<String, Dynamic> = new Map();
	/** Static `inf.props.costs` per layout pass; affordability still evaluates live resource values. */
	static var costsById:Map<String, Dynamic> = new Map();
	static var costsKnown:Map<String, Bool> = new Map();
	static var costSpecsById:Map<String, Array<{atb:String, amount:Float}>> = new Map();
	static inline var LAYOUT_RECOVERY_S:Float = 15.0; // missed-edge recovery only
	static inline var TELEMETRY_IDLE_S:Float = 0.12; // ~8 Hz idle
	static inline var TELEMETRY_HOT_S:Float = 0.05; // ~20 Hz while CD/drag/builder/dirty
	static var layoutAt:Float = 0;
	static var layoutDirty:Bool = true;
	static var layoutHero:Dynamic = null;
	static var layoutCount:Int = -1;
	static var layoutOverrideKey:String = "";
	static inline var EQUIP_S:Float = 0.35;
	static var equipAt:Float = 0;
	static var equipDirty:Bool = true;
	static var telemetryAt:Float = 0;
	static var telemetryDirty:Bool = true;
	/** Advances with the equip cadence; invalidates per-snap static skill metadata. */
	static var staticGen:Int = 0;

	/** Vanilla action-bar Skill / SkillButton pinned by id (layout / equip). Observe polls these pointers only. */
	static var barSkillById:Map<String, Dynamic> = new Map();
	static var barBtnById:Map<String, Dynamic> = new Map();
	/** Cached HUD bar roots after first successful resolve — skip full HUD crawl on later layouts. */
	static var cachedBarRoots:Array<Dynamic> = null;
	static var iconCandidatesCache:Map<String, Array<String>> = new Map();
	static var cdMaxFieldWin:String = "";
	static var cdPoll = new GeauxCdPoll();

	static var availMem:ResolvedMember;
	static var detailsMem:ResolvedMember;
	static var overrideMem:ResolvedMember;
	static var cdLeftMem:ResolvedMember;
	static var cdEffMem:ResolvedMember;
	static var cdMem:ResolvedMember;
	static var cdProgMem:ResolvedMember;
	static var levelMem:ResolvedMember;
	static var activeWepMem:ResolvedMember;
	static var wep1Mem:ResolvedMember;
	static var wep2Mem:ResolvedMember;
	static var offWepMem:ResolvedMember;
	static var secondaryWepMem:ResolvedMember;
	static var offSkillMem:ResolvedMember;
	static var arsSkillsMem:ResolvedMember;
	static var arsSlotsMem:ResolvedMember;
	static var byInputMem:ResolvedMember;
	static var passiveMem:ResolvedMember;
	static var isPassiveMem:ResolvedMember;
	static var isActiveMem:ResolvedMember;
	static var fromArsMem:ResolvedMember;
	static var isClassSkillMem:ResolvedMember;
	static var wepSkillMem:ResolvedMember;
	static var fromWepMem:ResolvedMember;
	static var isSignatureMem:ResolvedMember;
	static var isDashMem:ResolvedMember;
	static var skillMainWepMem:ResolvedMember;
	/** One getSkillByInput pass per observe — matching snaps does not re-hit Hero. */
	static var barInputSkills:Array<Dynamic> = [];
	static var hudWalkNodes:Int = 0;
	static var hudHero:Dynamic = null;
	/** When true, pushSkillSnap trusts the vanilla action bar (skip isActiveSkill gate). */
	static var trustHudSkills:Bool = false;

	/** Class signature script ids (Warrior/Mage do not use `_Sig_` naming). */
	public static inline var WARRIOR_SIG_SCRIPT:String = "Warrior_Rage_Strike";
	public static inline var MAGE_SIG_SCRIPT:String = "Mage_RayOfSpark";
	public static inline var PRIEST_SIG_SCRIPT:String = "Priest_Sig_DivineIntervention";
	public static inline var ROGUE_SIG_SCRIPT:String = "Rogue_Sig_Finisher";

	public static var CLASS_SIGNATURE_SCRIPTS:Array<String> = [
		WARRIOR_SIG_SCRIPT,
		MAGE_SIG_SCRIPT,
		PRIEST_SIG_SCRIPT,
		ROGUE_SIG_SCRIPT
	];

	/** True while Judgment / Divine Intervention still has remaining CD. Vitals prayers ignore this. */
	public static function judgmentOnCooldown():Bool {
		if (!solarflare.PrayerCache.active)
			return false;
		var snap = findSnap(PRIEST_SIG_SCRIPT);
		if (snap == null)
			snap = findSnap(solarflare.PrayerCache.judgmentId());
		if (snap == null || !snap.present)
			return false;
		return !snap.ready || snap.cdLeft > 0.05 || snap.remaining > 0.02;
	}

	static var signatureHashesReady:Bool = false;
	static var warriorSigHash:String = "";
	static var mageSigHash:String = "";
	static var priestSigHash:String = "";
	static var rogueSigHash:String = "";

	/**
	 * Frozen slot lookup for observe/draw. Never walks live Skill pointers.
	 * Matches script id, HASH, icon stem, and iconCandidates.
	 */
	public static function findSnap(id:String):GeauxSlotSnap {
		if (id == null || id.length == 0)
			return null;
		var found = matchSnapList(slots, id);
		if (found != null)
			return found;
		found = matchSnapList(weapons, id);
		if (found != null)
			return found;
		return matchSnapList(signatures, id);
	}

	static function matchSnapList(list:Array<GeauxSlotSnap>, id:String):GeauxSlotSnap {
		if (list == null)
			return null;
		var want = id.toLowerCase();
		var shown = solarflare.EngineSkillId.display(id);
		var shownLow = shown.toLowerCase();
		var labelHit:GeauxSlotSnap = null;
		for (s in list) {
			if (s == null)
				continue;
			if (!s.present && (s.id == null || s.id.length == 0))
				continue;
			if (snapTokenEq(s.id, want, shownLow) || snapTokenEq(s.iconId, want, shownLow))
				return s;
			if (s.iconCandidates != null) {
				for (c in s.iconCandidates) {
					if (snapTokenEq(c, want, shownLow))
						return s;
				}
			}
			if (labelHit == null && s.label != null && s.label.toLowerCase() == want)
				labelHit = s;
		}
		return labelHit;
	}

	static function snapTokenEq(have:String, wantLow:String, shownLow:String):Bool {
		if (have == null || have.length == 0)
			return false;
		var h = have.toLowerCase();
		if (h == wantLow)
			return true;
		if (shownLow.length > 0 && h == shownLow)
			return true;
		var hs = solarflare.EngineSkillId.display(have).toLowerCase();
		if (hs.length == 0)
			return false;
		return hs == wantLow || (shownLow.length > 0 && hs == shownLow);
	}

	public static function markLayoutDirty():Void {
		layoutDirty = true;
		equipDirty = true;
		telemetryDirty = true;
		solarflare.ObserveDemand.markGeauxDirty();
	}

	/** Drop cached HUD roots (zone unload / hero change). Next layout rediscovers. */
	public static function invalidateBarRoots():Void {
		clearReadyFlashes();
		cachedBarRoots = null;
	}

	public static function sample(heroDyn:Dynamic, visibleCount:Int, overrides:Array<String> = null):Void {
		if (visibleCount < 0)
			visibleCount = 0;
		ensureSlots(visibleCount);
		count = visibleCount;
		markOnBar();
		if (heroDyn == null) {
			clearReadyFlashes();
			weapons = [];
			classSkills = [];
			signatures = [];
			bookIds = [];
			bookIconIds = [];
			bookLabels = [];
			bookGroups = [];
			liveById = new Map();
			barSkillById = new Map();
			barBtnById = new Map();
			costsById = new Map();
			costsKnown = new Map();
			costSpecsById = new Map();
			cachedBarRoots = null;
			layoutDirty = true;
			layoutHero = null;
			layoutCount = -1;
			layoutOverrideKey = "";
			telemetryAt = 0;
			telemetryDirty = true;
			for (i in 0...visibleCount)
				clearSlot(slots[i], i);
			return;
		}
		var okey = overrideKey(overrides, visibleCount);
		var heroChanged = false;
		try
			heroChanged = (cast heroDyn : Dynamic) != (cast layoutHero : Dynamic)
		catch (_:Dynamic)
			heroChanged = true;
		if (heroChanged) {
			cachedBarRoots = null;
			clearReadyFlashes();
		}
		var now = nowStamp();
		// Layout only on dirty / identity / slot-count change; rare time fallback for missed dirty edges.
		var recovery = layoutAt > 0 && now >= layoutAt + LAYOUT_RECOVERY_S;
		if (layoutDirty || heroChanged || layoutCount != visibleCount || okey != layoutOverrideKey
			|| recovery) {
			if (recovery && !layoutDirty && !heroChanged && layoutCount == visibleCount
					&& okey == layoutOverrideKey)
				solarflare.runtime.RuntimeMetrics.layoutRecoveryPolls++;
			layoutHero = heroDyn;
			layoutCount = visibleCount;
			layoutOverrideKey = okey;
			layoutAt = now;
			layoutDirty = false;
			refreshLayout(heroDyn, visibleCount, overrides);
			equipDirty = true;
			telemetryDirty = true;
		}
		var telemInterval = telemetryInterval();
		if (telemetryDirty || now >= telemetryAt) {
			telemetryDirty = false;
			solarflare.ObserveDemand.geauxDirty = false;
			telemetryAt = now + telemInterval;
			tickTelemetry(heroDyn);
		}
	}

	static function telemetryInterval():Float {
		if (solarflare.ObserveDemand.geauxBuilder || solarflare.ObserveDemand.geauxDirty || telemetryDirty)
			return TELEMETRY_HOT_S;
		// Hot while any visible slot has a live cooldown.
		var n = count < slots.length ? count : slots.length;
		for (i in 0...n) {
			var s = slots[i];
			if (s != null && (s.cdLeft > 0.05 || s.remaining > 0.02))
				return TELEMETRY_HOT_S;
		}
		return TELEMETRY_IDLE_S;
	}

	static function overrideKey(overrides:Array<String>, n:Int):String {
		if (overrides == null || n <= 0)
			return "";
		var b = new StringBuf();
		for (i in 0...n) {
			if (i > 0)
				b.add("|");
			if (i < overrides.length && overrides[i] != null)
				b.add(overrides[i]);
		}
		return b.toString();
	}

	/** HUD walk + slot identity. Throttled. Not for draw(). */
	static function refreshLayout(heroDyn:Dynamic, visibleCount:Int, overrides:Array<String>):Void {
		liveById = new Map();
		barSkillById = new Map();
		barBtnById = new Map();
		costsById = new Map();
		costsKnown = new Map();
		costSpecsById = new Map();
		sampleActionBar(heroDyn);
		sampleClassSkills(heroDyn);
		sampleSignatures(heroDyn);
		refreshBook(heroDyn);
		refreshBookFromBar();
		refreshBookFromSignatures();
		var runtimeSlots = field(heroDyn, "skillSlots");
		var specSlots = null;
		try {
			var spec = field(heroDyn, "specialization");
			specSlots = field(spec, "skillSlots");
		} catch (_:Dynamic) {}
		for (i in 0...visibleCount) {
			var overrideId = "";
			if (overrides != null && i < overrides.length && overrides[i] != null)
				overrideId = overrides[i];
			fillSlot(heroDyn, runtimeSlots, specSlots, slots[i], i, overrideId);
		}
		refreshPrayerReady();
		freezeSlotIcons(visibleCount);
	}

	/** Per-observe: one slot loop binds Skill, cooldown, and afford. HUD / cdUntil never write snaps. */
	static function tickTelemetry(heroDyn:Dynamic):Void {
		var now = nowStamp();
		if (equipDirty || now >= equipAt) {
			rememberEquipped(heroDyn);
			equipDirty = false;
			equipAt = now + EQUIP_S;
			// Gear / talents may have changed, so re-read static skill metadata once.
			staticGen++;
		}
		tickSlots(heroDyn);
		var active = new Map<String, Bool>();
		for (s in slots) if (s.present) active.set(s.id, true);
		for (key in readyFlashes.keys()) if (!active.exists(key)) { readyFlashes.remove(key); readySkillRefs.remove(key); }
	}

	/** Keep liveById pointed at whatever is currently equipped so CD polls hit the real Skill. */
	static function rememberEquipped(heroDyn:Dynamic):Void {
		if (heroDyn == null)
			return;
		var lists = [
			field(heroDyn, "skillSlots"),
			field(heroDyn, "weaponSkills"),
			field(heroDyn, "attackSkills")
		];
		try {
			var spec = field(heroDyn, "specialization");
			lists.push(field(spec, "skillSlots"));
		} catch (_:Dynamic) {}
		for (arr in lists) {
			var n = arrayLen(arr);
			if (n <= 0 || n > 64)
				continue;
			for (i in 0...n) {
				var item = arrayAt(arr, i);
				if (item == null)
					continue;
				var parsed = parseSkillish(item);
				var skill = parsed.skill != null ? parsed.skill : item;
				rememberSkill(skill, parsed.id);
				pinBarEntry([parsed.id], skill, null);
			}
		}
		if (byInputMem == null)
			byInputMem = resolveMem("ent.Hero", "getSkillByInput");
		barInputSkills = [];
		for (inp in classBarInputNames())
			stashEquippedInput(callResolved(byInputMem, [heroDyn, inp]));
		var extra = [
			"ArsenalSkill1", "ArsenalSkill2", "ArsenalSkill3", "ArsenalSkill4",
			"WeaponSkill1", "WeaponSkill2", "OffhandSkill", "OffhandSkill1",
			"SignatureSkill", "Signature"
		];
		for (inp in extra)
			stashEquippedInput(callResolved(byInputMem, [heroDyn, inp]));
		stashEquippedInput(field(heroDyn, "dashSkill"));
		stashEquippedInput(field(heroDyn, "secondarySkill"));
		stashEquippedInput(field(heroDyn, "attackComboSkill"));
	}

	static function pinBarEntry(ids:Array<String>, skill:Dynamic, btn:Dynamic):Void {
		if ((ids == null || ids.length == 0) && skill == null)
			return;
		var prayer = skillIsPrayer(skill);
		if (ids != null) {
			for (id in ids)
				pinOneBarId(id, skill, btn, prayer);
		}
		if (skill != null) {
			try {
				for (a in skillIdAliases(skill))
					pinOneBarId(a, skill, btn, prayer);
			} catch (_:Dynamic) {}
		}
	}

	static function pinOneBarId(id:String, skill:Dynamic, btn:Dynamic, prayer:Bool):Void {
		var k = sanitizeSkillId(id);
		if (k.length == 0)
			return;
		if (solarflare.PrayerCache.isPrayerId(k) != prayer)
			return;
		var sig = isKnownClassSignature(k) || classSignatureScriptId(k).length > 0;
		if (prayer && sig)
			return;
		if (skill != null)
			barSkillById.set(k, skill);
		if (btn != null && buttonShowsId(btn, k))
			barBtnById.set(k, btn);
		var script = classSignatureScriptId(k);
		if (script.length > 0 && !prayer) {
			if (skill != null)
				barSkillById.set(script, skill);
			if (btn != null && buttonShowsId(btn, script))
				barBtnById.set(script, btn);
		}
	}

	static function stashEquippedInput(skill:Dynamic):Void {
		if (skill == null)
			return;
		rememberSkill(skill);
		try {
			for (have in barInputSkills) {
				if ((cast have : Dynamic) == (cast skill : Dynamic))
					return;
			}
		} catch (_:Dynamic) {}
		barInputSkills.push(skill);
	}

	static function rememberSkill(skill:Dynamic, ?id:String):Void {
		if (skill == null)
			return;
		if (id != null && id.length > 0) {
			try {
				var typed:st.skill.Skill = skill;
				if (typed != null && !skillMatches(typed, id))
					return;
			} catch (_:Dynamic) {}
			bindLiveId(id, skill);
		}
		try {
			for (a in skillIdAliases(skill))
				bindLiveId(a, skill);
		} catch (_:Dynamic) {}
	}

	static function bindLiveId(id:String, skill:Dynamic):Void {
		var k = sanitizeSkillId(id);
		if (k.length == 0 || skill == null)
			return;
		if (skillIsPrayer(skill) || solarflare.PrayerCache.isPrayerId(k)) {
			if (isKnownClassSignature(k) || classSignatureScriptId(k).length > 0)
				return;
			putLiveId(k, skill);
			return;
		}
		putLiveId(k, skill);
		var script = classSignatureScriptId(k);
		if (script.length > 0)
			putLiveId(script, skill);
	}

	static function skillIsPrayer(skill:Dynamic):Bool {
		if (skill == null)
			return false;
		try {
			if (solarflare.PrayerCache.isPrayerId(getSkillId(skill)))
				return true;
		} catch (_:Dynamic) {}
		try {
			for (a in skillIdAliases(skill)) {
				if (solarflare.PrayerCache.isPrayerId(a))
					return true;
			}
		} catch (_:Dynamic) {}
		return false;
	}

	/** Keep an in-CD equipped Skill; never replace it with a ready book stub. */
	static function putLiveId(k:String, skill:Dynamic):Void {
		if (liveById.exists(k)) {
			var have = liveById.get(k);
			if (skillCdActive(have) && !skillCdActive(skill))
				return;
		}
		liveById.set(k, skill);
	}

	static function skillCdActive(skill:Dynamic):Bool {
		if (skill == null)
			return false;
		try {
			var typed:st.skill.Skill = skill;
			if (typed == null)
				return false;
			if (typed.isInCooldown())
				return true;
			return typed.getCooldownLeft() > 0.05;
		} catch (_:Dynamic) {}
		return false;
	}

	static function cachedSkill(id:String):Dynamic {
		if (id == null || id.length == 0)
			return null;
		if (liveById.exists(id))
			return liveById.get(id);
		var script = classSignatureScriptId(id);
		if (script.length > 0 && liveById.exists(script))
			return liveById.get(script);
		return null;
	}

	/** Live Skill pointer from identity map (Geaux sample / noteUse). Null if never remembered. */
	public static function liveSkill(id:String):Dynamic {
		if (id == null || id.length == 0)
			return null;
		var k = sanitizeSkillId(id);
		if (k.length == 0)
			return null;
		return cachedSkill(k);
	}

	public static function weaponSnaps():Array<GeauxSlotSnap> {
		return weapons;
	}

	/** Skills currently on the vanilla action bar (class + weapon + signature strips). */
	public static function barSnaps():Array<GeauxSlotSnap> {
		return weapons;
	}

	/**
	 * Resolve every skill live on the vanilla action bar (3 strips):
	 *   left  = main-hand + off-hand + arsenal weapon skills
	 *   mid   = signature
	 *   right = class skills
	 * HUD widgets first (WeaponSkillSlotButton / SkillSlotButton), then inputs / live arrays.
	 */
	public static function sampleActionBar(hero:Dynamic):Void {
		weapons = [];
		if (hero == null)
			return;
		if (byInputMem == null)
			byInputMem = resolveMem("ent.Hero", "getSkillByInput");
		if (passiveMem == null)
			passiveMem = resolveMem("st.skill.BaseSkill", "isWeaponPassive");
		if (isPassiveMem == null)
			isPassiveMem = resolveMem("st.skill.BaseSkill", "isPassive");
		if (isActiveMem == null)
			isActiveMem = resolveMem("st.skill.BaseSkill", "isActiveSkill");
		if (wepSkillMem == null)
			wepSkillMem = resolveMem("st.skill.BaseSkill", "isWeaponSkill");
		if (fromArsMem == null)
			fromArsMem = resolveMem("st.skill.BaseSkill", "isFromArsenal");
		if (fromWepMem == null)
			fromWepMem = resolveMem("st.skill.BaseSkill", "isFromWeapon");
		if (isClassSkillMem == null)
			isClassSkillMem = resolveMem("st.skill.BaseSkill", "isClassSkill");
		if (isSignatureMem == null)
			isSignatureMem = resolveMem("st.skill.BaseSkill", "isSignature");
		if (arsSkillsMem == null)
			arsSkillsMem = resolveMem("st.player.HeroSpecialization", "getArsenalSkills");
		if (wep1Mem == null)
			wep1Mem = resolveMem("ent.Hero", "get_weapon1");
		if (wep2Mem == null)
			wep2Mem = resolveMem("ent.Hero", "get_weapon2");
		if (activeWepMem == null)
			activeWepMem = resolveMem("ent.Hero", "get_activeWeapon");
		if (offWepMem == null)
			offWepMem = resolveMem("ent.Hero", "get_activeOffhand");
		if (secondaryWepMem == null)
			secondaryWepMem = resolveMem("ent.Hero", "get_secondaryWeapon");
		if (offSkillMem == null)
			offSkillMem = resolveMem("ent.Hero", "getOffhandWeaponSkill");
		if (skillMainWepMem == null)
			skillMainWepMem = resolveMem("ent.Hero", "getSkillMainWeapon");
		if (arsSlotsMem == null)
			arsSlotsMem = resolveMem("ent.Hero", "getNbArsenalSkillSlots");

		trustHudSkills = true;
		hudWalkNodes = 0;
		hudHero = hero;
		try {
			ensureBarRoots();
			if (cachedBarRoots != null) {
				for (root in cachedBarRoots)
					walkActionBarAll(root, 0);
			}
			// Dead HUD after zone reload — one full rediscover.
			if (hudWalkNodes == 0) {
				cachedBarRoots = null;
				ensureBarRoots();
				if (cachedBarRoots != null) {
					for (root in cachedBarRoots)
						walkActionBarAll(root, 0);
				}
			}
		} catch (_:Dynamic) {}
		hudHero = null;

		var inputs = [
			"Skill1", "Skill2", "Skill3", "Skill4", "Skill5", "Skill6", "Skill7", "Skill8",
			"ClassSkill1", "ClassSkill2", "ClassSkill3", "ClassSkill4",
			"ClassSkill5", "ClassSkill6", "ClassSkill7", "ClassSkill8",
			"WeaponSkill1", "WeaponSkill2", "WeaponSkill3", "WeaponSkill4",
			"MainHandSkill1", "MainHandSkill2", "MainHandSkill3", "MainHandSkill4",
			"OffhandSkill", "OffhandSkill1", "OffhandSkill2", "OffHandSkill",
			"ArsenalSkill1", "ArsenalSkill2", "ArsenalSkill3", "ArsenalSkill4",
			"ArsenalSkill5", "ArsenalSkill6",
			"SecondaryWeaponSkill1", "SecondaryWeaponSkill2", "SecondaryWeaponSkill3", "SecondaryWeaponSkill4",
			"SecondarySkill1", "SecondarySkill2", "SecondarySkill3", "SecondarySkill4",
			"SignatureSkill", "Signature", "SigSkill", "ClassSignature",
			"Ultimate", "UltimateSkill"
		];
		var typedInputsOk = false;
		try {
			var h:ent.Hero = cast hero;
			for (inp in inputs) {
				var sk = h.getSkillByInput(inp);
				if (sk != null)
					pushBarSkill(hero, sk, getSkillId(sk));
			}
			typedInputsOk = true;
		} catch (_:Dynamic) {}
		if (!typedInputsOk) {
			for (inp in inputs) {
				var sk2 = callResolved(byInputMem, [hero, inp]);
				if (sk2 != null)
					pushBarSkill(hero, sk2, getSkillId(sk2));
			}
		}

		// Fallbacks when HUD / input names miss sheathed arsenal or class slots.
		fillBarFromWeaponSkills(hero);
		fillBarFromSkillSlots(hero);
		fillBarFromEquipment(hero);
		fillBarFromArsenalApi(hero);
		pushBarSkill(hero, field(hero, "secondarySkill"), getSkillId(field(hero, "secondarySkill")));
		pushBarSkill(hero, callResolved(offSkillMem, [hero]), "");

		trustHudSkills = false;
	}

	static function sampleClassSkills(hero:Dynamic):Void {
		classSkills = [];
		if (hero == null)
			return;
		if (isClassSkillMem == null)
			isClassSkillMem = resolveMem("st.skill.BaseSkill", "isClassSkill");
		if (isSignatureMem == null)
			isSignatureMem = resolveMem("st.skill.BaseSkill", "isSignature");
		if (wepSkillMem == null)
			wepSkillMem = resolveMem("st.skill.BaseSkill", "isWeaponSkill");
		if (byInputMem == null)
			byInputMem = resolveMem("ent.Hero", "getSkillByInput");
		var prevTrust = trustHudSkills;
		trustHudSkills = true;
		var inputs = classBarInputNames();
		var typedInputsOk = false;
		try {
			var h:ent.Hero = cast hero;
			for (inp in inputs) {
				var sk = h.getSkillByInput(inp);
				if (sk != null && looksLikeClass(sk, getSkillId(sk)))
					pushSkillSnap(hero, classSkills, sk, getSkillId(sk), "CLS");
			}
			typedInputsOk = true;
		} catch (_:Dynamic) {}
		if (!typedInputsOk) {
			for (inp in inputs) {
				var sk2 = callResolved(byInputMem, [hero, inp]);
				if (sk2 != null && looksLikeClass(sk2, getSkillId(sk2)))
					pushSkillSnap(hero, classSkills, sk2, getSkillId(sk2), "CLS");
			}
		}
		if (weapons != null) {
			for (s in weapons) {
				if (s == null || !s.present || s.id.length == 0)
					continue;
				var sk = cachedSkill(s.id);
				if (looksLikeClass(sk, s.id))
					pushSkillSnap(hero, classSkills, sk, s.id, "CLS");
			}
		}
		var lists = [field(hero, "skillSlots"), field(hero, "attackSkills")];
		try {
			var spec = field(hero, "specialization");
			lists.push(field(spec, "skillSlots"));
		} catch (_:Dynamic) {}
		for (arr in lists) {
			var n = arrayLen(arr);
			for (i in 0...n) {
				var parsed = parseSkillish(arrayAt(arr, i));
				if (parsed.id.length == 0)
					continue;
				if (callSkillBoolOpt(isClassSkillMem, parsed.skill) != true)
					continue;
				pushSkillSnap(hero, classSkills, parsed.skill, parsed.id, "CLS");
			}
		}
		trustHudSkills = prevTrust;
	}

	static function classBarInputNames():Array<String> {
		return [
			"Skill1", "Skill2", "Skill3", "Skill4", "Skill5", "Skill6", "Skill7", "Skill8",
			"ClassSkill1", "ClassSkill2", "ClassSkill3", "ClassSkill4",
			"ClassSkill5", "ClassSkill6", "ClassSkill7", "ClassSkill8"
		];
	}

	static function looksLikeClass(skill:Dynamic, id:String):Bool {
		if (isSignatureId(id, skill) || solarflare.PrayerCache.isPrayerId(id))
			return false;
		if (skillFromArsenal(skill))
			return false;
		if (isDashSkill(skill, id))
			return true;
		if (wepSkillMem == null)
			wepSkillMem = resolveMem("st.skill.BaseSkill", "isWeaponSkill");
		if (callSkillBoolOpt(wepSkillMem, skill) == true)
			return false;
		if (isClassSkillMem == null)
			isClassSkillMem = resolveMem("st.skill.BaseSkill", "isClassSkill");
		if (callSkillBoolOpt(isClassSkillMem, skill) == true)
			return true;
		try {
			var s:st.skill.BaseSkill = skill;
			if (s != null && s.isClassSkill())
				return true;
		} catch (_:Dynamic) {}
		return skill != null && callSkillBoolOpt(wepSkillMem, skill) != true;
	}

	/** Live weaponSkills array — includes sheathed arsenal entries marked isFromArsenal. */
	static function fillBarFromWeaponSkills(hero:Dynamic):Void {
		if (hero == null)
			return;
		var arr = field(hero, "weaponSkills");
		var n = arrayLen(arr);
		for (i in 0...n) {
			var skill = arrayAt(arr, i);
			if (skill == null)
				continue;
			var id = preferScriptId("", skill);
			if (id.length == 0)
				continue;
			if (callSkillBoolOpt(wepSkillMem, skill) == true
				|| skillFromArsenal(skill)
				|| field(skill, "originItem") != null
				|| callSkillBoolOpt(fromWepMem, skill) == true)
				pushBarSkill(hero, skill, id);
		}
	}

	/** Class / signature strip often mirrors hero.skillSlots (+ spec.skillSlots). */
	static function fillBarFromSkillSlots(hero:Dynamic):Void {
		if (hero == null)
			return;
		var lists = [field(hero, "skillSlots"), field(hero, "attackSkills"), field(hero, "skills")];
		try {
			var spec = field(hero, "specialization");
			lists.push(field(spec, "skillSlots"));
			lists.push(field(spec, "skills"));
		} catch (_:Dynamic) {}
		for (arr in lists) {
			var n = arrayLen(arr);
			for (i in 0...n) {
				var parsed = parseSkillish(arrayAt(arr, i));
				if (parsed.id.length == 0)
					continue;
				pushBarSkill(hero, parsed.skill, parsed.id);
			}
		}
	}

	/** MH / OH / active weapon skill lists from equipped items (not arsenal — that uses getArsenalSkills). */
	static function fillBarFromEquipment(hero:Dynamic):Void {
		if (hero == null)
			return;
		var weps = [
			resolveHeroWeapon(hero, wep1Mem, "get_weapon1", "weapon1"),
			resolveHeroWeapon(hero, wep2Mem, "get_weapon2", "weapon2"),
			resolveHeroWeapon(hero, activeWepMem, "get_activeWeapon", "activeWeapon"),
			resolveHeroWeapon(hero, offWepMem, "get_activeOffhand", "activeOffhand")
		];
		for (wep in weps)
			fillFromWeaponInf(hero, wep);
	}

	static function fillFromWeaponInf(hero:Dynamic, wep:Dynamic):Void {
		if (wep == null)
			return;
		var skills = field(field(wep, "inf"), "skills");
		var n = arrayLen(skills);
		for (i in 0...n) {
			var parsed = parseSkillish(arrayAt(skills, i));
			var id = sanitizeSkillId(parsed.id);
			if (id.length == 0)
				id = sanitizeSkillId(dynString(field(arrayAt(skills, i), "id")));
			if (id.length == 0)
				continue;
			// Weapon inf lists passives + unused arsenal options — keep actives / arsenal only.
			if (skipWeaponId(id))
				continue;
			if (parsed.skill != null) {
				if (callSkillBoolOpt(isPassiveMem, parsed.skill) == true)
					continue;
				if (callSkillBoolOpt(passiveMem, parsed.skill) == true)
					continue;
			}
			pushBarSkill(hero, parsed.skill, id);
		}
	}

	/**
	 * Selected arsenal skills for the secondary (arsenal) weapon via HeroSpecialization.getArsenalSkills.
	 * Tries multiple type keys — inventory ids vs weapon-family types differ.
	 */
	static function fillBarFromArsenalApi(hero:Dynamic):Void {
		if (hero == null)
			return;
		var secondary = resolveHeroWeapon(hero, secondaryWepMem, "get_secondaryWeapon", "secondaryWeapon");
		var weps = [
			secondary,
			resolveHeroWeapon(hero, wep1Mem, "get_weapon1", "weapon1"),
			resolveHeroWeapon(hero, wep2Mem, "get_weapon2", "weapon2"),
			resolveHeroWeapon(hero, activeWepMem, "get_activeWeapon", "activeWeapon")
		];
		for (wep in weps)
			fillSpecArsenalForWeapon(hero, wep);

		// Skills whose main weapon is the arsenal weapon (covers live instances not in getArsenalSkills).
		if (secondary != null) {
			var arr = field(hero, "weaponSkills");
			var n = arrayLen(arr);
			for (i in 0...n) {
				var skill = arrayAt(arr, i);
				if (skill == null)
					continue;
				if (skillFromArsenal(skill) || skillBelongsToWeapon(hero, skill, secondary))
					pushBarSkill(hero, skill, getSkillId(skill));
			}
		}
	}

	static function fillSpecArsenalForWeapon(hero:Dynamic, wep:Dynamic):Void {
		if (wep == null || hero == null)
			return;
		var spec = field(hero, "specialization");
		if (spec == null)
			return;
		for (tid in weaponTypeKeys(wep)) {
			var arsArr = callResolved(arsSkillsMem, [spec, tid]);
			var arsN = arrayLen(arsArr);
			for (i in 0...arsN) {
				var parsed = parseSkillish(arrayAt(arsArr, i));
				if (parsed.id.length == 0)
					continue;
				pushBarSkill(hero, parsed.skill, parsed.id);
			}
		}
		try {
			var h:ent.Hero = cast hero;
			var sp = h.specialization;
			if (sp != null) {
				for (tid in weaponTypeKeys(wep)) {
					var arr2 = sp.getArsenalSkills(tid);
					var n2 = arrayLen(arr2);
					for (i in 0...n2) {
						var parsed2 = parseSkillish(arrayAt(arr2, i));
						if (parsed2.id.length == 0)
							continue;
						pushBarSkill(hero, parsed2.skill, parsed2.id);
					}
				}
			}
		} catch (_:Dynamic) {}
	}

	static function skillBelongsToWeapon(hero:Dynamic, skill:Dynamic, wep:Dynamic):Bool {
		if (skill == null || wep == null)
			return false;
		try {
			var origin = field(skill, "originItem");
			if (origin != null && sameWeapon(origin, wep))
				return true;
		} catch (_:Dynamic) {}
		var main = callResolved(skillMainWepMem, [hero, skill]);
		if (main == null) {
			try {
				var h:ent.Hero = cast hero;
				main = h.getSkillMainWeapon(skill);
			} catch (_:Dynamic) {}
		}
		return sameWeapon(main, wep);
	}

	static function resolveHeroWeapon(hero:Dynamic, mem:ResolvedMember, typedName:String, fieldName:String):Dynamic {
		try {
			var h:ent.Hero = cast hero;
			if (typedName == "get_weapon1")
				return h.get_weapon1();
			if (typedName == "get_weapon2")
				return h.get_weapon2();
			if (typedName == "get_activeWeapon")
				return h.get_activeWeapon();
			if (typedName == "get_secondaryWeapon")
				return h.get_secondaryWeapon();
			if (typedName == "get_activeOffhand")
				return h.get_activeOffhand();
		} catch (_:Dynamic) {}
		var w = callResolved(mem, [hero]);
		if (w != null)
			return w;
		return field(hero, fieldName);
	}

	static function sameWeapon(a:Dynamic, b:Dynamic):Bool {
		if (a == null || b == null)
			return false;
		try
			return (cast a : Dynamic) == (cast b : Dynamic)
		catch (_:Dynamic) {}
		return false;
	}

	static function weaponTypeKeys(wep:Dynamic):Array<String> {
		var out:Array<String> = [];
		addTypeKey(out, dynString(field(field(wep, "inf"), "type")));
		addTypeKey(out, dynString(field(wep, "kind")));
		addTypeKey(out, dynString(field(wep, "baseId")));
		var inf = field(wep, "inf");
		addTypeKey(out, dynString(field(inf, "type")));
		addTypeKey(out, dynString(field(inf, "baseId")));
		var id = dynString(field(inf, "id"));
		addTypeKey(out, id);
		if (id.length > 0) {
			var us = id.indexOf("_");
			if (us > 0)
				addTypeKey(out, id.substr(0, us));
		}
		return out;
	}

	static function addTypeKey(out:Array<String>, key:String):Void {
		if (key == null || key.length == 0)
			return;
		for (e in out) {
			if (e == key)
				return;
		}
		out.push(key);
	}

	static function pushBarSkill(hero:Dynamic, skill:Dynamic, id:String):Void {
		var iconHint = preferScriptId(id, skill);
		id = sanitizeSkillId(iconHint.length > 0 ? iconHint : (id.length > 0 ? id : getSkillId(skill)));
		if (id.length == 0)
			return;
		if (skipWeaponId(id))
			return;
		if (skill != null) {
			if (callSkillBoolOpt(isPassiveMem, skill) == true)
				return;
			if (callSkillBoolOpt(passiveMem, skill) == true)
				return;
		}
		pushSkillSnap(hero, weapons, skill, id, "BAR");
	}

	static function resolveHud():Dynamic {
		var hud:Dynamic = null;
		try
			hud = ui.GameUI.getHud()
		catch (_:Dynamic) {}
		if (hud == null) {
			try {
				var gui = ui.GameUI.get();
				if (gui != null)
					hud = gui.get_hud();
			} catch (_:Dynamic) {}
		}
		if (hud == null) {
			try {
				var app = GameApp.get();
				if (app != null && app.gui != null)
					hud = app.gui.get_hud();
			} catch (_:Dynamic) {}
		}
		return hud;
	}

	/** Resolve bottomBar / skillBar roots once; HUD tree is static after boot. */
	static function ensureBarRoots():Void {
		if (cachedBarRoots != null)
			return;
		var roots:Array<Dynamic> = [];
		try {
			var hud = resolveHud();
			if (hud == null)
				return;
			var bottom = plainField(hud, "bottomBar");
			pushBarRoot(roots, plainField(bottom, "skillBar"));
			pushBarRoot(roots, plainField(bottom, "heroBar"));
			pushBarRoot(roots, plainField(bottom, "heroBarPad"));
			pushBarRoot(roots, bottom);
			pushBarRoot(roots, plainField(hud, "widgets"));
			pushBarRoot(roots, plainField(hud, "skillBar"));
		} catch (_:Dynamic) {}
		if (roots.length > 0)
			cachedBarRoots = roots;
	}

	static function pushBarRoot(roots:Array<Dynamic>, node:Dynamic):Void {
		if (node == null)
			return;
		for (have in roots) {
			if (have == node)
				return;
		}
		roots.push(node);
	}

	static function walkActionBarAll(node:Dynamic, depth:Int):Void {
		if (node == null || depth > 18 || hudWalkNodes > 1800)
			return;
		hudWalkNodes++;
		ingestAnyBarSlot(node);
		var follow = [
			"button", "skillBar", "skillBarPad", "primaryWeaponBar", "weapons",
			"secondaryWeaponBar", "offhandWeaponBar", "arsenalWeaponBar", "extraWeaponBar",
			"weaponBar", "classSkills", "skills"
		];
		for (name in follow)
			walkActionBarAll(plainField(node, name), depth + 1);
		for (name in ["skillSlots", "slots", "buttons", "skillButtons", "weaponBars", "children"]) {
			var arr = plainField(node, name);
			var n = arrayLen(arr);
			if (n <= 0 || n > 64)
				continue;
			for (i in 0...n)
				walkActionBarAll(arrayAt(arr, i), depth + 1);
		}
		var kids = objectChildren(node);
		var kn = arrayLen(kids);
		for (i in 0...kn)
			walkActionBarAll(arrayAt(kids, i), depth + 1);
	}

	static function ingestAnyBarSlot(node:Dynamic):Void {
		if (node == null || hudHero == null)
			return;

		// Typed wrappers first — arsenal / weapon strip skills live on WeaponSkillSlotButton,
		// class strip on SkillSlotButton; the live Skill is often only on getOverrideSkill().
			try {
			var wslot:ui.hud.WeaponSkillSlotButton = node;
			if (wslot != null) {
				var wSkill:Dynamic = callOverrideSkill(node);
				if (wSkill == null && wslot.button != null) {
					try
						wSkill = wslot.button.skill
					catch (_:Dynamic) {}
					if (wSkill == null)
						wSkill = callOverrideSkill(wslot.button);
				}
				var wId = "";
				if (wslot.button != null)
					wId = skillIdFromButton(wslot.button);
				if (wId.length == 0 || !isScriptStyleId(wId))
					wId = preferScriptId(wId, wSkill);
				var wInput = dynString(plainField(node, "input"));
				if ((wSkill == null || wId.length == 0) && wInput.length > 0)
					wSkill = callResolved(byInputMem, [hudHero, wInput]);
				if (wId.length == 0 || !isScriptStyleId(wId))
					wId = preferScriptId(wId, wSkill);
				if (wId.length > 0 || wSkill != null) {
					pushBarSkill(hudHero, wSkill, wId);
					return;
				}
			}
		} catch (_:Dynamic) {}

		try {
			var slot:ui.hud.SkillSlotButton = node;
			if (slot != null) {
				var sSkill:Dynamic = null;
				try
					sSkill = slot.getOverrideSkill()
				catch (_:Dynamic) {}
				if (sSkill == null)
					sSkill = callOverrideSkill(node);
				if (sSkill == null && slot.button != null) {
					try
						sSkill = slot.button.skill
					catch (_:Dynamic) {}
					if (sSkill == null)
						sSkill = callOverrideSkill(slot.button);
				}
				var sId = "";
				if (slot.button != null)
					sId = skillIdFromButton(slot.button);
				if (sId.length == 0 || !isScriptStyleId(sId))
					sId = preferScriptId(sId, sSkill);
				var sInput = dynString(plainField(node, "input"));
				if ((sSkill == null || sId.length == 0) && sInput.length > 0)
					sSkill = callResolved(byInputMem, [hudHero, sInput]);
				if (sId.length == 0 || !isScriptStyleId(sId))
					sId = preferScriptId(sId, sSkill);
				if (sId.length > 0 || sSkill != null) {
					pushBarSkill(hudHero, sSkill, sId);
					return;
				}
			}
		} catch (_:Dynamic) {}

		var btn = plainField(node, "button");
		var hasSlot = plainField(node, "index") != null || plainField(node, "input") != null
			|| plainField(node, "weapon") != null || btn != null;
		var isSkillBtn = plainField(node, "cdTimer") != null || plainField(node, "skill") != null
			|| plainField(node, "inf") != null;
		if (!hasSlot && !isSkillBtn)
			return;

		var target = btn != null ? btn : node;
		var skill:Dynamic = null;
		var id = "";

		try {
			var typed:ui.hud.SkillButton = target;
			if (typed != null) {
				try {
					if (typed.inf != null) {
						if (typed.inf.id != null)
							id = sanitizeSkillId(typed.inf.id);
						if (!isScriptStyleId(id)) {
							var script = sanitizeSkillId(dynString(field(typed.inf, "script")));
							if (isScriptStyleId(script))
								id = script;
						}
					}
				} catch (_:Dynamic) {}
				try
					skill = typed.skill
				catch (_:Dynamic) {}
				try {
					var over = typed.getOverrideSkill();
					if (over != null)
						skill = over;
				} catch (_:Dynamic) {}
			}
		} catch (_:Dynamic) {}

		if (skill == null)
			skill = plainField(target, "skill");
		if (skill == null)
			skill = callOverrideSkill(target);
		if (skill == null)
			skill = callOverrideSkill(node);

		var input = dynString(plainField(node, "input"));
		if (input.length == 0)
			input = dynString(plainField(target, "input"));
		if ((skill == null || getSkillId(skill).length == 0) && input.length > 0)
			skill = callResolved(byInputMem, [hudHero, input]);

		if (id.length == 0)
			id = sanitizeSkillId(skillIdFromButton(target));
		if (id.length == 0 || !isScriptStyleId(id))
			id = preferScriptId(id, skill);
		if (id.length == 0 && skill == null)
			return;
		pushBarSkill(hudHero, skill, id);
	}

	static function alreadyInGroup(id:String, group:Array<GeauxSlotSnap>):Bool {
		if (id == null || id.length == 0 || group == null)
			return false;
		for (s in group) {
			if (s != null && s.present && s.id == id)
				return true;
		}
		return false;
	}

	public static function skillFromArsenal(skill:Dynamic):Bool {
		if (skill == null)
			return false;
		if (fromArsMem == null)
			fromArsMem = resolveMem("st.skill.BaseSkill", "isFromArsenal");
		if (callSkillBoolOpt(fromArsMem, skill) == true)
			return true;
		try {
			var s:st.skill.BaseSkill = skill;
			return s.isFromArsenal();
		} catch (_:Dynamic) {}
		return false;
	}

	public static function isArsenalSkill(skill:Dynamic, id:String = ""):Bool {
		return skillFromArsenal(skill);
	}

	public static function sampleSignatures(hero:Dynamic):Void {
		signatures = [];
		if (hero == null)
			return;
		if (isSignatureMem == null)
			isSignatureMem = resolveMem("st.skill.BaseSkill", "isSignature");
		if (byInputMem == null)
			byInputMem = resolveMem("ent.Hero", "getSkillByInput");

		// Typed path first - same as HealthHooks (Priest_Sig_DivineIntervention, etc.).
		try {
			var h:ent.Hero = cast hero;
			var typed = h.getSkillByInput("SignatureSkill");
			if (typed == null)
				typed = h.getSkillByInput("Signature");
			typed = stableSignatureInput(hero, typed);
			if (typed != null)
				pushSkillSnap(hero, signatures, typed, getSkillId(typed), "SIG");
		} catch (_:Dynamic) {}

		for (input in [
			"SignatureSkill", "Signature", "SigSkill", "ClassSignature",
			"Ultimate", "UltimateSkill", "HeroSignature"
		]) {
			var skill = stableSignatureInput(hero, callResolved(byInputMem, [hero, input]));
			if (skill != null)
				pushSkillSnap(hero, signatures, skill, getSkillId(skill), "SIG");
		}

		var lists = [
			field(hero, "skillSlots"),
			field(hero, "attackSkills"),
			field(hero, "weaponSkills"),
			field(hero, "skills")
		];
		try {
			var spec = field(hero, "specialization");
			lists.push(field(spec, "skillSlots"));
			lists.push(field(spec, "skills"));
		} catch (_:Dynamic) {}
		// Available / base details often hold class signatures that aren't on the weapon bar.
		var level = heroLevel(hero);
		if (availMem == null)
			availMem = resolveMem("ent.Hero", "getAvailableSkillsForLevel");
		lists.push(callResolved(availMem, [hero, level]));
		if (detailsMem == null)
			detailsMem = resolveMem("ent.Hero", "getBaseSkillDetails");
		lists.push(callResolved(detailsMem, [hero]));

		for (arr in lists) {
			var n = arrayLen(arr);
			for (i in 0...n) {
				var item = arrayAt(arr, i);
				if (item == null)
					continue;
				var parsed = parseSkillish(item);
				if (!isSignatureId(parsed.id, parsed.skill))
					continue;
				pushSkillSnap(hero, signatures, parsed.skill, parsed.id, "SIG");
			}
		}

		ensureSignatureHashes();
		for (id in CLASS_SIGNATURE_SCRIPTS)
			forceSignature(hero, id);
		if (solarflare.PrayerCache.active)
			forceSignature(hero, solarflare.PrayerCache.judgmentId());
	}

	static function ensureSignatureHashes():Void {
		if (signatureHashesReady)
			return;
		signatureHashesReady = true;
		try {
			var h = script.skills.Warrior_Rage_Strike.HASH;
			if (h != null && h.length > 0)
				warriorSigHash = h;
		} catch (_:Dynamic) {}
		try {
			var h = script.skills.Mage_RayOfSpark.HASH;
			if (h != null && h.length > 0)
				mageSigHash = h;
		} catch (_:Dynamic) {}
		try {
			var h = script.skills.Priest_Sig_DivineIntervention.HASH;
			if (h != null && h.length > 0)
				priestSigHash = h;
		} catch (_:Dynamic) {}
		try {
			var h = script.skills.Rogue_Sig_Finisher.HASH;
			if (h != null && h.length > 0)
				rogueSigHash = h;
		} catch (_:Dynamic) {}
	}

	/** True for the four known class signatures (script id or runtime HASH). */
	public static function isKnownClassSignature(id:String):Bool {
		if (id == null || id.length == 0)
			return false;
		ensureSignatureHashes();
		if (id == WARRIOR_SIG_SCRIPT || id == MAGE_SIG_SCRIPT || id == PRIEST_SIG_SCRIPT || id == ROGUE_SIG_SCRIPT)
			return true;
		if (warriorSigHash.length > 0 && id == warriorSigHash)
			return true;
		if (mageSigHash.length > 0 && id == mageSigHash)
			return true;
		if (priestSigHash.length > 0 && id == priestSigHash)
			return true;
		if (rogueSigHash.length > 0 && id == rogueSigHash)
			return true;
		if (solarflare.PrayerCache.isJudgementId(id))
			return true;
		return false;
	}

	/** Prefer stable script-style id for icons / book entries. */
	static function classSignatureScriptId(id:String):String {
		if (id == null || id.length == 0)
			return "";
		ensureSignatureHashes();
		if (id == WARRIOR_SIG_SCRIPT || (warriorSigHash.length > 0 && id == warriorSigHash))
			return WARRIOR_SIG_SCRIPT;
		if (id == MAGE_SIG_SCRIPT || (mageSigHash.length > 0 && id == mageSigHash))
			return MAGE_SIG_SCRIPT;
		if (id == PRIEST_SIG_SCRIPT || (priestSigHash.length > 0 && id == priestSigHash)
			|| solarflare.PrayerCache.isJudgementId(id))
			return PRIEST_SIG_SCRIPT;
		if (id == ROGUE_SIG_SCRIPT || (rogueSigHash.length > 0 && id == rogueSigHash))
			return ROGUE_SIG_SCRIPT;
		return "";
	}

	static function forceSignature(hero:Dynamic, id:String):Void {
		if (id == null || id.length == 0)
			return;
		if (!isSignatureId(id, null) && !isKnownClassSignature(id))
			return;
		var scriptId = classSignatureScriptId(id);
		if (scriptId.length == 0) {
			if (isUsableSkillId(id) && (id.indexOf("_Sig_") >= 0 || id.indexOf("_sig_") >= 0))
				scriptId = id;
			else
				scriptId = id;
		}
		var skill = skillOverride(hero, id);
		if (skill == null && scriptId.length > 0 && id != scriptId)
			skill = skillOverride(hero, scriptId);
		if (skill == null)
			skill = findSkillById(hero, id);
		if (skill == null && scriptId.length > 0)
			skill = findSkillById(hero, scriptId);
		// Prefer script id so GameIcons hits Warrior_Rage_Strike.png / Mage_RayOfSpark.png / etc.
		var storeId = scriptId;
		var resolved = getSkillId(skill);
		if (isUsableSkillId(resolved)) {
			var resolvedScript = classSignatureScriptId(resolved);
			if (resolvedScript.length > 0)
				storeId = resolvedScript;
			else if (resolved.indexOf("_Sig_") >= 0 || resolved.indexOf("_sig_") >= 0)
				storeId = resolved;
		} else if (isUsableSkillId(id)) {
			var idScript = classSignatureScriptId(id);
			if (idScript.length > 0)
				storeId = idScript;
			else if (id.indexOf("_Sig_") >= 0 || id.indexOf("_sig_") >= 0)
				storeId = id;
		}
		pushSkillSnap(hero, signatures, skill, storeId, "SIG");
	}

	static function tryInputs(hero:Dynamic, dest:Array<GeauxSlotSnap>, group:String, inputs:Array<String>):Void {
		for (inp in inputs)
			pushSkillSnap(hero, dest, callResolved(byInputMem, [hero, inp]), "", group);
	}

	static function skipWeaponId(id:String):Bool {
		if (id == null || id.length == 0)
			return true;
		if (id.indexOf("_Passive") >= 0)
			return true;
		if (id.indexOf("_Base_Attack") >= 0)
			return true;
		if (id.indexOf("_Status") >= 0)
			return true;
		if (StringTools.endsWith(id, "_Upgrade") || StringTools.endsWith(id, "Upgrade"))
			return true;
		return false;
	}

	static function isUpgradeLabel(label:String):Bool {
		if (label == null || label.length == 0)
			return false;
		var s = label.toLowerCase();
		if (s == "upgrade" || s == "weapon upgraded")
			return true;
		if (s.indexOf("passive") >= 0)
			return true;
		return false;
	}

	static function callSkillBoolOpt(mem:ResolvedMember, skill:Dynamic):Null<Bool> {
		if (mem == null || skill == null)
			return null;
		try
			return HlxRuntime.callResolved(mem, [skill])
		catch (_:Dynamic) {}
		return null;
	}

	public static function isSignatureId(id:String, skill:Dynamic = null):Bool {
		if (id != null && id.length > 0) {
			if (isKnownClassSignature(id))
				return true;
			if (id.indexOf("_Sig_") >= 0 || id.indexOf("_sig_") >= 0)
				return true;
		}
		if (skill == null)
			return false;
		if (isSignatureMem == null)
			isSignatureMem = resolveMem("st.skill.BaseSkill", "isSignature");
		return callSkillBoolOpt(isSignatureMem, skill) == true;
	}

	static function skipInactive(skill:Dynamic, id:String, label:String = ""):Bool {
		if (isSignatureId(id, skill))
			return false;
		// Arsenal weapon skills must stay visible even if isActiveSkill flaps.
		if (isArsenalSkill(skill, id))
			return false;
		if (skipWeaponId(id))
			return true;
		var lab = label;
		if ((lab == null || lab.length == 0) && skill != null)
			lab = dynString(field(field(field(skill, "inf"), "texts"), "name"));
		if (isUpgradeLabel(lab))
			return true;
		if (skill == null)
			return false;
		if (isPassiveMem == null)
			isPassiveMem = resolveMem("st.skill.BaseSkill", "isPassive");
		if (isActiveMem == null)
			isActiveMem = resolveMem("st.skill.BaseSkill", "isActiveSkill");
		if (passiveMem == null)
			passiveMem = resolveMem("st.skill.BaseSkill", "isWeaponPassive");
		if (wepSkillMem == null)
			wepSkillMem = resolveMem("st.skill.BaseSkill", "isWeaponSkill");
		if (callSkillBoolOpt(isPassiveMem, skill) == true)
			return true;
		if (callSkillBoolOpt(passiveMem, skill) == true)
			return true;
		// Sheathed secondary/arsenal weapons still show on the action bar but report inactive.
		if (callSkillBoolOpt(isActiveMem, skill) == false) {
			if (trustHudSkills)
				return false;
			if (callSkillBoolOpt(wepSkillMem, skill) == true)
				return false;
			if (skillFromArsenal(skill))
				return false;
			return true;
		}
		return false;
	}

	static function pushSkillSnap(hero:Dynamic, dest:Array<GeauxSlotSnap>, skill:Dynamic, id:String, group:String):Void {
		if ((id == null || id.length == 0) && skill != null)
			id = getSkillId(skill);
		id = sanitizeSkillId(id);
		if (id.length == 0 && skill != null) {
			for (a in skillIdAliases(skill)) {
				id = sanitizeSkillId(a);
				if (id.length > 0)
					break;
			}
		}
		if (id.length == 0)
			return;
		for (s in dest) {
			if (s.id == id)
				return;
		}
		if (skill == null && id.length > 0) {
			try {
				var h:ent.Hero = cast hero;
				skill = equippedSkillByInput(h, id);
			} catch (_:Dynamic) {}
		}
		if (skill == null)
			skill = findSkillById(hero, id);
		if (skill == null)
			skill = skillOverride(hero, id);
		// Weapon / class / HUD paths must keep skills the vanilla bar still shows.
		var prevTrust = trustHudSkills;
		if (group == "BAR" || group == "WEP" || group == "CLS")
			trustHudSkills = true;
		var skip = skipInactive(skill, id, labelOf(skill, id));
		trustHudSkills = prevTrust;
		if (skip)
			return;
		var snap = new GeauxSlotSnap();
		snap.index = dest.length;
		snap.id = id;
		snap.iconId = preferScriptId(id, skill);
		if (snap.iconId.length == 0)
			snap.iconId = id;
		// Prefer script-style id for both identity and PNG lookup when we have one.
		if (isScriptStyleId(snap.iconId) && !isScriptStyleId(snap.id))
			snap.id = snap.iconId;
		snap.group = group;
		snap.label = labelOf(skill, snap.id);
		snap.present = true;
		if (skill == null)
			snap.ready = true;
		else {
			rememberSkill(skill, snap.id);
			applyCooldown(hero, snap, skill);
		}
		dest.push(snap);
	}

	static function callSkillBool(mem:ResolvedMember, skill:Dynamic):Bool {
		if (mem == null || skill == null)
			return false;
		try
			return HlxRuntime.callResolved(mem, [skill])
		catch (_:Dynamic) {}
		return false;
	}

	static function callSkillBool1(mem:ResolvedMember, skill:Dynamic, arg:String):Bool {
		if (mem == null || skill == null || arg == null || arg.length == 0)
			return false;
		try
			return HlxRuntime.callResolved(mem, [skill, arg])
		catch (_:Dynamic) {}
		return false;
	}

	public static function refreshBook(heroDyn:Dynamic):Void {
		bookIds = [];
		bookIconIds = [];
		bookLabels = [];
		bookGroups = [];
		if (heroDyn == null)
			return;
		var level = heroLevel(heroDyn);
		if (availMem == null)
			availMem = resolveMem("ent.Hero", "getAvailableSkillsForLevel");
		addBookArray(callResolved(availMem, [heroDyn, level]));
		if (detailsMem == null)
			detailsMem = resolveMem("ent.Hero", "getBaseSkillDetails");
		addBookArray(callResolved(detailsMem, [heroDyn]));
		addBookArray(field(heroDyn, "weaponSkills"));
		addBookArray(field(heroDyn, "attackSkills"));
		addBookArray(field(heroDyn, "skillSlots"));
		try {
			var spec = field(heroDyn, "specialization");
			addBookArray(field(spec, "skillSlots"));
		} catch (_:Dynamic) {}
	}

	static function heroLevel(hero:Dynamic):Int {
		var level = 1;
		try {
			if (levelMem == null)
				levelMem = HlxRuntime.resolveMember(HlxRuntime.resolveType("ent.Unit"), "get_level");
			if (levelMem != null)
				level = HlxRuntime.callResolved(levelMem, [hero]);
		} catch (_:Dynamic) {}
		if (level < 1)
			level = Std.int(FieldWalk.extractNumber(hero, "level", 1));
		if (level < 1)
			level = 1;
		return level;
	}

	static function resolveMem(typeName:String, name:String):ResolvedMember {
		try
			return HlxRuntime.resolveMember(HlxRuntime.resolveType(typeName), name)
		catch (_:Dynamic) {}
		return null;
	}

	static function callResolved(mem:ResolvedMember, args:Array<Dynamic>):Dynamic {
		if (mem == null)
			return null;
		try
			return HlxRuntime.callResolved(mem, args)
		catch (_:Dynamic) {}
		return null;
	}

	static function addBookArray(arr:Dynamic):Void {
		var n = arrayLen(arr);
		for (i in 0...n)
			addBookItem(arrayAt(arr, i));
	}

	static function addBookItem(item:Dynamic, group:String = ""):Void {
		if (item == null)
			return;
		var parsed = parseSkillish(item);
		if (parsed.id.length == 0)
			return;
		if (skipInactive(parsed.skill, parsed.id, parsed.label))
			return;
		if ((group == null || group.length == 0) && isSignatureId(parsed.id, parsed.skill))
			group = "SIG";
		if ((group == null || group.length == 0) && (skillFromArsenal(parsed.skill) || callSkillBool(wepSkillMem, parsed.skill))
			&& !solarflare.PrayerCache.isPrayerId(parsed.id))
			group = "WEP";
		addBookId(parsed.id, parsed.label.length > 0 ? parsed.label : shortFromId(parsed.id), group,
			preferScriptId(parsed.id, parsed.skill));
	}

	static function addBookId(id:String, label:String, group:String, iconId:String = ""):Void {
		id = sanitizeSkillId(id);
		if (id.length == 0)
			return;
		iconId = sanitizeSkillId(iconId);
		if (iconId.length == 0)
			iconId = id;
		var shown = solarflare.EngineSkillId.display(id);
		if (shown.length > 0)
			label = shown;
		else if (!isCleanLabel(label))
			label = id;
		if (!isCleanLabel(label))
			label = id;
		for (i in 0...bookIds.length) {
			if (bookIds[i] != id)
				continue;
			if (group != null && group.length > 0) {
				bookGroups[i] = group;
				bookLabels[i] = bookLabel(label, group);
			}
			if (i >= bookIconIds.length)
				bookIconIds.push(iconId);
			else if (bookIconIds[i] == null || bookIconIds[i].length == 0 || isScriptStyleId(iconId))
				bookIconIds[i] = iconId;
			return;
		}
		bookIds.push(id);
		bookIconIds.push(iconId);
		bookGroups.push(group != null ? group : "");
		bookLabels.push(bookLabel(label, group));
	}

	static function bookLabel(label:String, group:String):String {
		if (group != null && group.length > 0)
			return label + " (" + group + ")";
		return label;
	}

	static function refreshBookFromBar():Void {
		for (snap in weapons) {
			if (snap == null || !snap.present || snap.id == null || snap.id.length == 0)
				continue;
		addBookId(snap.id, snap.label.length > 0 ? snap.label : shortFromId(snap.id), "BAR", snap.iconId);
		}
		tagBookPrayers();
	}

	static function tagBookPrayers():Void {
		if (!solarflare.PrayerCache.active)
			return;
		addBookId(solarflare.PrayerCache.smiteId(), solarflare.PrayerCache.prayerLabel(solarflare.PrayerCache.smiteId()), "PR");
		addBookId(solarflare.PrayerCache.lifeId(), solarflare.PrayerCache.prayerLabel(solarflare.PrayerCache.lifeId()), "PR");
		addBookId(solarflare.PrayerCache.shieldId(), solarflare.PrayerCache.prayerLabel(solarflare.PrayerCache.shieldId()), "PR");
	}

	public static function groupForId(id:String):String {
		if (id == null || id.length == 0)
			return "";
		if (solarflare.PrayerCache.isPrayerId(id))
			return "PR";
		if (isSignatureId(id, null))
			return "SIG";
		for (s in weapons) {
			if (s != null && s.id == id)
				return "BAR";
		}
		for (i in 0...bookIds.length) {
			if (bookIds[i] == id)
				return bookGroups[i];
		}
		return "";
	}

	/**
	 * Priest Mouse Back swaps to a readied prayer. Geaux's signature cell must stay
	 * bound to Judgment, so never admit that temporary prayer pointer as a signature.
	 */
	static function stableSignatureInput(hero:Dynamic, skill:Dynamic):Dynamic {
		if (skill == null || !skillIsPrayer(skill))
			return skill;
		return ownerGetSkill(hero, PRIEST_SIG_SCRIPT);
	}

	static function refreshBookFromSignatures():Void {
		for (s in signatures) {
			if (s == null || !s.present || s.id == null || s.id.length == 0)
				continue;
			var label = s.label != null && s.label.length > 0 ? s.label : shortFromId(s.id);
		addBookId(s.id, label, "SIG", s.iconId);
		}
	}

	/** Keep prayer ready flags in sync every sample (charge / Judgment spend). */
	static function refreshPrayerReady():Void {
		for (i in 0...count) {
			var snap = slots[i];
			if (!snap.present || snap.id == null || snap.id.length == 0)
				continue;
			if (!solarflare.PrayerCache.isPrayerId(snap.id))
				continue;
			snap.group = "PR";
			snap.ready = solarflare.PrayerCache.prayerReady(snap.id);
			snap.affordable = snap.ready;
			snap.cdLeft = 0;
			snap.cdMax = 0;
			snap.remaining = 0;
		}
	}

	static function fillPrayerSnap(snap:GeauxSlotSnap, id:String, index:Int):Void {
		snap.index = index;
		snap.id = id;
		snap.iconId = id;
		snap.label = solarflare.PrayerCache.prayerLabel(id);
		snap.group = "PR";
		snap.present = true;
		snap.ready = solarflare.PrayerCache.prayerReady(id);
		snap.affordable = snap.ready;
		snap.cdLeft = 0;
		snap.cdMax = 0;
		snap.remaining = 0;
	}

	static function copySnap(dest:GeauxSlotSnap, src:GeauxSlotSnap, index:Int):Void {
		dest.index = index;
		dest.id = src.id;
		dest.iconId = src.iconId;
		dest.label = src.label;
		dest.group = src.group;
		dest.present = src.present;
		dest.ready = src.ready;
		dest.cooldownValid = src.cooldownValid;
		dest.readyFlashUntil = src.readyFlashUntil;
		dest.affordable = src.affordable;
		dest.procReady = src.procReady;
		dest.cdLeft = src.cdLeft;
		dest.cdMax = src.cdMax;
		dest.remaining = src.remaining;
		dest.iconCandidates = src.iconCandidates != null ? src.iconCandidates.copy() : [];
	}

	static function freezeSlotIcons(n:Int):Void {
		var i = 0;
		while (i < n) {
			var snap = slots[i];
			if (snap == null) {
				i++;
				continue;
			}
			if (!snap.present) {
				snap.iconCandidates = [];
				i++;
				continue;
			}
			var hint = snap.iconId != null && snap.iconId.length > 0 ? snap.iconId : snap.id;
			snap.iconCandidates = iconIdCandidates(hint, null);
			if (hint != snap.id && snap.id != null && snap.id.length > 0) {
				for (extra in iconIdCandidates(snap.id, null)) {
					var known = false;
					for (t in snap.iconCandidates) {
						if (t == extra) {
							known = true;
							break;
						}
					}
					if (!known)
						snap.iconCandidates.push(extra);
				}
			}
			i++;
		}
	}

	static function ensureSlots(n:Int):Void {
		while (slots.length < n)
			slots.push(new GeauxSlotSnap());
	}

	static function clearSlot(snap:GeauxSlotSnap, index:Int):Void {
		snap.index = index;
		snap.id = "";
		snap.iconId = "";
		snap.label = "";
		snap.group = "";
		snap.present = false;
		snap.cooldownValid = false;
		snap.readyFlashUntil = 0;
		snap.ready = false;
		snap.affordable = true;
		snap.cdLeft = 0;
		snap.cdMax = 0;
		snap.remaining = 0;
		snap.charges = 0;
		snap.chargesMax = 0;
		snap.iconCandidates = [];
	}

	static function fillSlot(hero:Dynamic, runtimeSlots:Dynamic, specSlots:Dynamic, snap:GeauxSlotSnap, index:Int, overrideId:String):Void {
		clearSlot(snap, index);
		var id = overrideId != null ? sanitizeSkillId(overrideId) : "";
		if (id.length == 0)
			return;
		var skill:Dynamic = null;

		if (solarflare.PrayerCache.isPrayerId(id)) {
			fillPrayerSnap(snap, id, index);
			return;
		}

		if (skill == null && id.length > 0) {
			try {
				var h:ent.Hero = cast hero;
				skill = equippedSkillByInput(h, id);
			} catch (_:Dynamic) {}
		}
		if (skill == null && id.length > 0)
			skill = findSkillById(hero, id);
		if (skill == null && id.length > 0)
			skill = skillOverride(hero, id);

		if (skill == null && id.length == 0)
			return;
		id = sanitizeSkillId(id.length > 0 ? id : getSkillId(skill));
		if (id.length == 0)
			return;
		if (skill != null)
			rememberSkill(skill, id);

		snap.id = id;
		snap.iconId = preferScriptId(id, skill);
		if (snap.iconId.length == 0)
			snap.iconId = id;
		if (isScriptStyleId(snap.iconId) && !isScriptStyleId(snap.id))
			snap.id = snap.iconId;
		snap.label = labelOf(skill, snap.id);
		snap.group = groupForId(snap.id);
		snap.present = true;
		if (skill == null) {
			snap.ready = true;
			return;
		}
		applyCooldown(hero, snap, skill);
	}

	static function parseSkillish(item:Dynamic):{id:String, label:String, skill:Dynamic} {
		var id = dynString(item);
		var label = "";
		var skill:Dynamic = null;
		if (id.length == 0) {
			id = getSkillId(item);
			var inf = field(item, "inf");
			label = dynString(field(field(inf, "texts"), "name"));
			if (label.length == 0)
				label = dynString(field(field(item, "texts"), "name"));
			if (id.length > 0 || inf != null || field(item, "kind") != null)
				skill = item;
		} else {
			label = shortFromId(id);
		}
		if (label.length == 0)
			label = shortFromId(id);
		return {id: id, label: label, skill: skill};
	}

	static function skillOverride(hero:Dynamic, id:String):Dynamic {
		try {
			if (overrideMem == null)
				overrideMem = HlxRuntime.resolveMember(HlxRuntime.resolveType("ent.Hero"), "getSkillOverride");
			if (overrideMem != null)
				return HlxRuntime.callResolved(overrideMem, [hero, id]);
		} catch (_:Dynamic) {}
		return null;
	}

	public static function findSkillById(hero:Dynamic, id:String):Dynamic {
		if (id == null || id.length == 0)
			return null;
		var lists = [
			field(hero, "weaponSkills"),
			field(hero, "attackSkills"),
			field(hero, "skillSlots")
		];
		try {
			var spec = field(hero, "specialization");
			lists.push(field(spec, "skillSlots"));
		} catch (_:Dynamic) {}
		for (arr in lists) {
			var n = arrayLen(arr);
			for (i in 0...n) {
				var item = arrayAt(arr, i);
				if (item == null)
					continue;
				var parsed = parseSkillish(item);
				var skill = parsed.skill != null ? parsed.skill : item;
				if (parsed.id == id)
					return skill;
				for (a in skillIdAliases(skill)) {
					if (a == id)
						return skill;
				}
				if (preferScriptId("", skill) == id)
					return skill;
			}
		}
		return null;
	}

	/**
	 * Solarflare ENGINE_ID_REGISTRY §5.1: prefer script-style ids (contain `_`) for icons.
	 * Order: inf.id → kind → inf.script → skill.id. Never return `{bytes…}` dumps.
	 */
	public static function getSkillId(skill:Dynamic):String {
		if (skill == null)
			return "";
		return preferScriptId("", skill);
	}

	/** True for `Class_Skill_Name` style ids used by DPS-meter PNGs. */
	public static function isScriptStyleId(id:String):Bool {
		id = sanitizeSkillId(id);
		return id.length >= 3 && id.indexOf("_") >= 0;
	}

	/**
	 * Best PNG / identity stem: script-style first, then any clean usable id.
	 * Pulls from hint, skill.kind, skill.inf.id, skill.inf.script, skill.id.
	 */
	public static function preferScriptId(hint:String, skill:Dynamic = null):String {
		var cands:Array<String> = [];
		addAlias(cands, hint);
		if (skill != null) {
			try {
				var s:st.skill.BaseSkill = skill;
				if (s != null) {
					// Always coerce — kind/inf.id are often HASH Bytes at runtime.
					addAlias(cands, s.kind);
					if (s.inf != null) {
						addAlias(cands, s.inf.id);
						addAlias(cands, field(s.inf, "script"));
					}
				}
			} catch (_:Dynamic) {}
			addAlias(cands, field(skill, "kind"));
			addAlias(cands, field(field(skill, "inf"), "id"));
			addAlias(cands, field(field(skill, "inf"), "script"));
			addAlias(cands, field(skill, "id"));
		}
		var bestHash = "";
		for (c in cands) {
			if (!isUsableSkillId(c))
				continue;
			if (isScriptStyleId(c))
				return c;
			if (bestHash.length == 0)
				bestHash = c;
		}
		return bestHash;
	}

	/** Drop Bytes dumps / object toString garbage. Keeps HASH and script ids. */
	public static function sanitizeSkillId(value:Dynamic):String {
		if (value == null)
			return "";
		// On HashLink, HASH/script identifiers can satisfy the String type check
		// while still being backed by hl.Bytes. Decode that representation first
		// so it cannot leak into config arrays and JSON as {bytes,length}.
		var decoded = bytesAsCleanString(value);
		if (decoded.length > 0)
			return isCleanLabel(decoded) ? decoded : "";
		var id = "";
		try {
			if (Std.isOfType(value, String))
				id = cast value;
		} catch (_:Dynamic) {}
		if (id.length == 0)
			return "";
		if (!isCleanLabel(id))
			return "";
		return id;
	}

	/** Ids safe for PNG lookup / UI — reject object dumps and empty. */
	public static function isUsableSkillId(id:String):Bool {
		if (id == null || id.length < 3)
			return false;
		if (!isCleanLabel(id))
			return false;
		// Prefer script-style ids (Class_Skill_Name); still allow long alphanumeric HASH stems.
		if (id.indexOf("_") >= 0)
			return true;
		if (id.length >= 8 && ~/^[A-Za-z0-9]+$/.match(id))
			return true;
		return false;
	}

	/** Candidate PNG stems for a skill (script id, kind, HASH, aliases). Script-style first. */
	public static function iconIdCandidates(id:String, skill:Dynamic = null):Array<String> {
		if (id == null || id.length == 0)
			return [];
		if (skill == null) {
			var cached = iconCandidatesCache.get(id);
			if (cached != null)
				return cached;
		}
		var raw:Array<String> = [];
		addAlias(raw, preferScriptId(id, skill));
		addAlias(raw, id);
		if (skill != null) {
			for (a in skillIdAliases(skill))
				addAlias(raw, a);
		}
		if (solarflare.PrayerCache.isPrayerId(id)) {
			var k = solarflare.PrayerCache.prayerKind(id);
			if (k == "smite")
				addAlias(raw, "Priest_Prayer_Smite");
			else if (k == "life")
				addAlias(raw, "Priest_Prayer_Life");
			else if (k == "shield")
				addAlias(raw, "Priest_Prayer_Shield");
		}
		// Only Judgment aliases to priest sig assets — do not remap Warrior/Mage/Rogue.
		ensureSignatureHashes();
		if (solarflare.PrayerCache.isJudgementId(id)
			|| id == PRIEST_SIG_SCRIPT
			|| (priestSigHash.length > 0 && id == priestSigHash)) {
			addAlias(raw, PRIEST_SIG_SCRIPT);
			addAlias(raw, solarflare.PrayerCache.judgmentId());
		} else {
			var sigScript = classSignatureScriptId(id);
			if (sigScript.length > 0)
				addAlias(raw, sigScript);
		}
		// Script-style ids first so GameIcons hits DPS-meter PNGs before HASH misses.
		var out:Array<String> = [];
		for (c in raw) {
			if (isScriptStyleId(c))
				addAlias(out, c);
		}
		for (c in raw)
			addAlias(out, c);
		if (skill == null)
			iconCandidatesCache.set(id, out);
		return out;
	}

	static function skillIdAliases(skill:Dynamic):Array<String> {
		var out:Array<String> = [];
		addAlias(out, dynString(field(skill, "id")));
		addAlias(out, dynString(field(skill, "kind")));
		addAlias(out, dynString(field(field(skill, "inf"), "id")));
		addAlias(out, dynString(field(field(skill, "inf"), "script")));
		try {
			var typed:st.skill.Skill = skill;
			if (typed != null) {
				addAlias(out, typed.kind);
				if (typed.inf != null) {
					addAlias(out, typed.inf.id);
					addAlias(out, dynString(field(typed.inf, "script")));
				}
			}
		} catch (_:Dynamic) {}
		return out;
	}

	static function addAlias(out:Array<String>, id:Dynamic):Void {
		var s = coerceSkillId(id);
		if (s.length == 0)
			return;
		for (e in out) {
			if (e == s)
				return;
		}
		out.push(s);
	}

	/**
	 * Force a JSON-safe skill id string. HASH fields are often hl.Bytes at runtime;
	 * putting those in slotIds makes Json.stringify emit `{bytes,length}` and wipe on load.
	 */
	public static function coerceSkillId(v:Dynamic):String {
		if (v == null)
			return "";
		// Decode byte-backed HashLink strings before Std.isOfType(v, String).
		// HashLink may report those values as String even though Json.stringify
		// would serialize the underlying object instead of a JSON string.
		var fromBytes = bytesAsCleanString(v);
		if (fromBytes.length > 0)
			return sanitizeSkillId(fromBytes);
		return sanitizeSkillId(v);
	}

	static function bytesAsCleanString(v:Dynamic):String {
		if (v == null)
			return "";
		var len = 0;
		try {
			var L:Dynamic = Reflect.field(v, "length");
			if (L != null)
				len = Std.int(L);
		} catch (_:Dynamic) {}
		if (len < 3 || len > 128)
			return "";
		var buf = new StringBuf();
		var i = 0;
		while (i < len) {
			var c = -1;
			try
				c = v.getUI8(i)
			catch (_:Dynamic) {
				try
					c = v.get(i)
				catch (_2:Dynamic) {
					return "";
				}
			}
			if (c == 0)
				break;
			if (c < 32 || c > 126)
				return "";
			buf.addChar(c);
			i++;
		}
		return buf.toString();
	}

	public static function noteUse(hero:Dynamic, skill:Dynamic):Void {
		rememberSkill(skill);
		telemetryAt = 0;
		telemetryDirty = true;
		var now = nowStamp();
		for (id in skillIdAliases(skill))
			lastUseAt.set(id, now);
	}

	/**
	 * Constant-time cooldown hook ingress. Native callbacks do not expand aliases,
	 * query cooldown getters, consult CDB, or walk equipment; the demanded sampler
	 * reconciles the authoritative continuous values within its 50 ms ceiling.
	 */
	public static function noteCooldownEdge():Void {
		equipDirty = true;
		telemetryAt = 0;
		telemetryDirty = true;
		solarflare.ObserveDemand.markGeauxDirty();
	}

	static function addSkillId(ids:Array<String>, id:String):Void {
		if (id == null || id.length == 0)
			return;
		for (e in ids) {
			if (e == id)
				return;
		}
		ids.push(id);
	}

	static function callOverrideSkill(obj:Dynamic):Dynamic {
		if (obj == null)
			return null;
		var types = ["ui.hud.WeaponSkillSlotButton", "ui.hud.SkillSlotButton", "ui.hud.SkillButton"];
		for (t in types) {
			try {
				var mem = resolveMem(t, "getOverrideSkill");
				if (mem != null) {
					var s = HlxRuntime.callResolved(mem, [obj]);
					if (s != null)
						return s;
				}
			} catch (_:Dynamic) {}
		}
		try {
			var s:Dynamic = untyped obj.getOverrideSkill();
			if (s != null)
				return s;
		} catch (_:Dynamic) {}
		return null;
	}

	static function skillIdFromButton(btn:Dynamic):String {
		var id = dynString(plainField(plainField(btn, "inf"), "id"));
		if (!isScriptStyleId(id)) {
			var script = dynString(plainField(plainField(btn, "inf"), "script"));
			if (isScriptStyleId(script))
				id = script;
		}
		if (id.length == 0)
			id = dynString(plainField(plainField(btn, "skill"), "kind"));
		if (id.length == 0)
			id = dynString(plainField(plainField(plainField(btn, "skill"), "inf"), "id"));
		if (id.length == 0)
			id = dynString(plainField(plainField(btn, "skill"), "id"));
		return id;
	}

	static function plainField(obj:Dynamic, name:String):Dynamic {
		return FieldWalk.extractObject(obj, name);
	}

	static function objectChildren(node:Dynamic):Dynamic {
		try {
			var kids = HlxRuntime.resolveField(node, "children");
			if (kids != null && arrayLen(kids) > 0)
				return kids;
		} catch (_:Dynamic) {}
		try
			return HlxRuntime.resolveField(node, "_children")
		catch (_:Dynamic) {}
		return null;
	}

	static function textOf(el:Dynamic):String {
		var t = dynString(field(el, "text"));
		if (t.length == 0)
			t = dynString(field(el, "prevUnformatted"));
		return t;
	}

	static function parseCdText(s:String):Float {
		if (s == null || s.length == 0)
			return Math.NaN;
		var buf = new StringBuf();
		var i = 0;
		while (i < s.length) {
			var ch = s.charAt(i);
			if (ch == "<") {
				var j = s.indexOf(">", i);
				if (j < 0)
					break;
				i = j + 1;
				continue;
			}
			buf.add(ch);
			i++;
		}
		var cleaned = StringTools.trim(buf.toString());
		cleaned = StringTools.replace(cleaned, "s", "");
		cleaned = StringTools.replace(cleaned, "S", "");
		var f = Std.parseFloat(cleaned);
		if (Math.isNaN(f) || f < 0)
			return Math.NaN;
		return f;
	}

	static function applyCooldown(hero:Dynamic, snap:GeauxSlotSnap, skill:Dynamic):Void {
		writeCooldownFromSkill(snap, skill);
	}

	/** Ledger/production name: typed Skill getters. Raw cdUntil / cooldownDuration fields miss. */
	static function writeCooldownFromSkill(snap:GeauxSlotSnap, skill:Dynamic):Void {
		if (snap == null || skill == null)
			return;
		// Duration is static per equipped skill; only the live timer is re-polled here.
		var cached:Float = snap.cdStaticGen == staticGen ? snap.cdMaxStatic : -1;
		pollSkillCooldown(skill, cdPoll, cached);
		if (cdPoll.max > 0) {
			snap.cdMaxStatic = cdPoll.max;
			snap.cdStaticGen = staticGen;
		}
		commitCooldown(snap, cdPoll);
	}

	static function ensureCdMems():Void {
		if (cdLeftMem == null)
			cdLeftMem = resolveMem("st.skill.Skill", "getCooldownLeft");
		if (cdEffMem == null)
			cdEffMem = resolveMem("st.skill.Skill", "getEffectiveCooldown");
		if (cdMem == null)
			cdMem = resolveMem("st.skill.Skill", "getCooldown");
		if (cdProgMem == null)
			cdProgMem = resolveMem("st.skill.Skill", "getCooldownProgress");
	}

	/**
	 * `cachedMax` > 0 reuses a duration already sampled on the equip cadence and skips the
	 * three static getters, leaving only the live timer calls on the telemetry tick.
	 */
	static function pollSkillCooldown(skill:Dynamic, out:GeauxCdPoll, cachedMax:Float = -1):Void {
		out.reset();
		var haveMax = cachedMax > 0;
		if (haveMax)
			out.max = cachedMax;
		var typedOk = false;
		try {
			var typed:st.skill.Skill = skill;
			if (typed != null) {
				typedOk = true;
				if (!haveMax) {
					try
						out.max = typed.getEffectiveCooldown()
					catch (_:Dynamic) {}
					if (out.max <= 0) {
						try
							out.max = typed.getCooldown()
						catch (_:Dynamic) {}
					}
					if (out.max <= 0) {
						try
							out.max = typed.cooldownDuration
						catch (_:Dynamic) {}
					}
				}
				try
					out.inCd = typed.isInCooldown()
				catch (_:Dynamic) {}
				try
					out.left = typed.getCooldownLeft()
				catch (_:Dynamic) {}
				try
					out.prog = typed.getCooldownProgress()
				catch (_:Dynamic) {}
			}
		} catch (_:Dynamic) {}
		if (!typedOk) {
			ensureCdMems();
			if (!haveMax) {
				out.max = callNamedFloat(skill, "getEffectiveCooldown", cdEffMem);
				if (Math.isNaN(out.max) || out.max <= 0)
					out.max = callNamedFloat(skill, "getCooldown", cdMem);
			}
			out.left = callNamedFloat(skill, "getCooldownLeft", cdLeftMem);
			out.prog = callNamedFloat(skill, "getCooldownProgress", cdProgMem);
		}
		out.max = normalizeSeconds(out.max, 0);
		if (Math.isNaN(out.max) || out.max < 0)
			out.max = 0;
		out.valid = Math.isFinite(out.left) && out.left >= 0 || Math.isFinite(out.prog) && out.prog >= 0;
		out.left = scaleCdLeft(out.left, out.max);
		if (!Math.isNaN(out.prog) && out.prog < 0)
			out.prog = Math.NaN;
	}

	static function scaleCdLeft(left:Float, max:Float):Float {
		left = normalizeSeconds(left, max);
		if (Math.isNaN(left) || left < 0)
			return 0;
		if (max > 2 && left > 0 && left <= 1.0001)
			return left * max;
		return left;
	}

	static function commitCooldown(snap:GeauxSlotSnap, p:GeauxCdPoll):Void {
		snap.cooldownValid = p.valid;
		var max = p.max;
		var left = p.left;
		var prog = p.prog;
		var inCd = p.inCd;
		var prevMax = snap.cdMax;
		if (!inCd && left <= 0.05 && (Math.isNaN(prog) || prog <= 0.05)) {
			snap.cdLeft = 0;
			snap.remaining = 0;
			snap.cdMax = max;
			snap.ready = true;
			ledgerGeauxCd("typed", "writeCooldownFromSkill", "getCooldownLeft", "", snap);
			return;
		}
		if (left > 0.05) {
			snap.cdLeft = left;
			snap.cdMax = max > left ? max : left;
			snap.remaining = snap.cdMax > 0.05 ? clamp01(left / snap.cdMax) : 1;
			if (!Math.isNaN(prog) && prog > 0.02 && prog <= 1.0001)
				snap.remaining = clamp01(prog);
			snap.ready = false;
			ledgerGeauxCd("typed", "writeCooldownFromSkill", "getCooldownLeft", "", snap);
			return;
		}
		if (inCd && !Math.isNaN(prog) && prog > 0.05 && prog <= 1.0001) {
			snap.remaining = clamp01(prog);
			snap.cdMax = max > 0.05 ? max : prevMax;
			snap.cdLeft = snap.cdMax > 0.05 ? snap.remaining * snap.cdMax : 0;
			snap.ready = snap.cdLeft <= 0.05;
			ledgerGeauxCd("typed", "writeCooldownFromSkill", "getCooldownProgress", "", snap);
			return;
		}
		if (inCd) {
			if (max > 0.05)
				snap.cdMax = max;
			else if (prevMax > snap.cdMax)
				snap.cdMax = prevMax;
			snap.ready = false;
			ledgerGeauxCd("typed", "writeCooldownFromSkill", "isInCooldown", "", snap);
			return;
		}
		snap.cdLeft = 0;
		snap.cdMax = max;
		snap.remaining = 0;
		snap.ready = true;
		ledgerGeauxCd("typed", "writeCooldownFromSkill", "getCooldownLeft", "", snap);
	}

	static function tickSlots(heroDyn:Dynamic):Void {
		if (heroDyn == null)
			return;
		var hero:ent.Hero = null;
		try
			hero = cast heroDyn
		catch (_:Dynamic) {}
		var i = 0;
		while (i < count) {
			tickSlot(hero, heroDyn, slots[i]);
			i++;
		}
	}

	static function tickSlot(hero:ent.Hero, heroDyn:Dynamic, snap:GeauxSlotSnap):Void {
		if (snap == null)
			return;
		snap.cooldownValid = false;
		snap.readyFlashUntil = 0;
		if (!snap.present || snap.id == null || snap.id.length == 0) {
			snap.affordable = true;
			snap.procReady = false;
			snap.charges = 0;
			snap.chargesMax = 0;
			return;
		}
		if (solarflare.PrayerCache.isPrayerId(snap.id)) {
			snap.affordable = snap.ready;
			snap.procReady = false;
			snap.charges = 0;
			snap.chargesMax = 0;
			return;
		}
		var skill:Dynamic = bindSlotSkill(hero, snap);
		if (skill != null) {
			applyCooldown(heroDyn, snap, skill);
			applySkillCharges(snap, skill);
		} else {
			snap.charges = 0;
			snap.chargesMax = 0;
		}
		// Charge pools: regenerating a charge is not "unusable" while ammo remains.
		if (snap.chargesMax > 0)
			snap.ready = snap.charges > 0;
		applyAffordSnap(hero, snap, skill);
		applyProcReady(snap, skill);
		var key = snap.id;
		if (!readyFlashes.exists(key) || readySkillRefs.get(key) != skill) {
			readyFlashes.set(key, new ReadyFlashState());
			readySkillRefs.set(key, skill);
		}
		snap.readyFlashUntil = readyFlashes.get(key).observe(skill != null && snap.cooldownValid,
			snap.cdLeft > 0.05 || snap.remaining > 0.02, haxe.Timer.stamp());
	}

	/** Observe-only: freeze Spell Activation Overlay flag from typed SkillScript. */
	static function applyProcReady(snap:GeauxSlotSnap, skill:Dynamic):Void {
		snap.procReady = false;
		if (skill == null || snap == null)
			return;
		try {
			var sc:script.SkillScript = skill;
			if (sc != null)
				snap.procReady = sc.shouldPlayInstantly();
		} catch (_:Dynamic) {}
	}

	static function bindSlotSkill(hero:ent.Hero, snap:GeauxSlotSnap):Dynamic {
		var skill:Dynamic = ownerGetSkill(hero, snap.id);
		if (skill == null && snap.iconId != null && snap.iconId != snap.id)
			skill = ownerGetSkill(hero, snap.iconId);
		if (skill != null && skillIsPrayer(skill) && isKnownClassSignature(snap.id))
			skill = ownerGetSkill(hero, PRIEST_SIG_SCRIPT);
		if (skill == null)
			skill = pinnedSkill(snap.id);
		if (skill == null && snap.iconId != null && snap.iconId != snap.id)
			skill = pinnedSkill(snap.iconId);
		if (skill != null && skillIsPrayer(skill) && isKnownClassSignature(snap.id))
			skill = pinnedSkill(PRIEST_SIG_SCRIPT);
		if (skill == null)
			skill = equippedSkillByInput(hero, snap.id);
		if (skill == null)
			skill = cachedSkill(snap.id);
		if (skill == null && hero != null)
			skill = resolveLiveSkill(hero, snap.id);
		if (skill != null && skillIsPrayer(skill) && isKnownClassSignature(snap.id))
			return pinnedSkill(PRIEST_SIG_SCRIPT);
		if (skill != null)
			rememberSkill(skill, snap.id);
		return skill;
	}

	/** Engine map lookup — not HUD, not SignatureSkill input, not array scan. */
	static function ownerGetSkill(hero:Dynamic, id:String):Dynamic {
		if (hero == null || id == null || id.length == 0)
			return null;
		try {
			var go:ent.GameObject = hero;
			var s = go.getSkill(id);
			if (s != null)
				return s;
		} catch (_:Dynamic) {}
		var script = classSignatureScriptId(id);
		if (script.length > 0 && script != id) {
			try {
				var go:ent.GameObject = hero;
				return go.getSkill(script);
			} catch (_:Dynamic) {}
		}
		return null;
	}

	static function pinnedSkill(id:String):Dynamic {
		if (id == null || id.length == 0)
			return null;
		if (barSkillById.exists(id))
			return barSkillById.get(id);
		var script = classSignatureScriptId(id);
		if (script.length > 0 && barSkillById.exists(script))
			return barSkillById.get(script);
		for (a in iconIdCandidates(id, null)) {
			if (barSkillById.exists(a))
				return barSkillById.get(a);
		}
		return null;
	}

	static function pinnedBtn(id:String):Dynamic {
		if (id == null || id.length == 0)
			return null;
		if (barBtnById.exists(id))
			return barBtnById.get(id);
		var script = classSignatureScriptId(id);
		if (script.length > 0 && barBtnById.exists(script))
			return barBtnById.get(script);
		for (a in iconIdCandidates(id, null)) {
			if (barBtnById.exists(a))
				return barBtnById.get(a);
		}
		return null;
	}

	/** Floor from vanilla cdTimer only if that button still shows this skill. Never shorten. */
	static function overlayVanillaCd(snap:GeauxSlotSnap):Void {
		if (snap == null || solarflare.PrayerCache.isPrayerId(snap.id))
			return;
		var btn = pinnedBtn(snap.id);
		if (btn == null && snap.iconId != snap.id)
			btn = pinnedBtn(snap.iconId);
		if (btn == null)
			return;
		if (!buttonShowsId(btn, snap.id) && (snap.iconId == null || !buttonShowsId(btn, snap.iconId)))
			return;
		var left = buttonCdLeft(btn);
		if (Math.isNaN(left) || left <= 0.05)
			return;
		snap.ready = false;
		if (snap.cdLeft + 0.05 >= left)
			return;
		snap.cdLeft = left;
		if (snap.cdMax < left)
			snap.cdMax = left;
		snap.remaining = snap.cdMax > 0.05 ? clamp01(left / snap.cdMax) : 1;
	}

	static function buttonShowsId(btn:Dynamic, id:String):Bool {
		if (btn == null || id == null || id.length == 0)
			return false;
		try {
			var typed:ui.hud.SkillButton = btn;
			if (typed != null) {
				if (typed.skill != null && skillMatches(typed.skill, id))
					return true;
				if (typed.inf != null && typed.inf.id != null) {
					var bid = sanitizeSkillId(typed.inf.id);
					if (bid == sanitizeSkillId(id) || classSignatureScriptId(bid) == classSignatureScriptId(id))
						return true;
				}
			}
		} catch (_:Dynamic) {}
		var fromBtn = sanitizeSkillId(skillIdFromButton(btn));
		if (fromBtn.length == 0)
			return false;
		var want = sanitizeSkillId(id);
		if (fromBtn == want)
			return true;
		var a = classSignatureScriptId(fromBtn);
		var b = classSignatureScriptId(want);
		return a.length > 0 && a == b;
	}

	static function buttonCdLeft(btn:Dynamic):Float {
		if (btn == null)
			return Math.NaN;
		try {
			var typed:ui.hud.SkillButton = btn;
			if (typed != null) {
				if (typed.cdTimer != null) {
					var t = parseCdText(typed.cdTimer.text);
					if (!Math.isNaN(t) && t > 0)
						return t;
				}
				if (typed.serverCdTimer != null) {
					var t2 = parseCdText(typed.serverCdTimer.text);
					if (!Math.isNaN(t2) && t2 > 0)
						return t2;
				}
			}
		} catch (_:Dynamic) {}
		var left = parseCdText(textOf(plainField(btn, "cdTimer")));
		if (Math.isNaN(left) || left <= 0)
			left = parseCdText(textOf(plainField(btn, "serverCdTimer")));
		return left;
	}

	static function eachCdSnap(fn:GeauxSlotSnap->Void):Void {
		if (fn == null)
			return;
		var i = 0;
		while (i < count) {
			if (slots[i] != null)
				fn(slots[i]);
			i++;
		}
		if (weapons != null) {
			for (s in weapons) {
				if (s != null)
					fn(s);
			}
		}
		if (classSkills != null) {
			for (s in classSkills) {
				if (s != null)
					fn(s);
			}
		}
		if (signatures != null) {
			for (s in signatures) {
				if (s != null)
					fn(s);
			}
		}
	}

	static function eachSlotSnap(fn:GeauxSlotSnap->Void):Void {
		if (fn == null)
			return;
		var i = 0;
		while (i < count) {
			if (slots[i] != null)
				fn(slots[i]);
			i++;
		}
	}

	static function signatureMatchesSnap(skill:st.skill.Skill, snapId:String):Bool {
		if (skill == null || snapId == null || snapId.length == 0)
			return false;
		if (skillMatches(skill, snapId))
			return true;
		var want = classSignatureScriptId(snapId);
		if (want.length == 0)
			want = snapId;
		var have = classSignatureScriptId(getSkillId(skill));
		if (have.length == 0)
			have = getSkillId(skill);
		return want.length > 0 && have.length > 0 && want == have;
	}

	static function isDashSkill(skill:Dynamic, id:String):Bool {
		if (id != null && (id == "Dash_Base" || StringTools.startsWith(id, "Dash_")))
			return true;
		if (isDashMem == null)
			isDashMem = resolveMem("st.skill.BaseSkill", "isDash");
		if (callSkillBoolOpt(isDashMem, skill) == true)
			return true;
		try {
			var s:st.skill.BaseSkill = skill;
			if (s != null && s.isDash())
				return true;
		} catch (_:Dynamic) {}
		return false;
	}

	/** Equipped class-bar / dash Skill for this id. Uses the once-per-observe input snapshot. */
	static function equippedSkillByInput(hero:ent.Hero, id:String):st.skill.Skill {
		if (id == null || id.length == 0)
			return null;
		if (wepSkillMem == null)
			wepSkillMem = resolveMem("st.skill.BaseSkill", "isWeaponSkill");
		if (barInputSkills != null) {
			for (item in barInputSkills) {
				try {
					var s:st.skill.Skill = item;
					if (s == null || !skillMatches(s, id))
						continue;
					if (isSignatureId(id, s) || solarflare.PrayerCache.isPrayerId(id))
						continue;
					if (callSkillBoolOpt(wepSkillMem, s) == true && !isDashSkill(s, id))
						continue;
					return s;
				} catch (_:Dynamic) {}
			}
		}
		if (hero != null) {
			try {
				var dash:Dynamic = field(hero, "dashSkill");
				if (dash != null) {
					var typed:st.skill.Skill = dash;
					if (typed != null && skillMatches(typed, id))
						return typed;
				}
			} catch (_:Dynamic) {}
		}
		return null;
	}

	static function resolveLiveSkill(hero:ent.Hero, id:String):st.skill.Skill {
		if (hero == null || id == null || id.length == 0)
			return null;
		var fromBar = equippedSkillByInput(hero, id);
		if (fromBar != null)
			return fromBar;
		try {
			var arr = hero.weaponSkills;
			if (arr != null) {
				var n = arr.length;
				for (i in 0...n) {
					var item:Dynamic = arr.getDyn(i);
					if (item == null)
						continue;
					var s:st.skill.Skill = item;
					if (skillMatches(s, id))
						return s;
				}
			}
		} catch (_:Dynamic) {}
		try {
			var found:Dynamic = findSkillById(hero, id);
			if (found != null) {
				var typed:st.skill.Skill = found;
				return typed;
			}
		} catch (_:Dynamic) {}
		var candidates = iconIdCandidates(id, null);
		if (candidates.length == 0)
			candidates = [id];
		for (cid in candidates) {
			try {
				var over = hero.getSkillOverride(cid);
				if (over != null && skillMatches(over, id))
					return over;
			} catch (_:Dynamic) {}
		}
		var cached = cachedSkill(id);
		if (cached != null) {
			try {
				var typed:st.skill.Skill = cached;
				if (typed != null)
					return typed;
			} catch (_:Dynamic) {}
		}
		return null;
	}

	static function skillMatches(skill:st.skill.Skill, id:String):Bool {
		if (skill == null || id == null || id.length == 0)
			return false;
		var idScript = classSignatureScriptId(id);
		for (alias in skillIdAliases(skill)) {
			if (alias == id)
				return true;
			if (idScript.length > 0 && alias == idScript)
				return true;
			var aScript = classSignatureScriptId(alias);
			if (aScript.length > 0 && (aScript == id || aScript == idScript))
				return true;
		}
		return false;
	}

	/** Four bound ledger rows per emit site — this is the highest-rate caller in the mod. */
	static var cdBinds:Map<String, GeauxCdBinds> = new Map();
	static var lastCdLeftMilli:Int = -1;
	static var lastCdMaxMilli:Int = -1;
	static var affordBind = new solarflare.debug.LedgerBinding();

	static function ledgerGeauxCd(method:String, src:String, name:String, hook:String, snap:GeauxSlotSnap):Void {
		if (snap == null || !solarflare.debug.ResolutionLedger.armed())
			return;
		if (!snap.onBar)
			return;
		var L = solarflare.debug.ResolutionLedger;
		var bindKey = method + "|" + src + "|" + name + "|" + hook;
		var b = cdBinds.get(bindKey);
		if (b == null) {
			b = new GeauxCdBinds();
			b.owner = "GeauxCache." + src;
			cdBinds.set(bindKey, b);
		}
		if (L.bind(b.cdLeft, "geaux.slot.cdLeft", method, b.owner, name, "", hook)) {
			// Preview strings are only rebuilt when the rounded value actually moved.
			var milli = Math.round(snap.cdLeft * 1000);
			var prev:String = null;
			if (milli != lastCdLeftMilli) {
				lastCdLeftMilli = milli;
				prev = Std.string(milli / 1000);
			}
			L.bump(b.cdLeft, prev);
		}
		if (L.bind(b.cdMax, "geaux.slot.cdMax", method, b.owner, name, "", hook)) {
			var milli = Math.round(snap.cdMax * 1000);
			var prev:String = null;
			if (milli != lastCdMaxMilli) {
				lastCdMaxMilli = milli;
				prev = Std.string(milli / 1000);
			}
			L.bump(b.cdMax, prev);
		}
		if (L.bind(b.ready, "geaux.slot.ready", method, b.owner, name, "", hook))
			L.bump(b.ready, snap.ready ? "true" : "false");
		if (snap.id != null && snap.id.length > 0 && L.bind(b.id, "geaux.slot.id", "typed", b.owner, "id"))
			L.bump(b.id, snap.id == b.lastId ? null : (b.lastId = solarflare.debug.ResolutionLedger.clip(snap.id, 48)));
	}

	/**
	 * Freeze live charge pool onto the snap for ImGui. Ordinary single-CD skills
	 * leave chargesMax at 0 so draw skips. Prefer live max only (no CDB fake UI).
	 */
	static function applySkillCharges(snap:GeauxSlotSnap, skill:Dynamic):Void {
		if (snap == null) {
			return;
		}
		snap.charges = 0;
		snap.chargesMax = 0;
		if (skill == null)
			return;
		try {
			var typed:st.skill.Skill = cast skill;
			if (typed == null)
				return;
			// Charge capacity is static per equipped skill; only the live count is hot.
			var cachedMax = snap.chargeStaticGen == staticGen ? snap.chargesMaxStatic : -1;
			var max = cachedMax >= 0 ? cachedMax : typed.getMaxCharges();
			if (cachedMax < 0) {
				snap.chargesMaxStatic = max < 0 ? 0 : max;
				snap.chargeStaticGen = staticGen;
			}
			if (max <= 0)
				return;
			var current = typed.getCurrentCharges();
			if (current < 0)
				current = 0;
			snap.charges = current;
			snap.chargesMax = max;
			if (solarflare.debug.ResolutionLedger.armed() && snap.onBar) {
				var L = solarflare.debug.ResolutionLedger;
				var key = snap.id != null ? snap.id : "";
				L.touch("geaux.slot.charges", "typed", "GeauxCache.applySkillCharges", "getCurrentCharges", "number", Std.string(current), key);
				L.touch("geaux.slot.chargesMax", "typed", "GeauxCache.applySkillCharges", "getMaxCharges", "number", Std.string(max), key);
			}
		} catch (_:Dynamic) {}
	}

	/**
	 * Stamp bar membership once per sample. Ledger emits used to answer this with an
	 * O(count) scan several times per slot per tick.
	 */
	static function markOnBar():Void {
		if (slots == null)
			return;
		var i = 0;
		var n = slots.length;
		while (i < n) {
			if (slots[i] != null)
				slots[i].onBar = i < count;
			i++;
		}
	}

	static function applyTrackedToSnap(snap:GeauxSlotSnap):Void {
		if (snap == null || !snap.present || snap.id == null || snap.id.length == 0)
			return;
		if (solarflare.PrayerCache.isPrayerId(snap.id))
			return;
		var until = trackedUntil(snap.id);
		if (Math.isNaN(until))
			return;
		var now = nowStamp();
		var left = until - now;
		if (left <= 0.05) {
			removeTracked(snap.id);
			if (snap.cdLeft <= 0.05) {
				snap.cdLeft = 0;
				snap.remaining = 0;
				snap.ready = true;
			}
			return;
		}
		// Never raise remaining above a good live poll. Overlay when live is 0 (stub) or tracked is lower (CDR).
		if (snap.cdLeft > 0.05 && left >= snap.cdLeft - 0.02)
			return;
		snap.cdLeft = left;
		var max = cdMaxForId(snap.id);
		if (max < left)
			max = left;
		if (max < snap.cdMax)
			max = snap.cdMax;
		snap.cdMax = max;
		snap.remaining = max > 0.05 ? clamp01(left / max) : 1;
		snap.ready = false;
		ledgerGeauxCd("engine", "applyTrackedToSnap", "cdUntil", "st.skill.Skill.onTriggerCD", snap);
	}

	static function rememberCdMax(snap:GeauxSlotSnap):Void {
		if (snap == null || snap.cdMax <= 0.05 || snap.id == null)
			return;
		cdMaxById.set(snap.id, snap.cdMax);
		for (a in iconIdCandidates(snap.id, null))
			cdMaxById.set(a, snap.cdMax);
	}

	static function skillRank(skill:Dynamic):Int {
		if (skill == null)
			return 1;
		try {
			var bs:st.skill.BaseSkill = skill;
			var r = bs.get_rank();
			if (r >= 1)
				return r;
		} catch (_:Dynamic) {}
		try {
			var r = Std.int(FieldWalk.extractNumber(skill, "internalRank", 1));
			if (r >= 1)
				return r;
		} catch (_:Dynamic) {}
		return 1;
	}

	static function skillIdKeys(id:String):Array<String> {
		var out:Array<String> = [];
		if (id != null && id.length > 0)
			out.push(id);
		try {
			for (a in iconIdCandidates(id, null)) {
				if (a != null && a.length > 0)
					out.push(a);
			}
		} catch (_:Dynamic) {}
		var script = classSignatureScriptId(id);
		if (script.length > 0)
			out.push(script);
		return out;
	}

	/**
	 * Off-cooldown skills that the hero cannot afford / enable are marked unaffordable
	 * so the bar can dim them. Never clears present/ready — resource lack is dim-only.
	 * Uses cost props + Skill.isEnabled (not Hero.canUseSkill — that includes targeting).
	 */
	static function applyAffordSnap(hero:ent.Hero, snap:GeauxSlotSnap, skill:Dynamic = null):Void {
		if (snap == null) {
			return;
		}
		if (!snap.present || snap.id == null || snap.id.length == 0) {
			snap.affordable = true;
			return;
		}
		if (solarflare.PrayerCache.isPrayerId(snap.id)) {
			snap.affordable = snap.ready;
			return;
		}
		if (!snap.ready || snap.cdLeft > 0.05 || snap.remaining > 0.02) {
			snap.affordable = true;
			return;
		}
		if (solarflare.PrayerCache.isJudgementId(snap.id) || classSignatureScriptId(snap.id) == PRIEST_SIG_SCRIPT) {
			snap.affordable = solarflare.PrayerCache.anyReady();
			return;
		}
		if (snap.id == ROGUE_SIG_SCRIPT || classSignatureScriptId(snap.id) == ROGUE_SIG_SCRIPT) {
			if (ComboPointsCache.valid || ComboPointsCache.active) {
				snap.affordable = ComboPointsCache.current >= 1;
				return;
			}
		}
		if (skill == null)
			skill = cachedSkill(snap.id);
		if (skill == null && hero != null) {
			try
				skill = resolveLiveSkill(hero, snap.id)
			catch (_:Dynamic) {}
		}
		if (skill != null)
			rememberSkill(skill, snap.id);
		snap.affordable = skillAffordable(hero, skill, snap.id);
		if (solarflare.debug.ResolutionLedger.armed() && snap.onBar
			&& solarflare.debug.ResolutionLedger.bind(affordBind, "geaux.slot.affordable", "typed",
				"GeauxCache.applyAffordSnap", "ownerHaveAllCost"))
			solarflare.debug.ResolutionLedger.bump(affordBind, snap.affordable ? "true" : "false");
	}

	static function skillAffordable(hero:ent.Hero, skill:Dynamic, snapId:String):Bool {
		if (skill != null) {
			try {
				var typed:st.skill.Skill = skill;
				if (typed != null) {
					var costs:Dynamic = liveCosts(skill, typed, snapId);
					if (costs != null) {
						var n = 0;
						try
							n = untyped costs.length
						catch (_:Dynamic)
							n = arrayLen(costs);
						if (n > 0) {
							try {
								if (!typed.ownerHaveAllCost(costs))
									return false;
								if (!liveCostsAffordable(snapId, costs, n))
									return false;
								return true;
							} catch (_:Dynamic) {
								if (!liveCostsAffordable(snapId, costs, n))
									return false;
							}
						}
					}
				}
			} catch (_:Dynamic) {}
		}
		var tableCosts = GeauxCdTable.costsForAliases(iconIdCandidates(snapId, null));
		if (tableCosts != null && tableCosts.length > 0) {
			for (c in tableCosts) {
				if (!cacheHasAtb(c.atb, c.amount))
					return false;
			}
			return true;
		}
		if (skill != null) {
			try {
				var typed:st.skill.Skill = skill;
				if (typed != null && !typed.isEnabled())
					return false;
			} catch (_:Dynamic) {}
		}
		return true;
	}

	static function liveCosts(skill:Dynamic, typed:st.skill.Skill, snapId:String):Dynamic {
		var key = sanitizeSkillId(snapId);
		if (key.length > 0 && costsKnown.exists(key))
			return costsById.exists(key) ? costsById.get(key) : null;
		var costs:Dynamic = null;
		try {
			if (typed != null && typed.inf != null) {
				var props = FieldWalk.extractObject(typed.inf, "props");
				if (props != null)
					costs = FieldWalk.extractObject(props, "costs");
			}
		} catch (_:Dynamic) {}
		if (costs == null)
			costs = FieldWalk.extractPath(skill, ["inf", "props", "costs"]);
		if (key.length > 0) {
			costsKnown.set(key, true);
			if (costs != null)
				costsById.set(key, costs);
		}
		return costs;
	}

	static function liveCostsAffordable(snapId:String, costs:Dynamic, n:Int):Bool {
		var key = sanitizeSkillId(snapId);
		if (key.length == 0)
			return walkCostsAffordable(costs, n);
		var specs = costSpecsById.get(key);
		if (specs == null) {
			specs = [];
			for (i in 0...n) {
				var item:Dynamic = arrayAt(costs, i);
				if (item == null)
					continue;
				var atb = dynString(FieldWalk.extractObject(item, "atb"));
				if (atb.length == 0)
					atb = dynString(FieldWalk.extractObject(item, "attribute"));
				var amt = FieldWalk.extractNumber(item, "amount", 0);
				if (amt <= 0)
					amt = FieldWalk.extractNumber(item, "val", 0);
				if (atb.length > 0)
					specs.push({atb: atb, amount: amt});
			}
			costSpecsById.set(key, specs);
		}
		for (spec in specs) {
			if (!cacheHasAtb(spec.atb, spec.amount))
				return false;
		}
		return true;
	}

	static function walkCostsAffordable(costs:Dynamic, n:Int):Bool {
		if (costs == null || n <= 0)
			return true;
		for (i in 0...n) {
			var item:Dynamic = arrayAt(costs, i);
			if (item == null)
				continue;
			var atb = dynString(FieldWalk.extractObject(item, "atb"));
			if (atb.length == 0)
				atb = dynString(FieldWalk.extractObject(item, "attribute"));
			var amt = FieldWalk.extractNumber(item, "amount", 0);
			if (amt <= 0)
				amt = FieldWalk.extractNumber(item, "val", 0);
			if (atb.length > 0 && !cacheHasAtb(atb, amt))
				return false;
		}
		return true;
	}

	static function cacheHasAtb(atb:String, amount:Float):Bool {
		if (atb == null || atb.length == 0)
			return true;
		var a = atb.toLowerCase();
		if (a == "rage")
			return HealthCache.rage + 0.01 >= amount;
		if (a == "spark")
			return !HealthCache.sparkValid || HealthCache.spark + 0.01 >= amount;
		if (a.indexOf("mana") >= 0 || a == "mp")
			return !HealthCache.manaValid || HealthCache.mana + 0.01 >= amount;
		if (a.indexOf("combo") >= 0)
			return ComboPointsCache.current + 0.01 >= amount;
		return true;
	}

	static function trackedUntil(id:String):Float {
		if (id == null || id.length == 0)
			return Math.NaN;
		if (cdUntil.exists(id))
			return cdUntil.get(id);
		for (a in iconIdCandidates(id, null)) {
			if (a != id && cdUntil.exists(a))
				return cdUntil.get(a);
		}
		var script = classSignatureScriptId(id);
		if (script.length > 0 && script != id && cdUntil.exists(script))
			return cdUntil.get(script);
		return Math.NaN;
	}

	static function cdMaxForId(id:String):Float {
		if (id != null && cdMaxById.exists(id))
			return cdMaxById.get(id);
		for (a in iconIdCandidates(id, null)) {
			if (cdMaxById.exists(a))
				return cdMaxById.get(a);
		}
		return 0;
	}

	static function clearLastUse(id:String):Void {
		if (id == null || id.length == 0)
			return;
		lastUseAt.remove(id);
		for (a in iconIdCandidates(id, null))
			lastUseAt.remove(a);
		var script = classSignatureScriptId(id);
		if (script.length > 0)
			lastUseAt.remove(script);
	}

	static function removeTracked(id:String):Void {
		if (id == null || id.length == 0)
			return;
		cdUntil.remove(id);
		clearLastUse(id);
		for (a in iconIdCandidates(id, null))
			cdUntil.remove(a);
		var script = classSignatureScriptId(id);
		if (script.length > 0)
			cdUntil.remove(script);
	}

	static function trackedLeft(id:String):Float {
		var until = trackedUntil(id);
		if (Math.isNaN(until))
			return 0;
		var left = until - nowStamp();
		return left > 0 ? left : 0;
	}

	static function typedLeftCd(skill:Dynamic, max:Float):Float {
		try {
			var typed:st.skill.Skill = skill;
			if (typed == null)
				return Math.NaN;
			return scaleCdLeft(typed.getCooldownLeft(), max);
		} catch (_:Dynamic) {}
		return Math.NaN;
	}

	static function typedMaxCd(skill:Dynamic):Float {
		try {
			var typed:st.skill.Skill = skill;
			if (typed == null)
				return 0;
			var max = typed.getEffectiveCooldown();
			if (max <= 0)
				max = typed.getCooldown();
			if (max <= 0)
				max = typed.cooldownDuration;
			max = normalizeSeconds(max, 0);
			if (max <= 0) {
				try {
					max = GeauxCdTable.resolveMax("", skillIdAliases(skill), skillRank(skill), max);
					if (max > 0 && solarflare.debug.ResolutionLedger.armed())
						solarflare.debug.ResolutionLedger.note("geaux.slot.cdMaxCdb")
							.withMethod("cdb")
							.withSrc("GeauxCache.typedMaxCd")
							.withName("GeauxCdTable.resolveMax")
							.num(max)
							.emit();
				} catch (_:Dynamic) {}
			}
			return max;
		} catch (_:Dynamic) {}
		return 0;
	}

	static function typedProgress(skill:Dynamic):Float {
		try {
			var typed:st.skill.Skill = skill;
			if (typed == null)
				return Math.NaN;
			return typed.getCooldownProgress();
		} catch (_:Dynamic) {}
		return Math.NaN;
	}

	static function gameNow():Float {
		try {
			var t = hxd.Timer.lastTimeStamp;
			if (t > 0)
				return t;
		} catch (_:Dynamic) {}
		try {
			var t = hxd.Timer.elapsedTime;
			if (t > 0)
				return t;
		} catch (_:Dynamic) {}
		return 0;
	}

	static function readMaxCd(skill:Dynamic):Float {
		var max = callNamedFloat(skill, "getEffectiveCooldown", cdEffMem);
		if (Math.isNaN(max) || max <= 0)
			max = callNamedFloat(skill, "getCooldown", cdMem);
		if (Math.isNaN(max) || max <= 0)
			max = readMaxCdField(skill);
		max = normalizeSeconds(max, 0);
		if (max <= 0) {
			try {
				var id = parseSkillish(skill).id;
				max = GeauxCdTable.resolveMax(id, skillIdAliases(skill), skillRank(skill), max);
			} catch (_:Dynamic) {}
		}
		return max;
	}

	static function readMaxCdField(skill:Dynamic):Float {
		if (cdMaxFieldWin.length > 0) {
			var cached = maxCdFromWin(skill, cdMaxFieldWin);
			if (cached > 0)
				return cached;
			cdMaxFieldWin = "";
		}
		var v = FieldWalk.extractNumber(skill, "cooldownDuration", 0);
		if (v > 0) {
			cdMaxFieldWin = "cooldownDuration";
			return v;
		}
		v = FieldWalk.extractNumber(field(skill, "inf"), "cooldown", 0);
		if (v > 0) {
			cdMaxFieldWin = "inf.cooldown";
			return v;
		}
		v = FieldWalk.extractNumber(field(field(skill, "inf"), "vars"), "cooldown", 0);
		if (v > 0) {
			cdMaxFieldWin = "inf.vars.cooldown";
			return v;
		}
		return 0;
	}

	static function maxCdFromWin(skill:Dynamic, win:String):Float {
		if (win == "cooldownDuration")
			return FieldWalk.extractNumber(skill, "cooldownDuration", 0);
		if (win == "inf.cooldown")
			return FieldWalk.extractNumber(field(skill, "inf"), "cooldown", 0);
		if (win == "inf.vars.cooldown")
			return FieldWalk.extractNumber(field(field(skill, "inf"), "vars"), "cooldown", 0);
		return 0;
	}

	static function readLeftCd(skill:Dynamic, hero:Dynamic, id:String, max:Float):Float {
		return scaleCdLeft(callNamedFloat(skill, "getCooldownLeft", cdLeftMem), max);
	}

	static function lastUseTime(hero:Dynamic, id:String):Float {
		if (id != null && lastUseAt.exists(id))
			return lastUseAt.get(id);
		try {
			var map = field(hero, "skillLastUse");
			if (map != null) {
				var v:Dynamic = FieldWalk.mapGet(map, id);
				if (v != null)
					return (v : Float);
			}
		} catch (_:Dynamic) {}
		try {
			var map = field(hero, "skillLastUse");
			var v:Dynamic = untyped map.get(id);
			if (v != null)
				return (v : Float);
		} catch (_:Dynamic) {}
		return 0;
	}

	static function nowStamp():Float {
		var t = gameNow();
		if (t > 0)
			return t;
		return Date.now().getTime() / 1000.0;
	}

	static function normalizeSeconds(v:Float, max:Float):Float {
		if (Math.isNaN(v) || v < 0)
			return Math.NaN;
		if (v > 200 && (max <= 0 || max > 200 || v > max * 20))
			return v / 1000.0;
		return v;
	}

	static function clamp01(v:Float):Float {
		if (v < 0)
			return 0;
		if (v > 1)
			return 1;
		return v;
	}

	static function callNamedFloat(obj:Dynamic, name:String, mem:ResolvedMember):Float {
		if (obj == null)
			return Math.NaN;
		if (mem != null) {
			try {
				var v:Dynamic = HlxRuntime.callResolved(mem, [obj]);
				if (v != null) {
					var f:Float = v;
					if (!Math.isNaN(f))
						return f;
				}
			} catch (_:Dynamic) {}
		}
		try {
			if (name == "getCooldownLeft") {
				var v:Float = untyped obj.getCooldownLeft();
				return v;
			}
			if (name == "getEffectiveCooldown") {
				var v:Float = untyped obj.getEffectiveCooldown();
				return v;
			}
			if (name == "getCooldown") {
				var v:Float = untyped obj.getCooldown();
				return v;
			}
			if (name == "getCooldownProgress") {
				var v:Float = untyped obj.getCooldownProgress();
				return v;
			}
		} catch (_:Dynamic) {}
		return Math.NaN;
	}

	static function labelOf(skill:Dynamic, id:String):String {
		var shown = solarflare.EngineSkillId.ofSkill(skill);
		if (shown.length > 0 && isCleanLabel(shown))
			return shown;
		var clean = sanitizeSkillId(id);
		var disp = solarflare.EngineSkillId.display(clean.length > 0 ? clean : id);
		if (disp.length > 0 && isCleanLabel(disp))
			return disp;
		return isCleanLabel(clean) ? clean : "";
	}

	/** Confirmed engine id for UI (never `{bytes…}` dumps or menu names). */
	public static function shortLabel(id:String):String {
		return solarflare.EngineSkillId.display(sanitizeSkillId(id));
	}

	static function isCleanLabel(s:String):Bool {
		if (s == null || s.length == 0)
			return false;
		if (s.indexOf("{") >= 0 || s.indexOf("}") >= 0)
			return false;
		var low = s.toLowerCase();
		if (low.indexOf("bytes") >= 0)
			return false;
		if (low.indexOf("haxe.io") >= 0)
			return false;
		return true;
	}

	static function shortFromId(id:String):String {
		id = sanitizeSkillId(id);
		if (id.length == 0)
			return "";
		if (!isUsableSkillId(id))
			return "";
		var s = id;
		var us = s.lastIndexOf("_");
		if (us >= 0 && us < s.length - 1)
			s = s.substr(us + 1);
		if (s.length > 10)
			s = s.substr(0, 10);
		if (!isCleanLabel(s))
			return "";
		return s;
	}

	static function dynString(v:Dynamic):String {
		if (v == null)
			return "";
		var fromBytes = bytesAsCleanString(v);
		if (fromBytes.length > 0 && isCleanLabel(fromBytes))
			return fromBytes;
		try {
			if (Std.isOfType(v, String)) {
				var s:String = v;
				if (!isCleanLabel(s))
					return "";
				return s;
			}
		} catch (_:Dynamic) {}
		// Never Std.string(v) — Bytes / objects become "{bytes :…}".
		return "";
	}

	static function field(obj:Dynamic, name:String):Dynamic {
		if (obj == null || name == null)
			return null;
		return FieldWalk.extractObject(obj, name);
	}

	static function arrayLen(arr:Dynamic):Int {
		return FieldWalk.arrayLen(arr);
	}

	static function arrayAt(arr:Dynamic, i:Int):Dynamic {
		return FieldWalk.arrayAt(arr, i);
	}
}
