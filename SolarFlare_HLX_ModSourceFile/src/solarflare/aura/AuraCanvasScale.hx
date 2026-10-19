package solarflare.aura;

/** How a freeform canvas follows its HUD window when the player drags the window's corner. */
class AuraCanvasScale {
	public static inline var MIN:Float = 0.4;
	public static inline var MAX:Float = 6.0;

	public static inline function clamp(v:Float):Float return Math.max(MIN, Math.min(MAX, v));

	/**
	 * New Scale for a canvas whose content box was dragged to `newW` x `newH`. The canvas keeps its shape, so the
	 * dimension the player moved the most decides the scale, and the window then snaps back to the canvas's
	 * proportions. Bad input leaves the current scale unchanged.
	 */
	public static function fromResize(current:Float, newW:Float, newH:Float, designW:Float, designH:Float):Float {
		if (!Math.isFinite(current) || !Math.isFinite(newW) || !Math.isFinite(newH)) return clamp(Math.isFinite(current) ? current : 1);
		var dw = Math.max(24, Math.isFinite(designW) ? designW : 96), dh = Math.max(24, Math.isFinite(designH) ? designH : 96);
		var byW = newW / dw, byH = newH / dh;
		return clamp(Math.abs(byW - current) >= Math.abs(byH - current) ? byW : byH);
	}
}
