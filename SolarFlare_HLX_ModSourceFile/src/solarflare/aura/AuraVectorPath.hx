package solarflare.aura;

/**
 * One anchor of a vector path. (ix, iy) and (ox, oy) are the absolute positions of its incoming and outgoing
 * Bezier handles; a handle equal to the anchor means "no curve on that side" (a corner).
 */
typedef PathNode = {x:Float, y:Float, ix:Float, iy:Float, ox:Float, oy:Float};

/** Result of reading SVG path data. `error` is empty on success. */
typedef SvgImport = {paths:Array<AuraVectorPath>, aspect:Float, error:String};

/**
 * Editable vector outline for the freeform canvas. Coordinates live in the unit square of the layer's box, so
 * resizing, moving and rotating the layer carry the whole path along. Native-free: parsing, flattening and
 * saving are unit tested without the game.
 */
class AuraVectorPath {
	public static inline var MAX_NODES:Int = 64;
	public static inline var MAX_SUBPATHS:Int = 16;
	/** Line segments used for each curved segment when flattening. */
	public static inline var CURVE_STEPS:Int = 8;
	static inline var COORD_MIN:Float = -4;
	static inline var COORD_MAX:Float = 5;

	public var nodes:Array<PathNode> = [];
	public var closed:Bool = false;
	var flatCache:Array<Float> = null;

	public function new() {}

	/** Call after editing nodes so the next draw re-flattens. */
	public function invalidate():Void flatCache = null;

	public function clone():AuraVectorPath {
		var p = new AuraVectorPath();
		p.closed = closed;
		p.nodes = [for (n in nodes) {x: n.x, y: n.y, ix: n.ix, iy: n.iy, ox: n.ox, oy: n.oy}];
		return p;
	}

	static inline function same(a:Float, b:Float):Bool return Math.abs(a - b) < 1e-9;

	inline function curved(a:PathNode, b:PathNode):Bool {
		return !(same(a.ox, a.x) && same(a.oy, a.y) && same(b.ix, b.x) && same(b.iy, b.y));
	}

	/** Interleaved x, y points along the outline in the layer's unit space. Cached until `invalidate()`. */
	public function flatPoints():Array<Float> {
		if (flatCache != null) return flatCache;
		var out:Array<Float> = [];
		var n = nodes.length;
		if (n > 0) out.push(nodes[0].x); if (n > 0) out.push(nodes[0].y);
		var segments = closed ? n : n - 1;
		for (i in 0...(segments < 0 ? 0 : segments)) {
			var a = nodes[i], b = nodes[(i + 1) % n];
			if (closed && i == n - 1 && n < 2) break;
			if (!curved(a, b)) {
				// A closing straight segment lands on the first point again; the polygon closes itself.
				if (!(closed && i == n - 1)) { out.push(b.x); out.push(b.y); }
				continue;
			}
			for (k in 1...CURVE_STEPS + 1) {
				var t = k / CURVE_STEPS, u = 1 - t;
				var w0 = u * u * u, w1 = 3 * u * u * t, w2 = 3 * u * t * t, w3 = t * t * t;
				if (closed && i == n - 1 && k == CURVE_STEPS) break;
				out.push(w0 * a.x + w1 * a.ox + w2 * b.ix + w3 * b.x);
				out.push(w0 * a.y + w1 * a.oy + w2 * b.iy + w3 * b.y);
			}
		}
		flatCache = out;
		return out;
	}

	// ---- Editing -----------------------------------------------------------------------------

	/** Appends a corner node; returns its index, or -1 at the node limit. */
	public function addNode(x:Float, y:Float):Int {
		if (nodes.length >= MAX_NODES) return -1;
		nodes.push({x: x, y: y, ix: x, iy: y, ox: x, oy: y});
		invalidate();
		return nodes.length - 1;
	}

	public function isCornerAt(i:Int):Bool {
		var n = nodes[i];
		return same(n.ix, n.x) && same(n.iy, n.y) && same(n.ox, n.x) && same(n.oy, n.y);
	}

	/** Both handles pulled out and in line through the anchor (a smooth join). */
	public function isSmooth(i:Int):Bool {
		var n = nodes[i];
		var ax = n.ix - n.x, ay = n.iy - n.y, bx = n.ox - n.x, by = n.oy - n.y;
		var la = Math.sqrt(ax * ax + ay * ay), lb = Math.sqrt(bx * bx + by * by);
		if (la < 1e-9 || lb < 1e-9) return false;
		return Math.abs(ax * by - ay * bx) / (la * lb) < 1e-3 && ax * bx + ay * by < 0;
	}

	public function setCorner(i:Int):Void {
		var n = nodes[i];
		n.ix = n.x; n.iy = n.y; n.ox = n.x; n.oy = n.y;
		invalidate();
	}

	/** Gives a node tangent handles along the line between its neighbours, a third of the way to each. */
	public function setSmooth(i:Int):Void {
		var n = nodes[i], count = nodes.length;
		var prev = i > 0 ? nodes[i - 1] : (closed && count > 2 ? nodes[count - 1] : null);
		var next = i < count - 1 ? nodes[i + 1] : (closed && count > 2 ? nodes[0] : null);
		if (prev == null && next == null) return;
		var dx:Float, dy:Float;
		if (prev != null && next != null) { dx = next.x - prev.x; dy = next.y - prev.y; }
		else if (next != null) { dx = next.x - n.x; dy = next.y - n.y; }
		else { dx = n.x - prev.x; dy = n.y - prev.y; }
		var len = Math.sqrt(dx * dx + dy * dy);
		if (len < 1e-9) return;
		dx /= len; dy /= len;
		var lin = prev != null ? Math.sqrt((n.x - prev.x) * (n.x - prev.x) + (n.y - prev.y) * (n.y - prev.y)) / 3 : 0;
		var lout = next != null ? Math.sqrt((next.x - n.x) * (next.x - n.x) + (next.y - n.y) * (next.y - n.y)) / 3 : 0;
		if (prev == null) lin = lout;
		if (next == null) lout = lin;
		n.ix = n.x - dx * lin; n.iy = n.y - dy * lin;
		n.ox = n.x + dx * lout; n.oy = n.y + dy * lout;
		invalidate();
	}

	/** Moves an anchor together with both of its handles. */
	public function moveNode(i:Int, dx:Float, dy:Float):Void {
		var n = nodes[i];
		n.x += dx; n.y += dy; n.ix += dx; n.iy += dy; n.ox += dx; n.oy += dy;
		invalidate();
	}

	/**
	 * Drags one handle to (x, y). With `mirror`, a node that already has a handle on the other side keeps it in
	 * line through the anchor and at its own length, so the join stays smooth.
	 */
	public function moveHandle(i:Int, outgoing:Bool, x:Float, y:Float, mirror:Bool):Void {
		var n = nodes[i];
		if (outgoing) { n.ox = x; n.oy = y; } else { n.ix = x; n.iy = y; }
		if (mirror) {
			var hx = x - n.x, hy = y - n.y, len = Math.sqrt(hx * hx + hy * hy);
			var ox = outgoing ? n.ix - n.x : n.ox - n.x, oy = outgoing ? n.iy - n.y : n.oy - n.y;
			var olen = Math.sqrt(ox * ox + oy * oy);
			if (len > 1e-9 && olen > 1e-9) {
				var mx = n.x - hx / len * olen, my = n.y - hy / len * olen;
				if (outgoing) { n.ix = mx; n.iy = my; } else { n.ox = mx; n.oy = my; }
			}
		}
		invalidate();
	}

	/** Removes an anchor; paths keep at least two. A closed path with fewer than three becomes open. */
	public function removeNode(i:Int):Bool {
		if (nodes.length <= 2 || i < 0 || i >= nodes.length) return false;
		nodes.splice(i, 1);
		if (closed && nodes.length < 3) closed = false;
		invalidate();
		return true;
	}

	public function setClosed(value:Bool):Void {
		closed = value && nodes.length >= 3;
		invalidate();
	}

	/** Same outline traced the other way round. */
	public function reverse():Void {
		nodes.reverse();
		for (n in nodes) { var tx = n.ix, ty = n.iy; n.ix = n.ox; n.iy = n.oy; n.ox = tx; n.oy = ty; }
		invalidate();
	}

	/**
	 * Splits segment `seg` (from node seg to the next) at parameter t, keeping the outline unchanged. Straight
	 * segments gain a corner; curves gain a smooth node. Returns the new node's index, or -1 when full.
	 */
	public function splitSegment(seg:Int, t:Float):Int {
		var n = nodes.length;
		if (n >= MAX_NODES || seg < 0 || seg >= (closed ? n : n - 1)) return -1;
		var a = nodes[seg], b = nodes[(seg + 1) % n];
		t = Math.max(0.001, Math.min(0.999, t));
		var node:PathNode;
		if (!curved(a, b)) {
			var x = a.x + (b.x - a.x) * t, y = a.y + (b.y - a.y) * t;
			node = {x: x, y: y, ix: x, iy: y, ox: x, oy: y};
		} else {
			inline function lp(p:Float, q:Float):Float return p + (q - p) * t;
			var q0x = lp(a.x, a.ox), q0y = lp(a.y, a.oy), q1x = lp(a.ox, b.ix), q1y = lp(a.oy, b.iy), q2x = lp(b.ix, b.x), q2y = lp(b.iy, b.y);
			var r0x = lp(q0x, q1x), r0y = lp(q0y, q1y), r1x = lp(q1x, q2x), r1y = lp(q1y, q2y);
			node = {x: lp(r0x, r1x), y: lp(r0y, r1y), ix: r0x, iy: r0y, ox: r1x, oy: r1y};
			a.ox = q0x; a.oy = q0y; b.ix = q2x; b.iy = q2y;
		}
		var at = seg + 1;
		nodes.insert(at, node);
		invalidate();
		return at;
	}

	/**
	 * Closest point on the outline to (px, py), measuring distance in pixels through the box scale (sx, sy).
	 * Null when nothing is within `maxDist`.
	 */
	public function nearestSegment(px:Float, py:Float, sx:Float, sy:Float, maxDist:Float):{seg:Int, t:Float, dist:Float} {
		var n = nodes.length, best:{seg:Int, t:Float, dist:Float} = null;
		var segments = closed ? n : n - 1;
		for (i in 0...(segments < 0 ? 0 : segments)) {
			var a = nodes[i], b = nodes[(i + 1) % n];
			var isCurve = curved(a, b), steps = isCurve ? 24 : 1;
			var prevX = a.x, prevY = a.y;
			for (k in 1...steps + 1) {
				var t = k / steps, u = 1 - t;
				var x = isCurve ? u * u * u * a.x + 3 * u * u * t * a.ox + 3 * u * t * t * b.ix + t * t * t * b.x : b.x;
				var y = isCurve ? u * u * u * a.y + 3 * u * u * t * a.oy + 3 * u * t * t * b.iy + t * t * t * b.y : b.y;
				// Distance from the point to this tiny chord, in pixels.
				var cx = (x - prevX) * sx, cy = (y - prevY) * sy, wx = (px - prevX) * sx, wy = (py - prevY) * sy;
				var len2 = cx * cx + cy * cy, f = len2 > 1e-12 ? Math.max(0, Math.min(1, (wx * cx + wy * cy) / len2)) : 0;
				var dx = wx - cx * f, dy = wy - cy * f, d = Math.sqrt(dx * dx + dy * dy);
				if (d <= maxDist && (best == null || d < best.dist)) best = {seg: i, t: ((k - 1) + f) / steps, dist: d};
				prevX = x; prevY = y;
			}
		}
		return best;
	}

	/**
	 * Rescales the nodes so the outline's bounding box becomes the unit square and returns the old box, letting the
	 * caller resize the layer to match so nothing moves on screen.
	 */
	public function fitUnit():{x0:Float, y0:Float, w:Float, h:Float} {
		var f = flatPoints(), minX = 1e30, minY = 1e30, maxX = -1e30, maxY = -1e30, i = 0;
		while (i + 1 < f.length) { minX = Math.min(minX, f[i]); maxX = Math.max(maxX, f[i]); minY = Math.min(minY, f[i + 1]); maxY = Math.max(maxY, f[i + 1]); i += 2; }
		if (minX > maxX) return {x0: 0, y0: 0, w: 1, h: 1};
		var w = maxX - minX, h = maxY - minY;
		var sx = w > 1e-9 ? 1 / w : 1, sy = h > 1e-9 ? 1 / h : 1;
		for (n in nodes) {
			n.x = (n.x - minX) * sx; n.ix = (n.ix - minX) * sx; n.ox = (n.ox - minX) * sx;
			n.y = (n.y - minY) * sy; n.iy = (n.iy - minY) * sy; n.oy = (n.oy - minY) * sy;
		}
		invalidate();
		return {x0: minX, y0: minY, w: w > 1e-9 ? w : 0, h: h > 1e-9 ? h : 0};
	}

	// ---- Saving ----------------------------------------------------------------------------

	static inline function r(v:Float):Float return Math.round(v * 10000) / 10000;

	/** Compact form: nodes as [x, y] for corners or [x, y, inX, inY, outX, outY] for curves. */
	public function toObj():Dynamic {
		var rows:Array<Dynamic> = [];
		for (n in nodes) {
			var corner = same(n.ix, n.x) && same(n.iy, n.y) && same(n.ox, n.x) && same(n.oy, n.y);
			rows.push(corner ? [r(n.x), r(n.y)] : [r(n.x), r(n.y), r(n.ix), r(n.iy), r(n.ox), r(n.oy)]);
		}
		var o:Dynamic = {n: rows};
		if (closed) o.c = true;
		return o;
	}

	static function clampCoord(v:Dynamic):Null<Float> {
		if (!Std.isOfType(v, Float) && !Std.isOfType(v, Int)) return null;
		var f:Float = v;
		return Math.isFinite(f) ? Math.max(COORD_MIN, Math.min(COORD_MAX, f)) : null;
	}

	/** Null when the record holds no usable nodes. Bad rows are skipped and values clamped. */
	public static function fromDyn(d:Dynamic):AuraVectorPath {
		if (d == null || !Std.isOfType(d.n, Array)) return null;
		var rows:Array<Dynamic> = cast d.n;
		var p = new AuraVectorPath();
		for (row in rows) {
			if (p.nodes.length >= MAX_NODES) break;
			if (!Std.isOfType(row, Array)) continue;
			var v:Array<Dynamic> = cast row;
			var x = v.length >= 2 ? clampCoord(v[0]) : null, y = v.length >= 2 ? clampCoord(v[1]) : null;
			if (x == null || y == null) continue;
			if (v.length >= 6) {
				var ix = clampCoord(v[2]), iy = clampCoord(v[3]), ox = clampCoord(v[4]), oy = clampCoord(v[5]);
				if (ix != null && iy != null && ox != null && oy != null) { p.nodes.push({x: x, y: y, ix: ix, iy: iy, ox: ox, oy: oy}); continue; }
			}
			p.nodes.push({x: x, y: y, ix: x, iy: y, ox: x, oy: y});
		}
		if (p.nodes.length == 0) return null;
		p.closed = d.c == true && p.nodes.length >= 3;
		return p;
	}

	// ---- SVG path data -----------------------------------------------------------------------

	/**
	 * Reads SVG `d` data (M L H V C S Q T A Z, absolute and relative). Every subpath becomes its own path; all
	 * share one bounding box, normalised to the unit square, so they line up when inserted with the same box.
	 * `aspect` is the artwork's width / height for sizing that box.
	 */
	public static function fromSvg(data:String):SvgImport {
		var fail = function(msg:String):SvgImport return {paths: [], aspect: 1, error: msg};
		if (data == null || StringTools.trim(data).length == 0) return fail("Paste SVG path data (the d=\"...\" value).");
		if (data.length > 20000) return fail("That path is too long. Simplify it first.");
		var parser = new SvgParser(data);
		var subs = parser.parse();
		if (parser.error.length > 0) return fail(parser.error);
		var usable = [for (s in subs) if (s.nodes.length >= 2) s];
		if (usable.length == 0) return fail("No drawable path found in that text.");
		var minX = 1e30, minY = 1e30, maxX = -1e30, maxY = -1e30;
		for (s in usable) {
			var f = s.flatPoints();
			var i = 0;
			while (i + 1 < f.length) { minX = Math.min(minX, f[i]); maxX = Math.max(maxX, f[i]); minY = Math.min(minY, f[i + 1]); maxY = Math.max(maxY, f[i + 1]); i += 2; }
		}
		var w = maxX - minX, h = maxY - minY;
		if (!Math.isFinite(w) || !Math.isFinite(h)) return fail("That path has invalid numbers.");
		var sx = w > 1e-9 ? 1 / w : 1, sy = h > 1e-9 ? 1 / h : 1;
		for (s in usable) {
			for (n in s.nodes) {
				n.x = (n.x - minX) * sx; n.ix = (n.ix - minX) * sx; n.ox = (n.ox - minX) * sx;
				n.y = (n.y - minY) * sy; n.iy = (n.iy - minY) * sy; n.oy = (n.oy - minY) * sy;
			}
			s.invalidate();
		}
		var aspect = h > 1e-9 && w > 1e-9 ? w / h : (w > 1e-9 ? 20 : 1);
		return {paths: usable, aspect: Math.max(0.05, Math.min(20, aspect)), error: ""};
	}
}

/** Tokeniser and path builder for SVG path data. Absolute coordinates; no normalisation. */
private class SvgParser {
	var s:String;
	var i:Int = 0;
	public var error:String = "";
	var subs:Array<AuraVectorPath> = [];
	var cur:AuraVectorPath = null;
	var cx:Float = 0;
	var cy:Float = 0;
	var sx:Float = 0;
	var sy:Float = 0;
	/** Last cubic / quadratic control point, for the smooth S and T commands. */
	var lcx:Float = 0;
	var lcy:Float = 0;
	var lastWasCubic:Bool = false;
	var lastWasQuad:Bool = false;

	public function new(data:String) { s = data; }

	function fail(msg:String):Void { if (error.length == 0) error = msg; }

	function skipSeparators():Void {
		while (i < s.length) {
			var c = s.charCodeAt(i);
			if (c == " ".code || c == ",".code || c == "\n".code || c == "\r".code || c == "\t".code) i++; else break;
		}
	}

	function atNumber():Bool {
		skipSeparators();
		if (i >= s.length) return false;
		var c = s.charCodeAt(i);
		return (c >= "0".code && c <= "9".code) || c == "-".code || c == "+".code || c == ".".code;
	}

	function number():Float {
		skipSeparators();
		var start = i;
		if (i < s.length && (s.charAt(i) == "-" || s.charAt(i) == "+")) i++;
		var dot = false;
		while (i < s.length) {
			var c = s.charCodeAt(i);
			if (c >= "0".code && c <= "9".code) i++;
			else if (c == ".".code && !dot) { dot = true; i++; }
			else break;
		}
		if (i < s.length && (s.charAt(i) == "e" || s.charAt(i) == "E")) {
			var save = i;
			i++;
			if (i < s.length && (s.charAt(i) == "-" || s.charAt(i) == "+")) i++;
			var digits = 0;
			while (i < s.length && s.charCodeAt(i) >= "0".code && s.charCodeAt(i) <= "9".code) { i++; digits++; }
			if (digits == 0) i = save;
		}
		var v = Std.parseFloat(s.substring(start, i));
		if (!Math.isFinite(v)) { fail("Could not read a number near position " + start + "."); return 0; }
		return v;
	}

	/** Arc flags are single 0/1 characters and may run into the next number. */
	function flag():Bool {
		skipSeparators();
		if (i < s.length && (s.charAt(i) == "0" || s.charAt(i) == "1")) return s.charAt(i++) == "1";
		fail("Bad arc flag.");
		return false;
	}

	function begin(x:Float, y:Float):Void {
		cur = new AuraVectorPath();
		cur.nodes.push({x: x, y: y, ix: x, iy: y, ox: x, oy: y});
		subs.push(cur);
		if (subs.length > AuraVectorPath.MAX_SUBPATHS) fail("Too many separate shapes (max " + AuraVectorPath.MAX_SUBPATHS + ").");
		cx = x; cy = y; sx = x; sy = y;
	}

	function ensure():Void { if (cur == null) begin(cx, cy); }

	function room():Bool {
		if (cur.nodes.length >= AuraVectorPath.MAX_NODES) { fail("A shape has more than " + AuraVectorPath.MAX_NODES + " points. Simplify it first."); return false; }
		return true;
	}

	function lineTo(x:Float, y:Float):Void {
		ensure();
		if (!room()) return;
		cur.nodes.push({x: x, y: y, ix: x, iy: y, ox: x, oy: y});
		cx = x; cy = y;
		lastWasCubic = false; lastWasQuad = false;
	}

	function cubicTo(x1:Float, y1:Float, x2:Float, y2:Float, x:Float, y:Float):Void {
		ensure();
		if (!room()) return;
		var last = cur.nodes[cur.nodes.length - 1];
		last.ox = x1; last.oy = y1;
		cur.nodes.push({x: x, y: y, ix: x2, iy: y2, ox: x, oy: y});
		cx = x; cy = y;
		lcx = x2; lcy = y2;
		lastWasCubic = true; lastWasQuad = false;
	}

	function quadTo(qx:Float, qy:Float, x:Float, y:Float):Void {
		var k = 2.0 / 3.0;
		cubicTo(cx + k * (qx - cx), cy + k * (qy - cy), x + k * (qx - x), y + k * (qy - y), x, y);
		lcx = qx; lcy = qy;
		lastWasCubic = false; lastWasQuad = true;
	}

	/** Endpoint arc to cubic segments (SVG implementation notes, F.6), at most 90 degrees each. */
	function arcTo(rx:Float, ry:Float, rotDeg:Float, large:Bool, sweep:Bool, x:Float, y:Float):Void {
		if (same(cx, x) && same(cy, y)) return;
		rx = Math.abs(rx); ry = Math.abs(ry);
		if (rx < 1e-9 || ry < 1e-9) { lineTo(x, y); return; }
		var phi = rotDeg * Math.PI / 180, cp = Math.cos(phi), sp = Math.sin(phi);
		var dx = (cx - x) / 2, dy = (cy - y) / 2;
		var x1 = cp * dx + sp * dy, y1 = -sp * dx + cp * dy;
		var lambda = (x1 * x1) / (rx * rx) + (y1 * y1) / (ry * ry);
		if (lambda > 1) { var sq = Math.sqrt(lambda); rx *= sq; ry *= sq; }
		var num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1;
		var den = rx * rx * y1 * y1 + ry * ry * x1 * x1;
		var coef = (large == sweep ? -1 : 1) * Math.sqrt(Math.max(0, num / den));
		var cxp = coef * (rx * y1 / ry), cyp = coef * -(ry * x1 / rx);
		var ccx = cp * cxp - sp * cyp + (cx + x) / 2, ccy = sp * cxp + cp * cyp + (cy + y) / 2;
		var a1 = Math.atan2((y1 - cyp) / ry, (x1 - cxp) / rx);
		var a2 = Math.atan2((-y1 - cyp) / ry, (-x1 - cxp) / rx);
		var delta = a2 - a1;
		if (sweep && delta < 0) delta += Math.PI * 2;
		if (!sweep && delta > 0) delta -= Math.PI * 2;
		var count = Std.int(Math.max(1, Math.ceil(Math.abs(delta) / (Math.PI / 2) - 1e-9)));
		var step = delta / count;
		var t = 4.0 / 3.0 * Math.tan(step / 4);
		var ang = a1;
		for (k in 0...count) {
			var c1 = Math.cos(ang), s1 = Math.sin(ang), c2 = Math.cos(ang + step), s2 = Math.sin(ang + step);
			var p1x = c1 - t * s1, p1y = s1 + t * c1, p2x = c2 + t * s2, p2y = s2 - t * c2;
			function px(ux:Float, uy:Float):Float return cp * rx * ux - sp * ry * uy + ccx;
			function py(ux:Float, uy:Float):Float return sp * rx * ux + cp * ry * uy + ccy;
			var ex = k == count - 1 ? x : px(c2, s2), ey = k == count - 1 ? y : py(c2, s2);
			cubicTo(px(p1x, p1y), py(p1x, p1y), px(p2x, p2y), py(p2x, p2y), ex, ey);
			ang += step;
			if (error.length > 0) return;
		}
		lastWasCubic = false; lastWasQuad = false;
	}

	static inline function same(a:Float, b:Float):Bool return Math.abs(a - b) < 1e-9;

	function close():Void {
		if (cur == null) return;
		var first = cur.nodes[0], last = cur.nodes[cur.nodes.length - 1];
		if (cur.nodes.length > 1 && same(first.x, last.x) && same(first.y, last.y)) {
			first.ix = last.ix; first.iy = last.iy;
			cur.nodes.pop();
		}
		cur.closed = cur.nodes.length >= 3;
		cx = sx; cy = sy;
		cur = null;
		lastWasCubic = false; lastWasQuad = false;
	}

	public function parse():Array<AuraVectorPath> {
		var cmd = "";
		while (error.length == 0) {
			skipSeparators();
			if (i >= s.length) break;
			var c = s.charAt(i);
			if (!atNumber()) {
				if ("MmLlHhVvCcSsQqTtAaZz".indexOf(c) < 0) { fail("Unsupported path command \"" + c + "\"."); break; }
				cmd = c; i++;
				if (subs.length == 0 && cmd != "M" && cmd != "m") { fail("Path data must start with M."); break; }
				if (cmd == "Z" || cmd == "z") { close(); continue; }
			} else if (cmd == "" || cmd == "Z" || cmd == "z") { fail("Path data must start with M."); break; }
			var rel = cmd == cmd.toLowerCase();
			var ox = rel ? cx : 0, oy = rel ? cy : 0;
			switch (cmd.toUpperCase()) {
				case "M":
					var x = number() + ox, y = number() + oy;
					begin(x, y);
					// Extra coordinate pairs after M are implicit line-to commands.
					cmd = rel ? "l" : "L";
				case "L": lineTo(number() + ox, number() + oy);
				case "H": lineTo(number() + ox, cy);
				case "V": lineTo(cx, number() + oy);
				case "C":
					var x1 = number() + ox, y1 = number() + oy, x2 = number() + ox, y2 = number() + oy, x = number() + ox, y = number() + oy;
					cubicTo(x1, y1, x2, y2, x, y);
				case "S":
					var x2 = number() + ox, y2 = number() + oy, x = number() + ox, y = number() + oy;
					var x1 = lastWasCubic ? 2 * cx - lcx : cx, y1 = lastWasCubic ? 2 * cy - lcy : cy;
					cubicTo(x1, y1, x2, y2, x, y);
				case "Q":
					var qx = number() + ox, qy = number() + oy, x = number() + ox, y = number() + oy;
					quadTo(qx, qy, x, y);
				case "T":
					var x = number() + ox, y = number() + oy;
					var qx = lastWasQuad ? 2 * cx - lcx : cx, qy = lastWasQuad ? 2 * cy - lcy : cy;
					quadTo(qx, qy, x, y);
				case "A":
					var rx = number(), ry = number(), rot = number();
					var large = flag(), sweep = flag();
					arcTo(rx, ry, rot, large, sweep, number() + ox, number() + oy);
				default: fail("Unsupported path command.");
			}
		}
		return subs;
	}
}
