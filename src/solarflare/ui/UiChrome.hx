package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiChildFlags;

/**
 * Shared visual language for SolarFlare tool windows: section headers and cel-shaded borders.
 */
class UiChrome {
	/** Large section title — center-aligned, stroked text, glow underline. */
	public static function sectionHeader(label:String):Void {
		ImGui.spacing();
		ThemePalette.init();
		var theme = ThemePalette.current();
		var font = ImGui.getFont();
		var base = ImGui.getFontSize();
		var bumped = false;
		if (font != null) {
			try {
				ImGui.pushFont(font, base * 1.85);
				bumped = true;
			} catch (_:Dynamic) {}
		}

		var ts = ImGui.calcTextSize(label);
		var avail = ImGui.getContentRegionAvail().x;
		var cursor = ImGui.getCursorScreenPos();
		var textX = cursor.x + Math.max(0, (avail - ts.x) * 0.5);
		var textY = cursor.y;
		var dl = ImGui.getWindowDrawList();

		var padX:Single = 14;
		var padY:Single = 3;
		WindowEffects.glassRect(dl, textX - padX, textY - padY, ts.x + padX * 2, ts.y + padY * 2,
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(theme.cellBg.x, theme.cellBg.y, theme.cellBg.z, 0.55)), 0.35);
		WindowEffects.spotlight(dl, textX + ts.x * 0.5, textY + ts.y * 0.5, Math.max(ts.x * 0.55, 28),
			ImGui.colorConvertFloat4ToU32(theme.accent), 0.12);

		var textCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(
			Math.min(1, theme.accent.x * 1.05 + 0.15),
			Math.min(1, theme.accent.y * 1.05 + 0.12),
			Math.min(1, theme.accent.z * 0.9 + 0.2), 1));
		EnhancedText.stroked(dl, ImGui.vec2(textX, textY), label, textCol, 0xCC000000, 1.0);

		if (bumped)
			ImGui.popFont();

		ImGui.dummy(ImGui.vec2(0, ts.y + 2));
		var p = ImGui.getCursorScreenPos();
		var w = ImGui.getContentRegionAvail().x;
		var accent = ImGui.colorConvertFloat4ToU32(theme.accent);
		var edge = ImGui.colorConvertFloat4ToU32(theme.border);
		var lineW = Math.min(w, Math.max(ts.x + 32, w * 0.5));
		var lx = p.x + (w - lineW) * 0.5;
		WindowEffects.glowLine(dl, lx, p.y + 1, lineW, accent, 2.0);
		WindowEffects.doubleLine(dl, lx, p.y + 1, lineW, accent, edge);
		ImGui.dummy(ImGui.vec2(0, 10));
	}

	/** Smaller subsection label — center-aligned with light stroke. */
	public static function subHeader(label:String):Void {
		ThemePalette.init();
		var theme = ThemePalette.current();
		var font = ImGui.getFont();
		var base = ImGui.getFontSize();
		var bumped = false;
		if (font != null) {
			try {
				ImGui.pushFont(font, base * 1.25);
				bumped = true;
			} catch (_:Dynamic) {}
		}
		var ts = ImGui.calcTextSize(label);
		var avail = ImGui.getContentRegionAvail().x;
		var cursor = ImGui.getCursorScreenPos();
		var textX = cursor.x + Math.max(0, (avail - ts.x) * 0.5);
		var dl = ImGui.getWindowDrawList();
		var textCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(theme.text.x, theme.text.y, theme.text.z, 0.95));
		EnhancedText.stroked(dl, ImGui.vec2(textX, cursor.y), label, textCol, 0x88000000, 0.75);
		if (bumped)
			ImGui.popFont();
		ImGui.dummy(ImGui.vec2(0, ts.y + 4));
	}

	/** Extra-prominent header for milestone / final-step panels. */
	public static function premiumHeader(label:String):Void {
		ImGui.spacing();
		ThemePalette.init();
		var theme = ThemePalette.current();
		var font = ImGui.getFont();
		var base = ImGui.getFontSize();
		var bumped = false;
		if (font != null) {
			try {
				ImGui.pushFont(font, base * 1.7);
				bumped = true;
			} catch (_:Dynamic) {}
		}
		var ts = ImGui.calcTextSize(label);
		var avail = ImGui.getContentRegionAvail().x;
		var cursor = ImGui.getCursorScreenPos();
		var textX = cursor.x + Math.max(0, (avail - ts.x) * 0.5);
		var dl = ImGui.getWindowDrawList();
		var accent = ImGui.colorConvertFloat4ToU32(theme.accent);

		WindowEffects.glassRect(dl, textX - 18, cursor.y - 4, ts.x + 36, ts.y + 8,
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(theme.titleBg.x, theme.titleBg.y, theme.titleBg.z, 0.7)), 0.45);
		WindowEffects.spotlight(dl, textX + ts.x * 0.5, cursor.y + ts.y * 0.5, ts.x * 0.7, accent, 0.22);

		var textCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 0.97, 0.88, 1));
		EnhancedText.glowStroke(dl, ImGui.vec2(textX, cursor.y), label, textCol, accent, 3.0);

		if (bumped)
			ImGui.popFont();
		ImGui.dummy(ImGui.vec2(0, ts.y + 4));
		WindowEffects.glowLine(dl, cursor.x, ImGui.getCursorScreenPos().y, avail, accent, 2.2);
		ImGui.dummy(ImGui.vec2(0, 10));
	}

	/** High-contrast accent button with clear label. */
	public static function accentButton(label:String, size:imgui.Vec2 = null):Bool {
		var theme = ThemePalette.current();
		ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 14);
		ImGui.pushStyleColor(ImGuiCol.Button, ImGui.vec4(theme.accent.x * 0.75, theme.accent.y * 0.55, theme.accent.z * 0.2, 1.0));
		ImGui.pushStyleColor(ImGuiCol.ButtonHovered, theme.accent);
		ImGui.pushStyleColor(ImGuiCol.ButtonActive, ImGui.vec4(theme.accent.x * 0.7, theme.accent.y * 0.7, theme.accent.z * 0.7, 1.0));
		ImGui.pushStyleColor(ImGuiCol.Text, ImGui.vec4(0.05, 0.04, 0.02, 1.0));
		ImGui.pushStyleVar(ImGuiStyleVar.FrameBorderSize, 2.0);
		ImGui.pushStyleColor(ImGuiCol.Border, ImGui.vec4(theme.accent.x, theme.accent.y, theme.accent.z, 0.95));
		var r = size != null ? ImGui.button(label, size) : ImGui.button(label);
		ImGui.popStyleColor(5);
		ImGui.popStyleVar(2);
		return r;
	}

	/** Secondary outlined button. */
	public static function ghostButton(label:String, size:imgui.Vec2 = null):Bool {
		var theme = ThemePalette.current();
		ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 12);
		ImGui.pushStyleColor(ImGuiCol.Button, theme.cellBg);
		ImGui.pushStyleColor(ImGuiCol.ButtonHovered, ImGui.vec4(theme.cellBg.x + 0.08, theme.cellBg.y + 0.08, theme.cellBg.z + 0.1, 1.0));
		ImGui.pushStyleColor(ImGuiCol.ButtonActive, theme.windowBg);
		ImGui.pushStyleColor(ImGuiCol.Text, theme.text);
		ImGui.pushStyleVar(ImGuiStyleVar.FrameBorderSize, 1.5);
		ImGui.pushStyleColor(ImGuiCol.Border, theme.border);
		var r = size != null ? ImGui.button(label, size) : ImGui.button(label);
		ImGui.popStyleColor(5);
		ImGui.popStyleVar(2);
		return r;
	}

	/**
	 * Push cel-shaded window/frame styling from the active theme.
	 * Squarer windows + rounder controls. Always pair with popCelShade().
	 */
	public static function pushCelShade():Int {
		ThemePalette.init();
		var theme = ThemePalette.current();
		var a = ThemePalette.panelAlpha();

		ImGui.pushStyleVar(ImGuiStyleVar.WindowRounding, 4);
		ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 12);
		ImGui.pushStyleVar(ImGuiStyleVar.ChildRounding, 6);
		ImGui.pushStyleVar(ImGuiStyleVar.GrabRounding, 10);
		ImGui.pushStyleVar(ImGuiStyleVar.TabRounding, 8);
		ImGui.pushStyleVar(ImGuiStyleVar.WindowBorderSize, 2.0);
		ImGui.pushStyleVar(ImGuiStyleVar.ChildBorderSize, 1.5);
		ImGui.pushStyleVar(ImGuiStyleVar.FrameBorderSize, 1.25);
		ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(14, 12));
		ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing, ImGui.vec2(10, 8));

		ImGui.pushStyleColor(ImGuiCol.Border, theme.border);
		ImGui.pushStyleColor(ImGuiCol.BorderShadow, ImGui.vec4(0.05, 0.05, 0.08, 0.85));
		ImGui.pushStyleColor(ImGuiCol.WindowBg, ImGui.vec4(theme.windowBg.x, theme.windowBg.y, theme.windowBg.z, a));
		ImGui.pushStyleColor(ImGuiCol.ChildBg, ImGui.vec4(theme.cellBg.x, theme.cellBg.y, theme.cellBg.z, a * 0.94));
		ImGui.pushStyleColor(ImGuiCol.TitleBg, theme.titleBg);
		ImGui.pushStyleColor(ImGuiCol.TitleBgActive, ImGui.vec4(theme.accent.x * 0.35, theme.accent.y * 0.28, theme.accent.z * 0.15, 1.0));
		ImGui.pushStyleColor(ImGuiCol.TitleBgCollapsed, theme.titleBg);
		ImGui.pushStyleColor(ImGuiCol.FrameBg, theme.cellBg);
		ImGui.pushStyleColor(ImGuiCol.Header, theme.cellBg);
		ImGui.pushStyleColor(ImGuiCol.HeaderHovered, ImGui.vec4(theme.accent.x, theme.accent.y, theme.accent.z, 0.45));
		ImGui.pushStyleColor(ImGuiCol.Text, theme.text);
		return 10;
	}

	public static function popCelShade(styleVars:Int = 10):Void {
		ImGui.popStyleColor(11);
		ImGui.popStyleVar(styleVars);
	}

	/** Cel-bordered child with soft edge glow. Always pairs begin/end. */
	public static function celChild(id:String, size:imgui.Vec2, draw:Void->Void):Void {
		var theme = ThemePalette.current();
		ImGui.pushStyleColor(ImGuiCol.Border, theme.border);
		ImGui.pushStyleColor(ImGuiCol.ChildBg, ImGui.vec4(theme.cellBg.x, theme.cellBg.y, theme.cellBg.z, 0.94));
		ImGui.beginChild(id, size, ImGuiChildFlags.Borders | ImGuiChildFlags.AlwaysUseWindowPadding);
		try {
			var wp = ImGui.getWindowPos();
			var ws = ImGui.getWindowSize();
			var dl = ImGui.getWindowDrawList();
			WindowEffects.dropShadow(dl, wp.x, wp.y, wp.x + ws.x, wp.y + ws.y, 5.0, 0.14);
			WindowEffects.glassPanel(dl, wp.x + 1, wp.y + 1, wp.x + ws.x - 1, wp.y + Math.min(28, ws.y * 0.12),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, 0.08)), 0.5);
			if (draw != null)
				draw();
		} catch (_:Dynamic) {}
		ImGui.endChild();
		ImGui.popStyleColor(2);
	}
}
