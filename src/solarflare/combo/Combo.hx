package solarflare.combo;

import solarflare.HealthCache;
import solarflare.FieldWalk;
import solarflare.ui.GameIcons;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.HudChrome;
import solarflare.ui.PipShapes;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiLayout;
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
			ImGui.textWrapped("Mirrors hero.attr.comboPoint (0–6). Move / resize the overlay.");
			ImGui.separatorText("Window");
			chrome.drawWindowSettings(hidden, "combo");
			UiLayout.propertyGrid("##combo_props", function() {
				UiLayout.propertyRow("Layout", function() {
					if (ImGui.checkbox("Vertical stack##combo_vert", vertical))
						SettingsStore.markDirty();
				});
				UiLayout.propertyRow("Pips", function() {
					PipShapes.drawShapeCombo("##combo_shape", shape);
				});
				UiLayout.propertyRow("Size", function() {
					UiLayout.inlinePair(
						"##combo_size",
						function(_:Single) {
							if (ImGui.sliderFloat("Width##combo_w", width, MIN_W, MAX_W, "%.0f px")) {
								sizeDirty = true;
								SettingsStore.markDirty();
							}
						},
						function(_:Single) {
							if (ImGui.sliderFloat("Height##combo_h", height, MIN_H, MAX_H, "%.0f px")) {
								sizeDirty = true;
								SettingsStore.markDirty();
							}
						}
					);
				});
			});
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

	public var openBuilder:Void->Void;
	function drawWindow(cfg:ComboConfig):Void {
		var w:Single = Math.max(ComboConfig.MIN_W, Math.min(ComboConfig.MAX_W, cfg.width.get()));
		var alertH:Single = ComboPointsCache.alertActive() ? solarflare.ui.ResourceMaxAlert.TOAST_H + 3 : 0;
		var h:Single = Math.max(38, cfg.height.get()) + alertH;
		solarflare.ui.HUDWidgetWindow.draw("SolarFlare Combo", "Combo", cfg.chrome, w, h, function(size) {
			var p = ImGui.getCursorScreenPos();
			ImGui.dummy(size);
			ImGui.setCursorScreenPos(ImGui.vec2(p.x+4, p.y+4));
			var rowH:Single = size.y - 8;
			if (ComboPointsCache.alertActive()) { solarflare.ui.ResourceMaxAlert.drawToast(size.x-8, solarflare.ui.ResourceMaxAlert.TOAST_H); rowH -= solarflare.ui.ResourceMaxAlert.TOAST_H + 3; }
			drawPips(size.x-8, rowH, cfg);
		}, openBuilder, function() { cfg.hidden.set(true); SettingsStore.markDirty(); }, false, null, function(newW:Single, newH:Single) {
			cfg.width.set(Math.max(ComboConfig.MIN_W, Math.min(ComboConfig.MAX_W, newW)));
			cfg.height.set(Math.max(38, newH - alertH));
			SettingsStore.markDirty();
		});
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
