package solarflare.aura.signal;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiChildFlags;
import solarflare.ui.ThemePalette;
import solarflare.ui.UiChrome;
import solarflare.ui.UiScope;

/** Local rule-editor chrome: semantic green structure, neutral rectangular controls. */
class AuraRuleChrome {
	/** Use the preceding item's measured right edge, not the next line's reset cursor. */
	public static function sameLineIfFits(width:Single, gap:Single = 8):Void {
		var right = ImGui.getCursorScreenPos().x + ImGui.getContentRegionAvail().x;
		if (ImGui.getItemRectMax().x + gap + width <= right) ImGui.sameLine(0, gap);
	}
	public static function controls(body:Void->Void):Void {
		var t = ThemePalette.current();
		ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 2);
		ImGui.pushStyleVar(ImGuiStyleVar.FramePadding, ImGui.vec2(10, 6));
		ImGui.pushStyleVar(ImGuiStyleVar.ItemSpacing, ImGui.vec2(8, 8));
		ImGui.pushStyleColor(ImGuiCol.Border, t.border);
		ImGui.pushStyleColor(ImGuiCol.FrameBg, t.windowBg);
		ImGui.pushStyleColor(ImGuiCol.Button, t.cellBg);
		ImGui.pushStyleColor(ImGuiCol.ButtonHovered, t.border);
		ImGui.pushStyleColor(ImGuiCol.ButtonActive, t.titleBg);
		ImGui.pushStyleColor(ImGuiCol.Header, t.windowBg);
		ImGui.pushStyleColor(ImGuiCol.HeaderHovered, t.cellBg);
		ImGui.pushStyleColor(ImGuiCol.HeaderActive, t.titleBg);
		ImGui.pushStyleColor(ImGuiCol.CheckMark, ThemePalette.status(ThemePalette.STATUS_SUCCESS));
		// Property grids organize fields without boxing every row in the theme accent.
		ImGui.pushStyleColor(ImGuiCol.TableRowBg, t.windowBg);
		ImGui.pushStyleColor(ImGuiCol.TableRowBgAlt, t.windowBg);
		ImGui.pushStyleColor(ImGuiCol.TableBorderLight, t.windowBg);
		ImGui.pushStyleColor(ImGuiCol.TableBorderStrong, t.windowBg);
		var failed = false;
		var failure:Dynamic = null;
		try { body(); } catch (e:Dynamic) { failed = true; failure = e; }
		ImGui.popStyleColor(13);
		ImGui.popStyleVar(3);
		if (failed) throw failure;
	}

	public static function button(label:String, width:Single = 0, height:Single = 30):Bool {
		var t = ThemePalette.current();
		var w:Single = width > 0 ? width : ImGui.calcTextSize(UiChrome.displayLabel(label)).x + 24;
		ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 2);
		ImGui.pushStyleVar(ImGuiStyleVar.FrameBorderSize, 1);
		ImGui.pushStyleColor(ImGuiCol.Button, t.cellBg);
		ImGui.pushStyleColor(ImGuiCol.Border, t.border);
		var clicked = ImGui.button(label, ImGui.vec2(w, height));
		ImGui.popStyleColor(2);
		ImGui.popStyleVar(2);
		return clicked;
	}

	/** Colour and vector icons reinforce the action without relying on symbol font coverage. */
	public static function action(label:String, kind:String):Bool {
		var t = ThemePalette.current();
		var tint = ThemePalette.status(kind == "delete" ? ThemePalette.STATUS_DANGER
			: kind == "add" || kind == "group" ? ThemePalette.STATUS_SUCCESS : ThemePalette.STATUS_INFO);
		var prominent = kind == "group";
		var font = ImGui.getFont();
		if (prominent && font != null) ImGui.pushFont(font, ImGui.getFontSize() * 1.15);
		var caption = StringTools.startsWith(label, "+ ") ? label.substr(2) : label;
		var width:Single = ImGui.calcTextSize(UiChrome.displayLabel(caption)).x + 44;
		ImGui.pushStyleColor(ImGuiCol.Text, tint);
		ImGui.pushStyleColor(ImGuiCol.Border, tint);
		ImGui.pushStyleColor(ImGuiCol.Button, t.cellBg);
		ImGui.pushStyleColor(ImGuiCol.ButtonHovered, t.titleBg);
		ImGui.pushStyleVar(ImGuiStyleVar.FrameRounding, 2);
		ImGui.pushStyleVar(ImGuiStyleVar.FrameBorderSize, 1);
		var clicked = ImGui.button("   " + caption, ImGui.vec2(width, prominent ? 34 : 30));
		var p = ImGui.getItemRectMin();
		var size = ImGui.getItemRectSize();
		var x = p.x + 13;
		var y = p.y + size.y * 0.5;
		var dl = ImGui.getWindowDrawList();
		var color = ImGui.colorConvertFloat4ToU32(tint);
		if (kind == "delete") {
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x - 4, y - 4), ImGui.vec2(x + 4, y + 4), color, 2);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x + 4, y - 4), ImGui.vec2(x - 4, y + 4), color, 2);
		} else if (kind == "up" || kind == "down") {
			var direction = kind == "up" ? -1 : 1;
			ImGui.ImDrawList_AddTriangleFilled(dl, ImGui.vec2(x, y + direction * 5),
				ImGui.vec2(x - 4, y - direction * 3), ImGui.vec2(x + 4, y - direction * 3), color);
		} else {
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x - 4, y), ImGui.vec2(x + 4, y), color, 2);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x, y - 4), ImGui.vec2(x, y + 4), color, 2);
		}
		ImGui.popStyleVar(2);
		ImGui.popStyleColor(4);
		if (prominent && font != null) ImGui.popFont();
		return clicked;
	}

	public static function card(id:String, main:Bool, body:Void->Void):Void {
		var t = ThemePalette.current();
		ImGui.pushStyleColor(ImGuiCol.Border, ThemePalette.status(ThemePalette.STATUS_SUCCESS));
		ImGui.pushStyleColor(ImGuiCol.ChildBg, main ? t.cellBg : t.windowBg);
		ImGui.pushStyleVar(ImGuiStyleVar.ChildBorderSize, main ? 2 : 1);
		ImGui.pushStyleVar(ImGuiStyleVar.ChildRounding, 3);
		ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(12, main ? 14 : 10));
		UiScope.child(id, ImGui.vec2(0, 0), body,
			ImGuiChildFlags.Borders | ImGuiChildFlags.AutoResizeY | ImGuiChildFlags.AlwaysUseWindowPadding);
		ImGui.popStyleVar(3);
		ImGui.popStyleColor(2);
	}

	/** A title and a numbered identifier, with larger type reserved for the main trigger. */
	public static function conditionHeader(index:Int, main:Bool):Void {
		var green = ThemePalette.status(ThemePalette.STATUS_SUCCESS);
		var p = ImGui.getCursorScreenPos();
		var width = ImGui.getContentRegionAvail().x;
		var height:Single = main ? 42 : 28;
		var label = "CONDITION " + (index + 1);
		var number = main ? "*Main Trigger" : "";
		var font = ImGui.getFont();
		if (font != null && main) ImGui.pushFont(font, ImGui.getFontSize() * 1.15);
		ImGui.textColored(green, label);
		if (font != null && main) ImGui.popFont();
		// Number anchors the right edge; the submitted band owns all drawn geometry.
		var dl = ImGui.getWindowDrawList();
		var text = ImGui.calcTextSize(number);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(p.x + width - text.x - 4, p.y + 3),
			ImGui.colorConvertFloat4ToU32(ThemePalette.status(ThemePalette.STATUS_DANGER)), number);
		ImGui.dummy(ImGui.vec2(width, Math.max(1, height - ImGui.getTextLineHeightWithSpacing())));
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(p.x, p.y + height - 2),
			ImGui.vec2(p.x + width, p.y + height - 2), ImGui.colorConvertFloat4ToU32(green), main ? 2 : 1);
	}
}
