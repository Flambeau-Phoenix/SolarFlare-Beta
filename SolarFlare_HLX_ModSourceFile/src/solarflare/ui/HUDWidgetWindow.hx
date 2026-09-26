package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiMouseButton;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Structs.ImVec2;

/**
 * Runtime HUD content in a single HudChrome window: no native title bar, the
 * thin chrome strip on top, native ImGui move and resize while unlocked.
 * The strip covers the top resize border, so the art underneath cannot be
 * grabbed. `w` / `h` are the window size; ImGui owns them between external
 * changes and hands them back through `onResize`.
 */
class HUDWidgetWindow {
	public static inline var PADDING:Single = 10;
	public static inline var ROW:Single = 30;

	/** A one-row widget still needs room for an icon plus its glow ring. */
	static inline var MIN_CONTENT_H:Single = 18;

	/**
	 * First-frame chrome guess, before `win - avail` has ever been measured for an id.
	 * Deliberately larger than any theme's real padding: an oversized window shrinks on
	 * the next frame, an undersized one clips and squashes the art it is holding.
	 */
	static inline var SEED_PAD:Single = 24;

	static inline var FLAGS:Int = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse
		| ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse;

	/** Last content size pushed per id — a caller-side change must re-assert, a drag must not. */
	static var lastW:Map<String, Single> = new Map();
	static var lastH:Map<String, Single> = new Map();
	/** Measured chrome overhead per id (strip + padding), so `h` stays a content height. */
	static var ovW:Map<String, Single> = new Map();
	static var ovH:Map<String, Single> = new Map();
	static var reassert:Map<String, Bool> = new Map();

	public static function draw(id:String, caption:String, chrome:HudChrome, w:Single, h:Single,
			drawBody:ImVec2->Void, ?openBuilder:Void->Void, ?hide:Void->Void, layoutOverride:Bool = false,
			?quickActions:Void->Void, onResize:Single->Single->Void = null):Void {
		UiLayout.contentSpacing(function() {
			drawContent(id, caption, chrome, w, h, drawBody, openBuilder, hide, layoutOverride, quickActions, onResize);
		});
	}

	static function drawContent(id:String, caption:String, chrome:HudChrome, w:Single, h:Single,
			drawBody:ImVec2->Void, openBuilder:Void->Void, hide:Void->Void, layoutOverride:Bool,
			quickActions:Void->Void, onResize:Single->Single->Void):Void {
		if (chrome == null)
			return;
		w = Math.max(HudChrome.SUN + HudChrome.CLOSE + 12, w);
		h = Math.max(MIN_CONTENT_H, h);

		// Re-assert only when the owner changed the numbers (slider, scale, profile load).
		var prevW:Single = lastW.exists(id) ? lastW.get(id) : -1;
		var prevH:Single = lastH.exists(id) ? lastH.get(id) : -1;
		var external = Math.abs(prevW - w) > 1 || Math.abs(prevH - h) > 1;
		if (chrome.takeExpandDirty())
			external = true;
		if (reassert.exists(id) && reassert.get(id))
			external = true;
		reassert.set(id, false);
		lastW.set(id, w);
		lastH.set(id, h);

		// Requested size is the CONTENT box; grow the window by the measured chrome.
		var measured = ovH.exists(id);
		var oW:Single = measured ? ovW.get(id) : SEED_PAD;
		var oH:Single = measured ? ovH.get(id) : HudChrome.STRIP + 2 + SEED_PAD;
		ImGui.setNextWindowBgAlpha(chrome.isTransparent() ? 0 : 0.82);
		// Until the chrome has been measured once the seed above is a guess, so the size
		// has to be asserted every frame; FirstUseEver would freeze the guess in place.
		var locked = chrome.isLocked() && !layoutOverride;
		var sizeCond = (locked || external || !measured) ? ImGuiCond.Always : ImGuiCond.FirstUseEver;
		ImGui.setNextWindowSize(ImGui.vec2(w + oW, h + oH), sizeCond);
		chrome.clampToViewport();
		chrome.applyPos();
		if (!chrome.collapsed.get())
			ImGui.setNextWindowPos(ImGui.vec2(chrome.x.get(), chrome.y.get()), ImGuiCond.FirstUseEver);

		var editable = !chrome.isLocked() || layoutOverride;
		var flags = chrome.windowFlagsKeepClicks(FLAGS);
		if (locked)
			flags |= ImGuiWindowFlags.NoMove | ImGuiWindowFlags.NoResize;
		chrome.extraMenu = function() {
			if (openBuilder != null && ImGui.menuItem("Open Builder##hw_build"))
				openBuilder();
			if (quickActions != null)
				quickActions();
			if (hide != null && ImGui.menuItem("Hide##hw_hide"))
				hide();
		};
		var failed = false;
		var failure:Dynamic = null;
		var began = ImGui.begin(caption + "###" + id, null, flags);
		try {
			if (began) {
				var win = ImGui.getWindowSize();
				if (editable) {
					chrome.capturePos();
					if (ImGui.isMouseReleased(ImGuiMouseButton.Left)) {
						if (SettingsStore.isDirty())
							SettingsStore.flushDirty();
					}
					// Native edge resize, reported back in content units. A frame that
					// asserts its own size is not a drag: subtracting an overhead that
					// changed this frame would report a resize the player never made,
					// which is how widgets drifted and squashed their art.
					if (onResize != null && !external && measured) {
						var cw:Single = win.x - oW;
						var ch:Single = win.y - oH;
						if (Math.abs(cw - w) > 1 || Math.abs(ch - h) > 1) {
							lastW.set(id, cw);
							lastH.set(id, ch);
							onResize(cw, ch);
							SettingsStore.markDirty();
						}
					}
				}
				var onClose:Void->Void = hide;
				if (chrome.beginBody(onClose, null, caption, false, 0, ImGuiChildFlags.AlwaysUseWindowPadding)) {
					var avail = ImGui.getContentRegionAvail();
					// Re-measure the chrome; a stale figure is what clipped content.
					var mW:Single = win.x - avail.x;
					var mH:Single = win.y - avail.y;
					if (mH >= 0 && (Math.abs(mW - oW) > 0.5 || Math.abs(mH - oH) > 0.5)) {
						ovW.set(id, mW);
						ovH.set(id, mH);
						reassert.set(id, true);
					}
					// Hand the body its configured content box, never a larger region: on an
					// oversized seed frame the extra space would stretch blit art out of shape.
					var bodyW:Single = Math.min(avail.x, w);
					var bodyH:Single = Math.min(avail.y, h);
					if (bodyW > 1 && bodyH > 1 && drawBody != null)
						drawBody(ImGui.vec2(bodyW, bodyH));
				}
			}
		} catch (e:Dynamic) {
			failed = true;
			failure = e;
		}
		HudChrome.endOverlayWindow(began, chrome);
		chrome.extraMenu = null;
		if (failed)
			UiScope.report("HUD", id, failure);
	}
}
