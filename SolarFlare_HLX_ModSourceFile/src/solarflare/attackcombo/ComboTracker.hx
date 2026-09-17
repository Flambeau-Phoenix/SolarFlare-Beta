package solarflare.attackcombo;

import imgui.ImGui;
import imgui.Enums.ImGuiStyleVar;
import imgui.Structs.ImVec2;
import solarflare.ui.UiCol;
import solarflare.ui.VectorGlow;

typedef ColorSet = {
	var active:Int;
	var inactive:Int;
	var finalCol:Int;
	var background:Int;
	var text:Int;
}

/**
 * Professional attack combo tracker with multiple visual styles (Compact, Detailed, Minimalist, Circular).
 */
class ComboTracker {
	public var displayMode:Int = 0; // 0=Compact, 1=Detailed, 2=Minimalist, 3=Circular
	public var orientation:Int = 0; // 0=Horizontal, 1=Vertical
	public var showLabels:Bool = true;
	public var showGlow:Bool = true;
	public var animationSpeed:Float = 1.0;
	public var colorScheme:Int = 0; // 0=Default, 1=Fiery, 2=Icy, 3=Electric, 4=Royal

	var animTime:Float = 0;
	var pulsePhase:Float = 0;
	var lastStep:Int = -1;
	var stepChangeTime:Float = 0;

	static inline var SIZE_COMPACT:Float = 32;
	static inline var SIZE_DETAILED:Float = 44;
	static inline var SIZE_MINIMAL:Float = 20;

	public function new() {}

	public function draw(step:Int, count:Int, isFinal:Bool, withinCombo:Bool, rowW:Single, rowH:Single):Void {
		var dt = 0.016;
		animTime += dt * animationSpeed;
		pulsePhase = Math.sin(animTime * 2.5) * 0.5 + 0.5;

		if (step != lastStep) {
			lastStep = step;
			stepChangeTime = animTime;
		}

		var n = count > 0 ? count : 4;
		var cur = step;
		if (cur < 0) cur = 0;
		if (cur > n) cur = n;

		var colors = getColors(colorScheme);

		switch (displayMode) {
			case 1:
				drawDetailed(n, cur, isFinal, withinCombo, colors, rowW, rowH);
			case 2:
				drawModernRadial(n, cur, isFinal, withinCombo, colors, rowW, rowH);
			case 3:
				drawClassicBar(n, cur, isFinal, withinCombo, colors, rowW, rowH);
			case 4:
				drawMinimalist(n, cur, isFinal, withinCombo, colors, rowW, rowH);
			case 5:
				drawCircular(n, cur, isFinal, withinCombo, colors, rowW, rowH);
			default:
				drawCompact(n, cur, isFinal, withinCombo, colors, rowW, rowH);
		}
	}

	function drawModernRadial(count:Int, current:Int, isFinal:Bool, withinCombo:Bool, colors:ColorSet, rowW:Single, rowH:Single):Void {
		var radius:Single = Math.min(rowW, rowH) * 0.38;
		if (radius < 12) radius = 12;
		var progress:Float = count > 0 ? (current / count) : 0;
		if (progress > 1.0) progress = 1.0;
		var isActive = current > 0;

		var origin = ImGui.getCursorScreenPos();
		var cx = origin.x + rowW * 0.5;
		var cy = origin.y + rowH * 0.5;
		var dl = ImGui.getWindowDrawList();

		ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), radius, 0x33FFFFFF, 32, 2.0);

		if (isActive) {
			var startAngle = -Math.PI / 2.0;
			var endAngle = startAngle + progress * Math.PI * 2.0;
			var color = isFinal ? colors.finalCol : colors.active;

			if (showGlow) {
				var glowSize = radius * (1.1 + 0.2 * pulsePhase);
				VectorGlow.radial(dl, cx, cy, glowSize, color, 0.35, 8);
			}

			ImGui.ImDrawList_PathClear(dl);
			ImGui.ImDrawList_PathArcTo(dl, ImGui.vec2(cx, cy), radius, startAngle, endAngle, 32);
			ImGui.ImDrawList_PathStroke(dl, color, 3.0, 0);

			var endX = cx + Math.cos(endAngle) * radius;
			var endY = cy + Math.sin(endAngle) * radius;
			var dotSize:Single = 3.0 + 1.5 * pulsePhase;
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(endX, endY), dotSize, color, 8);
		}

		var numText = isFinal ? "MAX" : Std.string(current);
		var textColor = isFinal ? colors.finalCol : (isActive ? colors.active : colors.inactive);
		var ts = ImGui.calcTextSize(numText);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(cx - ts.x * 0.5, cy - ts.y * 0.5), textColor, numText);

		if (showLabels && !isFinal) {
			var counterText = '$current/$count';
			var cs = ImGui.calcTextSize(counterText);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(cx - cs.x * 0.5, cy + radius + 2), 0x99FFFFFF, counterText);
		}

		ImGui.dummy(ImGui.vec2(rowW > 1 ? rowW : 100, rowH > 1 ? rowH : 50));
	}

	function drawClassicBar(count:Int, current:Int, isFinal:Bool, withinCombo:Bool, colors:ColorSet, rowW:Single, rowH:Single):Void {
		var isActive = current > 0;
		var progress:Float = count > 0 ? (current / count) : 0;
		if (progress > 1.0) progress = 1.0;
		var barHeight:Single = 10.0;
		var barWidth:Single = Math.min(rowW - 20, 180.0);
		if (barWidth < 40) barWidth = 40;

		var origin = ImGui.getCursorScreenPos();
		var cx = origin.x + rowW * 0.5;
		var cy = origin.y + rowH * 0.5;
		var barX = cx - barWidth * 0.5;
		var barY = cy + 4.0;
		var dl = ImGui.getWindowDrawList();

		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(barX, barY), ImGui.vec2(barX + barWidth, barY + barHeight), 0x33FFFFFF, 4.0);

		if (isActive) {
			var fillW = barWidth * progress;
			var color = isFinal ? colors.finalCol : colors.active;
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(barX, barY), ImGui.vec2(barX + fillW, barY + barHeight), color, 4.0);

			if (showGlow) {
				VectorGlow.radial(dl, barX + fillW, barY + barHeight * 0.5, 14.0, color, 0.4, 6);
			}
		}

		var numText = isFinal ? "MAX COMBO" : (isActive ? 'COMBO $current' : "READY");
		var textColor = isFinal ? colors.finalCol : (isActive ? colors.active : colors.inactive);
		var ts = ImGui.calcTextSize(numText);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(cx - ts.x * 0.5, barY - ts.y - 4), textColor, numText);

		ImGui.dummy(ImGui.vec2(rowW > 1 ? rowW : 100, rowH > 1 ? rowH : 50));
	}

	function drawCompact(count:Int, current:Int, isFinal:Bool, withinCombo:Bool, colors:ColorSet, rowW:Single, rowH:Single):Void {
		var size:Single = SIZE_COMPACT;
		var spacing:Single = 6;
		var isVert = orientation == 1;
		var totalW:Single = isVert ? size : count * (size + spacing) - spacing;
		var totalH:Single = isVert ? count * (size + spacing) - spacing : size;

		var origin = ImGui.getCursorScreenPos();
		var startX = origin.x + (rowW - totalW) * 0.5;
		var startY = origin.y + (rowH - totalH) * 0.5;
		var dl = ImGui.getWindowDrawList();

		// Background plate
		var pad:Single = 4;
		ImGui.ImDrawList_AddRectFilled(dl,
			ImGui.vec2(startX - pad, startY - pad),
			ImGui.vec2(startX + totalW + pad, startY + totalH + pad),
			0x66111827, 8.0);

		for (i in 0...count) {
			var isActive = i < current;
			var isCur = i == current - 1;
			var x = isVert ? startX : startX + i * (size + spacing);
			var y = isVert ? startY + i * (size + spacing) : startY;

			var col = isActive ? (isFinal && isCur ? colors.finalCol : colors.active) : colors.inactive;
			var alpha:Float = isActive ? 1.0 : 0.35;
			var colorWithAlpha = (col & 0x00FFFFFF) | (Std.int(alpha * 255) << 24);

			// Glow on active step
			if (isCur && isActive && showGlow) {
				var glowSize = size * (0.6 + 0.3 * pulsePhase);
				VectorGlow.radial(dl, x + size * 0.5, y + size * 0.5, glowSize, col, 0.4, 8);
			}

			// Segment shape
			drawSegment(dl, x, y, size, colorWithAlpha, isActive, isCur, colors);

			// Number label
			if (showLabels) {
				var num = Std.string(i + 1);
				var ts = ImGui.calcTextSize(num);
				ImGui.ImDrawList_AddText_Vec2(dl,
					ImGui.vec2(x + (size - ts.x) * 0.5, y + (size - ts.y) * 0.5),
					isActive ? 0xFFFFFFFF : 0x88FFFFFF, num);
			}

			// Connector line
			if (i < count - 1) {
				var x1 = isVert ? x + size * 0.5 : x + size;
				var y1 = isVert ? y + size : y + size * 0.5;
				var x2 = isVert ? x + size * 0.5 : x + size + spacing;
				var y2 = isVert ? y + size + spacing : y + size * 0.5;
				var lineCol = (i < current - 1) ? colors.active : colors.inactive;
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x1, y1), ImGui.vec2(x2, y2), lineCol, 2.0);
			}
		}

		ImGui.dummy(ImGui.vec2(rowW > 1 ? rowW : totalW, rowH > 1 ? rowH : totalH));
	}

	function drawDetailed(count:Int, current:Int, isFinal:Bool, withinCombo:Bool, colors:ColorSet, rowW:Single, rowH:Single):Void {
		var size:Single = SIZE_DETAILED;
		var spacing:Single = 8;
		var totalW:Single = count * (size + spacing) - spacing;
		var totalH:Single = size + 20;

		var origin = ImGui.getCursorScreenPos();
		var startX = origin.x + (rowW - totalW) * 0.5;
		var startY = origin.y + (rowH - totalH) * 0.5;
		var dl = ImGui.getWindowDrawList();

		var title = isFinal ? "FINAL COMBO" : (withinCombo ? 'COMBO $current/$count' : "READY");
		var titleCol = isFinal ? colors.finalCol : (withinCombo ? colors.active : colors.inactive);
		var ts = ImGui.calcTextSize(title);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(startX + (totalW - ts.x) * 0.5, startY), titleCol | 0xFF000000, title);

		var segmentY = startY + 18;

		for (i in 0...count) {
			var isActive = i < current;
			var isCur = i == current - 1;
			var x = startX + i * (size + spacing);
			var y = segmentY;

			var col = isActive ? (isFinal && isCur ? colors.finalCol : colors.active) : colors.inactive;
			var alpha:Float = isActive ? 1.0 : 0.3;
			var colorWithAlpha = (col & 0x00FFFFFF) | (Std.int(alpha * 255) << 24);

			if (isCur && isActive && showGlow) {
				var glowSize = size * (0.7 + 0.3 * pulsePhase);
				VectorGlow.radial(dl, x + size * 0.5, y + size * 0.5, glowSize, col, 0.45, 10);
			}

			drawSegment(dl, x, y, size, colorWithAlpha, isActive, isCur, colors);

			if (i < count - 1) {
				var x1 = x + size;
				var y1 = y + size * 0.5;
				var x2 = x + size + spacing;
				var y2 = y + size * 0.5;
				var lineCol = (i < current - 1) ? colors.active : colors.inactive;
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x1, y1), ImGui.vec2(x2, y2), lineCol, 2.5);
			}
		}

		ImGui.dummy(ImGui.vec2(rowW > 1 ? rowW : totalW, rowH > 1 ? rowH : totalH));
	}

	function drawMinimalist(count:Int, current:Int, isFinal:Bool, withinCombo:Bool, colors:ColorSet, rowW:Single, rowH:Single):Void {
		var size:Single = SIZE_MINIMAL;
		var spacing:Single = 4;
		var totalW:Single = count * (size + spacing) - spacing;

		var origin = ImGui.getCursorScreenPos();
		var startX = origin.x + (rowW - totalW) * 0.5;
		var startY = origin.y + (rowH - size) * 0.5;
		var dl = ImGui.getWindowDrawList();

		for (i in 0...count) {
			var isActive = i < current;
			var isCur = i == current - 1;
			var x = startX + i * (size + spacing);
			var y = startY;

			var col = isActive ? (isFinal && isCur ? colors.finalCol : colors.active) : colors.inactive;
			var alpha:Float = isActive ? 1.0 : 0.25;
			var colorWithAlpha = (col & 0x00FFFFFF) | (Std.int(alpha * 255) << 24);

			if (isCur && isActive && showGlow) {
				VectorGlow.radial(dl, x + size * 0.5, y + size * 0.5, size * 0.9, col, 0.35, 6);
			}

			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(x + size * 0.5, y + size * 0.5), size * 0.45, colorWithAlpha, 12);

			if (i < count - 1) {
				var x1 = x + size;
				var y1 = y + size * 0.5;
				var x2 = x + size + spacing;
				var y2 = y + size * 0.5;
				var lineCol = (i < current - 1) ? colors.active : colors.inactive;
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x1, y1), ImGui.vec2(x2, y2), lineCol, 1.5);
			}
		}

		ImGui.dummy(ImGui.vec2(rowW > 1 ? rowW : totalW, rowH > 1 ? rowH : size));
	}

	function drawCircular(count:Int, current:Int, isFinal:Bool, withinCombo:Bool, colors:ColorSet, rowW:Single, rowH:Single):Void {
		var radius:Single = Math.min(rowW, rowH) * 0.45;
		if (radius < 16) radius = 16;
		var origin = ImGui.getCursorScreenPos();
		var center = ImGui.vec2(origin.x + rowW * 0.5, origin.y + rowH * 0.5);
		var dl = ImGui.getWindowDrawList();

		ImGui.ImDrawList_AddCircleFilled(dl, center, radius + 4, 0x88000000, 24);

		var segAngle = Math.PI * 2.0 / count;
		var startAngle = -Math.PI / 2.0;

		for (i in 0...count) {
			var isActive = i < current;
			var isCur = i == current - 1;
			var angle = startAngle + i * segAngle;

			var col = isActive ? (isFinal && isCur ? colors.finalCol : colors.active) : colors.inactive;
			var alpha:Float = isActive ? 1.0 : 0.3;
			var colorWithAlpha = (col & 0x00FFFFFF) | (Std.int(alpha * 255) << 24);

			var innerR = radius * 0.45;
			var outerR = isCur ? radius * 0.88 : radius * 0.78;

			// Arc wedge
			var midA = angle + segAngle * 0.5;
			var dotX = center.x + Math.cos(midA) * ((innerR + outerR) * 0.5);
			var dotY = center.y + Math.sin(midA) * ((innerR + outerR) * 0.5);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(dotX, dotY), (outerR - innerR) * 0.4, colorWithAlpha, 12);

			if (isCur && isActive && showGlow) {
				VectorGlow.radial(dl, dotX, dotY, radius * 0.5, col, 0.4, 8);
			}
		}

		if (current > 0) {
			var label = '$current/$count';
			var ts = ImGui.calcTextSize(label);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(center.x - ts.x * 0.5, center.y - ts.y * 0.5), 0xFFFFFFFF, label);
		}

		ImGui.dummy(ImGui.vec2(rowW, rowH));
	}

	function drawSegment(dl:Dynamic, x:Float, y:Float, size:Float, color:Int, active:Bool, current:Bool, colors:ColorSet):Void {
		var half = size * 0.45;
		var cx = x + size * 0.5;
		var cy = y + size * 0.5;

		if (current) {
			// Diamond for current
			ImGui.ImDrawList_AddQuadFilled(dl,
				ImGui.vec2(cx, cy - half),
				ImGui.vec2(cx + half, cy),
				ImGui.vec2(cx, cy + half),
				ImGui.vec2(cx - half, cy),
				color);
		} else if (active) {
			// Circle for active
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), half, color, 16);
		} else {
			// Rounded square for inactive
			var pad:Single = 3;
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x + pad, y + pad), ImGui.vec2(x + size - pad, y + size - pad), color, 4.0);
		}
	}

	function getColors(scheme:Int):ColorSet {
		return switch (scheme) {
			case 1: // Fiery
				{ active: UiCol.fromArgb(0xFFFF6633), inactive: UiCol.fromArgb(0x66442200), finalCol: UiCol.fromArgb(0xFFFF2244), background: UiCol.fromArgb(0x88221100), text: UiCol.fromArgb(0xFFFF8844) };
			case 2: // Icy
				{ active: UiCol.fromArgb(0xFF33AAFF), inactive: UiCol.fromArgb(0x55002244), finalCol: UiCol.fromArgb(0xFF88FFFF), background: UiCol.fromArgb(0x88002244), text: UiCol.fromArgb(0xFF88CCFF) };
			case 3: // Electric
				{ active: UiCol.fromArgb(0xFF44FF88), inactive: UiCol.fromArgb(0x55004422), finalCol: UiCol.fromArgb(0xFFFFCC00), background: UiCol.fromArgb(0x88002211), text: UiCol.fromArgb(0xFFCCFF44) };
			case 4: // Royal
				{ active: UiCol.fromArgb(0xFFCC44FF), inactive: UiCol.fromArgb(0x55440066), finalCol: UiCol.fromArgb(0xFFFF44AA), background: UiCol.fromArgb(0x88220044), text: UiCol.fromArgb(0xFFFFAAFF) };
			default: // Default Blue / teal
				{ active: UiCol.fromArgb(0xFF38B2AC), inactive: UiCol.fromArgb(0x552D3748), finalCol: UiCol.fromArgb(0xFFF56565), background: UiCol.fromArgb(0x881A202C), text: 0xFFFFFFFF };
		};
	}
}
