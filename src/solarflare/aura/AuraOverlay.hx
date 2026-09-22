package solarflare.aura;

import solarflare.ui.HudChrome;
import solarflare.ui.CursorCaptureFix;
import solarflare.ui.SettingsStore;
import solarflare.ui.ToastManager;
import solarflare.aura.ui.AuraTimerBoard;
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
		AuraVisualRenderer.countdownAll = cfg.countdownAll.get();
		AuraVisualRenderer.countdownCeiling = cfg.countdownAutoMax.get();
		AuraVisualRenderer.countdownGlobalScale = Math.max(0.5, Math.min(3, cfg.countdownScale.get()));
		theme.wrap(() -> {
			for (a in cfg.auras) {
				try
					drawOne(a)
				catch (_:Dynamic) {}
			}
		});
		AuraTimerBoard.openBuilder = openBuilder;
		try
			AuraTimerBoard.draw(cfg)
		catch (_:Dynamic) {}
	}

	public var openBuilder:Void->Void;
	function drawOne(a:AuraDef):Void {
		if (a == null || !a.enabled.get()) return;
		// A window that is individually locked must hide when conditions are not met,
		// regardless of the global unlockAll flag (which defaults to true and would
		// otherwise keep every window visible as a ghost even when locked).
		var indivLocked = a.chrome != null && a.chrome.locked.get();
		var layout = cfg.unlockAll.get() || !indivLocked;
		if (!a.show && indivLocked) return;
		// Unlocked windows in layout mode stay visible as a ghost so the author can
		// see and reposition them even when the condition is not active.
		if (!a.show && !layout) return;
		if (a.alertShow) drawAlert(a);
		var sc:Single = Math.max(0.4, Math.min(2.5, a.scale.get()));
		var w:Single = Math.max(24, a.w.get() * sc);
		var h:Single = Math.max(24, a.h.get() * sc);
		solarflare.ui.HUDWidgetWindow.draw("SolarFlare Aura " + a.id, a.displayLabel(), a.chrome, w, h, function(size) {
			var p = ImGui.getCursorScreenPos();
			ImGui.dummy(size);
			var dl = ImGui.getWindowDrawList();
			drawRegion(dl, a, p.x, p.y, size.x, size.y, !a.show && layout);
			drawKeyChip(dl, p.x, p.y, size.x, size.y, a, !a.show && layout);
		}, openBuilder, function() { a.enabled.set(false); SettingsStore.markDirty(); }, cfg.unlockAll.get(), function() {
			if (a.isCounter.get() && ImGui.menuItem("Reset Counter")) {
				a.counterValue = 0;
				a.stacks = 1;
				SettingsStore.markDirty();
			}
		}, function(newW:Single, newH:Single) {
			a.w.set(Math.max(24, newW) / sc);
			a.h.set(Math.max(24, newH) / sc);
			SettingsStore.markDirty();
		});
	}

	function drawRegion(dl:Dynamic, a:AuraDef, x:Single, y:Single, w:Single, h:Single, ghost:Bool):Void {
		AuraVisualRenderer.draw(dl, a, x, y, w, h, a.progress, a.stacks, a.counterValue, ghost, a.fxAlpha);
	}

	function drawAlert(a:AuraDef):Void {
		// Large typed alert is the only live text-alert channel; off = no draw.
		if (a.showBanner == null || !a.showBanner.get())
			return;
		var msg = a.bannerText != null && StringTools.trim(a.bannerText).length > 0
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
			var scale:Single = a.bannerScale != null ? a.bannerScale.get() : 1.15;
			if (scale < 1) scale = 1;
			if (scale > 3) scale = 3;
			ImGui.pushFont(ImGui.getFont(), ImGui.getFontSize() * (1.75 + scale));
			ImGui.textColored(ImGui.vec4(1, 0.92, 0.45, opacity), msg);
			ImGui.popFont();
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
