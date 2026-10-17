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
	/** Cached callbacks; current UI configuration and frozen snaps are refreshed per draw. */
	var hudAura:AuraDef;
	var hudAllFn:Void->Void;
	var hudBodyFn:imgui.Structs.ImVec2->Void;
	var hudHideFn:Void->Void;
	var hudQuickActionsFn:Void->Void;
	var hudResizeFn:Single->Single->Void;

	static inline var FLAGS:Int = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse
		| ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse
		| ImGuiWindowFlags.NoBackground;

	var cfg:AuraConfig;
	var theme:Theme;
	var visualBounds = new solarflare.ui.HUDVisualBounds();

	/** Dynamic groups: reused per frame so drawing a group allocates nothing once warmed up. */
	var hudGroup:AuraGroupDef;
	var hudGroupBodyFn:imgui.Structs.ImVec2->Void;
	var hudGroupHideFn:Void->Void;
	var hudGroupResizeFn:Single->Single->Void;
	var groupMembers:Array<AuraDef> = [];
	var groupW:Array<Float> = [];
	var groupH:Array<Float> = [];
	var groupLayout = new AuraGroupLayout();
	var groupBounds = new solarflare.ui.HUDVisualBounds();
	var memberBounds = new solarflare.ui.HUDVisualBounds();

	public function new(cfg:AuraConfig) {
		hudBodyFn = hudBody;
		hudHideFn = hudHide;
		hudQuickActionsFn = hudQuickActions;
		hudResizeFn = hudResize;

		hudAllFn = hudAll;
		hudGroupBodyFn = hudGroupBody;
		hudGroupHideFn = hudGroupHide;
		hudGroupResizeFn = hudGroupResize;
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
		theme.wrap(hudAllFn);
		AuraTimerBoard.openBuilder = openBuilder;
		try
			AuraTimerBoard.draw(cfg)
		catch (_:Dynamic) {}
	}

	public var openBuilder:Void->Void;
	function drawOne(a:AuraDef):Void {
		if (a == null || !a.enabled.get()) return;
		// Typed alerts are independent of the ordinary face's visibility / layout lock.
		if (a.alertShow) drawAlert(a);
		if (!a.visual.get()) return;
		// Group members are drawn by their group's window.
		if (a.group != null && a.group.length > 0 && cfg.findGroup(a.group) != null) return;
		// A window that is individually locked must hide when conditions are not met,
		// regardless of the legacy global unlock flag.
		var indivLocked = a.chrome != null && a.chrome.locked.get();
		var layout = !indivLocked;
		if (!a.show && indivLocked) return;
		// Unlocked windows in layout mode stay visible as a ghost so the author can
		// see and reposition them even when the condition is not active.
		if (!a.show && !layout) return;
		var sc:Single = Math.max(0.4, Math.min(2.5, a.scale.get()));
		var w:Single = Math.max(24, a.w.get() * sc);
		var h:Single = Math.max(24, a.h.get() * sc);
		AuraVisualRenderer.measureBounds(a, w, h, a.stacks, a.counterValue, visualBounds, sc);
		hudAura = a;
		solarflare.ui.HUDWidgetWindow.draw("SolarFlare Aura " + a.id, a.displayLabel(), a.chrome, w, h, hudBodyFn, openBuilder, hudHideFn, false, hudQuickActionsFn, hudResizeFn, visualBounds);
		hudAura = null;
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
		if (a.chrome != null && a.chrome.locked.get())
			flags |= ImGuiWindowFlags.NoInputs;
		var ax:Single = a.chrome != null ? a.chrome.x.get() : 200;
		var ay:Single = a.chrome != null ? a.chrome.y.get() - 28 : 172;
		ImGui.setNextWindowPos(ImGui.vec2(ax, ay), ImGuiCond.Always);
		ImGui.setNextWindowBgAlpha(0.72 * opacity);
		var began = ImGui.begin("SolarFlare AuraAlert " + a.id, null, flags);
		var fontPushed = false;
		try {
			if (began) {
				var scale:Single = a.bannerScale != null ? a.bannerScale.get() : 1.15;
				if (scale < 1) scale = 1;
				if (scale > 3) scale = 3;
				ImGui.pushFont(ImGui.getFont(), ImGui.getFontSize() * (1.75 + scale));
				fontPushed = true;
				ImGui.textColored(ImGui.vec4(1, 0.92, 0.45, opacity), msg);
			}
		} catch (_:Dynamic) {}
		if (fontPushed) ImGui.popFont();
		ImGui.end();
	}


	function hudAll():Void {
		for (a in cfg.auras) {
			try drawOne(a) catch (_:Dynamic) {}
		}
		for (g in cfg.groups) {
			try drawGroup(g) catch (_:Dynamic) {}
		}
	}

	static inline function memberScale(a:AuraDef, g:AuraGroupDef):Single {
		return Math.max(0.4, Math.min(2.5, a.scale.get())) * g.scale;
	}

	static function byTime(a:AuraDef, b:AuraDef):Int {
		var c = AuraGroupLayout.compareTime(a.timerInfinite, a.timeLeft, b.timerInfinite, b.timeLeft);
		return c != 0 ? c : Reflect.compare(a.id, b.id);
	}

	/**
	 * One window per group. Locked: only showing members, packed so gaps close. Unlocked: every member,
	 * non-showing ones as ghosts, so the author sees and positions the full footprint.
	 */
	function drawGroup(g:AuraGroupDef):Void {
		if (g == null) return;
		var chrome = cfg.groupChrome(g);
		var layout = !chrome.locked.get();
		groupMembers.splice(0, groupMembers.length);
		for (a in cfg.auras) {
			if (a == null || a.group != g.id || !a.enabled.get() || !a.visual.get()) continue;
			if (!a.show && !layout) continue;
			groupMembers.push(a);
		}
		var n = groupMembers.length;
		if (n == 0) return;
		if (g.sort == "time") groupMembers.sort(byTime);
		for (i in 0...n) {
			var a = groupMembers[i];
			var sc = memberScale(a, g);
			setAt(groupW, i, Math.max(24, a.w.get() * sc));
			setAt(groupH, i, Math.max(24, a.h.get() * sc));
		}
		groupLayout.compute(groupW, groupH, n, g.grow, g.wrap, g.spacing * g.scale, g.align);
		groupBounds.reset(groupLayout.totalW, groupLayout.totalH);
		for (i in 0...n) {
			var a = groupMembers[i];
			AuraVisualRenderer.measureBounds(a, groupW[i], groupH[i], a.stacks, a.counterValue, memberBounds, memberScale(a, g));
			groupBounds.include(groupLayout.xs[i] + memberBounds.minX, groupLayout.ys[i] + memberBounds.minY,
				memberBounds.width(), memberBounds.height());
		}
		hudGroup = g;
		try
			solarflare.ui.HUDWidgetWindow.draw("SolarFlare AuraGroup " + g.id, g.name, chrome, groupLayout.totalW, groupLayout.totalH,
				hudGroupBodyFn, openBuilder, hudGroupHideFn, false, null, hudGroupResizeFn, groupBounds)
		catch (e:Dynamic) { hudGroup = null; throw e; }
		hudGroup = null;
	}

	function hudGroupBody(size:imgui.Structs.ImVec2):Void {
		var g = hudGroup;
		var layout = !cfg.groupChrome(g).locked.get();
		var p = ImGui.getCursorScreenPos();
		ImGui.dummy(size);
		var dl = ImGui.getWindowDrawList();
		for (i in 0...groupLayout.count) {
			var a = groupMembers[i];
			var x:Single = p.x + groupLayout.xs[i];
			var y:Single = p.y + groupLayout.ys[i];
			var ghost = !a.show && layout;
			AuraVisualRenderer.draw(dl, a, x, y, groupW[i], groupH[i], a.progress, a.stacks, a.counterValue, ghost,
				a.fxAlpha * g.opacity, memberScale(a, g));
			AuraVisualRenderer.drawKeyChip(dl, x, y, groupW[i], groupH[i], a, ghost);
		}
	}

	/** Window menu Hide: turns every member off, like Hide on a single aura. */
	function hudGroupHide():Void {
		var g = hudGroup;
		for (a in cfg.auras)
			if (a != null && a.group == g.id)
				a.enabled.set(false);
		SettingsStore.markDirty();
	}

	/** Dragging the grip scales the whole group. */
	function hudGroupResize(newW:Single, newH:Single):Void {
		var g = hudGroup;
		if (g == null || groupLayout.totalW < 1) return;
		g.scale = Math.max(0.25, Math.min(4, g.scale * (newW / groupLayout.totalW)));
		SettingsStore.markDirty();
	}

	static inline function setAt(arr:Array<Float>, i:Int, v:Float):Void {
		if (i < arr.length) arr[i] = v; else arr.push(v);
	}

	function hudBody(size:imgui.Structs.ImVec2):Void {
		var a = hudAura;
		var sc:Single = Math.max(0.4, Math.min(2.5, a.scale.get()));
		var layout = a.chrome == null || !a.chrome.locked.get();
		var p = ImGui.getCursorScreenPos();
		ImGui.dummy(size);
		var dl = ImGui.getWindowDrawList();
		AuraVisualRenderer.draw(dl, a, p.x, p.y, size.x, size.y, a.progress, a.stacks,
			a.counterValue, !a.show && layout, a.fxAlpha, sc);
		AuraVisualRenderer.drawKeyChip(dl, p.x, p.y, size.x, size.y, a, !a.show && layout);
	}

	function hudHide():Void {
		var a = hudAura;
		a.enabled.set(false); SettingsStore.markDirty();
	}

	function hudQuickActions():Void {
		var a = hudAura;
		if (a.isCounter.get() && ImGui.menuItem("Reset Counter")) {
			a.counterValue = 0;
			SettingsStore.markDirty();
		}
	}

	function hudResize(newW:Single, newH:Single):Void {
		var a = hudAura;
		var sc:Single = Math.max(0.4, Math.min(2.5, a.scale.get()));
		a.w.set(Math.max(24, newW) / sc);
		a.h.set(Math.max(24, newH) / sc);
		SettingsStore.markDirty();
	}
}
