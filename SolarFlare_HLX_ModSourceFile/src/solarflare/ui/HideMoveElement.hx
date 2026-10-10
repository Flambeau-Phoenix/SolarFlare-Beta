package solarflare.ui;

import imgui.ref.BoolRef;
import imgui.ref.FloatRef;

/** Per-element hide/move/scale/alpha prefs. No live engine pointers. */
class HideMoveElement {
	public var id:String;
	public var label:String;
	/** DomKit Comp* type name, e.g. domkit.CompChatBox */
	public var typePath:String;
	public var visible:BoolRef;
	public var locked:BoolRef;
	public var x:FloatRef;
	public var y:FloatRef;
	public var scale:FloatRef;
	public var alpha:FloatRef;
	public var applyPos:BoolRef;
	public var applyScale:BoolRef;
	public var applyAlpha:BoolRef;

	public function new(id:String, label:String, typePath:String) {
		this.id = id;
		this.label = label;
		this.typePath = typePath;
		visible = new BoolRef(true);
		locked = new BoolRef(false);
		x = new FloatRef(0);
		y = new FloatRef(0);
		scale = new FloatRef(1);
		alpha = new FloatRef(1);
		applyPos = new BoolRef(false);
		applyScale = new BoolRef(false);
		applyAlpha = new BoolRef(false);
	}

	public function dump():Dynamic {
		return {
			id: id,
			visible: visible.get(),
			locked: locked.get(),
			x: x.get(),
			y: y.get(),
			scale: scale.get(),
			alpha: alpha.get(),
			applyPos: applyPos.get(),
			applyScale: applyScale.get(),
			applyAlpha: applyAlpha.get()
		};
	}

	public function apply(data:Dynamic):Void {
		if (data == null)
			return;
		setBool(visible, Reflect.field(data, "visible"));
		setBool(locked, Reflect.field(data, "locked"));
		setFloat(x, Reflect.field(data, "x"));
		setFloat(y, Reflect.field(data, "y"));
		setFloat(scale, Reflect.field(data, "scale"));
		setFloat(alpha, Reflect.field(data, "alpha"));
		setBool(applyPos, Reflect.field(data, "applyPos"));
		setBool(applyScale, Reflect.field(data, "applyScale"));
		setBool(applyAlpha, Reflect.field(data, "applyAlpha"));
	}

	static function setBool(ref:BoolRef, v:Dynamic):Void {
		if (Std.isOfType(v, Bool))
			ref.set(v);
	}

	static function setFloat(ref:FloatRef, v:Dynamic):Void {
		if (Std.isOfType(v, Float) || Std.isOfType(v, Int))
			ref.set(v);
	}
}
