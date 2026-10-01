package solarflare.hemorrhage;

import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiTableColumnFlags;
import imgui.Enums.ImGuiTableFlags;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Theme;
import solarflare.hemorrhage.HemorrhageCache.HemorrhageRow;
import solarflare.ui.HudChrome;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.ImGuiLists;
import solarflare.ui.SettingsStore;
import solarflare.ui.UiScope;

/** Reads module snapshots only. Floating labels use a draw list, never an input window. */
class HemorrhageOverlay {
	static inline var MIN_W:Single = 360;
	static inline var MIN_H:Single = 180;
	static inline var FOOTER:Single = HudChrome.RESIZE_GRIP + 12;
	var theme:Theme;
	var transparentTheme:Theme;
	var drawnRevision:Int = -1;

	public function new() {
		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(8, 6))
			.varV(ImGuiStyleVar.ItemSpacing, ImGui.vec2(4, 2))
			.varF(ImGuiStyleVar.WindowRounding, 6)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0.075, 0.065, 0.075, 0.9))
			.color(ImGuiCol.Border, ImGui.vec4(0.85, 0.38, 0.44, 0.7))
			.color(ImGuiCol.ChildBg, ImGui.vec4(0, 0, 0, 0))
			.color(ImGuiCol.TableHeaderBg, ImGui.vec4(0, 0, 0, 0))
			.color(ImGuiCol.TableRowBg, ImGui.vec4(0.08, 0.07, 0.08, 0.4))
			.color(ImGuiCol.TableRowBgAlt, ImGui.vec4(0.16, 0.10, 0.12, 0.4));
		transparentTheme = new Theme().color(ImGuiCol.Border, ImGui.vec4(0, 0, 0, 0));
	}

	public function draw(cfg:HemorrhageConfig):Void {
		if (cfg == null || cfg.hidden.get() || solarflare.ui.HudSuppress.active()) {
			HemorrhageCache.clearFloating();
			return;
		}
		theme.wrap(function() {
			if (cfg.chrome.isTransparent()) transparentTheme.wrap(function() drawWindow(cfg));
			else drawWindow(cfg);
		});
	}

	function close(cfg:HemorrhageConfig):Void {
		cfg.hidden.set(true);
		HemorrhageCache.configure(false, false, false);
		SettingsStore.markDirty();
	}

	function drawWindow(cfg:HemorrhageConfig):Void {
		var chrome = cfg.chrome;
		chrome.extraMenu = function() {
			if (ImGui.menuItem("Clear history##hemorrhage_clear")) HemorrhageCache.clear();
			if (ImGui.menuItem("Auto-scroll##hemorrhage_auto", null, cfg.autoScroll)) SettingsStore.markDirty();
		};
		var collapsed = chrome.isCollapsed();
		var minimumHeight:Single = cfg.floatingText.get() ? Math.max(MIN_H,
			HemorrhageFloatLayout.stageHeight(cfg.textSize.get()) + 120) : MIN_H;
		ImGui.setNextWindowBgAlpha(chrome.isTransparent() ? 0 : 0.9);
		ImGui.setNextWindowSizeConstraints(
			ImGui.vec2(collapsed ? HudChrome.SUN + HudChrome.CLOSE + 18 : MIN_W,
				collapsed ? HudChrome.STRIP + 6 : minimumHeight), ImGui.vec2(1600, 1200));
		if (chrome.takeExpandDirty()) cfg.sizeDirty = true;
		ImGui.setNextWindowSize(ImGui.vec2(Math.max(MIN_W, cfg.width.get()), Math.max(minimumHeight, cfg.height.get())),
			cfg.sizeDirty ? ImGuiCond.Always : ImGuiCond.FirstUseEver);
		cfg.sizeDirty = false;
		chrome.clampToViewport();
		chrome.applyPos();
		var flags = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse
			| ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse;
		var began = ImGui.begin("Hemorrhage###SolarFlare.Hemorrhage", null, chrome.windowFlagsKeepClicks(flags));
		var failure:Dynamic = null;
		try {
			if (began) {
				var size = ImGui.getWindowSize();
				chrome.winW = size.x;
				chrome.winH = size.y;
				if (!chrome.isLocked()) chrome.capturePos();
				if (chrome.beginBody(function() close(cfg), null, "Hemorrhage", false,
						ImGuiWindowFlags.NoScrollWithMouse, 0, FOOTER)) {
					if (cfg.floatingText.get()) drawFloating(cfg);
					drawHeader();
					var avail = ImGui.getContentRegionAvail();
					if (avail.y > 24) drawRows(cfg, avail.x, avail.y);
				}
				chrome.closeBodyChild();
				if (!chrome.isCollapsed()) chrome.captureSize(cfg.width, cfg.height);
				chrome.drawResizeCorner("hemorrhage", !chrome.isLocked(), MIN_W, minimumHeight, 1600, 1200,
					function(w:Single, h:Single) {
						cfg.width.set(w); cfg.height.set(h); SettingsStore.markDirty();
					}, 8);
				chrome.pollTransparentSurfaceDrag("hemorrhage", !chrome.isLocked());
			}
		} catch (e:Dynamic) failure = e;
		HudChrome.endOverlayWindow(began, chrome);
		chrome.extraMenu = null;
		if (failure != null) UiScope.report("window", "hemorrhage", failure);
	}

	function drawHeader():Void {
		var chance = HemorrhageCache.criticalChance;
		var value = Math.isFinite(chance) ? Std.string(Math.ffloor(chance * 1000 + 0.5) / 10) + "%" : "—";
		UiScope.table("##hemorrhage_summary", 3, function() {
			ImGui.tableSetupColumn("Chance", ImGuiTableColumnFlags.WidthStretch, 1);
			ImGui.tableSetupColumn("Hits", ImGuiTableColumnFlags.WidthStretch, 1);
			ImGui.tableSetupColumn("Bleed", ImGuiTableColumnFlags.WidthStretch, 1);
			ImGui.tableNextRow();
			ImGui.tableNextColumn(); ImGui.textUnformatted("Crit " + value);
			if (CursorCaptureFix.cursorFree && ImGui.isItemHovered())
				ImGui.setTooltip("Current Critical Strike chance.\nCritical rating: " + HemorrhageCache.number(HemorrhageCache.criticalRating));
			ImGui.tableNextColumn();
			ImGui.textColored(ImGui.vec4(1, 0.82, 0.36, 1), "Hits " + HemorrhageCache.number(HemorrhageCache.criticalTotal));
			if (CursorCaptureFix.cursorFree && ImGui.isItemHovered()) ImGui.setTooltip("Total physical critical-hit damage since Clear.");
			ImGui.tableNextColumn();
			ImGui.textColored(ImGui.vec4(1, 0.48, 0.57, 1), "Bleed " + HemorrhageCache.number(HemorrhageCache.hemorrhageTotal));
			if (CursorCaptureFix.cursorFree && ImGui.isItemHovered()) ImGui.setTooltip("Actual Hemorrhage damage since Clear, including talent effects.");
		}, ImGuiTableFlags.SizingStretchProp | ImGuiTableFlags.NoSavedSettings | ImGuiTableFlags.NoPadOuterX);
		ImGui.separator();
	}

	function drawRows(cfg:HemorrhageConfig, width:Single, height:Single):Void {
		// Own the scroll child explicitly: ImGui's table-created child does not inherit NoInputs.
		UiScope.child("##hemorrhage_scroll", ImGui.vec2(width, height), function() {
			var flags = ImGuiTableFlags.SizingStretchProp | ImGuiTableFlags.NoSavedSettings;
			if (!cfg.chrome.isTransparent()) flags |= ImGuiTableFlags.RowBg | ImGuiTableFlags.BordersInnerV;
			if (CursorCaptureFix.cursorFree) flags |= ImGuiTableFlags.Resizable;
			UiScope.table("##hemorrhage_rows", 4, function() {
				ImGui.tableSetupColumn("Enemy", ImGuiTableColumnFlags.WidthStretch, 1);
				ImGui.tableSetupColumn("Ability", ImGuiTableColumnFlags.WidthStretch, 1.2);
				ImGui.tableSetupColumn("Crit", ImGuiTableColumnFlags.WidthFixed, 68);
				ImGui.tableSetupColumn("Hemorrhage", ImGuiTableColumnFlags.WidthFixed, 88);
				ImGui.tableHeadersRow();
				ImGuiLists.forVisible(HemorrhageCache.count, function(i:Int) drawRow(HemorrhageCache.rowAt(i)));
			}, flags);
			if (HemorrhageCache.count == 0) ImGui.textDisabled("Waiting for damage");
			if (cfg.autoScroll.get() && drawnRevision != HemorrhageCache.revision)
				ImGui.setScrollFromPosY(ImGui.getCursorPosY(), 1);
			drawnRevision = HemorrhageCache.revision;
		}, 0, CursorCaptureFix.windowFlags(ImGuiWindowFlags.NoBackground));
	}

	function drawRow(row:HemorrhageRow):Void {
		if (row == null) return;
		ImGui.tableNextRow();
		ImGui.tableNextColumn(); ImGui.textUnformatted(row.enemy);
		if (CursorCaptureFix.cursorFree && ImGui.isItemHovered()) ImGui.setTooltip(row.enemy);
		ImGui.tableNextColumn(); ImGui.textUnformatted(row.ability);
		if (CursorCaptureFix.cursorFree && ImGui.isItemHovered()) ImGui.setTooltip(row.ability);
		ImGui.tableNextColumn();
		if (!row.bleed) ImGui.textColored(ImGui.vec4(1, 0.82, 0.36, 1), HemorrhageCache.number(row.amount));
		ImGui.tableNextColumn();
		if (row.bleed) ImGui.textColored(ImGui.vec4(1, 0.48, 0.57, 1), HemorrhageCache.number(row.amount));
	}

	function drawFloating(cfg:HemorrhageConfig):Void {
		var rows = HemorrhageCache.floating;
		var font = ImGui.getFont();
		if (font == null) return;
		var now = haxe.Timer.stamp();
		var failure:Dynamic = null;
		ImGui.pushFont(font, cfg.textSize.get());
		var pos = ImGui.getCursorScreenPos();
		var width = ImGui.getContentRegionAvail().x;
		var textHeight = ImGui.getTextLineHeight();
		var height:Single = HemorrhageFloatLayout.stageHeight(textHeight);
		ImGui.dummy(ImGui.vec2(width, height));
		var dl = ImGui.getWindowDrawList();
		ImGui.ImDrawList_PushClipRect(dl, pos, ImGui.vec2(pos.x + width, pos.y + height), true);
		try {
			if (rows.length == 0 && !cfg.chrome.isLocked() && CursorCaptureFix.cursorFree) {
				var label = "Floating text";
				var size = ImGui.calcTextSize(label);
				ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(pos.x + Math.max(0, (width - size.x) * 0.5), pos.y + height - textHeight),
					ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.7, 0.7, 0.7, 0.5)), label);
			}
			for (i in 0...rows.length) {
				var row = rows[i];
				var size = ImGui.calcTextSize(row.text);
				var p = HemorrhageFloatLayout.placeInStage(pos.x, pos.y, width, size.x, size.y,
					rows.length - 1 - i, now - row.at, cfg.textLifetime.get());
				if (p.alpha <= 0) continue;
				var outline = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.03, 0.02, 0.03, p.alpha * 0.85));
				var color = row.bleed ? ImGui.vec4(1, 0.48, 0.57, p.alpha) : ImGui.vec4(1, 0.82, 0.36, p.alpha);
				for (offset in [-1, 1]) {
					ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(p.x + offset, p.y), outline, row.text);
					ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(p.x, p.y + offset), outline, row.text);
				}
				ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(p.x, p.y), ImGui.colorConvertFloat4ToU32(color), row.text);
			}
		} catch (e:Dynamic) failure = e;
		ImGui.ImDrawList_PopClipRect(dl);
		ImGui.popFont();
		if (failure != null) UiScope.report("floating text", "hemorrhage", failure);
	}
}
