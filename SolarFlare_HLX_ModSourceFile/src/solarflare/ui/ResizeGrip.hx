package solarflare.ui;

import imgui.ImGui;
import imgui.Structs.ImVec2;

/**
 * Custom styled 3-dot resize grip for unlocked HUD chrome windows.
 */
class ResizeGrip {
	public static function draw(dl:Dynamic, posX:Float, posY:Float, size:Float = 14.0, color:Int = 0x66FFFFFF):Void {
		var dotSize:Single = 2.0;
		var spacing:Single = 4.0;
		var startX = posX + size - spacing * 2 - dotSize;
		var startY = posY + size - spacing * 2 - dotSize;

		for (row in 0...3) {
			for (col in 0...3) {
				if (row + col >= 2) {
					var x = startX + col * spacing;
					var y = startY + row * spacing;
					ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(x, y), dotSize, color, 6);
				}
			}
		}
	}
}
