package solarflare.ui;

import hlx.runtime.ResolvedMember;

/** Observation-owned native references. No engine access from configuration/drawing. */
class NativeHideCache {
	static var initialized = false;
	static var available = false;
	static var failed = false;
	static var initStatus = "NativeHide unavailable: resolution failed";
	static var getHud:ResolvedMember;
	static var setBottom:ResolvedMember;
	static var updateVisibility:ResolvedMember;
	static var setVisible:ResolvedMember;
	static var setMode:ResolvedMember;
	static var modeAll:Dynamic;
	static var modeKeepWorld:Dynamic;
	static var modeNone:Dynamic;
	static var rootHideMode:Dynamic;
	static var rootAvailable = false;
	static var gui:Dynamic;
	static var hud:Dynamic;
	static var bottom:Dynamic;
	static var heroBar:Dynamic;
	static var heroBarPad:Dynamic;
	static var appRef:Dynamic;
	static var suppress = false;
	static var bottomOwned = false;
	static var precedingAlphaHidden = false;
	static var rootOwned = false;
	static var precedingMode:Dynamic;
	// Preallocated exact-arity argument buffers. Also scrubbed on session exit.
	static var guiArgs:Array<Dynamic> = [null];
	static var hudArgs:Array<Dynamic> = [null];
	static var bottomArgs:Array<Dynamic> = [null, false];
	static var visibleArgs:Array<Dynamic> = [null, false];
	static var modeArgs:Array<Dynamic> = [null, null];

	static function init():Void {
		if (initialized) return;
		initialized = true;
		try {
			var hudType = HlxRuntime.resolveType("ui.Hud");
			var guiType = HlxRuntime.resolveType("ui.GameUI");
			var elementType = HlxRuntime.resolveType("ui.UIElement");
			if (hudType == null || guiType == null || elementType == null) return;
			getHud = HlxRuntime.resolveMember(guiType, "get_hud");
			setBottom = HlxRuntime.resolveMember(hudType, "setBottomBarVisible");
			updateVisibility = HlxRuntime.resolveMember(hudType, "updateVisibility");
			setVisible = HlxRuntime.resolveMember(elementType, "set_visible");
			available = getHud != null && setBottom != null && updateVisibility != null && setVisible != null;
			if (!available) return;
			// A missing enum/full-root member must not disable the first milestone.
			try {
				var enumType = HlxRuntime.resolveType("ui.HideMode");
				if (enumType != null) {
					modeAll = HlxRuntime.resolveStaticField(enumType, "All");
					modeKeepWorld = HlxRuntime.resolveStaticField(enumType, "KeepWorld");
					modeNone = HlxRuntime.resolveStaticField(enumType, "None");
					// Parameterless enums are compared by identity elsewhere in native UI.
					// Use reflection companion singletons, never freshly constructed values.
					setMode = HlxRuntime.resolveMember(guiType, "set_hideMode");
					// Prefer KeepWorld (hide UI root, keep world) — All is fallback only.
					rootHideMode = null;
					if (validMode(modeKeepWorld, "KeepWorld", 1))
						rootHideMode = modeKeepWorld;
					else if (validMode(modeAll, "All", 2))
						rootHideMode = modeAll;
					rootAvailable = setMode != null && rootHideMode != null && validMode(modeNone, "None", 0);
				}
			} catch (_:Dynamic) { rootAvailable = false; }
		} catch (_:Dynamic) { available = false; }
	}

	static function validMode(value:Dynamic, name:String, index:Int):Bool {
		return value != null && Type.enumConstructor(cast value) == name && Type.enumIndex(cast value) == index;
	}

	static inline function field(value:Dynamic, name:String):Dynamic {
		return value == null ? null : HlxRuntime.resolveField(value, name);
	}

	static function inCharacterEdit():Bool {
		var edit = field(appRef, "characterEditCamera");
		return edit != null && field(appRef, "camera") == edit;
	}

	public static function apply(app:GameApp, cfg:NativeHideConfig):Void {
		if (app == null || cfg == null) return;
		init();
		if (!available || failed) {
			if (failed && (hud != null || gui != null)) clearSession(false);
			// A hook failure releases ownership once, then remains disabled this session.
			cfg.status = failed ? "NativeHide stopped after a runtime error; native restoration attempted" : initStatus;
			return;
		}
		try {
			var nextGui = field(app, "gui");
			guiArgs[0] = nextGui;
			var nextHud = nextGui == null ? null : HlxRuntime.callResolved(getHud, guiArgs);
			var nextBottom = field(nextHud, "bottomBar");
			if (nextGui != gui || nextHud != hud || nextBottom != bottom) {
				// Release only still-attached objects; never call a detached old HUD.
				restore(nextGui == gui, nextHud == hud && nextBottom == bottom);
				gui = nextGui;
				hud = nextHud;
				bottom = nextBottom;
				appRef = app;
				bottomOwned = false;
				rootOwned = false;
			}
			appRef = app;
			hudArgs[0] = hud;
			refreshBars();
			if (hud == null || bottom == null) {
				cfg.status = "Waiting for native HUD";
				return;
			}
			if (cfg.hideAll.get() && cfg.bottomBarAccepted.get() && rootAvailable) {
				var current = field(gui, "hideMode");
				var wantIdx = Type.enumIndex(cast rootHideMode);
				if (current != null && Type.enumIndex(cast current) != wantIdx) {
					// Observe native/other-mod mode changes before taking ownership again.
					precedingMode = current;
					rootOwned = true;
					writeMode(rootHideMode);
				}
			} else releaseRoot(true);
			// Restore the root mode before asking native child visibility policy to run.
			if (cfg.hideBottomBar.get()) {
				if (!bottomOwned) {
					// Keep an already-hidden parent owned by another mod hidden on release.
					precedingAlphaHidden = field(bottom, "alpha") == 0.0 && !inCharacterEdit();
					bottomOwned = true;
				}
				suppress = true;
				hideBars();
			} else releaseBottom(true);
			var modeName = rootHideMode != null ? Type.enumConstructor(cast rootHideMode) : "?";
			cfg.status = cfg.hideAll.get() && cfg.bottomBarAccepted.get() && !rootAvailable
				? "Bottom-bar control ready; symbolic full-root resolution unavailable"
				: rootOwned ? "Full-root " + modeName + " active; F6 restores native UI"
				: suppress ? "Native bottom bar hidden; custom HUD unchanged" : "Native visibility restored";
		} catch (_:Dynamic) {
			suppress = false;
			failed = true;
			clearSession(false);
			cfg.status = "NativeHide stopped after a runtime error; native restoration attempted";
		}
	}

	static function refreshBars():Void {
		heroBar = field(bottom, "heroBar");
		heroBarPad = field(bottom, "heroBarPad");
	}

	static function hideBars():Void {
		bottomArgs[0] = hud;
		bottomArgs[1] = false;
		HlxRuntime.callResolved(setBottom, bottomArgs);
		visibleArgs[1] = false;
		if (heroBar != null && field(heroBar, "visible") != false) {
			visibleArgs[0] = heroBar;
			HlxRuntime.callResolved(setVisible, visibleArgs);
		}
		if (heroBarPad != null && field(heroBarPad, "visible") != false) {
			visibleArgs[0] = heroBarPad;
			HlxRuntime.callResolved(setVisible, visibleArgs);
		}
	}

	/** No resolveMember, arrays, I/O, or returned-value override inside the hook. */
	public static function afterUpdateVisibility(self:Dynamic):Void {
		if (!suppress || failed || self != hud) return;
		try {
			// Let observation acquire a rebuilt parent and capture its preceding alpha.
			if (field(hud, "bottomBar") != bottom) return;
			refreshBars();
			if (bottom != null) hideBars();
		} catch (_:Dynamic) {
			// Suppression must be off before any restoration invokes updateVisibility.
			suppress = false;
			failed = true;
		}
	}

	static function writeMode(value:Dynamic):Void {
		modeArgs[0] = gui;
		modeArgs[1] = value;
		HlxRuntime.callResolved(setMode, modeArgs);
	}

	static function releaseBottom(attached:Bool):Void {
		suppress = false;
		if (!bottomOwned) return;
		bottomOwned = false;
		if (!attached || hud == null || bottom == null) return;
		// No blanket set_visible(true): let the native controller/menu/death policy decide.
		hudArgs[0] = hud;
		try HlxRuntime.callResolved(updateVisibility, hudArgs) catch (_:Dynamic) {}
		try {
			if (field(bottom, "alpha") == 0.0) {
				bottomArgs[0] = hud;
				bottomArgs[1] = !inCharacterEdit() && !precedingAlphaHidden;
				HlxRuntime.callResolved(setBottom, bottomArgs);
			}
		} catch (_:Dynamic) {}
	}

	static function releaseRoot(attached:Bool):Void {
		if (!rootOwned) return;
		rootOwned = false;
		try {
			var current = attached ? field(gui, "hideMode") : null;
			// Do not overwrite a subsequent native/other-mod mode change.
			var wantIdx = rootHideMode != null ? Type.enumIndex(cast rootHideMode) : -1;
			if (current != null && wantIdx >= 0 && Type.enumIndex(cast current) == wantIdx && precedingMode != null)
				writeMode(precedingMode);
		} catch (_:Dynamic) {}
		precedingMode = null;
	}

	static function restore(guiAttached:Bool, hudAttached:Bool):Void {
		suppress = false;
		releaseRoot(guiAttached);
		releaseBottom(hudAttached);
	}

	/** Explicit host cleanup API; the mod runtime does not promise an unload callback. */
	public static function clearSession(resetFailure:Bool = true):Void {
		try {
			var currentGui = field(appRef, "gui");
			guiArgs[0] = currentGui;
			var currentHud = currentGui == null || getHud == null ? null : HlxRuntime.callResolved(getHud, guiArgs);
			restore(currentGui == gui, currentHud == hud && field(currentHud, "bottomBar") == bottom);
		} catch (_:Dynamic) { suppress = false; }
		gui = null; hud = null; bottom = null; heroBar = null; heroBarPad = null; appRef = null;
		precedingMode = null; rootOwned = false; bottomOwned = false; suppress = false;
		if (resetFailure) failed = false;
		guiArgs[0] = null; hudArgs[0] = null; bottomArgs[0] = null; visibleArgs[0] = null;
		modeArgs[0] = null; modeArgs[1] = null;
	}
}
