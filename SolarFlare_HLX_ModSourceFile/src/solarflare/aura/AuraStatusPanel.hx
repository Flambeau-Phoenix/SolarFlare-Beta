package solarflare.aura;

import solarflare.HealthCache;
import solarflare.ui.GameIcons;
import solarflare.ui.HUDWidgetWindow;
import solarflare.ui.SettingsStore;
import imgui.ImGui;
import imgui.Structs.ImVec2;

/**
 * Compact HUD overlay: active aura badge grid + live resource tracker bars.
 *
 * Reads AuraConfig.auras presentation state (show / progress / timeLeft) and
 * HealthCache resource snaps -- no game mutations, no config writes except
 * SettingsStore.markDirty() on resize.
 *
 * Registered in SolarFlarePanel.drawOverlays via the standard isolated
 * try/catch block alongside the existing auraOverlay.draw() call.
 */
class AuraStatusPanel {
	/** Max badges rendered regardless of active aura count. */
	static inline var MAX_BADGES:Int = 8;
	/** Gap in px between badge cells. */
	static inline var BADGE_GAP:Single = 4;
	/** Gap between badge grid and resource bar section. */
	static inline var SECTION_GAP:Single = 6;
	static inline var GLOW_INSET:Single = 12;

	var cfg:AuraStatusPanelConfig;
	var auraCfg:AuraConfig;

	public function new(cfg:AuraStatusPanelConfig, auraCfg:AuraConfig) {
		this.cfg = cfg;
		this.auraCfg = auraCfg;
	}

	public function draw():Void {
		if (cfg == null || cfg.hidden.get() || auraCfg == null) return;
		var cols:Int = cfg.columns.get();
		if (cols < 1) cols = 1;
		if (cols > 4) cols = 4;
		var cell:Single = cfg.cellSize.get();
		if (cell < 24) cell = 24;
		var contentW:Single = cols * (cell + BADGE_GAP) - BADGE_GAP;
		var panelW:Single = Math.max(contentW + GLOW_INSET * 2, cfg.panelW.get());
		var badges = 0;
		for (a in auraCfg.auras)
			if (a != null && a.show && a.enabled.get() && badges < MAX_BADGES) badges++;
		var rows = Math.max(1, Math.ceil(badges / cols));
		var panelH:Single = rows * (cell + BADGE_GAP) - BADGE_GAP + GLOW_INSET * 2;
		if (badges == 0) panelH += ImGui.getTextLineHeight() + 3;
		if (cfg.showResourceBars.get()) {
			var bars = (HealthCache.valid ? 1 : 0) + (HealthCache.rageValid ? 1 : 0)
				+ (HealthCache.resourceValid() ? 1 : 0);
			panelH += SECTION_GAP + 3 + bars * (Math.max(10, cfg.barRowH.get()) + 3);
		}
		HUDWidgetWindow.draw(
			"SFAuraStatusPanel", "Auras", cfg.chrome,
			panelW, panelH,
			function(size:ImVec2) drawContent(size, cols, cell),
			null,
			function() {
				cfg.hidden.set(true);
				SettingsStore.markDirty();
			},
			false,
			null,
			function(nw:Single, nh:Single) {
				cfg.panelW.set(Math.max(contentW, nw));
				SettingsStore.markDirty();
			}
		);
	}

	function drawContent(size:ImVec2, cols:Int, cell:Single):Void {
		drawBadgeGrid(cols, cell);
		if (cfg.showResourceBars.get())
			drawResourceBars(size.x);
	}

	function drawBadgeGrid(cols:Int, cell:Single):Void {
		if (auraCfg == null || auraCfg.auras == null) return;
		var dl = ImGui.getWindowDrawList();
		var origin = ImGui.getCursorScreenPos();
		var col = 0;
		var row = 0;
		var shown = 0;
		for (a in auraCfg.auras) {
			if (a == null || !a.show || !a.enabled.get()) continue;
			if (shown >= MAX_BADGES) break;
			var x:Single = origin.x + GLOW_INSET + col * (cell + BADGE_GAP);
			var y:Single = origin.y + GLOW_INSET + row * (cell + BADGE_GAP);
			drawBadge(dl, a, x, y, cell);
			col++;
			if (col >= cols) { col = 0; row++; }
			shown++;
		}
		var rows = row + (col > 0 ? 1 : 0);
		if (rows < 1) rows = 1;
		ImGui.dummy(ImGui.vec2(cols * (cell + BADGE_GAP) - BADGE_GAP + GLOW_INSET * 2,
			rows * (cell + BADGE_GAP) - BADGE_GAP + GLOW_INSET * 2));
		if (shown == 0)
			ImGui.textDisabled("(no active auras)");
	}

	function drawBadge(dl:Dynamic, a:AuraDef, x:Single, y:Single, cell:Single):Void {
		// Icon
		var tex = GameIcons.get(a.resolvedIcon.length > 0 ? a.resolvedIcon : a.preferredIconId());
		var tint = ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, a.opacity != null ? a.opacity.get() : 1));
		if (!GameIcons.draw(dl, tex, x, y, cell, tint)) {
			// Fallback placeholder rect
			ImGui.ImDrawList_AddRectFilled(dl,
				ImGui.vec2(x, y), ImGui.vec2(x + cell, y + cell),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.13, 0.16, 0.21, 0.9)), 4);
		}
		// Fuse strip (bottom edge drains with remaining progress)
		if (cfg.fuseBottom.get() && a.showFuse != null && a.showFuse.get() && a.progress > 0) {
			var barH:Single = 4;
			var fill:Single = cell * a.progress;
			ImGui.ImDrawList_AddRectFilled(dl,
				ImGui.vec2(x, y + cell - barH),
				ImGui.vec2(x + cell, y + cell),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.08, 0.08, 0.1, 0.8)), 0);
			if (fill > 0)
				ImGui.ImDrawList_AddRectFilled(dl,
					ImGui.vec2(x, y + cell - barH),
					ImGui.vec2(x + fill, y + cell),
					ImGui.colorConvertFloat4ToU32(
						a.progress < 0.25
							? ImGui.vec4(0.95, 0.35, 0.2, 0.92)
							: ImGui.vec4(0.95, 0.78, 0.28, 0.9)
					), 2);
		}
		// Countdown text overlay
		if (cfg.showCountdown.get() && a.showCountdown != null && a.showCountdown.get()
				&& !a.timerInfinite && Math.isFinite(a.timeLeft) && a.timeLeft > 0) {
			var label = a.timeLeft < 10
				? (Math.round(a.timeLeft * 10) / 10) + ""
				: Std.string(Math.round(a.timeLeft));
			var ts = ImGui.calcTextSize(label);
			ImGui.ImDrawList_AddText_Vec2(dl,
				ImGui.vec2(x + (cell - ts.x) * 0.5, y + (cell - ts.y) * 0.5),
				0xFFFFFFFF, label);
		}
		// Glow accent bloom when iconGlow is active
		if (a.iconGlow) {
			var gc = a.glowColor != 0 ? a.glowColor : 0xFFFF8800;
			solarflare.ui.VectorGlow.procTinted(dl, x, y, cell, cell, ImGui.getTime(), gc);
		}
	}

	function drawResourceBars(availW:Single):Void {
		var h:Single = cfg.barRowH.get();
		if (h < 10) h = 10;
		ImGui.dummy(ImGui.vec2(1, SECTION_GAP));
		var dl = ImGui.getWindowDrawList();
		if (HealthCache.valid)
			drawBar(dl, availW, h, HealthCache.ratio(), ImGui.vec4(0.25, 0.72, 0.32, 0.88), "HP");
		if (HealthCache.rageValid)
			drawBar(dl, availW, h, HealthCache.rageRatio(), ImGui.vec4(0.85, 0.22, 0.18, 0.88), "Rage");
		if (HealthCache.resourceValid())
			drawBar(dl, availW, h, HealthCache.resourceRatio(),
				ImGui.vec4(0.28, 0.55, 0.98, 0.88),
				HealthCache.sparkValid ? "Spark" : "Mana");
	}

	function drawBar(dl:Dynamic, w:Single, h:Single, ratio:Float, color:Dynamic, label:String):Void {
		var p = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(w, h));
		// Track
		ImGui.ImDrawList_AddRectFilled(dl, p, ImGui.vec2(p.x + w, p.y + h),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.08, 0.09, 0.11, 0.82)), 3);
		// Fill
		var filled:Single = Math.max(0, Math.min(1, ratio)) * w;
		if (filled > 1)
			ImGui.ImDrawList_AddRectFilled(dl, p, ImGui.vec2(p.x + filled, p.y + h),
				ImGui.colorConvertFloat4ToU32(color), 3);
		// Label
		var ts = ImGui.calcTextSize(label);
		ImGui.ImDrawList_AddText_Vec2(dl,
			ImGui.vec2(p.x + 5, p.y + (h - ts.y) * 0.5),
			0xCCFFFFFF, label);
	}
}
