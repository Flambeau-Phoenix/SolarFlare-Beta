package solarflare.ui;

import imgui.ImGui;
import imgui.Enums.ImGuiChildFlags;
import imgui.Enums.ImGuiCond;
import imgui.Enums.ImGuiMouseButton;
import imgui.Enums.ImGuiWindowFlags;
import imgui.Structs.ImVec2;

/**
 * Runtime HUD content in a single HudChrome window: no native title bar, the
 * thin chrome strip on top, sun-drag movement, and one explicit bottom-right
 * resize grip while unlocked. `w` / `h` are content dimensions; the wrapper
 * measures chrome overhead and hands resized content dimensions back through
 * `onResize`.
 */
class HUDWidgetWindow {
	public static inline var PADDING:Single = 10;
	public static inline var ROW:Single = 30;
	static inline var RESIZE_FOOTER:Single = HudChrome.RESIZE_GRIP + PADDING + 4;

	/** A one-row widget still needs room for an icon plus its glow ring. */
	static inline var MIN_CONTENT_H:Single = 18;

	/**
	 * First-frame chrome guess, before `win - avail` has ever been measured for an id.
	 * Deliberately larger than any theme's real padding: an oversized window shrinks on
	 * the next frame, an undersized one clips and squashes the art it is holding.
	 */
	static inline var SEED_PAD:Single = 24;

	static inline var FLAGS:Int = ImGuiWindowFlags.NoTitleBar | ImGuiWindowFlags.NoCollapse
		| ImGuiWindowFlags.NoScrollbar | ImGuiWindowFlags.NoScrollWithMouse
		| ImGuiWindowFlags.NoResize;

	/** Last content size pushed per id — a caller-side change must re-assert, a drag must not. */
	static var lastW:Map<String, Single> = new Map();
	static var lastH:Map<String, Single> = new Map();
	/** Measured chrome overhead per id (strip + padding), so `h` stays a content height. */
	static var ovW:Map<String, Single> = new Map();
	static var ovH:Map<String, Single> = new Map();
	static var reassert:Map<String, Bool> = new Map();
	static var lastVisualW:Map<String, Single> = new Map();
	static var lastVisualH:Map<String, Single> = new Map();

	public static function draw(id:String, caption:String, chrome:HudChrome, w:Single, h:Single,
			drawBody:ImVec2->Void, ?openBuilder:Void->Void, ?hide:Void->Void, layoutOverride:Bool = false,
			?quickActions:Void->Void, onResize:Single->Single->Void = null, visualBounds:HUDVisualBounds = null):Void {
		UiLayout.contentSpacing(function() {
			drawContent(id, caption, chrome, w, h, drawBody, openBuilder, hide, layoutOverride, quickActions, onResize, visualBounds);
		});
	}

	static function drawContent(id:String, caption:String, chrome:HudChrome, w:Single, h:Single,
			drawBody:ImVec2->Void, openBuilder:Void->Void, hide:Void->Void, layoutOverride:Bool,
			quickActions:Void->Void, onResize:Single->Single->Void, visualBounds:HUDVisualBounds):Void {
		if (chrome == null)
			return;
		var minFaceW:Single = visualBounds != null ? 24 : HudChrome.SUN + HudChrome.CLOSE + 12;
		w = Math.max(minFaceW, w);
		h = Math.max(MIN_CONTENT_H, h);
		var left:Single = visualBounds != null ? Math.max(0, -visualBounds.minX) : 0;
		var top:Single = visualBounds != null ? Math.max(0, -visualBounds.minY) : 0;
		var extraW:Single = visualBounds != null ? Math.max(0, visualBounds.maxX - w) + left : 0;
		var extraH:Single = visualBounds != null ? Math.max(0, visualBounds.maxY - h) + top : 0;
		chrome.setVisualOffset(left, top);

		// Re-assert only when the owner changed the numbers (slider, scale, profile load).
		var prevW:Single = lastW.exists(id) ? lastW.get(id) : -1;
		var prevH:Single = lastH.exists(id) ? lastH.get(id) : -1;
		var external = Math.abs(prevW - w) > 1 || Math.abs(prevH - h) > 1;
		if (!lastVisualW.exists(id) || Math.abs(lastVisualW.get(id) - extraW) > 0.5
				|| !lastVisualH.exists(id) || Math.abs(lastVisualH.get(id) - extraH) > 0.5) external = true;
		lastVisualW.set(id, extraW);
		lastVisualH.set(id, extraH);
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
		var oH:Single = measured ? ovH.get(id) : HudChrome.STRIP + 2 + SEED_PAD + RESIZE_FOOTER;
		ImGui.setNextWindowBgAlpha(chrome.isTransparent() ? 0 : 0.82);
		// Until the chrome has been measured once the seed above is a guess, so the size
		// has to be asserted every frame; FirstUseEver would freeze the guess in place.
		var locked = chrome.isLocked() && !layoutOverride;
		var sizeCond = (locked || external || !measured) ? ImGuiCond.Always : ImGuiCond.FirstUseEver;
		ImGui.setNextWindowSize(ImGui.vec2(w + extraW + oW, h + extraH + oH), sizeCond);
		chrome.clampToViewport();
		chrome.applyPos();
		if (!chrome.collapsed.get() && !chrome.isLocked()) {
			ImGui.setNextWindowPos(ImGui.vec2(HUDVisualBounds.hostCoordinate(chrome.x.get(), left),
				HUDVisualBounds.hostCoordinate(chrome.y.get(), top)), ImGuiCond.FirstUseEver);
		}

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
				chrome.winW = win.x;
				chrome.winH = win.y;
				if (editable) {
					chrome.capturePos();
				}
				var onClose:Void->Void = hide;
				if (chrome.beginBody(onClose, null, caption, false, ImGuiWindowFlags.NoScrollWithMouse,
						ImGuiChildFlags.AlwaysUseWindowPadding, RESIZE_FOOTER)) {
					var avail = ImGui.getContentRegionAvail();
					// Measurement includes the footer, so content dimensions never shrink to fit it.
					var mW:Single = win.x - avail.x;
					var mH:Single = win.y - avail.y;
					if (mH >= 0 && (Math.abs(mW - oW) > 0.5 || Math.abs(mH - oH) > 0.5)) {
						ovW.set(id, mW);
						ovH.set(id, mH);
						reassert.set(id, true);
					}
					// Hand the body its configured content box, never a larger region: on an
					// oversized seed frame the extra space would stretch blit art out of shape.
					var bodyW:Single = Math.min(Math.max(0, avail.x - extraW), w);
					var bodyH:Single = Math.min(Math.max(0, avail.y - extraH), h);
					if (bodyW > 1 && bodyH > 1 && drawBody != null) {
						var clipMin = ImGui.getCursorScreenPos();
						ImGui.pushClipRect(clipMin,
							ImGui.vec2(clipMin.x + bodyW + extraW, clipMin.y + bodyH + extraH), true);
						var drawFailed = false;
						var drawFailure:Dynamic = null;
						try {
							if (visualBounds != null) ImGui.setCursorScreenPos(ImGui.vec2(clipMin.x + left, clipMin.y + top));
							drawBody(ImGui.vec2(bodyW, bodyH));
						} catch (e:Dynamic) {
							drawFailed = true;
							drawFailure = e;
						}
						ImGui.popClipRect();
						if (visualBounds != null) {
							// Submit the full visual allocation, including above/below plates.
							ImGui.setCursorScreenPos(clipMin);
							ImGui.dummy(ImGui.vec2(bodyW + extraW, bodyH + extraH));
						}
						if (drawFailed)
							throw drawFailure;
					}
				}
				chrome.closeBodyChild();
				chrome.drawResizeCorner(id, editable,
					minFaceW + extraW + oW, MIN_CONTENT_H + extraH + oH,
					10000, 10000, function(outerW:Single, outerH:Single) {
						var contentW:Single = Math.max(minFaceW, outerW - oW - extraW);
						var contentH:Single = Math.max(MIN_CONTENT_H, outerH - oH - extraH);
						lastW.set(id, contentW);
						lastH.set(id, contentH);
						if (onResize != null)
							onResize(contentW, contentH);
						SettingsStore.markDirty();
					}, PADDING);
				chrome.pollTransparentSurfaceDrag(id, editable);
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
