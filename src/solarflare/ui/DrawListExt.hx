package solarflare.ui;

import imgui.ImGui;
import imgui.ImGui.ImDrawList;
import imgui.Structs.ImVec2;
import imgui.Enums.ImDrawFlags;

/**
 * Extended canvas drawing helpers for ImDrawList.
 */
typedef ImDrawListExt = DrawListExt;

class DrawListExt {
	/**
	 * Draw an arc (partial circle outline).
	 */
	public static function addArc(drawList:ImDrawList, center:ImVec2, radius:Float, startAngle:Float, endAngle:Float, color:Int, thickness:Float = 1.0, segments:Int = 16):Void {
		if (drawList == null || segments <= 0)
			return;

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
	}

	/**
	 * Draw a dashed line between two points.
	 */
	public static function addDashedLine(drawList:ImDrawList, p1:ImVec2, p2:ImVec2, color:Int, thickness:Float = 1.0, dashLength:Float = 4.0, gapLength:Float = 4.0):Void {
		if (drawList == null)
			return;

		var dx = p2.x - p1.x;
		var dy = p2.y - p1.y;
		var len = Math.sqrt(dx * dx + dy * dy);
		if (len <= 0.001)
			return;

		var step = dashLength + gapLength;
		var count = Math.floor(len / step);

		for (i in 0...count) {
			var t1 = (i * step) / len;
			var t2 = ((i * step) + dashLength) / len;
			if (t2 > 1.0) t2 = 1.0;

			var x1 = p1.x + dx * t1;
			var y1 = p1.y + dy * t1;
			var x2 = p1.x + dx * t2;
			var y2 = p1.y + dy * t2;
			ImGui.ImDrawList_AddLine(drawList, ImGui.vec2(x1, y1), ImGui.vec2(x2, y2), color, thickness);
		}
	}

	/**
	 * Draw a rounded rectangle outline.
	 */
	public static function addRoundedRect(drawList:ImDrawList, pMin:ImVec2, pMax:ImVec2, color:Int, rounding:Float = 0.0, thickness:Float = 1.0):Void {
		if (drawList == null)
			return;
		ImGui.ImDrawList_AddRect(drawList, pMin, pMax, color, rounding, thickness, ImDrawFlags.RoundCornersAll);
	}

	/**
	 * Draw a filled rounded rectangle with optional border.
	 */
	public static function addRoundedRectFilled(drawList:ImDrawList, pMin:ImVec2, pMax:ImVec2, fillColor:Int, borderColor:Int = 0, rounding:Float = 0.0, borderThickness:Float = 0.0):Void {
		if (drawList == null)
			return;
		ImGui.ImDrawList_AddRectFilled(drawList, pMin, pMax, fillColor, rounding);
		if (borderThickness > 0.0 && borderColor != 0) {
			ImGui.ImDrawList_AddRect(drawList, pMin, pMax, borderColor, rounding, borderThickness, ImDrawFlags.RoundCornersAll);
		}
	}
}
