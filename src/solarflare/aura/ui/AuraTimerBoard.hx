package solarflare.aura.ui;

import imgui.ImGui;
import imgui.Structs.ImVec2;
import solarflare.aura.AuraConfig;
import solarflare.aura.AuraDef;
import solarflare.aura.AuraTimer;
import solarflare.aura.AuraVisualRenderer;
import solarflare.ui.GameIcons;
import solarflare.ui.HUDWidgetWindow;
import solarflare.ui.SettingsStore;

/** Movable HUD window that stacks every active condition-driven timer. */
class AuraTimerBoard {
	/** Reused per frame; the board never allocates inside the draw loop. */
	static var scratch:Array<AuraDef> = [];

	public static var openBuilder:Void->Void;

	public static function draw(cfg:AuraConfig):Void {
		if (cfg == null || cfg.timerBoardHidden.get())
			return;
		scratch.splice(0, scratch.length);
		var max = cfg.timerBoardMax.get();
		if (max < 1)
			max = 1;
		for (a in cfg.auras) {
			if (a == null || !a.enabled.get())
				continue;
			if (AuraTimer.onBoard(a))
				scratch.push(a);
		}
		if (scratch.length == 0)
			return;
		scratch.sort(byRemaining);
		if (scratch.length > max)
			scratch.splice(max, scratch.length - max);

		var rowH:Single = Math.max(16, cfg.timerBoardRowH.get());
		var w:Single = Math.max(96, cfg.timerBoardW.get());
		var h:Single = rowH * scratch.length + 4;
		HUDWidgetWindow.draw("SolarFlare Timers##sf_timer_board", "Timers", cfg.timerBoardChrome, w, h,
			function(size:ImVec2) {
				body(size, rowH);
			}, openBuilder, function() {
				cfg.timerBoardHidden.set(true);
				SettingsStore.markDirty();
			}, cfg.unlockAll.get(), null, function(newW:Single, _:Single) {
				cfg.timerBoardW.set(Math.max(96, newW));
				SettingsStore.markDirty();
			});
	}

	static function body(size:ImVec2, rowH:Single):Void {
		var origin = ImGui.getCursorScreenPos();
		ImGui.dummy(size);
		var dl = ImGui.getWindowDrawList();
		var y:Single = origin.y + 2;
		for (a in scratch) {
			row(dl, a, origin.x + 2, y, size.x - 4, rowH - 2);
			y += rowH;
		}
	}

	static function row(dl:Dynamic, a:AuraDef, x:Single, y:Single, w:Single, h:Single):Void {
		if (w < 24 || h < 8)
			return;
		var expired = AuraTimer.expired(a);
		var frac = AuraTimer.fraction(a);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w, y + h),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.04, 0.05, 0.07, 0.78)), 4);
		var fillCol = expired
			? ImGui.vec4(0.55, 0.20, 0.18, 0.75)
			: (a.timerMode == AuraTimer.MODE_UP ? ImGui.vec4(0.20, 0.55, 0.72, 0.70) : ImGui.vec4(0.22, 0.62, 0.42, 0.70));
		if (frac > 0.001)
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, y), ImGui.vec2(x + w * frac, y + h),
				ImGui.colorConvertFloat4ToU32(fillCol), 4);

		var iconSide:Single = h - 2;
		var textX = x + 4;
		var icon = a.preferredIconId();
		if (icon != null && icon.length > 0 && iconSide >= 10
			&& GameIcons.drawKey(dl, icon, x + 2, y + 1, iconSide, iconSide, 0xFFFFFFFF))
			textX = x + iconSide + 6;

		var label = a.displayLabel();
		var value = AuraVisualRenderer.formatRemain(a.timerValue);
		if (value.length == 0)
			value = "0";
		var vts = ImGui.calcTextSize(value);
		var lts = ImGui.calcTextSize(label);
		var ty = y + (h - lts.y) * 0.5;
		var white = ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0.95));
		var valueX = x + w - vts.x - 5;
		var labelRight = valueX - 4;
		if (labelRight > textX) {
			ImGui.pushClipRect(ImGui.vec2(textX, y), ImGui.vec2(labelRight, y + h), true);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(textX, ty), white, label);
			ImGui.popClipRect();
		}
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(valueX, ty),
			ImGui.colorConvertFloat4ToU32(expired ? ImGui.vec4(1, 0.72, 0.6, 1) : ImGui.vec4(1, 0.95, 0.75, 1)), value);
	}

	/** Soonest-finishing first; expired rows sink to the bottom. */
	static function byRemaining(l:AuraDef, r:AuraDef):Int {
		var le = AuraTimer.expired(l);
		var re = AuraTimer.expired(r);
		if (le != re)
			return le ? 1 : -1;
		var lv = l.timerMode == AuraTimer.MODE_UP ? -l.timerValue : l.timerValue;
		var rv = r.timerMode == AuraTimer.MODE_UP ? -r.timerValue : r.timerValue;
		if (lv < rv)
			return -1;
		return lv > rv ? 1 : 0;
	}
}
