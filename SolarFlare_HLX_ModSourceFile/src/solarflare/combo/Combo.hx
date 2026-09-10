package solarflare.combo;

import solarflare.HealthCache;
import solarflare.FieldWalk;
import solarflare.ui.GameIcons;
import solarflare.ui.CursorCaptureFix;
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

/**
 * Rogue combo-point snapshot mirroring ent.HeroAttributes.comboPoint (AttributeBlockBar).
 * Cap is 6; Finisher spends via the engine setter — we only mirror the live value.
 */
class ComboPointsCache {
	public static inline var MAX:Int = 6;
	public static inline var ALERT_SEC:Float = 2;

	public static var active:Bool = false;
	public static var current:Int = 0;
	public static var max:Int = MAX;
	public static var valid:Bool = false;
	public static var alertUntil:Float = 0;

	static var comboKey:String = "Rogue_ComboPoints";
	static var finisherKey:String = "Rogue_Sig_Finisher";
	static var hashesReady:Bool = false;

	public static function clear():Void {
		active = false;
		current = 0;
		max = MAX;
		valid = false;
		alertUntil = 0;
	}

	public static function set(points:Float):Void {
		var prev = current;
		var n = Std.int(points);
		if (n < 0)
			n = 0;
		if (n > max)
			n = max;
		current = n;
		valid = true;
		if (n > 0)
			active = true;
		if (n >= max && prev < max)
			alertUntil = nowSec() + ALERT_SEC;
	}

	public static function alertActive():Bool {
		return nowSec() < alertUntil;
	}

	public static function nowSec():Float {
		try
			return haxe.Timer.stamp()
		catch (_:Dynamic)
			return Date.now().getTime() / 1000.0;
	}

	public static function noteRogue():Void {
		active = true;
		max = MAX;
	}

	public static function comboId():String {
		ensureHashes();
		return comboKey;
	}

	public static function finisherId():String {
		ensureHashes();
		return finisherKey;
	}

	public static function isRogueSkillId(id:String):Bool {
		if (id == null || id.length == 0)
			return false;
		ensureHashes();
		if (id == comboKey || id == finisherKey)
			return true;
		var s = id.toLowerCase();
		return s.indexOf("rogue_") == 0
			|| s.indexOf("rogue_combo") >= 0
			|| s.indexOf("sig_finisher") >= 0
			|| s.indexOf("combopoints") >= 0;
	}

	public static function isFinisherSkill(skill:Dynamic):Bool {
		if (skill == null)
			return false;
		ensureHashes();
		if (isFinisherKind(skillKind(skill)))
			return true;
		try {
			var inf = FieldWalk.extractObject(skill, "inf");
			if (isFinisherKind(stringField(inf, "id")) || isFinisherKind(stringField(inf, "script")))
				return true;
		} catch (_:Dynamic) {}
		return false;
	}

	static function isFinisherKind(kind:String):Bool {
		if (kind == null || kind.length == 0)
			return false;
		if (kind == finisherKey)
			return true;
		var s = kind.toLowerCase();
		return s.indexOf("sig_finisher") >= 0
			|| s.indexOf("rogue_sig_finisher") >= 0
			|| s == "finisher";
	}

	static function skillKind(skill:Dynamic):String {
		try {
			var s:st.skill.BaseSkill = skill;
			var k = s.kind;
			if (k != null && k.length > 0)
				return k;
		} catch (_:Dynamic) {}
		var k = stringField(skill, "kind");
		if (k != null)
			return k;
		return stringField(skill, "id");
	}

	static function stringField(obj:Dynamic, name:String):String {
		if (obj == null)
			return null;
		try {
			var v:String = FieldWalk.extractObject(obj, name);
			if (v != null && v.length > 0)
				return v;
		} catch (_:Dynamic) {}
		return null;
	}

	static function ensureHashes():Void {
		if (hashesReady)
			return;
		hashesReady = true;
		try {
			var h = script.skills.Rogue_ComboPoints.HASH;
			if (h != null && h.length > 0)
				comboKey = h;
		} catch (_:Dynamic) {}
		try {
			var h = script.skills.Rogue_Sig_Finisher.HASH;
			if (h != null && h.length > 0)
				finisherKey = h;
		} catch (_:Dynamic) {}
	}
}

/**
 * F6 → Combo Points. Hide + size + lock/transparent chrome.
 * Mirrors ui.comp.AttributeBlockBar("comboPoint"); layout is ours to move/resize.
 */
class ComboConfig {
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
		chrome = new HudChrome(40, 160);
	}

	public function draw():Void {
		if (!open.get())
			return;
		ImGui.setNextWindowSize(ImGui.vec2(360, 0), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel("Combo Points", open, "Combo Points")) {
			ImGui.text("Mirrors hero.attr.comboPoint (0–6). Move / resize the overlay.");
			if (ImGui.checkbox("Hide overlay##combo_hidden", hidden))
				SettingsStore.markDirty();
			if (ImGui.checkbox("Vertical stack##combo_vert", vertical))
				SettingsStore.markDirty();
			PipShapes.drawShapeCombo("Pip shape##combo", shape);
			chrome.drawToggles("combo");
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
 * Movable/resizable pip gauge mirroring the game's AttributeBlockBar for comboPoint.
 * Reads ComboPointsCache only — never live hero attrs from the draw loop.
 */
class ComboOverlay {
	static inline var FLAGS:Int = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse
		| ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse;
	static inline var PAD:Single = 4;

	var theme:Theme;

	public function new() {
		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(PAD, PAD))
			.varF(ImGuiStyleVar.WindowRounding, 4)
			.varF(ImGuiStyleVar.WindowBorderSize, 1)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0.06, 0.08, 0.07, 0.72))
			.color(ImGuiCol.Border, ImGui.vec4(0.20, 0.28, 0.22, 0.55))
			.color(ImGuiCol.ResizeGrip, ImGui.vec4(0.35, 0.48, 0.38, 0.45));
	}

	public function draw(cfg:ComboConfig):Void {
		if (cfg == null || cfg.hidden.get())
			return;
		if (!ComboPointsCache.active)
			return;
		theme.wrap(() -> drawWindow(cfg));
	}

	function drawWindow(cfg:ComboConfig):Void {
		var w:Single = cfg.width.get();
		var h:Single = cfg.height.get();
		if (w < ComboConfig.MIN_W)
			w = ComboConfig.MIN_W;
		if (w > ComboConfig.MAX_W)
			w = ComboConfig.MAX_W;
		if (h < ComboConfig.MIN_H)
			h = ComboConfig.MIN_H;
		if (h > ComboConfig.MAX_H)
			h = ComboConfig.MAX_H;

		var trans = cfg.chrome != null && cfg.chrome.isTransparent();
		ImGui.setNextWindowBgAlpha(trans ? 0 : 0.72);
		ImGui.setNextWindowSizeConstraints(
			ImGui.vec2(ComboConfig.MIN_W, ComboConfig.MIN_H),
			ImGui.vec2(ComboConfig.MAX_W, ComboConfig.MAX_H)
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
			ImGui.setNextWindowPos(ImGui.vec2(40, 160), ImGuiCond.FirstUseEver);
		}

		var flags = cfg.chrome != null ? cfg.chrome.windowFlags(FLAGS) : FLAGS;
		var began = ImGui.begin("SolarFlare ComboPoints", null, flags);
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
			}, null, "Combo");
			if (showBody) {
				var avail = ImGui.getContentRegionAvail();
				var rowW:Single = avail.x > 1 ? avail.x : 1;
				var rowH:Single = avail.y > 1 ? avail.y : ComboConfig.MIN_H;
				if (ComboPointsCache.alertActive()) {
					solarflare.ui.ResourceMaxAlert.drawToast(rowW, solarflare.ui.ResourceMaxAlert.TOAST_H);
					rowH -= solarflare.ui.ResourceMaxAlert.TOAST_H;
					if (rowH < 12)
						rowH = 12;
				}
				drawPips(rowW, rowH, cfg);
			}
		}
		solarflare.ui.HudChrome.endOverlayWindow(began, cfg.chrome);
	}

	static function drawPips(rowW:Single, rowH:Single, cfg:ComboConfig):Void {
		var n = ComboPointsCache.MAX;
		var filled = ComboPointsCache.valid ? ComboPointsCache.current : 0;
		if (filled < 0)
			filled = 0;
		if (filled > n)
			filled = n;
			PipShapes.drawCount(rowW, rowH, n, filled, cfg.vertical.get(), cfg.shape.get(), Std.string(filled), null);
	}
}
