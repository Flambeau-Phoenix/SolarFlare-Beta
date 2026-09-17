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

	public var openBuilder:Void->Void;
	function drawWindow(cfg:AttackComboConfig):Void {
		var w:Single = Math.max(AttackComboConfig.MIN_W, Math.min(AttackComboConfig.MAX_W, cfg.width.get()));
		var h:Single = Math.max(38, cfg.height.get());
		solarflare.ui.HUDWidgetWindow.draw("SolarFlare Attack Combo", "Attack Combo", cfg.chrome, w, h, function(size) {
			var p = ImGui.getCursorScreenPos();
			ImGui.dummy(size);
			ImGui.setCursorScreenPos(ImGui.vec2(p.x+4, p.y+4));
			drawBody(cfg, size.x - 8, size.y - 8);
		}, openBuilder, function() { cfg.hidden.set(true); SettingsStore.markDirty(); }, false, null, function(newW:Single, newH:Single) {
			cfg.width.set(Math.max(AttackComboConfig.MIN_W, Math.min(AttackComboConfig.MAX_W, newW)));
			cfg.height.set(Math.max(38, newH));
			SettingsStore.markDirty();
		});
	}

	function drawBody(cfg:AttackComboConfig, rowW:Single, rowH:Single):Void {
		var n = AttackComboCache.comboLength > 0 ? AttackComboCache.comboLength : 4;
		AttackComboRenderer.draw(AttackComboCache.step, n, AttackComboCache.flashFinal, AttackComboCache.withinCombo, cfg, rowW, rowH);
	}
}
