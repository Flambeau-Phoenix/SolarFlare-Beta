package solarflare.aura;

/**
 * Packs member boxes for a dynamic Aura group. Pure math with reused arrays: the HUD and the builder
 * preview call compute() each frame without allocating once the arrays have grown to the member count.
 */
class AuraGroupLayout {
	/** Top-left of each member inside the group box, in input order. */
	public var xs:Array<Float> = [];
	public var ys:Array<Float> = [];
	public var totalW:Float = 0;
	public var totalH:Float = 0;
	public var count:Int = 0;

	var lineMain:Array<Float> = [];
	var lineCross:Array<Float> = [];

	public function new() {}

	/**
	 * Lay out `n` boxes (`ws[i]` x `hs[i]`). Members fill a line along `grow`, wrapping every `wrap`
	 * members (0 = one line); further lines stack below (rows) or to the right (columns).
	 */
	public function compute(ws:Array<Float>, hs:Array<Float>, n:Int, grow:String, wrap:Int, spacing:Float, align:String):Void {
		count = n;
		totalW = 0;
		totalH = 0;
		if (n <= 0) return;
		var horizontal = grow != "down" && grow != "up";
		var reverse = grow == "left" || grow == "up";
		var per = wrap > 0 ? wrap : n;
		var lines = Std.int((n + per - 1) / per);
		if (spacing < 0) spacing = 0;
		for (l in 0...lines) {
			var main:Float = 0;
			var cross:Float = 0;
			var k = 0;
			var i = l * per;
			while (i < n && k < per) {
				var m = horizontal ? ws[i] : hs[i];
				var c = horizontal ? hs[i] : ws[i];
				main += (k > 0 ? spacing : 0) + m;
				if (c > cross) cross = c;
				i++;
				k++;
			}
			setAt(lineMain, l, main);
			setAt(lineCross, l, cross);
		}
		var totalMain:Float = 0;
		var totalCross:Float = 0;
		for (l in 0...lines) {
			if (lineMain[l] > totalMain) totalMain = lineMain[l];
			totalCross += (l > 0 ? spacing : 0) + lineCross[l];
		}
		var crossAt:Float = 0;
		for (l in 0...lines) {
			var mainAt:Float = 0;
			var k = 0;
			var i = l * per;
			while (i < n && k < per) {
				var m = horizontal ? ws[i] : hs[i];
				var c = horizontal ? hs[i] : ws[i];
				var slack = lineCross[l] - c;
				var off = align == "start" ? 0 : (align == "end" ? slack : slack * 0.5);
				var mainPos = reverse ? totalMain - mainAt - m : mainAt;
				var crossPos = crossAt + off;
				setAt(xs, i, horizontal ? mainPos : crossPos);
				setAt(ys, i, horizontal ? crossPos : mainPos);
				mainAt += m + spacing;
				i++;
				k++;
			}
			crossAt += lineCross[l] + spacing;
		}
		totalW = horizontal ? totalMain : totalCross;
		totalH = horizontal ? totalCross : totalMain;
	}

	/** Soonest expiry first; infinite or unknown time sorts last. Negative = a before b. */
	public static function compareTime(aInf:Bool, aLeft:Float, bInf:Bool, bLeft:Float):Int {
		var aKnown = !aInf && Math.isFinite(aLeft) && aLeft >= 0;
		var bKnown = !bInf && Math.isFinite(bLeft) && bLeft >= 0;
		if (aKnown && bKnown) return aLeft < bLeft ? -1 : (aLeft > bLeft ? 1 : 0);
		if (aKnown) return -1;
		if (bKnown) return 1;
		return 0;
	}

	static inline function setAt(arr:Array<Float>, i:Int, v:Float):Void {
		if (i < arr.length) arr[i] = v; else arr.push(v);
	}
}
