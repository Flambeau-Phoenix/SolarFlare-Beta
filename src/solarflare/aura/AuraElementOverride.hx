package solarflare.aura;

/** Per-state replacements for a canvas element's placement and tint. Unset fields keep the element's own value. */
class AuraElementOverride {
	public var x:Null<Float> = null;
	public var y:Null<Float> = null;
	public var w:Null<Float> = null;
	public var h:Null<Float> = null;
	public var color:Null<Int> = null;
	public var opacity:Null<Float> = null;
	public var rotation:Null<Float> = null;
	public var hidden:Null<Bool> = null;

	public function new() {}

	public function isEmpty():Bool return x == null && y == null && w == null && h == null && color == null && opacity == null && rotation == null && hidden == null;

	public function clone():AuraElementOverride {
		var o = new AuraElementOverride();
		o.x = x; o.y = y; o.w = w; o.h = h; o.color = color; o.opacity = opacity; o.rotation = rotation; o.hidden = hidden;
		return o;
	}

	public function toObj():Dynamic {
		var o:Dynamic = {};
		if (x != null) o.x = x;
		if (y != null) o.y = y;
		if (w != null) o.w = w;
		if (h != null) o.h = h;
		if (color != null) o.color = color;
		if (opacity != null) o.opacity = opacity;
		if (rotation != null) o.rotation = rotation;
		if (hidden != null) o.hidden = hidden;
		return o;
	}

	public static function fromDyn(d:Dynamic):AuraElementOverride {
		var o = new AuraElementOverride();
		if (d == null) return o;
		o.x = pos(d.x); o.y = pos(d.y);
		o.w = size(d.w); o.h = size(d.h);
		if (d.color != null) o.color = Std.int(d.color);
		var op:Null<Float> = d.opacity;
		if (op != null && Math.isFinite(op)) o.opacity = AuraCanvasElement.clampOpacity(op);
		var rot:Null<Float> = d.rotation;
		if (rot != null && Math.isFinite(rot)) o.rotation = AuraCanvasElement.clampRotation(rot);
		if (d.hidden == true || d.hidden == false) o.hidden = d.hidden;
		return o;
	}

	static function pos(v:Dynamic):Null<Float> {
		var f:Null<Float> = v;
		return f != null && Math.isFinite(f) ? Math.max(-4000, Math.min(4000, f)) : null;
	}
	static function size(v:Dynamic):Null<Float> {
		var f:Null<Float> = v;
		return f != null && Math.isFinite(f) ? Math.max(1, Math.min(4000, f)) : null;
	}
}
