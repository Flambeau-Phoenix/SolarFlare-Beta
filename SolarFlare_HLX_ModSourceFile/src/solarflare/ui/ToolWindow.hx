package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.BoolRef;

/**
 * Floating tool windows (builders, Notebook, F6 hub).
 * Geometry is ImGui/imgui.ini owned — never HudChrome.
 * Native title bar + MenuBar; the shared chrome family for every editor.
 */
class ToolWindow {
	static var lastOpen:Map<String, Bool> = new Map();
	static var forceLayoutIds:Map<String, Bool> = new Map();

	static function beginWithMenuBar(title:String, open:BoolRef, defaultW:Single = 520,
			defaultH:Single = 640, dockable:Bool = false, rememberLayout:Bool = true):Bool {
		// Native title + MenuBar — same chrome family as F6 ConfigPanel hub.
		if (open != null && !open.get()) {
			lastOpen.set(title, false);
			return false;
		}
		DockingHelper.init();
		var wasOpen = lastOpen.exists(title) && lastOpen.get(title);
		var nowOpen = open == null || open.get();
		if (nowOpen && !wasOpen)
			forceLayoutIds.set(title, true);
		lastOpen.set(title, nowOpen);
		var force = !rememberLayout && forceLayoutIds.exists(title) && forceLayoutIds.get(title);
		var sizeCond = force ? ImGuiCond.Always : ImGuiCond.FirstUseEver;
		ImGui.setNextWindowSize(ImGui.vec2(defaultW, defaultH), sizeCond);
		var minW:Single = defaultW >= 1000 ? 960 : 520;
		var minH:Single = defaultH >= 700 ? 640 : 400;
		ImGui.setNextWindowSizeConstraints(ImGui.vec2(minW, minH), ImGui.vec2(2400, 1600));
		{
			try {
				var vp = ImGui.getMainViewport();
				if (vp != null) {
					var c = ImGui.ImGuiViewport_GetCenter(vp);
					if (c != null)
						ImGui.setNextWindowPos(ImGui.vec2(c.x - defaultW * 0.5, c.y - defaultH * 0.5), sizeCond);
				}
			} catch (_:Dynamic) {}
			forceLayoutIds.set(title, false);
		}
		var flags = CursorCaptureFix.windowFlags(ImGuiWindowFlags.MenuBar | ImGuiWindowFlags.NoCollapse);
		if (!dockable)
			flags |= ImGuiWindowFlags.NoDocking;
		UiChrome.pushCelShade();
		ImGui.pushStyleVar(ImGuiStyleVar.WindowTitleAlign, ImGui.vec2(0.5, 0.5));
		var shown = ImGui.begin(title, open, flags);
		ImGui.popStyleVar();
		return shown;
	}

	/** Callback-owned menu-bar tool window with the same balance guarantee. */
	public static function drawMenuWindow(title:String, open:BoolRef,
			defaultW:Single, defaultH:Single, body:Void->Void,
			dockable:Bool = false, rememberLayout:Bool = true):Void {
		if (open != null && !open.get())
			return;

		var shown = beginWithMenuBar(title, open, defaultW, defaultH,
			dockable, rememberLayout);
		var failed = false;
		var failure:Dynamic = null;
		if (shown && body != null) {
			try {
				body();
			} catch (e:Dynamic) {
				failed = true;
				failure = e;
			}
		}
		end();
		if (failed)
			UiScope.report("menu tool window", title, failure);
	}

	static function end():Void {
		ImGui.end();
		UiChrome.popCelShade();
	}

}
