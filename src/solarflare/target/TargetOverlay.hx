package solarflare.target;

import solarflare.combatlog.CombatLogCache;
import solarflare.ui.EnhancedText;
import solarflare.ui.GameIcons;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import solarflare.ui.ThemePalette;
import solarflare.ui.UiCol;
import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Theme;

/**
 * Current-target HUD. Draws frozen TargetSnap only — no live unit reads.
 * Portrait via GameIcons.get(snap.kind) after observe preload (same as skill icons).
 */
class TargetOverlay {
	static inline var FLAGS:Int = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse
		| ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse;
	static inline var EMPTY_LABEL:String = "No target";
	static inline var PORTRAIT_GAP:Single = 6;

	var theme:Theme;
	var snap:TargetSnap;

	public function new() {
		snap = new TargetSnap();
		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(8, 6))
			.varF(ImGuiStyleVar.WindowRounding, 4)
			.varF(ImGuiStyleVar.WindowBorderSize, 1)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0.07, 0.08, 0.10, 0.90))
			.color(ImGuiCol.Border, ImGui.vec4(0.55, 0.35, 0.30, 0.65));
	}

	public function draw(cfg:TargetConfig):Void {
		if (cfg == null || cfg.hidden.get())
			return;
		snap.copyFrom(CombatLogCache.currentTargetSnap());
		if (cfg.bossesOnly.get() && snap.valid) {
			if (!snap.isBoss && !snap.isMiniboss && !snap.isElite)
				snap.valid = false;
		}
		if (!snap.valid && !cfg.alwaysShow.get())
			return;
		theme.wrap(() -> drawWindow(cfg));
	}

	function drawWindow(cfg:TargetConfig):Void {
		var w:Single = cfg.width.get() < TargetConfig.MIN_W ? TargetConfig.MIN_W : cfg.width.get();
		var h:Single = cfg.height.get() < TargetConfig.MIN_H ? TargetConfig.MIN_H : cfg.height.get();
		if (w > TargetConfig.MAX_W)
			w = TargetConfig.MAX_W;
		if (h > TargetConfig.MAX_H)
			h = TargetConfig.MAX_H;

		var trans = cfg.chrome != null && cfg.chrome.isTransparent();
		ImGui.setNextWindowBgAlpha(trans ? 0 : ThemePalette.panelAlpha());
		ImGui.setNextWindowSizeConstraints(
			ImGui.vec2(TargetConfig.MIN_W, TargetConfig.MIN_H),
			ImGui.vec2(TargetConfig.MAX_W, TargetConfig.MAX_H)
		);
		if (cfg.chrome != null && cfg.chrome.takeExpandDirty())
			cfg.sizeDirty = true;
		if (cfg.sizeDirty) {
			ImGui.setNextWindowSize(ImGui.vec2(w, h), ImGuiCond.Always);
			cfg.sizeDirty = false;
		} else {
			ImGui.setNextWindowSize(ImGui.vec2(w, h), ImGuiCond.FirstUseEver);
		}
		if (cfg.chrome != null) {
			cfg.chrome.clampToViewport();
			cfg.chrome.applyPos();
			if (!cfg.chrome.collapsed.get())
				ImGui.setNextWindowPos(ImGui.vec2(cfg.chrome.x.get(), cfg.chrome.y.get()), ImGuiCond.FirstUseEver);
		} else {
			ImGui.setNextWindowPos(ImGui.vec2(420, 80), ImGuiCond.FirstUseEver);
		}

		var flags = cfg.chrome != null ? cfg.chrome.windowFlags(FLAGS) : FLAGS;
		var began = ImGui.begin("SolarFlare Target", null, flags);
		if (began) {
			if (cfg.chrome != null && !cfg.chrome.isLocked()) {
				cfg.chrome.capturePos();
				var win = ImGui.getWindowSize();
				if (Math.abs(win.x - cfg.width.get()) > 1 || Math.abs(win.y - cfg.height.get()) > 1)
					SettingsStore.markDirty();
				cfg.width.set(win.x);
				cfg.height.set(win.y);
			}
			var showBody = cfg.chrome == null || cfg.chrome.beginBody(function() {
				cfg.hidden.set(true);
				SettingsStore.markDirty();
			}, null, "Target");
			if (showBody) {
				var avail = ImGui.getContentRegionAvail();
				drawBody(cfg, avail.x > 1 ? avail.x : 1, avail.y > 1 ? avail.y : TargetConfig.MIN_H);
			}
		}
		HudChrome.endOverlayWindow(began, cfg.chrome);
	}

	function drawBody(cfg:TargetConfig, w:Single, h:Single):Void {
		var dl = ImGui.getWindowDrawList();
		var origin = ImGui.getCursorScreenPos();

		var portraitSize:Single = 0;
		var contentX:Single = origin.x;
		var contentW:Single = w;
		if (cfg.showPortrait.get()) {
			portraitSize = Math.max(28, Math.min(h - 2, 56));
			contentW = Math.max(40, w - portraitSize - PORTRAIT_GAP);
			// In-flow only — never SetCursorScreenPos (Dear ImGui boundary assert).
			ImGui.beginGroup();
			ImGui.ImDrawList_AddRectFilled(dl,
				ImGui.vec2(origin.x, origin.y),
				ImGui.vec2(origin.x + portraitSize, origin.y + portraitSize), 0xCC0E1016, 3);
			ImGui.ImDrawList_AddRect(dl,
				ImGui.vec2(origin.x, origin.y),
				ImGui.vec2(origin.x + portraitSize, origin.y + portraitSize), 0x66888888, 3, 1.25);
			var drew = false;
			if (snap.valid && snap.kind.length > 0)
				drew = GameIcons.imageKey(snap.kind, portraitSize, portraitSize);
			if (!drew)
				ImGui.dummy(ImGui.vec2(portraitSize, portraitSize));
			var padH:Single = h - portraitSize;
			if (padH > 1)
				ImGui.dummy(ImGui.vec2(portraitSize, padH));
			ImGui.endGroup();
			ImGui.sameLine(0, PORTRAIT_GAP);
		}

		contentX = ImGui.getCursorScreenPos().x;
		ImGui.dummy(ImGui.vec2(contentW, h));

		var nameH:Single = cfg.showName.get() || (!snap.valid && cfg.alwaysShow.get()) ? 18 : 2;
		var barY:Single = origin.y + nameH;
		var barH:Single = Math.max(14, h - nameH - 4);
		var rounding:Single = Math.max(0, cfg.barRounding.get());

		if (!snap.valid) {
			drawEmptyFrame(cfg, dl, contentX, origin.y, contentW, nameH, barY, barH, rounding);
			return;
		}

		if (cfg.showName.get()) {
			var name = snap.name.length > 0 ? snap.name : "Target";
			var badge = cfg.showBadge.get() ? badgeText(snap) : "";
			var font = ImGui.getFont();
			var base = ImGui.getFontSize();
			var bumped = false;
			if (font != null) {
				try {
					ImGui.pushFont(font, base * 1.25);
					bumped = true;
				} catch (_:Dynamic) {}
			}
			var nameSize = ImGui.calcTextSize(name);
			var badgeSize = badge.length > 0 ? ImGui.calcTextSize(badge) : ImGui.vec2(0, 0);
			var badgeGap:Single = badge.length > 0 ? 8 : 0;
			var totalW:Single = nameSize.x + badgeGap + badgeSize.x;
			var nameX:Single = contentX + Math.max(0, (contentW - totalW) * 0.5);
			EnhancedText.glowStroke(dl, ImGui.vec2(nameX, origin.y), name, 0xFFFFF0D8, 0xAA8B5CC7, 1.6);
			if (badge.length > 0)
				EnhancedText.stroked(dl, ImGui.vec2(nameX + nameSize.x + badgeGap, origin.y + 2), badge, UiCol.rgb(0xFFAA66), 0xAA000000, 0.8);
			if (bumped)
				ImGui.popFont();
		}

		var ratio = snap.ratio;
		var fillCol = healthColor(ratio);
		var lowPct = cfg.lowHpPercent.get();
		if (lowPct < 5)
			lowPct = 5;
		else if (lowPct > 50)
			lowPct = 50;
		var low = lowPct / 100;

		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(contentX, barY), ImGui.vec2(contentX + contentW, barY + barH), 0xCC12141A, rounding);
		var fillW = contentW * ratio;
		if (fillW > 1) {
			var top = lighten(fillCol, 0.25);
			ImGui.ImDrawList_AddRectFilledMultiColor(dl,
				ImGui.vec2(contentX, barY), ImGui.vec2(contentX + fillW, barY + barH),
				top, top, fillCol, fillCol);
			var shineH = barH * 0.28;
			if (shineH > 2)
				ImGui.ImDrawList_AddRectFilled(dl,
					ImGui.vec2(contentX + 2, barY + 1),
					ImGui.vec2(contentX + fillW - 2, barY + shineH),
					0x22FFFFFF, Math.max(0, rounding - 1));
		}

		if (cfg.lowHpPulse.get() && ratio < low) {
			var pulse = 0.5 + 0.5 * Math.sin(ImGui.getTime() * 3.2);
			var glowA = Std.int(0.18 * pulse * 255);
			var glow = (fillCol & 0x00FFFFFF) | (glowA << 24);
			ImGui.ImDrawList_AddRectFilled(dl,
				ImGui.vec2(contentX - 2, barY - 2),
				ImGui.vec2(contentX + contentW + 2, barY + barH + 2),
				glow, rounding + 2);
		}

		var border = ratio < low ? UiCol.rgb(0xFF5555) : UiCol.rgba(255, 255, 255, 0x88);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(contentX, barY), ImGui.vec2(contentX + contentW, barY + barH), border, rounding, 1.5);

		var label = buildHpLabel(cfg, snap.health, snap.maxHealth, ratio);
		if (label.length > 0) {
			var ts = ImGui.calcTextSize(label);
			EnhancedText.shadowed(dl,
				ImGui.vec2(contentX + (contentW - ts.x) * 0.5, barY + (barH - ts.y) * 0.5),
				label, 0xFFFFFFFF, 0xAA000000, 1, 1);
		}
	}

	function drawEmptyFrame(cfg:TargetConfig, dl:Dynamic, x:Single, y:Single, w:Single,
			nameH:Single, barY:Single, barH:Single, rounding:Single):Void {
		EnhancedText.shadowed(dl, ImGui.vec2(x + 2, y + 1), EMPTY_LABEL, 0x99AAAAAA, 0x66000000, 1, 1);

		if (!cfg.showEmptyBar.get())
			return;

		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, barY), ImGui.vec2(x + w, barY + barH), 0xAA0E1016, rounding);
		// Subtle dashed-feel: dim inner fill strip so the empty frame reads as a real bar slot.
		ImGui.ImDrawList_AddRectFilled(dl,
			ImGui.vec2(x + 3, barY + barH * 0.35),
			ImGui.vec2(x + w - 3, barY + barH * 0.55),
			0x22FFFFFF, 2);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, barY), ImGui.vec2(x + w, barY + barH), 0x66888888, rounding, 1.5);

		var emptyLabel = "";
		if (cfg.showHpText.get())
			emptyLabel = "— / —";
		if (cfg.showPercent.get())
			emptyLabel = emptyLabel.length > 0 ? emptyLabel + "  —%" : "—%";
		if (emptyLabel.length == 0)
			emptyLabel = EMPTY_LABEL;
		var ts = ImGui.calcTextSize(emptyLabel);
		ImGui.ImDrawList_AddText_Vec2(dl,
			ImGui.vec2(x + (w - ts.x) * 0.5, barY + (barH - ts.y) * 0.5),
			0x77AAAAAA, emptyLabel);
	}

	static function badgeText(s:TargetSnap):String {
		if (s.isBoss)
			return "BOSS";
		if (s.isMiniboss)
			return "MINI";
		if (s.isElite)
			return "ELITE";
		return "";
	}

	static function buildHpLabel(cfg:TargetConfig, health:Float, maxHealth:Float, ratio:Float):String {
		var label = "";
		if (cfg.showHpText.get())
			label = formatHp(health) + " / " + formatHp(maxHealth);
		if (cfg.showPercent.get()) {
			var pct = Std.string(Std.int(ratio * 100 + 0.5)) + "%";
			label = label.length > 0 ? label + "  " + pct : pct;
		}
		return label;
	}

	static function healthColor(ratio:Float):Int {
		if (ratio > 0.6)
			return UiCol.rgb(0x44CC55);
		if (ratio > 0.3)
			return UiCol.rgb(0xE8C040);
		return UiCol.rgb(0xE04545);
	}

	static function lighten(color:Int, amount:Float):Int {
		var a = (color >>> 24) & 0xFF;
		var b = (color >>> 16) & 0xFF;
		var g = (color >>> 8) & 0xFF;
		var r = color & 0xFF;
		r = Std.int(Math.min(255, r + (255 - r) * amount));
		g = Std.int(Math.min(255, g + (255 - g) * amount));
		b = Std.int(Math.min(255, b + (255 - b) * amount));
		return UiCol.rgba(r, g, b, a);
	}

	static function formatHp(v:Float):String {
		if (v >= 1000000)
			return Std.string(Math.ffloor(v / 100000) / 10) + "M";
		if (v >= 10000)
			return Std.string(Math.ffloor(v / 100) / 10) + "k";
		return Std.string(Std.int(v));
	}
}
