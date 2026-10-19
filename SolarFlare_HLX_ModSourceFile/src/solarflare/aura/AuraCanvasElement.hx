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
	/** Editable vector outline (nodes and Bezier handles) held in `path`. */
	public static inline var KIND_PATH:String = "path";

	/** Cap on states an element can reference (matches AuraStateDef.MAX_STATES plus headroom for stale ids). */
	public static inline var MAX_STATE_REFS:Int = 16;
	public static inline var MAX_NAME:Int = 32;

	public static var SHAPES:Array<String> = ["rect", "rounded", "circle", "diamond", "hex", "triangle", "line", "polygon", "star", "ring", "chevron"];

	/** Icon content with this prefix names a PNG in the user's custom image folder. */
	public static inline var CUSTOM_PREFIX:String = solarflare.ui.CustomImageKey.PREFIX;

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
	/** State ids this element is drawn in; null means every state. "" is the Default look. */
	public var inStates:Array<String> = null;
	/** Per-state replacements keyed by state id (never ""). Null when the element has none. */
	public var overrides:Map<String, AuraElementOverride> = null;

	public inline function ov(sid:String):AuraElementOverride return overrides != null && sid != null && sid != "" ? overrides.get(sid) : null;
	public inline function xAt(sid:String):Float { var o = ov(sid); return o != null && o.x != null ? o.x : x; }
	public inline function yAt(sid:String):Float { var o = ov(sid); return o != null && o.y != null ? o.y : y; }
	public inline function wAt(sid:String):Float { var o = ov(sid); return o != null && o.w != null ? o.w : w; }
	public inline function hAt(sid:String):Float { var o = ov(sid); return o != null && o.h != null ? o.h : h; }
	public inline function colorAt(sid:String):Int { var o = ov(sid); return o != null && o.color != null ? o.color : color; }
	public inline function opacityAt(sid:String):Float { var o = ov(sid); return o != null && o.opacity != null ? o.opacity : opacity; }
	public inline function rotationAt(sid:String):Float { var o = ov(sid); return o != null && o.rotation != null ? o.rotation : rotation; }
	public inline function hiddenAt(sid:String):Bool { var o = ov(sid); return o != null && o.hidden != null ? o.hidden : hidden; }
	public inline function inState(sid:String):Bool return inStates == null || inStates.indexOf(sid == null ? "" : sid) >= 0;

	/** Override record for a state, created on demand. Callers pass a non-empty state id. */
	public function overrideFor(sid:String):AuraElementOverride {
		if (overrides == null) overrides = new Map();
		var o = overrides.get(sid);
		if (o == null) { o = new AuraElementOverride(); overrides.set(sid, o); }
		return o;
	}
	public function clearOverride(sid:String):Void {
		if (overrides == null) return;
		overrides.remove(sid);
		var any = false;
		for (_ in overrides.keys()) { any = true; break; }
		if (!any) overrides = null;
	}
	/** Drop everything that refers to a state that no longer exists. */
	public function forgetState(sid:String):Void {
		clearOverride(sid);
		if (inStates != null) { inStates.remove(sid); }
	}

	/** Shared by drawing, bounds and editor hit testing. `sid` is the state being drawn ("" = Default). */
	public inline function visible(editAll:Bool = false, sid:String = ""):Bool {
		return !hiddenAt(sid) && inState(sid) && (editAll || visibilityRule == null || visibilityResult.known && visibilityResult.hit);
	}
	public function clearVisibility():Void { visibilityResult.reset(); }
	/** Ignores stage clicks and drags so plates under text stay put. */
	public var locked:Bool = false;
	/** Text: 1 px drop shadow for readability over icons. */
	public var shadow:Bool = false;
	/** Shape: 0 = filled, otherwise outline thickness in px. */
	public var stroke:Float = 0;
	// ---- Animation (all optional; defaults keep layers static) ---------------------------------
	public static inline var PULSE_NONE:Int = 0;
	/** Breathing opacity. */
	public static inline var PULSE_FADE:Int = 1;
	/** Blends the layer colour towards `pulseColor` and back. */
	public static inline var PULSE_COLOR:Int = 2;
	public static inline var MAX_FADE:Float = 5;

	/** Seconds to fade in when the layer appears (0 = instant). */
	public var fadeIn:Float = 0;
	/** Seconds to fade out when the layer goes away (0 = instant). */
	public var fadeOut:Float = 0;
	public var pulseKind:Int = 0;
	/** Seconds per pulse cycle. */
	public var pulsePeriod:Float = 2;
	/** 0..1: how far opacity dips, or how far the colour travels towards `pulseColor`. */
	public var pulseDepth:Float = 0.6;
	public var pulseColor:Int = 0xFFFFFFFF;
	/** Sound file stems from custom_sounds, played when the layer appears / goes away in game. */
	public var soundShow:String = "";
	public var soundHide:String = "";
	public var soundVolume:Float = 0.7;

	// Runtime only: written by the engine each tick, read by the renderer.
	public var animInit:Bool = false;
	public var animVisible:Bool = false;
	public var animChangedAt:Float = -1e9;
	public var animFrom:Float = 0;

	public inline function hasFade():Bool return fadeIn > 0.001 || fadeOut > 0.001;
	public inline function hasAnimation():Bool return hasFade() || pulseKind != PULSE_NONE || soundShow.length > 0 || soundHide.length > 0;

	/** Forget the last visibility so the next tick treats the layer as newly rendered (fade in, play its cue). */
	public inline function resetAnimation():Void animInit = false;

	/**
	 * Engine tick. Returns 1 when the layer just appeared (including the first tick after its aura was
	 * hidden), -1 when it just went away, otherwise 0.
	 */
	public function trackVisibility(visible:Bool, now:Float):Int {
		if (!animInit) {
			animInit = true; animVisible = visible; animChangedAt = now; animFrom = 0;
			return visible ? 1 : 0;
		}
		if (visible == animVisible) return 0;
		animFrom = fadeAlpha(now);
		animVisible = visible;
		animChangedAt = now;
		return visible ? 1 : -1;
	}

	/** 0..1 fade factor for the current moment; 1 when the layer has no fades or has not been tracked. */
	public function fadeAlpha(now:Float):Float {
		if (!animInit) return 1;
		var target = animVisible ? 1.0 : 0.0, dur = animVisible ? fadeIn : fadeOut;
		if (dur <= 0.001) return target;
		var t = Math.max(0, Math.min(1, (now - animChangedAt) / dur));
		t = t * t * (3 - 2 * t);
		return animFrom + (target - animFrom) * t;
	}

	/** True while a faded-out layer is still dissolving, so it keeps drawing after it stops being visible. */
	public function dissolving(now:Float):Bool return animInit && !animVisible && fadeOut > 0.001 && fadeAlpha(now) > 0.002;

	/** 0..1 position in the pulse cycle, smooth: 0 at rest, 1 at the peak. */
	public function pulseWave(now:Float):Float {
		var period = Math.max(0.2, pulsePeriod);
		return 0.5 - 0.5 * Math.cos(2 * Math.PI * ((now % period) / period));
	}

	/** Path layers: the outline, in the unit square of the layer's box. */
	public var path:AuraVectorPath = null;
	/** Path layers: fill the closed outline (the `color`/`color2` fill). Outlines are drawn when `stroke` > 0. */
	public var fill:Bool = true;
	/** Path layers: outline colour; null reuses `color`. */
	public var strokeColor:Null<Int> = null;

	/** Shape polygon: corner count; star: point count. 3..12. */
	public var sides:Int = 5;
	/** Shape fill gradient: end colour (packed 0xAARRGGBB) or null for a flat fill. */
	public var color2:Null<Int> = null;
	/** 0 = top to bottom, 1 = left to right. Follows the screen axes, not the shape's rotation. */
	public var gradDir:Int = 0;
	/** Text: 0 left, 1 centre, 2 right inside the box width `w` (when w > 1). */
	public var textAlign:Int = 0;
	/** Text: dark outline thickness in px, 0 for none. */
	public var outline:Float = 0;
	/** Group this layer belongs to ("" = none). Layers sharing a name move and select together. */
	public var group:String = "";
	/** Layer name shown in the editor; empty falls back to the content. */
	public var name:String = "";

	static function clampSeconds(v:Dynamic, lo:Float, hi:Float, fallback:Float):Float {
		if (!Std.isOfType(v, Float) && !Std.isOfType(v, Int)) return fallback;
		var f:Float = v;
		return Math.isFinite(f) ? Math.max(lo, Math.min(hi, f)) : fallback;
	}

	/** Sound names are plain file stems: no paths, no odd characters. */
	public static function cleanSound(v:Dynamic):String {
		if (!Std.isOfType(v, String)) return "";
		var s:String = StringTools.trim(v);
		if (s.length == 0 || s.length > 64 || s.indexOf("/") >= 0 || s.indexOf("\\") >= 0 || s.indexOf("..") >= 0 || s.indexOf("\x00") >= 0) return "";
		return s;
	}

	public static inline function clampSides(v:Int):Int return v < 3 ? 3 : (v > 12 ? 12 : v);

	/** Degrees clockwise about the element centre. Drawn for shapes; text and images ignore it. */
	public var rotation:Float = 0;
	/** 0..1, multiplied into the element colour alpha and the aura alpha. */
	public var opacity:Float = 1;

	public static inline function clampRotation(v:Float):Float {
		if (!Math.isFinite(v)) return 0;
		var r = v % 360;
		if (r > 180) r -= 360;
		if (r <= -180) r += 360;
		return r;
	}
	/** Half extents of a w x h box rotated by `deg` about its centre (HUD bounds and editor hit tests). */
	public static function rotatedHalfExtent(w:Float, h:Float, deg:Float):{hx:Float, hy:Float} {
		var r = deg * Math.PI / 180, c = Math.abs(Math.cos(r)), sn = Math.abs(Math.sin(r));
		return {hx: (w * c + h * sn) * 0.5, hy: (w * sn + h * c) * 0.5};
	}
	public static inline function clampOpacity(v:Float):Float return Math.isFinite(v) ? Math.max(0, Math.min(1, v)) : 1;

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

	public static function vector(path:AuraVectorPath, x:Float, y:Float, w:Float, h:Float, color:Int = 0xFFFFFFFF):AuraCanvasElement {
		var el = new AuraCanvasElement(KIND_PATH, "", x, y, w, h, 16, color);
		el.path = path;
		return el;
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
		if (rotation != 0) o.rotation = rotation;
		if (opacity < 1) o.opacity = opacity;
		if (path != null) o.path = path.toObj();
		if (!fill) o.fill = false;
		if (strokeColor != null) o.strokeColor = strokeColor;
		if (fadeIn > 0) o.fadeIn = fadeIn;
		if (fadeOut > 0) o.fadeOut = fadeOut;
		if (pulseKind != PULSE_NONE) {
			o.pulseKind = pulseKind; o.pulsePeriod = pulsePeriod; o.pulseDepth = pulseDepth;
			if (pulseKind == PULSE_COLOR) o.pulseColor = pulseColor;
		}
		if (soundShow.length > 0) o.soundShow = soundShow;
		if (soundHide.length > 0) o.soundHide = soundHide;
		if ((soundShow.length > 0 || soundHide.length > 0) && soundVolume != 0.7) o.soundVolume = soundVolume;
		if (sides != 5) o.sides = sides;
		if (color2 != null) { o.color2 = color2; if (gradDir != 0) o.gradDir = gradDir; }
		if (textAlign != 0) o.textAlign = textAlign;
		if (outline > 0) o.outline = outline;
		if (name != null && name.length > 0) o.name = name;
		if (group != null && group.length > 0) o.group = group;
		if (inStates != null) o.inStates = inStates.copy();
		if (overrides != null) {
			var states:Dynamic = {};
			for (k => v in overrides) if (!v.isEmpty()) Reflect.setField(states, k, v.toObj());
			if (Reflect.fields(states).length > 0) o.stateOverrides = states;
		}
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
		var rotation:Null<Float> = d.rotation;
		el.rotation = rotation != null ? clampRotation(rotation) : 0;
		var opacity:Null<Float> = d.opacity;
		el.opacity = opacity != null ? clampOpacity(opacity) : 1;
		if (kind == KIND_PATH && d.path != null) el.path = AuraVectorPath.fromDyn(d.path);
		el.fill = d.fill != false;
		if (d.strokeColor != null && (Std.isOfType(d.strokeColor, Int) || Std.isOfType(d.strokeColor, Float))) el.strokeColor = Std.int(d.strokeColor);
		el.fadeIn = clampSeconds(d.fadeIn, 0, MAX_FADE, 0);
		el.fadeOut = clampSeconds(d.fadeOut, 0, MAX_FADE, 0);
		var pk:Null<Int> = d.pulseKind != null ? Std.int(d.pulseKind) : null;
		el.pulseKind = pk == PULSE_FADE || pk == PULSE_COLOR ? pk : PULSE_NONE;
		el.pulsePeriod = clampSeconds(d.pulsePeriod, 0.2, 30, 2);
		el.pulseDepth = clampSeconds(d.pulseDepth, 0, 1, 0.6);
		if (d.pulseColor != null && (Std.isOfType(d.pulseColor, Int) || Std.isOfType(d.pulseColor, Float))) el.pulseColor = Std.int(d.pulseColor);
		el.soundShow = cleanSound(d.soundShow);
		el.soundHide = cleanSound(d.soundHide);
		el.soundVolume = clampSeconds(d.soundVolume, 0, 1, 0.7);
		var sides:Null<Int> = d.sides != null ? Std.int(d.sides) : null;
		el.sides = sides != null ? clampSides(sides) : 5;
		if (d.color2 != null) el.color2 = Std.int(d.color2);
		el.gradDir = d.gradDir == 1 ? 1 : 0;
		var ta:Null<Int> = d.textAlign != null ? Std.int(d.textAlign) : null;
		el.textAlign = ta == 1 || ta == 2 ? ta : 0;
		var ol:Null<Float> = d.outline;
		el.outline = ol != null && Math.isFinite(ol) ? Math.max(0, Math.min(4, ol)) : 0;
		if (Std.isOfType(d.group, String)) el.group = AuraCanvasGroups.clean(d.group);
		if (d.name != null) { var n = StringTools.trim(Std.string(d.name)); el.name = n.length > MAX_NAME ? n.substr(0, MAX_NAME) : n; }
		if (Std.isOfType(d.inStates, Array)) {
			var raw:Array<Dynamic> = cast d.inStates;
			el.inStates = [];
			for (v in raw) {
				if (el.inStates.length >= MAX_STATE_REFS) break;
				var id = Std.isOfType(v, String) ? AuraStateDef.cleanId(v) : null;
				if (id != null && el.inStates.indexOf(id) < 0) el.inStates.push(id);
			}
		}
		if (d.stateOverrides != null) {
			for (key in Reflect.fields(d.stateOverrides)) {
				if (el.overrides != null && Lambda.count(el.overrides) >= MAX_STATE_REFS) break;
				var id = AuraStateDef.cleanId(key);
				if (id.length == 0) continue;
				var o = AuraElementOverride.fromDyn(Reflect.field(d.stateOverrides, key));
				if (o.isEmpty()) continue;
				if (el.overrides == null) el.overrides = new Map();
				el.overrides.set(id, o);
			}
		}
		return el;
	}
}
