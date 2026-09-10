package solarflare.attackcombo;

import solarflare.ui.HudChrome;
import solarflare.ui.PipShapes;
import solarflare.ui.SettingsStore;
import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;

class AttackComboConfig {
	public static inline var MIN_W:Single = 48;
	public static inline var MAX_W:Single = 720;
	public static inline var MIN_H:Single = 28;
	public static inline var MAX_H:Single = 240;

	public static inline var TYPE_PIP:Int = 0;
	public static inline var TYPE_CUSTOM:Int = 1;

	public static inline var CUSTOM_SUN:Int = 0;
	public static inline var CUSTOM_PURPLE_BLADE:Int = 1;

	public var open = new BoolRef(false);
	public var hidden = new BoolRef(false);

	/** 0 = Pip, 1 = Custom */
	public var comboType = new IntRef(0);
	/** 0 = Sun (Classic), 1 = Purple Blade (Style_*) */
	public var customStyle = new IntRef(0);
	public var vertical = new BoolRef(false);
	public var shape = new IntRef(PipShapes.CIRCLE);
	public var displayMode = new IntRef(0); // 0=Compact, 1=Detailed, 2=Minimalist, 3=Circular
	public var colorScheme = new IntRef(0); // 0=Default, 1=Fiery, 2=Icy, 3=Electric, 4=Royal
	public var showLabels = new BoolRef(true);
	public var showGlow = new BoolRef(true);
	public var animationSpeed = new FloatRef(1.0);

	public var width = new FloatRef(220);
	public var height = new FloatRef(56);
	public var bannerH = new FloatRef(56);
	public var sizeDirty = true;
	public var chrome:HudChrome;

	public var previewStep = new IntRef(2);

	static var TYPE_ITEMS = ["Pip", "Custom"];
	static var CUSTOM_STYLE_ITEMS = ["Sun", "Purple Blade"];
	static var DISPLAY_MODE_ITEMS = ["Compact", "Detailed", "Modern Radial", "Classic Bar", "Minimalist", "Circular"];
	static var COLOR_SCHEME_ITEMS = ["Default", "Fiery", "Icy", "Electric", "Royal"];

	public function new() chrome = new HudChrome(80, 220);

	public function draw():Void {
		if (!open.get()) return;
		ImGui.setNextWindowSize(ImGui.vec2(380, 0), ImGuiCond.FirstUseEver);
		if (HudChrome.beginPanel("Attack Combo Tracker##sf_actcfg", open, "Attack Combo Tracker")) {
			ImGui.textWrapped("Weapon attack chain (not Rogue combo points). Tracker stays visible and shows no progress between chains.");
			ImGui.separatorText("Window");
			chrome.drawWindowSettings(hidden, "act");
			if (ImGui.sliderFloat("Width##act_w", width, MIN_W, MAX_W, "%.0f px")) { sizeDirty = true; SettingsStore.markDirty(); }
			if (ImGui.sliderFloat("Height##act_h", height, MIN_H, MAX_H, "%.0f px")) { sizeDirty = true; SettingsStore.markDirty(); }
			ImGui.separatorText("Appearance");
			drawAppearanceSettings();
			ImGui.separatorText("Behavior");
			drawBehaviorSettings();
		}
		HudChrome.endPanel();
	}

	/**
	 * Builder pane content (no standalone window). Mirrors draw() but uses the
	 * shared chrome toggles instead of the missing drawWindowSettings helper.
	 * Hide lives on the builder navigation row; Lock/Transparent live in the
	 * builder's Window chrome section.
	 */
	public function drawSettings():Void {
		drawAppearanceSettings();
		drawBehaviorSettings();
	}

	public function drawAppearanceSettings():Void {
		if (intCombo("Type##act_type", "at", comboType, TYPE_ITEMS)) SettingsStore.markDirty();

		if (comboType.get() == TYPE_PIP) {
			if (intCombo("Display Mode##act_disp", "adm", displayMode, DISPLAY_MODE_ITEMS)) SettingsStore.markDirty();
			if (intCombo("Color Scheme##act_col", "acs", colorScheme, COLOR_SCHEME_ITEMS)) SettingsStore.markDirty();
			if (ImGui.checkbox("Vertical layout##act_vert", vertical)) SettingsStore.markDirty();
			ImGui.sameLine();
			if (ImGui.checkbox("Show Glow FX##act_glow", showGlow)) SettingsStore.markDirty();
			ImGui.sameLine();
			if (ImGui.checkbox("Step Numbers##act_labels", showLabels)) SettingsStore.markDirty();
		} else {
			if (intCombo("Style##act_custom_style", "acst", customStyle, CUSTOM_STYLE_ITEMS)) SettingsStore.markDirty();
		}

		ImGui.separatorText("Preview");
		ImGui.text("Step:"); ImGui.sameLine();
		for (s in 0...5) {
			var label = s == 4 ? "Final" : Std.string(s);
			if (s > 0) ImGui.sameLine();
			if (ImGui.button((previewStep.get() == s ? "[" + label + "]" : label) + "##act_prev_s" + s)) {
				previewStep.set(s);
			}
		}

		HudChrome.safeChild("##act_prev_box", ImGui.vec2(0, 56), HudChrome.CHILD_NO_SCROLL, function() {
			var avail = ImGui.getContentRegionAvail();
			var st = previewStep.get();
			AttackComboRenderer.draw(st, 4, st == 4, st > 0, this, avail.x > 20 ? avail.x : 20, avail.y > 20 ? avail.y : 20);
		});
	}

	function drawPipStyleCombo(label:String):Void {
		var curShape = PipShapes.normalize(shape.get());
		var curIdx = switch (curShape) {
			case PipShapes.DIAMOND: 0;
			case PipShapes.CIRCLE: 1;
			case PipShapes.RING: 2;
			case PipShapes.HEX: 3;
			case PipShapes.BOX: 4;
			default: 1;
		};
		var pipStyleNames = ["Diamond", "Circle", "Ring", "Hexagon", "Box"];
		if (ImGui.beginCombo(label, pipStyleNames[curIdx])) {
			if (ImGui.selectable("Diamond##act_ps0", curIdx == 0)) { shape.set(PipShapes.DIAMOND); SettingsStore.markDirty(); }
			if (ImGui.selectable("Circle##act_ps1", curIdx == 1)) { shape.set(PipShapes.CIRCLE); SettingsStore.markDirty(); }
			if (ImGui.selectable("Ring##act_ps2", curIdx == 2)) { shape.set(PipShapes.RING); SettingsStore.markDirty(); }
			if (ImGui.selectable("Hexagon##act_ps3", curIdx == 3)) { shape.set(PipShapes.HEX); SettingsStore.markDirty(); }
			if (ImGui.selectable("Box##act_ps4", curIdx == 4)) { shape.set(PipShapes.BOX); SettingsStore.markDirty(); }
			ImGui.endCombo();
		}
	}

	public function drawBehaviorSettings():Void {
		ImGui.textWrapped("Weapon attack chain (not Rogue combo points). Tracker stays visible and shows no progress between chains.");
		ImGui.text(AttackComboCache.debugLine);
		ImGui.textWrapped(AttackComboArt.diagnostic());
		if (ImGui.button("Reload banner assets##act_reload"))
			AttackComboArt.requestReload();
	}

	static function intCombo(label:String, id:String, ref:IntRef, items:Array<String>):Bool {
		var idx = ref.get(); if (idx < 0 || idx >= items.length) idx = 0;
		var changed = false;
		if (ImGui.beginCombo(label, items[idx])) { var cur = idx; for (i in 0...items.length) if (ImGui.selectable(items[i] + "##" + id + i, cur == i)) cur = i; ImGui.endCombo(); if (cur != ref.get()) { ref.set(cur); changed = true; } }
		return changed;
	}
}
