package solarflare.attackcombo;

import imgui.ImGui;
import solarflare.ui.GameIcons;
import solarflare.ui.PipShapes;
import solarflare.ui.ThemePalette;

/**
 * Shared Attack Combo presentation renderer.
 * Consumes step, length, flash state, and config to render into a fixed viewport.
 * Does not modify live caches, persisted geometry, or window dimensions.
 */
class AttackComboRenderer {
	static var tracker = new ComboTracker();

	public static function draw(step:Int, length:Int, flashFinal:Bool, withinCombo:Bool, cfg:AttackComboConfig, rowW:Single, rowH:Single):Void {
		if (cfg == null)
			return;
		if (cfg.comboType.get() == 1 && drawCustom(cfg, step, rowW, rowH))
			return;

		tracker.displayMode = cfg.displayMode != null ? cfg.displayMode.get() : 0;
		tracker.orientation = cfg.vertical != null && cfg.vertical.get() ? 1 : 0;
		tracker.colorScheme = cfg.colorScheme != null ? cfg.colorScheme.get() : 0;
		tracker.showLabels = cfg.showLabels != null ? cfg.showLabels.get() : true;
		tracker.showGlow = cfg.showGlow != null ? cfg.showGlow.get() : true;
		tracker.animationSpeed = cfg.animationSpeed != null ? cfg.animationSpeed.get() : 1.0;

		tracker.draw(step, length, flashFinal, withinCombo, rowW, rowH);
	}

	public static function drawCustom(cfg:AttackComboConfig, step:Int, rowW:Single, rowH:Single):Bool {
		if (!AttackComboArt.isLoaded())
			return false;
		var customStyle = cfg.customStyle.get();
		var chosen = AttackComboArt.candidate(customStyle, step);
		if (chosen.length == 0 || GameIcons.cachedW(chosen) <= 0)
			return false;
		var tw = GameIcons.cachedW(chosen);
		var th = GameIcons.cachedH(chosen);
		if (tw <= 0 || th <= 0)
			return false;
		var tex = GameIcons.cached(chosen);
		if (tex == 0)
			return false;

		var vw = rowW > 1 ? rowW : 1.0;
		var vh = rowH > 1 ? rowH : 1.0;

		var aspect = tw / th;
		var fitW = vw;
		var fitH = vw / aspect;
		if (fitH > vh) {
			fitH = vh;
			fitW = vh * aspect;
		}

		var p = ImGui.getCursorScreenPos();
		var offsetX = (vw - fitW) * 0.5;
		var offsetY = (vh - fitH) * 0.5;

		GameIcons.drawRect(ImGui.getWindowDrawList(), tex, p.x + offsetX, p.y + offsetY, fitW, fitH);
		ImGui.dummy(ImGui.vec2(vw, vh));
		return true;
	}
}
