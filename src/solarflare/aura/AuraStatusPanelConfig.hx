package solarflare.aura;

import solarflare.ui.HudChrome;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;

/**
 * Persistent configuration for the AuraStatusPanel HUD overlay.
 * Follows the BoolRef / FloatRef / IntRef + HudChrome pattern used by
 * VitalsConfig and AuraConfig sub-objects.
 * Serialised as a nested "statusPanel" block inside the auras save slot.
 */
class AuraStatusPanelConfig {
	/** Panel hidden on HUD (default true -- opt-in). */
	public var hidden = new BoolRef(true);
	/** Badge cell size in px (square icon face). */
	public var cellSize = new FloatRef(44);
	/** Number of badge columns in the grid (1-4). */
	public var columns = new IntRef(2);
	/** Overlay countdown seconds on each active badge. */
	public var showCountdown = new BoolRef(true);
	/** Draw fuse as a bottom strip instead of the right-edge bar. */
	public var fuseBottom = new BoolRef(true);
	/** Show ResourceTracker bars below the badge grid. */
	public var showResourceBars = new BoolRef(true);
	/** Height of each resource bar row in px. */
	public var barRowH = new FloatRef(18);
	/** Drag/lock/transparent chrome for the HUD window. */
	public var chrome = new HudChrome(200, 200);
	/** Content width; updated by resize grip callback. */
	public var panelW = new FloatRef(200);

	public function new() {}
}
