package solarflare.aura;

import solarflare.aura.signal.AuraRuleDef;
import solarflare.aura.signal.AuraRuleResult;
import solarflare.aura.signal.AuraRuleCodec;
import solarflare.aura.signal.AuraRuleEvaluator;
import solarflare.aura.signal.AuraSignalFrame;

/**
 * Freeform canvas placement inside an Aura window (region=canvas).
 * Coordinates are local to the aura body origin.
 */
@:keep
class AuraCanvasElement {
	public static inline var KIND_TEXT:String = "text";
	public static inline var KIND_ICON:String = "icon";
	/** Vector plate; content holds one of SHAPES. */
	public static inline var KIND_SHAPE:String = "shape";

	public static var SHAPES:Array<String> = ["rect", "rounded", "circle", "diamond", "hex", "triangle", "line"];

	/** Icon content with this prefix names a PNG in the user's custom image folder. */
	public static inline var CUSTOM_PREFIX:String = "custom:";

	public var kind:String;
	/** Text content (supports {time} / {name}), icon texture id, or shape name. */
	public var content:String;
	public var x:Float;
	public var y:Float;
	public var w:Float;
	public var h:Float;
	public var fontSize:Float;
	/** Packed 0xAARRGGBB. */
	public var color:Int;
	/** Skipped by the renderer; still listed and editable. */
	public var hidden:Bool = false;
	/** Optional independent visibility conditions; null preserves legacy display. */
	public var visibilityRule:AuraRuleDef = null;
	public var visibilityResult(default, null):AuraRuleResult = new AuraRuleResult();
	public function observeVisibility(frame:AuraSignalFrame):Void {
		if (visibilityRule == null) visibilityResult.reset();
		else {
			AuraRuleEvaluator.evaluate(visibilityRule, frame, visibilityResult);
			// Invalid entries cannot be masked by a true sibling in an ANY rule.
			for (i in 0...visibilityResult.totalCount) {
				var code = visibilityResult.conditions[i].code;
				if (code == UNKNOWN_SIGNAL || code == INVALID_OPERATOR || code == INVALID_RULE || code == NON_FINITE) {
					visibilityResult.known = false; visibilityResult.hit = false; visibilityResult.code = code;
					break;
				}
			}
		}
	}
	/** Shared by drawing, bounds and editor hit testing. */
	public inline function visible(editAll:Bool = false):Bool {
		return !hidden && (editAll || visibilityRule == null || visibilityResult.known && visibilityResult.hit);
	}
	public function clearVisibility():Void { visibilityResult.reset(); }
	/** Ignores stage clicks and drags so plates under text stay put. */
	public var locked:Bool = false;
	/** Text: 1 px drop shadow for readability over icons. */
	public var shadow:Bool = false;
	/** Shape: 0 = filled, otherwise outline thickness in px. */
	public var stroke:Float = 0;

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

	public static function shape(name:String, x:Float, y:Float, w:Float, h:Float, color:Int = 0xC0101418):AuraCanvasElement {
		return new AuraCanvasElement(KIND_SHAPE, name, x, y, w, h, 16, color);
	}

	public inline function isCustomImage():Bool {
		return kind == KIND_ICON && content != null && StringTools.startsWith(content, CUSTOM_PREFIX);
	}

	public function toObj():Dynamic {
		var o:Dynamic = {
			kind: kind != null ? kind : KIND_TEXT,
			content: content != null ? content : "",
			x: x,
			y: y,
			w: w,
			h: h,
			fontSize: fontSize,
			color: color
		};
		// Optional fields stay out of share keys until used.
		if (hidden) o.hidden = true;
		if (visibilityRule != null) o.visibilityRule = AuraRuleCodec.toObj(visibilityRule);
		if (locked) o.locked = true;
		if (shadow) o.shadow = true;
		if (stroke > 0) o.stroke = stroke;
		return o;
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
		var el = new AuraCanvasElement(kind, content, x, y, w, h, fontSize, color);
		el.hidden = d.hidden == true;
		if (d.visibilityRule != null) el.visibilityRule = AuraRuleCodec.fromDyn(d.visibilityRule);
		el.locked = d.locked == true;
		el.shadow = d.shadow == true;
		var stroke:Null<Float> = d.stroke;
		el.stroke = stroke != null && Math.isFinite(stroke) ? Math.max(0, Math.min(16, stroke)) : 0;
		return el;
	}
}
