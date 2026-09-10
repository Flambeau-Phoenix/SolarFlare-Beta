package solarflare.attackcombo;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiStyleVar;
import imgui.Structs.ImVec2;
import solarflare.ui.UiCol;
import solarflare.ui.VectorGlow;
import solarflare.attackcombo.ComboTracker.ColorSet;

/**
 * Modern, sleek attack combo tracker with smooth animations.
 * Designed for transparent, lockable windows.
 */
class AttackComboTracker {
	// Animation state
	var animTime:Float = 0;
	var pulsePhase:Float = 0;
	var lastCombo:Float = 0;
	var comboTransition:Float = 1.0;
	var targetCombo:Float = 0;

	// Display settings
	public var displayStyle:Int = 0; // 0=Modern, 1=Classic, 2=Minimal
	public var colorTheme:Int = 0; // 0=Blue, 1=Orange, 2=Purple, 3=Green, 4=Red

	public var showCounter:Bool = true;
	public var showProgress:Bool = true;
	public var showLabel:Bool = true;
	public var showGlow:Bool = true;
	public var size:Float = 64;
	public var progressWidth:Float = 180;

	static inline var ANIMATION_SPEED:Float = 5.0;

	public function new() {
		animTime = 0;
		pulsePhase = 0;
	}

	public function draw(currentCombo:Int, maxCombo:Int = 4, isMaxed:Bool = false, rowW:Single = 200, rowH:Single = 60):Void {
		var dt = 0.016;
		animTime += dt;
		pulsePhase = Math.sin(animTime * 2.5) * 0.5 + 0.5;

		if (currentCombo != targetCombo) {
			lastCombo = targetCombo;
			targetCombo = currentCombo;
			comboTransition = 0;
		}
		comboTransition = Math.min(1.0, comboTransition + dt * ANIMATION_SPEED);

		var displayCombo = lerp(lastCombo, targetCombo, easeOutCubic(comboTransition));

		var colors = getColors(colorTheme);
		var dl = ImGui.getWindowDrawList();
		var pos = ImGui.getCursorScreenPos();

		var cx = pos.x + rowW * 0.5;
		var cy = pos.y + rowH * 0.5;

		switch (displayStyle) {
			case 1:
				drawClassic(dl, cx, cy, displayCombo, maxCombo, isMaxed, colors, rowW, rowH);
			case 2:
				drawMinimal(dl, cx, cy, displayCombo, maxCombo, isMaxed, colors, rowW, rowH);
			default:
				drawModern(dl, cx, cy, displayCombo, maxCombo, isMaxed, colors, rowW, rowH);
		}

		ImGui.dummy(ImGui.vec2(rowW > 1 ? rowW : 100, rowH > 1 ? rowH : 50));
	}

	function drawModern(dl:Dynamic, cx:Float, cy:Float, combo:Float, max:Int, isMaxed:Bool, colors:ColorSet, rowW:Single, rowH:Single):Void {
		var radius:Single = Math.min(rowW, rowH) * 0.38;
		if (radius < 12) radius = 12;
		var progress = max > 0 ? (combo / max) : 0;
		if (progress > 1.0) progress = 1.0;
		var isActive = combo > 0.1;

		// Background ring
		ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(cx, cy), radius, 0x33FFFFFF, 32, 2.0);

		// Active progress ring
		if (isActive) {
			var startAngle = -Math.PI / 2.0;
			var endAngle = startAngle + progress * Math.PI * 2.0;
			var color = isMaxed ? colors.finalCol : colors.active;

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

		// Combo number
		var numText = isMaxed ? "MAX" : Std.string(Math.round(combo));
		var textColor = isMaxed ? colors.finalCol : (isActive ? colors.active : colors.inactive);
		var ts = ImGui.calcTextSize(numText);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(cx - ts.x * 0.5, cy - ts.y * 0.5), textColor, numText);

		// Counter: 0/4
		if (showCounter && !isMaxed) {
			var counterText = Std.string(Math.round(combo)) + "/" + Std.string(max);
			var cs = ImGui.calcTextSize(counterText);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(cx - cs.x * 0.5, cy + radius + 2), 0x99FFFFFF, counterText);
		}
	}

	function drawClassic(dl:Dynamic, cx:Float, cy:Float, combo:Float, max:Int, isMaxed:Bool, colors:ColorSet, rowW:Single, rowH:Single):Void {
		var isActive = combo > 0.1;
		var progress = max > 0 ? (combo / max) : 0;
		if (progress > 1.0) progress = 1.0;
		var barHeight:Single = 10.0;
		var barWidth:Single = Math.min(rowW - 20, progressWidth);
		if (barWidth < 40) barWidth = 40;
		var barX = cx - barWidth * 0.5;
		var barY = cy + 4.0;

		// Bar background
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(barX, barY), ImGui.vec2(barX + barWidth, barY + barHeight), 0x33FFFFFF, 4.0);

		// Progress fill
		if (isActive) {
			var fillW = barWidth * progress;
			var color = isMaxed ? colors.finalCol : colors.active;
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(barX, barY), ImGui.vec2(barX + fillW, barY + barHeight), color, 4.0);

			if (showGlow) {
				VectorGlow.radial(dl, barX + fillW, barY + barHeight * 0.5, 14.0, color, 0.4, 6);
			}
		}

		// Combo text
		var numText = isMaxed ? "MAX COMBO" : (isActive ? 'COMBO ${Math.round(combo)}' : "READY");
		var textColor = isMaxed ? colors.finalCol : (isActive ? colors.active : colors.inactive);
		var ts = ImGui.calcTextSize(numText);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(cx - ts.x * 0.5, barY - ts.y - 4), textColor, numText);
	}

	function drawMinimal(dl:Dynamic, cx:Float, cy:Float, combo:Float, max:Int, isMaxed:Bool, colors:ColorSet, rowW:Single, rowH:Single):Void {
		var isActive = combo > 0.1;
		var numText = isMaxed ? "MAX" : Std.string(Math.round(combo));
		var textColor = isMaxed ? colors.finalCol : (isActive ? colors.active : colors.inactive);

		if (isActive && showGlow) {
			VectorGlow.radial(dl, cx, cy - 4, 18.0, textColor, 0.4, 8);
		}

		var ts = ImGui.calcTextSize(numText);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(cx - ts.x * 0.5, cy - ts.y * 0.5 - 4), textColor, numText);

		// Dots
		if (showProgress && !isMaxed && max > 0) {
			var dotRadius:Single = 3.0;
			var dotSpacing:Single = 8.0;
			var totalDots = Math.min(max, 8);
			var startX = cx - (totalDots - 1) * dotSpacing * 0.5;
			var dotY = cy + 12.0;

			for (i in 0...Std.int(totalDots)) {
				var isFilled = i < combo;
				var dotColor = isFilled ? colors.active : 0x44FFFFFF;
				var dotX = startX + i * dotSpacing;
				ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(dotX, dotY), isFilled ? dotRadius : dotRadius * 0.6, dotColor, 8);
			}
		}
	}

	function getColors(scheme:Int):ColorSet {
		return switch (scheme) {
			case 1: // Fiery Orange
				{ active: UiCol.fromArgb(0xFFFF6633), inactive: UiCol.fromArgb(0x66442200), finalCol: UiCol.fromArgb(0xFFFF2244), background: UiCol.fromArgb(0x88221100), text: UiCol.fromArgb(0xFFFF8844) };
			case 2: // Royal Purple
				{ active: UiCol.fromArgb(0xFFCC44FF), inactive: UiCol.fromArgb(0x55440066), finalCol: UiCol.fromArgb(0xFFFF44AA), background: UiCol.fromArgb(0x88220044), text: UiCol.fromArgb(0xFFFFAAFF) };
			case 3: // Electric Green
				{ active: UiCol.fromArgb(0xFF44FF88), inactive: UiCol.fromArgb(0x55004422), finalCol: UiCol.fromArgb(0xFFFFCC00), background: UiCol.fromArgb(0x88002211), text: UiCol.fromArgb(0xFFCCFF44) };
			case 4: // Crimson Red
				{ active: UiCol.fromArgb(0xFFFF3344), inactive: UiCol.fromArgb(0x66441111), finalCol: UiCol.fromArgb(0xFFFFD700), background: UiCol.fromArgb(0x88220000), text: UiCol.fromArgb(0xFFFFEEEE) };
			default: // Modern Blue / teal
				{ active: UiCol.fromArgb(0xFF38B2AC), inactive: UiCol.fromArgb(0x552D3748), finalCol: UiCol.fromArgb(0xFFF56565), background: UiCol.fromArgb(0x881A202C), text: 0xFFFFFFFF };
		};
	}

	static function lerp(a:Float, b:Float, t:Float):Float {
		return a + (b - a) * t;
	}

	static function easeOutCubic(t:Float):Float {
		var p = 1.0 - t;
		return 1.0 - p * p * p;
	}
}
