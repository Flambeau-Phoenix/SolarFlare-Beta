package solarflare.ui;

import solarflare.ui.GameIcons;
import solarflare.ui.HudChrome;
import solarflare.ui.SettingsStore;
import imgui.ImGui;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiStyleVar;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Theme;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;
import sys.FileSystem;
import sys.io.File;

/**
 * Frameless art buttons: F6 MENU plaque, F7 square RiftMods.
 * BlankButton.png is GetRifty / Local Time only — never a menu opener.
 */
class LauncherSpec {
	public var hidden:BoolRef;
	public var size:FloatRef;
	public var sizeDirty:Bool;
	public var chrome:HudChrome;

	public function new(x0:Single, y0:Single, sz:Single) {
		hidden = new BoolRef(false);
		size = new FloatRef(sz);
		sizeDirty = true;
		chrome = new HudChrome(x0, y0);
	}
}

class HudLaunchers {
	static inline var FLAGS:Int = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse
		| ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse
		| ImGuiWindowFlags.NoBackground;
	public static inline var NOTE_MIN:Single = 48;
	public static inline var NOTE_MAX:Single = 220;
	/** F6 MENU is a wide plaque; slider is width. */
	public static inline var F6_MIN:Single = 80;
	public static inline var F6_MAX:Single = 240;
	public static inline var F6_DEFAULT:Single = 165;
	/** F7 RiftMods is square. */
	public static inline var F7_MIN:Single = 48;
	public static inline var F7_MAX:Single = 160;
	public static inline var F7_DEFAULT:Single = 72;
	public static inline var CFG_MIN:Single = F7_MIN;
	public static inline var CFG_MAX:Single = F7_MAX;

	public var f6:LauncherSpec;
	public var f7:LauncherSpec;
	var theme:Theme;

	public function new() {
		f6 = new LauncherSpec(80, 480, F6_DEFAULT);
		f7 = new LauncherSpec(260, 480, F7_DEFAULT);
		theme = new Theme()
			.varV(ImGuiStyleVar.WindowPadding, ImGui.vec2(0, 0))
			.varF(ImGuiStyleVar.WindowRounding, 0)
			.varF(ImGuiStyleVar.WindowBorderSize, 0)
			.color(ImGuiCol.WindowBg, ImGui.vec4(0, 0, 0, 0))
			.color(ImGuiCol.Border, ImGui.vec4(0, 0, 0, 0))
			.color(ImGuiCol.ResizeGrip, ImGui.vec4(0.35, 0.40, 0.48, 0.45));
	}

	public function dump():Dynamic {
		return {
			f6: specDump(f6),
			f7: specDump(f7)
		};
	}

	public function apply(data:Dynamic):Void {
		if (data == null)
			return;
		applySpec(f6, data.f6);
		applySpec(f7, data.f7);
	}

	static function specDump(s:LauncherSpec):Dynamic {
		if (s == null)
			return {};
		var c = s.chrome;
		return {
			hidden: s.hidden.get(),
			size: s.size.get(),
			chrome: c == null ? {} : {
				lock: c.locked.get(),
				trans: c.transparent.get(),
				sun: c.showGrip.get(),
				collapsed: c.collapsed.get(),
				x: c.x.get(),
				y: c.y.get()
			}
		};
	}

	static function applySpec(s:LauncherSpec, data:Dynamic):Void {
		if (s == null || data == null)
			return;
		try
			if (data.hidden != null)
				s.hidden.set(data.hidden == true)
		catch (_:Dynamic) {}
		try {
			if (data.size != null) {
				s.size.set(data.size);
				s.sizeDirty = true;
			}
		} catch (_:Dynamic) {}
		var ch = data.chrome;
		if (s.chrome != null && ch != null) {
			try
				if (ch.collapsed != null)
					s.chrome.collapsed.set(ch.collapsed == true)
			catch (_:Dynamic) {}
			try
				if (ch.lock != null)
					s.chrome.locked.set(ch.lock == true)
			catch (_:Dynamic) {}
			try
				if (ch.trans != null)
					s.chrome.transparent.set(ch.trans == true)
			catch (_:Dynamic) {}
			try
				if (ch.sun != null)
					s.chrome.showGrip.set(ch.sun == true)
			catch (_:Dynamic) {}
			try
				if (ch.x != null)
					s.chrome.x.set(ch.x)
			catch (_:Dynamic) {}
			try
				if (ch.y != null)
					s.chrome.y.set(ch.y)
			catch (_:Dynamic) {}
			s.chrome.posDirty = true;
		}
	}

	public function draw(hubOpen:BoolRef):Void {
		theme.wrap(() -> {
			drawMenu(hubOpen);
			drawCfg("SolarFlare F7Btn", f7, F7_MIN, F7_MAX, "RiftModsButtonNew_Test", bumpF7, true);
		});
	}

	static inline var GRIP:Single = 14;
	static inline var MENU_GRIP:Single = 28;

	function drawMenu(hubOpen:BoolRef):Void {
		if (f6.hidden.get()) return;
		var chrome = f6.chrome;
		var collapsed = chrome.isCollapsed();
		var width:Single = clamp(f6.size.get(), F6_MIN, F6_MAX);
		var tw = GameIcons.texW("menubutton");
		var th = GameIcons.texH("menubutton");
		var ratio:Single = tw > 0 && th > 0 ? th / tw : 1;
		var height:Single = Math.max(MENU_GRIP, width * ratio);
		ImGui.setNextWindowBgAlpha(0);
		chrome.applyPos();
		if (collapsed) {
			ImGui.setNextWindowSizeConstraints(ImGui.vec2(MENU_GRIP, MENU_GRIP), ImGui.vec2(MENU_GRIP, MENU_GRIP));
			ImGui.setNextWindowSize(ImGui.vec2(MENU_GRIP, MENU_GRIP), ImGuiCond.Always);
		} else {
			ImGui.setNextWindowSizeConstraints(ImGui.vec2(F6_MIN + MENU_GRIP, MENU_GRIP),
				ImGui.vec2(F6_MAX + MENU_GRIP, Math.max(MENU_GRIP, F6_MAX * ratio)));
			var expanding = chrome.takeExpandDirty();
			ImGui.setNextWindowSize(ImGui.vec2(width + MENU_GRIP, height),
				f6.sizeDirty || expanding ? ImGuiCond.Always : ImGuiCond.FirstUseEver);
			f6.sizeDirty = false;
		}
		var flags = chrome.windowFlagsKeepClicks(FLAGS) | ImGuiWindowFlags.NoMove;
		if (collapsed) flags |= ImGuiWindowFlags.NoResize;
		var shown = ImGui.begin("SolarFlare F6Btn", null, flags);
		if (shown) {
			chrome.capturePos();
			var win = ImGui.getWindowSize();
			if (!collapsed) {
				var actualWidth:Single = clamp(win.x - MENU_GRIP, F6_MIN, F6_MAX);
				if (Math.abs(actualWidth - width) > 1 || Math.abs(win.y - height) > 1) {
					f6.size.set(actualWidth);
					f6.sizeDirty = true;
					SettingsStore.markDirty();
				}
			}
			var origin = ImGui.getCursorScreenPos();
			ImGui.dummy(win);
			chrome.drawLauncherGrip(origin.x, origin.y, MENU_GRIP);
			if (chrome.isCollapsed() != collapsed) f6.sizeDirty = true;
			if (!collapsed) {
				var x:Single = origin.x + MENU_GRIP;
				var dl = ImGui.getWindowDrawList();
				if (!GameIcons.drawRect(dl, GameIcons.get("menubutton"), x, origin.y, width, width * ratio))
					ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(x, origin.y), ImGui.vec2(x + width, origin.y + height),
						ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.9, 0.45, 0.12, 0.9)), 8);
				ImGui.setCursorScreenPos(ImGui.vec2(x, origin.y));
				if (ImGui.invisibleButton("##menu_open", ImGui.vec2(width - GRIP, Math.max(14, height - GRIP)))) {
					hubOpen.set(!hubOpen.get());
					SettingsStore.markDirty();
				}
			}
		}
		ImGui.end();
	}

	function hitStrip(spec:LauncherSpec):Single {
		if (spec != null && spec.chrome != null && spec.chrome.isLocked())
			return 0;
		return GRIP;
	}

	function drawCfg(title:String, spec:LauncherSpec, minS:Single, maxS:Single, art:String, onClick:Void->Void, lockAspect:Bool):Void {
		if (spec.hidden.get())
			return;
		var s:Single = clamp(spec.size.get(), minS, maxS);
		var tex = GameIcons.get(art);
		var tw = GameIcons.texW(art);
		var th = GameIcons.texH(art);
		var winW:Single = s;
		var winH:Single = s;
		if (lockAspect && tw > 0 && th > 0)
			winH = s * (th / tw);
		prepareWindow(spec, winW, winH, minS, maxS, lockAspect);
		var flags = spec.chrome != null ? spec.chrome.windowFlagsKeepClicks(FLAGS) : FLAGS;
		flags |= ImGuiWindowFlags.NoSavedSettings;
		var pad:Single = hitStrip(spec) > 0 ? 4 : 0;
		ImGui.pushStyleVar(ImGuiStyleVar.WindowPadding, ImGui.vec2(pad, pad));
		if (!ImGui.begin(title, null, flags)) {
			ImGui.popStyleVar();
			return;
		}
		ImGui.popStyleVar();
		if (spec.chrome != null)
			spec.chrome.capturePos();
		noteSize(spec, lockAspect ? winH : -1);
		var origin = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(winW, winH));
		var dl = ImGui.getWindowDrawList();
		var dw = winW;
		var dh = winH;
		if (!lockAspect && tw > 0 && th > 0) {
			var scale:Single = s / (tw > th ? tw : th);
			dw = tw * scale;
			dh = th * scale;
		}
		var dx:Single = origin.x + (winW - dw) * 0.5;
		var dy:Single = origin.y + (winH - dh) * 0.5;
		if (!GameIcons.drawRect(dl, tex, dx, dy, dw, dh)) {
			ImGui.ImDrawList_AddRectFilled(dl, ImGui.vec2(origin.x, origin.y), ImGui.vec2(origin.x + winW, origin.y + winH),
				ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.9, 0.45, 0.12, 0.9)), 8);
		}
		ImGui.setCursorScreenPos(origin);
		var strip = hitStrip(spec);
		var hitW:Single = winW - strip;
		var hitH:Single = winH - strip;
		if (hitW < 16)
			hitW = winW;
		if (hitH < 16)
			hitH = winH;
		if (ImGui.invisibleButton("##hit_" + title, ImGui.vec2(hitW, hitH)))
			onClick();
		ImGui.end();
	}

	function prepareWindow(spec:LauncherSpec, w:Single, h:Single, minS:Single, maxS:Single, lockAspect:Bool = false):Void {
		ImGui.setNextWindowBgAlpha(0);
		var minH:Single = lockAspect ? Math.max(16, h * (minS / w)) : minS;
		var maxH:Single = lockAspect ? Math.max(h, maxS) : maxS + 80;
		ImGui.setNextWindowSizeConstraints(ImGui.vec2(minS, minH), ImGui.vec2(maxS, maxH));
		if (spec.sizeDirty) {
			ImGui.setNextWindowSize(ImGui.vec2(w, h), ImGuiCond.Always);
			spec.sizeDirty = false;
		} else
			ImGui.setNextWindowSize(ImGui.vec2(w, h), ImGuiCond.FirstUseEver);
		if (spec.chrome != null) {
			spec.chrome.clampToViewport();
			spec.chrome.applyPos();
		}
	}

	function noteSize(spec:LauncherSpec, expectedH:Single = -1):Void {
		var win = ImGui.getWindowSize();
		if (Math.abs(win.x - spec.size.get()) > 1) {
			spec.size.set(win.x);
			spec.sizeDirty = true;
			SettingsStore.markDirty();
		}
		if (expectedH > 0 && Math.abs(win.y - expectedH) > 1)
			spec.sizeDirty = true;
	}

	static function bumpF7():Void {
		try {
			var exeDir = haxe.io.Path.directory(Sys.programPath());
			var dir = haxe.io.Path.join([exeDir, "hlx", "mods", "deadlyriftmods"]);
			if (!FileSystem.exists(dir))
				FileSystem.createDirectory(dir);
			var p = haxe.io.Path.join([dir, "f7.toggle"]);
			var n = 0;
			if (FileSystem.exists(p)) {
				var parsed = Std.parseInt(StringTools.trim(File.getContent(p)));
				if (parsed != null)
					n = parsed;
			}
			n++;
			File.saveContent(p, Std.string(n));
		} catch (_:Dynamic) {}
	}

	static function clamp(v:Single, lo:Single, hi:Single):Single {
		if (v < lo)
			return lo;
		if (v > hi)
			return hi;
		return v;
	}
}
