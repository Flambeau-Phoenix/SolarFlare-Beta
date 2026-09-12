package solarflare.ui;

import imgui.ImGui;
import imgui.ImGui.ImGuiIO;
import imgui.Enums.ImGuiConfigFlags;
import imgui.Enums.ImGuiWindowFlags;

/**
 * Solar Flare input ownership — mouse/cursor and keyboard are separate machines.
 *
 * cursorFree (observe snapshot of GameApp.isCursorFree):
 *   May Solar Flare use mouse interaction without fighting Farever's cursor?
 *
 * interactiveActive (ConfigPanel.anyInteractiveOpen):
 *   Does Solar Flare own keyboard interaction?
 *
 * keyboardCaptureActive / blockGameKeys follow interactiveActive only — never
 * revoked merely because Farever locked its cursor.
 *
 * Mouse policy: NEVER set ImGuiConfigFlags.NoMouse in io.ConfigFlags. That is a
 * global IO flag that stops ImGui reading mouse position from the OS, which
 * makes the native cursor go invisible or escape clipping even with
 * NoMouseCursorChange set. Per-window NoMouseInputs (applied by windowFlags())
 * is the correct mechanism for blocking SolarFlare hit-testing during camera-lock.
 * io.ConfigFlags must only ever carry NoMouseCursorChange (+ DockingEnable).
 *
 * Heaps note: Window.event() invokes every eventTarget and ignores e.cancel /
 * e.propagate. Farever hotkeys often poll hxd.Key.isPressed/isDown, so after
 * Key.onEvent updates keyPressed we must invalidate with -1. Register LAST
 * (addEventTarget), not first — prepending lets Key overwrite our -1.
 *
 * No HLX prefix hooks. No native cursor show/hide/warp.
 */
class CursorCaptureFix {
	public static inline var ENABLED:Bool = true;
	public static function keep():Void {}

	/** Snapshotted in observe(); draw must not call GameApp.isCursorFree(). */
	public static var cursorFree:Bool = false;

	/** True while any interactive Solar Flare tool/config/editor is open. */
	public static var interactiveActive:Bool = false;

	/** Authoritative keyboard-ownership flag (mirrors interactiveActive while ENABLED). */
	public static var keyboardCaptureActive:Bool = false;

	static inline var FLAG_NO_MOUSE:Int = ImGuiConfigFlags.NoMouse; // 16
	static inline var FLAG_NO_CURSOR_CHANGE:Int = ImGuiConfigFlags.NoMouseCursorChange; // 32
	static var clipKnown:Bool = false;
	static var lastClip:Bool = false;
	/** Heaps hook gate — same lifetime as keyboardCaptureActive. */
	static var blockGameKeys:Bool = false;
	static var eventHooked:Bool = false;

	/**
	 * Mouse policy only. When Farever locks the cursor, suppress mouse hit-testing
	 * without killing keyboard/text (NoMouseInputs, not the composite NoInputs).
	 */
	public static function windowFlags(base:Int = 0):Int {
		if (!cursorFree)
			return base | ImGuiWindowFlags.NoMouseInputs;
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
		// Hook first so the keyboard handler is always registered before policy writes.
		ensureEventHook();
		applyMousePolicy(free);
		applyWindowClip(!free);
		// Re-assert keyboard WantCapture after mouse policy — mouse must not release keys.
		if (keyboardCaptureActive)
			assertWantCaptureKeyboard(true);
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
		if (!ENABLED) {
			setInteractive(false);
			return;
		}
		// Keyboard ownership follows interactiveOpen regardless of cursorFree.
		setInteractive(interactiveOpen);
		syncCaptureClaims();
	}

	/**
	 * Must run after every SolarFlare ImGui window.
	 * Keyboard ownership follows interactive tools; mouse follows cursorFree.
	 * Never clear blockGameKeys merely because cursorFree became false.
	 */
	public static function finishFrame(interactiveOpen:Bool = false):Void {
		if (!ENABLED) {
			setInteractive(false);
			return;
		}
		setInteractive(interactiveOpen);
		syncCaptureClaims();
		// Re-assert clip unconditionally — one authoritative clip state per frame,
		// regardless of transitions that occurred during the frame.
		applyWindowClip(!cursorFree);
	}

	static function setInteractive(open:Bool):Void {
		interactiveActive = open;
		keyboardCaptureActive = open;
		blockGameKeys = open;
	}

	static function syncCaptureClaims():Void {
		assertWantCaptureKeyboard(keyboardCaptureActive);
		// Mouse capture only while Farever allows a free cursor.
		assertWantCaptureMouse(keyboardCaptureActive && cursorFree);
	}

	static function assertWantCaptureKeyboard(want:Bool):Void {
		try
			ImGui.setNextFrameWantCaptureKeyboard(want)
		catch (_:Dynamic) {}
	}

	static function assertWantCaptureMouse(want:Bool):Void {
		try
			ImGui.setNextFrameWantCaptureMouse(want)
		catch (_:Dynamic) {}
	}

	/**
	 * Keep our handler at the END of eventTargets so hxd.Key.onEvent updates
	 * keyPressed first; we then invalidate. Re-add each ensure so late Farever
	 * listeners cannot permanently sit after us.
	 */
	static function ensureEventHook():Void {
		try {
			var window = hxd.Window.getInstance();
			if (window == null)
				return;
			try
				window.removeEventTarget(onWindowEvent)
			catch (_:Dynamic) {}
			window.addEventTarget(onWindowEvent);
			eventHooked = true;
		} catch (_:Dynamic) {
			eventHooked = false;
		}
	}

	/**
	 * Eat Farever hotkeys while Solar Flare owns keyboard — independent of cursorFree.
	 * WantCapture / Heaps cancel alone are not enough: inventory/map poll
	 * hxd.Key.isPressed in tick (keyPressed[code] == frame), so invalidate with -1.
	 *
	 * Window.event ignores cancel/propagate; they are set for cancel-aware listeners only.
	 * hl-imgui feeds ImGui from its own Win32 path, so InputText still receives characters.
	 */
	static function onWindowEvent(e:hxd.Event):Void {
		if (!ENABLED || !blockGameKeys || e == null)
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

			// Solar Flare global toggles must still reach mod poll (ConfigPanel / DebugSystem).
			// ALT passes through so Farever's cursor-toggle keybind still fires while a
			// SolarFlare tool is open. The cascade risk (inventory teardown) is gone now
			// that NoMouse is never set in io.ConfigFlags — ALT no longer leaks game hotkeys.
			// F6/F12 remain Solar Flare controls.
			if (code == hxd.Key.F6 || code == hxd.Key.F12
					|| code == hxd.Key.ALT)
				return;

			e.propagate = false;
			e.cancel = true;

			// Invalidate Heaps poll table AFTER Key.onEvent (we are last on the list).
			// isPressed uses == frame; isDown uses > 0; -1 fails both.
			if (code > 0) {
				@:privateAccess hxd.Key.keyPressed[code] = -1;
			}
		} catch (_:Dynamic) {}
	}

	/**
	 * IO ConfigFlags — only enforce NoMouseCursorChange.
	 * NEVER set NoMouse: it is a global IO flag that stops ImGui reading mouse
	 * position from the OS, making the native Farever cursor invisible or causing
	 * it to escape the window clip rectangle. Per-window NoMouseInputs (applied
	 * by windowFlags()) is the correct camera-lock hit-test gate.
	 * Keyboard ownership is never affected here.
	 */
	static function applyMousePolicy(free:Bool):Void {
		try {
			var io:ImGuiIO = ImGui.getIO();
			if (io == null)
				return;
			var mem = hl.Bytes.fromAddress(addressOf(io));
			// Ensure NoMouseCursorChange is always set (Farever owns native cursor shape).
			// Defensively clear NoMouse in case any other code ever set it.
			var flags = (mem.getI32(0) | FLAG_NO_CURSOR_CHANGE) & ~FLAG_NO_MOUSE;
			mem.setI32(0, flags);
			// Release ImGui mouse capture when camera has the cursor.
			if (!free)
				assertWantCaptureMouse(false);
			// Do NOT clear blockGameKeys / WantCaptureKeyboard here.
		} catch (_:Dynamic) {}
	}

	static inline function addressOf(io:ImGuiIO):haxe.Int64 {
		return untyped io;
	}
}
