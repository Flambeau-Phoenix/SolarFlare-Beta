package solarflare.ui;

import imgui.ref.BoolRef;

/**
 * Hide All policy: decides whether HUD overlays should be skipped this frame.
 *
 * Draw gating only — the hidden refs on each widget are never written, so the HUD
 * returns exactly as the player left it once it is unhidden.
 *
 * This used to also detect open game menus (bank, vendor, map) and hide for them.
 * That was removed: resolving the type of every open game window each poll cost
 * frame time, recognised only the windows it knew by name, and a merely-undrawn
 * window was still one the player could not act through. A single explicit key is
 * both cheaper and predictable.
 */
class HudSuppress {
	/**
	 * Deliberately NOT persisted: a saved "everything hidden" would look exactly
	 * like a broken mod on the next launch. See HideAllBind for the bound key.
	 */
	public static var hideAll = new BoolRef(false);

	public static function active():Bool {
		return hideAll.get();
	}
}
