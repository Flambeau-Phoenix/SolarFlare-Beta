package solarflare.aura;

/**
 * Closed loops of interleaved x, y points: winding and sideways offsets for outlines. A loop is "solid on the
 * left" (screen space, y down) when its signed area is negative, which is how `AuraAlphaContour` returns them.
 */
class AuraPolyLoop {
	/** Shoelace area in screen space (y down). Negative = the inside is on the left of travel. */
	public static function signedArea(pts:Array<Float>):Float {
		var n = pts.length >> 1, sum = 0.0;
		for (i in 0...n) {
			var j = (i + 1) % n;
			sum += pts[i * 2] * pts[j * 2 + 1] - pts[j * 2] * pts[i * 2 + 1];
		}
		return sum * 0.5;
	}

	/** The same loop traced the other way round. */
	public static function reversed(pts:Array<Float>):Array<Float> {
		var n = pts.length >> 1, out:Array<Float> = [];
		var i = n - 1;
		while (i >= 0) { out.push(pts[i * 2]); out.push(pts[i * 2 + 1]); i--; }
		return out;
	}

	/** Loop with its inside on the left of travel, whichever way it was drawn. */
	public static function insideLeft(pts:Array<Float>):Array<Float> {
		return signedArea(pts) > 0 ? reversed(pts) : pts;
	}

	/**
	 * Moves a closed loop sideways by `dist`. The loop must have its inside on the left of travel; positive
	 * `dist` then moves it outwards, negative inwards. Corners are mitred, with the mitre capped so sharp spikes
	 * stay bounded.
	 */
	public static function offset(pts:Array<Float>, dist:Float, miterLimit:Float = 2.5):Array<Float> {
		var n = pts.length >> 1;
		if (n < 3 || dist == 0) return pts.copy();
		var out:Array<Float> = [];
		for (i in 0...n) {
			var p = (i + n - 1) % n, q = (i + 1) % n;
			var e1x = pts[i * 2] - pts[p * 2], e1y = pts[i * 2 + 1] - pts[p * 2 + 1];
			var e2x = pts[q * 2] - pts[i * 2], e2y = pts[q * 2 + 1] - pts[i * 2 + 1];
			var l1 = Math.sqrt(e1x * e1x + e1y * e1y), l2 = Math.sqrt(e2x * e2x + e2y * e2y);
			if (l1 < 1e-9 && l2 < 1e-9) { out.push(pts[i * 2]); out.push(pts[i * 2 + 1]); continue; }
			if (l1 < 1e-9) { e1x = e2x; e1y = e2y; l1 = l2; }
			if (l2 < 1e-9) { e2x = e1x; e2y = e1y; l2 = l1; }
			// Right-hand normal of travel in y-down space is (-dy, dx); with the inside on the left that points outwards.
			var n1x = -e1y / l1, n1y = e1x / l1, n2x = -e2y / l2, n2y = e2x / l2;
			var mx = n1x + n2x, my = n1y + n2y, ml = Math.sqrt(mx * mx + my * my);
			if (ml < 1e-6) { mx = n1x; my = n1y; ml = 1; }
			mx /= ml; my /= ml;
			var cosHalf = mx * n1x + my * n1y;
			var scale = cosHalf > 1e-3 ? Math.min(miterLimit, 1 / cosHalf) : miterLimit;
			out.push(pts[i * 2] + mx * dist * scale);
			out.push(pts[i * 2 + 1] + my * dist * scale);
		}
		return out;
	}
}
