package solarflare.ui;

import imgui.ref.BoolRef;

/**
 * Hide All policy: decides whether HUD overlays should be skipped this frame.
 *
 * Draw gating only — the hidden refs on each widget are never written, so the HUD
 * returns exactly as the player left it once it is unhidden.
 *
 * The old menu detection (bank, vendor, map) was removed because it resolved the type of
 * every open game window on every poll. It is back as an opt-in, off by default:
 * WindowAutoHide classifies each window once and freezes a bool from the observe phase,
 * so this stays a pair of cheap reads. The explicit key remains the reliable escape hatch.
 */
class HudSuppress {
	/**
	 * Deliberately NOT persisted: a saved "everything hidden" would look exactly
	 * like a broken mod on the next launch. See HideAllBind for the bound key.
	 */
	public static var hideAll = new BoolRef(false);

	public static function active():Bool {
		return WindowAutoHidePolicy.suppress(hideAll.get(), WindowAutoHide.active());
	}
}
