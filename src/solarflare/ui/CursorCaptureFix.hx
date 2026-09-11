package solarflare.ui;

import imgui.ImGui;
import imgui.ImGui.ImGuiIO;
import imgui.Enums.ImGuiConfigFlags;
import imgui.Enums.ImGuiWindowFlags;

/**
 * Look-lock input gating while Farever retains native-cursor ownership.
 * Pew Pew Meter pattern: windows use NoInputs while `!isCursorFree()` so they
 * do not steal camera clicks.  The shared hl-imgui backend is an overlay, so
 * it must never replace, show, or hide Farever's native cursor.
 *
 * When the cursor is free AND an interactive tool is open, claim keyboard+mouse
 * capture and cancel Heaps key events so Farever hotkeys (inventory, abilities)
 * do not fire under the UI. Alt / F6 / F12 still reach the game/mod toggles.
 */
class CursorCaptureFix {
	public static inline var ENABLED:Bool = true;
	public static function keep():Void {}

	/** Snapshotted in observe(); draw must not call GameApp.isCursorFree(). */
	public static var cursorFree:Bool = false;

	static inline var FLAG_NO_MOUSE:Int = ImGuiConfigFlags.NoMouse; // 16
	static inline var FLAG_NO_CURSOR_CHANGE:Int = ImGuiConfigFlags.NoMouseCursorChange; // 32
	static var clipKnown:Bool = false;
	static var lastClip:Bool = false;
	static var blockGameKeys:Bool = false;
	static var interactiveActive:Bool = false;
	static var eventHooked:Bool = false;

	public static function windowFlags(base:Int = 0):Int {
		if (!cursorFree)
			return base | ImGuiWindowFlags.NoInputs;
		return base;
	}

	public static function apply(app:GameApp):Void {
		if (!ENABLED || app == null)
			return;
		var free = false;
		try
			free = app.isCursorFree()
		catch (_:Dynamic) {}
		cursorFree = free;
		applyInputPolicy(free);
		applyWindowClip(!free);
		ensureEventHook();
	}

	static function applyWindowClip(locked:Bool):Void {
		if (clipKnown && lastClip == locked)
			return;
		try {
			var window = hxd.Window.getInstance();
			if (window == null)
				return;
			window.set_mouseClip(locked);
			lastClip = locked;
			clipKnown = true;
		} catch (_:Dynamic) {}
	}

	/** Call at the start of draw when tools may be open — claim capture early. */
	public static function beginFrameCapture(interactiveOpen:Bool):Void {
		interactiveActive = ENABLED && interactiveOpen;
		if (!ENABLED || !cursorFree)
			return;
		claimCapture(interactiveOpen);
	}

	/**
	 * Must run after every SolarFlare ImGui window.
	 * When cursor-free + interactive tools open, keep WantCapture* asserted so
	 * the hl-imgui backend can suppress game key/mouse routing where supported.
	 */
	public static function finishFrame(interactiveOpen:Bool = false):Void {
		interactiveActive = ENABLED && interactiveOpen;
		if (!ENABLED)
			return;
		if (cursorFree) {
			claimCapture(interactiveOpen);
			return;
		}
		blockGameKeys = false;
		try {
			var window = hxd.Window.getInstance();
			if (window == null)
				return;
			window.set_mouseClip(true);
			lastClip = true;
			clipKnown = true;
		} catch (_:Dynamic) {}
	}

	static function claimCapture(interactiveOpen:Bool):Void {
		blockGameKeys = interactiveOpen;
		try {
			ImGui.setNextFrameWantCaptureKeyboard(interactiveOpen);
			ImGui.setNextFrameWantCaptureMouse(interactiveOpen);
		} catch (_:Dynamic) {}
	}

	static function ensureEventHook():Void {
		if (eventHooked)
			return;
		try {
			var window = hxd.Window.getInstance();
			if (window == null)
				return;
			window.addEventTarget(onWindowEvent);
			eventHooked = true;
		} catch (_:Dynamic) {}
	}

	/**
	 * Stop Farever from seeing hotkeys while SolarFlare tools own the cursor-free UI.
	 * ImGui still receives Win32 keys independently; Heaps cancel only hits game listeners.
	 */
	static function onWindowEvent(e:hxd.Event):Void {
		if (!ENABLED || !blockGameKeys || !cursorFree || e == null)
			return;
		try {
			var kind = e.kind;
			if (kind == null)
				return;
			var isKey = false;
			try
				isKey = kind.isEKeyDown() || kind.isEKeyUp() || kind.isETextInput()
			catch (_:Dynamic)
				isKey = false;
			if (!isKey)
				return;

			var code = 0;
			try
				code = e.keyCode
			catch (_:Dynamic)
				code = 0;

			// Keep camera/UI and hub toggles reachable.
			if (code == hxd.Key.ALT || code == hxd.Key.LALT || code == hxd.Key.RALT)
				return;
			if (code == hxd.Key.F6 || code == hxd.Key.F12)
				return;

			e.propagate = false;
			e.cancel = true;
		} catch (_:Dynamic) {}
	}

	static function applyInputPolicy(free:Bool):Void {
		try {
			var io:ImGuiIO = ImGui.getIO();
			if (io == null)
				return;
			var mem = hl.Bytes.fromAddress(addressOf(io));
			var flags = mem.getI32(0) | FLAG_NO_CURSOR_CHANGE;
			if (free)
				flags &= ~FLAG_NO_MOUSE;
			else {
				flags |= FLAG_NO_MOUSE;
				blockGameKeys = false;
				ImGui.setNextFrameWantCaptureMouse(false);
				ImGui.setNextFrameWantCaptureKeyboard(false);
			}
			mem.setI32(0, flags);
		} catch (_:Dynamic) {}
	}

	static inline function addressOf(io:ImGuiIO):haxe.Int64 {
		return untyped io;
	}

	/** Observation prefix — always Continue. Capture uses WantCapture / NoInputs / Heaps cancel. */
	@:hlx.prefix(client.UnitController.isInputBlocked)
	static function beforeIsInputBlocked(instance:client.UnitController):hlx.runtime.HlxPrefixControl {
		try {
			if (instance == null)
				return hlx.runtime.HlxPrefixControl.Continue;
		} catch (_:Dynamic) {}
		return hlx.runtime.HlxPrefixControl.Continue;
	}

	@:hlx.prefix(h2d.Scene.handleEvent)
	static function beforeSceneHandleEvent(instance:h2d.Scene, event:hxd.Event, prev:Dynamic):hlx.runtime.HlxPrefixControl {
		try {
			if (instance == null || event == null)
				return hlx.runtime.HlxPrefixControl.Continue;
		} catch (_:Dynamic) {}
		return hlx.runtime.HlxPrefixControl.Continue;
	}

	@:hlx.prefix(client.BaseCamera.onEvent)
	static function beforeBaseCameraOnEvent(instance:client.BaseCamera, event:hxd.Event):hlx.runtime.HlxPrefixControl {
		try {
			if (instance == null || event == null)
				return hlx.runtime.HlxPrefixControl.Continue;
		} catch (_:Dynamic) {}
		return hlx.runtime.HlxPrefixControl.Continue;
	}

	@:hlx.prefix(ui.Hud.shouldFreeCursor)
	static function beforeHudShouldFreeCursor(instance:ui.Hud):hlx.runtime.HlxPrefixControl {
		try {
			if (instance == null)
				return hlx.runtime.HlxPrefixControl.Continue;
		} catch (_:Dynamic) {}
		return hlx.runtime.HlxPrefixControl.Continue;
	}

	@:hlx.prefix(lib.Input.allBlocked)
	static function beforeInputAllBlocked():hlx.runtime.HlxPrefixControl {
		try {
			if (!ENABLED)
				return hlx.runtime.HlxPrefixControl.Continue;
		} catch (_:Dynamic) {}
		return hlx.runtime.HlxPrefixControl.Continue;
	}

	@:hlx.prefix(ui.BaseUI.isBlockingAllInputs)
	static function beforeUIBlockingAllInputs(instance:ui.BaseUI):hlx.runtime.HlxPrefixControl {
		try {
			if (instance == null)
				return hlx.runtime.HlxPrefixControl.Continue;
		} catch (_:Dynamic) {}
		return hlx.runtime.HlxPrefixControl.Continue;
	}
}
