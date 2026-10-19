package solarflare.aura;

import haxe.io.Bytes;

/**
 * Outline of an image's visible shape, found once when the image is loaded. The alpha channel is thinned to a
 * coarse grid, marching squares walks the edge between see-through and solid, and the loops are simplified. Each
 * loop is returned as interleaved x, y in the image's unit square, ordered with the solid side on the left of
 * travel (screen space, y down), so `AuraPolyline.offsetClosed` can grow or shrink it. Native-free.
 */
class AuraAlphaContour {
	/** Longest side of the sampling grid. */
	public static inline var GRID:Int = 128;
	public static inline var MAX_LOOPS:Int = 12;
	public static inline var MAX_POINTS:Int = 900;
	/** Alpha (0-255 average over a grid cell) at or above which a cell counts as solid. */
	public static inline var THRESHOLD:Int = 96;

	/** `bgra` holds 4 bytes per pixel with alpha last (as the PNG reader returns them). */
	public static function trace(bgra:Bytes, width:Int, height:Int):Array<Array<Float>> {
		if (bgra == null || width < 1 || height < 1 || bgra.length < width * height * 4) return [];
		var step = Std.int(Math.max(1, Math.ceil(Math.max(width, height) / GRID)));
		var gw = Std.int(Math.ceil(width / step)), gh = Std.int(Math.ceil(height / step));
		var solid = new haxe.ds.Vector<Bool>((gw + 2) * (gh + 2));
		var any = false;
		for (cy in 0...gh) for (cx in 0...gw) {
			var x0 = cx * step, y0 = cy * step, x1 = Std.int(Math.min(width, x0 + step)), y1 = Std.int(Math.min(height, y0 + step));
			var sum = 0, count = 0;
			for (y in y0...y1) {
				var row = y * width * 4 + 3;
				for (x in x0...x1) { sum += bgra.get(row + x * 4); count++; }
			}
			var on = count > 0 && sum >= THRESHOLD * count;
			solid[(cy + 1) * (gw + 2) + cx + 1] = on;
			if (on) any = true;
		}
		return any ? loops(solid, gw, gh) : [];
	}

	// Edge ids in a marching-squares cell: 0 top, 1 right, 2 bottom, 3 left. Corners: 0 tl, 1 tr, 2 br, 3 bl.
	static var PAIRS:Array<Array<Int>> = [
		[], [3, 0], [0, 1], [3, 1], [1, 2], [3, 0, 1, 2], [0, 2], [3, 2],
		[2, 3], [0, 2], [0, 1, 2, 3], [1, 2], [3, 1], [0, 1], [3, 0], []
	];
	/** Corner each segment cuts off (used to put the solid side on the left). Saddles list one per segment. */
	static var REFS:Array<Array<Int>> = [
		[], [0], [1], [0], [2], [0, 2], [1], [0],
		[3], [0], [1, 3], [0], [2], [0], [1], []
	];

	static function loops(solid:haxe.ds.Vector<Bool>, gw:Int, gh:Int):Array<Array<Float>> {
		var sw = gw + 2;
		// A segment runs between two edge midpoints. Edge key = vertex index * 2 + (0 horizontal | 1 vertical).
		var next = new Map<Int, Int>();
		var pos = new Map<Int, Array<Float>>();
		function edgeKey(cx:Int, cy:Int, edge:Int):Int {
			return switch (edge) {
				case 0: (cy * sw + cx) * 2;
				case 1: (cy * sw + cx + 1) * 2 + 1;
				case 2: ((cy + 1) * sw + cx) * 2;
				default: (cy * sw + cx) * 2 + 1;
			}
		}
		// Sample i is the centre of grid cell i - 1, so unit x of sample i is (i - 0.5) / gw.
		function edgePos(cx:Int, cy:Int, edge:Int):Array<Float> {
			return switch (edge) {
				case 0: [cx / gw, (cy - 0.5) / gh];
				case 1: [(cx + 0.5) / gw, cy / gh];
				case 2: [cx / gw, (cy + 0.5) / gh];
				default: [(cx - 0.5) / gw, cy / gh];
			}
		}
		var cornerDx = [0, 1, 1, 0], cornerDy = [0, 0, 1, 1];
		for (cy in 0...gh + 1) for (cx in 0...gw + 1) {
			var tl = solid[cy * sw + cx], tr = solid[cy * sw + cx + 1], br = solid[(cy + 1) * sw + cx + 1], bl = solid[(cy + 1) * sw + cx];
			var idx = (tl ? 1 : 0) | (tr ? 2 : 0) | (br ? 4 : 0) | (bl ? 8 : 0);
			var pairs = PAIRS[idx], refs = REFS[idx];
			var s = 0;
			while (s < pairs.length) {
				var ea = pairs[s], eb = pairs[s + 1];
				var pa = edgePos(cx, cy, ea), pb = edgePos(cx, cy, eb);
				var ref = refs[s >> 1];
				var rx = (cx + cornerDx[ref] - 0.5) / gw, ry = (cy + cornerDy[ref] - 0.5) / gh;
				var refSolid = [tl, tr, br, bl][ref];
				// y-down: the left of travel (dx, dy) is (dy, -dx). The reference corner is solid for the
				// corner-cutting cases and see-through for the 3-solid cases, so it decides the direction.
				var dx = pb[0] - pa[0], dy = pb[1] - pa[1];
				var side = dy * (rx - pa[0]) - dx * (ry - pa[1]);
				var forward = refSolid ? side > 0 : side < 0;
				var from = forward ? ea : eb, to = forward ? eb : ea;
				var kf = edgeKey(cx, cy, from), kt = edgeKey(cx, cy, to);
				next.set(kf, kt);
				pos.set(kf, forward ? pa : pb);
				pos.set(kt, forward ? pb : pa);
				s += 2;
			}
		}
		var seen = new Map<Int, Bool>();
		var found:Array<{pts:Array<Float>, area:Float}> = [];
		for (start in next.keys()) {
			if (seen.exists(start)) continue;
			var loop:Array<Float> = [];
			var k = start, guard = 0;
			while (!seen.exists(k) && next.exists(k) && guard++ < 100000) {
				seen.set(k, true);
				var p = pos.get(k);
				loop.push(p[0]); loop.push(p[1]);
				k = next.get(k);
			}
			if (k != start || loop.length < 6) continue;
			found.push({pts: loop, area: Math.abs(AuraPolyLoop.signedArea(loop))});
		}
		// Keep the biggest shapes; specks of only a few grid cells are noise.
		found.sort(function(a, b) return a.area < b.area ? 1 : (a.area > b.area ? -1 : 0));
		var minArea = 3.0 / (gw * gh);
		var kept:Array<Array<Float>> = [];
		for (l in found) {
			if (kept.length >= MAX_LOOPS || l.area < minArea) break;
			kept.push(l.pts);
		}
		var eps = 0.0035, total = 0;
		var simplified:Array<Array<Float>> = [];
		for (attempt in 0...6) {
			simplified = [];
			total = 0;
			for (l in kept) {
				var r = AuraPolyline.rdp(l.concat([l[0], l[1]]), eps);
				r.pop(); r.pop();
				if (r.length >= 6) { simplified.push(r); total += r.length >> 1; }
			}
			if (total <= MAX_POINTS) break;
			eps *= 1.8;
		}
		return simplified;
	}
}
