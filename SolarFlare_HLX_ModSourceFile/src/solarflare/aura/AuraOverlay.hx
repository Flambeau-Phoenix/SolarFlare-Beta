package solarflare.aura;

import solarflare.ui.HudChrome;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.SettingsStore;
import solarflare.ui.ToastManager;
import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Theme;

class AuraOverlay {
	static inline var FLAGS:Int = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse
		| ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse
		| ImGuiWindowFlags.NoBackground;

	var cfg:AuraConfig;
	var theme:Theme;

	public function new(cfg:AuraConfig) {
		this.cfg = cfg;
		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(2, 2))
			.varF(ImGuiStyleVar.WindowRounding, 0)
			.varF(ImGuiStyleVar.WindowBorderSize, 0)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0, 0, 0, 0))
			.color(ImGuiCol.ResizeGrip, ImGui.vec4(0.35, 0.40, 0.48, 0.55));
	}

	public function draw():Void {
		if (cfg == null || !cfg.enabled.get())
			return;
		theme.wrap(() -> {
			for (a in cfg.auras) {
				try
					drawOne(a)
				catch (_:Dynamic) {}
			}
		});
	}

	function drawOne(a:AuraDef):Void {
		if (a == null || !a.enabled.get())
			return;
		var layout = cfg.unlockAll.get() || (a.chrome != null && !a.chrome.locked.get());
		if (!a.show && !layout && !a.alertShow)
			return;
		if (a.alertShow)
			drawAlert(a);
		if (!a.show && !layout)
			return;
		var sc:Single = a.scale != null ? a.scale.get() : 1;
		if (sc < 0.4)
			sc = 0.4;
		if (sc > 2.5)
			sc = 2.5;
		var w:Single = a.w.get() * sc;
		var h:Single = a.h.get() * sc;
		if (w < 24)
			w = 24;
		if (h < 24)
			h = 24;
		ImGui.setNextWindowBgAlpha(0);
		ImGui.setNextWindowSizeConstraints(ImGui.vec2(24, 24), ImGui.vec2(720 * sc, 480 * sc));
		if (a.chrome != null && a.chrome.takeExpandDirty())
			a.sizeDirty = true;
		if (a.sizeDirty) {
			ImGui.setNextWindowSize(ImGui.vec2(w, h), ImGuiCond.Always);
			a.sizeDirty = false;
		} else
			ImGui.setNextWindowSize(ImGui.vec2(w, h), ImGuiCond.FirstUseEver);
		if (a.chrome != null) {
			a.chrome.clampToViewport();
			a.chrome.applyPos();
		}
		var flags = CursorCaptureFix.windowFlags(FLAGS);
		if (a.chrome != null) {
			var wasLocked = a.chrome.locked.get();
			if (cfg.unlockAll.get())
				a.chrome.locked.set(false);
			flags = a.chrome.windowFlags(FLAGS);
			a.chrome.locked.set(wasLocked);
		}
		flags |= ImGuiWindowFlags.NoSavedSettings;
		var began = ImGui.begin("SolarFlare Aura " + a.id, null, flags);
		if (began) {
			var win = ImGui.getWindowSize();
			if (a.chrome != null && !a.chrome.isLocked()) {
				a.chrome.capturePos();
				var baseW = a.w.get();
				var baseH = a.h.get();
				if (sc > 0.05) {
					var logicW = win.x / sc;
					var logicH = win.y / sc;
					if (Math.abs(logicW - baseW) > 1 || Math.abs(logicH - baseH) > 1) {
						a.w.set(logicW);
						a.h.set(logicH);
						SettingsStore.markDirty();
					}
				}
			}
			w = win.x;
			h = win.y;
			var showBody = a.chrome == null || a.chrome.beginBody(function() {
				a.enabled.set(false);
				SettingsStore.markDirty();
			}, null, a.displayLabel());
			if (showBody) {
				var origin = ImGui.getCursorScreenPos();
				var avail = ImGui.getContentRegionAvail();
				var bodyW:Single = avail.x > 1 ? avail.x : w;
				var bodyH:Single = avail.y > 1 ? avail.y : h;
				// Invisible hit target first — grows hm_body before any SetCursorScreenPos icons.
				ImGui.invisibleButton("##aura_hit_" + a.id, ImGui.vec2(bodyW, bodyH));
				var rmin = ImGui.getItemRectMin();
				var rw = ImGui.getItemRectSize().x;
				var rh = ImGui.getItemRectSize().y;
				if (rw < 1) rw = bodyW;
				if (rh < 1) rh = bodyH;

				if (CursorCaptureFix.cursorFree) {
					if (ImGui.isItemClicked(1)) {
						ImGui.openPopup("sf_aura_live_pop_" + a.id);
					}
					if (ImGui.beginPopup("sf_aura_live_pop_" + a.id)) {
						ImGui.separatorText('${a.name}');
						if (a.chrome != null && ImGui.checkbox("Lock Aura##la_lock_" + a.id, a.chrome.locked)) {
							SettingsStore.markDirty();
							ToastManager.info(a.chrome.locked.get() ? '${a.name} locked' : '${a.name} unlocked');
						}
						if (ImGui.checkbox("Enable Aura##la_en_" + a.id, a.enabled)) {
							SettingsStore.markDirty();
							ToastManager.info(a.enabled.get() ? '${a.name} enabled' : '${a.name} disabled');
						}
						if (a.isCounter.get() && ImGui.menuItem("Reset Counter##la_rst_" + a.id)) {
							a.counterValue = 0; a.stacks = 1;
							SettingsStore.markDirty();
							ToastManager.info('${a.name} counter reset');
						}
						ImGui.separator();
						if (ImGui.menuItem("Hide Aura##la_cls_" + a.id)) {
							a.enabled.set(false);
							SettingsStore.markDirty();
							ToastManager.info('${a.name} hidden');
						}
						ImGui.endPopup();
					}
				}

				var dl = ImGui.getWindowDrawList();
				drawRegion(dl, a, rmin.x, rmin.y, rw, rh, !a.show && layout);
				drawKeyChip(dl, rmin.x, rmin.y, rw, rh, a, !a.show && layout);
				// Keep layout cursor at the end of reserved content (no stray SetCursor beyond).
				ImGui.setCursorScreenPos(ImGui.vec2(origin.x, origin.y + rh));
				ImGui.dummy(ImGui.vec2(0.01, 0.01));
			}
		}
		HudChrome.endOverlayWindow(began, a.chrome);
	}

	function drawRegion(dl:Dynamic, a:AuraDef, x:Single, y:Single, w:Single, h:Single, ghost:Bool):Void {
		AuraVisualRenderer.draw(dl, a, x, y, w, h, a.progress, a.stacks, a.counterValue, ghost, a.fxAlpha);
	}

	function drawAlert(a:AuraDef):Void {
		var large = a.showBanner != null && a.showBanner.get();
		var msg = large && a.bannerText != null && StringTools.trim(a.bannerText).length > 0
			? a.bannerText : (a.alertText != null && a.alertText.length > 0 ? a.alertText : a.displayLabel());
		var opacity:Single = a.opacity != null ? a.opacity.get() : 1;
		if (opacity < 0) opacity = 0;
		if (opacity > 1) opacity = 1;
		var flags = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoScrollbar
			| ImGuiWindowFlags.NoCollapse | ImGuiWindowFlags.NoSavedSettings | ImGuiWindowFlags.AlwaysAutoResize;
		flags = CursorCaptureFix.windowFlags(flags);
		if (a.chrome != null && a.chrome.locked.get() && !cfg.unlockAll.get())
			flags |= ImGuiWindowFlags.NoInputs;
		var ax:Single = a.chrome != null ? a.chrome.x.get() : 200;
		var ay:Single = a.chrome != null ? a.chrome.y.get() - 28 : 172;
		ImGui.setNextWindowPos(ImGui.vec2(ax, ay), ImGuiCond.Always);
		ImGui.setNextWindowBgAlpha(0.72 * opacity);
		if (ImGui.begin("SolarFlare AuraAlert " + a.id, null, flags)) {
			if (large) {
				var scale:Single = a.bannerScale != null ? a.bannerScale.get() : 1.15;
				if (scale < 1) scale = 1;
				if (scale > 3) scale = 3;
				ImGui.pushFont(ImGui.getFont(), ImGui.getFontSize() * (1.75 + scale));
				ImGui.textColored(ImGui.vec4(1, 0.92, 0.45, opacity), msg);
				ImGui.popFont();
			} else
				ImGui.textColored(ImGui.vec4(1, 0.92, 0.45, opacity), msg);
			ImGui.end();
		}
	}

	/** Geaux-style key chip: dark plate + cream text on the aura face. */
	function drawKeyChip(dl:Dynamic, x:Single, y:Single, w:Single, h:Single, a:AuraDef, ghost:Bool):Void {
		if (a == null || a.showKey == null || !a.showKey.get())
			return;
		var hk = AuraDef.sanitizeKey(a.keyText);
		if (hk.length == 0)
			return;
		var size:Single = w < h ? w : h;
		var fontSize:Single = Math.max(ImGui.getFontSize() * 1.05, size * 0.28);
		if (fontSize > 22)
			fontSize = 22;
		if (fontSize < 12)
			fontSize = 12;
		ImGui.pushFont(ImGui.getFont(), fontSize);
		var ts = ImGui.calcTextSize(hk);
		var padX:Single = Math.max(4, size * 0.06);
		var padY:Single = Math.max(2, size * 0.04);
		var tx:Single = x + 3;
		var ty:Single = y + 2;
		var bx0:Single = tx - 1;
		var by0:Single = ty - 1;
		var bx1:Single = tx + ts.x + padX;
		var by1:Single = ty + ts.y + padY;
		var lit = !ghost;
		var plateA:Single = lit ? 0.88 : 0.55;
		ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(bx0, by0), ImGui.vec2(bx1, by1),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.02, 0.02, 0.03, plateA)), 4);
		ImGui.ImDrawList_AddRect(dl, ImGui.vec2(bx0, by0), ImGui.vec2(bx1, by1),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(1, 1, 1, lit ? 0.35 : 0.18)), 4, 1);
		var textCol = lit ? ImGui.vec4(1, 0.96, 0.78, 1) : ImGui.vec4(0.78, 0.76, 0.70, 0.75);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx + 1, ty + 1),
			ImGui.colorConvertFloat4ToU32(ImGui.vec4(0, 0, 0, 0.95)), hk);
		ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(tx, ty), ImGui.colorConvertFloat4ToU32(textCol), hk);
		ImGui.popFont();
	}
}
