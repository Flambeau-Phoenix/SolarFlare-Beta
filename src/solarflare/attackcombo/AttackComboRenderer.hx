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
	public static inline var LIVE:Int = 0;
	public static inline var BUILDER_PREVIEW:Int = 1;
	public static inline var RESOURCE_PREVIEW:Int = 2;
	/**
	 * One tracker per caller: previews cycle `step` on their own, which would otherwise keep
	 * resetting the live overlay's step-change animation (and vice versa).
	 */
	static var trackers:Array<ComboTracker> = [new ComboTracker(), new ComboTracker(), new ComboTracker()];

	public static function draw(step:Int, length:Int, flashFinal:Bool, withinCombo:Bool, cfg:AttackComboConfig, rowW:Single, rowH:Single,
			slot:Int = LIVE):Void {
		if (cfg == null)
			return;
		if (drawSlotArt(step, flashFinal, rowW, rowH))
			return;
		if (cfg.comboType.get() == 1 && drawCustom(cfg, step, rowW, rowH, flashFinal))
			return;
		var tracker = trackers[slot >= 0 && slot < trackers.length ? slot : LIVE];

		tracker.displayMode = cfg.displayMode != null ? cfg.displayMode.get() : 0;
		tracker.orientation = cfg.vertical != null && cfg.vertical.get() ? 1 : 0;
		tracker.colorScheme = cfg.colorScheme != null ? cfg.colorScheme.get() : 0;
		tracker.showLabels = cfg.showLabels != null ? cfg.showLabels.get() : true;
		tracker.showGlow = cfg.showGlow != null ? cfg.showGlow.get() : true;
		tracker.animationSpeed = cfg.animationSpeed != null ? cfg.animationSpeed.get() : 1.0;

		tracker.draw(step, length, flashFinal, withinCombo, rowW, rowH);
	}

	/** User-chosen image for this state (Resource Tracker > Custom artwork). False keeps the built-in look. */
	static function drawSlotArt(step:Int, flashFinal:Bool, rowW:Single, rowH:Single):Bool {
		var art = solarflare.resourcetracker.ResourceArtwork.active;
		var skin = art != null ? art.get("attack") : null;
		if (skin == null || !skin.enabled.get())
			return false;
		var n = flashFinal ? 4 : step;
		if (n < 0) n = 0;
		if (n > 4) n = 4;
		if (skin.slotKey(n).length == 0)
			return false;
		var p = ImGui.getCursorScreenPos();
		var vw:Single = rowW > 1 ? rowW : 1;
		var vh:Single = rowH > 1 ? rowH : 1;
		skin.drawSlot(ImGui.getWindowDrawList(), n, p.x, p.y, vw, vh);
		ImGui.dummy(ImGui.vec2(vw, vh));
		return true;
	}

	public static function drawCustom(cfg:AttackComboConfig, step:Int, rowW:Single, rowH:Single, flashFinal:Bool = false):Bool {
		if (!AttackComboArt.isLoaded())
			return false;
		var customStyle = cfg.customStyle.get();
		var chosen = AttackComboArt.candidate(customStyle, step, flashFinal);
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
