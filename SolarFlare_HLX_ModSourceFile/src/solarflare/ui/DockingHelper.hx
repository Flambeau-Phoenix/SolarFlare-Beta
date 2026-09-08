package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiDockNodeFlags;
import imgui.Enums.ImGuiConfigFlags;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Enums.ImGuiCond;
import imgui.Structs.ImVec2;

/**
 * Docking and workspace management for Solar Flare 2.
 * Fully compatible with Farever's single DX12 swap chain and CursorCaptureFix input gating.
 */
class DockingHelper {
	public static var dockSpaceId:Int = 0;
	static var initialized:Bool = false;
	static var firstFrame:Bool = true;

	/**
	 * Initialize the docking system and enable docking flag on ImGuiIO.
	 */
	public static function init():Void {
		if (initialized)
			return;

		enableDocking();
		dockSpaceId = ImGui.getID_Str("SolarFlareDockSpace");
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
				// ImGuiConfigFlags_DockingEnable is bit 6 (64)
				var flags = mem.getI32(0) | ImGuiConfigFlags.DockingEnable;
				mem.setI32(0, flags);
			}
		} catch (_:Dynamic) {}
	}

	static inline function addressOf(io:imgui.ImGui.ImGuiIO):haxe.Int64 {
		return untyped io;
	}

	/**
	 * Setup the main dockspace filling the viewport with PassthruCentralNode so Farever 3D scene clicks pass through.
	 * Call once per frame early in the draw loop before child dockable windows.
	 */
	public static function setupMainDockSpace():Void {
		if (!initialized)
			init();

		// PassthruCentralNode keeps the central node transparent and click-through to Farever
		var flags = ImGuiDockNodeFlags.PassthruCentralNode;

		// dockSpaceOverViewport submits the full-viewport host window and dockspace
		ImGui.dockSpaceOverViewport(null, flags);

		firstFrame = false;
	}

	/**
	 * Create a dockable window that respects CursorCaptureFix look-lock input gating.
	 * @param title Window title and unique ID
	 * @param content Function to draw window contents
	 * @param open Open state
	 * @param flags Optional base window flags
	 * @return Current open state
	 */
	public static function dockableWindow(title:String, content:Void->Void, open:Null<imgui.ref.BoolRef> = null, flags:Int = 0):Bool {
		if (!initialized)
			init();

		if (open != null && !open.get())
			return false;

		// Assign default docking to the main dockspace on first use
		ImGui.setNextWindowDockID(dockSpaceId, ImGuiCond.FirstUseEver);

		// Apply CursorCaptureFix to ensure look-lock camera clicks are not stolen
		var effectiveFlags = CursorCaptureFix.windowFlags(flags);

		var visible = ImGui.begin(title, open, effectiveFlags);
		if (visible) {
			content();
		}
		ImGui.end();

		return open != null ? open.get() : visible;
	}

	/**
	 * Create a dockable window with forced initial position/size on first frame.
	 */
	public static function dockableWindowWithPosition(title:String, content:Void->Void, open:Null<imgui.ref.BoolRef>, pos:ImVec2, size:ImVec2, flags:Int = 0):Bool {
		if (!initialized)
			init();

		if (open != null && !open.get())
			return false;

		if (firstFrame) {
			ImGui.setNextWindowPos(pos, ImGuiCond.FirstUseEver);
			ImGui.setNextWindowSize(size, ImGuiCond.FirstUseEver);
		}
		ImGui.setNextWindowDockID(dockSpaceId, ImGuiCond.FirstUseEver);

		var effectiveFlags = CursorCaptureFix.windowFlags(flags);
		var visible = ImGui.begin(title, open, effectiveFlags);
		if (visible) {
			content();
		}
		ImGui.end();

		return open != null ? open.get() : visible;
	}

	/**
	 * Get the current dock ID for the enclosing window.
	 */
	public static inline function getCurrentDockID():Int {
		return ImGui.getWindowDockID();
	}

	/**
	 * Check if the enclosing window is currently docked into a dock node.
	 */
	public static inline function isWindowDocked():Bool {
		return ImGui.isWindowDocked();
	}

	/**
	 * Reset docking state.
	 */
	public static function resetLayout():Void {
		firstFrame = true;
		initialized = false;
	}
}
