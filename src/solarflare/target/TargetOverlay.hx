package solarflare.target;

import solarflare.combatlog.CombatLogCache;
import solarflare.castbar.CastBarRenderer;
import solarflare.castbar.CastCache;
import solarflare.castbar.CastSnap;
import solarflare.ui.EnhancedText;
import solarflare.ui.GameIcons;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
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
 * Layout: a square portrait with an HP bar exactly as tall as the portrait beside it. Name,
 * classification and HP text sit inside the bar; an active target cast draws as a smaller strip
 * inside the bottom of the bar (XPerl style), so nothing outside the window ever grows.
 */
class TargetOverlay {
	/** Cached callbacks; current UI configuration and frozen snaps are refreshed per draw. */
	var hudCfg:TargetConfig;
	var hudBodyFn:imgui.Structs.ImVec2->Void;
	var hudHideFn:Void->Void;
	var hudResizeFn:Single->Single->Void;
	var hudWindowFn:Void->Void;

	static inline var EMPTY_LABEL:String = "No target";
	static inline var PORTRAIT_GAP:Single = 8;
	static inline var PAD:Single = 4;
	/** Below this bar height, name and HP text share one row instead of stacking. */
	static inline var TWO_ROW_MIN:Single = 40;
	static inline var BAR_MIN:Single = 12;
	/** Portrait side and bar height cap; both always equal. */
	static inline var SIDE_MAX:Single = 160;
	static inline var PORTRAIT_MIN:Single = 24;
	static inline var TEXT_PAD:Single = 5;
	static inline var CAST_INSET:Single = 3;

	var theme:Theme;
	var snap:TargetSnap;
	var castSnap:CastSnap;
	var lastBodyW:Single = 0;
	var lastBodyH:Single = 0;

	public function new() {
		hudBodyFn = hudBody;
		hudHideFn = hudHide;
		hudResizeFn = hudResize;
		hudWindowFn = hudWindow;

		snap = new TargetSnap();
		castSnap = new CastSnap();
		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(6, 4))
			.varF(ImGuiStyleVar.WindowRounding, 4)
			.varF(ImGuiStyleVar.WindowBorderSize, 1)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0.07, 0.08, 0.10, 0.90))
			.color(ImGuiCol.Border, ImGui.vec4(0.55, 0.35, 0.30, 0.65));
	}

	public function draw(cfg:TargetConfig):Void {
		if (cfg == null || cfg.hidden.get()) {
			touchDraw("hidden", "", "", false, 0, 0);
			return;
		}
		if (cfg.sizeDirty && cfg.chrome != null) {
			cfg.chrome.expandSizeDirty = true;
			cfg.sizeDirty = false;
		}
		snap.copyFrom(CombatLogCache.currentTargetSnap());
		castSnap.copyFrom(CastCache.targetSnap());
		if (!snap.valid && !cfg.alwaysShow.get()) {
			touchDraw("empty", "", "", false, 0, 0);
			return;
		}
		hudCfg = cfg;
		theme.wrap(hudWindowFn);
	}

	public function drawPreview(cfg:TargetConfig, sample:TargetSnap, w:Single, h:Single, castSample:CastSnap = null):Void {
		var diagnostic = lastHealthDiagnostic;
		snap.copyFrom(sample);
		castSnap.copyFrom(castSample);
		drawBody(cfg, w, h);
		lastHealthDiagnostic = diagnostic;
	}

	public var openBuilder:Void->Void;

	function drawWindow(cfg:TargetConfig):Void {
		var w:Single = Math.max(TargetConfig.MIN_W, Math.min(TargetConfig.MAX_W, cfg.width.get()));
		var h:Single = Math.max(TargetConfig.MIN_H, Math.min(TargetConfig.MAX_H, cfg.height.get()));
		hudCfg = cfg;
		solarflare.ui.HUDWidgetWindow.draw("SolarFlare Target", "Target", cfg.chrome, w, h, hudBodyFn, openBuilder, hudHideFn, false, null, hudResizeFn);
		hudCfg = null;
	}

	static inline function touchDraw(method:String, name:String, kind:String, hasIcon:Bool, bw:Single, bh:Single):Void {
		#if solarflare_telemetry
		if (!solarflare.debug.ResolutionLedger.armed())
			return;
		var preview = (name != null ? name : "") + "|" + (kind != null ? kind : "")
			+ "|" + (hasIcon ? "icon" : "noIcon") + "|" + Std.int(bw) + "x" + Std.int(bh);
		solarflare.debug.ResolutionLedger.touch("target.draw", method, "TargetOverlay.draw",
			name != null ? name : "", "string", preview);
		#end
	}

	function drawBody(cfg:TargetConfig, w:Single, h:Single):Void {
		var dl = ImGui.getWindowDrawList();
		var origin = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(w, h));

		var contentH:Single = Math.max(8, h - PAD * 2);
		var contentX:Single = origin.x + PAD;
		var contentW:Single = Math.max(1, w - PAD * 2);

		// One square decides both heights: the HP bar is exactly as tall as the portrait.
		var side:Single = Math.min(contentH, SIDE_MAX);
		if (cfg.showPortrait.get()) {
			if (side > contentW * 0.5)
				side = contentW * 0.5;
			if (side < PORTRAIT_MIN)
				side = PORTRAIT_MIN;
		} else if (side < BAR_MIN)
			side = BAR_MIN;
		var barY:Single = origin.y + PAD + Math.max(0, (contentH - side) * 0.5);
		var barH:Single = side;
		if (cfg.showPortrait.get()) {
			drawPortrait(cfg, dl, contentX, barY, side);
			ImGui.setCursorScreenPos(origin);
			ImGui.dummy(ImGui.vec2(w, h));
			contentX = contentX + side + PORTRAIT_GAP;
			contentW = Math.max(1, origin.x + w - PAD - contentX);
		}
		var rounding:Single = Math.max(0, cfg.barRounding.get());

		if (!snap.valid) {
			drawEmptyFrame(cfg, dl, contentX, barY, contentW, barH, rounding);
			return;
		}

		var ratio = snap.healthValid ? snap.ratio : 0;
		var confirmedDead = snap.deadKnown && snap.dead;
		var fillCol = solarflare.ui.HealthColorPolicy.resolve(confirmedDead, false, snap.healthValid ? healthColor(ratio) : null);
		lastHealthDiagnostic = solarflare.ui.HealthColorPolicy.source(confirmedDead, false, snap.healthValid)
			+ (snap.healthValid ? " | health valid" : " | health unavailable: empty fill");
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

		if (snap.healthValid && !confirmedDead && cfg.lowHpPulse.get() && ratio < low) {
			var pulse = 0.5 + 0.5 * Math.sin(ImGui.getTime() * 3.2);
			var glowA = Std.int(0.18 * pulse * 255);
			var glow = (fillCol & 0x00FFFFFF) | (glowA << 24);
			ImGui.ImDrawList_AddRectFilled(dl,
				ImGui.vec2(contentX - 2, barY - 2),
				ImGui.vec2(contentX + contentW + 2, barY + barH + 2),
				glow, rounding + 2);
		}

		var border = snap.healthValid && ratio < low ? UiCol.rgb(0xFF5555) : UiCol.rgba(255, 255, 255, 0x88);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(contentX, barY), ImGui.vec2(contentX + contentW, barY + barH), border, rounding, 1.5);

		// Target cast: a smaller strip inside the bottom of the bar, over the fill.
		var castH:Single = 0;
		if (cfg.showCastBar.get() && castSnap.active) {
			castH = Math.min(Math.max(12, Math.min(28, cfg.castBarHeight.get())), barH * 0.45);
			if (castH < 8)
				castH = 0;
		}
		var castTop:Single = barY + barH - CAST_INSET - castH;
		drawBarText(cfg, dl, contentX, barY, contentW, barH, ratio, castH > 0 ? castTop : barY + barH);
		if (castH > 0)
			CastBarRenderer.drawPlainCompact(castSnap, contentX + CAST_INSET, castTop, Math.max(1, contentW - CAST_INSET * 2), castH);
	}

	/**
	 * Name, classification and HP numbers inside the bar. Tall bars stack two rows (name and badge on
	 * top, HP text centered in what is left above any cast strip); short bars share one row.
	 * `textBottom` is where the text area ends (the cast strip top while casting, else the bar bottom).
	 */
	function drawBarText(cfg:TargetConfig, dl:Dynamic, x:Single, y:Single, w:Single, barH:Single, ratio:Float, textBottom:Single):Void {
		var lineH = ImGui.getTextLineHeight();
		var innerX:Single = x + TEXT_PAD;
		var innerW:Single = Math.max(1, w - TEXT_PAD * 2);
		var showName = cfg.showName.get();
		var cls = cfg.showBadge.get() ? badgeText(snap) : "";
		var label = snap.healthValid ? buildHpLabel(cfg, snap.health, snap.maxHealth, ratio) : "HP --";
		var clsW:Single = cls.length > 0 ? ImGui.calcTextSize(cls).x : 0;
		var labelW:Single = label.length > 0 ? ImGui.calcTextSize(label).x : 0;
		var gold = UiCol.rgb(0xD6AD55);
		if (barH >= TWO_ROW_MIN) {
			var headerY:Single = y + 4;
			var hasHeader = showName || cls.length > 0;
			var regionTop:Single = hasHeader ? headerY + lineH + 2 : y + 3;
			var regionBot:Single = textBottom - 2;
			var labelFits = regionBot - regionTop >= lineH;
			var headerRight:Single = innerX + innerW;
			if (label.length > 0 && !labelFits) {
				// Not enough room for a second row: the numbers take the header row's right side.
				EnhancedText.shadowed(dl, ImGui.vec2(headerRight - labelW, headerY), label, 0xFFFFFFFF, 0xAA000000, 1, 1);
				headerRight -= labelW + 6;
				cls = "";
			} else if (label.length > 0) {
				EnhancedText.shadowed(dl, ImGui.vec2(innerX + (innerW - labelW) * 0.5, regionTop + (regionBot - regionTop - lineH) * 0.5),
					label, 0xFFFFFFFF, 0xAA000000, 1, 1);
			}
			if (cls.length > 0) {
				EnhancedText.shadowed(dl, ImGui.vec2(headerRight - clsW, headerY), cls, gold, 0xAA000000, 1, 1);
				headerRight -= clsW + 6;
			}
			if (showName) {
				var name = fitText(snap.name.length > 0 ? snap.name : "Target", Math.max(1, headerRight - innerX));
				EnhancedText.shadowed(dl, ImGui.vec2(innerX, headerY), name, 0xFFFFF0D8, 0xAA000000, 1, 1);
			}
			return;
		}
		// One row: name left, numbers right, classification between them when it fits.
		var rowY:Single = y + Math.max(1, (textBottom - y - lineH) * 0.5);
		var right = innerX + innerW;
		if (label.length > 0) {
			EnhancedText.shadowed(dl, ImGui.vec2(right - labelW, rowY), label, 0xFFFFFFFF, 0xAA000000, 1, 1);
			right -= labelW + 8;
		}
		if (showName) {
			var name = fitText(snap.name.length > 0 ? snap.name : "Target", Math.max(1, right - innerX));
			EnhancedText.shadowed(dl, ImGui.vec2(innerX, rowY), name, 0xFFFFF0D8, 0xAA000000, 1, 1);
			if (cls.length > 0) {
				var after = innerX + ImGui.calcTextSize(name).x + 8;
				if (after + clsW <= right)
					EnhancedText.shadowed(dl, ImGui.vec2(after, rowY), cls, gold, 0xAA000000, 1, 1);
			}
		} else if (cls.length > 0 && innerX + clsW <= right) {
			EnhancedText.shadowed(dl, ImGui.vec2(innerX, rowY), cls, gold, 0xAA000000, 1, 1);
		}
	}

	function drawPortrait(cfg:TargetConfig, dl:Dynamic, px:Single, py:Single, side:Single):Void {
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(px, py), ImGui.vec2(px + side, py + side), 0xCC16100E, 3);
		ImGui.pushClipRect(ImGui.vec2(px, py), ImGui.vec2(px + side, py + side), true);
		try {
			var key = snap.valid ? snap.kind : "";
			var drew = false;
			if (key.length > 0 && GameIcons.hasKey(key)) {
				ImGui.setCursorScreenPos(ImGui.vec2(px, py));
				var tw = GameIcons.texW(key);
				var th = GameIcons.texH(key);
				var u:Single = tw > th && tw > 0 ? (1 - th / tw) / 2 : 0;
				var v:Single = th > tw && th > 0 ? (1 - tw / th) / 2 : 0;
				drew = GameIcons.imageKeyUv(key, side, side, u, v, 1 - u, 1 - v);
			} else if (key.length > 0) {
				// Atlas miss: still try imageKeyUv (loose PNG); silhouette if that fails.
				ImGui.setCursorScreenPos(ImGui.vec2(px, py));
				var tw2 = GameIcons.texW(key);
				var th2 = GameIcons.texH(key);
				var u2:Single = tw2 > th2 && tw2 > 0 ? (1 - th2 / tw2) / 2 : 0;
				var v2:Single = th2 > tw2 && th2 > 0 ? (1 - tw2 / th2) / 2 : 0;
				drew = GameIcons.imageKeyUv(key, side, side, u2, v2, 1 - u2, 1 - v2);
			}
			if (!drew)
				drawSilhouette(dl, px, py, side);
		} catch (_:Dynamic) {
			try
				drawSilhouette(dl, px, py, side)
			catch (__:Dynamic) {}
		}
		ImGui.popClipRect();

		var elite = snap.valid && (snap.isBoss || snap.isMiniboss || snap.isElite);
		var trim = elite ? UiCol.rgb(0xD6AD55) : 0x88888888;
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(px - 1, py - 1), ImGui.vec2(px + side + 1, py + side + 1),
			trim, 3, elite ? 2 : 1);
		if (elite && cfg.showBadge.get()) {
			var wingY:Single = py + side * 0.25;
			for (i in 0...3) {
				var yy:Single = wingY + i * 5;
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(px, yy + 5), ImGui.vec2(px - 3, yy), trim, 2);
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(px + side, yy + 5), ImGui.vec2(px + side + 3, yy), trim, 2);
			}
		}
		if (cfg.showBadge.get() && snap.valid)
			drawLevelBadge(dl, px + side - 3, py + side - 3);
	}

	/** Dim bust so an empty portrait reads as a frame rather than a missing texture. */
	static function drawSilhouette(dl:Dynamic, px:Single, py:Single, side:Single):Void {
		var col = 0x26FFFFFF;
		var cx:Single = px + side * 0.5;
		var headR:Single = side * 0.16;
		var headY:Single = py + side * 0.37;
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, headY), headR, col, 20);
		var bodyW:Single = side * 0.54;
		var bodyTop:Single = headY + headR * 1.4;
		ImGui.ImDrawList_AddRectFilled(dl,
			ImGui.vec2(cx - bodyW * 0.5, bodyTop),
			ImGui.vec2(cx + bodyW * 0.5, py + side * 0.88), col, bodyW * 0.32);
	}

	public static var lastHealthDiagnostic:String = "";
	static function fitText(text:String, width:Single):String {
		if (ImGui.calcTextSize(text).x <= width) return text;
		while (text.length > 0 && ImGui.calcTextSize(text + "...").x > width) text = text.substr(0, text.length - 1);
		return text.length > 0 ? text + "..." : "";
	}
	function drawLevelBadge(dl:Dynamic, x:Single, y:Single):Void {
		var known = snap.valid && snap.targetLevelValid;
		var compared = known && snap.playerLevelValid;
		var delta = snap.targetLevel - snap.playerLevel;
		var col = compared ? TargetDifficulty.color(delta) : 0xFFDDDDDD;
		ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(x,y), 11, 0xEF171717, 16);
		ImGui.ImDrawList_AddCircle(dl, ImGui.vec2(x,y), 11, col, 16, 1.5);
		if (compared && TargetDifficulty.skull(delta)) {
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(x,y-2), 6, col, 12);
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x-3,y+1), ImGui.vec2(x+3,y+6), col);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(x-2,y-2), 1.5, 0xFF171717, 6);
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(x+2,y-2), 1.5, 0xFF171717, 6);
		} else {
			var label = known ? Std.string(snap.targetLevel) : "?";
			var ts = ImGui.calcTextSize(label);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(x-ts.x/2,y-ts.y/2), col, label);
		}
	}

	function drawEmptyFrame(cfg:TargetConfig, dl:Dynamic, x:Single, barY:Single, w:Single, barH:Single, rounding:Single):Void {
		if (!cfg.showEmptyBar.get()) {
			EnhancedText.shadowed(dl, ImGui.vec2(x, barY + 2), EMPTY_LABEL, 0x99AAAAAA, 0x66000000, 1, 1);
			return;
		}

		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, barY), ImGui.vec2(x + w, barY + barH), 0xAA0E1016, rounding);
		ImGui.ImDrawList_AddRectFilled(dl,
			ImGui.vec2(x + 3, barY + barH * 0.35),
			ImGui.vec2(x + w - 3, barY + barH * 0.55),
			0x22FFFFFF, 2);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(x, barY), ImGui.vec2(x + w, barY + barH), 0x66888888, rounding, 1.5);

		var showName = cfg.showName.get();
		if (showName)
			EnhancedText.shadowed(dl, ImGui.vec2(x + TEXT_PAD, barY + 4), EMPTY_LABEL, 0x99AAAAAA, 0x66000000, 1, 1);
		var emptyLabel = "";
		if (cfg.showHpText.get())
			emptyLabel = "— / —";
		if (cfg.showPercent.get())
			emptyLabel = emptyLabel.length > 0 ? emptyLabel + "  —%" : "—%";
		if (emptyLabel.length == 0) {
			if (showName)
				return;
			emptyLabel = EMPTY_LABEL;
		}
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

	static inline function lighten(color:Int, amount:Float):Int return UiCol.lighten(color, amount);

	static function formatHp(v:Float):String {
		if (v >= 1000000)
			return Std.string(Math.ffloor(v / 100000) / 10) + "M";
		if (v >= 10000)
			return Std.string(Math.ffloor(v / 100) / 10) + "k";
		return Std.string(Std.int(v));
	}

	function hudBody(size:imgui.Structs.ImVec2):Void {
		var cfg = hudCfg;
		lastBodyW = size.x;
		lastBodyH = size.y;
		drawBody(cfg, size.x, size.y);
		var hasIcon = snap.valid && snap.kind.length > 0 && GameIcons.hasKey(snap.kind);
		touchDraw(snap.valid ? "shown" : "empty", snap.name, snap.kind, hasIcon, size.x, size.y);
	}

	function hudHide():Void {
		var cfg = hudCfg;
		cfg.hidden.set(true); SettingsStore.markDirty();
	}

	function hudResize(newW:Single, newH:Single):Void {
		var cfg = hudCfg;
		cfg.width.set(Math.max(TargetConfig.MIN_W, Math.min(TargetConfig.MAX_W, newW)));
		cfg.height.set(Math.max(TargetConfig.MIN_H, Math.min(TargetConfig.MAX_H, newH)));
		SettingsStore.markDirty();
	}

	function hudWindow():Void { drawWindow(hudCfg); }
}
