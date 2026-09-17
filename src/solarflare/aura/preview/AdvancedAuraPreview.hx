package solarflare.aura.preview;

import imgui.ImGui;
import imgui.ref.FloatRef;
import imgui.ref.IntRef;
import solarflare.aura.AuraDef;
import solarflare.aura.AuraVisualRenderer;
import solarflare.ui.effects.EffectHelpers;
import solarflare.ui.effects.VectorEffectSystem.EffectParams;
import solarflare.ui.effects.VectorEffectSystem.EffectType;
import solarflare.ui.effects.VectorEffectSystem.VectorEffect;

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
	/** Preview-only camera controls. They never mutate live HUD placement. */
	public var panX = new FloatRef(0);
	public var panY = new FloatRef(0);
	public var previewZoom = new FloatRef(1);
	/** 0 = Fit (non-canvas), 1 = 100% logical size. Canvas always 1:1 local. */
	public var zoomMode:Int = 0;
	public var showGrid:Bool = false;
	public var showBounds:Bool = false;
	public var ghostPreview:Bool = false;

	var animTime:Float = 0.0;
	var lastAuraId:String = "";
	var previewEffects:Array<VectorEffect> = [];
	var lastPreviewStamp:Float = 0;
	var lastCx:Float = 0;
	var lastCy:Float = 0;
	/** Last aura draw origin/size in screen space (Builder overlays). */
	public var lastDrawX:Float = 0;
	public var lastDrawY:Float = 0;
	public var lastDrawW:Float = 0;
	public var lastDrawH:Float = 0;

	public function new() {}

	/** Compact canvas; set withControls=false when host draws [Play]/Pulse]/Expire]/Ready] below.
	 *  compactFit=true scales any region (including canvas) into the stage so the preview stays centered and stable. */
	public function draw(a:AuraDef, width:Float, height:Float, withControls:Bool = true, compactFit:Bool = false):Void {
		if (a == null) return;
		if (a.id != lastAuraId) {
			lastAuraId = a.id;
			previewEffects = [];
			panX.set(0);
			panY.set(0);
			previewZoom.set(1);
		}

		var chromeH:Float = withControls ? 48 : (compactFit ? 8 : 14);
		var canvasPos = ImGui.getCursorScreenPos();
		var center = ImGui.vec2(canvasPos.x + width * 0.5, canvasPos.y + height * 0.5);
		ImGui.dummy(ImGui.vec2(width, height));
		var drawList = ImGui.getWindowDrawList();
		var now = haxe.Timer.stamp();
		var dt:Float = lastPreviewStamp > 0 ? now - lastPreviewStamp : 0;
		if (dt > 1) {
			previewEffects = [];
			dt = 0;
		} else if (dt > 0.1) dt = 0.1;
		lastPreviewStamp = now;
		updatePreviewEffects(dt);

		if (autoPlay) {
			animTime += 0.016 * animSpeed.get();
			if (animTime > 1.0) animTime = 0.0;
			progress.set(animTime);
		} else {
			animTime = progress.get();
		}

		var logicalW = a.w.get() > 1 ? a.w.get() : 96;
		var logicalH = a.h.get() > 1 ? a.h.get() : 96;
		var isCanvas = a.region == "canvas";
		var drawW:Float;
		var drawH:Float;
		var effectiveScale:Float = 1;
		var maxW = Math.max(1, width - 20);
		var maxH = Math.max(1, height - chromeH);
		if (compactFit) {
			// Contained preview: always letterbox into stage (no 1:1 overflow, no L/R wander).
			var scaledW = logicalW * a.scale.get();
			var scaledH = logicalH * a.scale.get();
			var fit = Math.min(1, Math.min(maxW / Math.max(1, scaledW), maxH / Math.max(1, scaledH)));
			drawW = scaledW * fit;
			drawH = scaledH * fit;
			effectiveScale = a.scale.get() * fit;
		} else if (isCanvas) {
			drawW = logicalW;
			drawH = logicalH;
			effectiveScale = 1;
		} else {
			var scaledW = logicalW * a.scale.get() * previewZoom.get();
			var scaledH = logicalH * a.scale.get() * previewZoom.get();
			if (zoomMode == 1) {
				drawW = scaledW;
				drawH = scaledH;
				effectiveScale = a.scale.get() * previewZoom.get();
			} else {
				var fit = Math.min(1, Math.min(maxW / Math.max(1, scaledW), maxH / Math.max(1, scaledH)));
				drawW = scaledW * fit;
				drawH = scaledH * fit;
				effectiveScale = a.scale.get() * previewZoom.get() * fit;
			}
		}

		var cx = center.x - drawW * 0.5;
		var cy = compactFit ? center.y - drawH * 0.5 : canvasPos.y + (height - chromeH - drawH) * 0.5;
		if (!compactFit && isCanvas) {
			if (drawW > width - 20) cx = canvasPos.x + 10;
			if (drawH > height - chromeH) cy = canvasPos.y + 4;
		}
		if (!compactFit) {
			cx += panX.get();
			cy += panY.get();
		}

		var stageFailed = false;
		var stageFailure:Dynamic = null;
		ImGui.ImDrawList_PushClipRect(drawList, canvasPos,
			ImGui.vec2(canvasPos.x + width, canvasPos.y + height), true);
		try {
			ImGui.ImDrawList_AddRectFilled(drawList, canvasPos,
				ImGui.vec2(canvasPos.x + width, canvasPos.y + height), 0xEE121722, 6.0);
			ImGui.ImDrawList_AddRect(drawList, canvasPos,
				ImGui.vec2(canvasPos.x + width, canvasPos.y + height), 0x444A5568, 6.0, 1.0);
			if (showGrid) drawGrid(drawList, canvasPos.x, canvasPos.y, width, height);
			var simLeft:Null<Float> = null;
			if (!(Math.isFinite(a.timeLeft) && a.timeLeft >= 0) && !a.timerInfinite) {
				var span = solarflare.cdb.CdbAuraTable.listedSpan(a.timingSubjectId());
				if (!(span > 0.05))
					span = 12;
				simLeft = span * (1 - progress.get());
			}
			AuraVisualRenderer.draw(drawList, a, cx, cy, drawW, drawH, progress.get(), stacks.get(),
				stacks.get(), ghostPreview, 1, effectiveScale, simLeft, solarflare.aura.AuraEffects.hasIconGlow(a));
			if (showBounds)
				ImGui.ImDrawList_AddRect(drawList, ImGui.vec2(cx, cy), ImGui.vec2(cx + drawW, cy + drawH),
					0x88F0C040, 0, 1.0);
			for (effect in previewEffects) effect.draw(drawList, center.x, center.y, effectiveScale);
			var barW = width - 40;
			var barH = 4;
			var barX = canvasPos.x + 20;
			var barY = canvasPos.y + height - (withControls ? 36 : 10);
			ImGui.ImDrawList_AddRectFilled(drawList, ImGui.vec2(barX, barY),
				ImGui.vec2(barX + barW, barY + barH), 0x44FFFFFF, 3.0);
			ImGui.ImDrawList_AddRectFilled(drawList, ImGui.vec2(barX, barY),
				ImGui.vec2(barX + barW * progress.get(), barY + barH), 0xFF4FD1C5, 3.0);
		} catch (e:Dynamic) {
			stageFailed = true;
			stageFailure = e;
		}
		ImGui.ImDrawList_PopClipRect(drawList);
		if (stageFailed) throw stageFailure;

		lastDrawX = cx;
		lastDrawY = cy;
		lastDrawW = drawW;
		lastDrawH = drawH;

		lastCx = center.x;
		lastCy = center.y;

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

	/** Play + Pulse/Expire/Ready (legacy single-row). Prefer drawFxButtons when host owns Play. */
	public function drawSimButtons(a:AuraDef):Void {
		if (a == null) return;
		if (ImGui.button(autoPlay ? "Pause##apv" : "Play##apv", ImGui.vec2(0, 26)))
			autoPlay = !autoPlay;
		ImGui.sameLine();
		drawFxButtons(a);
	}

	/** Pulse / Expire / Ready only — Host owns Play separately; these triggers never change aura settings. */
	public function drawFxButtons(a:AuraDef):Void {
		if (a == null) return;
		ImGui.alignTextToFramePadding();
		ImGui.text("Test FX:");
		ImGui.sameLine(0, 6);
		if (ImGui.button("Pulse##apv", ImGui.vec2(0, 26))) {
			EffectHelpers.auraHit(0, 0, createPreviewEffect);
		}
		ImGui.sameLine();
		if (ImGui.button("Expire##apv", ImGui.vec2(0, 26))) {
			EffectHelpers.auraExpire(0, 0, createPreviewEffect);
		}
		ImGui.sameLine();
		if (ImGui.button("Ready##apv", ImGui.vec2(0, 26))) {
			EffectHelpers.skillReady(0, 0, createPreviewEffect);
		}
	}

	function createPreviewEffect(type:EffectType, x:Float, y:Float, params:EffectParams):VectorEffect {
		var effect = new VectorEffect();
		effect.init(type, x, y, params);
		previewEffects.push(effect);
		if (previewEffects.length > 32) previewEffects.shift();
		return effect;
	}

	function updatePreviewEffects(dt:Float):Void {
		var i = 0;
		while (i < previewEffects.length) {
			var effect = previewEffects[i];
			effect.update(dt);
			if (effect.isDead()) previewEffects.splice(i, 1); else i++;
		}
	}
}
