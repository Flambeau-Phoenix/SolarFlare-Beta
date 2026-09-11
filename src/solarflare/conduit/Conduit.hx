package solarflare.conduit;

import solarflare.EngineSkillId;
import solarflare.ui.GameIcons;
import solarflare.ui.HudChrome;
import solarflare.ui.PipShapes;
import solarflare.ui.SettingsStore;
import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Theme;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;

/** Frozen Sparkmaster slot for the conduit overlay. Draw reads this only. */
class ConduitSlotSnap {
	public var id:String = "";
	public var filled:Bool = false;
	public var stacks:Int = 0;
	public var power:Bool = false;

	public function new() {}
}

/** Frozen conduit proc/buff for HealthHooks sampling. Draw does not read this. */
class ConduitProcSnap {
	public var id:String = "";
	public var stacks:Int = 0;
	public var left:Float = 0;
	public var power:Bool = false;

	public function new() {}
}

/**
 * Mage conduit snapshot. Sparkmaster slots plus live proc stacks (Power 0–20).
 * Engine owns spawn/despawn; we only mirror.
 */
class ConduitCache {
	public static inline var MAX_SLOTS:Int = 8;
	public static inline var POWER_MAX:Int = 20;
	public static inline var DEFAULT_SLOTS:Int = 3;

	public static var active:Bool = false;
	public static var current:Int = 0;
	public static var max:Int = POWER_MAX;
	public static var valid:Bool = false;
	public static var slotCount:Int = DEFAULT_SLOTS;
	public static var filledCount:Int = 0;
	public static var powerStacks:Int = 0;
	public static var powerLeft:Float = 0;
	public static var slots:Array<ConduitSlotSnap> = [];

	static var powerKey:String = "Mage_Conduit_Power";
	static var powerHash:String = "";
	static var projectileKey:String = "Mage_Conduit_Projectile";
	static var projectileHash:String = "";
	static var sparkKey:String = "Mage_Talent_ConduitSparkExplosion_Conduit";
	static var sparkHash:String = "";
	static var lifeKey:String = "Mage_Talent_ConduitLifebolt_Conduit";
	static var lifeHash:String = "";
	static var hashesReady:Bool = false;

	static function ensureSlots():Void {
		if (slots.length >= MAX_SLOTS)
			return;
		while (slots.length < MAX_SLOTS)
			slots.push(new ConduitSlotSnap());
	}

	static function resetSlot(s:ConduitSlotSnap):Void {
		if (s == null)
			return;
		s.id = "";
		s.filled = false;
		s.stacks = 0;
		s.power = false;
	}

	public static function clear():Void {
		ensureSlots();
		active = false;
		current = 0;
		max = POWER_MAX;
		valid = false;
		slotCount = DEFAULT_SLOTS;
		filledCount = 0;
		powerStacks = 0;
		powerLeft = 0;
		var i = 0;
		while (i < slots.length) {
			resetSlot(slots[i]);
			i++;
		}
	}

	public static function noteMage():Void {
		active = true;
		if (slotCount < 1)
			slotCount = DEFAULT_SLOTS;
	}

	/**
	 * Copy first `nSlots` entries from `next` into the stable `slots` buffer.
	 * Does not take ownership of `next` (scratch-safe).
	 */
	public static function setSlots(next:Array<ConduitSlotSnap>, nSlots:Int, filled:Int, power:Int, left:Float):Void {
		ensureSlots();
		var n = nSlots;
		if (n < 1)
			n = DEFAULT_SLOTS;
		if (n > MAX_SLOTS)
			n = MAX_SLOTS;
		var p = power;
		if (p < 0)
			p = 0;
		if (p > POWER_MAX)
			p = POWER_MAX;
		var f = filled;
		if (f < 0)
			f = 0;
		var i = 0;
		while (i < n) {
			var dst = slots[i];
			var src = next != null && i < next.length ? next[i] : null;
			if (src == null)
				resetSlot(dst);
			else {
				dst.id = src.id != null ? src.id : "";
				dst.filled = src.filled;
				dst.stacks = src.stacks;
				dst.power = src.power;
			}
			i++;
		}
		while (i < slots.length) {
			resetSlot(slots[i]);
			i++;
		}
		slotCount = n;
		filledCount = f;
		powerStacks = p;
		powerLeft = left >= 0 ? left : 0;
		current = p > 0 ? p : f;
		max = p > 0 ? POWER_MAX : n;
		valid = true;
		active = true;
	}

	public static function powerId():String {
		ensureHashes();
		return powerKey;
	}

	public static function powerHashId():String {
		ensureHashes();
		return powerHash;
	}

	public static function projectileId():String {
		ensureHashes();
		return projectileKey;
	}

	public static function projectileHashId():String {
		ensureHashes();
		return projectileHash;
	}

	public static function lookupIds():Array<String> {
		ensureHashes();
		var out = [powerKey, projectileKey, sparkKey, lifeKey];
		pushIfNew(out, powerHash);
		pushIfNew(out, projectileHash);
		pushIfNew(out, sparkHash);
		pushIfNew(out, lifeHash);
		return out;
	}

	public static function isPowerKind(id:String):Bool {
		var s = canonical(id);
		if (s.length == 0)
			return false;
		ensureHashes();
		if (s == powerKey || (powerHash.length > 0 && s == powerHash))
			return true;
		return idContains(s, "mage_conduit_power");
	}

	public static function isConduitKind(id:String):Bool {
		var s = canonical(id);
		if (s.length == 0)
			return false;
		ensureHashes();
		if (s == powerKey || s == projectileKey || s == sparkKey || s == lifeKey)
			return true;
		if (powerHash.length > 0 && s == powerHash)
			return true;
		if (projectileHash.length > 0 && s == projectileHash)
			return true;
		if (sparkHash.length > 0 && s == sparkHash)
			return true;
		if (lifeHash.length > 0 && s == lifeHash)
			return true;
		if (idContains(s, "mage_conduit_"))
			return true;
		if (idContains(s, "mage_talent_conduit"))
			return true;
		if (idContains(s, "conduit_shard") || idContains(s, "conduitshard"))
			return true;
		return false;
	}

	/** Case-insensitive substring without allocating a lowercased copy. */
	public static function idContains(hay:String, needle:String):Bool {
		if (hay == null || needle == null || needle.length == 0 || hay.length < needle.length)
			return false;
		var lim = hay.length - needle.length;
		var i = 0;
		while (i <= lim) {
			var j = 0;
			while (j < needle.length) {
				var a = hay.charCodeAt(i + j);
				var b = needle.charCodeAt(j);
				if (a >= 65 && a <= 90)
					a += 32;
				if (b >= 65 && b <= 90)
					b += 32;
				if (a != b)
					break;
				j++;
			}
			if (j == needle.length)
				return true;
			i++;
		}
		return false;
	}

	/** Case-insensitive equality without allocating. */
	public static function idEq(a:String, b:String):Bool {
		if (a == b)
			return true;
		if (a == null || b == null || a.length != b.length)
			return false;
		var i = 0;
		while (i < a.length) {
			var ca = a.charCodeAt(i);
			var cb = b.charCodeAt(i);
			if (ca >= 65 && ca <= 90)
				ca += 32;
			if (cb >= 65 && cb <= 90)
				cb += 32;
			if (ca != cb)
				return false;
			i++;
		}
		return true;
	}

	public static function canonical(id:String):String {
		if (id == null || id.length == 0)
			return "";
		var shown = EngineSkillId.display(id);
		if (shown != null && shown.length > 0)
			return shown;
		return id;
	}

	static function pushIfNew(out:Array<String>, id:String):Void {
		if (id == null || id.length == 0)
			return;
		for (x in out) {
			if (x == id)
				return;
		}
		out.push(id);
	}

	static function ensureHashes():Void {
		if (hashesReady)
			return;
		hashesReady = true;
		try {
			var h = script.skills.Mage_Conduit_Power.HASH;
			if (h != null && h.length > 0)
				powerHash = h;
		} catch (_:Dynamic) {}
		try {
			var h = script.skills.Mage_Conduit_Projectile.HASH;
			if (h != null && h.length > 0)
				projectileHash = h;
		} catch (_:Dynamic) {}
		try {
			var h = script.skills.Mage_Talent_ConduitSparkExplosion_Conduit.HASH;
			if (h != null && h.length > 0)
				sparkHash = h;
		} catch (_:Dynamic) {}
		try {
			var h = script.skills.Mage_Talent_ConduitLifebolt_Conduit.HASH;
			if (h != null && h.length > 0)
				lifeHash = h;
		} catch (_:Dynamic) {}
	}
}

/**
 * F6 → Conduits. Hide + size + pip shape + lock/transparent chrome.
 */
class ConduitConfig {
	public static inline var MIN_W:Single = 28;
	public static inline var MAX_W:Single = 720;
	public static inline var MIN_H:Single = 28;
	public static inline var MAX_H:Single = 420;

	public var open = new BoolRef(false);
	public var hidden = new BoolRef(false);
	public var vertical = new BoolRef(false);
	public var shape = new IntRef(PipShapes.DIAMOND);
	public var width = new FloatRef(220);
	public var height = new FloatRef(36);
	public var sizeDirty = true;
	public var chrome:HudChrome;

	public function new() {
		chrome = new HudChrome(40, 250);
	}

	public function draw():Void {
		if (!open.get())
			return;
		ImGui.setNextWindowSize(ImGui.vec2(360, 0), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel("Conduits", open, "Conduits")) {
			ImGui.text("Sparkmaster slots. Power stacks 0–20 while the buff is up.");
			if (ImGui.checkbox("Hide overlay##conduit_hidden", hidden))
				SettingsStore.markDirty();
			if (ImGui.checkbox("Vertical stack##conduit_vert", vertical))
				SettingsStore.markDirty();
			PipShapes.drawShapeCombo("Pip shape##conduit", shape);
			chrome.drawToggles("conduit");
			if (ImGui.sliderFloat("Width", width, MIN_W, MAX_W, "%.0f px")) {
				sizeDirty = true;
				SettingsStore.markDirty();
			}
			if (ImGui.sliderFloat("Height", height, MIN_H, MAX_H, "%.0f px")) {
				sizeDirty = true;
				SettingsStore.markDirty();
			}
		}
		HudChrome.endPanel();
	}
}

/**
 * Movable pip gauge for mage conduits. Reads ConduitCache only.
 */
class ConduitOverlay {
	static inline var FLAGS:Int = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse
		| ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse;
	static inline var PAD:Single = 4;

	var theme:Theme;

	public function new() {
		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(PAD, PAD))
			.varF(ImGuiStyleVar.WindowRounding, 4)
			.varF(ImGuiStyleVar.WindowBorderSize, 1)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0.06, 0.07, 0.12, 0.72))
			.color(ImGuiCol.Border, ImGui.vec4(0.28, 0.40, 0.62, 0.55))
			.color(ImGuiCol.ResizeGrip, ImGui.vec4(0.40, 0.55, 0.80, 0.45));
	}

	public function draw(cfg:ConduitConfig):Void {
		if (cfg == null || cfg.hidden.get())
			return;
		if (!ConduitCache.active)
			return;
		theme.wrap(() -> drawWindow(cfg));
	}

	function drawWindow(cfg:ConduitConfig):Void {
		var w:Single = cfg.width.get();
		var h:Single = cfg.height.get();
		if (w < ConduitConfig.MIN_W)
			w = ConduitConfig.MIN_W;
		if (w > ConduitConfig.MAX_W)
			w = ConduitConfig.MAX_W;
		if (h < ConduitConfig.MIN_H)
			h = ConduitConfig.MIN_H;
		if (h > ConduitConfig.MAX_H)
			h = ConduitConfig.MAX_H;

		var trans = cfg.chrome != null && cfg.chrome.isTransparent();
		ImGui.setNextWindowBgAlpha(trans ? 0 : 0.72);
		ImGui.setNextWindowSizeConstraints(
			ImGui.vec2(ConduitConfig.MIN_W, ConduitConfig.MIN_H),
			ImGui.vec2(ConduitConfig.MAX_W, ConduitConfig.MAX_H)
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
			ImGui.setNextWindowPos(ImGui.vec2(40, 250), ImGuiCond.FirstUseEver);
		}

		var flags = cfg.chrome != null ? cfg.chrome.windowFlags(FLAGS) : FLAGS;
		var began = ImGui.begin("SolarFlare Conduits", null, flags);
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
			}, null, "Conduits");
			if (showBody) {
				var avail = ImGui.getContentRegionAvail();
				var rowW:Single = avail.x > 1 ? avail.x : 1;
				var rowH:Single = avail.y > 1 ? avail.y : ConduitConfig.MIN_H;
				drawSlots(rowW, rowH, cfg);
			}
		}
		HudChrome.endOverlayWindow(began, cfg.chrome);
	}

	static function drawSlots(rowW:Single, rowH:Single, cfg:ConduitConfig):Void {
		var n = ConduitCache.valid ? ConduitCache.slotCount : ConduitCache.DEFAULT_SLOTS;
		if (n < 1)
			n = ConduitCache.DEFAULT_SLOTS;
		if (n > ConduitCache.MAX_SLOTS)
			n = ConduitCache.MAX_SLOTS;
		var amounts = new Array<Float>();
		var iconIds = new Array<String>();
		var stackLabels = new Array<String>();
		var i = 0;
		while (i < n) {
			var snap:ConduitSlotSnap = null;
			if (ConduitCache.slots != null && i < ConduitCache.slots.length)
				snap = ConduitCache.slots[i];
			var id = snap != null && snap.id != null ? snap.id : "";
			var stacks = snap != null ? snap.stacks : 0;
			var power = snap != null && snap.power;
			// Lit by equipped Sparkmaster slots (how many the player has), not proc stacks.
			var amt:Float = id.length > 0 ? 1 : 0;
			amounts.push(amt);
			iconIds.push(id);
			if (power && stacks > 0)
				stackLabels.push(Std.string(stacks));
			else
				stackLabels.push("");
			i++;
		}
		var label = "0";
		if (ConduitCache.valid) {
			if (ConduitCache.powerStacks > 0)
				label = Std.string(ConduitCache.powerStacks);
			else
				label = Std.string(ConduitCache.filledCount);
		}
		drawSlotRow(rowW, rowH, n, amounts, iconIds, stackLabels, cfg.vertical.get(), cfg.shape.get(), label);
	}

	/** Shared live + Resource Tracker Builder presentation. */
	public static function drawSlotRow(rowW:Single, rowH:Single, n:Int, amounts:Array<Float>, iconIds:Array<String>,
			stackLabels:Array<String>, vertical:Bool, shape:Int, label:String):Void {
		shape = PipShapes.normalize(shape);
		var origin = ImGui.getCursorScreenPos();
		var dl = ImGui.getWindowDrawList();
		var gap:Single = PipShapes.GAP;
		var text = label != null ? label : "";
		var ts = text.length > 0 ? ImGui.calcTextSize(text) : ImGui.vec2(0, 0);
		var labelW:Single = text.length > 0 ? Math.max(PipShapes.LABEL_W, ts.x + 6) : 0;
		var labelH:Single = text.length > 0 ? Math.max(PipShapes.LABEL_H, ts.y + 2) : 0;
		var pipW:Single = rowW;
		var pipH:Single = rowH;
		var labelX:Single = origin.x;
		var labelY:Single = origin.y;
		if (vertical) {
			pipH = rowH - labelH;
			if (pipH < 8)
				pipH = 8;
			labelX = origin.x + Math.max(0, (rowW - ts.x) * 0.5);
			labelY = origin.y + pipH + 1;
		} else {
			pipW = rowW - labelW;
			if (pipW < 8)
				pipW = 8;
			labelX = origin.x + pipW + 4;
			labelY = origin.y + Math.max(0, (rowH - ts.y) * 0.5);
		}
		var lit = ImGui.vec4(0.45, 0.72, 0.95, 1);
		var dim = ImGui.vec4(0.10, 0.12, 0.16, 0.95);
		var litBorder = ImGui.vec4(0.70, 0.88, 1.0, 0.55);
		var dimBorder = ImGui.vec4(0.22, 0.26, 0.32, 1);
		if (vertical) {
			var blockH:Single = (pipH - gap * (n - 1)) / n;
			if (blockH < 4)
				blockH = 4;
			var blockW:Single = pipW;
			if (blockW < 8)
				blockW = 8;
			var i = 0;
			while (i < n) {
				var idx = n - 1 - i;
				var y:Single = origin.y + (blockH + gap) * i;
				drawOneSlot(dl, origin.x, y, blockW, blockH, shape,
					idx < amounts.length ? amounts[idx] : 0,
					idx < iconIds.length ? iconIds[idx] : "",
					idx < stackLabels.length ? stackLabels[idx] : "",
					lit, dim, litBorder, dimBorder);
				i++;
			}
		} else {
			var blockW:Single = (pipW - gap * (n - 1)) / n;
			if (blockW < 4)
				blockW = 4;
			var blockH:Single = pipH;
			if (blockH < 8)
				blockH = 8;
			var i = 0;
			while (i < n) {
				var x:Single = origin.x + (blockW + gap) * i;
				drawOneSlot(dl, x, origin.y, blockW, blockH, shape,
					i < amounts.length ? amounts[i] : 0,
					i < iconIds.length ? iconIds[i] : "",
					i < stackLabels.length ? stackLabels[i] : "",
					lit, dim, litBorder, dimBorder);
				i++;
			}
		}
		if (text.length > 0) {
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(labelX, labelY),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0.92)), text);
		}
		ImGui.dummy(ImGui.vec2(rowW, rowH));
	}

	static function drawOneSlot(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, shape:Int, amount:Float,
			iconId:String, stackText:String, lit:imgui.Structs.ImVec4, dim:imgui.Structs.ImVec4,
			litBorder:imgui.Structs.ImVec4, dimBorder:imgui.Structs.ImVec4):Void {
		var a = amount;
		if (a < 0)
			a = 0;
		if (a > 1)
			a = 1;
		var cx:Single = x + w * 0.5;
		var cy:Single = y + h * 0.5;
		var rad:Single = Math.min(w, h) * 0.42;
		if (rad < 3)
			rad = 3;
		var t = a;
		var fill = ImGui.vec4(dim.x + (lit.x - dim.x) * t, dim.y + (lit.y - dim.y) * t, dim.z + (lit.z - dim.z) * t,
			dim.w + (lit.w - dim.w) * t);
		var bt = a > 0.01 ? Math.max(a, 0.35) : 0;
		var border = ImGui.vec4(dimBorder.x + (litBorder.x - dimBorder.x) * bt,
			dimBorder.y + (litBorder.y - dimBorder.y) * bt, dimBorder.z + (litBorder.z - dimBorder.z) * bt,
			dimBorder.w + (litBorder.w - dimBorder.w) * bt);
		var fillU = ImGui.colorConvertFloat4ToU32(fill);
		var borderU = ImGui.colorConvertFloat4ToU32(border);
		switch (shape) {
			case PipShapes.CIRCLE:
				ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), rad, fillU, 24);
				ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), rad, borderU, 24, 1.25);
			case PipShapes.RING:
				var thick:Single = Math.max(1.5, rad * 0.22);
				ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), rad, borderU, 24, thick);
				if (a > 0.02)
					ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), rad * (0.35 + 0.55 * a), fillU, 24);
			case PipShapes.HEX:
				ImGui.ImDrawList_AddNgonFilled(dl, ImGui.vec2(cx, cy), rad, fillU, 6);
				ImGui.ImDrawList_AddNgon(dl, ImGui.vec2(cx, cy), rad, borderU, 6, 1.25);
			case PipShapes.DIAMOND:
				ImGui.ImDrawList_AddNgonFilled(dl, ImGui.vec2(cx, cy), rad, fillU, 4);
				ImGui.ImDrawList_AddNgon(dl, ImGui.vec2(cx, cy), rad, borderU, 4, 1.25);
			default:
				ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), fillU, 3);
				ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h), borderU, 3, 1);
		}
		if (iconId != null && iconId.length > 0) {
			var tex:hl.I64 = GameIcons.get(iconId);
			if (tex != (0 : hl.I64)) {
				var side:Single = Math.min(w, h) * 0.62;
				if (side < 6)
					side = 6;
				var tint = a > 0.55 ? GameIcons.tintReady(true) : GameIcons.tintReady(false);
				GameIcons.draw(dl, tex, cx - side * 0.5, cy - side * 0.5, side, tint);
			}
		}
		if (stackText != null && stackText.length > 0) {
			var st = ImGui.calcTextSize(stackText);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(cx - st.x * 0.5, cy - st.y * 0.5),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0.95)), stackText);
		}
	}
}
