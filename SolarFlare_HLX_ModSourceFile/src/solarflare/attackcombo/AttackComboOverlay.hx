package solarflare.attackcombo;

import solarflare.ui.GameIcons;
import solarflare.ui.PipShapes;
import solarflare.ui.SettingsStore;
import solarflare.ui.ThemePalette;
import solarflare.ui.HudChrome;
import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Theme;

class AttackComboOverlay {
	static inline var FLAGS:Int = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse | ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse;
	var theme:Theme;

	public function new() {
		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(4, 4))
			.varF(ImGuiStyleVar.WindowRounding, 4)
			.varF(ImGuiStyleVar.WindowBorderSize, 1)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0.08, 0.06, 0.12, 0.85))
			.color(ImGuiCol.Border, ImGui.vec4(0.45, 0.32, 0.65, 0.65))
			.color(ImGuiCol.ResizeGrip, ImGui.vec4(0.55, 0.40, 0.80, 0.45));
	}

	/**
	 * The HUD stays mounted between chains. `visible` only describes live combo
	 * telemetry; it must not control whether the user-positioned window exists.
	 */
	public function draw(cfg:AttackComboConfig):Void {
		if (cfg == null || cfg.hidden.get())
			return;
		theme.wrap(() -> drawWindow(cfg));
	}

	function drawWindow(cfg:AttackComboConfig):Void {
		var w:Single = cfg.width.get() < AttackComboConfig.MIN_W ? AttackComboConfig.MIN_W : cfg.width.get();
		var h:Single = cfg.height.get() < AttackComboConfig.MIN_H ? AttackComboConfig.MIN_H : cfg.height.get();
		if (w > AttackComboConfig.MAX_W)
			w = AttackComboConfig.MAX_W;
		if (h > AttackComboConfig.MAX_H)
			h = AttackComboConfig.MAX_H;

		var trans = cfg.chrome != null && cfg.chrome.isTransparent();
		ImGui.setNextWindowBgAlpha(trans ? 0 : ThemePalette.panelAlpha());
		ImGui.setNextWindowSizeConstraints(
			ImGui.vec2(AttackComboConfig.MIN_W, AttackComboConfig.MIN_H),
			ImGui.vec2(AttackComboConfig.MAX_W, AttackComboConfig.MAX_H)
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
			ImGui.setNextWindowPos(ImGui.vec2(80, 220), ImGuiCond.FirstUseEver);
		}

		var flags = cfg.chrome != null ? cfg.chrome.windowFlags(FLAGS) : FLAGS;
		var began = ImGui.begin("SolarFlare AttackCombo", null, flags);
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
			}, null, "Attack Combo");
			if (showBody) {
				var avail = ImGui.getContentRegionAvail();
				drawBody(cfg, avail.x > 1 ? avail.x : 1, avail.y > 1 ? avail.y : AttackComboConfig.MIN_H);
			}
		}
		HudChrome.endOverlayWindow(began, cfg.chrome);
	}

	function drawBody(cfg:AttackComboConfig, rowW:Single, rowH:Single):Void {
		var n = AttackComboCache.comboLength > 0 ? AttackComboCache.comboLength : 4;
		AttackComboRenderer.draw(AttackComboCache.step, n, AttackComboCache.flashFinal, AttackComboCache.withinCombo, cfg, rowW, rowH);
	}
}
