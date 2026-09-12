package solarflare.aura;

/**
 * Freeform canvas placement inside an Aura window (region=canvas).
 * Coordinates are local to the aura body origin.
 */
@:keep
class AuraCanvasElement {
	public static inline var KIND_TEXT:String = "text";
	public static inline var KIND_ICON:String = "icon";

	public var kind:String;
	/** Text content (supports {time} / {name}) or icon texture id. */
	public var content:String;
	public var x:Float;
	public var y:Float;
	public var w:Float;
	public var h:Float;
	public var fontSize:Float;
	/** Packed 0xAARRGGBB. */
	public var color:Int;

	public function new(kind:String = KIND_TEXT, content:String = "", x:Float = 0, y:Float = 0, w:Float = 32, h:Float = 32,
			fontSize:Float = 16, color:Int = 0xFFFFFFFF) {
		this.kind = kind != null ? kind : KIND_TEXT;
		this.content = content != null ? content : "";
		this.x = x;
		this.y = y;
		this.w = w;
		this.h = h;
		this.fontSize = fontSize;
		this.color = color;
	}

	public static function text(content:String, x:Float, y:Float, fontSize:Float = 16, color:Int = 0xFFFFFFFF):AuraCanvasElement {
		return new AuraCanvasElement(KIND_TEXT, content, x, y, 0, 0, fontSize, color);
	}

	public static function icon(textureId:String, x:Float, y:Float, w:Float, h:Float, color:Int = 0xFFFFFFFF):AuraCanvasElement {
		return new AuraCanvasElement(KIND_ICON, textureId, x, y, w, h, 16, color);
	}

	public function toObj():Dynamic {
		return {
			kind: kind != null ? kind : KIND_TEXT,
			content: content != null ? content : "",
			x: x,
			y: y,
			w: w,
			h: h,
			fontSize: fontSize,
			color: color
		};
	}

	public static function fromDyn(d:Dynamic):AuraCanvasElement {
		if (d == null)
			return new AuraCanvasElement();
		var kind = d.kind != null ? Std.string(d.kind) : KIND_TEXT;
		var content = d.content != null ? Std.string(d.content) : "";
		var x:Float = d.x != null ? d.x : 0;
		var y:Float = d.y != null ? d.y : 0;
		var w:Float = d.w != null ? d.w : 32;
		var h:Float = d.h != null ? d.h : 32;
		var fontSize:Float = d.fontSize != null ? d.fontSize : 16;
		var color:Int = d.color != null ? Std.int(d.color) : 0xFFFFFFFF;
		return new AuraCanvasElement(kind, content, x, y, w, h, fontSize, color);
	}
}
