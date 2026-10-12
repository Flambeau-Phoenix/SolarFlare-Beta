package solarflare.ui;

import hlx.runtime.ResolvedMember;
import imgui.ref.BoolRef;

/**
 * Opt-in (off by default): hide the SolarFlare overlays while a bank, trader, crafting/upgrade,
 * obelisk-travel or dungeon/rift portal window is open.
 *
 * Ownership: the observe phase samples the engine's window list a few times per second and freezes
 * one bool. Draw code reads `active()` only, through HudSuppress. Nothing here runs per draw.
 *
 * Cost: each window instance is classified by runtime type name once, then remembered by identity,
 * so a poll is a short identity scan. The earlier menu-hide resolved every open window's type on
 * every poll, which is what this avoids. No hook is involved.
 */
class WindowAutoHide {
	/** Persisted by SettingsStore. */
	public static var enabled = new BoolRef(false);

	static inline var POLL_S:Float = 0.25;
	/** Hard bound on windows examined per poll. */
	static inline var MAX_WINDOWS:Int = 48;

	static var lastPoll:Float = -1e9;
	static var hidden:Bool = false;
	// Identity cache of already-classified windows, double-buffered so a poll allocates nothing.
	static var objA:Array<Dynamic> = [];
	static var kindA:Array<Int> = [];
	static var objB:Array<Dynamic> = [];
	static var kindB:Array<Int> = [];
	static var modeInit = false;
	static var getMode:ResolvedMember = null;
	static var modeArgs:Array<Dynamic> = [null];

	/** True while the option is on and a listed window is open. Cheap; safe from draw. */
	public static function active():Bool {
		return hidden && enabled.get();
	}

	/** Observe phase only. */
	public static function observe(app:Dynamic, now:Float):Void {
		if (!enabled.get()) {
			if (hidden || objA.length > 0)
				reset();
			return;
		}
		if (now - lastPoll < POLL_S)
			return;
		lastPoll = now;
		var next = false;
		try {
			next = scan(app);
		} catch (_:Dynamic) {
			reset();
			return;
		}
		hidden = next;
	}

	/** Drop references to engine windows and the frozen result (session exit, option turned off). */
	public static function reset():Void {
		hidden = false;
		objA.resize(0);
		kindA.resize(0);
		objB.resize(0);
		kindB.resize(0);
	}

	static function scan(app:Dynamic):Bool {
		var gui:Dynamic = app == null ? null : HlxRuntime.resolveField(app, "gui");
		if (gui == null) {
			reset();
			return false;
		}
		var raw:Dynamic = HlxRuntime.resolveField(gui, "windows");
		if (raw == null)
			return false;
		var list:hl.types.ArrayBase = cast raw;
		var count = list.length;
		if (count > MAX_WINDOWS)
			count = MAX_WINDOWS;
		objB.resize(0);
		kindB.resize(0);
		var any = false;
		for (i in 0...count) {
			var w:Dynamic = list.getDyn(i);
			if (w == null)
				continue;
			var seen = objA.indexOf(w);
			var kind = seen >= 0 ? kindA[seen] : classify(w);
			objB.push(w);
			kindB.push(kind);
			if (kind == WindowAutoHidePolicy.HIDE)
				any = true;
			else if (kind == WindowAutoHidePolicy.TRAVEL_MAP && travelMode(w))
				any = true;
		}
		var o = objA;
		objA = objB;
		objB = o;
		var k = kindA;
		kindA = kindB;
		kindB = k;
		return any;
	}

	/** Walk the class chain by name, once per window instance. */
	static function classify(w:Dynamic):Int {
		try {
			var t = hl.Type.getDynamic(w);
			var depth = 0;
			while (depth < 8) {
				var raw:hl.Bytes = cast t;
				if (raw == null || t.kind != hl.Type.TypeKind.HObj)
					break;
				var kind = WindowAutoHidePolicy.kindOfType(t.getTypeName());
				if (kind != WindowAutoHidePolicy.OTHER)
					return kind;
				t = t.getSuper();
				depth++;
			}
		} catch (_:Dynamic) {}
		return WindowAutoHidePolicy.OTHER;
	}

	/** Only called for a window already classified as ui.win.MapWindow. */
	static function travelMode(w:Dynamic):Bool {
		try {
			if (!modeInit) {
				modeInit = true;
				var mapType = HlxRuntime.resolveType("ui.win.MapWindow");
				if (mapType != null)
					getMode = HlxRuntime.resolveMember(mapType, "get_mode");
			}
			var mode:Dynamic = null;
			if (getMode != null) {
				modeArgs[0] = w;
				mode = HlxRuntime.callResolved(getMode, modeArgs);
				modeArgs[0] = null;
			} else {
				mode = HlxRuntime.resolveField(w, "mode");
			}
			if (mode == null)
				return false;
			return WindowAutoHidePolicy.hidesForMapMode(Type.enumConstructor(cast mode));
		} catch (_:Dynamic) {}
		return false;
	}
}
