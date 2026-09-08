package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiButtonFlags;
import imgui.Enums.ImGuiCol;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiMouseButton;
import imgui.Enums.ImGuiWindowFlags;
import imgui.ref.BoolRef;
import imgui.ref.FloatRef;

/**
 * Overlay / panel chrome for hl-imgui 0.0.5: thin custom title bar (no native title),
 * chrome-sun.ico grip (click collapse, hold-drag), X to close. Lock disables interaction
 * without changing title-strip geometry.
 * Lock + Transparent stay as body checkboxes — no collapse checkbox.
 */
class HudChrome {
	static var sunRetryDone = false;
	public static inline var SUN_ID:String = "chrome-sun";
	public static inline var SUN:Single = 14;
	public static inline var CLOSE:Single = 14;
	public static inline var STRIP:Single = 18;

	static var pool = new Map<String, HudChrome>();
	static var nextUid:Int = 1;

	public var locked = new BoolRef(false);
	public var transparent = new BoolRef(false);
	public var collapsed = new BoolRef(false);
	/** Kept for solarflare.json; no longer shown in UI. */
	public var showGrip = new BoolRef(true);
	public var x = new FloatRef(40);
	public var y = new FloatRef(40);
	public var posDirty = false;
	public var expandSizeDirty = false;
	/** When false, collapse still resizes; x/y are not forced each frame (config panels). */
	public var bindPos:Bool = true;
	public var winW:Single = 0;
	public var winH:Single = 0;

	public function captureSize(w:FloatRef, h:FloatRef):Void {
		if (w != null && h != null && winW > 0 && winH > 0) {
			if (Math.abs(winW - w.get()) > 1 || Math.abs(winH - h.get()) > 1)
				SettingsStore.markDirty();
			w.set(winW);
			h.set(winH);
		}
	}

	static inline var BODY_CHILD_ID:String = "##hm_body";
	static inline var GRIP_ID:String = "##hm_grip";
	static inline var CLOSE_ID:String = "##hm_x";

	var dragSun:Bool = false;
	var didDrag:Bool = false;
	var dragOffX:Single = 0;
	var dragOffY:Single = 0;
	var expandW:Single = 280;
	var expandH:Single = 200;
	var bodyChild:Bool = false;
	/** True only when the matching ImGui.begin() for this panel succeeded. */
	var windowBegan:Bool = false;
	/** Config panels may scroll; overlays keep NoScrollbar on the body child. */
	var bodyScroll:Bool = false;
	static var endStack:Array<HudChrome> = [];

	public function new(x0:Single = 40, y0:Single = 40) {
		x.set(x0);
		y.set(y0);
	}

	public static function of(id:String):HudChrome {
		if (id == null || id.length == 0)
			id = "panel";
		if (!pool.exists(id)) {
			var c = new HudChrome();
			c.bindPos = false;
			pool.set(id, c);
		}
		return pool.get(id);
	}

	/** HUD overlays: never dock, never write imgui.ini geometry. */
	public static inline var HUD_BASE:Int = ImGuiWindowFlags.NoDocking | ImGuiWindowFlags.NoSavedSettings;

	public static function panelFlags(extra:Int = 0):Int {
		return CursorCaptureFix.windowFlags(ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse | HUD_BASE | extra);
	}

	/** Child that must not scroll (screen-space draw lists clip when the parent scrolls). */
	public static inline var CHILD_NO_SCROLL:Int = ImGuiWindowFlags.NoScrollWithMouse;

	/** Always pairs beginChild/endChild; swallows draw throws so the stack stays balanced. */
	public static function safeChild(id:String, size:imgui.Vec2, flags:Int, draw:Void->Void, childFlags:Int = 0):Void {
		var shown = ImGui.beginChild(id, size, childFlags, flags);
		try {
			if (shown && draw != null)
				draw();
		} catch (e:Dynamic) {
			trace('SolarFlare child $id: $e');
		}
		ImGui.endChild();
	}

	public static function beginPanel(name:String, ?open:BoolRef, caption:String = "", extraFlags:Int = 0, ?chrome:HudChrome,
			keepClicks:Bool = false, scrollBody:Bool = true):Bool {
		var c = chrome != null ? chrome : of(name);
		c.windowBegan = false;
		c.closeBodyChild();
		var base = ImGuiWindowFlags.NoCollapse | extraFlags;
		var flags = keepClicks ? c.windowFlagsKeepClicks(base) : c.windowFlags(base);
		c.applyPos();
		var shown = ImGui.begin(name, open, flags);
		c.windowBegan = true;
		endStack.push(c);
		if (!shown)
			return false;
		var ws = ImGui.getWindowSize();
		c.winW = ws.x;
		c.winH = ws.y;
		if (c.bindPos)
			c.capturePos();
		var onClose:Void->Void = null;
		if (open != null)
			onClose = function() {
				open.set(false);
			};
		return c.beginBody(onClose, null, caption, scrollBody);
	}

	/** Pair with raw `ImGui.begin()` on HUD overlays — closes body child and ends only when begin succeeded. */
	public static function endOverlayWindow(began:Bool, ?chrome:HudChrome):Void {
		if (chrome != null)
			chrome.closeBodyChild();
		if (began)
			ImGui.end();
	}

	public static function endPanel():Void {
		if (endStack.length == 0)
			return;
		var c = endStack.pop();
		if (c != null) {
			c.closeBodyChild();
			if (c.windowBegan)
				ImGui.end();
			c.windowBegan = false;
		}
	}

	public function isLocked():Bool {
		return locked.get();
	}

	public function isTransparent():Bool {
		return transparent.get();
	}

	public function isCollapsed():Bool {
		return collapsed.get();
	}

	public function takeExpandDirty():Bool {
		if (!expandSizeDirty)
			return false;
		expandSizeDirty = false;
		return true;
	}

	public function windowFlags(base:Int):Int {
		var f = CursorCaptureFix.windowFlags(base | ImGuiWindowFlags.NoCollapse | HUD_BASE);
		if (isLocked() && !isCollapsed())
			f |= ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoResize | ImGuiWindowFlags.NoMouseInputs;
		if (isTransparent())
			f |= ImGuiWindowFlags.NoBackground;
		return f;
	}

	/** Lock move/resize but keep hit-testing (art buttons that must stay clickable). */
	public function windowFlagsKeepClicks(base:Int):Int {
		var f = CursorCaptureFix.windowFlags(base | ImGuiWindowFlags.NoCollapse | HUD_BASE);
		if (isLocked() && !isCollapsed())
			f |= ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoResize;
		if (isTransparent())
			f |= ImGuiWindowFlags.NoBackground;
		return f;
	}

	public function applyPos():Void {
		if (bindPos && posDirty) {
			clampToViewport();
			ImGui.setNextWindowPos(ImGui.vec2(x.get(), y.get()), ImGuiCond.Always);
			posDirty = false;
		}
		if (collapsed.get())
			ImGui.setNextWindowSize(ImGui.vec2(SUN + CLOSE + 18, STRIP + 6), ImGuiCond.Always);
		else if (expandSizeDirty && !bindPos) {
			ImGui.setNextWindowSize(ImGui.vec2(expandW, expandH), ImGuiCond.Always);
			expandSizeDirty = false;
		}
	}

	/** Keep overlays on-screen after resolution / multi-monitor moves. Safe before ImGui init. */
	public function clampToViewport():Void {
		var maxX:Single = 1920;
		var maxY:Single = 1080;
		try {
			// getMainViewport AV's if called during mod main() before ImGuiFrame presents.
			var vp = ImGui.getMainViewport();
			if (vp != null) {
				var c = ImGui.ImGuiViewport_GetCenter(vp);
				if (c != null) {
					maxX = c.x * 2;
					maxY = c.y * 2;
				}
			}
		} catch (_:Dynamic) {}
		var px = x.get();
		var py = y.get();
		if (maxX < 200)
			maxX = 1920;
		if (maxY < 200)
			maxY = 1080;
		if (px > maxX - 40)
			px = maxX - 200;
		if (py > maxY - 40)
			py = maxY - 120;
		if (px < 0)
			px = 20;
		if (py < 0)
			py = 20;
		x.set(px);
		y.set(py);
	}

	public function capturePos():Void {
		var p = ImGui.getWindowPos();
		x.set(p.x);
		y.set(p.y);
	}

	public function drawToggles(id:String):Bool {
		var changed = false;
		if (ImGui.checkbox("Lock##" + id, locked))
			changed = true;
		ImGui.sameLine();
		if (ImGui.checkbox("Transparent##" + id, transparent))
			changed = true;
		if (changed)
			SettingsStore.markDirty();
		return changed;
	}

	/** Standard editor prefix for every independently movable HUD window. */
	public function drawWindowSettings(hidden:BoolRef, id:String):Bool {
		var changed = false;
		if (hidden != null && ImGui.checkbox("Hide window##" + id, hidden))
			changed = true;
		if (ImGui.checkbox("Lock window##" + id, locked))
			changed = true;
		if (ImGui.checkbox("Transparent window##" + id, transparent))
			changed = true;
		if (changed)
			SettingsStore.markDirty();
		return changed;
	}

	/**
	 * Thin title: ico (collapse / drag) + optional leading + caption + X.
	 * Hidden while locked (unless collapsed, so the ico can expand).
	 * Returns false when collapsed — caller should skip body widgets.
	 */
	public function drawTitleTools(?onClose:Void->Void, ?drawLeading:Void->Void, ?caption:String):Bool {
		var showBody = !collapsed.get();

		var saved = ImGui.getCursorPos();
		var wp = ImGui.getWindowPos();
		var ws = ImGui.getWindowSize();
		var dl = ImGui.getWindowDrawList();
		var theme = ThemePalette.current();

		if (!isTransparent()) {
			WindowEffects.dropShadow(dl, wp.x, wp.y, wp.x + ws.x, wp.y + ws.y, 6.0, 0.22);

			var a = ThemePalette.panelAlpha();
			var topCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(
				Math.min(1, theme.titleBg.x * 1.25 + 0.04),
				Math.min(1, theme.titleBg.y * 1.25 + 0.04),
				Math.min(1, theme.titleBg.z * 1.2 + 0.04), a));
			var bottomCol = ImGui.colorConvertFloat4ToU32(ImGui.vec4(theme.titleBg.x, theme.titleBg.y, theme.titleBg.z, a));
			WindowEffects.gradientHeader(dl, wp.x, wp.y, ws.x, STRIP + 2, topCol, bottomCol);

			var accentCol = ImGui.colorConvertFloat4ToU32(theme.accent);
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(wp.x + 4, wp.y + STRIP + 1), ImGui.vec2(wp.x + ws.x - 4, wp.y + STRIP + 1), accentCol, 1);
		}

		var sunX:Single = wp.x + 3;
		var sunY:Single = wp.y + ((STRIP + 2) - SUN) * 0.5;
		if (!isLocked())
			pollSunGrip(sunX, sunY);
		if (!isTransparent()) {
			var gripCol = ImGui.colorConvertFloat4ToU32(theme.text);
			for (i in 0...3)
				ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(sunX + 3 + i * 4, sunY + SUN * 0.5), 1, gripCol, 8);
		}

		var closeHit = false;
		if (onClose != null) {
			var closeX:Single = wp.x + ws.x - CLOSE - 4;
			var closeY:Single = wp.y + ((STRIP + 2) - CLOSE) * 0.5;
			if (!isLocked())
				closeHit = pollCloseButton(closeX, closeY);
			if (!isTransparent())
				drawCloseGlyph(closeX, closeY);
		}

		ImGui.setCursorPos(saved);
		if (closeHit)
			onClose();

		if (!showBody) {
			ImGui.dummy(ImGui.vec2(SUN + CLOSE + 12, STRIP));
			return false;
		}

		var start = ImGui.getCursorPos();
		if (!isTransparent() && drawLeading != null) {
			ImGui.setCursorScreenPos(ImGui.vec2(wp.x + SUN + 8, wp.y + 2));
			drawLeading();
		}
		if (!isTransparent() && caption != null && caption.length > 0) {
			var ts = ImGui.calcTextSize(caption);
			var titleX:Single = wp.x + (ws.x - ts.x) * 0.5;
			var titleY:Single = wp.y + ((STRIP + 2) - ts.y) * 0.5;
			var textCol = ImGui.colorConvertFloat4ToU32(theme.text);
			ImGui.ImDrawList_AddText_Vec2(dl, ImGui.vec2(titleX, titleY), textCol, caption);
		}
		ImGui.setCursorPos(start);
		ImGui.dummy(ImGui.vec2(0, STRIP));
		ImGui.setCursorPos(ImGui.vec2(start.x, start.y + STRIP + 2));
		return true;
	}

	var lastOnClose:Void->Void = null;
	var lastCaption:String = null;

	/** Title strip then a body child so a window scrollbar cannot cover the X. */
	public function beginBody(?onClose:Void->Void, ?drawLeading:Void->Void, ?caption:String, scrollBody:Bool = false, bodyFlags:Int = 0):Bool {
		closeBodyChild();
		bodyScroll = scrollBody;
		lastOnClose = onClose;
		lastCaption = caption;
		drawContextMenu(onClose, caption);
		if (!drawTitleTools(onClose, drawLeading, caption))
			return false;
		openBodyChild(bodyFlags);
		return true;
	}

	public function drawContextMenu(?onClose:Void->Void, ?caption:String):Void {
		if (ImGui.beginPopupContextWindow(null, 1)) {
			var title = caption != null ? caption : "Window Controls";
			ImGui.separatorText('$title');

			if (ImGui.checkbox("Lock Window##ctx_lock", locked)) {
				SettingsStore.markDirty();
				ToastManager.info(locked.get() ? '$title locked' : '$title unlocked');
			}
			if (ImGui.checkbox("Transparent Window##ctx_trans", transparent)) {
				SettingsStore.markDirty();
			}
			if (ImGui.checkbox("Collapse Window##ctx_col", collapsed)) {
				SettingsStore.markDirty();
			}

			ImGui.separator();
			if (ImGui.menuItem("Reset Position##ctx_rst")) {
				x.set(40);
				y.set(40);
				posDirty = true;
				SettingsStore.markDirty();
				ToastManager.info('$title position reset');
			}

			if (onClose != null) {
				ImGui.separator();
				if (ImGui.menuItem("Close Window##ctx_cls", "Esc")) {
					onClose();
					ToastManager.info('$title closed');
				}
			}

			ImGui.endPopup();
		}
	}

	public function openBodyChild(extraFlags:Int = 0):Void {
		if (bodyChild)
			return;
		var flags = ImGuiWindowFlags.NoBackground | ImGuiWindowFlags.NoScrollbar;
		if (bodyScroll)
			flags = ImGuiWindowFlags.NoBackground;
		flags |= extraFlags;
		ImGui.pushStyleColor(ImGuiCol.ChildBg, ImGui.vec4(0, 0, 0, 0));
		ImGui.beginChild(BODY_CHILD_ID, ImGui.vec2(0, 0), 0, flags);
		ImGui.popStyleColor();
		bodyChild = true;
		drawContextMenu(lastOnClose, lastCaption);
	}

	public function closeBodyChild():Void {
		if (!bodyChild)
			return;
		ImGui.endChild();
		bodyChild = false;
	}

	function blitSun(px:Single, py:Single):Void {
		var dl = ImGui.getWindowDrawList();
		var tex = GameIcons.get(SUN_ID);
		if (tex == 0 && !sunRetryDone) {
			sunRetryDone = true;
			tex = GameIcons.retry(SUN_ID);
		}
		if (!GameIcons.draw(dl, tex, px, py, SUN)) {
			var cx:Single = px + SUN * 0.5;
			var cy:Single = py + SUN * 0.5;
			var col = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.98, 0.76, 0.12, 0.98));
			ImGui.ImDrawList_AddCircleFilled(dl, ImGui.vec2(cx, cy), 2.8, col, 12);
			for (i in 0...8) {
				var a = i * Math.PI / 4;
				ImGui.ImDrawList_AddLine(dl,
					ImGui.vec2(cx + Math.cos(a) * 4.2, cy + Math.sin(a) * 4.2),
					ImGui.vec2(cx + Math.cos(a) * 6.4, cy + Math.sin(a) * 6.4), col, 1.35);
			}
		}
	}

	function drawCloseGlyph(px:Single, py:Single):Void {
		var dl = ImGui.getWindowDrawList();
		var pad:Single = 3;
		var col = ImGui.colorConvertFloat4ToU32(ImGui.vec4(0.92, 0.78, 0.78, 0.95));
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(px + pad, py + pad), ImGui.vec2(px + CLOSE - pad, py + CLOSE - pad), col, 1.6);
		ImGui.ImDrawList_AddLine(dl, ImGui.vec2(px + CLOSE - pad, py + pad), ImGui.vec2(px + pad, py + CLOSE - pad), col, 1.6);
	}

	/** Standalone launcher grip; shares HUD drag/collapse authority with the title icon. */
	public function drawLauncherGrip(px:Single, py:Single, hitSize:Single):Void {
		if (!isLocked())
			pollSunGrip(px, py, hitSize);
		var inset:Single = (hitSize - SUN) * 0.5;
		blitSun(px + inset, py + inset);
	}

	function pollSunGrip(px:Single, py:Single, hitSize:Single = SUN):Void {
		if (!CursorCaptureFix.cursorFree)
			return;
		ImGui.setCursorScreenPos(ImGui.vec2(px, py));
		ImGui.invisibleButton(GRIP_ID, ImGui.vec2(hitSize, hitSize), ImGuiButtonFlags.AllowOverlap);
		if (ImGui.isItemActive()) {
			var m = ImGui.getMousePos();
			if (!dragSun) {
				dragSun = true;
				didDrag = false;
				dragOffX = m.x - ImGui.getWindowPos().x;
				dragOffY = m.y - ImGui.getWindowPos().y;
			}
			if (ImGui.isMouseDragging(ImGuiMouseButton.Left, 4) && !isLocked()) {
				didDrag = true;
				var nx = m.x - dragOffX;
				var ny = m.y - dragOffY;
				this.x.set(nx);
				this.y.set(ny);
				ImGui.setWindowPos(ImGui.vec2(nx, ny));
				SettingsStore.markDirty();
			}
		}
		if (ImGui.isItemDeactivated()) {
			var click = dragSun && !didDrag;
			dragSun = false;
			didDrag = false;
			if (click)
				toggleCollapsed();
		}
	}

	function pollCloseButton(px:Single, py:Single):Bool {
		if (!CursorCaptureFix.cursorFree)
			return false;
		ImGui.setCursorScreenPos(ImGui.vec2(px, py));
		return ImGui.invisibleButton(CLOSE_ID, ImGui.vec2(CLOSE, CLOSE), ImGuiButtonFlags.AllowOverlap);
	}

	function toggleCollapsed():Void {
		if (!collapsed.get()) {
			try {
				var s = ImGui.getWindowSize();
				if (s != null && s.x > 40 && s.y > 20) {
					expandW = s.x;
					expandH = s.y;
				}
			} catch (_:Dynamic) {}
			collapsed.set(true);
		} else {
			collapsed.set(false);
			expandSizeDirty = true;
		}
		SettingsStore.markDirty();
	}
}
