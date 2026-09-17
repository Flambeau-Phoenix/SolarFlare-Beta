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
	static inline var PAD:Single = 4;
	static inline var NAME_H:Single = 18;
	static inline var SUB_H:Single = 16;
	/** The bar is a bar, not a slab: it never grows to fill a tall frame. */
	static inline var BAR_MIN:Single = 12;
	static inline var BAR_MAX:Single = 30;
	static inline var PORTRAIT_MIN:Single = 24;
	static inline var PORTRAIT_MAX:Single = 128;

	var theme:Theme;
	var snap:TargetSnap;

	public function new() {
		snap = new TargetSnap();
		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(6, 4))
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

	public function drawPreview(cfg:TargetConfig, sample:TargetSnap, w:Single, h:Single):Void {
		var diagnostic = lastHealthDiagnostic;
		snap.copyFrom(sample);
		drawBody(cfg, w, h);
		lastHealthDiagnostic = diagnostic;
	}
	public var openBuilder:Void->Void;
	function drawWindow(cfg:TargetConfig):Void {
		var w:Single = Math.max(TargetConfig.MIN_W, Math.min(TargetConfig.MAX_W, cfg.width.get()));
		var h:Single = Math.max(TargetConfig.MIN_H, Math.min(TargetConfig.MAX_H, cfg.height.get()));
		solarflare.ui.HUDWidgetWindow.draw("SolarFlare Target", "Target", cfg.chrome, w, h, function(size) {
			drawBody(cfg, size.x, size.y);
		}, openBuilder, function() { cfg.hidden.set(true); SettingsStore.markDirty(); }, false, null, function(newW:Single, newH:Single) {
			cfg.width.set(Math.max(TargetConfig.MIN_W, Math.min(TargetConfig.MAX_W, newW)));
			cfg.height.set(Math.max(TargetConfig.MIN_H, Math.min(TargetConfig.MAX_H, newH)));
			SettingsStore.markDirty();
		});
	}

	function drawBody(cfg:TargetConfig, w:Single, h:Single):Void {
		var dl = ImGui.getWindowDrawList();
		var origin = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(w, h));

		var contentH:Single = Math.max(8, h - PAD * 2);
		var contentX:Single = origin.x + PAD;
		var contentW:Single = Math.max(1, w - PAD * 2);

		if (cfg.showPortrait.get()) {
			// Square, sized to the frame, so a tall frame has no dead space beside it.
			var side:Single = contentH;
			if (side > PORTRAIT_MAX)
				side = PORTRAIT_MAX;
			if (side > contentW * 0.5)
				side = contentW * 0.5;
			if (side < PORTRAIT_MIN)
				side = PORTRAIT_MIN;
			drawPortrait(cfg, dl, contentX, origin.y + PAD, side);
			// drawPortrait submits the image item and leaves the cursor inside the
			// portrait. Re-assert the box from a real item here, before any early
			// return below: ImGui must never grow a parent off a bare cursor move.
			ImGui.setCursorScreenPos(origin);
			ImGui.dummy(ImGui.vec2(w, h));
			contentX = contentX + side + PORTRAIT_GAP;
			contentW = Math.max(1, origin.x + w - PAD - contentX);
		}

		var nameH:Single = cfg.showName.get() ? NAME_H : 0;
		var classification = snap.valid ? badgeText(snap) : "";
		var subH:Single = (cfg.showBadge.get() && classification.length > 0) ? SUB_H : 0;
		var headerH:Single = nameH + subH;
		var gap:Single = headerH > 0 ? 3 : 0;
		var barH:Single = contentH - headerH - gap;
		if (barH > BAR_MAX)
			barH = BAR_MAX;
		if (barH < BAR_MIN)
			barH = BAR_MIN;
		// Header + bar travel together, centred against the portrait.
		var blockH:Single = headerH + gap + barH;
		var blockY:Single = origin.y + PAD + Math.max(0, (contentH - blockH) * 0.5);
		var barY:Single = blockY + headerH + gap;
		var rounding:Single = Math.max(0, cfg.barRounding.get());

		if (!snap.valid) {
			drawEmptyFrame(cfg, dl, contentX, blockY, contentW, nameH, barY, barH, rounding);
			return;
		}

		if (cfg.showName.get()) {
			var name = fitText(snap.name.length > 0 ? snap.name : "Target", contentW);
			EnhancedText.shadowed(dl, ImGui.vec2(contentX, blockY), name, 0xFFFFF0D8, 0xAA000000, 1, 1);
		}
		if (cfg.showBadge.get() && classification.length > 0) {
			EnhancedText.shadowed(dl, ImGui.vec2(contentX, blockY + nameH), fitText(classification, contentW), UiCol.rgb(0xD6AD55), 0xAA000000, 1, 1);
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

		var label = snap.healthValid ? buildHpLabel(cfg, snap.health, snap.maxHealth, ratio) : "HP --";
		if (label.length > 0) {
			var ts = ImGui.calcTextSize(label);
			EnhancedText.shadowed(dl,
				ImGui.vec2(contentX + (contentW - ts.x) * 0.5, barY + (barH - ts.y) * 0.5),
				label, 0xFFFFFFFF, 0xAA000000, 1, 1);
		}
	}

	function drawPortrait(cfg:TargetConfig, dl:Dynamic, px:Single, py:Single, side:Single):Void {
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(px, py), ImGui.vec2(px + side, py + side), 0xCC16100E, 3);
		ImGui.pushClipRect(ImGui.vec2(px, py), ImGui.vec2(px + side, py + side), true);
		var failure:Dynamic = null;
		try {
			if (snap.valid && snap.kind.length > 0) {
				ImGui.setCursorScreenPos(ImGui.vec2(px, py));
				var tw = GameIcons.texW(snap.kind);
				var th = GameIcons.texH(snap.kind);
				var u:Single = tw > th && tw > 0 ? (1 - th / tw) / 2 : 0;
				var v:Single = th > tw && th > 0 ? (1 - tw / th) / 2 : 0;
				GameIcons.imageKeyUv(snap.kind, side, side, u, v, 1 - u, 1 - v);
			} else {
				drawSilhouette(dl, px, py, side);
			}
		} catch (e:Dynamic) { failure = e; }
		ImGui.popClipRect();
		if (failure != null) throw failure;

		var elite = snap.valid && (snap.isBoss || snap.isMiniboss || snap.isElite);
		var trim = elite ? UiCol.rgb(0xD6AD55) : 0x88888888;
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(px - 1, py - 1), ImGui.vec2(px + side + 1, py + side + 1),
			trim, 3, elite ? 2 : 1);
		if (elite && cfg.showBadge.get()) {
			// Symmetric wing trim outside the portrait's clip.
			var wingY:Single = py + side * 0.25;
			for (i in 0...3) {
				var yy:Single = wingY + i * 5;
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(px, yy + 5), ImGui.vec2(px - 3, yy), trim, 2);
				ImGui.ImDrawList_AddLine(dl, ImGui.vec2(px + side, yy + 5), ImGui.vec2(px + side + 3, yy), trim, 2);
			}
		}
		// A level badge with nothing to report just reads as a stray "?".
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
			// Vector skull avoids depending on a font's Unicode glyph coverage.
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

	function drawEmptyFrame(cfg:TargetConfig, dl:Dynamic, x:Single, blockY:Single, w:Single,
			nameH:Single, barY:Single, barH:Single, rounding:Single):Void {
		if (nameH > 0)
			EnhancedText.shadowed(dl, ImGui.vec2(x, blockY), EMPTY_LABEL, 0x99AAAAAA, 0x66000000, 1, 1);

		if (!cfg.showEmptyBar.get()) {
			// Nothing else would render — keep the label wherever there is room.
			if (nameH == 0)
				EnhancedText.shadowed(dl, ImGui.vec2(x, barY), EMPTY_LABEL, 0x99AAAAAA, 0x66000000, 1, 1);
			return;
		}

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
