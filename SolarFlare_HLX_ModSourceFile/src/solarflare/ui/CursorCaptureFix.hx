package solarflare.ui;

import imgui.ImGui;
import imgui.ImGui.ImGuiIO;
import imgui.Enums.ImGuiConfigFlags;
import imgui.Enums.ImGuiWindowFlags;

/**
 * Look-lock input gating while Farever retains native-cursor ownership.
 *
 * THIS IS THE SHIPPED SolarFlare-Beta POLICY, restored verbatim apart from the Alt
 * note below. It was replaced at one point by a "never set NoMouse" variant, which
 * is what left the player unable to interact with the world while the cursor was
 * hidden. Do not reintroduce that variant; see docs and the notes here first.
 *
 * When the cursor is NOT free:
 *   - windows carry ImGuiWindowFlags.NoInputs
 *   - io.ConfigFlags carries ImGuiConfigFlags.NoMouse
 *   - every WantCapture* claim is dropped
 *   - mouseClip is reasserted
 * All four together are what hand the mouse back to Farever. Per-window flags alone
 * leave ImGui hovering and reporting WantCaptureMouse, and the backend holds clicks
 * on that basis.
 *
 * NoMouseCursorChange is held permanently: the hl-imgui backend is an overlay and
 * must never replace, show, or hide Farever's native cursor.
 *
 * Deliberately minimal: no per-frame reflection, no engine poll-table writes, no
 * bind-queue draining. Capture is WantCapture*, window flags, and Heaps event
 * cancel only. Anything heavier belongs nowhere near a per-frame path.
 */
class CursorCaptureFix {
	public static inline var ENABLED:Bool = true;
	public static function keep():Void {}

	/** Snapshotted in observe(); draw must not call GameApp.isCursorFree(). */
	public static var cursorFree:Bool = false;

	/** True while any interactive SolarFlare tool/config/editor is open. */
	public static var interactiveActive:Bool = false;

	/** Authoritative keyboard-ownership flag. */
	public static var keyboardCaptureActive:Bool = false;

	static inline var FLAG_NO_MOUSE:Int = ImGuiConfigFlags.NoMouse; // 16
	static inline var FLAG_NO_CURSOR_CHANGE:Int = ImGuiConfigFlags.NoMouseCursorChange; // 32

	static var clipKnown:Bool = false;
	static var lastClip:Bool = false;
	static var freeKnown:Bool = false;
	static var lastFree:Bool = false;
	static var blockGameKeys:Bool = false;
	static var eventHooked:Bool = false;

	/**
	 * True while an ImGui widget is actually being edited, sampled in finishFrame().
	 *
	 * The open-editor list misses fields in windows that never register (aura name
	 * boxes, inline HUD fields), and WantCaptureKeyboard is unusable as a signal
	 * because it goes true on mere hover. isAnyItemActive is the narrow one.
	 *
	 * Gating the engine-side clear on this rather than on "an editor is open" keeps
	 * an idle builder completely off the proxy path.
	 */
	static var typingActive:Bool = false;

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

	/** ONE-TIME STARTUP CALL — seeds NoMouseCursorChange before the first observe. */
	public static function ensureHardwareCursor():Void {
		try {
			var io:ImGuiIO = ImGui.getIO();
			if (io == null)
				return;
			var mem = hl.Bytes.fromAddress(addressOf(io));
			var existing = mem.getI32(0);
			var desired = existing | FLAG_NO_CURSOR_CHANGE;
			if (existing != desired)
				mem.setI32(0, desired);
		} catch (_:Dynamic) {}
	}

	/** Call at the start of draw when tools may be open — claim capture early. */
	public static function beginFrameCapture(interactiveOpen:Bool):Void {
		interactiveActive = ENABLED && interactiveOpen;
		keyboardCaptureActive = interactiveActive;
		if (!ENABLED || !cursorFree)
			return;
		claimCapture(interactiveOpen);
	}

	/**
	 * Must run after every SolarFlare ImGui window.
	 * When cursor-free and interactive tools are open, keep WantCapture* asserted so
	 * the backend can suppress game key/mouse routing where supported.
	 */
	public static function finishFrame(interactiveOpen:Bool = false):Void {
		interactiveActive = ENABLED && interactiveOpen;
		keyboardCaptureActive = interactiveActive;
		if (!ENABLED)
			return;
		// Sampled here because every SolarFlare window has been submitted by now.
		try
			typingActive = ImGui.isAnyItemActive()
		catch (_:Dynamic)
			typingActive = false;
		// The WndProc gate, not the Heaps event cancel, is what actually keeps keystrokes out
		// of Farever. io.WantTextInput already covers an active field, so this only has to
		// assert the window-level claim.
		try
			ImGui.setKeyboardBlock(cursorFree && interactiveActive)
		catch (_:Dynamic) {}
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
	 * ImGui still receives Win32 keys independently; the Heaps cancel only hits game
	 * listeners, so a focused inputText still gets its characters.
	 *
	 * Alt is consumed rather than whitelisted (the one deviation from Beta): Farever
	 * uses it to toggle look-lock, which hid the cursor out from under an open editor.
	 * blockGameKeys is false during HUD-only play, so camera Alt still works there.
	 */
	static function onWindowEvent(e:hxd.Event):Void {
		if (!ENABLED || !cursorFree || e == null)
			return;
		if (!blockGameKeys && !typingActive)
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

			// Mod toggles must still reach their own poll paths.
			if (code == hxd.Key.F6 || code == hxd.Key.F12)
				return;

			// Belt and braces only. The authoritative block is the plugin's WndProc gate
			// (ImGui.setKeyboardBlock / io.WantTextInput); this just stops any Heaps listener
			// that is fed from somewhere other than the window message pump.
			e.propagate = false;
			e.cancel = true;
		} catch (_:Dynamic) {}
	}

	static function applyInputPolicy(free:Bool):Void {
		try {
			// Farever taking the cursor back mid-drag is what sent windows walking off screen:
			// NoMouse parks the mouse off-screen while ImGui still holds an active drag/resize,
			// so it keeps moving the window towards a position that no longer exists. Releasing
			// held input on the transition ends the drag instead of stranding it.
			if (freeKnown && lastFree && !free)
				ImGui.clearInput();
			freeKnown = true;
			lastFree = free;
		} catch (_:Dynamic) {}
		try {
			var io:ImGuiIO = ImGui.getIO();
			if (io == null)
				return;
			// io.ConfigFlags is the first I32 in ImGuiIO. Other bits, including the
			// engine's DockingEnable, are preserved.
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
}
