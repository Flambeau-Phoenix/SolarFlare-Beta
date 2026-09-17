package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiConfigFlags;
import imgui.Enums.ImGuiCond;
import imgui.Structs.ImVec2;

/**
 * Window-into-window docking only.
 *
 * DockingEnable stays on so tool windows can tab/split into each other.
 * No viewport dockspace — no screen-edge anchors or empty central docking void.
 */
class DockingHelper {
	/** Legacy ID retained for callers; never used as a viewport dock target. */
	public static var dockSpaceId:Int = 0;
	static var initialized:Bool = false;

	/**
	 * Enable docking without creating a full-screen dock host.
	 */
	public static function init():Void {
		if (initialized)
			return;

		enableDocking();
		dockSpaceId = 0;
		initialized = true;
	}

	/**
	 * Explicitly enable ImGuiConfigFlags.DockingEnable without tampering with NoMouseCursorChange.
	 */
	public static function enableDocking():Void {
		try {
			var io:imgui.ImGui.ImGuiIO = ImGui.getIO();
			if (io != null) {
				var mem = hl.Bytes.fromAddress(addressOf(io));
				// ImGuiConfigFlags_DockingEnable is bit 6 (64), NoMouseCursorChange is bit 5 (32)
				var flags = mem.getI32(0) | ImGuiConfigFlags.DockingEnable | ImGuiConfigFlags.NoMouseCursorChange;
				mem.setI32(0, flags);
			}
		} catch (_:Dynamic) {}
	}

	static inline function addressOf(io:imgui.ImGui.ImGuiIO):haxe.Int64 {
		return untyped io;
	}

	/**
	 * Per-frame docking prep. Does not submit dockSpaceOverViewport —
	 * that was the screen-anchor / preset docking host.
	 */
	public static function setupMainDockSpace():Void {
		if (!initialized)
			init();
		else
			enableDocking();
	}

	/**
	 * Floating dockable window (CursorCaptureFix look-lock gating).
	 * No default dock target — user docks onto another window only.
	 */
	public static function dockableWindow(title:String, content:Void->Void, open:Null<imgui.ref.BoolRef> = null, flags:Int = 0):Bool {
		if (!initialized)
			init();

		if (open != null && !open.get())
			return false;

		var effectiveFlags = CursorCaptureFix.windowFlags(flags);
		var visible = ImGui.begin(title, open, effectiveFlags);
		if (visible) {
			content();
		}
		ImGui.end();

		return open != null ? open.get() : visible;
	}

	/**
	 * Floating dockable window with first-use position/size hints.
	 */
	public static function dockableWindowWithPosition(title:String, content:Void->Void, open:Null<imgui.ref.BoolRef>, pos:ImVec2, size:ImVec2, flags:Int = 0):Bool {
		if (!initialized)
			init();

		if (open != null && !open.get())
			return false;

		ImGui.setNextWindowPos(pos, ImGuiCond.FirstUseEver);
		ImGui.setNextWindowSize(size, ImGuiCond.FirstUseEver);

		var effectiveFlags = CursorCaptureFix.windowFlags(flags);
		var visible = ImGui.begin(title, open, effectiveFlags);
		if (visible) {
			content();
		}
		ImGui.end();

		return open != null ? open.get() : visible;
	}

	public static inline function getCurrentDockID():Int {
		return ImGui.getWindowDockID();
	}

	public static inline function isWindowDocked():Bool {
		return ImGui.isWindowDocked();
	}

	public static function resetLayout():Void {
		initialized = false;
		dockSpaceId = 0;
	}
}
