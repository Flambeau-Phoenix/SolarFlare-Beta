package solarflare.aura.preview;

import imgui.ImGui;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import solarflare.aura.AuraDef;
import solarflare.aura.AuraVisualRenderer;
import solarflare.ui.effects.EffectHelpers;

/**
 * Advanced live interactive preview with play/pause animations and vector effects.
 * Canvas region uses 1:1 local aura bounds (elements are unscaled local pixels).
 * Non-canvas regions support Fit / 100% letterboxing of the outer aura rect.
 */
class AdvancedAuraPreview {
	public var progress = new FloatRef(0.65);
	public var stacks = new IntRef(3);
	public var autoPlay:Bool = false;
	public var animSpeed = new FloatRef(0.8);
	/** 0 = Fit (non-canvas), 1 = 100% logical size. Canvas always 1:1 local. */
	public var zoomMode:Int = 0;
	public var showGrid:Bool = false;
	public var showBounds:Bool = true;
	public var ghostPreview:Bool = false;

	var animTime:Float = 0.0;
	var lastCx:Float = 0;
	var lastCy:Float = 0;
	/** Last aura draw origin/size in screen space (Builder overlays). */
	public var lastDrawX:Float = 0;
	public var lastDrawY:Float = 0;
	public var lastDrawW:Float = 0;
	public var lastDrawH:Float = 0;

	public function new() {}

	/** Compact canvas; set withControls=false when host draws [Play]/Pulse]/Expire]/Ready] below. */
	public function draw(a:AuraDef, width:Float, height:Float, withControls:Bool = true):Void {
		if (a == null) return;

		var chromeH:Float = withControls ? 48 : 14;
		var canvasPos = ImGui.getCursorScreenPos();
		ImGui.dummy(ImGui.vec2(width, height));
		var drawList = ImGui.getWindowDrawList();

		ImGui.ImDrawList_AddRectFilled(drawList, canvasPos, ImGui.vec2(canvasPos.x + width, canvasPos.y + height), 0xEE121722, 6.0);
		ImGui.ImDrawList_AddRect(drawList, canvasPos, ImGui.vec2(canvasPos.x + width, canvasPos.y + height), 0x444A5568, 6.0, 1.0);

		if (autoPlay) {
			animTime += 0.016 * animSpeed.get();
			if (animTime > 1.0) animTime = 0.0;
			progress.set(animTime);
		}

		var logicalW = a.w.get() > 1 ? a.w.get() : 96;
		var logicalH = a.h.get() > 1 ? a.h.get() : 96;
		var isCanvas = a.region == "canvas";
		// Live overlay sizes window to w*scale / h*scale, but canvas elements stay local pixels.
		// Builder canvas preview uses 1:1 logical bounds so editor coords match el.x/y/w/h.
		var drawW:Float;
		var drawH:Float;
		if (isCanvas) {
			drawW = logicalW;
			drawH = logicalH;
			var maxW = Math.max(1, width - 20);
			var maxH = Math.max(1, height - chromeH);
			if (drawW > maxW || drawH > maxH) {
				// Letterbox without scaling children: clip viewport (draw at 1:1, may overflow stage).
				// Prefer showing top-left of canvas so numeric editors stay trustworthy.
			}
		} else {
			var scaledW = logicalW * a.scale.get();
			var scaledH = logicalH * a.scale.get();
			if (zoomMode == 1) {
				drawW = scaledW;
				drawH = scaledH;
			} else {
				var fit = Math.min(1, Math.min((width - 20) / Math.max(1, scaledW), (height - chromeH) / Math.max(1, scaledH)));
				drawW = scaledW * fit;
				drawH = scaledH * fit;
			}
		}

		var cx = canvasPos.x + (width - drawW) * 0.5;
		var cy = canvasPos.y + (height - chromeH - drawH) * 0.5;
		if (isCanvas) {
			// Keep origin inside stage when oversized; top-left bias for editable local space.
			if (drawW > width - 20) cx = canvasPos.x + 10;
			if (drawH > height - chromeH) cy = canvasPos.y + 4;
		}

		if (showGrid)
			drawGrid(drawList, canvasPos.x, canvasPos.y, width, height - chromeH);

		AuraVisualRenderer.draw(drawList, a, cx, cy, drawW, drawH, progress.get(), stacks.get(), stacks.get(), ghostPreview);

		if (showBounds) {
			ImGui.ImDrawList_AddRect(drawList, ImGui.vec2(cx, cy), ImGui.vec2(cx + drawW, cy + drawH),
				0x88F0C040, 0, 1.0);
		}

		lastDrawX = cx;
		lastDrawY = cy;
		lastDrawW = drawW;
		lastDrawH = drawH;

		var size = Math.min(drawW, drawH);
		lastCx = cx + size * 0.5;
		lastCy = cy + size * 0.5;

		var barW = width - 40;
		var barH = 4;
		var barX = canvasPos.x + 20;
		var barY = canvasPos.y + height - (withControls ? 36 : 10);
		ImGui.ImDrawList_AddRectFilled(drawList, ImGui.vec2(barX, barY), ImGui.vec2(barX + barW, barY + barH), 0x44FFFFFF, 3.0);
		ImGui.ImDrawList_AddRectFilled(drawList, ImGui.vec2(barX, barY), ImGui.vec2(barX + barW * progress.get(), barY + barH), 0xFF4FD1C5, 3.0);

		if (!withControls)
			return;

		var after = ImGui.getCursorScreenPos();
		ImGui.setCursorScreenPos(ImGui.vec2(canvasPos.x + 8, canvasPos.y + height - 28));
		drawSimButtons(a);
		ImGui.setCursorScreenPos(after);
	}

	static function drawGrid(dl:Dynamic, x:Float, y:Float, w:Float, h:Float):Void {
		var step:Float = 24;
		var col = 0x224A5568;
		var gx = x;
		while (gx <= x + w) {
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(gx, y), ImGui.vec2(gx, y + h), col, 1.0);
			gx += step;
		}
		var gy = y;
		while (gy <= y + h) {
			ImGui.ImDrawList_AddLine(dl, ImGui.vec2(x, gy), ImGui.vec2(x + w, gy), col, 1.0);
			gy += step;
		}
	}

	public function drawSimButtons(a:AuraDef):Void {
		if (a == null) return;
		if (ImGui.button(autoPlay ? "Pause##apv" : "Play##apv", ImGui.vec2(0, 26)))
			autoPlay = !autoPlay;
		ImGui.sameLine();
		if (ImGui.button("Pulse FX##apv", ImGui.vec2(0, 26))) {
			if (a.fxPulse != null) a.fxPulse.set(true);
			EffectHelpers.auraHit(lastCx, lastCy);
		}
		ImGui.sameLine();
		if (ImGui.button("Expire FX##apv", ImGui.vec2(0, 26))) {
			if (a.fxExpire != null) a.fxExpire.set(true);
			EffectHelpers.auraExpire(lastCx, lastCy);
		}
		ImGui.sameLine();
		if (ImGui.button("Ready FX##apv", ImGui.vec2(0, 26))) {
			if (a.fxReady != null) a.fxReady.set(true);
			EffectHelpers.skillReady(lastCx, lastCy);
		}
	}
}
