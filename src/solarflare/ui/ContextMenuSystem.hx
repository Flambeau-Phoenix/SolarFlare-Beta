package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiMouseButton;

/**
 * Unified context menu system with item binding, safe begin/end pairing, and section separators.
 */
class ContextMenuSystem {
	static var activeMenu:String = "";
	static var openTimestamp:Float = 0;

	/**
	 * Open a context menu when right-clicking the last submitted ImGui item.
	 */
	public static function openForItem(id:String, mouseButton:Int = 1):Bool {
		if (ImGui.isItemClicked(mouseButton)) {
			ImGui.openPopup(id);
			return true;
		}
		return false;
	}

	/**
	 * Begin a context menu popup. Always pair with ContextMenuSystem.end().
	 */
	public static function begin(id:String, ?onOpen:Void->Void):Bool {
		var now = Date.now().getTime() / 1000.0;
		if (activeMenu != "" && now - openTimestamp > 30.0) {
			activeMenu = "";
		}

		var result = ImGui.beginPopup(id);
		if (result) {
			if (activeMenu != id) {
				activeMenu = id;
				openTimestamp = now;
				if (onOpen != null)
					onOpen();
			}
		}
		return result;
	}

	public static function end():Void {
		ImGui.endPopup();
		activeMenu = "";
	}

	/**
	 * Render a styled menu item with optional icon.
	 */
	public static function menuItem(label:String, shortcut:String = "", icon:String = "", selected:Bool = false, enabled:Bool = true):Bool {
		if (!enabled)
			ImGui.beginDisabled();

		if (icon != null && icon.length > 0) {
			var iconKey = icon;
			if (!GameIcons.imageKey(iconKey, 16, 16))
				ImGui.dummy(ImGui.vec2(16, 16));
			ImGui.sameLine(0, 6);
		}

		var result = ImGui.menuItem(label, shortcut, selected, enabled);

		if (!enabled)
			ImGui.endDisabled();
		return result;
	}

	/**
	 * Render a styled section header separator.
	 */
	public static function separatorLabel(text:String):Void {
		ImGui.separatorText(text);
	}
}
