package solarflare.ui;

import hlx.runtime.ResolvedMember;

/**
 * Observe-side HideMove apply. Resolve DomKit Comp*.inst each call;
 * never stash live pointers in config. Re-assert from updateVisibility postfix.
 */
class HideMoveCache {
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
			setAlpha = HlxRuntime.resolveMember(objType, "set_alpha");
			if (setAlpha == null)
				setAlpha = HlxRuntime.resolveMember(elType, "set_alpha");
			available = setVisible != null && setScale != null && setX != null && setY != null;
		} catch (_:Dynamic) {
			available = false;
		}
	}

	public static function apply(cfg:HideMoveConfig):Void {
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
			cfg.status = "HideMove idle (disabled)";
			lastStatus = cfg.status;
			return;
		}
		try {
			var ok = 0;
			var miss = 0;
			for (e in cfg.elements) {
				if (applyOne(e))
					ok++;
				else
					miss++;
			}
			cfg.status = "HideMove applied " + ok + " element(s); missing inst=" + miss;
			lastStatus = cfg.status;
		} catch (_:Dynamic) {
			failed = true;
			cfg.status = "HideMove stopped after runtime error";
			lastStatus = cfg.status;
		}
	}

	/** Called from Hud.updateVisibility Void postfix — re-hide when game re-shows. */
	public static function afterUpdateVisibility(_self:Dynamic):Void {
		if (cfgRef == null || failed || !cfgRef.enabled.get())
			return;
		try
			apply(cfgRef)
		catch (_:Dynamic) {
			failed = true;
		}
	}

	static function applyOne(e:HideMoveElement):Bool {
		if (e == null || e.typePath == null || e.typePath.length == 0)
			return false;
		var t = HlxRuntime.resolveType(e.typePath);
		if (t == null)
			return false;
		var inst:Dynamic = null;
		try
			inst = HlxRuntime.resolveStaticField(t, "inst")
		catch (_:Dynamic) {}
		if (inst == null)
			return false;
		visibleArgs[0] = inst;
		visibleArgs[1] = e.visible.get();
		try
			HlxRuntime.callResolved(setVisible, visibleArgs)
		catch (_:Dynamic) {}
		if (e.locked.get())
			return true;
		if (e.applyPos.get()) {
			xyArgs[0] = inst;
			xyArgs[1] = e.x.get();
			try
				HlxRuntime.callResolved(setX, xyArgs)
			catch (_:Dynamic) {}
			xyArgs[1] = e.y.get();
			try
				HlxRuntime.callResolved(setY, xyArgs)
			catch (_:Dynamic) {}
		}
		if (e.applyScale.get()) {
			scaleArgs[0] = inst;
			scaleArgs[1] = e.scale.get();
			try
				HlxRuntime.callResolved(setScale, scaleArgs)
			catch (_:Dynamic) {}
		}
		if (e.applyAlpha.get() && setAlpha != null) {
			alphaArgs[0] = inst;
			alphaArgs[1] = e.alpha.get();
			try
				HlxRuntime.callResolved(setAlpha, alphaArgs)
			catch (_:Dynamic) {}
		}
		return true;
	}

	public static function clearSession():Void {
		cfgRef = null;
		failed = false;
	}
}
