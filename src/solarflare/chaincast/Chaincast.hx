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
		ImGui.textWrapped("4 skill procs charge the rail. Ready gem: next weapon skill has no CD and no Spark, and triggers Conduits.");
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
					spendId = id;
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
				rotation.push(s.id);
				SettingsStore.markDirty();
			}
		}
	}

	public static function snapLabel(snap:GeauxSlotSnap, id:String):String {
		if (snap != null && snap.label != null && snap.label.length > 0)
			return snap.label;
		var shown = EngineSkillId.display(id);
		if (shown != null && shown.length > 0)
			return shown;
		return id;
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
	static inline var GAP:Single = 6;

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
		var numW:Single = rowW * 0.28;
		if (numW < 48)
			numW = 48;
		if (numW > 90)
			numW = 90;
		drawCount(numW, rowH);
		ImGui.sameLine(0, 8);
		var pipW:Single = rowW - numW - 8;
		if (pipW < 80)
			pipW = 80;
		drawBlocks(pipW, rowH);
	}

	static function drawCount(w:Single, h:Single):Void {
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var n = ChaincastCache.shownCount();
		var txt = Std.string(n);
		var pulse:Single = 1;
		if (ChaincastCache.ready || ChaincastCache.pulseActive()) {
			try
				pulse = 0.70 + 0.30 * Math.sin(haxe.Timer.stamp() * 8)
			catch (_:Dynamic)
				pulse = 1;
		}
		ImGui.ImDrawList_AddRectFilled(dl, origin, ImGui.vec2(origin.x + w, origin.y + h),
			u32(0.04, 0.06, 0.12, 0.92), 6);
		var ts = ImGui.calcTextSize(txt);
		var tx:Single = origin.x + (w - ts.x) * 0.5;
		var ty:Single = origin.y + (h - ts.y) * 0.5;
		if (ChaincastCache.pulseActive() || ChaincastCache.ready)
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx + 1, ty + 1), u32(0.25, 0.55, 1.0, 0.55 * pulse), txt);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty),
			ChaincastCache.ready ? u32(0.82, 0.94, 1.0, 0.70 + 0.30 * pulse) : u32(0.95, 0.97, 1.0, 1), txt);
		ImGui.dummy(ImGui.vec2(w, h));
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

	static function drawBlocks(rowW:Single, rowH:Single):Void {
		var n = ChaincastCache.SLOT_COUNT;
		var accumMax = ChaincastCache.ACCUM_MAX;
		var filled = ChaincastCache.valid ? ChaincastCache.current : 0;
		if (filled < 0)
			filled = 0;
		if (filled > accumMax)
			filled = accumMax;
		var ready = ChaincastCache.ready;

		var gap:Single = GAP;
		var blockW:Single = (rowW - gap * (n - 1)) / n;
		if (blockW < 8)
			blockW = 8;
		var blockH:Single = rowH;
		if (blockH < 16)
			blockH = 16;

		var accumIcon = GameIcons.get(GameIcons.CHAINCAST);
		if (accumIcon == 0)
			accumIcon = GameIcons.get(GameIcons.CHAINCAST_FALLBACK);
		var readyIcon = GameIcons.get(GameIcons.CHAINCAST_FALLBACK);
		if (readyIcon == 0)
			readyIcon = accumIcon;
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var midY:Single = origin.y + blockH * 0.5;
		var pulse:Single = 1;
		if (ready) {
			try
				pulse = 0.62 + 0.38 * Math.sin(haxe.Timer.stamp() * 7.5)
			catch (_:Dynamic)
				pulse = 1;
		}

		var x0:Single = origin.x + blockW * 0.5;
		var x1:Single = origin.x + (blockW + gap) * (n - 1) + blockW * 0.5;
		var railA:Single = ready ? (0.42 + 0.38 * pulse) : 0.28;
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x0, midY), ImGui.vec2(x1, midY), u32(0.08, 0.10, 0.16, 0.95), 7);
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x0, midY), ImGui.vec2(x1, midY), u32(0.32, 0.55, 0.92, railA), 3);
		if (ready)
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x0, midY), ImGui.vec2(x1, midY), u32(0.70, 0.88, 1.0, 0.18 * pulse), 1.25);

		for (i in 0...n) {
			var x:Single = origin.x + (blockW + gap) * i;
			var cx:Single = x + blockW * 0.5;
			var isReadySlot = i == accumMax;
			var lit = isReadySlot ? ready : (ready || i < filled);
			var well = ImGui.vec2(x, origin.y);
			var well2 = ImGui.vec2(x + blockW, origin.y + blockH);

			if (isReadySlot) {
				var rad:Single = (blockW < blockH ? blockW : blockH) * 0.46;
				if (rad < 10)
					rad = 10;
				ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, midY), rad + 3,
					ready ? u32(0.45, 0.78, 1.0, 0.22 * pulse) : u32(0.10, 0.14, 0.22, 0.55), 20);
				ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, midY), rad,
					ready ? u32(0.10, 0.22, 0.48, 0.92) : u32(0.05, 0.06, 0.10, 0.94), 20);
				if (ready)
					ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, midY), rad * 0.82,
						u32(0.22, 0.48, 0.88, 0.45 + 0.28 * pulse), 18);
			} else {
				var rounding:Single = 5;
				ImGui.ImDrawList_AddRectFilled(dl, well, well2, u32(0.04, 0.05, 0.08, 0.94), rounding);
				if (lit) {
					ImGui.ImDrawList_AddRectFilled(dl,
						ImGui.vec2(x + 1, origin.y + 1),
						ImGui.vec2(x + blockW - 1, origin.y + blockH - 1),
						u32(0.14, 0.28, 0.58, 0.55), rounding);
					ImGui.ImDrawList_AddRectFilledMultiColor(dl,
						ImGui.vec2(x + 2, origin.y + 2),
						ImGui.vec2(x + blockW - 2, origin.y + blockH - 2),
						u32(0.38, 0.62, 1.0, 0.22),
						u32(0.22, 0.38, 0.78, 0.10),
						u32(0.12, 0.18, 0.42, 0.28),
						u32(0.18, 0.32, 0.62, 0.16));
				} else {
					ImGui.ImDrawList_AddRect(dl,
						ImGui.vec2(x + 2, origin.y + 2),
						ImGui.vec2(x + blockW - 2, origin.y + blockH - 2),
						u32(1, 1, 1, 0.04), rounding, 1);
				}
			}

			var pad:Single = isReadySlot ? 7 : 5;
			var side:Single = blockW < blockH ? blockW : blockH;
			side = side - pad * 2;
			if (side < 8)
				side = 8;
			var ix:Single = cx - side * 0.5;
			var iy:Single = midY - side * 0.5;
			var icon = isReadySlot ? readyIcon : accumIcon;
			if (lit)
				GameIcons.draw(dl, icon, ix, iy, side, 0xFFFFFFFF);
			else if (!isReadySlot)
				GameIcons.draw(dl, icon, ix, iy, side, u32(1, 1, 1, 0.16));

			if (isReadySlot) {
				var rad:Single = (blockW < blockH ? blockW : blockH) * 0.46;
				if (rad < 10)
					rad = 10;
				ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, midY), rad,
					ready ? u32(0.78, 0.92, 1.0, 0.50 + 0.45 * pulse) : u32(0.28, 0.36, 0.48, 0.80),
					20, ready ? 2.0 : 1.25);
			} else {
				ImGui.ImDrawList_AddRect(dl, well, well2,
					lit ? u32(0.62, 0.82, 1.0, 0.78) : u32(0.20, 0.26, 0.36, 0.90),
					5, lit ? 1.5 : 1.15);
			}
		}
		ImGui.dummy(ImGui.vec2(rowW, blockH));
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
