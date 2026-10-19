package solarflare.aura;

/**
 * Polyline helpers shared by SVG import and layer outlines. Points are interleaved x, y. Native-free so the
 * geometry is unit tested without the game.
 */
class AuraPolyline {
	/** Ramer-Douglas-Peucker. Iterative, so a long outline cannot overflow the stack. Endpoints are always kept. */
	public static function rdp(pts:Array<Float>, eps:Float):Array<Float> {
		var n = pts.length >> 1;
		if (n <= 2) return pts.copy();
		var keep = [for (_ in 0...n) false];
		keep[0] = true; keep[n - 1] = true;
		var stack:Array<Int> = [0, n - 1];
		while (stack.length > 0) {
			var hi = stack.pop(), lo = stack.pop();
			if (hi - lo < 2) continue;
			var ax = pts[lo * 2], ay = pts[lo * 2 + 1], bx = pts[hi * 2], by = pts[hi * 2 + 1];
			var dx = bx - ax, dy = by - ay, len2 = dx * dx + dy * dy;
			var worst = -1.0, at = -1;
			for (i in lo + 1...hi) {
				var px = pts[i * 2] - ax, py = pts[i * 2 + 1] - ay, d:Float;
				if (len2 < 1e-18) d = Math.sqrt(px * px + py * py);
				else {
					var f = Math.max(0, Math.min(1, (px * dx + py * dy) / len2));
					var qx = px - dx * f, qy = py - dy * f;
					d = Math.sqrt(qx * qx + qy * qy);
				}
				if (d > worst) { worst = d; at = i; }
			}
			if (at >= 0 && worst > eps) {
				keep[at] = true;
				stack.push(lo); stack.push(at);
				stack.push(at); stack.push(hi);
			}
		}
		var out:Array<Float> = [];
		for (i in 0...n) if (keep[i]) { out.push(pts[i * 2]); out.push(pts[i * 2 + 1]); }
		return out;
	}

	/**
	 * Fewest-possible simplification that leaves at most `maxPoints` points, found by bisecting the tolerance.
	 * A closed outline is simplified as a loop and returned without a repeated first point.
	 */
	public static function reduceTo(pts:Array<Float>, closed:Bool, maxPoints:Int):Array<Float> {
		var n = pts.length >> 1;
		if (n <= maxPoints || maxPoints < 2) return pts.copy();
		var minX = 1e30, minY = 1e30, maxX = -1e30, maxY = -1e30;
		for (i in 0...n) {
			minX = Math.min(minX, pts[i * 2]); maxX = Math.max(maxX, pts[i * 2]);
			minY = Math.min(minY, pts[i * 2 + 1]); maxY = Math.max(maxY, pts[i * 2 + 1]);
		}
		var diag = Math.sqrt((maxX - minX) * (maxX - minX) + (maxY - minY) * (maxY - minY));
		if (!(diag > 1e-12)) return pts.slice(0, maxPoints * 2);
		var src = pts;
		if (closed) { src = pts.copy(); src.push(pts[0]); src.push(pts[1]); }
		var lo = 0.0, hi = diag * 0.5, best:Array<Float> = null;
		for (_ in 0...28) {
			var mid = (lo + hi) * 0.5;
			var r = rdp(src, mid);
			var count = (r.length >> 1) - (closed ? 1 : 0);
			if (count <= maxPoints) { best = r; hi = mid; } else lo = mid;
		}
		if (best == null) best = rdp(src, hi);
		if (closed) { best.pop(); best.pop(); }
		return best;
	}
}
