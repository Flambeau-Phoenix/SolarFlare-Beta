package solarflare.ui;

import hlx.runtime.ResolvedMember;

/** Native values HideMove overrode for one element, as primitives (no live pointers). */
private class HideMoveOriginal {
	public var visible:Bool = true;
	public var x:Float = 0;
	public var y:Float = 0;
	/** Last absolute position HideMove wrote, and the offset it was built from (see baseOf). */
	public var wx:Float = 0;
	public var wy:Float = 0;
	public var ox:Float = 0;
	public var oy:Float = 0;
	public var scale:Float = 1;
	public var alpha:Float = 1;
	public var hid:Bool = false;
	public var moved:Bool = false;
	public var scaled:Bool = false;
	public var faded:Bool = false;

	public function new() {}

	public inline function touched():Bool return hid || moved || scaled || faded;
}

/**
 * Observe-side HideMove apply. Resolve DomKit Comp*.inst each call;
 * never stash live pointers in config. Re-assert from updateVisibility postfix.
 *
 * Presentation-setter carve-out (docs/hooks.md §4.3): only values the user overrides are
 * written, natives are captured before the first write, and every override is restored
 * when it is switched off or HideMove is disabled.
 */
class HideMoveCache {
	/**
	 * v4.1b: shelved. Move/scale/alpha of native widgets is not part of this patch; only the bottom
	 * bar can be hidden (NativeHide, on the Utilities page). While true nothing here resolves engine
	 * members or writes to a widget, and the page is not drawn. Saved settings are left untouched.
	 * Known open issue when this is resumed: member resolution reported "unavailable" in game.
	 */
	public static inline var SHELVED:Bool = true;

	static var initialized = false;
	static var available = false;
	static var failed = false;
	static var setVisible:ResolvedMember;
	static var setScale:ResolvedMember;
	static var setX:ResolvedMember;
	static var setY:ResolvedMember;
	static var setAlpha:ResolvedMember;
	static var visibleArgs:Array<Dynamic> = [null, true];
	static var scaleArgs:Array<Dynamic> = [null, 1.0];
	static var xyArgs:Array<Dynamic> = [null, 0.0];
	static var alphaArgs:Array<Dynamic> = [null, 1.0];
	static var lastStatus:String = "HideMove idle";
	static var cfgRef:HideMoveConfig;
	/** Latest ui.Hud from the updateVisibility postfix; cleared with the session. */
	static var hudRef:Dynamic = null;
	/** hl type of h2d.Object, used to refuse any non-widget before a native setter call. */
	static var h2dType:hl.Type = null;
	/** Per element id; dropped with the session because the native widgets are rebuilt. */
	static var originals:Map<String, HideMoveOriginal> = new Map();
	static var wasEnabled = false;

	static function init():Void {
		if (initialized)
			return;
		initialized = true;
		try {
			var elType = HlxRuntime.resolveType("ui.UIElement");
			var objType = HlxRuntime.resolveType("h2d.Object");
			if (elType == null || objType == null)
				return;
			setVisible = HlxRuntime.resolveMember(elType, "set_visible");
			setScale = HlxRuntime.resolveMember(objType, "setScale");
			setX = HlxRuntime.resolveMember(objType, "set_x");
			setY = HlxRuntime.resolveMember(objType, "set_y");
			// h2d.Object has no set_alpha: alpha is a plain field, written with HlxRuntime.setField.
			h2dType = cast objType;
			available = setVisible != null && setScale != null && setX != null && setY != null && h2dType != null;
		} catch (_:Dynamic) {
			available = false;
		}
	}

	public static function apply(cfg:HideMoveConfig):Void {
		if (SHELVED)
			return;
		cfgRef = cfg;
		if (cfg == null)
			return;
		init();
		if (!available || failed) {
			cfg.status = failed ? "HideMove stopped after runtime error" : "HideMove unavailable: resolution failed";
			lastStatus = cfg.status;
			return;
		}
		if (!cfg.enabled.get()) {
			if (wasEnabled) {
				wasEnabled = false;
				restoreAll(cfg);
			}
			cfg.status = "HideMove idle (disabled)";
			lastStatus = cfg.status;
			return;
		}
		wasEnabled = true;
		try {
			var ok = 0;
			var miss = 0;
			for (e in cfg.elements) {
				if (applyOne(e))
					ok++;
				else
					miss++;
			}
			cfg.status = hudRef == null
				? "HideMove waiting for the HUD"
				: "HideMove applied " + ok + " element(s); unavailable: " + miss;
			lastStatus = cfg.status;
		} catch (_:Dynamic) {
			failed = true;
			cfg.status = "HideMove stopped after runtime error";
			lastStatus = cfg.status;
		}
	}

	/** Called from Hud.updateVisibility Void postfix — re-hide when game re-shows. */
	public static function afterUpdateVisibility(_self:Dynamic):Void {
		if (SHELVED)
			return;
		hudRef = _self;
		if (cfgRef == null || failed || !cfgRef.enabled.get())
			return;
		try
			apply(cfgRef)
		catch (_:Dynamic) {
			failed = true;
		}
	}

	/**
	 * The live widget, reached by field path from the Hud. The previous lookup used the domkit
	 * Comp*.inst statics, which are component descriptors: native setters were being aimed at
	 * objects that are not h2d.Object, so nothing moved. Anything not an h2d.Object is refused.
	 */
	static function instOf(e:HideMoveElement):Dynamic {
		if (e == null || hudRef == null || e.pathParts.length == 0)
			return null;
		try {
			var cur:Dynamic = hudRef;
			for (part in e.pathParts) {
				cur = HlxRuntime.resolveField(cur, part);
				if (cur == null)
					return null;
			}
			return hl.Type.getDynamic(cur).safeCast(h2dType) ? cur : null;
		} catch (_:Dynamic) {}
		return null;
	}

	/** Native values before HideMove's first write to this element. */
	static function originalFor(e:HideMoveElement, inst:Dynamic):HideMoveOriginal {
		var o = originals.get(e.id);
		if (o != null)
			return o;
		o = new HideMoveOriginal();
		try {
			var v:Dynamic = HlxRuntime.resolveField(inst, "visible");
			if (v != null) o.visible = v;
		} catch (_:Dynamic) {}
		o.x = readFloat(inst, "x", 0);
		o.y = readFloat(inst, "y", 0);
		o.scale = readFloat(inst, "scaleX", 1);
		o.alpha = readFloat(inst, "alpha", 1);
		originals.set(e.id, o);
		return o;
	}

	static inline function baseOf(current:Float, written:Float, offset:Float):Float {
		return current == written ? written - offset : current;
	}

	static function readFloat(inst:Dynamic, field:String, fallback:Float):Float {
		try {
			var v:Dynamic = HlxRuntime.resolveField(inst, field);
			if (v != null) {
				var f:Float = v;
				if (Math.isFinite(f))
					return f;
			}
		} catch (_:Dynamic) {}
		return fallback;
	}

	static function applyOne(e:HideMoveElement):Bool {
		var inst = instOf(e);
		if (inst == null)
			return false;
		var o = originalFor(e, inst);
		// Visibility is only forced when hidden; a shown element stays under native control
		// (the casting bar, for one, is hidden by the game between casts).
		if (!e.visible.get()) {
			writeVisible(inst, false);
			o.hid = true;
		} else if (o.hid) {
			writeVisible(inst, o.visible);
			o.hid = false;
		}
		if (e.locked.get())
			return true;
		// X/Y are offsets from wherever the engine placed the widget, so 0,0 means "unmoved". If the
		// value we last wrote is still there we strip our own offset to find the native base; if the
		// engine rewrote it (reflow, resize) the current value already is the native base.
		if (e.applyPos.get()) {
			var cx = readFloat(inst, "x", 0);
			var cy = readFloat(inst, "y", 0);
			var bx = o.moved ? baseOf(cx, o.wx, o.ox) : cx;
			var by = o.moved ? baseOf(cy, o.wy, o.oy) : cy;
			o.ox = e.x.get();
			o.oy = e.y.get();
			o.wx = bx + o.ox;
			o.wy = by + o.oy;
			writeXY(inst, o.wx, o.wy);
			o.moved = true;
		} else if (o.moved) {
			writeXY(inst, baseOf(readFloat(inst, "x", o.x), o.wx, o.ox), baseOf(readFloat(inst, "y", o.y), o.wy, o.oy));
			o.moved = false;
		}
		if (e.applyScale.get()) {
			writeScale(inst, e.scale.get());
			o.scaled = true;
		} else if (o.scaled) {
			writeScale(inst, o.scale);
			o.scaled = false;
		}
		if (e.applyAlpha.get()) {
			writeAlpha(inst, e.alpha.get());
			o.faded = true;
		} else if (o.faded) {
			writeAlpha(inst, o.alpha);
			o.faded = false;
		}
		if (!o.touched())
			originals.remove(e.id); // Recapture next time: natives may move while untouched.
		return true;
	}

	/** HideMove switched off: put back every value it overrode. */
	static function restoreAll(cfg:HideMoveConfig):Void {
		for (e in cfg.elements) {
			var o = e != null ? originals.get(e.id) : null;
			if (o == null)
				continue;
			var inst = instOf(e);
			if (inst != null) {
				try {
					if (o.hid) writeVisible(inst, o.visible);
					if (o.moved) writeXY(inst, baseOf(readFloat(inst, "x", o.x), o.wx, o.ox), baseOf(readFloat(inst, "y", o.y), o.wy, o.oy));
					if (o.scaled) writeScale(inst, o.scale);
					if (o.faded) writeAlpha(inst, o.alpha);
				} catch (_:Dynamic) {}
			}
			originals.remove(e.id);
		}
	}

	static function writeVisible(inst:Dynamic, v:Bool):Void {
		visibleArgs[0] = inst;
		visibleArgs[1] = v;
		try
			HlxRuntime.callResolved(setVisible, visibleArgs)
		catch (_:Dynamic) {}
		visibleArgs[0] = null;
	}

	static function writeXY(inst:Dynamic, x:Float, y:Float):Void {
		xyArgs[0] = inst;
		xyArgs[1] = x;
		try
			HlxRuntime.callResolved(setX, xyArgs)
		catch (_:Dynamic) {}
		xyArgs[1] = y;
		try
			HlxRuntime.callResolved(setY, xyArgs)
		catch (_:Dynamic) {}
		xyArgs[0] = null;
	}

	static function writeScale(inst:Dynamic, s:Float):Void {
		scaleArgs[0] = inst;
		scaleArgs[1] = s;
		try
			HlxRuntime.callResolved(setScale, scaleArgs)
		catch (_:Dynamic) {}
		scaleArgs[0] = null;
	}

	static function writeAlpha(inst:Dynamic, a:Float):Void {
		try
			HlxRuntime.setField(inst, "alpha", a)
		catch (_:Dynamic) {}
	}

	/** Logout/shutdown: native widgets are rebuilt with native values, so captures are stale. */
	public static function clearSession():Void {
		cfgRef = null;
		hudRef = null;
		failed = false;
		wasEnabled = false;
		originals.clear();
	}
}
