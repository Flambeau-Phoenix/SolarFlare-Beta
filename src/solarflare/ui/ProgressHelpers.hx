package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Structs.ImVec2;
import solarflare.ui.UiCol;

/**
 * Helper functions for progress bars, health gauges, and loading indicators in Solar Flare 2.
 */
class ProgressHelpers {
	/**
	 * Draw a labeled progress bar
	 * @param label The label text to prepend
	 * @param fraction 0.0 to 1.0, or negative for indeterminate
	 * @param width Width in pixels (0 = fill available space)
	 */
	public static function labeled(label:String, fraction:Float, width:Float = 0):Void {
		ImGui.text(label);
		ImGui.sameLine();
		var size = (width > 0) ? ImGui.vec2(width, 0) : ImGui.vec2(-1.0, 0);
		var pct = fraction >= 0 ? '${Std.int(fraction * 100)}%' : null;
		ImGui.progressBar(fraction, size, pct);
	}

	/**
	 * Draw an indeterminate (pulsing) progress bar
	 * @param width Width in pixels (0 = fill available space)
	 */
	public static function indeterminate(width:Float = 0, message:String = "Loading..."):Void {
		var size = (width > 0) ? ImGui.vec2(width, 0) : ImGui.vec2(-1.0, 0);
		ImGui.progressBar(-1.0, size, message);
	}

	/**
	 * Draw a health/resource style progress bar with color coding
	 * @param current Current value
	 * @param max Maximum value
	 * @param width Width in pixels (0 = fill available space)
	 */
	public static function healthBar(current:Float, max:Float, width:Float = 100):Void {
		var fraction = max > 0 ? (current / max) : 0.0;
		if (fraction > 1.0) fraction = 1.0;
		if (fraction < 0.0) fraction = 0.0;

		var color = if (fraction > 0.6) {
			UiCol.rgb(0x44DD44); // Green
		} else if (fraction > 0.25) {
			UiCol.rgb(0xDDDD22); // Yellow / Gold
		} else {
			UiCol.rgb(0xFF4444); // Red
		};

		var size = (width > 0) ? ImGui.vec2(width, 0) : ImGui.vec2(-1.0, 0);
		ImGui.pushStyleColor(ImGuiCol.PlotHistogram, color);
		ImGui.progressBar(fraction, size, '${Std.int(current)} / ${Std.int(max)}');
		ImGui.popStyleColor();
	}

	/**
	 * Draw a progress bar with custom styling and text
	 */
	public static function colored(fraction:Float, color:Int, label:String = null, width:Float = 0):Void {
		var size = (width > 0) ? ImGui.vec2(width, 0) : ImGui.vec2(-1.0, 0);
		ImGui.pushStyleColor(ImGuiCol.PlotHistogram, color);
		ImGui.progressBar(fraction, size, label);
		ImGui.popStyleColor();
	}

	/**
	 * Draw a circular animated progress spinner using WindowDrawList
	 */
	public static function spinner(radius:Float = 12.0, thickness:Float = 2.5, color:Int = -1):Void {
		if (color < 0)
			color = UiCol.rgb(0xFFAA00);
		var pos = ImGui.getCursorScreenPos();
		var center = ImGui.vec2(pos.x + radius, pos.y + radius);
		var drawList = ImGui.getWindowDrawList();
		if (drawList == null)
			return;

		var time = ImGui.getTime();
		var startAngle = (time * 5.0) % (Math.PI * 2);
		var endAngle = startAngle + (Math.PI * 1.5);
		var segments = 20;

		// Background circle
		ImGui.ImDrawList_AddCircle(drawList, center, radius, UiCol.rgba(255, 255, 255, 0x33), segments, thickness);

		// Spinning arc points
		var angleStep = (endAngle - startAngle) / segments;
		var lastX = center.x + Math.cos(startAngle) * radius;
		var lastY = center.y + Math.sin(startAngle) * radius;

		for (i in 1...segments + 1) {
			var a = startAngle + i * angleStep;
			var nextX = center.x + Math.cos(a) * radius;
			var nextY = center.y + Math.sin(a) * radius;
			ImGui.ImDrawList_AddLine(drawList, ImGui.vec2(lastX, lastY), ImGui.vec2(nextX, nextY), color, thickness);
			lastX = nextX;
			lastY = nextY;
		}

		// Reserve widget layout space
		ImGui.dummy(ImGui.vec2(radius * 2, radius * 2));
	}
}
