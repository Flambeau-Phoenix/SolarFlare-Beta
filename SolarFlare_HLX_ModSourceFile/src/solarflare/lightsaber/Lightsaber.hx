package solarflare.lightsaber;

import solarflare.HealthCache;
import solarflare.FieldWalk;
import solarflare.combatlog.CombatLogCache;
import solarflare.combatlog.CombatLogLine;
import solarflare.combatlog.UniqueHeroName;
import solarflare.getrifty.GetRifty;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.HudChrome;
import solarflare.ui.ImGuiLists;
import solarflare.ui.SettingsStore;
import solarflare.ui.ToastManager;
import solarflare.ui.UiLayout;
import imgui.ImGui;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiSelectableFlags;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiTableColumnFlags;
import imgui.Enums.ImGuiTableFlags;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Theme;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;

/**
 * Self-only encounter DPS snapshot. Primitives only — never store live engine objects.
 * Encounter ends after IDLE_SEC without a local hit; meter stays visible until reset / next hit.
 */
class LightsaberSkillRow {
	public var id:String = "";
	public var label:String = "";
	public var player:String = "";
	public var minion:String = "";
	public var damage:Float = 0;
	public var hits:Int = 0;
	public var crits:Int = 0;
	public var maxHit:Float = 0;

	public function new(id:String, label:String) {
		this.id = id;
		this.label = label;
	}
}

@:keep
class LightsaberPlayerTotal {
	public var player:String = "";
	public var damage:Float = 0;
	public var hits:Int = 0;
	public var crits:Int = 0;

	public function new(player:String) {
		this.player = player;
	}
}

class LightsaberHit {
	public var t:Float = 0;
	public var skillId:String = "";
	public var source:String = "";
	public var minion:String = "";
	public var target:String = "";
	public var amount:Float = 0;
	public var crit:Bool = false;
	public var targetHp:Float = 0;
	public var targetMaxHp:Float = 0;

	public function new() {}

	public static function fromJson(o:Dynamic):LightsaberHit {
		if (o == null)
			return null;
		var h = new LightsaberHit();
		h.t = jsonFloat(o, "t");
		h.skillId = jsonFieldStr(o, "skill");
		h.source = jsonFieldStr(o, "src");
		h.minion = jsonFieldStr(o, "minion");
		h.target = jsonFieldStr(o, "tgt");
		h.amount = jsonFloat(o, "amt");
		h.crit = jsonBool(o, "crit");
		h.targetHp = jsonFloat(o, "hp");
		h.targetMaxHp = jsonFloat(o, "max");
		if (h.amount <= 0 && h.skillId.length == 0 && h.source.length == 0)
			return null;
		return h;
	}

	/** Copy into a real Haxe String so Json.stringify cannot emit `{bytes,length}`. */
	public static function jsonSafe(s:String):String {
		if (s == null || s.length == 0)
			return "";
		try {
			var out = new StringBuf();
			var i = 0;
			while (i < s.length) {
				var c = s.charCodeAt(i);
				if (c != null)
					out.addChar(c);
				i++;
			}
			return out.toString();
		} catch (_:Dynamic)
			return "";
	}

	/** Avoid Int32 Math.round overflow (epoch seconds * 100). */
	public static function round2(v:Float):Float {
		if (v != v || !Math.isFinite(v))
			return 0;
		return Math.ffloor(v * 100 + 0.5) / 100;
	}

	static function jsonFieldStr(o:Dynamic, k:String):String {
		try {
			var v:Dynamic = Reflect.field(o, k);
			if (v == null)
				return "";
			if (Std.isOfType(v, String))
				return jsonSafe(cast v);
			return jsonSafe(Std.string(v));
		} catch (_:Dynamic)
			return "";
	}

	static function jsonFloat(o:Dynamic, k:String):Float {
		try {
			var v:Dynamic = Reflect.field(o, k);
			if (v == null)
				return 0;
			if (Std.isOfType(v, Float))
				return v;
			if (Std.isOfType(v, Int))
				return v;
			var n = Std.parseFloat(Std.string(v));
			return Math.isNaN(n) ? 0 : n;
		} catch (_:Dynamic)
			return 0;
	}

	static function jsonBool(o:Dynamic, k:String):Bool {
		try {
			var v:Dynamic = Reflect.field(o, k);
			if (v == true)
				return true;
			if (v == false)
				return false;
			var s = StringTools.trim(Std.string(v)).toLowerCase();
			return s == "true" || s == "1" || s == "yes";
		} catch (_:Dynamic)
			return false;
	}
}

/**
 * One encounter snapshot (local You, or in-rift hero players).
 */
class LightsaberMeter {
	public var active:Bool = false;
	public var ended:Bool = false;
	public var totalDamage:Float = 0;
	public var totalHits:Int = 0;
	public var totalCrits:Int = 0;
	public var unattribDamage:Float = 0;
	public var elapsedSec:Float = 0;
	public var lastHitAt:Float = 0;
	public var startedAt:Float = 0;
	public var skills:Array<LightsaberSkillRow> = [];

	var byId:Map<String, LightsaberSkillRow> = new Map();
	var lastIngestSequence:Float = 0;
	var groupByCaster:Bool;
	var writeLog:Bool;

	public function new(groupByCaster:Bool, writeLog:Bool) {
		this.groupByCaster = groupByCaster;
		this.writeLog = writeLog;
	}

	public function reset(discardPending:Bool = true):Void {
		active = false;
		ended = false;
		totalDamage = 0;
		totalHits = 0;
		totalCrits = 0;
		unattribDamage = 0;
		elapsedSec = 0;
		lastHitAt = 0;
		startedAt = 0;
		skills = [];
		byId = new Map();
		if (discardPending)
			lastIngestSequence = CombatLogCache.latestSequence;
		if (writeLog)
			LightsaberLog.clearLive();
	}

	public function dps():Float {
		if (elapsedSec <= 0)
			return 0;
		return totalDamage / elapsedSec;
	}

	public function noteHit(amount:Float, skillId:String, skillLabel:String, nowSec:Float, crit:Bool = false,
			source:String = "", minion:String = "", target:String = "", targetHp:Float = 0, targetMaxHp:Float = 0):Void {
		if (!LightsaberCache.enabled)
			return;
		if (amount <= 0 || !Math.isFinite(amount))
			return;
		if (!active || ended) {
			reset(false);
			active = true;
			ended = false;
			startedAt = nowSec;
			LightsaberCache.refreshName();
		}
		lastHitAt = nowSec;
		elapsedSec = nowSec - startedAt;
		if (elapsedSec < 0)
			elapsedSec = 0;

		totalDamage += amount;
		totalHits += 1;
		if (crit)
			totalCrits += 1;

		var who = UniqueHeroName.rejectClass(source);
		if (who.length == 0)
			who = UniqueHeroName.rejectClass(LightsaberCache.playerName);
		if (who.length == 0)
			who = LightsaberCache.playerName.length > 0 ? LightsaberCache.playerName : "You";
		var confirmed = solarflare.EngineSkillId.display(skillId);
		if (confirmed.length == 0)
			confirmed = solarflare.EngineSkillId.display(skillLabel);
		if (confirmed.length == 0) {
			confirmed = "Unknown";
			unattribDamage += amount;
		}

		var key = (groupByCaster ? LightsaberCache.skillKey(who, confirmed) : confirmed) + "\u001f" + minion;
		var row = byId.get(key);
		if (row == null) {
			row = new LightsaberSkillRow(confirmed, confirmed);
			row.player = who;
			row.minion = minion;
			byId.set(key, row);
			skills.push(row);
		} else if (row.player.length == 0)
			row.player = who;
		row.damage += amount;
		row.hits += 1;
		if (crit)
			row.crits += 1;
		if (amount > row.maxHit)
			row.maxHit = amount;
		sortSkills();
		if (writeLog)
			LightsaberLog.push(nowSec, confirmed == "Unknown" ? "" : confirmed, who, minion, target, amount, crit, targetHp,
				targetMaxHp);
	}

	public function tick(nowSec:Float):Void {
		if (!active || ended)
			return;
		elapsedSec = nowSec - startedAt;
		if (elapsedSec < 0)
			elapsedSec = 0;
		if (lastHitAt > 0 && (nowSec - lastHitAt) >= LightsaberCache.IDLE_SEC) {
			ended = true;
			if (writeLog)
				LightsaberLog.seal();
		}
	}

	public function ingestYou():Void {
		ingestMatching(function(line) {
			return line != null && line.kind == CombatLogCache.KIND_HIT
				&& line.sourceRole == CombatLogCache.ROLE_YOU
				&& line.amount > 0 && !Math.isNaN(line.amount);
		});
	}

	public function ingestHeroes():Void {
		ingestMatching(LightsaberCache.isHeroOutgoingHit);
	}

	public function playerRows():Array<LightsaberPlayerTotal> {
		var order:Array<LightsaberPlayerTotal> = [];
		var map = new Map<String, LightsaberPlayerTotal>();
		for (s in skills) {
			if (s == null)
				continue;
			var name = s.player.length > 0 ? s.player : "?";
			var row = map.get(name);
			if (row == null) {
				row = new LightsaberPlayerTotal(name);
				map.set(name, row);
				order.push(row);
			}
			row.damage += s.damage;
			row.hits += s.hits;
			row.crits += s.crits;
		}
		order.sort(function(a, b) {
			if (a.damage == b.damage)
				return 0;
			return a.damage > b.damage ? -1 : 1;
		});
		return order;
	}

	function ingestMatching(ok:CombatLogLine->Bool):Void {
		if (!LightsaberCache.enabled)
			return;
		LightsaberCache.refreshName();
		var lines = CombatLogCache.recentAll();
		var maxSequence = lastIngestSequence;
		for (line in lines) {
			if (line == null || line.sequence <= lastIngestSequence)
				continue;
			if (line.sequence > maxSequence)
				maxSequence = line.sequence;
			if (!ok(line))
				continue;
			noteHit(line.amount, line.skillId, line.skillLabel, line.t, line.crit, LightsaberCache.casterName(line),
				line.minionName, line.targetName, line.targetHp, line.targetMaxHp);
		}
		lastIngestSequence = maxSequence;
	}

	function sortSkills():Void {
		skills.sort(function(a, b) {
			if (a.damage == b.damage)
				return 0;
			return a.damage > b.damage ? -1 : 1;
		});
	}
}

class LightsaberCache {
	public static inline var IDLE_SEC:Float = 6.0;

	public static var enabled:Bool = true;
	public static var playerName:String = "";
	public static var you:LightsaberMeter = new LightsaberMeter(false, true);
	public static var rift:LightsaberMeter = new LightsaberMeter(true, false);

	static var riftLive:Bool = false;

	public static function reset():Void {
		you.reset();
	}

	public static function dps():Float {
		return you.dps();
	}

	public static function noteHit(amount:Float, skillId:String, skillLabel:String, nowSec:Float, crit:Bool = false,
			source:String = "", minion:String = "", target:String = "", targetHp:Float = 0, targetMaxHp:Float = 0):Void {
		you.noteHit(amount, skillId, skillLabel, nowSec, crit, source, minion, target, targetHp, targetMaxHp);
	}

	public static function tick(nowSec:Float):Void {
		refreshName();
		you.tick(nowSec);
		if (riftLive)
			rift.tick(nowSec);
	}

	public static function isHeroOutgoingHit(line:CombatLogLine):Bool {
		if (line == null)
			return false;
		if (line.kind != CombatLogCache.KIND_HIT)
			return false;
		if (line.amount <= 0 || Math.isNaN(line.amount))
			return false;
		return line.sourceRole == CombatLogCache.ROLE_YOU || line.sourceRole == CombatLogCache.ROLE_PLAYER;
	}

	public static function casterName(line:CombatLogLine):String {
		if (line == null)
			return "?";
		var who = UniqueHeroName.rejectClass(line.sourcePlayer);
		if (who.length > 0)
			return who;
		who = UniqueHeroName.rejectClass(line.sourceName);
		if (who.length > 0)
			return who;
		if (line.sourceRole != CombatLogCache.ROLE_YOU)
			return "?";
		who = UniqueHeroName.rejectClass(playerName);
		if (who.length > 0)
			return who;
		if (playerName.length > 0)
			return playerName;
		return "?";
	}

	public static function skillKey(player:String, skillId:String):String {
		var p = player != null ? player : "";
		var s = skillId != null ? skillId : "";
		return p + "\t" + s;
	}

	/** Local You always. In-rift hero meter only inside a rift instance. */
	public static function ingestForConfig(cfg:LightsaberConfig):Void {
		you.ingestYou();
		var wantRift = cfg != null && cfg.showRiftMeter.get() && GetRiftyCache.inInstance;
		if (wantRift) {
			if (!riftLive) {
				rift.reset();
				riftLive = true;
			}
			rift.ingestHeroes();
		} else if (riftLive) {
			rift.reset();
			riftLive = false;
		}
	}

	public static function playerTotals(hits:Array<LightsaberHit>):Array<LightsaberPlayerTotal> {
		var order:Array<LightsaberPlayerTotal> = [];
		if (hits == null)
			return order;
		var map = new Map<String, LightsaberPlayerTotal>();
		for (h in hits) {
			if (h == null)
				continue;
			var name = h.source != null && h.source.length > 0 ? h.source : "?";
			var row = map.get(name);
			if (row == null) {
				row = new LightsaberPlayerTotal(name);
				map.set(name, row);
				order.push(row);
			}
			row.damage += h.amount;
			row.hits += 1;
			if (h.crit)
				row.crits += 1;
		}
		order.sort(function(a, b) {
			if (a.damage == b.damage)
				return 0;
			return a.damage > b.damage ? -1 : 1;
		});
		return order;
	}

	public static function refreshName():Void {
		if (HealthCache.heroName != null && HealthCache.heroName.length > 0)
			playerName = HealthCache.heroName;
	}
}

class LightsaberLog {
	static inline var CAP:Int = 400;

	public static var hits:Array<LightsaberHit> = [];
	public static var archived:Array<LightsaberHit> = [];
	static var writeAt:Int = 0;
	static var count:Int = 0;
	static var sealed:Bool = false;

	public static function clearLive():Void {
		if (count > 0)
			archived = hitsForDraw();
		hits = [];
		writeAt = 0;
		count = 0;
		sealed = false;
	}

	public static function push(t:Float, skillId:String, source:String, minion:String, target:String, amount:Float, crit:Bool,
			targetHp:Float, targetMaxHp:Float):Void {
		var h = new LightsaberHit();
		h.t = t;
		h.skillId = LightsaberHit.jsonSafe(skillId);
		h.source = LightsaberHit.jsonSafe(source);
		h.minion = LightsaberHit.jsonSafe(minion);
		h.target = LightsaberHit.jsonSafe(target);
		h.amount = amount;
		h.crit = crit;
		h.targetHp = targetHp;
		h.targetMaxHp = targetMaxHp;
		if (hits.length < CAP) {
			hits.push(h);
			writeAt = hits.length % CAP;
			count++;
			return;
		}
		hits[writeAt] = h;
		writeAt = (writeAt + 1) % CAP;
		if (count < CAP)
			count++;
	}

	public static function seal():Void {
		if (sealed)
			return;
		sealed = true;
		writeFile();
	}

	public static function hitsForDraw():Array<LightsaberHit> {
		var out:Array<LightsaberHit> = [];
		var n = count < CAP ? count : CAP;
		var start = count < CAP ? 0 : writeAt;
		var i = 0;
		while (i < n) {
			var h = hits[(start + i) % CAP];
			if (h != null)
				out.push(h);
			i++;
		}
		return out;
	}

	static function writeFile():Void {
		try {
			solarflare.ui.SettingsStore.migrateSaberLogs();
			var dir = solarflare.ui.SettingsStore.logSubdir("saber");
			if (dir == null || dir.length == 0)
				return;
			var name = "saber-" + Date.now().getTime() + ".jsonl";
			var path = haxe.io.Path.join([dir, name]);
			var buf = new StringBuf();
			for (h in hitsForDraw()) {
				buf.add(haxe.Json.stringify({
					t: LightsaberHit.round2(h.t),
					skill: LightsaberHit.jsonSafe(h.skillId),
					src: LightsaberHit.jsonSafe(h.source),
					minion: LightsaberHit.jsonSafe(h.minion),
					tgt: LightsaberHit.jsonSafe(h.target),
					amt: LightsaberHit.round2(h.amount),
					crit: h.crit,
					hp: LightsaberHit.round2(h.targetHp),
					max: LightsaberHit.round2(h.targetMaxHp)
				}));
				buf.add("\n");
			}
			sys.io.File.saveContent(path, buf.toString());
		} catch (_:Dynamic) {}
	}
}

class LightsaberConfig {
	public static inline var MIN_W:Single = 280;
	public static inline var MAX_W:Single = 860;
	public static inline var MIN_H:Single = 80;
	public static inline var MAX_H:Single = 640;

	public var open = new BoolRef(false);
	public var hidden = new BoolRef(false);
	public var expandSkills = new BoolRef(true);
	public var showLog = new BoolRef(false);
	public var showRiftMeter = new BoolRef(false);
	public var width = new FloatRef(480);
	public var height = new FloatRef(240);
	public var sizeDirty = true;
	public var chrome:HudChrome;
	public var riftWidth = new FloatRef(420);
	public var riftHeight = new FloatRef(280);
	public var riftSizeDirty = true;
	public var riftChrome:HudChrome;

	public function new() {
		chrome = new HudChrome(40, 280);
		riftChrome = new HudChrome(480, 280);
	}

	public function draw():Void {
		if (!open.get())
			return;
		ImGui.setNextWindowSize(ImGui.vec2(380, 0), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel("Lightsaber", open, "Lightsaber options")) {
			ImGui.textWrapped("Local meter is always You. GetRifty clock is independent. Encounter ends after 6s without your hit; totals stay until next hit.");
			ImGui.separatorText("Window");
			chrome.drawWindowSettings(hidden, "saber");
			UiLayout.propertyGrid("##saber_props", function() {
				UiLayout.propertyRow("Rift meter", function() {
					if (ImGui.checkbox("In that rift##saber_rift", showRiftMeter))
						SettingsStore.markDirty();
				}, GetRiftyCache.inInstance
					? "Tracks hero players in the instance only."
					: "Opens only while inside a rift.");
				UiLayout.propertyRow("Size", function() {
					UiLayout.inlinePair(
						"##saber_size",
						function(_:Single) {
							if (ImGui.sliderFloat("Width##saber_w", width, MIN_W, MAX_W, "%.0f px")) {
								sizeDirty = true;
								SettingsStore.markDirty();
							}
						},
						function(_:Single) {
							if (ImGui.sliderFloat("Height##saber_h", height, MIN_H, MAX_H, "%.0f px")) {
								sizeDirty = true;
								SettingsStore.markDirty();
							}
						}
					);
				});
			});
			if (ImGui.button("Reset local encounter", ImGui.vec2(-1, 0)))
				LightsaberCache.reset();
			if (GetRiftyCache.inInstance && ImGui.button("Reset in-rift encounter", ImGui.vec2(-1, 0)))
				LightsaberCache.rift.reset();
			if (ImGui.collapsingHeader("Advanced##saber")) {
				UiLayout.propertyGrid("##saber_adv_props", function() {
					UiLayout.propertyRow("Display", function() {
						UiLayout.inlinePair(
							"##saber_adv_disp",
							function(_:Single) {
								if (ImGui.checkbox("Expand skills##saber", expandSkills))
									SettingsStore.markDirty();
							},
							function(_:Single) {
								if (ImGui.checkbox("Log viewer##saber", showLog))
									SettingsStore.markDirty();
							}
						);
					});
				});
				ImGui.separatorText("In that rift window");
				riftChrome.drawWindowSettings(null, "saber_rift");
			}
		}
		HudChrome.endPanel();
	}
}

/**
 * Legacy direct ingest — preferred path is CombatLogCache.noteInflict → ingestYou.
 * Kept for `-dce full` / ModEntry.keep; no second Unit postfix.
 */
class LightsaberHooks {
	/** Keep reachable under `-dce full`. */
	public static function keep():Void {}

	public static function ingest(self:Dynamic, dmgObj:Dynamic):Void {
		if (self == null || dmgObj == null)
			return;
		try {
			var credited = solarflare.combatlog.CombatOwnership.resolve(self, FieldWalk.extractObject, ownerOfSkill);
			if (!HealthCache.isLocalHero(credited))
				return;
			var amount = readAmount(dmgObj);
			if (amount <= 0)
				return;
			var skillId = solarflare.EngineSkillId.ofSkill(dmgObj);
			if (skillId.length == 0)
				skillId = readSkillId(dmgObj);
			// v6 resolution: leaf kind -> CDB unit name, else the CDB summon map on
			// the hit skill (never the raw engine kind / guessed prefix).
			var minion = "";
			if (credited != null && (cast self : Dynamic) != (cast credited : Dynamic)) {
				var kind = FieldWalk.extractString(self, "kind", "");
				var label = solarflare.cdb.CdbUnitNames.lookup(kind);
				if (label.length == 0)
					label = solarflare.cdb.CdbSummonUnits.labelForSkill(skillId);
				if (label.length == 0)
					label = kind;
				minion = label;
			} else {
				minion = solarflare.cdb.CdbSummonUnits.labelForSkill(skillId);
			}
			LightsaberCache.noteHit(amount, skillId, skillId, nowSec(), false, HealthCache.heroName, minion);
		} catch (_:Dynamic) {}
	}

	static function ownerOfSkill(skill:Dynamic):Dynamic {
		if (skill == null)
			return null;
		var o = FieldWalk.extractObject(skill, "owner");
		if (o != null)
			return o;
		return FieldWalk.extractObject(skill, "parent");
	}

	static function nowSec():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}

	static function readAmount(dmgObj:Dynamic):Float {
		try {
			var dr:st.skill.DamageResult = dmgObj;
			var a = dr.get_amount();
			if (a > 0 && !Math.isNaN(a))
				return a;
		} catch (_:Dynamic) {}
		var a = FieldWalk.extractNumber(dmgObj, "amount", Math.NaN);
		if (!Math.isNaN(a) && a > 0)
			return a;
		a = FieldWalk.extractNumber(dmgObj, "_amount", Math.NaN);
		if (!Math.isNaN(a) && a > 0)
			return a;
		return 0;
	}

	static function readSkillId(dmgObj:Dynamic):String {
		try {
			var access:st.skill.BaseSkillAccess = dmgObj;
			var id = solarflare.EngineSkillId.display(access.get_skillId());
			if (id.length > 0)
				return id;
		} catch (_:Dynamic) {}
		return "";
	}
}

class LightsaberOverlay {
	static inline var FLAGS:Int = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse;

	var theme:Theme;
	var logView:LightsaberLogViewer;
	var tableColsReady:Map<String, Bool>;

	public function new() {
		tableColsReady = new Map();
		logView = new LightsaberLogViewer();
		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(6, 4))
			.varF(ImGuiStyleVar.WindowRounding, 5)
			.varF(ImGuiStyleVar.WindowBorderSize, 2)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0.07, 0.08, 0.10, 0.88))
			.color(ImGuiCol.Border, ImGui.vec4(0.42, 0.62, 0.92, 0.72))
			.color(ImGuiCol.ChildBg, ImGui.vec4(0.05, 0.06, 0.08, 0.55))
			.color(ImGuiCol.ResizeGrip, ImGui.vec4(0.40, 0.55, 0.80, 0.45));
	}

	public function draw(cfg:LightsaberConfig):Void {
		if (cfg == null || cfg.hidden.get())
			return;
		LightsaberCache.enabled = !cfg.hidden.get();
		theme.wrap(() -> drawWindow(cfg));
		if (GetRiftyCache.inInstance && cfg.showRiftMeter.get())
			theme.wrap(() -> drawRiftWindow(cfg));
		if (cfg.showLog.get())
			logView.draw(cfg);
	}

	function drawWindow(cfg:LightsaberConfig):Void {
		var w:Single = cfg.width.get();
		var h:Single = cfg.height.get();
		if (w < LightsaberConfig.MIN_W)
			w = LightsaberConfig.MIN_W;
		if (w > LightsaberConfig.MAX_W)
			w = LightsaberConfig.MAX_W;
		if (h < LightsaberConfig.MIN_H)
			h = LightsaberConfig.MIN_H;
		if (h > LightsaberConfig.MAX_H)
			h = LightsaberConfig.MAX_H;

		var trans = cfg.chrome != null && cfg.chrome.isTransparent();
		ImGui.setNextWindowBgAlpha(trans ? 0 : 0.88);
		ImGui.setNextWindowSizeConstraints(
			ImGui.vec2(LightsaberConfig.MIN_W, LightsaberConfig.MIN_H),
			ImGui.vec2(LightsaberConfig.MAX_W, LightsaberConfig.MAX_H)
		);
		if (cfg.chrome != null && cfg.chrome.takeExpandDirty())
			cfg.sizeDirty = true;
		if (cfg.sizeDirty) {
			ImGui.setNextWindowSize(ImGui.vec2(w, h), ImGuiCond.Always);
			cfg.sizeDirty = false;
		} else {
			ImGui.setNextWindowSize(ImGui.vec2(w, h), ImGuiCond.FirstUseEver);
			ImGui.setNextWindowPos(ImGui.vec2(40, 280), ImGuiCond.FirstUseEver);
		}
		if (cfg.chrome != null) {
			cfg.chrome.clampToViewport();
			cfg.chrome.applyPos();
		}

		var flags = cfg.chrome != null ? cfg.chrome.windowFlagsKeepClicks(FLAGS) : FLAGS;
		flags |= ImGuiWindowFlags.NoSavedSettings;
		var began = ImGui.begin("SolarFlare Lightsaber", null, flags);
		if (began) {
			if (cfg.chrome == null || !cfg.chrome.isLocked()) {
				var win = ImGui.getWindowSize();
				if (Math.abs(win.x - w) > 1 || Math.abs(win.y - h) > 1) {
					cfg.width.set(Math.max(LightsaberConfig.MIN_W, Math.min(LightsaberConfig.MAX_W, win.x)));
					cfg.height.set(Math.max(LightsaberConfig.MIN_H, Math.min(LightsaberConfig.MAX_H, win.y)));
					SettingsStore.markDirty();
				}
				if (cfg.chrome != null)
					cfg.chrome.capturePos();
			}
			var showBody = true;
			if (cfg.chrome != null) {
				showBody = cfg.chrome.beginBody(function() {
					cfg.hidden.set(true);
					SettingsStore.markDirty();
				}, null, "Lightsaber");
			}
			if (showBody) {
				drawSaberTitleLeading(cfg);
				if (GetRiftyCache.inInstance) {
					if (ImGui.checkbox("In that rift##saber_win_rift", cfg.showRiftMeter))
						SettingsStore.markDirty();
				}
				drawMeterVals(LightsaberCache.you);
				if (cfg.expandSkills.get()) {
					var avail = ImGui.getContentRegionAvail();
					var tableFlags = trans ? ImGuiWindowFlags.NoBackground : 0;
					if (ImGui.beginChild("saber_table_host", ImGui.vec2(0, avail.y), 0, tableFlags))
						drawSkillTable("saber_skills", LightsaberCache.you);
					ImGui.endChild();
				}
			}
		}
		solarflare.ui.HudChrome.endOverlayWindow(began, cfg.chrome);
	}

	function drawRiftWindow(cfg:LightsaberConfig):Void {
		var w:Single = cfg.riftWidth.get();
		var h:Single = cfg.riftHeight.get();
		if (w < LightsaberConfig.MIN_W)
			w = LightsaberConfig.MIN_W;
		if (w > LightsaberConfig.MAX_W)
			w = LightsaberConfig.MAX_W;
		if (h < LightsaberConfig.MIN_H)
			h = LightsaberConfig.MIN_H;
		if (h > LightsaberConfig.MAX_H)
			h = LightsaberConfig.MAX_H;

		var trans = cfg.riftChrome != null && cfg.riftChrome.isTransparent();
		ImGui.setNextWindowBgAlpha(trans ? 0 : 0.88);
		ImGui.setNextWindowSizeConstraints(
			ImGui.vec2(LightsaberConfig.MIN_W, LightsaberConfig.MIN_H),
			ImGui.vec2(LightsaberConfig.MAX_W, LightsaberConfig.MAX_H)
		);
		if (cfg.riftSizeDirty) {
			ImGui.setNextWindowSize(ImGui.vec2(w, h), ImGuiCond.Always);
			cfg.riftSizeDirty = false;
		} else {
			ImGui.setNextWindowSize(ImGui.vec2(w, h), ImGuiCond.FirstUseEver);
			ImGui.setNextWindowPos(ImGui.vec2(480, 280), ImGuiCond.FirstUseEver);
		}
		if (cfg.riftChrome != null)
			cfg.riftChrome.applyPos();

		var flags = cfg.riftChrome != null ? cfg.riftChrome.windowFlags(FLAGS) : FLAGS;
		flags |= ImGuiWindowFlags.NoSavedSettings;
		var began = ImGui.begin("SolarFlare Lightsaber Rift", null, flags);
		if (began) {
			if (cfg.riftChrome == null || !cfg.riftChrome.isLocked()) {
				var win = ImGui.getWindowSize();
				if (Math.abs(win.x - w) > 1 || Math.abs(win.y - h) > 1) {
					cfg.riftWidth.set(Math.max(LightsaberConfig.MIN_W, Math.min(LightsaberConfig.MAX_W, win.x)));
					cfg.riftHeight.set(Math.max(LightsaberConfig.MIN_H, Math.min(LightsaberConfig.MAX_H, win.y)));
					SettingsStore.markDirty();
				}
				if (cfg.riftChrome != null)
					cfg.riftChrome.capturePos();
			}
			var showBody = true;
			if (cfg.riftChrome != null) {
				showBody = cfg.riftChrome.beginBody(function() {
					cfg.showRiftMeter.set(false);
					SettingsStore.markDirty();
				}, function() {
					ImGui.text("In that rift  heroes [" + meterStatus(LightsaberCache.rift) + "]");
					ImGui.sameLine();
					ImGui.pushStyleColor(ImGuiCol.Button, ImGui.vec4(0.52, 0.20, 0.20, 0.9));
					ImGui.pushStyleColor(ImGuiCol.ButtonHovered, ImGui.vec4(0.68, 0.26, 0.26, 1));
					ImGui.pushStyleColor(ImGuiCol.ButtonActive, ImGui.vec4(0.40, 0.15, 0.15, 1));
					if (ImGui.button("Reset##saber_reset_rift")) {
						LightsaberCache.rift.reset();
						ToastManager.info("In-rift DPS meter reset");
					}
					if (ImGui.isItemHovered())
						ImGui.setTooltip("Reset in-rift hero encounter metrics");
					ImGui.popStyleColor(3);
					ImGui.sameLine();
					drawRiftTimerBox("saber_rift_grp");
				}, "");
			} else {
				ImGui.text("In that rift  heroes [" + meterStatus(LightsaberCache.rift) + "]");
				ImGui.sameLine();
				ImGui.pushStyleColor(ImGuiCol.Button, ImGui.vec4(0.52, 0.20, 0.20, 0.9));
				ImGui.pushStyleColor(ImGuiCol.ButtonHovered, ImGui.vec4(0.68, 0.26, 0.26, 1));
				ImGui.pushStyleColor(ImGuiCol.ButtonActive, ImGui.vec4(0.40, 0.15, 0.15, 1));
				if (ImGui.button("Reset##saber_reset_rift")) {
					LightsaberCache.rift.reset();
					ToastManager.info("In-rift DPS meter reset");
				}
				if (ImGui.isItemHovered())
					ImGui.setTooltip("Reset in-rift hero encounter metrics");
				ImGui.popStyleColor(3);
				ImGui.sameLine();
				drawRiftTimerBox("saber_rift_grp");
			}
			if (showBody) {
				var m = LightsaberCache.rift;
				drawMeterVals(m);
				drawPlayerTable(m);
				if (cfg.expandSkills.get()) {
					var avail = ImGui.getContentRegionAvail();
					var tableFlags = trans ? ImGuiWindowFlags.NoBackground : 0;
					if (ImGui.beginChild("saber_rift_table_host", ImGui.vec2(0, avail.y), 0, tableFlags))
						drawSkillTable("saber_rift_skills", m);
					ImGui.endChild();
				}
			}
		}
		solarflare.ui.HudChrome.endOverlayWindow(began, cfg.riftChrome);
	}

	function drawSaberTitleLeading(cfg:LightsaberConfig):Void {
		ImGui.text("Lightsaber  you [" + meterStatus(LightsaberCache.you) + "]");
		ImGui.sameLine();
		ImGui.pushStyleColor(ImGuiCol.Button, ImGui.vec4(0.22, 0.42, 0.78, 1));
		ImGui.pushStyleColor(ImGuiCol.ButtonHovered, ImGui.vec4(0.30, 0.52, 0.90, 1));
		ImGui.pushStyleColor(ImGuiCol.ButtonActive, ImGui.vec4(0.16, 0.32, 0.62, 1));
		if (ImGui.button("Logs##saber_logs")) {
			cfg.showLog.set(true);
			SettingsStore.markDirty();
		}
		ImGui.popStyleColor(3);
		ImGui.sameLine();
		ImGui.pushStyleColor(ImGuiCol.Button, ImGui.vec4(0.52, 0.20, 0.20, 0.9));
		ImGui.pushStyleColor(ImGuiCol.ButtonHovered, ImGui.vec4(0.68, 0.26, 0.26, 1));
		ImGui.pushStyleColor(ImGuiCol.ButtonActive, ImGui.vec4(0.40, 0.15, 0.15, 1));
		if (ImGui.button("Reset##saber_reset_you")) {
			LightsaberCache.reset();
			ToastManager.info("Lightsaber DPS meter reset");
		}
		if (ImGui.isItemHovered())
			ImGui.setTooltip("Reset current DPS encounter metrics");
		ImGui.popStyleColor(3);
		ImGui.sameLine();
		drawRiftTimerBox("saber_rift");
	}

	function drawMeterVals(m:LightsaberMeter):Void {
		ImGui.text("DPS " + formatNum(m.dps()));
		ImGui.sameLine(0, 16);
		ImGui.text("Damage " + formatNum(m.totalDamage));
		ImGui.sameLine(0, 16);
		ImGui.text("Time " + formatTime(m.elapsedSec));
	}

	static function meterStatus(m:LightsaberMeter):String {
		if (m == null)
			return "idle";
		if (m.active && !m.ended)
			return "live";
		if (m.ended)
			return "ended";
		return "idle";
	}

	function drawRiftTimerBox(_id:String):Void {
		var label = GetRiftyCache.phaseLabel;
		var remain = GetRiftyCache.countdownText;
		if (label == null || label.length == 0)
			label = ":00 RIFT";
		if (remain == null || remain.length == 0)
			remain = "00:00";
		var text = label + "  " + remain;
		var hot = label == "CLOSE" || GetRiftyCache.alertKind == GetRiftyCache.ALERT_RIFT;
		var col = hot ? ImGui.vec4(0.92, 0.32, 0.28, 1) : ImGui.vec4(0.35, 0.85, 0.42, 1);
		ImGui.pushStyleColor(ImGuiCol.Text, col);
		ImGui.text(text);
		ImGui.popStyleColor();
	}

	function drawPlayerTable(m:LightsaberMeter):Void {
		var total = m.totalDamage > 0 ? m.totalDamage : 1;
		var elapsed = m.elapsedSec > 0 ? m.elapsedSec : 1;
		var headers = ["Player", "Dmg", "DPS", "%", "Hits"];
		var cells:Array<Array<String>> = [];
		for (row in m.playerRows()) {
			cells.push([
				row.player,
				formatNum(row.damage),
				formatNum(row.damage / elapsed),
				Std.string(Std.int((row.damage / total) * 100)),
				Std.string(row.hits)
			]);
		}
		var mins = minTableColumns(headers, cells);
		var flags = ImGuiTableFlags.Borders | ImGuiTableFlags.RowBg | ImGuiTableFlags.SizingFixedFit
			| ImGuiTableFlags.Resizable;
		if (!ImGui.beginTable("saber_rift_players", 5, flags, ImGui.vec2(0, 0)))
			return;
		setupTableColumns("saber_rift_players", headers, mins);
		ImGui.tableHeadersRow();
		for (cellsRow in cells) {
			ImGui.tableNextRow();
			var ci = 0;
			while (ci < cellsRow.length) {
				ImGui.tableNextColumn();
				ImGui.text(cellsRow[ci]);
				ci++;
			}
		}
		ImGui.endTable();
	}

	function drawSkillTable(tableId:String, m:LightsaberMeter):Void {
		var total = m.totalDamage > 0 ? m.totalDamage : 1;
		var headers = ["Player", "Minion", "Skill", "Dmg", "%", "Hits", "Crit", "Max"];
		var cells:Array<Array<String>> = [];
		for (row in m.skills) {
			cells.push([
				row.player,
				row.minion,
				row.label,
				formatNum(row.damage),
				Std.string(Std.int((row.damage / total) * 100)),
				Std.string(row.hits),
				Std.string(row.crits),
				formatNum(row.maxHit)
			]);
		}
		var mins = minTableColumns(headers, cells);
		var flags = ImGuiTableFlags.Borders | ImGuiTableFlags.RowBg | ImGuiTableFlags.SizingFixedFit
			| ImGuiTableFlags.Resizable;
		if (!ImGui.beginTable(tableId, 8, flags, ImGui.vec2(0, 0)))
			return;
		setupTableColumns(tableId, headers, mins);
		ImGui.tableHeadersRow();
		for (cellsRow in cells) {
			ImGui.tableNextRow();
			var ci = 0;
			while (ci < cellsRow.length) {
				ImGui.tableNextColumn();
				ImGui.text(cellsRow[ci]);
				ci++;
			}
		}
		ImGui.endTable();
	}

	static inline var COL_PAD:Single = 18;

	function setupTableColumns(tableId:String, headers:Array<String>, mins:Array<Single>):Void {
		var ready = tableColsReady.exists(tableId);
		var stretchAt = stretchColumnIndex(headers);
		var hi = 0;
		while (hi < headers.length) {
			var stretch = hi == stretchAt;
			var colFlags = stretch ? ImGuiTableColumnFlags.WidthStretch : ImGuiTableColumnFlags.WidthFixed;
			var initW:Single = stretch ? 1.0 : (ready ? 0 : mins[hi]);
			ImGui.tableSetupColumn(headers[hi], colFlags, initW);
			hi++;
		}
		tableColsReady.set(tableId, true);
	}

	static function stretchColumnIndex(headers:Array<String>):Int {
		var i = 0;
		while (i < headers.length) {
			if (headers[i] == "Skill")
				return i;
			i++;
		}
		i = 0;
		while (i < headers.length) {
			if (headers[i] == "Player")
				return i;
			i++;
		}
		return 0;
	}

	static function minTableColumns(headers:Array<String>, rows:Array<Array<String>>):Array<Single> {
		var n = headers.length;
		var mins:Array<Single> = [];
		var i = 0;
		while (i < n) {
			var h = headers[i];
			mins.push(ImGui.calcTextSize(h != null ? h : "").x + COL_PAD);
			i++;
		}
		for (row in rows) {
			i = 0;
			while (i < n) {
				var cell = i < row.length && row[i] != null ? row[i] : "";
				var cw:Single = ImGui.calcTextSize(cell).x + COL_PAD;
				if (cw > mins[i])
					mins[i] = cw;
				i++;
			}
		}
		return mins;
	}

	static function formatNum(v:Float):String {
		if (v >= 1000000)
			return (Math.round(v / 10000) / 100) + "M";
		if (v >= 1000)
			return (Math.round(v / 10) / 100) + "k";
		return Std.string(Std.int(v));
	}

	static function formatTime(sec:Float):String {
		if (sec < 0)
			sec = 0;
		var s = Std.int(sec);
		var m = Std.int(s / 60);
		s = s % 60;
		return m + ":" + (s < 10 ? "0" : "") + s;
	}
}

class LightsaberLogViewer {
	static inline var FLAGS:Int = ImGuiWindowFlags.NoCollapse;

	var theme:Theme;
	var liveMode:Bool = true;

	public function new() {
		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(8, 6))
			.varF(ImGuiStyleVar.WindowRounding, 6)
			.varF(ImGuiStyleVar.WindowBorderSize, 1.5)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0.07, 0.08, 0.10, 0.92))
			.color(ImGuiCol.Border, ImGui.vec4(0.42, 0.62, 0.92, 0.55))
			.color(ImGuiCol.TableHeaderBg, ImGui.vec4(0.12, 0.14, 0.18, 0.9))
			.color(ImGuiCol.TableRowBg, ImGui.vec4(0.06, 0.07, 0.09, 0.35))
			.color(ImGuiCol.TableRowBgAlt, ImGui.vec4(0.09, 0.10, 0.13, 0.45));
	}

	public function draw(cfg:LightsaberConfig):Void {
		theme.wrap(() -> drawWindow(cfg));
	}

	function drawWindow(cfg:LightsaberConfig):Void {
		ImGui.setNextWindowSize(ImGui.vec2(860, 340), ImGuiCond.FirstUseEver);
		ImGui.setNextWindowPos(ImGui.vec2(40, 520), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel("Lightsaber Log", cfg.showLog, "Lightsaber Log")) {
			ImGui.separatorText("Hit log");
			if (ImGui.smallButton(liveMode ? "Live##saber_src" : "File##saber_src"))
				liveMode = !liveMode;
			ImGui.sameLine();
			ImGui.text(liveMode ? "live hits" : SaberJsonlArchive.status);

			var rows:Array<LightsaberHit> = [];
			if (liveMode) {
				rows = LightsaberLog.hitsForDraw();
				if (rows.length == 0)
					rows = LightsaberLog.archived;
			} else {
				drawFileList();
				rows = SaberJsonlArchive.loadedRows();
			}

			var dmg:Float = 0;
			var hits = 0;
			var crits = 0;
			for (h in rows) {
				if (h == null)
					continue;
				hits++;
				dmg += h.amount;
				if (h.crit)
					crits++;
			}
			var totals = LightsaberCache.playerTotals(rows);
			var who = "";
			if (totals.length > 0)
				who = "  " + totals[0].player;
			ImGui.text(hits + " hits  " + Std.int(dmg) + " dmg  " + crits + " crits" + who);

			var flags = ImGuiTableFlags.Borders | ImGuiTableFlags.RowBg | ImGuiTableFlags.ScrollY
				| ImGuiTableFlags.SizingStretchProp;
			if (ImGui.beginTable("saber_log", 8, flags)) {
				ImGui.tableSetupColumn("Time", ImGuiTableColumnFlags.WidthFixed, 56);
				ImGui.tableSetupColumn("Skill", ImGuiTableColumnFlags.WidthStretch);
				ImGui.tableSetupColumn("Player", ImGuiTableColumnFlags.WidthFixed, 140);
				ImGui.tableSetupColumn("Minion", ImGuiTableColumnFlags.WidthFixed, 120);
				ImGui.tableSetupColumn("Target", ImGuiTableColumnFlags.WidthFixed, 110);
				ImGui.tableSetupColumn("Dmg", ImGuiTableColumnFlags.WidthFixed, 56);
				ImGui.tableSetupColumn("Crit", ImGuiTableColumnFlags.WidthFixed, 40);
				ImGui.tableSetupColumn("HP", ImGuiTableColumnFlags.WidthFixed, 56);
				ImGui.tableSetupScrollFreeze(0, 1);
				ImGui.tableHeadersRow();
				var dense:Array<LightsaberHit> = [];
				for (h in rows)
					if (h != null)
						dense.push(h);
				var t0:Float = dense.length > 0 ? dense[0].t : 0;
				ImGuiLists.forVisible(dense.length, function(i:Int) drawHitRow(dense[i], t0));
				ImGui.endTable();
			}
		}
		HudChrome.endPanel();
	}

	function drawHitRow(h:LightsaberHit, t0:Float):Void {
		ImGui.tableNextRow();
		ImGui.tableNextColumn();
		var rel = h.t - t0;
		if (rel < 0)
			rel = 0;
		ImGui.text(Std.string(LightsaberHit.round2(rel)));
		ImGui.tableNextColumn();
		ImGui.text(h.skillId);
		ImGui.tableNextColumn();
		ImGui.text(h.source);
		ImGui.tableNextColumn();
		ImGui.text(h.minion);
		ImGui.tableNextColumn();
		ImGui.text(h.target);
		ImGui.tableNextColumn();
		ImGui.text(Std.string(Std.int(h.amount)));
		ImGui.tableNextColumn();
		if (h.crit)
			ImGui.textColored(ImGui.vec4(1.0, 0.78, 0.28, 1), "●");
		else
			ImGui.text("");
		ImGui.tableNextColumn();
		if (h.targetMaxHp > 0)
			ImGui.text(Std.string(Std.int((h.targetHp / h.targetMaxHp) * 100)) + "%");
		else if (h.targetHp > 0)
			ImGui.text(Std.string(Std.int(h.targetHp)));
		else
			ImGui.text("");
	}

	function drawFileList():Void {
		var list = SaberJsonlArchive.fileList();
		if (list.length == 0) {
			ImGui.text("No saber-*.jsonl in logs/saber.");
			return;
		}
		if (ImGui.beginChild("saber_files", ImGui.vec2(0, 72), ImGuiChildFlags.Borders)) {
			var i = 0;
			while (i < list.length) {
				var f = list[i];
				i++;
				if (f == null)
					continue;
				var sel = f.name == SaberJsonlArchive.loadedName;
				if (ImGui.selectable(f.name, sel, ImGuiSelectableFlags.None))
					SaberJsonlArchive.requestLoad(f.name);
			}
		}
		ImGui.endChild();
	}
}

@:keep
class SaberFileInfo {
	public var name:String = "";
	public var bytes:Int = 0;
	public var mtime:Float = 0;

	public function new() {}
}

@:keep
class SaberJsonlArchive {
	static inline var MAX_EVENTS:Int = 400;
	static inline var MAX_BYTES:Int = 2 * 1024 * 1024;
	static inline var LINES_PER_TICK:Int = 400;
	static inline var LIST_REFRESH_S:Float = 1.0;

	public static var status:String = "no file";
	public static var loadedName:String = "";

	static var files:Array<SaberFileInfo> = [];
	static var lastListAt:Float = 0;
	static var pendingName:String = "";
	static var pendingLines:Array<String> = [];
	static var pendingAt:Int = 0;
	static var building:Array<LightsaberHit> = [];
	static var rows:Array<LightsaberHit> = [];
	static var ready:Bool = false;
	static var loadGen:Int = 0;

	public static function keep():Void {}

	public static function fileList():Array<SaberFileInfo> {
		return files;
	}

	public static function loadedRows():Array<LightsaberHit> {
		return rows;
	}

	public static function isReady():Bool {
		return ready;
	}

	public static function gen():Int {
		return loadGen;
	}

	public static function requestLoad(name:String):Void {
		if (name == null || name.length == 0)
			return;
		if (name.indexOf("/") >= 0 || name.indexOf("\\") >= 0 || name.indexOf("..") >= 0) {
			status = "bad name";
			return;
		}
		pendingName = name;
		pendingLines = [];
		pendingAt = 0;
		building = [];
		ready = false;
		status = "loading " + name;
	}

	public static function tick():Void {
		refreshList();
		if (pendingName.length > 0 && pendingLines.length == 0)
			beginRead();
		if (pendingLines.length > 0)
			pumpParse();
	}

	static function refreshList():Void {
		var now = stamp();
		if (now - lastListAt < LIST_REFRESH_S && files.length > 0)
			return;
		lastListAt = now;
		var dir = logDir();
		if (dir == null)
			return;
		var next:Array<SaberFileInfo> = [];
		try {
			if (!sys.FileSystem.exists(dir) || !sys.FileSystem.isDirectory(dir))
				return;
			var names = sys.FileSystem.readDirectory(dir);
			var i = 0;
			while (i < names.length) {
				var n = names[i];
				i++;
				if (n == null || n.length < 12)
					continue;
				if (!StringTools.startsWith(n, "saber-") || !StringTools.endsWith(n, ".jsonl"))
					continue;
				var fp = haxe.io.Path.join([dir, n]);
				var info = new SaberFileInfo();
				info.name = n;
				try {
					var st = sys.FileSystem.stat(fp);
					if (st != null) {
						info.bytes = st.size;
						if (st.mtime != null)
							info.mtime = st.mtime.getTime();
					}
				} catch (_:Dynamic) {}
				next.push(info);
			}
		} catch (_:Dynamic) {}
		next.sort(function(a, b) {
			if (a.mtime == b.mtime)
				return 0;
			return a.mtime > b.mtime ? -1 : 1;
		});
		files = next;
	}

	static function beginRead():Void {
		var name = pendingName;
		var dir = logDir();
		if (dir == null) {
			pendingName = "";
			status = "no saber dir";
			return;
		}
		var fp = haxe.io.Path.join([dir, name]);
		try {
			if (!sys.FileSystem.exists(fp) || sys.FileSystem.isDirectory(fp)) {
				pendingName = "";
				status = "not found";
				return;
			}
			var st = sys.FileSystem.stat(fp);
			if (st != null && st.size > MAX_BYTES) {
				pendingName = "";
				status = "too large (" + Std.string(Std.int(st.size / 1024)) + " KB)";
				return;
			}
			var raw = sys.io.File.getContent(fp);
			pendingLines = raw.split("\n");
			pendingAt = 0;
			building = [];
			loadedName = name;
			status = "parsing " + name;
		} catch (_:Dynamic) {
			pendingName = "";
			pendingLines = [];
			status = "read fail";
		}
	}

	static function pumpParse():Void {
		var n = pendingLines.length;
		var take = 0;
		while (pendingAt < n && take < LINES_PER_TICK && building.length < MAX_EVENTS) {
			var line = pendingLines[pendingAt];
			pendingAt++;
			take++;
			if (line == null)
				continue;
			line = StringTools.trim(line);
			if (line.length == 0)
				continue;
			var o:Dynamic = null;
			try
				o = haxe.Json.parse(line)
			catch (_:Dynamic)
				continue;
			var hit = LightsaberHit.fromJson(o);
			if (hit == null)
				continue;
			building.push(hit);
		}
		if (building.length >= MAX_EVENTS && pendingAt < n)
			status = "capped at " + MAX_EVENTS + "  " + loadedName;
		if (pendingAt >= n || building.length >= MAX_EVENTS) {
			rows = building;
			building = [];
			pendingLines = [];
			pendingAt = 0;
			pendingName = "";
			ready = true;
			loadGen++;
			if (status.indexOf("capped") < 0)
				status = loadedName + "  " + rows.length + " hits";
		} else {
			status = "parsing " + loadedName + "  " + pendingAt + "/" + n;
		}
	}

	static function logDir():String {
		solarflare.ui.SettingsStore.migrateSaberLogs();
		return solarflare.ui.SettingsStore.logSubdir("saber");
	}

	static function stamp():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}
}
