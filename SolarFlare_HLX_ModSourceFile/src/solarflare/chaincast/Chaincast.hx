package solarflare.chaincast;

import solarflare.ui.GameIcons;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.ByteUtil;
import solarflare.EngineSkillId;
import solarflare.geaux.GeauxCache;
import solarflare.geaux.GeauxCache.GeauxSlotSnap;
import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Theme;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;

/**
 * Mage Chaincast snapshot. Accumul is Mage_Talent_Chaincast_Accum_Status
 * (maxStacks 4). Ready is Mage_Talent_Chaincast_Status (free weapon skill).
 * Engine owns apply/clear; we only mirror.
 */
class ChaincastCache {
	public static inline var ACCUM_MAX:Int = 4;
	public static inline var SLOT_COUNT:Int = 5;

	public static var active:Bool = false;
	public static var current:Int = 0;
	public static var max:Int = ACCUM_MAX;
	public static var valid:Bool = false;
	public static var ready:Bool = false;
	public static var remainLeft:Float = 0;
	public static var remainProg:Float = 0;
	public static var remainValid:Bool = false;
	public static var readyLeft:Float = 0;
	public static var readyProgress:Float = 0;
	public static var alertUntil:Float = 0;
	public static var pulseUntil:Float = 0;
	static var lastShown:Int = 0;

	static var talentKey:String = "Mage_Talent_Chaincast";
	static var talentHash:String = "";
	static var statusKey:String = "Mage_Talent_Chaincast_Status";
	static var accumKey:String = "Mage_Talent_Chaincast_Accum_Status";
	static var hashesReady:Bool = false;

	public static function clear():Void {
		active = false;
		current = 0;
		max = ACCUM_MAX;
		valid = false;
		ready = false;
		remainLeft = 0;
		remainProg = 0;
		remainValid = false;
		readyLeft = 0;
		readyProgress = 0;
		alertUntil = 0;
		pulseUntil = 0;
		lastShown = 0;
	}

	public static function noteMage():Void {
		active = true;
		max = ACCUM_MAX;
	}

	public static function setAccum(stacks:Int):Void {
		var n = stacks;
		if (n < 0)
			n = 0;
		if (n > ACCUM_MAX)
			n = ACCUM_MAX;
		current = n;
		max = ACCUM_MAX;
		ready = false;
		valid = true;
		active = true;
		notePulse(n);
	}

	public static function setRemain(left:Float, progress:Float, validRemain:Bool):Void {
		remainLeft = left >= 0 ? left : 0;
		var p = progress;
		if (p < 0)
			p = 0;
		if (p > 1)
			p = 1;
		remainProg = p;
		remainValid = validRemain && remainLeft > 0.02;
		readyLeft = remainLeft;
		readyProgress = remainProg;
	}

	public static function setReady():Void {
		var was = ready;
		current = ACCUM_MAX;
		max = ACCUM_MAX;
		ready = true;
		valid = true;
		active = true;
		notePulse(SLOT_COUNT);
		if (!was)
			alertUntil = solarflare.ui.ResourceMaxAlert.nowSec() + solarflare.ui.ResourceMaxAlert.ALERT_SEC;
	}

	static function notePulse(shown:Int):Void {
		if (shown > lastShown)
			pulseUntil = solarflare.ui.ResourceMaxAlert.nowSec() + 0.55;
		lastShown = shown;
	}

	public static function shownCount():Int {
		if (ready)
			return SLOT_COUNT;
		if (current < 0)
			return 0;
		return current;
	}

	public static function pulseActive():Bool {
		return solarflare.ui.ResourceMaxAlert.nowSec() < pulseUntil;
	}

	public static function alertActive():Bool {
		return solarflare.ui.ResourceMaxAlert.active(alertUntil);
	}

	public static function set(stacks:Int, cap:Int = -1):Void {
		setAccum(stacks);
	}

	public static function talentId():String {
		ensureHashes();
		return talentKey;
	}

	public static function talentHashId():String {
		ensureHashes();
		return talentHash;
	}

	public static function statusId():String {
		ensureHashes();
		return statusKey;
	}

	public static function accumId():String {
		ensureHashes();
		return accumKey;
	}

	public static function lookupReadyIds():Array<String> {
		ensureHashes();
		return [statusKey];
	}

	public static function lookupAccumIds():Array<String> {
		ensureHashes();
		return [accumKey];
	}

	public static function isChaincastKind(id:String):Bool {
		if (id == null || id.length == 0)
			return false;
		ensureHashes();
		var shown = solarflare.EngineSkillId.display(id);
		var s = shown != null && shown.length > 0 ? shown : id;
		if (s == talentKey || s == statusKey || s == accumKey)
			return true;
		if (talentHash.length > 0 && (s == talentHash || id == talentHash))
			return true;
		var low = s.toLowerCase();
		return low.indexOf("mage_talent_chaincast") >= 0
			|| low.indexOf("chaincast_accum") >= 0
			|| low.indexOf("chaincast_status") >= 0
			|| low == "chaincast";
	}

	public static function isReadyKind(id:String):Bool {
		if (id == null || id.length == 0)
			return false;
		ensureHashes();
		var shown = solarflare.EngineSkillId.display(id);
		var s = shown != null && shown.length > 0 ? shown : id;
		if (s == statusKey)
			return true;
		var low = s.toLowerCase();
		if (low.indexOf("accum") >= 0)
			return false;
		return low.indexOf("mage_talent_chaincast_status") >= 0
			|| (low.indexOf("chaincast_status") >= 0 && low.indexOf("accum") < 0);
	}

	public static function isAccumKind(id:String):Bool {
		if (id == null || id.length == 0)
			return false;
		ensureHashes();
		var shown = solarflare.EngineSkillId.display(id);
		var s = shown != null && shown.length > 0 ? shown : id;
		if (s == accumKey)
			return true;
		var low = s.toLowerCase();
		return low.indexOf("chaincast_accum") >= 0
			|| low.indexOf("mage_talent_chaincast_accum") >= 0;
	}

	public static function isMageSkillId(id:String):Bool {
		if (id == null || id.length == 0)
			return false;
		ensureHashes();
		if (isChaincastKind(id))
			return true;
		var s = id.toLowerCase();
		return s.indexOf("mage_") == 0;
	}

	static function ensureHashes():Void {
		if (hashesReady)
			return;
		hashesReady = true;
		try {
			var h = script.skills.Mage_Talent_Chaincast.HASH;
			if (h != null && h.length > 0)
				talentHash = h;
		} catch (_:Dynamic) {}
	}
}

/**
 * F6 → Chaincast. Hide + size + lock/transparent chrome.
 * Mirrors Mage_Talent_Chaincast_Accum_Status stacks; layout is ours to move/resize.
 */
class ChaincastConfig {
	public static inline var MIN_W:Single = 220;
	public static inline var MAX_W:Single = 720;
	public static inline var MIN_H:Single = 96;
	public static inline var MAX_H:Single = 480;
	public static inline var MAX_ROT:Int = 6;
	public static inline var TITLE_BUF:Int = 80;

	public var open = new BoolRef(false);
	public var hidden = new BoolRef(false);
	public var width = new FloatRef(320);
	public var height = new FloatRef(200);
	public var sizeDirty = true;
	public var chrome:HudChrome;
	public var title:String = "Chaincast";
	public var rotation:Array<String> = [];
	public var spendId:String = "";
	/** Left stack badge (N/4 or READY). Hide to use pip rail only. */
	public var showStackBadge = new BoolRef(true);
	public var titleBuf:hl.Bytes;

	public function new() {
		chrome = new HudChrome(40, 210);
		titleBuf = new hl.Bytes(TITLE_BUF);
		syncTitleBuf();
	}

	public function syncTitleBuf():Void {
		fillBuf(titleBuf, TITLE_BUF, title);
	}

	public function draw():Void {
		if (!open.get())
			return;
		ImGui.setNextWindowSize(ImGui.vec2(400, 0), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel("Chaincast", open, "Chaincast")) {
			if (ImGui.checkbox("Hide overlay##chain_hidden", hidden))
				SettingsStore.markDirty();
			chrome.drawToggles("chaincast");
			if (ImGui.sliderFloat("Width", width, MIN_W, MAX_W, "%.0f px")) {
				sizeDirty = true;
				SettingsStore.markDirty();
			}
			if (ImGui.sliderFloat("Height", height, MIN_H, MAX_H, "%.0f px")) {
				sizeDirty = true;
				SettingsStore.markDirty();
			}
			drawSettings();
		}
		HudChrome.endPanel();
	}

	public function drawSettings():Void {
		ImGui.textWrapped("4 skill procs charge the rail. Ready gem: next weapon skill has no CD and no Spark, and triggers Conduits. Stack badge = talent progress (not Geaux skill charges).");
		if (ImGui.checkbox("Show stack count badge##chain_badge", showStackBadge))
			SettingsStore.markDirty();
		if (ImGui.inputText("Title##chain_title", titleBuf, TITLE_BUF)) {
			title = bytesToString(titleBuf, TITLE_BUF);
			SettingsStore.markDirty();
		}
		ImGui.separatorText("Next-cast list");
		ImGui.textWrapped("Pick from your action bar and class skills. Highlight is a reminder only.");
		var i = 0;
		while (i < rotation.length) {
			var id = rotation[i];
			var snap = GeauxCache.findSnap(id);
			var lab = snapLabel(snap, id);
			ImGui.alignTextToFramePadding();
			ImGui.text((i + 1) + ". " + lab);
			ImGui.sameLine();
			if (ImGui.smallButton("Up##chup" + i) && i > 0) {
				var tmp = rotation[i - 1];
				rotation[i - 1] = rotation[i];
				rotation[i] = tmp;
				SettingsStore.markDirty();
			}
			ImGui.sameLine();
			if (ImGui.smallButton("Dn##chdn" + i) && i < rotation.length - 1) {
				var tmp = rotation[i + 1];
				rotation[i + 1] = rotation[i];
				rotation[i] = tmp;
				SettingsStore.markDirty();
			}
			ImGui.sameLine();
			if (ImGui.smallButton("X##chrm" + i)) {
				if (spendId == id)
					spendId = "";
				rotation.splice(i, 1);
				SettingsStore.markDirty();
				continue;
			}
			i++;
		}
		if (rotation.length < MAX_ROT) {
			var preview = "Add skill";
			if (ImGui.beginCombo("##chain_add", preview)) {
				var seen = new Map<String, Bool>();
				addComboSnaps(GeauxCache.weapons, seen);
				addComboSnaps(GeauxCache.slots, seen);
				addComboSnaps(GeauxCache.signatures, seen);
				ImGui.endCombo();
			}
		}
		var spendPrev = spendId.length > 0 ? snapLabel(GeauxCache.findSnap(spendId), spendId) : "(first weapon in list)";
		if (ImGui.beginCombo("Spend Chaincast on##chain_spend", spendPrev)) {
			if (ImGui.selectable("(first weapon in list)", spendId.length == 0)) {
				spendId = "";
				SettingsStore.markDirty();
			}
			for (id in rotation) {
				if (ImGui.selectable(snapLabel(GeauxCache.findSnap(id), id), spendId == id)) {
					spendId = GeauxCache.coerceSkillId(id);
					if (spendId.length == 0)
						spendId = GeauxCache.sanitizeSkillId(id);
					SettingsStore.markDirty();
				}
			}
			ImGui.endCombo();
		}
	}

	function addComboSnaps(list:Array<GeauxSlotSnap>, seen:Map<String, Bool>):Void {
		if (list == null)
			return;
		for (s in list) {
			if (s == null || s.id == null || s.id.length == 0)
				continue;
			if (seen.exists(s.id))
				continue;
			seen.set(s.id, true);
			if (rotation.indexOf(s.id) >= 0)
				continue;
			var g = s.group != null ? s.group : "";
			if (g != "WEP" && g != "BAR" && g != "CLS" && g != "SIG" && g != "")
				continue;
			if (ImGui.selectable(snapLabel(s, s.id), false)) {
				var addId = GeauxCache.coerceSkillId(s.id);
				if (addId.length == 0)
					addId = GeauxCache.sanitizeSkillId(s.id);
				if (addId.length > 0)
					rotation.push(addId);
				SettingsStore.markDirty();
			}
		}
	}

	public static function snapLabel(snap:GeauxSlotSnap, id:String):String {
		if (snap != null && snap.label != null && snap.label.length > 0) {
			var lab = snap.label;
			if (lab.indexOf("{") < 0 && lab.toLowerCase().indexOf("bytes") < 0 && lab.indexOf("haxe.io") < 0)
				return lab;
		}
		var clean = GeauxCache.coerceSkillId(id);
		if (clean.length == 0)
			clean = GeauxCache.sanitizeSkillId(id);
		var short = GeauxCache.shortLabel(clean.length > 0 ? clean : id);
		if (short != null && short.length > 0)
			return short;
		var shown = EngineSkillId.display(clean.length > 0 ? clean : id);
		if (shown != null && shown.length > 0 && shown.indexOf("{") < 0 && shown.toLowerCase().indexOf("bytes") < 0)
			return shown;
		return "";
	}

	static function fillBuf(buf:hl.Bytes, cap:Int, s:String):Void ByteUtil.fillBuf(buf, cap, s);

	static function bytesToString(buf:hl.Bytes, max:Int):String {
		return ByteUtil.readString(buf, max);
	}

	public static function isWeaponSnap(snap:GeauxSlotSnap):Bool {
		if (snap == null)
			return false;
		var g = snap.group != null ? snap.group : "";
		return g == "WEP" || g == "BAR";
	}
}

/**
 * Movable/resizable block gauge for mage Chaincast stacks.
 * Reads ChaincastCache only — never live status objects from the draw loop.
 */
class ChaincastOverlay {
	static inline var FLAGS:Int = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse
		| ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse;
	static inline var PAD:Single = 6;

	var theme:Theme;

	public function new() {
		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(PAD, PAD))
			.varF(ImGuiStyleVar.WindowRounding, 8)
			.varF(ImGuiStyleVar.WindowBorderSize, 0)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0.05, 0.07, 0.12, 0.55))
			.color(ImGuiCol.Border, ImGui.vec4(0.35, 0.55, 0.90, 0.35))
			.color(ImGuiCol.ResizeGrip, ImGui.vec4(0.45, 0.65, 0.95, 0.40));
	}

	public function draw(cfg:ChaincastConfig):Void {
		if (cfg == null || cfg.hidden.get())
			return;
		if (!ChaincastCache.active)
			return;
		theme.wrap(() -> drawWindow(cfg));
	}

	function drawWindow(cfg:ChaincastConfig):Void {
		var w:Single = cfg.width.get();
		var h:Single = cfg.height.get();
		if (w < ChaincastConfig.MIN_W)
			w = ChaincastConfig.MIN_W;
		if (w > ChaincastConfig.MAX_W)
			w = ChaincastConfig.MAX_W;
		if (h < ChaincastConfig.MIN_H)
			h = ChaincastConfig.MIN_H;
		if (h > ChaincastConfig.MAX_H)
			h = ChaincastConfig.MAX_H;

		var trans = cfg.chrome != null && cfg.chrome.isTransparent();
		ImGui.setNextWindowBgAlpha(trans ? 0 : 0.42);
		ImGui.setNextWindowSizeConstraints(
			ImGui.vec2(ChaincastConfig.MIN_W, ChaincastConfig.MIN_H),
			ImGui.vec2(ChaincastConfig.MAX_W, ChaincastConfig.MAX_H)
		);
		if (cfg.chrome != null && cfg.chrome.takeExpandDirty())
			cfg.sizeDirty = true;
		if (cfg.sizeDirty) {
			ImGui.setNextWindowSize(ImGui.vec2(w, h), ImGuiCond.Always);
			cfg.sizeDirty = false;
		} else {
			ImGui.setNextWindowSize(ImGui.vec2(w, h), ImGuiCond.FirstUseEver);
		}
		if (cfg.chrome != null) {
			cfg.chrome.clampToViewport();
			cfg.chrome.applyPos();
			if (!cfg.chrome.collapsed.get())
				ImGui.setNextWindowPos(ImGui.vec2(cfg.chrome.x.get(), cfg.chrome.y.get()), ImGuiCond.FirstUseEver);
		} else {
			ImGui.setNextWindowPos(ImGui.vec2(40, 210), ImGuiCond.FirstUseEver);
		}

		var flags = cfg.chrome != null ? cfg.chrome.windowFlags(FLAGS) : FLAGS;
		var began = ImGui.begin("SolarFlare Chaincast", null, flags);
		if (began) {
			if (cfg.chrome != null && !cfg.chrome.isLocked()) {
				cfg.chrome.capturePos();
				var win = ImGui.getWindowSize();
				if (Math.abs(win.x - cfg.width.get()) > 1 || Math.abs(win.y - cfg.height.get()) > 1)
					SettingsStore.markDirty();
				cfg.width.set(win.x);
				cfg.height.set(win.y);
			}
			var showBody = cfg.chrome == null || cfg.chrome.beginBody(function() {
				cfg.hidden.set(true);
				SettingsStore.markDirty();
			}, null, captionOf(cfg));
			if (showBody) {
				var avail = ImGui.getContentRegionAvail();
			var rowW:Single = avail.x > 1 ? avail.x : 1;
			var rowH:Single = avail.y > 1 ? avail.y : ChaincastConfig.MIN_H;
			if (ChaincastCache.alertActive()) {
				solarflare.ui.ResourceMaxAlert.drawToast(rowW, solarflare.ui.ResourceMaxAlert.TOAST_H);
				rowH -= solarflare.ui.ResourceMaxAlert.TOAST_H;
				if (rowH < 16)
					rowH = 16;
			}
			var hintN = cfg.rotation != null ? cfg.rotation.length : 0;
			var timerH:Single = ChaincastCache.remainValid ? 28 : 0;
			var hintH:Single = hintN > 0 ? hintN * 22 : 0;
			var headH:Single = rowH - timerH - hintH;
			if (headH < 40)
				headH = 40;
			drawHead(cfg, rowW, headH);
			if (ChaincastCache.remainValid)
				drawTimer(rowW, timerH > 8 ? timerH : 28);
			if (hintN > 0)
				drawHints(cfg, rowW);
			}
		}
		HudChrome.endOverlayWindow(began, cfg.chrome);
	}

	static function captionOf(cfg:ChaincastConfig):String {
		if (cfg != null && cfg.title != null && cfg.title.length > 0)
			return cfg.title;
		return "Chaincast";
	}

	static function drawHead(cfg:ChaincastConfig, rowW:Single, rowH:Single):Void {
		var showBadge = cfg == null || cfg.showStackBadge == null || cfg.showStackBadge.get();
		var stacks = ChaincastCache.valid ? ChaincastCache.current : 0;
		var ready = ChaincastCache.ready;
		var pulse = ready || ChaincastCache.pulseActive();
		ChaincastRenderer.drawHead(rowW, rowH, stacks, ready, showBadge, pulse);
	}

	static function drawTimer(rowW:Single, rowH:Single):Void {
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var left = ChaincastCache.remainLeft;
		var prog = ChaincastCache.remainProg;
		if (prog < 0)
			prog = 0;
		if (prog > 1)
			prog = 1;
		var label = "CHAIN TIME REMAINING: " + formatReadyLeft(left) + "s";
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(origin.x + 2, origin.y), u32(0.75, 0.88, 1.0, 0.95), label);
		var barY:Single = origin.y + 14;
		var barH:Single = rowH - 16;
		if (barH < 6)
			barH = 6;
		var x1:Single = origin.x + rowW;
		var y1:Single = barY + barH;
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(origin.x, barY), ImGui.vec2(x1, y1), u32(0.06, 0.08, 0.12, 0.95), 3);
		var fillW:Single = rowW * prog;
		if (fillW > 1)
			ImGui.ImDrawList_AddRectFilledMultiColor(dl, ImGui.vec2(origin.x, barY), ImGui.vec2(origin.x + fillW, y1),
				u32(0.15, 0.45, 0.95, 0.90),
				u32(0.45, 0.85, 1.0, 0.90),
				u32(0.20, 0.40, 0.85, 0.75),
				u32(0.10, 0.25, 0.55, 0.75));
		ImGui.dummy(ImGui.vec2(rowW, rowH));
	}

	static function drawHints(cfg:ChaincastConfig, rowW:Single):Void {
		var hi = highlightIndex(cfg);
		var i = 0;
		while (i < cfg.rotation.length) {
			var id = cfg.rotation[i];
			var snap = GeauxCache.findSnap(id);
			var lab = ChaincastConfig.snapLabel(snap, id);
			var cd = snap != null ? snap.cdLeft : 0;
			var ready = snap != null && snap.ready && snap.affordable;
			var active = i == hi;
			var prefix = "[" + Std.string(i + 1) + "] ";
			var tail = "";
			if (active)
				tail = "  [ACTIVE]";
			else if (cd > 0.05)
				tail = "  " + formatReadyLeft(cd) + "s";
			else if (ready)
				tail = "  ready";
			var col = active ? u32(0.45, 0.95, 1.0, 1) : u32(0.70, 0.78, 0.88, 0.72);
			var origin = ImGui.getCursorScreenPos();
			var dl = ImGui.getWindowDrawList();
			var icon:hl.I64 = 0;
			if (snap != null) {
				if (snap.iconId != null && snap.iconId.length > 0)
					icon = GameIcons.get(snap.iconId);
				if (icon == 0 && snap.iconCandidates != null) {
					for (c in snap.iconCandidates) {
						icon = GameIcons.get(c);
						if (icon.toInt() != 0)
							break;
					}
				}
			}
			if (icon.toInt() != 0)
				GameIcons.draw(dl, icon, origin.x, origin.y, 18, active ? 0xFFFFFFFF : u32(1, 1, 1, 0.45));
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(origin.x + 22, origin.y + 2), col, prefix + lab + tail);
			ImGui.dummy(ImGui.vec2(rowW, 22));
			i++;
		}
	}

	static function highlightIndex(cfg:ChaincastConfig):Int {
		if (cfg == null || cfg.rotation == null || cfg.rotation.length == 0)
			return -1;
		if (ChaincastCache.ready) {
			if (cfg.spendId != null && cfg.spendId.length > 0) {
				var si = cfg.rotation.indexOf(cfg.spendId);
				if (si >= 0)
					return si;
			}
			var w = 0;
			while (w < cfg.rotation.length) {
				var snap = GeauxCache.findSnap(cfg.rotation[w]);
				if (ChaincastConfig.isWeaponSnap(snap))
					return w;
				w++;
			}
			return 0;
		}
		var best = -1;
		var bestCd = 1e9;
		var j = 0;
		while (j < cfg.rotation.length) {
			var snap = GeauxCache.findSnap(cfg.rotation[j]);
			if (snap != null && snap.ready && snap.affordable) {
				var cd = snap.cdLeft;
				if (cd < bestCd) {
					bestCd = cd;
					best = j;
				}
			}
			j++;
		}
		return best;
	}

	static function formatReadyLeft(sec:Float):String {
		var n = sec;
		if (n < 0)
			n = 0;
		if (n >= 9.95)
			return Std.string(Std.int(Math.ceil(n)));
		var t = Math.floor(n * 10 + 0.5) / 10;
		return Std.string(t);
	}

	static function u32(r:Float, g:Float, b:Float, a:Float):Int {
		return ImGui.colorConvertFloat4ToU32(ImGui.vec4(r, g, b, a));
	}
}
