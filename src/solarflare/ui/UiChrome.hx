package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiChildFlags;
import imgui.Structs.ImVec2;

/**
 * Shared visual language for SolarFlare tool windows: section headers and cel-shaded borders.
 */
class UiChrome {
	/** Structured section bands shared by builders. */
	public static function sectionHeader(label:String):Void sectionBand(label, 34, true);
	public static function subHeader(label:String):Void sectionBand(label, 28, false);
	public static function premiumHeader(label:String):Void sectionBand(label, 38, true);

	/** ImGui ID stays after ## / ###; visible caption is the prefix only. */
	public static function displayLabel(label:String):String {
		if (label == null || label.length == 0)
			return "";
		var triple = label.indexOf("###");
		if (triple >= 0)
			return label.substr(0, triple);
		var hash = label.indexOf("##");
		if (hash >= 0)
			return label.substr(0, hash);
		return label;
	}

	static function sectionBand(label:String, height:Single, strong:Bool):Void {
		var theme = ThemePalette.current();
		var caption = displayLabel(label);
		var pos = ImGui.getCursorScreenPos();
		var width = Math.max(1, ImGui.getContentRegionAvail().x);
		ImGui.dummy(ImGui.vec2(width, height));
		var dl = ImGui.getWindowDrawList();
		var max = ImGui.vec2(pos.x + width, pos.y + height);
		var bg = ImGui.colorConvertFloat4ToU32(ImGui.vec4(
			theme.cellBg.x, theme.cellBg.y, theme.cellBg.z, strong ? 0.82 : 0.52));
		var inner = ImGui.colorConvertFloat4ToU32(ImGui.vec4(
			theme.windowBg.x, theme.windowBg.y, theme.windowBg.z, 0.42));
		var accent = ImGui.colorConvertFloat4ToU32(theme.accent);
		ImGui.ImDrawList_AddRectFilled(dl, pos, max, bg, strong ? 8 : 6);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(pos.x + 1, pos.y + 1),
			ImGui.vec2(max.x - 1, pos.y + height * 0.48), inner, strong ? 7 : 5);
		ImGui.ImDrawList_AddRectFilled(dl, pos,
			ImGui.vec2(pos.x + (strong ? 5 : 3), max.y), accent, strong ? 8 : 6);
		ImGui.ImDrawList_AddRect(dl, pos, max,
			ImGui.colorConvertFloat4ToU32(theme.border), strong ? 8 : 6, strong ? 1.4 : 1);
		var ts = ImGui.calcTextSize(caption);
		ImGui.ImDrawList_AddText_Vec2(dl,
			ImGui.vec2(pos.x + (strong ? 16 : 12), pos.y + (height - ts.y) * 0.5),
			ImGui.colorConvertFloat4ToU32(theme.text), caption);
	}

	public static function heading(label:String, scale:Single = 1.35):Void {
		var caption = displayLabel(label);
		var font = ImGui.getFont();
		if (font != null) ImGui.pushFont(font, ImGui.getFontSize() * scale);
		var x = ImGui.getCursorPosX();
		var width = ImGui.getContentRegionAvail().x;
		ImGui.setCursorPosX(x + Math.max(0, (width - ImGui.calcTextSize(caption).x) * 0.5));
		ImGui.text(caption);
		ImGui.setCursorPosX(x);
		if (font != null) ImGui.popFont();
	}

	/** High-contrast accent button with clear label. */
	public static function accentButton(label:String, size:ImVec2 = null):Bool {
		return gradientButton(label, size);
	}

	/** Layered accent action with a real gradient, shadow, and generous hit area. */
	public static function gradientButton(label:String, size:ImVec2 = null):Bool {
		var theme = ThemePalette.current();
		var caption = displayLabel(label);
		var textSize = ImGui.calcTextSize(caption);
		var actual = size != null ? size : ImGui.vec2(textSize.x + 28, 34);
		if (actual.x <= 0)
			actual.x = ImGui.getContentRegionAvail().x;
		if (actual.y < 30)
			actual.y = 30;
		// Keep full label on the invisible hit target so ## IDs stay unique.
		var clicked = ImGui.invisibleButton(label, actual);
		var hovered = ImGui.isItemHovered();
		var active = ImGui.isItemActive();
		var min = ImGui.getItemRectMin();
		var max = ImGui.getItemRectMax();
		var dl = ImGui.getWindowDrawList();
		var rounding:Single = Math.min(12, actual.y * 0.35);
		var lift:Single = active ? 1 : 0;
		var baseScale:Single = active ? 0.68 : (hovered ? 0.90 : 0.76);
		var base = ImGui.colorConvertFloat4ToU32(ImGui.vec4(
			theme.accent.x * baseScale, theme.accent.y * baseScale,
			theme.accent.z * baseScale, 1));
		var top = ImGui.colorConvertFloat4ToU32(ImGui.vec4(
			Math.min(1, theme.accent.x * 1.18 + 0.06),
			Math.min(1, theme.accent.y * 1.12 + 0.04),
			Math.min(1, theme.accent.z * 1.08 + 0.02), 0.92));
		var bottom = ImGui.colorConvertFloat4ToU32(ImGui.vec4(
			theme.accent.x * 0.48, theme.accent.y * 0.42,
			theme.accent.z * 0.38, 0.98));
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(min.x + 2, min.y + 4),
			ImGui.vec2(max.x + 2, max.y + 4), 0x55000000, rounding);
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(min.x, min.y + lift),
			ImGui.vec2(max.x, max.y + lift), base, rounding);
		WindowEffects.gradientHeader(dl, min.x + 2, min.y + 2 + lift,
			Math.max(1, actual.x - 4), Math.max(1, actual.y - 4), top, bottom);
		// Prominent black vector outline (outer plate + hard rim), then gold stroke inside.
		var y0:Single = min.y + lift;
		var y1:Single = max.y + lift;
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(min.x - 1.5, y0 - 1.5),
			ImGui.vec2(max.x + 1.5, y1 + 1.5), 0xFF000000, rounding + 1.5, hovered ? 4.2 : 3.6, 0);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(min.x, y0),
			ImGui.vec2(max.x, y1), 0xFF000000, rounding, hovered ? 2.4 : 2.0, 0);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(min.x + 2.2, y0 + 2.2),
			ImGui.vec2(max.x - 2.2, y1 - 2.2),
			ImGui.colorConvertFloat4ToU32(theme.accent), rounding - 1, hovered ? 1.6 : 1.35, 0);
		var textCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.06, 0.05, 0.04, 1));
		ImGui.ImDrawList_AddText_Vec2(dl,
			ImGui.vec2(min.x + (actual.x - textSize.x) * 0.5,
				min.y + lift + (actual.y - textSize.y) * 0.5), textCol, caption);
		return clicked;
	}

	/** Secondary outlined button. */
	public static function ghostButton(label:String, size:ImVec2 = null):Bool {
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

	/** Shared selected/unselected navigation control. */
	public static function navButton(label:String, selected:Bool,
			size:ImVec2 = null):Bool {
		return selected ? accentButton(label, size) : ghostButton(label, size);
	}

	/**
	 * Compact chrome toggle chip (Lock / Transparent / etc).
	 * Flips `state` on click; returns true when the value changed.
	 */
	public static function toggleChip(label:String, state:imgui.ref.BoolRef,
			size:ImVec2 = null):Bool {
		if (state == null)
			return false;
		var on = state.get();
		var chipSize = size != null ? size : ImGui.vec2(0, 28);
		if (chipSize.y < 26)
			chipSize.y = 26;
		if (navButton(label, on, chipSize)) {
			state.set(!on);
			return true;
		}
		return false;
	}

	/**
	 * Positive visibility control for a stored `hidden` flag.
	 * Checked / selected means Showing (overlay visible). Persistence stays on `hidden`.
	 */
	public static function showingChip(label:String, hidden:imgui.ref.BoolRef,
			size:ImVec2 = null):Bool {
		if (hidden == null)
			return false;
		var showing = !hidden.get();
		var chipSize = size != null ? size : ImGui.vec2(0, 28);
		if (chipSize.y < 26)
			chipSize.y = 26;
		if (navButton(label, showing, chipSize)) {
			hidden.set(showing);
			return true;
		}
		return false;
	}

	/** Checkbox form of showingChip — label should read Showing/Enabled, not Hide. */
	static var showingMirrors:Map<String, imgui.ref.BoolRef> = new Map();
	public static function showingCheckbox(label:String, hidden:imgui.ref.BoolRef):Bool {
		if (hidden == null)
			return false;
		var mirror = showingMirrors.get(label);
		if (mirror == null) {
			mirror = new imgui.ref.BoolRef(false);
			showingMirrors.set(label, mirror);
		}
		mirror.set(!hidden.get());
		if (ImGui.checkbox(label, mirror)) {
			hidden.set(!mirror.get());
			return true;
		}
		return false;
	}

	/**
	 * Standardized toggle tile for boolean on/off states (card background, 1px border, 12x12 checkbox indicator).
	 * Strictly for boolean state toggles, never action buttons.
	 */
	public static function toggleTile(
		id:String,
		label:String,
		checked:Bool,
		width:Single = 108.0,
		height:Single = 32.0,
		mixed:Bool = false
	):Bool {
		var clicked = false;
		var p0 = ImGui.getCursorScreenPos();
		var p1 = ImGui.vec2(p0.x + width, p0.y + height);

		// Invisible button handles hover and click interactions
		if (ImGui.invisibleButton(id, ImGui.vec2(width, height))) {
			clicked = true;
		}

		var hovered = ImGui.isItemHovered();
		var active = ImGui.isItemActive();

		// Theme colors: Accent tint when ON, neutral when OFF
		var bgColor = checked 
			? (hovered ? 0xFF2A5070 : 0xFF1E3A52) 
			: (hovered ? 0xFF2B2E33 : 0xFF1B1D21);
		var borderColor = checked ? 0xFF4A90E2 : (hovered ? 0xFF555B66 : 0xFF353940);
		var checkColor = checked ? 0xFF50E3C2 : (mixed ? 0xFFE5A93C : 0x00000000);

		var dl = ImGui.getWindowDrawList();

		// Card background + 1px border with 4px rounding
		ImGui.ImDrawList_AddRectFilled(dl, p0, p1, bgColor, 4.0);
		ImGui.ImDrawList_AddRect(dl, p0, p1, borderColor, 4.0, 1.0);

		// Explicit 12x12 checkbox indicator box
		var boxP0 = ImGui.vec2(p0.x + 8.0, p0.y + (height * 0.5) - 6.0);
		var boxP1 = ImGui.vec2(boxP0.x + 12.0, boxP0.y + 12.0);
		ImGui.ImDrawList_AddRect(dl, boxP0, boxP1, 0xFF888E99, 2.0, 1.0);

		if (checked) {
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(boxP0.x + 2.0, boxP0.y + 2.0), ImGui.vec2(boxP1.x - 2.0, boxP1.y - 2.0), checkColor, 1.0);
		} else if (mixed) {
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(boxP0.x + 2.0, boxP0.y + 6.0), ImGui.vec2(boxP1.x - 2.0, boxP0.y + 6.0), checkColor, 2.0);
		}

		// Label
		var textPos = ImGui.vec2(boxP1.x + 8.0, p0.y + (height * 0.5) - 7.0);
		ImGui.ImDrawList_AddText_Vec2(dl, textPos, 0xFFE0E0E0, label);

		return clicked;
	}

	/** Toggle tile helper for a BoolRef state. */
	public static function toggleTileRef(id:String, label:String, ref:imgui.ref.BoolRef, width:Single = 108.0, height:Single = 32.0):Bool {
		if (ref == null)
			return false;
		if (toggleTile(id, label, ref.get(), width, height)) {
			ref.set(!ref.get());
			return true;
		}
		return false;
	}

	/** Toggle tile helper for a hidden flag (checked = showing = !hidden.get()). */
	public static function showingTile(id:String, label:String, hidden:imgui.ref.BoolRef, width:Single = 108.0, height:Single = 32.0):Bool {
		if (hidden == null)
			return false;
		var showing = !hidden.get();
		if (toggleTile(id, label, showing, width, height)) {
			hidden.set(showing);
			return true;
		}
		return false;
	}

	/** Centered section band for structural hierarchy (builders / hub panes). */
	public static function centeredHeader(label:String, height:Single = 36):Void {
		var theme = ThemePalette.current();
		var pos = ImGui.getCursorScreenPos();
		var width = Math.max(1, ImGui.getContentRegionAvail().x);
		ImGui.dummy(ImGui.vec2(width, height));
		var dl = ImGui.getWindowDrawList();
		var max = ImGui.vec2(pos.x + width, pos.y + height);
		var bg = ImGui.colorConvertFloat4ToU32(ImGui.vec4(
			theme.cellBg.x, theme.cellBg.y, theme.cellBg.z, 0.78));
		var accent = ImGui.colorConvertFloat4ToU32(theme.accent);
		ImGui.ImDrawList_AddRectFilled(dl, pos, max, bg, 8);
		ImGui.ImDrawList_AddRect(dl, pos, max,
			ImGui.colorConvertFloat4ToU32(theme.border), 8, 1.5);
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(pos.x + 10, pos.y + height - 2),
			ImGui.vec2(pos.x + width - 10, pos.y + height - 2), accent, 2);
		var font = ImGui.getFont();
		var scale:Single = 1.22;
		if (font != null)
			ImGui.pushFont(font, ImGui.getFontSize() * scale);
		var caption = displayLabel(label);
		var ts = ImGui.calcTextSize(caption);
		ImGui.ImDrawList_AddText_Vec2(dl,
			ImGui.vec2(pos.x + (width - ts.x) * 0.5, pos.y + (height - ts.y) * 0.5),
			ImGui.colorConvertFloat4ToU32(theme.text), caption);
		if (font != null)
			ImGui.popFont();
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
		ImGui.pushStyleColor(ImGuiCol.MenuBarBg, ImGui.vec4(theme.titleBg.x, theme.titleBg.y, theme.titleBg.z, a));
		ImGui.pushStyleColor(ImGuiCol.FrameBg, theme.cellBg);
		ImGui.pushStyleColor(ImGuiCol.Header, theme.cellBg);
		ImGui.pushStyleColor(ImGuiCol.HeaderHovered, ImGui.vec4(theme.accent.x, theme.accent.y, theme.accent.z, 0.45));
		ImGui.pushStyleColor(ImGuiCol.Text, theme.text);
		return 10;
	}

	public static function popCelShade(styleVars:Int = 10):Void {
		ImGui.popStyleColor(12);
		ImGui.popStyleVar(styleVars);
	}

	/** Bordered child. Always pairs begin/end.
	 *  Optional windowFlags (e.g. NoScrollbar) so only inner UiScope.child scrolls. */
	public static function celChild(id:String, size:ImVec2, draw:Void->Void,
			windowFlags:Int = 0):Void {
		var theme = ThemePalette.current();
		var pushed = 0;
		var pushedVars = 0;
		var failed = false;
		var failure:Dynamic = null;
		try {
			var pos = ImGui.getCursorScreenPos();
			var avail = ImGui.getContentRegionAvail();
			var width = size.x <= 0 ? avail.x : size.x;
			var height = size.y <= 0 ? avail.y : size.y;
			var dl = ImGui.getWindowDrawList();
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(pos.x + 3, pos.y + 5),
				ImGui.vec2(pos.x + width + 3, pos.y + height + 5), 0x44000000, 10);
			ImGui.pushStyleVar(ImGuiStyleVar.ChildRounding, 10);
			pushedVars++;
			ImGui.pushStyleVar(ImGuiStyleVar.ChildBorderSize, 1.5);
			pushedVars++;
			ImGui.pushStyleColor(ImGuiCol.Border, theme.border);
			pushed++;
			ImGui.pushStyleColor(ImGuiCol.ChildBg,
				ImGui.vec4(theme.cellBg.x, theme.cellBg.y, theme.cellBg.z, 0.94));
			pushed++;
			UiScope.child(id, size, draw,
				ImGuiChildFlags.Borders | ImGuiChildFlags.AlwaysUseWindowPadding,
				windowFlags);
		} catch (e:Dynamic) {
			failed = true;
			failure = e;
		}
		if (pushed > 0)
			ImGui.popStyleColor(pushed);
		if (pushedVars > 0)
			ImGui.popStyleVar(pushedVars);
		if (failed)
			UiScope.report("cel child", id, failure);
	}
}
