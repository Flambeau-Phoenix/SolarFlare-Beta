package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Structs.ImVec4;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import hl.Bytes;

/**
 * Layer-2 theme palette selection shared by the SolarFlare UI.
 * Integrates 6 curated presets plus an editable Custom theme.
 * All color buffers are persistent `hl.Bytes` instances to ensure zero memory
 * allocations during `draw()`.
 */
enum abstract ThemeKind(String) from String to String {
	var PurpleGold = "purple_gold";
	var ObsidianEmber = "obsidian_ember";
	var VoidsteelBlue = "voidsteel_blue";
	var AshGold = "ash_gold";
	var SolarflareCrimson = "solarflare_crimson";
	var MoonlitSlate = "moonlit_slate";
	var HighContrast = "high_contrast";
	var Custom = "custom";
}

class ThemeColors {
	public var windowBg:ImVec4;
	public var cellBg:ImVec4;
	public var titleBg:ImVec4;
	public var border:ImVec4;
	public var accent:ImVec4;
	public var text:ImVec4;
	public var textDisabled:ImVec4;
	public var dimOverlay:ImVec4;

	public function new(windowBg:ImVec4, cellBg:ImVec4, titleBg:ImVec4, border:ImVec4, accent:ImVec4, text:ImVec4, textDisabled:ImVec4, dimOverlay:ImVec4) {
		this.windowBg = windowBg;
		this.cellBg = cellBg;
		this.titleBg = titleBg;
		this.border = border;
		this.accent = accent;
		this.text = text;
		this.textDisabled = textDisabled;
		this.dimOverlay = dimOverlay;
	}

	public function copy():ThemeColors {
		return new ThemeColors(
			ImGui.vec4(windowBg.x, windowBg.y, windowBg.z, windowBg.w),
			ImGui.vec4(cellBg.x, cellBg.y, cellBg.z, cellBg.w),
			ImGui.vec4(titleBg.x, titleBg.y, titleBg.z, titleBg.w),
			ImGui.vec4(border.x, border.y, border.z, border.w),
			ImGui.vec4(accent.x, accent.y, accent.z, accent.w),
			ImGui.vec4(text.x, text.y, text.z, text.w),
			ImGui.vec4(textDisabled.x, textDisabled.y, textDisabled.z, textDisabled.w),
			ImGui.vec4(dimOverlay.x, dimOverlay.y, dimOverlay.z, dimOverlay.w)
		);
	}
}

class ThemePalette {
	public static var windowOpacity:FloatRef;
	public static inline function panelAlpha():Single {
		init();
		return windowOpacity.get();
	}

	static var PURPLE_GOLD:ThemeColors;
	static var OBSIDIAN_EMBER:ThemeColors;
	static var VOIDSTEEL_BLUE:ThemeColors;
	static var ASH_GOLD:ThemeColors;
	static var SOLARFLARE_CRIMSON:ThemeColors;
	static var MOONLIT_SLATE:ThemeColors;
	static var HIGH_CONTRAST:ThemeColors;
	static var CUSTOM:ThemeColors;
	static var panelBg:ImVec4;
	static var presets:Array<String>;

	/** Persistent hl.Bytes float[4] buffers for ImGui.colorEdit4() — zero allocation in draw() */
	public static var customBufWindowBg:Bytes;
	public static var customBufCellBg:Bytes;
	public static var customBufTitleBg:Bytes;
	public static var customBufBorder:Bytes;
	public static var customBufAccent:Bytes;
	public static var customBufText:Bytes;
	public static var customBufTextDisabled:Bytes;
	public static var customBufDimOverlay:Bytes;

	static var previewDummyCheck:BoolRef;
	static var initialized = false;
	static inline var COLOR_COUNT = 28;

	public static function init():Void {
		if (initialized)
			return;

		// Native-backed ImGui refs and color buffers are initialized explicitly
		// after ModEntry.main() has begun. Never construct them as static fields.
		windowOpacity = new FloatRef(1);
		previewDummyCheck = new BoolRef(true);
		panelBg = ImGui.vec4(0, 0, 0, 1);
		presets = [
			ThemeKind.PurpleGold, ThemeKind.ObsidianEmber, ThemeKind.VoidsteelBlue,
			ThemeKind.AshGold, ThemeKind.SolarflareCrimson, ThemeKind.MoonlitSlate,
			ThemeKind.HighContrast, ThemeKind.Custom
		];

		PURPLE_GOLD = new ThemeColors(
			ImGui.vec4(0.055, 0.043, 0.092, 1),
			ImGui.vec4(0.105, 0.075, 0.180, 1),
			ImGui.vec4(0.160, 0.090, 0.300, 0.98),
			ImGui.vec4(0.500, 0.380, 0.720, 0.72),
			ImGui.vec4(0.930, 0.700, 0.220, 1),
			ImGui.vec4(0.960, 0.940, 1.000, 1),
			ImGui.vec4(0.580, 0.540, 0.680, 1),
			ImGui.vec4(0.025, 0.018, 0.050, 0.62)
		);

		OBSIDIAN_EMBER = new ThemeColors(
			ImGui.vec4(0.07, 0.08, 0.10, 1),
			ImGui.vec4(0.14, 0.15, 0.19, 1),
			ImGui.vec4(0.09, 0.10, 0.13, 0.95),
			ImGui.vec4(0.24, 0.26, 0.31, 1),
			ImGui.vec4(0.93, 0.56, 0.25, 1),
			ImGui.vec4(0.91, 0.91, 0.94, 1),
			ImGui.vec4(0.49, 0.52, 0.57, 1),
			ImGui.vec4(0, 0, 0, 0.50)
		);

		VOIDSTEEL_BLUE = new ThemeColors(
			ImGui.vec4(0.06, 0.07, 0.11, 1),
			ImGui.vec4(0.12, 0.16, 0.22, 1),
			ImGui.vec4(0.08, 0.10, 0.14, 0.95),
			ImGui.vec4(0.22, 0.27, 0.37, 1),
			ImGui.vec4(0.37, 0.68, 0.93, 1),
			ImGui.vec4(0.91, 0.93, 0.96, 1),
			ImGui.vec4(0.49, 0.56, 0.64, 1),
			ImGui.vec4(0, 0, 0, 0.50)
		);

		ASH_GOLD = new ThemeColors(
			ImGui.vec4(0.09, 0.09, 0.09, 1),
			ImGui.vec4(0.17, 0.15, 0.13, 1),
			ImGui.vec4(0.12, 0.11, 0.09, 0.95),
			ImGui.vec4(0.35, 0.31, 0.23, 1),
			ImGui.vec4(0.83, 0.69, 0.22, 1),
			ImGui.vec4(0.93, 0.92, 0.87, 1),
			ImGui.vec4(0.59, 0.56, 0.49, 1),
			ImGui.vec4(0, 0, 0, 0.50)
		);

		SOLARFLARE_CRIMSON = new ThemeColors(
			ImGui.vec4(0.09, 0.06, 0.07, 1),
			ImGui.vec4(0.19, 0.11, 0.13, 1),
			ImGui.vec4(0.12, 0.07, 0.08, 0.95),
			ImGui.vec4(0.35, 0.20, 0.24, 1),
			ImGui.vec4(0.91, 0.36, 0.41, 1),
			ImGui.vec4(0.94, 0.91, 0.92, 1),
			ImGui.vec4(0.59, 0.49, 0.52, 1),
			ImGui.vec4(0, 0, 0, 0.50)
		);

		MOONLIT_SLATE = new ThemeColors(
			ImGui.vec4(0.10, 0.11, 0.14, 1),
			ImGui.vec4(0.16, 0.19, 0.24, 1),
			ImGui.vec4(0.12, 0.14, 0.17, 0.95),
			ImGui.vec4(0.27, 0.31, 0.36, 1),
			ImGui.vec4(0.54, 0.66, 0.85, 1),
			ImGui.vec4(0.91, 0.92, 0.94, 1),
			ImGui.vec4(0.56, 0.59, 0.64, 1),
			ImGui.vec4(0, 0, 0, 0.50)
		);

		HIGH_CONTRAST = new ThemeColors(
			ImGui.vec4(0.03, 0.03, 0.04, 1),
			ImGui.vec4(0.12, 0.12, 0.14, 1),
			ImGui.vec4(0.05, 0.05, 0.06, 0.98),
			ImGui.vec4(0.44, 0.44, 0.48, 1),
			ImGui.vec4(1.0, 0.72, 0.23, 1),
			ImGui.vec4(1.0, 1.0, 1.0, 1),
			ImGui.vec4(0.72, 0.72, 0.76, 1),
			ImGui.vec4(0, 0, 0, 0.65)
		);

		CUSTOM = PURPLE_GOLD.copy();

		customBufWindowBg = makeBytes(CUSTOM.windowBg);
		customBufCellBg = makeBytes(CUSTOM.cellBg);
		customBufTitleBg = makeBytes(CUSTOM.titleBg);
		customBufBorder = makeBytes(CUSTOM.border);
		customBufAccent = makeBytes(CUSTOM.accent);
		customBufText = makeBytes(CUSTOM.text);
		customBufTextDisabled = makeBytes(CUSTOM.textDisabled);
		customBufDimOverlay = makeBytes(CUSTOM.dimOverlay);

		initialized = true;
	}

	static function makeBytes(c:ImVec4):Bytes {
		var b = new Bytes(16);
		syncVecToBytes(c, b);
		return b;
	}

	public static function syncVecToBytes(c:ImVec4, b:Bytes):Void {
		if (c == null || b == null) return;
		b.setF32(0, c.x);
		b.setF32(4, c.y);
		b.setF32(8, c.z);
		b.setF32(12, c.w);
	}

	public static function syncBytesToVec(b:Bytes, c:ImVec4):Void {
		if (b == null || c == null) return;
		c.x = b.getF32(0);
		c.y = b.getF32(4);
		c.z = b.getF32(8);
		c.w = b.getF32(12);
	}

	public static function syncCustomFromBytes():Void {
		init();
		syncBytesToVec(customBufWindowBg, CUSTOM.windowBg);
		syncBytesToVec(customBufCellBg, CUSTOM.cellBg);
		syncBytesToVec(customBufTitleBg, CUSTOM.titleBg);
		syncBytesToVec(customBufBorder, CUSTOM.border);
		syncBytesToVec(customBufAccent, CUSTOM.accent);
		syncBytesToVec(customBufText, CUSTOM.text);
		syncBytesToVec(customBufTextDisabled, CUSTOM.textDisabled);
		syncBytesToVec(customBufDimOverlay, CUSTOM.dimOverlay);
	}

	public static function copyPresetToCustom(kind:String):Void {
		init();
		var src = resolvePreset(kind);
		CUSTOM = src.copy();
		syncVecToBytes(CUSTOM.windowBg, customBufWindowBg);
		syncVecToBytes(CUSTOM.cellBg, customBufCellBg);
		syncVecToBytes(CUSTOM.titleBg, customBufTitleBg);
		syncVecToBytes(CUSTOM.border, customBufBorder);
		syncVecToBytes(CUSTOM.accent, customBufAccent);
		syncVecToBytes(CUSTOM.text, customBufText);
		syncVecToBytes(CUSTOM.textDisabled, customBufTextDisabled);
		syncVecToBytes(CUSTOM.dimOverlay, customBufDimOverlay);
	}

	public static function dumpCustom():Dynamic {
		init();
		syncCustomFromBytes();
		return {
			windowBg: [CUSTOM.windowBg.x, CUSTOM.windowBg.y, CUSTOM.windowBg.z, CUSTOM.windowBg.w],
			cellBg: [CUSTOM.cellBg.x, CUSTOM.cellBg.y, CUSTOM.cellBg.z, CUSTOM.cellBg.w],
			titleBg: [CUSTOM.titleBg.x, CUSTOM.titleBg.y, CUSTOM.titleBg.z, CUSTOM.titleBg.w],
			border: [CUSTOM.border.x, CUSTOM.border.y, CUSTOM.border.z, CUSTOM.border.w],
			accent: [CUSTOM.accent.x, CUSTOM.accent.y, CUSTOM.accent.z, CUSTOM.accent.w],
			text: [CUSTOM.text.x, CUSTOM.text.y, CUSTOM.text.z, CUSTOM.text.w],
			textDisabled: [CUSTOM.textDisabled.x, CUSTOM.textDisabled.y, CUSTOM.textDisabled.z, CUSTOM.textDisabled.w],
			dimOverlay: [CUSTOM.dimOverlay.x, CUSTOM.dimOverlay.y, CUSTOM.dimOverlay.z, CUSTOM.dimOverlay.w]
		};
	}

	public static function applyCustomDump(data:Dynamic):Void {
		if (data == null) return;
		if (!initialized) init();
		readArrToVec(Reflect.field(data, "windowBg"), CUSTOM.windowBg);
		readArrToVec(Reflect.field(data, "cellBg"), CUSTOM.cellBg);
		readArrToVec(Reflect.field(data, "titleBg"), CUSTOM.titleBg);
		readArrToVec(Reflect.field(data, "border"), CUSTOM.border);
		readArrToVec(Reflect.field(data, "accent"), CUSTOM.accent);
		readArrToVec(Reflect.field(data, "text"), CUSTOM.text);
		readArrToVec(Reflect.field(data, "textDisabled"), CUSTOM.textDisabled);
		readArrToVec(Reflect.field(data, "dimOverlay"), CUSTOM.dimOverlay);
		syncVecToBytes(CUSTOM.windowBg, customBufWindowBg);
		syncVecToBytes(CUSTOM.cellBg, customBufCellBg);
		syncVecToBytes(CUSTOM.titleBg, customBufTitleBg);
		syncVecToBytes(CUSTOM.border, customBufBorder);
		syncVecToBytes(CUSTOM.accent, customBufAccent);
		syncVecToBytes(CUSTOM.text, customBufText);
		syncVecToBytes(CUSTOM.textDisabled, customBufTextDisabled);
		syncVecToBytes(CUSTOM.dimOverlay, customBufDimOverlay);
	}

	static function readArrToVec(arr:Array<Dynamic>, vec:ImVec4):Void {
		if (arr == null || arr.length < 4 || vec == null) return;
		try {
			vec.x = Std.parseFloat(Std.string(arr[0]));
			vec.y = Std.parseFloat(Std.string(arr[1]));
			vec.z = Std.parseFloat(Std.string(arr[2]));
			vec.w = Std.parseFloat(Std.string(arr[3]));
		} catch (_:Dynamic) {}
	}

	public static function drawThemeEditorPane():Void {
		init();
		ImGui.textWrapped("Select a preset or customize each chrome color. Theme settings persist in your universal F6 profile.");
		var currentTheme = SettingsStore.currentTheme();

		if (ImGui.beginCombo("Theme preset##th_preset", themeLabel(currentTheme))) {
			for (p in presets) {
				if (ImGui.selectable(themeLabel(p) + "##th_p_" + p, currentTheme == p)) {
					SettingsStore.setActiveTheme(p);
					SettingsStore.markDirty();
				}
			}
			ImGui.endCombo();
		}

		if (ImGui.sliderFloat("Window opacity##th_opacity", windowOpacity, 0.2, 1.0, "%.2f")) {
			SettingsStore.markDirty();
		}

		if (SettingsStore.currentTheme() == ThemeKind.Custom) {
			ImGui.separatorText("Custom Color Channels");
			if (ImGui.colorEdit4("Window BG##th_winbg", customBufWindowBg)) SettingsStore.markDirty();
			if (ImGui.colorEdit4("Control/Frame BG##th_cellbg", customBufCellBg)) SettingsStore.markDirty();
			if (ImGui.colorEdit4("Title Bar BG##th_titlebg", customBufTitleBg)) SettingsStore.markDirty();
			if (ImGui.colorEdit4("Border##th_border", customBufBorder)) SettingsStore.markDirty();
			if (ImGui.colorEdit4("Accent / Hover##th_accent", customBufAccent)) SettingsStore.markDirty();
			if (ImGui.colorEdit4("Text##th_text", customBufText)) SettingsStore.markDirty();
			if (ImGui.colorEdit4("Muted Text##th_textdis", customBufTextDisabled)) SettingsStore.markDirty();
			if (ImGui.colorEdit4("Dim Overlay##th_dim", customBufDimOverlay)) SettingsStore.markDirty();

			if (ImGui.button("Copy Purple & Gold to Custom##th_cpy_pg")) { copyPresetToCustom(ThemeKind.PurpleGold); SettingsStore.markDirty(); }
			ImGui.sameLine();
			if (ImGui.button("Copy Obsidian Ember to Custom##th_cpy_oe")) { copyPresetToCustom(ThemeKind.ObsidianEmber); SettingsStore.markDirty(); }
		}

		ImGui.separatorText("Preview");
		drawContainedPreview();
	}

	public static function drawContainedPreview():Void {
		init();
		var candidate = current();
		pushColors(candidate);
		var childBegun = false;
		var failure:Dynamic = null;
		try {
			ImGui.beginChild("##th_preview_child", ImGui.vec2(0, 130), 0, 0);
			childBegun = true;
			ImGui.text("Title Strip / Normal Text");
			ImGui.textDisabled("Disabled / Muted Text");
			ImGui.button("Action Button##th_prev_btn"); ImGui.sameLine();
			ImGui.checkbox("Checkbox##th_prev_chk", previewDummyCheck);
		} catch (e:Dynamic) {
			failure = e;
		}
		if (childBegun)
			try ImGui.endChild() catch (e:Dynamic) if (failure == null) failure = e;
		pop();
		if (failure != null)
			throw failure;
	}

	static function themeLabel(k:String):String {
		if (k == ThemeKind.PurpleGold) return "Purple & Gold (Default)";
		if (k == ThemeKind.ObsidianEmber) return "Obsidian Ember";
		if (k == ThemeKind.VoidsteelBlue) return "Voidsteel Blue";
		if (k == ThemeKind.AshGold) return "Ash & Gold";
		if (k == ThemeKind.SolarflareCrimson) return "Solarflare Crimson";
		if (k == ThemeKind.MoonlitSlate) return "Moonlit Slate";
		if (k == ThemeKind.HighContrast) return "High Contrast";
		if (k == ThemeKind.Custom) return "Custom Theme";
		return "Purple & Gold";
	}

	public static function current():ThemeColors {
		init();
		return resolve(SettingsStore.currentTheme());
	}

	public static function resolve(kind:String):ThemeColors {
		init();
		if (kind == ThemeKind.Custom) {
			syncCustomFromBytes();
			return CUSTOM;
		}
		return resolvePreset(kind);
	}

	static function resolvePreset(kind:String):ThemeColors {
		if (!initialized) init();
		if (kind == ThemeKind.ObsidianEmber) return OBSIDIAN_EMBER;
		if (kind == ThemeKind.VoidsteelBlue) return VOIDSTEEL_BLUE;
		if (kind == ThemeKind.AshGold) return ASH_GOLD;
		if (kind == ThemeKind.SolarflareCrimson) return SOLARFLARE_CRIMSON;
		if (kind == ThemeKind.MoonlitSlate) return MOONLIT_SLATE;
		if (kind == ThemeKind.HighContrast) return HIGH_CONTRAST;
		if (kind == "volcanic") return OBSIDIAN_EMBER;
		if (kind == "midnight") return VOIDSTEEL_BLUE;
		if (kind == "emerald") return MOONLIT_SLATE;
		if (kind == "obsidian") return OBSIDIAN_EMBER;
		return PURPLE_GOLD;
	}

	public static function pushColors(c:ThemeColors):Void {
		if (c == null) return;
		panelBg.x = c.windowBg.x;
		panelBg.y = c.windowBg.y;
		panelBg.z = c.windowBg.z;
		panelBg.w = panelAlpha();
		ImGui.pushStyleColor(ImGuiCol.WindowBg, panelBg);
		ImGui.pushStyleColor(ImGuiCol.ChildBg, panelBg);
		ImGui.pushStyleColor(ImGuiCol.PopupBg, panelBg);
		ImGui.pushStyleColor(ImGuiCol.Border, c.border);
		ImGui.pushStyleColor(ImGuiCol.Text, c.text);
		ImGui.pushStyleColor(ImGuiCol.TextDisabled, c.textDisabled);
		ImGui.pushStyleColor(ImGuiCol.FrameBg, c.cellBg);
		ImGui.pushStyleColor(ImGuiCol.FrameBgHovered, c.accent);
		ImGui.pushStyleColor(ImGuiCol.FrameBgActive, c.accent);
		ImGui.pushStyleColor(ImGuiCol.Button, c.cellBg);
		ImGui.pushStyleColor(ImGuiCol.ButtonHovered, c.accent);
		ImGui.pushStyleColor(ImGuiCol.ButtonActive, c.accent);
		ImGui.pushStyleColor(ImGuiCol.Header, c.cellBg);
		ImGui.pushStyleColor(ImGuiCol.HeaderHovered, c.accent);
		ImGui.pushStyleColor(ImGuiCol.HeaderActive, c.accent);
		ImGui.pushStyleColor(ImGuiCol.Separator, c.border);
		ImGui.pushStyleColor(ImGuiCol.TitleBg, c.titleBg);
		ImGui.pushStyleColor(ImGuiCol.TitleBgActive, c.cellBg);
		ImGui.pushStyleColor(ImGuiCol.ScrollbarBg, panelBg);
		ImGui.pushStyleColor(ImGuiCol.ScrollbarGrab, c.border);
		ImGui.pushStyleColor(ImGuiCol.Tab, c.cellBg);
		ImGui.pushStyleColor(ImGuiCol.TabHovered, c.accent);
		ImGui.pushStyleColor(ImGuiCol.TabSelected, c.titleBg);
		ImGui.pushStyleColor(ImGuiCol.TabDimmed, c.windowBg);
		ImGui.pushStyleColor(ImGuiCol.TabDimmedSelected, c.cellBg);
		ImGui.pushStyleColor(ImGuiCol.DockingPreview, c.accent);
		ImGui.pushStyleColor(ImGuiCol.DockingEmptyBg, c.dimOverlay);
		ImGui.pushStyleColor(ImGuiCol.DragDropTarget, c.accent);
	}

	public static function push():Void {
		pushColors(current());
	}

	public static function pop():Void ImGui.popStyleColor(COLOR_COUNT);

	public static function wrap(draw:Void->Void):Void {
		push();
		try {
			draw();
		} catch (e:Dynamic) {
			pop();
			throw e;
		}
		pop();
	}
}
