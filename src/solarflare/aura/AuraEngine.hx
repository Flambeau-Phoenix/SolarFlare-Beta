package solarflare.aura;

import solarflare.EngineSkillId;
import solarflare.HealthCache;
import solarflare.cdb.CdbAuraTable;
import solarflare.chaincast.Chaincast;
import solarflare.combo.Combo;
import solarflare.combatlog.CombatLogCache;
import solarflare.combatlog.CombatLogLine;
import solarflare.conduit.Conduit;
import solarflare.geaux.GeauxCache;
import sys.FileSystem;
import sys.io.File;
import solarflare.aura.signal.AuraRuleCodec;
import solarflare.aura.signal.AuraRuleEvaluator;
import solarflare.aura.signal.AuraSignalFrame;
import solarflare.aura.signal.AuraSignalFrameBuilder;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;

class AuraEngine {
	public static inline var MAX:Int = 32;
	static inline var STATUS_HOLD:Float = 0.18;
	static var frame:AuraSignalFrame;

	/** Explicit runtime initialization; called by AuraConfig construction. */
	public static function initialize():Void {
		if (frame == null)
			frame = new AuraSignalFrame();
	}

	/** Last frozen signal frame for read-only builder pickers/value display. */
	public static function signalFrame():AuraSignalFrame return frame;

	public static function tick(cfg:AuraConfig):Void {
		if (cfg == null || cfg.auras == null)
			return;
		if (!cfg.enabled.get() && !solarflare.ObserveDemand.auraBuilderOpen) {
			clearAllPresentation(cfg);
			return;
		}
		var now = stamp();
		var hot = frame != null && frame.statusCount > 0;
		if (!AuraStatusCache.isCurrent(HealthCache.localHero) || solarflare.ObserveDemand.dueAuraStatus(now, hot)) {
			try
				AuraStatusCache.sample(HealthCache.localHero)
			catch (_:Dynamic) {}
		}
		initialize();
		if (solarflare.ObserveDemand.aurasNeedEnemyCast)
			EnemyCastCache.tick(now);
		AuraSignalFrameBuilder.build(frame, now);
		if (!cfg.enabled.get()) {
			clearAllPresentation(cfg);
			return;
		}
		var n = cfg.auras.length;
		if (n > MAX)
			n = MAX;
		var i = 0;
		while (i < n) {
			try
				eval(cfg.auras[i], now)
			catch (_:Dynamic) {
				var a = cfg.auras[i];
				if (a != null)
					AuraEffects.clearPresentation(a);
			}
			i++;
		}
	}

	static function clearAllPresentation(cfg:AuraConfig):Void {
		if (cfg == null || cfg.auras == null)
			return;
		var i = 0;
		var n = cfg.auras.length;
		if (n > MAX)
			n = MAX;
		while (i < n) {
			AuraEffects.clearPresentation(cfg.auras[i]);
			i++;
		}
	}

	static function eval(a:AuraDef, now:Float):Void {
		if (a == null || !a.enabled.get()) {
			if (a != null)
				AuraEffects.clearPresentation(a);
			return;
		}
		a.resolvedIcon = "";
		if (a.rule != null) {
			evalDeclarative(a, now);
			return;
		}
		var hit = false;
		var known = false;
		var prog:Float = 1;
		var stacks = 1;
		var t = a.trigger;
		if (t == "resource") {
			var rr = resourceRatio(a.resource);
			known = rr.ok;
			if (known) {
				hit = a.op == "above" ? rr.r >= a.pct / 100.0 : rr.r <= a.pct / 100.0;
				prog = rr.r;
			}
		} else if (t == "prayer") {
			known = PrayerCache.active;
			if (known)
				hit = prayerReady(a.skillId);
			prog = hit ? 1 : 0;
		} else if (t == "cooldown") {
			var cd = cooldownState(a, now);
			known = cd.ok;
			if (known) {
				hit = cd.ready;
				prog = cd.progress;
				if (a.resolvedIcon.length == 0 && cd.icon.length > 0)
					a.resolvedIcon = cd.icon;
			}
		} else if (t == "status") {
			var st = AuraStatusCache.find(a.skillId);
			var hold = catalogHold(a, STATUS_HOLD);
			if (st != null) {
				known = true;
				hit = statusStackHit(a, st.stacks);
				prog = statusProgress(a, st);
				stacks = st.stacks;
				if (hit && !a.dormant.get()) {
					a.lastHitAt = now;
					a.until = now + hold;
				}
				if (st.id.length > 0)
					a.resolvedIcon = st.id;
			} else if (!a.dormant.get() && now < a.until) {
				known = true;
				hit = true;
				prog = hold > 0.05 ? clamp01((a.until - now) / hold) : a.progress;
				stacks = a.stacks;
			} else
				known = HealthCache.localHero != null;
		} else if (t == "combatlog") {
			var hold = logHold(a, now);
			known = true;
			hit = hold.hit;
			prog = hold.progress;
		} else if (t == "combo") {
			known = ComboPointsCache.valid;
			if (known) {
				var need = Std.int(a.pct);
				if (need < 1)
					need = ComboPointsCache.max;
				hit = ComboPointsCache.current >= need;
				prog = ComboPointsCache.max > 0 ? ComboPointsCache.current / ComboPointsCache.max : 0;
				stacks = ComboPointsCache.current;
			}
		} else if (t == "chaincast") {
			known = ChaincastCache.valid || ChaincastCache.active;
			if (ChaincastCache.valid) {
				var wantReady = a.skillId != null && a.skillId.toLowerCase().indexOf("ready") >= 0;
				if (wantReady)
					hit = ChaincastCache.ready;
				else {
					var need = Std.int(a.pct);
					if (need < 1)
						need = ChaincastCache.max;
					hit = ChaincastCache.ready || ChaincastCache.current >= need;
				}
				prog = ChaincastCache.ready ? 1 : (ChaincastCache.max > 0 ? ChaincastCache.current / ChaincastCache.max : 0);
				stacks = ChaincastCache.ready ? ChaincastCache.max : ChaincastCache.current;
			}
		} else if (t == "conduit") {
			known = ConduitCache.valid || ConduitCache.active;
			if (ConduitCache.valid) {
				var need = Std.int(a.pct);
				if (need < 1)
					need = 1;
				var stacksNow = ConduitCache.powerStacks > 0 ? ConduitCache.powerStacks : ConduitCache.filledCount;
				hit = stacksNow >= need || (need == 1 && ConduitCache.filledCount > 0);
				if (ConduitCache.powerStacks > 0)
					prog = ConduitCache.powerStacks / ConduitCache.POWER_MAX;
				else if (ConduitCache.slotCount > 0)
					prog = ConduitCache.filledCount / ConduitCache.slotCount;
				else
					prog = 0;
				stacks = stacksNow;
			}
		} else if (t == "script" || t == "custom") {
			known = true;
			hit = solarflare.scripting.ScriptEngine.evalBool(a.skillId, frame);
			prog = hit ? 1.0 : 0.0;
		}
		if (!known)
			hit = false;
		if (a.invert.get())
			hit = known && !hit;
		AuraEffects.apply(a, hit, known, now, prog);
		a.stacks = stacks < 1 ? 1 : stacks;
		if (a.resolvedIcon.length == 0) {
			if (a.iconId != null && a.iconId.length > 0)
				a.resolvedIcon = a.iconId;
			else if (a.plate != null && a.plate.length > 0)
				a.resolvedIcon = a.plate;
			else if (a.skillId != null && a.skillId.length > 0)
				a.resolvedIcon = a.skillId;
		}
	}

	static function evalDeclarative(a:AuraDef, now:Float):Void {
		AuraRuleEvaluator.evaluate(a.rule, frame, a.ruleResult);
		var hit = a.ruleResult.hit;
		var known = a.ruleResult.known;
		var prog = a.ruleResult.progress;
		if (!Math.isFinite(prog)) prog = hit ? 1 : 0;
		var stacks = a.ruleResult.stacks;
		if (stacks < 1) stacks = 1;
		AuraEffects.apply(a, hit, known, now, prog);
		a.stacks = stacks;
		if (a.iconId != null && a.iconId.length > 0) {
			a.resolvedIcon = a.iconId;
		} else if (a.rule.conditions != null && a.rule.conditions.length > 0) {
			var pi = a.rule.presentationSource;
			if (pi < 0 || pi >= a.rule.conditions.length) pi = 0;
			var c = a.rule.conditions[pi];
			if (c != null && c.subject != null && c.subject.length > 0) a.resolvedIcon = c.subject;
		}
		resolveIconFallback(a);
	}

	static function resolveIconFallback(a:AuraDef):Void {
		if (a.resolvedIcon.length > 0) return;
		if (a.iconId != null && a.iconId.length > 0) a.resolvedIcon = a.iconId;
		else if (a.plate != null && a.plate.length > 0) a.resolvedIcon = a.plate;
		else if (a.skillId != null && a.skillId.length > 0) a.resolvedIcon = a.skillId;
	}

	/**
	 * Continuous / dormant visibility is handled by AuraEffects (legacy applyVisibility kept
	 * only for reference during migration — call site uses AuraEffects.apply).
	 */
	static function applyVisibility(a:AuraDef, hit:Bool, known:Bool, now:Float, prog:Float):Void {
		AuraEffects.apply(a, hit, known, now, prog);
	}

	static function resourceRatio(which:String):{ok:Bool, r:Float} {
		if (which == "rage")
			return {ok: HealthCache.rageValid, r: HealthCache.rageRatio()};
		if (which == "spark")
			return {ok: HealthCache.sparkValid, r: HealthCache.sparkRatio()};
		if (which == "mana")
			return {ok: HealthCache.manaValid, r: HealthCache.manaRatio()};
		if (which == "shield") {
			if (!HealthCache.valid)
				return {ok: false, r: 0};
			var cap = HealthCache.max > 0 ? HealthCache.max : 1;
			return {ok: true, r: clamp01(HealthCache.shield / cap)};
		}
		return {ok: HealthCache.valid, r: HealthCache.ratio()};
	}

	static function prayerReady(id:String):Bool {
		if (!PrayerCache.active)
			return false;
		if (id == null || StringTools.trim(id).length == 0)
			return PrayerCache.anyReady();
		var k = PrayerCache.prayerKind(id);
		if (k == "life")
			return PrayerCache.lifeReady;
		if (k == "shield")
			return PrayerCache.shieldReady;
		if (k == "smite")
			return PrayerCache.smiteReady;
		if (PrayerCache.isPrayerId(id))
			return PrayerCache.prayerReady(id);
		var s = id.toLowerCase();
		if (s == "any" || s == "prayer")
			return PrayerCache.anyReady();
		return false;
	}

	static function cooldownState(a:AuraDef, now:Float):{ok:Bool, ready:Bool, progress:Float, icon:String} {
		var snap = GeauxCache.findSnap(a.skillId);
		if (snap != null) {
			var ready = snap.ready;
			if (a.requireAfford.get() && ready && !snap.affordable)
				ready = false;
			var prog = ready ? 1.0 : snap.remaining;
			var icon = snap.iconId.length > 0 ? snap.iconId : snap.id;
			return {ok: true, ready: ready, progress: clamp01(prog), icon: icon};
		}
		var until = trackedUntil(a.skillId);
		if (!Math.isNaN(until)) {
			var left = until - now;
			var max = 0.0;
			if (a.skillId != null && GeauxCache.cdMaxById.exists(a.skillId))
				max = GeauxCache.cdMaxById.get(a.skillId);
			if (max < 0.05)
				max = CdbAuraTable.cooldown(a.skillId);
			if (max < 0.05)
				max = solarflare.geaux.GeauxCdTable.baseFor(a.skillId);
			if (left > 0.05) {
				var rem = max > 0.05 ? clamp01(left / max) : 1;
				return {ok: true, ready: false, progress: rem, icon: a.skillId};
			}
			return {ok: true, ready: true, progress: 1, icon: a.skillId};
		}
		return {ok: false, ready: false, progress: 0, icon: ""};
	}

	static function trackedUntil(id:String):Float {
		if (id == null || id.length == 0)
			return Math.NaN;
		if (GeauxCache.cdUntil.exists(id))
			return GeauxCache.cdUntil.get(id);
		var shown = EngineSkillId.display(id);
		if (shown.length > 0 && shown != id && GeauxCache.cdUntil.exists(shown))
			return GeauxCache.cdUntil.get(shown);
		return Math.NaN;
	}

	static function logHold(a:AuraDef, now:Float):{hit:Bool, progress:Float} {
		var want = a.skillId != null ? StringTools.trim(a.skillId) : "";
		if (want.length < 2)
			return {hit: false, progress: 0};
		var hold = catalogHold(a, 3);
		var lines = CombatLogCache.recentAll();
		var bestT = -1.0;
		var i = lines.length - 1;
		while (i >= 0) {
			var line:CombatLogLine = lines[i];
			if (line != null && line.t + hold >= now && logLineMatch(want, line)) {
				if (line.t > bestT)
					bestT = line.t;
			}
			i--;
		}
		if (bestT < 0)
			return {hit: false, progress: 0};
		var left = (bestT + hold) - now;
		if (left < 0)
			left = 0;
		return {hit: true, progress: hold > 0.05 ? clamp01(left / hold) : 1};
	}

	static function logLineMatch(want:String, line:CombatLogLine):Bool {
		if (line.sourceRole != CombatLogCache.ROLE_YOU && line.targetRole != CombatLogCache.ROLE_YOU)
			return false;
		if (idEq(want, line.skillId) || idEq(want, line.skillLabel) || idEq(want, line.skillName))
			return true;
		var w = want.toLowerCase();
		if (w.length < 3)
			return false;
		return contains(line.skillId, w) || contains(line.skillLabel, w) || contains(line.skillName, w);
	}

	static function idEq(want:String, have:String):Bool {
		if (want == null || have == null || have.length == 0)
			return false;
		var w = want.toLowerCase();
		var h = have.toLowerCase();
		if (w == h)
			return true;
		var wd = EngineSkillId.display(want).toLowerCase();
		var hd = EngineSkillId.display(have).toLowerCase();
		if (wd.length > 0 && hd.length > 0 && wd == hd)
			return true;
		if (wd.length > 0 && h == wd)
			return true;
		if (hd.length > 0 && w == hd)
			return true;
		return false;
	}

	static function contains(have:String, wantLow:String):Bool {
		if (have == null || have.length == 0)
			return false;
		return have.toLowerCase().indexOf(wantLow) >= 0;
	}

	/** duration 0 = CastleDB length. pct > 16 on status is leftover resource default → any stacks. */
	static function catalogHold(a:AuraDef, fallback:Float):Float {
		if (a.duration > 0.05)
			return a.duration;
		var c = CdbAuraTable.duration(a.skillId);
		if (c > 0.2)
			return c;
		return fallback;
	}

	static function statusStackHit(a:AuraDef, stacks:Int):Bool {
		if (a.pct < 1 || a.pct > 16)
			return true;
		var need = Std.int(a.pct);
		if (need < 1)
			need = 1;
		if (a.op == "below")
			return stacks <= need;
		return stacks >= need;
	}

	static function statusProgress(a:AuraDef, st:AuraStatusSnap):Float {
		if (st == null)
			return 1;
		var max = CdbAuraTable.duration(a.skillId);
		if (st.left > 0.05 && max > 0.05)
			return clamp01(st.left / max);
		return st.progress;
	}

	static function clamp01(v:Float):Float {
		if (v < 0)
			return 0;
		if (v > 1)
			return 1;
		return v;
	}

	public static function aurasDir():String {
		try {
			return haxe.io.Path.join([solarflare.ui.ModPaths.modDir(), "auras"]);
		} catch (_:Dynamic) {
			return haxe.io.Path.join([Sys.getCwd(), "hlx", "mods", "SolarFlare", "auras"]);
		}
	}

	public static function toObj(a:AuraDef):Dynamic {
		if (a == null)
			return {};
		try {
			return toObjUnsafe(a);
		} catch (_:Dynamic) {
			return minimalObj(a);
		}
	}

	static function toObjUnsafe(a:AuraDef):Dynamic {
		AuraEffects.ensure(a);
		var fx:Array<Dynamic> = [];
		var i = 0;
		while (i < a.effects.length) {
			var e = a.effects[i];
			if (e != null)
				fx.push(e.toObj());
			i++;
		}
		var obj:Dynamic = {
			id: safeString(a.id),
			name: safeString(a.name),
			enabled: boolRef(a.enabled, true),
			trigger: safeString(a.trigger, "resource"),
			skillId: safeString(a.skillId),
			resource: safeString(a.resource, "hp"),
			op: safeString(a.op, "below"),
			pct: a.pct,
			duration: a.duration,
			region: safeString(a.region, "bar"),
			iconId: safeString(a.iconId),
			invert: boolRef(a.invert, false),
			requireAfford: boolRef(a.requireAfford, true),
			dormant: boolRef(a.dormant, false),
			alwaysOn: boolRef(a.alwaysOn, false),
			visual: boolRef(a.visual, true),
			audio: boolRef(a.audio, false),
			cue: safeString(a.cue),
			// Keep the DRM alias compatible while iconId remains authoritative.
			plate: safeString(a.iconId != null && a.iconId.length > 0 ? a.iconId : a.plate),
			announce: safeString(a.announce),
			fight: safeString(a.fight),
			volume: floatRef(a.volume, 1),
			opacity: floatRef(a.opacity, 1),
			scale: floatRef(a.scale, 1),
			showIcon: boolRef(a.showIcon, true),
			progressRing: boolRef(a.progressRing, true),
			stackCounter: boolRef(a.stackCounter, false),
			showLabel: boolRef(a.showLabel, true),
			isCounter: boolRef(a.isCounter, false),
			bannerText: safeString(a.bannerText),
			bannerScale: floatRef(a.bannerScale, 1.15),
			showBanner: boolRef(a.showBanner, false),
			keyText: safeString(a.keyText),
			showKey: boolRef(a.showKey, true),
			effects: fx,
			w: floatRef(a.w, 96),
			h: floatRef(a.h, 96)
		};
		if (a.chrome != null) {
			Reflect.setField(obj, "x", floatRef(a.chrome.x, 0));
			Reflect.setField(obj, "y", floatRef(a.chrome.y, 0));
			Reflect.setField(obj, "lock", boolRef(a.chrome.locked, false));
			Reflect.setField(obj, "transparent", boolRef(a.chrome.transparent, false));
		}
		if (a.rule != null)
			Reflect.setField(obj, "rule", AuraRuleCodec.toObj(a.rule));
		return obj;
	}

	static function minimalObj(a:AuraDef):Dynamic {
		return {
			id: safeString(a.id, "aura"),
			name: safeString(a.name, "Aura"),
			enabled: true,
			trigger: "resource",
			resource: "hp",
			op: "below",
			pct: 35,
			duration: 3,
			region: "bar"
		};
	}

	static function boolRef(r:Null<BoolRef>, fallback:Bool):Bool {
		if (r == null)
			return fallback;
		try {
			return r.get();
		} catch (_:Dynamic) {
			return fallback;
		}
	}

	static function floatRef(r:Null<FloatRef>, fallback:Float):Float {
		if (r == null)
			return fallback;
		try {
			return r.get();
		} catch (_:Dynamic) {
			return fallback;
		}
	}

	static function safeString(s:Null<String>, ?fallback:String = ""):String {
		if (s == null)
			return fallback;
		try {
			var out = StringTools.trim(s);
			return out.length > 0 ? out : fallback;
		} catch (_:Dynamic) {
			return fallback;
		}
	}

	public static function saveAll(cfg:AuraConfig):Void {
		if (cfg == null)
			return;
		try {
			var dir = aurasDir();
			if (!FileSystem.exists(dir))
				FileSystem.createDirectory(dir);
			var i = 0;
			while (i < cfg.auras.length) {
				var a = cfg.auras[i];
				File.saveContent(haxe.io.Path.join([dir, a.id + ".json"]), haxe.Json.stringify(toObj(a), null, "  "));
				i++;
			}
		} catch (_:Dynamic) {}
	}

	public static function loadAll(cfg:AuraConfig):Void {
		if (cfg == null)
			return;
		try {
			var dir = aurasDir();
			if (!FileSystem.exists(dir) || !FileSystem.isDirectory(dir))
				return;
			for (name in FileSystem.readDirectory(dir)) {
				if (!StringTools.endsWith(name.toLowerCase(), ".json"))
					continue;
				var raw = File.getContent(haxe.io.Path.join([dir, name]));
				var d:Dynamic = haxe.Json.parse(raw);
				if (d == null || d.id == null)
					continue;
				if (cfg.find(Std.string(d.id)) != null)
					continue;
				var a = AuraConfig.fromDyn(d);
				if (cfg.auras.length < MAX)
					cfg.auras.push(a);
			}
		} catch (_:Dynamic) {}
	}

	static function stamp():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}
}
