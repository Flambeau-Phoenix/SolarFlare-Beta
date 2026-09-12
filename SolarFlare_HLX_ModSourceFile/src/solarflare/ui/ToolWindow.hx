package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiMouseButton;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.BoolRef;

/**
 * Floating tool windows (builders, Notebook, F6 hub).
 * Geometry is ImGui/imgui.ini owned — never HudChrome.
 * Plain title strip (theme-reactive); builders open undocked at full stage size.
 */
class ToolWindow {
	static var lastOpen:Map<String, Bool> = new Map();
	static var forceLayoutIds:Map<String, Bool> = new Map();
	static inline var STRIP:Single = 22;
	static inline var CLOSE:Single = 14;
	/** Keep close X left of the vertical scrollbar lane (ImGui default ~14–16px). */
	static inline var SCROLL_GUTTER:Single = 18;

	/**
	 * Begin a floating tool window. Always pair with ToolWindow.end() when open was true
	 * (ImGui.begin was called).
	 * @param dockable false = never dock; force large floating stage when opened.
	 */
	public static function begin(title:String, open:BoolRef, defaultW:Single = 1400, defaultH:Single = 900,
			extraFlags:Int = 0, dockable:Bool = false):Bool {
		if (open != null && !open.get()) {
			lastOpen.set(title, false);
			return false;
		}

		DockingHelper.init();

		var wasOpen = lastOpen.exists(title) && lastOpen.get(title);
		var nowOpen = open == null || open.get();
		if (nowOpen && !wasOpen)
			forceLayoutIds.set(title, true);
		lastOpen.set(title, nowOpen);

		var force = forceLayoutIds.exists(title) && forceLayoutIds.get(title);
		var sizeCond = force ? ImGuiCond.Always : ImGuiCond.FirstUseEver;
		ImGui.setNextWindowSize(ImGui.vec2(defaultW, defaultH), sizeCond);
		ImGui.setNextWindowSizeConstraints(ImGui.vec2(960, 640), ImGui.vec2(2400, 1600));

		if (force) {
			try {
				var vp = ImGui.getMainViewport();
				if (vp != null) {
					var c = ImGui.ImGuiViewport_GetCenter(vp);
					if (c != null) {
						ImGui.setNextWindowPos(ImGui.vec2(c.x - defaultW * 0.5, c.y - defaultH * 0.5), ImGuiCond.Always);
					}
				}
			} catch (_:Dynamic) {}
			try
				ImGui.setNextWindowDockID(0, ImGuiCond.Always)
			catch (_:Dynamic) {}
			try
				ImGui.setNextWindowCollapsed(false, ImGuiCond.Always)
			catch (_:Dynamic) {}
			forceLayoutIds.set(title, false);
		}

		var flags = CursorCaptureFix.windowFlags(extraFlags);
		flags |= ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse;
		if (!dockable) {
			flags |= ImGuiWindowFlags.NoDocking;
		} else if (DockingHelper.dockSpaceId != 0 && !force) {
			ImGui.setNextWindowDockID(DockingHelper.dockSpaceId, ImGuiCond.FirstUseEver);
		}

		UiChrome.pushCelShade();
		var shown = ImGui.begin(title, open, flags);
		if (shown)
			drawTitleStrip(title, open);
		return shown;
	}

	public static function beginWithMenuBar(title:String, open:BoolRef, defaultW:Single = 520,
			defaultH:Single = 640, dockable:Bool = false, rememberLayout:Bool = true):Bool {
		// Keep native menu/title interaction.
		if (open != null && !open.get()) {
			lastOpen.set(title, false);
			return false;
		}
		DockingHelper.init();
		var wasOpen = lastOpen.exists(title) && lastOpen.get(title);
		var nowOpen = open == null || open.get();
		if (nowOpen && !wasOpen)
			forceLayoutIds.set(title, true);
		lastOpen.set(title, nowOpen);
		var force = !rememberLayout && forceLayoutIds.exists(title) && forceLayoutIds.get(title);
		var sizeCond = force ? ImGuiCond.Always : ImGuiCond.FirstUseEver;
		ImGui.setNextWindowSize(ImGui.vec2(defaultW, defaultH), sizeCond);
		{
			try {
				var vp = ImGui.getMainViewport();
				if (vp != null) {
					var c = ImGui.ImGuiViewport_GetCenter(vp);
					if (c != null)
						ImGui.setNextWindowPos(ImGui.vec2(c.x - defaultW * 0.5, c.y - defaultH * 0.5), sizeCond);
				}
			} catch (_:Dynamic) {}
			forceLayoutIds.set(title, false);
		}
		var flags = CursorCaptureFix.windowFlags(ImGuiWindowFlags.MenuBar | ImGuiWindowFlags.NoCollapse);
		if (!dockable)
			flags |= ImGuiWindowFlags.NoDocking;
		UiChrome.pushCelShade();
		ImGui.pushStyleVar(ImGuiStyleVar.WindowTitleAlign, ImGui.vec2(0.5, 0.5));
		var shown = ImGui.begin(title, open, flags);
		ImGui.popStyleVar();
		return shown;
	}

	public static function end():Void {
		ImGui.end();
		UiChrome.popCelShade();
	}

	/** Theme-reactive title strip with drag area, centered caption, and close button. */
	static function drawTitleStrip(fullTitle:String, open:BoolRef):Void {
		ThemePalette.init();
		var theme = ThemePalette.current();
		var caption = fullTitle;
		var hash = fullTitle.indexOf("###");
		if (hash >= 0)
			caption = fullTitle.substr(0, hash);
		else {
			var hash2 = fullTitle.indexOf("##");
			if (hash2 >= 0)
				caption = fullTitle.substr(0, hash2);
		}

		var wp = ImGui.getWindowPos();
		var ws = ImGui.getWindowSize();
		var dl = ImGui.getWindowDrawList();

		var a = ThemePalette.panelAlpha();
		var topCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(
			Math.min(1, theme.titleBg.x * 1.25 + 0.04),
			Math.min(1, theme.titleBg.y * 1.25 + 0.04),
			Math.min(1, theme.titleBg.z * 1.2 + 0.04), a));
		var bottomCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(theme.titleBg.x, theme.titleBg.y, theme.titleBg.z, a));
		WindowEffects.gradientHeader(dl, wp.x, wp.y, ws.x, STRIP, topCol, bottomCol);

		var accentCol = ImGui.colorConvertFloat4ToU32(theme.accent);
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(wp.x, wp.y + STRIP), ImGui.vec2(wp.x + ws.x, wp.y + STRIP), accentCol, 1);

		// Drag grip leaves close + scrollbar gutter free on the right.
		var rightReserve:Single = CLOSE + 10 + SCROLL_GUTTER;
		ImGui.setCursorScreenPos(ImGui.vec2(wp.x, wp.y));
		ImGui.invisibleButton("##tw_title_drag", ImGui.vec2(ws.x - rightReserve, STRIP));
		if (ImGui.isItemActive() && ImGui.isMouseDragging(ImGuiMouseButton.Left)) {
			var delta = ImGui.getMouseDragDelta(ImGuiMouseButton.Left, 0);
			if (delta != null && (delta.x != 0 || delta.y != 0)) {
				var p = ImGui.getWindowPos();
				ImGui.setWindowPos(ImGui.vec2(p.x + delta.x, p.y + delta.y));
				ImGui.resetMouseDragDelta(ImGuiMouseButton.Left);
			}
		}

		var ts = ImGui.calcTextSize(caption);
		var titleX:Single = wp.x + (ws.x - ts.x) * 0.5;
		var titleY:Single = wp.y + (STRIP - ts.y) * 0.5;
		var textCol = ImGui.colorConvertFloat4ToU32(theme.text);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(titleX, titleY), textCol, caption);

		if (open != null) {
			// Place X left of scrollbar lane so root vertical scroll never covers hitbox.
			var closeX:Single = wp.x + ws.x - CLOSE - 6 - SCROLL_GUTTER;
			var closeY:Single = wp.y + (STRIP - CLOSE) * 0.5;
			ImGui.setCursorScreenPos(ImGui.vec2(closeX, closeY));
			if (ImGui.invisibleButton("##tw_close", ImGui.vec2(CLOSE, CLOSE)))
				open.set(false);
			var pad:Single = 3;
			var col = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.92, 0.78, 0.78, 0.95));
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(closeX + pad, closeY + pad), ImGui.vec2(closeX + CLOSE - pad, closeY + CLOSE - pad), col, 1.6);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(closeX + CLOSE - pad, closeY + pad), ImGui.vec2(closeX + pad, closeY + CLOSE - pad), col, 1.6);
		}

		// Advance layout past the custom title strip (one reservation only).
		ImGui.setCursorPos(ImGui.vec2(14, STRIP + 8));
	}

}
