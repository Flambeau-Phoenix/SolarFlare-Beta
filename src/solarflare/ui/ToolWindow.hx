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
 * Custom sun title strip (theme-reactive); builders open undocked at full stage size.
 */
class ToolWindow {
	static var lastOpen:Map<String, Bool> = new Map();
	static var forceLayoutIds:Map<String, Bool> = new Map();
	static inline var STRIP:Single = 22;
	static inline var SUN:Single = 14;
	static inline var CLOSE:Single = 14;

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
			defaultH:Single = 640, dockable:Bool = false):Bool {
		// Keep native menu/title interaction; decorate the title with the shared sun icon.
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
		if (force) {
			try {
				var vp = ImGui.getMainViewport();
				if (vp != null) {
					var c = ImGui.ImGuiViewport_GetCenter(vp);
					if (c != null)
						ImGui.setNextWindowPos(ImGui.vec2(c.x - defaultW * 0.5, c.y - defaultH * 0.5), ImGuiCond.Always);
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
		if (shown) {
			var wp = ImGui.getWindowPos();
			var ws = ImGui.getWindowSize();
			var titleH = ImGui.getFrameHeight();
			var dl = ImGui.getWindowDrawList();
			// Begin clips content below the title; temporarily include the native title region.
			ImGui.ImDrawList_PushClipRect(dl, wp, ImGui.vec2(wp.x + ws.x, wp.y + titleH), false);
			blitSun(dl, wp.x + 6, wp.y + (titleH - SUN) * 0.5);
			ImGui.ImDrawList_PopClipRect(dl);
		}
		return shown;
	}

	public static function end():Void {
		ImGui.end();
		UiChrome.popCelShade();
	}

	/** Theme-reactive title strip with chrome-sun grip (drag) + centered caption + close. */
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

		WindowEffects.dropShadow(dl, wp.x, wp.y, wp.x + ws.x, wp.y + ws.y, 8.0, 0.2);

		var a = ThemePalette.panelAlpha();
		var topCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(
			Math.min(1, theme.titleBg.x * 1.25 + 0.04),
			Math.min(1, theme.titleBg.y * 1.25 + 0.04),
			Math.min(1, theme.titleBg.z * 1.2 + 0.04), a));
		var bottomCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(theme.titleBg.x, theme.titleBg.y, theme.titleBg.z, a));
		WindowEffects.gradientHeader(dl, wp.x, wp.y, ws.x, STRIP, topCol, bottomCol);

		var accentCol = ImGui.colorConvertFloat4ToU32(theme.accent);
		WindowEffects.glowLine(dl, wp.x + 6, wp.y + STRIP - 1, ws.x - 12, accentCol, 1.6);
		WindowEffects.spotlight(dl, wp.x + 6 + SUN * 0.5, wp.y + STRIP * 0.5, 18, accentCol, 0.18);

		var sunX:Single = wp.x + 6;
		var sunY:Single = wp.y + (STRIP - SUN) * 0.5;
		blitSun(dl, sunX, sunY);

		// Invisible drag grip on the whole title strip (sun is the visual affordance).
		ImGui.setCursorScreenPos(ImGui.vec2(wp.x, wp.y));
		ImGui.invisibleButton("##tw_title_drag", ImGui.vec2(ws.x - CLOSE - 10, STRIP));
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
		EnhancedText.glowStroke(dl, ImGui.vec2(titleX, titleY), caption, textCol, accentCol, 2.5);

		if (open != null) {
			var closeX:Single = wp.x + ws.x - CLOSE - 6;
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

	static function blitSun(dl:Dynamic, px:Single, py:Single):Void {
		var tex = GameIcons.get(HudChrome.SUN_ID);
		if (tex == 0)
			tex = GameIcons.retry(HudChrome.SUN_ID);
		if (!GameIcons.draw(dl, tex, px, py, SUN)) {
			var cx:Single = px + SUN * 0.5;
			var cy:Single = py + SUN * 0.5;
			var col = ImGui.colorConvertFloat4ToU32(ThemePalette.current().accent);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), 2.8, col, 12);
			for (i in 0...8) {
				var a = i * Math.PI / 4;
				ImGui.ImDrawList_AddLine(dl,
					ImGui.vec2(cx + Math.cos(a) * 4.2, cy + Math.sin(a) * 4.2),
					ImGui.vec2(cx + Math.cos(a) * 6.4, cy + Math.sin(a) * 6.4), col, 1.35);
			}
		}
	}
}
