package solarflare.aura;

import solarflare.ui.HudChrome;
import solarflare.ui.ByteUtil;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import solarflare.aura.signal.AuraRuleDef;
import solarflare.aura.signal.AuraRuleResult;
import solarflare.aura.signal.AuraConditionUiState;

class AuraDef {
	public var id:String;
	public var name:String;
	public var enabled:BoolRef;
	public var trigger:String;
	public var skillId:String;
	public var resource:String;
	public var op:String;
	public var pct:Float;
	public var duration:Float;
	public var region:String;
	public var iconId:String;
	public var invert:BoolRef;
	public var requireAfford:BoolRef;
	public var w:FloatRef;
	public var h:FloatRef;
	public var sizeDirty:Bool;
	public var chrome:HudChrome;

	/** Alert-style: invisible until rising-edge, hold for duration, then dormant again. */
	public var dormant:BoolRef;
	/** Keep presentation visible while triggers continue to count normally. */
	public var alwaysOn = new BoolRef(false);
	/** DRM-parity toggles (visual used live; audio/cue/volume stored for DRM export). */
	public var visual:BoolRef;
	public var audio:BoolRef;
	public var cue:String;
	public var plate:String;
	public var announce:String;
	public var fight:String;
	public var volume:FloatRef;
	/** SolarFlare visual alpha. DRM sound volume remains in `volume`. */
	public var opacity:FloatRef;
	public var scale:FloatRef;
	public var showIcon:BoolRef;
	public var progressRing:BoolRef;
	/** Integer seconds (or ∞) overlaid on the icon. */
	public var showCountdown:BoolRef;
	/** Countdown text size multiplier vs. the auto-fit base. */
	public var countdownScale:FloatRef;
	/** 0 = center, 1 = above the face, 2 = below the face. */
	public var countdownPlace:Int;
	/** Vertical fuse bar that drains with remaining time. */
	public var showFuse:BoolRef;
	/** Draw fuse as a bottom strip instead of the right-edge bar (canvas / icon). */
	public var fuseBottom:BoolRef;
	/** Prefer live status duration when known; else fixed Display Duration hold. */
	public var followBuffDuration:BoolRef;
	/** Freeform canvas placements when region == "canvas". */
	public var canvasElements:Array<AuraCanvasElement>;
	/** Packed 0xAARRGGBB glow accent (used when iconGlow is active). */
	public var glowColor:Int;
	public var stackCounter:BoolRef;
	/** Stack / activation count text size multiplier vs. the auto-fit base. */
	public var stackScale:FloatRef;
	/** Same placement contract as countdownPlace: 0 = center, 1 = above, 2 = below. */
	public var stackPlace:Int;
	public var showLabel:BoolRef;
	public var isCounter:BoolRef;
	public var counterValue:Int;
	/** Optional Geaux-style key chip drawn on the aura (user text, not engine-bound). */
	public var keyText:String;
	public var showKey:BoolRef;
	/** Preview / live visual FX overlays (Pulse, Expire, Ready). */
	public var fxPulse:BoolRef;
	public var fxExpire:BoolRef;
	public var fxReady:BoolRef;
	/** Optional DBM-style plain text overlay (in addition to announce/label). */
	public var bannerText:String;
	public var bannerBuf:hl.Bytes;
	public var bannerScale:FloatRef;
	public var showBanner:BoolRef;
	public static inline var BANNER_BUF:Int = 160;
	/** Pack combiner checkbox (session UI only — not persisted). */
	public var packSelect:BoolRef;
	/** Presentation / lifecycle effects (window, alert, icon, audio). */
	public var effects:Array<AuraEffect>;
	/** Optional declarative condition group. Null selects the unchanged legacy trigger path. */
	public var rule:Null<AuraRuleDef>;
	/** Frozen, reusable runtime result; never serialized. */
	public var ruleResult:AuraRuleResult;
	public var conditionUi:Array<AuraConditionUiState>;

	/** 0 = off, 1 = count down, 2 = count up. */
	public var timerMode:Int;
	/** 0 = follow the condition's remaining time, 1 = fixed timerSeconds. */
	public var timerSource:Int;
	public var timerSeconds:FloatRef;
	/** Show this timer in the shared AuraTimerBoard window. */
	public var timerBoard:BoolRef;
	/** Seconds the finished timer lingers at 0 before it is dropped. */
	public var timerKeepExpired:FloatRef;

	public var timerActive:Bool;
	/** Seconds remaining (count down) or elapsed (count up). */
	public var timerValue:Float;
	public var timerTotal:Float;
	public var timerStartedAt:Float;
	public var timerEndsAt:Float;
	public var timerExpiredAt:Float;

	public var show:Bool;
	public var until:Float;
	public var progress:Float;
	/** Seconds left for countdown draw; SkillRemain.INFINITE_LEFT when infinite. */
	public var timeLeft:Float;
	public var timerInfinite:Bool;
	public var stacks:Int;
	public var resolvedIcon:String;
	public var lastHitAt:Float;
	/** Rising-edge memory for dormant / effect modes. */
	public var condWas:Bool;
	/** Alert channel from effects (drawn by AuraOverlay). */
	public var alertShow:Bool;
	public var alertText:String;
	public var iconGlow:Bool;
	public var fxAlpha:Float;
	public var skillBuf:hl.Bytes;
	public var nameBuf:hl.Bytes;
	public var iconBuf:hl.Bytes;
	public var cueBuf:hl.Bytes;
	public var plateBuf:hl.Bytes;
	public var announceBuf:hl.Bytes;
	public var fightBuf:hl.Bytes;
	public var keyBuf:hl.Bytes;
	public var pctRef:FloatRef;
	public var durRef:FloatRef;
	public static inline var SKILL_BUF:Int = 160;
	public static inline var NAME_BUF:Int = 80;
	public static inline var ICON_BUF:Int = 160;
	public static inline var CUE_BUF:Int = 48;
	public static inline var PLATE_BUF:Int = 80;
	public static inline var ANN_BUF:Int = 120;
	public static inline var FIGHT_BUF:Int = 32;
	public static inline var KEY_BUF:Int = 16;

	public function new(id:String, name:String) {
		this.id = id;
		this.name = name;
		enabled = new BoolRef(true);
		trigger = "resource";
		skillId = "";
		resource = "hp";
		op = "below";
		pct = 35;
		duration = 3;
		region = "bar";
		iconId = "";
		invert = new BoolRef(false);
		requireAfford = new BoolRef(true);
		dormant = new BoolRef(false);
		visual = new BoolRef(true);
		audio = new BoolRef(false);
		cue = "";
		plate = "";
		announce = "";
		fight = "";
		keyText = "";
		showKey = new BoolRef(true);
		fxPulse = new BoolRef(false);
		fxExpire = new BoolRef(false);
		fxReady = new BoolRef(false);
		bannerText = "";
		bannerScale = new FloatRef(1.15);
		showBanner = new BoolRef(false);
		showIcon = new BoolRef(true);
		progressRing = new BoolRef(false);
		showCountdown = new BoolRef(false);
		countdownScale = new FloatRef(1);
		countdownPlace = 2;
		showFuse = new BoolRef(false);
		fuseBottom = new BoolRef(false);
		followBuffDuration = new BoolRef(true);
		canvasElements = [];
		glowColor = 0xFFFF8800;
		stackCounter = new BoolRef(false);
		stackScale = new FloatRef(1);
		stackPlace = 2;
		showLabel = new BoolRef(false);
		isCounter = new BoolRef(false);
		counterValue = 0;
		effects = [AuraEffect.defaultWindow()];
		rule = null;
		ruleResult = new AuraRuleResult();
		conditionUi = [];
		for (_ in 0...AuraRuleDef.MAX_CONDITIONS) conditionUi.push(new AuraConditionUiState());
		w = new FloatRef(96);
		h = new FloatRef(96);
		volume = new FloatRef(1);
		opacity = new FloatRef(1);
		scale = new FloatRef(1);
		pctRef = new FloatRef(35);
		durRef = new FloatRef(3);
		sizeDirty = true;
		chrome = new HudChrome(200, 200);
		show = false;
		until = 0;
		progress = 0;
		timeLeft = Math.NaN;
		timerInfinite = false;
		timerMode = 0;
		timerSource = 0;
		timerSeconds = new FloatRef(60);
		timerBoard = new BoolRef(true);
		timerKeepExpired = new FloatRef(3);
		timerActive = false;
		timerValue = 0;
		timerTotal = 0;
		timerStartedAt = 0;
		timerEndsAt = 0;
		timerExpiredAt = 0;
		stacks = 1;
		resolvedIcon = "";
		lastHitAt = 0;
		condWas = false;
		alertShow = false;
		alertText = "";
		iconGlow = false;
		fxAlpha = 1;
		skillBuf = new hl.Bytes(SKILL_BUF);
		nameBuf = new hl.Bytes(NAME_BUF);
		iconBuf = new hl.Bytes(ICON_BUF);
		cueBuf = new hl.Bytes(CUE_BUF);
		plateBuf = new hl.Bytes(PLATE_BUF);
		announceBuf = new hl.Bytes(ANN_BUF);
		fightBuf = new hl.Bytes(FIGHT_BUF);
		keyBuf = new hl.Bytes(KEY_BUF);
		bannerBuf = new hl.Bytes(BANNER_BUF);
		syncSkillBuf();
		syncNameBuf();
		syncIconBuf();
		syncCueBuf();
		syncPlateBuf();
		syncAnnounceBuf();
		syncFightBuf();
		syncKeyBuf();
		syncBannerBuf();
	}

	public function syncBannerBuf():Void {
		fillBuf(bannerBuf, BANNER_BUF, bannerText);
	}

	public function syncSkillBuf():Void {
		fillBuf(skillBuf, SKILL_BUF, skillId);
	}

	public function syncNameBuf():Void {
		fillBuf(nameBuf, NAME_BUF, name);
	}

	public function syncIconBuf():Void {
		fillBuf(iconBuf, ICON_BUF, iconId);
	}

	public function syncCueBuf():Void {
		fillBuf(cueBuf, CUE_BUF, cue);
	}

	public function syncPlateBuf():Void {
		fillBuf(plateBuf, PLATE_BUF, plate);
	}

	public function syncAnnounceBuf():Void {
		fillBuf(announceBuf, ANN_BUF, announce);
	}

	public function syncFightBuf():Void {
		fillBuf(fightBuf, FIGHT_BUF, fight);
	}

	public function syncKeyBuf():Void {
		fillBuf(keyBuf, KEY_BUF, keyText);
	}

	/** Short key chip text (same rules as Geaux slot keys). */
	public static function sanitizeKey(v:Dynamic):String {
		if (v == null)
			return "";
		var s = Std.string(v);
		if (s.length == 0)
			return "";
		s = StringTools.trim(s);
		if (s.toLowerCase().indexOf("bytes") >= 0 || s.indexOf("{") >= 0)
			return "";
		if (s.length > 8)
			s = s.substr(0, 8);
		return s;
	}

	public function displayLabel():String {
		if (announce != null && announce.length > 0)
			return announce;
		if (name != null && name.length > 0)
			return name;
		return id;
	}

	public function plateOrIcon():String {
		return preferredIconId();
	}

	/**
	 * Raw CastleDB id for timing lookups — the explicit skill, else the presentation
	 * condition's subject. Unlike preferredIconId this never maps to a gfx stem, since
	 * the timing tables are keyed by record id.
	 */
	public function timingSubjectId():String {
		if (skillId != null && skillId.length > 0)
			return skillId;
		if (rule != null && rule.conditions != null && rule.conditions.length > 0) {
			var pi = rule.presentationSource;
			if (pi < 0 || pi >= rule.conditions.length)
				pi = 0;
			var c = rule.conditions[pi];
			if (c != null && c.subject != null && c.subject.length > 0)
				return c.subject;
		}
		return "";
	}

	/**
	 * Canonical presentation icon with automatic declarative-rule fallback.
	 *
	 * A skill id is only a usable icon key when that skill owns an atlas frame, so a
	 * candidate without art must not end the chain — otherwise the aura renders "?"
	 * while a plausible-looking id sits in Custom Icon ID. Keeps the original priority
	 * and degrades to the first candidate when nothing in the chain has art.
	 * Runs per-frame from AuraVisualRenderer: no allocation here.
	 */
	public function preferredIconId():String {
		var fallback = "";
		var key = iconKeyFor(iconId);
		if (key.length > 0) {
			if (solarflare.ui.GameIcons.hasKey(key)) return key;
			fallback = key;
		}
		if (rule != null && rule.conditions != null && rule.conditions.length > 0) {
			var pi = rule.presentationSource;
			if (pi < 0 || pi >= rule.conditions.length)
				pi = 0;
			var c = rule.conditions[pi];
			if (c != null) {
				key = iconKeyFor(c.subject);
				if (key.length > 0) {
					if (solarflare.ui.GameIcons.hasKey(key)) return key;
					if (fallback.length == 0) fallback = key;
				}
			}
		}
		key = iconKeyFor(resolvedIcon);
		if (key.length > 0) {
			if (solarflare.ui.GameIcons.hasKey(key)) return key;
			if (fallback.length == 0) fallback = key;
		}
		key = iconKeyFor(skillId);
		if (key.length > 0) {
			if (solarflare.ui.GameIcons.hasKey(key)) return key;
			if (fallback.length == 0) fallback = key;
		}
		key = iconKeyFor(plate);
		if (key.length > 0) {
			if (solarflare.ui.GameIcons.hasKey(key)) return key;
			if (fallback.length == 0) fallback = key;
		}
		var grant = solarflare.cdb.CdbAuraTable.grantedStatusId(timingSubjectId());
		key = iconKeyFor(grant);
		if (key.length > 0) {
			if (solarflare.ui.GameIcons.hasKey(key)) return key;
			if (fallback.length == 0) fallback = key;
		}
		return fallback;
	}

	static inline function iconKeyFor(id:String):String {
		if (id == null || id.length == 0)
			return "";
		var stem = solarflare.cdb.CdbAuraTable.iconStem(id);
		return stem.length > 0 ? stem : id;
	}

	static function fillBuf(buf:hl.Bytes, cap:Int, s:String):Void ByteUtil.fillBuf(buf, cap, s);
}
