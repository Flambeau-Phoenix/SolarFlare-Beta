package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiChildFlags;

/**
 * Shared visual language for SolarFlare tool windows: section headers and cel-shaded borders.
 */
class UiChrome {
	/** Plain, centered headings shared by builders. */
	public static function sectionHeader(label:String):Void heading(label, 1.4);
	public static function subHeader(label:String):Void heading(label, 1.15);
	public static function premiumHeader(label:String):Void heading(label, 1.4);

	public static function heading(label:String, scale:Single = 1.35):Void {
		var font = ImGui.getFont();
		if (font != null) ImGui.pushFont(font, ImGui.getFontSize() * scale);
		var x = ImGui.getCursorPosX();
		var width = ImGui.getContentRegionAvail().x;
		ImGui.setCursorPosX(x + Math.max(0, (width - ImGui.calcTextSize(label).x) * 0.5));
		ImGui.text(label);
		ImGui.setCursorPosX(x);
		if (font != null) ImGui.popFont();
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

	/** Bordered child. Always pairs begin/end. */
	public static function celChild(id:String, size:imgui.Vec2, draw:Void->Void):Void {
		var theme = ThemePalette.current();
		ImGui.pushStyleColor(ImGuiCol.Border, theme.border);
		ImGui.pushStyleColor(ImGuiCol.ChildBg, ImGui.vec4(theme.cellBg.x, theme.cellBg.y, theme.cellBg.z, 0.94));
		var shown = ImGui.beginChild(id, size, ImGuiChildFlags.Borders | ImGuiChildFlags.AlwaysUseWindowPadding);
		try {
			if (shown && draw != null)
				draw();
		} catch (e:Dynamic) {
			trace('SolarFlare cel child $id: $e');
		}
		ImGui.endChild();
		ImGui.popStyleColor(2);
	}
}
