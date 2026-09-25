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

	public static inline function isWindowDocked():Bool {
		return ImGui.isWindowDocked();
	}

	public static function resetLayout():Void {
		initialized = false;
		dockSpaceId = 0;
	}
}
